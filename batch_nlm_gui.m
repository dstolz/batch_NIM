classdef batch_nlm_gui < handle
    % batch_nlm_gui
    % obj = batch_nlm_gui(___)
    %
    % Daniel Stolzberg 2024

    properties (GetAccess = public, SetAccess = protected)
        currentNIM (1,1) = NIM;
        currentStimulus (1,:) double {mustBeFinite} = [];
        currentResponse (1,:) double {mustBeFinite} = [];
        dataffns (:,1) string = ""
        datafns (:,1) string = ""

        handles % gui handles

    end

    properties (SetObservable,AbortSet)
        fileSelection (:,1) logical
        regexpPattern (1,1) string = "**\*.dat"
        dataroot (1,1) string = string(cd)
    end

    properties (Dependent)
        nimffns (:,1) string
    end

    properties (Hidden)

    end


    methods

        function obj = batch_nlm_gui(options)
            arguments
                options.dataroot (1,1) string = string(cd)
                options.regexpPattern (1,1) string = "**\*.dat"
                options.fileSelection (:,1) logical = false
            end



            h.figure = findall(0,'Name','NLM Analysis');

            if ~isempty(h.figure)
                movegui(h.figure);
                figure(h.figure);
                return
            end

            fprintf('Starting batch_nlm_gui\n')
            obj.handles = obj.create_gui;

            addlistener(obj,'regexpPattern','PostSet',@obj.update_filelist);
            addlistener(obj,'dataroot','PostSet',@obj.update_dataroot);
            addlistener(obj,'fileSelection','PostSet',@obj.files_select);


            for p = string(fieldnames(options))'
                obj.(p) = options.(p);
            end

            obj.gui_state('check')

            if nargout == 0, clear obj; end
        end


        function browse_dataroot(obj,~,~)
            d = uigetdir(obj.dataroot,"Select data root");
            if isequal(d,0), return; end

            obj.dataroot = string(d);

            % obj.handles.dataroot.Value = obj.dataroot;
        end


        function update_dataroot(obj,src,~)
            if ishandle(src)
                obj.dataroot = string(src.Value);
                return
            end


            assert(isfolder(obj.dataroot),"batch_nlm_gui:update_dataroot:Path not found!")


            fprintf("New data path: %s\n",obj.dataroot)

            if ~ishandle(src)
                obj.handles.dataroot.Value = obj.dataroot;
            end

            obj.update_filelist([]);
        end

        function update_filelist(obj,src,~)
            if ishandle(src)
                obj.regexpPattern = src.Value;
                return
            end

            d = dir(fullfile(obj.dataroot, obj.regexpPattern));

            n = length(d);
            if n == 0
                fprintf(2,"Found %d files matching the pattern: %s\n",n,obj.regexpPattern)
            else
                fprintf("Found %d files matching the pattern: %s\n",n,obj.regexpPattern)
            end

            obj.dataffns = arrayfun(@(x) string(fullfile(x.folder, x.name)), d);
            obj.datafns = string({d.name});

            f = cellstr(obj.dataffns);
            x = cellfun(@(a) find(a==filesep,2,'last'),f,'uni',0);
            x = cellfun(@(a) a(1),x,'uni',0);
            f = "." + cellfun(@(a,b) string(a(b:end)),f,x);

            obj.handles.files.Items = f;
            obj.handles.files.ItemsData = obj.dataffns;

            hr = obj.handles.regexp;
            if ~any(string(hr.Items) == obj.regexpPattern)
                hr.Items{end + 1} = char(obj.regexpPattern);
                hr.ItemsData{end + 1} = char(obj.regexpPattern);
                setpref('batch_nlm_gui','ritems',hr.ItemsData);
            end
            hr.Value = char(obj.regexpPattern);

            obj.fileSelection = true(n,1);

        end

        function files_select(obj,~,~,type)

            hf = obj.handles.files;

            if nargin == 4
                switch type
                    case "all"
                        obj.fileSelection = true(size(hf.Items));

                    case "none"
                        obj.fileSelection = false(size(hf.Items));

                    case "other"
                        obj.fileSelection = ismember(hf.ItemsData,hf.Value);
                end
                return
            end

            if length(obj.fileSelection) == 1
                if obj.fileSelection == true
                    obj.fileSelection = true(size(hf.ItemsData));
                else
                    obj.fileSelection = false(size(hf.ItemsData));
                end
                return
            end

            try
                assert(length(obj.fileSelection) == length(hf.ItemsData), ...
                    "obj.fileSelection must be a logical vector with the same number of values as there are files.")
            catch me
                obj.gui_state('disabled');
                rethrow(me);
            end

            hf.Value = hf.ItemsData(obj.fileSelection);

            fprintf("Selected %d of %d files for analysis\n", ...
                sum(obj.fileSelection),length(obj.fileSelection))

            obj.gui_state("check")
        end




        function fns = get.nimffns(obj)
            [fpths,frs,~] = fileparts(obj.dataffns);
            fns = fullfile(fpths,frs) + "_NIM.mat";
        end



        function gui_state(obj,state)
            h = obj.handles;

            h.dataroot.Enable = "on";
            h.datarootBrowse.Enable = "on";
            h.regexp.Enable = "on";
            h.files.Enable = "on";
            h.fileSelectAll.Enable = "on";
            h.fileSelectNone.Enable = "on";
            h.params.Enable = "on";

            switch state

                case 'check'
                    if sum(obj.fileSelection) == 0
                        obj.gui_state("disabled")
                    else
                        obj.gui_state("ready")
                    end

                case 'ready'
                    h.run.Enable = "on";

                case 'running'
                    h.dataroot.Enable = "off";
                    h.datarootBrowse.Enable = "off";
                    h.regexp.Enable = "off";
                    h.files.Enable = "off";
                    h.fileSelectAll.Enable = "off";
                    h.fileSelectNone.Enable = "off";
                    h.params.Enable = "off";
                    h.run.Enable = "off";

                case 'disabled'
                    h.run.Enable = "off";
            end

            drawnow
        end




        function run(obj,~,~)

            obj.gui_state('running')

            try
                ffnOut = obj.nimffns(obj.fileSelection);

                params = obj.handles.params.Data;
                for i = 1:size(params,1)
                    P.(params{i,1}) = params{i,2};
                end

                dfns = obj.datafns(obj.fileSelection);
                dffns = obj.dataffns(obj.fileSelection);

                nk = sum(obj.fileSelection);
                for k = 1:nk
                    fprintf("%d of %d: %s\n",k,nk,dfns(k))


                    % m(:,1) : stim; m(:,2) : response
                    m = readmatrix(dffns(k),FileType="text");
                    obj.currentStimulus = m(:,1);
                    obj.currentResponse = m(:,2);


                    % Run the LNAnalysis
                    obj.currentNIM = process_nlm(obj.currentResponse,obj.currentStimulus,P);

                    obj.currentNIM.OriginalFilename = dffns(k);
                    obj.currentNIM.Label = dfns(k);


                    obj.currentNIM.kernelPeak = max(obj.currentNIM.fit_RectLin_NonParam.subunits.filtK);

                    f = findobj('type','figure','-and','name',"NLM");
                    if isempty(f), f = figure(Name = "NLM",Color="w"); end
                    figure(f);
                    clf(f);
                    obj.plot_models(obj.currentNIM);
                    sgtitle(dfns(k),Interpreter = "none")
                    drawnow

                    fprintf('Saving NIM to: %s ...',ffnOut(k))
                    MODEL = obj.currentNIM;
                    save(ffnOut(k),"MODEL")
                    fprintf(' done\n')

                end

            catch me

                obj.gui_state('ready')
                rethrow(me)
            end
            obj.gui_state('ready')

            setpref('batch_nlm_gui','params',params);
        end













        function h = create_gui(obj)

            h.figure = uifigure(Name="NLM Analysis");

            % main grid layout
            gmain = uigridlayout(h.figure);
            gmain.RowHeight = {50,'1x'};
            gmain.ColumnWidth = {'1x','1x'};


            % path and file specifications
            gpth = uigridlayout(gmain);
            gpth.Layout.Row = 1;
            gpth.Layout.Column = [1 2];
            gpth.RowHeight = {40};
            gpth.ColumnWidth = {'1x',30};

            h.dataroot = uieditfield(gpth,"text");
            h.dataroot.Tag = "dataroot";
            h.dataroot.Layout.Row = 1;
            h.dataroot.Layout.Column = 1;
            h.dataroot.ValueChangedFcn = @(src,event) obj.update_dataroot(src,event);
            h.dataroot.Value = cd;

            h.datarootBrowse = uibutton(gpth);
            h.datarootBrowse.Tag = "datarootBrowse";
            h.datarootBrowse.Layout.Row = 1;
            h.datarootBrowse.Layout.Column = 2;
            h.datarootBrowse.Text = "...";
            h.datarootBrowse.Tooltip = "select a directory for analysis";
            h.datarootBrowse.ButtonPushedFcn = @(src,event) obj.browse_dataroot(src,event);


            % File list
            gfiles = uigridlayout(gmain);
            gfiles.Layout.Row = 2;
            gfiles.Layout.Column = 1;
            gfiles.RowHeight = {40,'1x',40};
            gfiles.ColumnWidth = repmat({'1x'},1,3);


            ritems = getpref('batch_nlm_gui','ritems', ["**\*.dat","**\*avg.dat"]);
            h.regexp = uidropdown(gfiles);
            h.regexp.Tag = "FileRegexp";
            h.regexp.Layout.Row = 1;
            h.regexp.Layout.Column = [1 3];
            h.regexp.Items = ritems;
            h.regexp.ItemsData = ritems;
            h.regexp.Editable = true;
            h.regexp.ValueChangedFcn = @(src,event) obj.update_filelist(src,event);

            h.files = uilistbox(gfiles);
            h.files.Tag = "FileList";
            h.files.Layout.Row = 2;
            h.files.Layout.Column = [1 3];
            h.files.Items = {};
            h.files.Multiselect = "on";
            h.files.FontName = "Consolas";
            h.files.ValueChangedFcn = @(src,event) obj.files_select(src,event,"other");

            h.fileSelectAll = uibutton(gfiles);
            h.fileSelectAll.Tag = "FileSelectAll";
            h.fileSelectAll.Layout.Row = 3;
            h.fileSelectAll.Layout.Column = 1;
            h.fileSelectAll.Text = "All";
            h.fileSelectAll.Tooltip = "select all files currently in the file list";
            h.fileSelectAll.ButtonPushedFcn = @(src,event) obj.files_select(src,event,"all");

            h.fileSelectNone = uibutton(gfiles);
            h.fileSelectNone.Tag = "FileSelectNone";
            h.fileSelectNone.Layout.Row = 3;
            h.fileSelectNone.Layout.Column = 3;
            h.fileSelectNone.Text = "None";
            h.fileSelectNone.Tooltip = "select all files currently in the file list";
            h.fileSelectNone.ButtonPushedFcn = @(src,event) obj.files_select(src,event,"none");




            % Parameters
            gparams = uigridlayout(gmain);
            gparams.Layout.Row = 2;
            gparams.Layout.Column = 2;
            gparams.RowHeight = {'1x',50};
            gparams.ColumnWidth = {'1x'};

            p = getpref('batch_nlm_gui','params',obj.default_params);
            h.params = uitable(gparams,Data=p);
            h.params.Tag = "ParameterTable";
            h.params.Layout.Row = 1;
            h.params.Layout.Column = 1;
            h.params.FontName = "Consolas";
            h.params.ColumnEditable = [false true];
            % h.params.CellEditCallback = @(src,event) obj.update_params(src,event);

            h.run = uibutton(gparams);
            h.run.Tag = "Run";
            h.run.Layout.Row = 2;
            h.run.Layout.Column = 1;
            h.run.Text = "Run";
            h.run.ButtonPushedFcn = @(src,event) obj.run(src,event);


        end
    end










    methods (Static)
        function plot_xcorr(stim,resp,options)
            % batch_nlm_gui.plot_xcorr(stim,resp,[nlags])

            arguments
                stim double
                resp double
                options.nlags (1,1) {mustBeInteger,mustBePositive,mustBeNonempty} = 200;
            end

            % Quick plot of DATA-STIM cross-correlation ---------
            [r,lags] = xcorr(stim,resp,"coeff");

            cla
            plot(lags,r,LineWidth=2);

            yline(0)
            xline(0)
            xlabel("lag (samples)")
            grid on
            axis tight
            xlim([-1 1]* options.nlags)

        end


        function plot_models(DNIM)
            % batch_nlm_gui.plot_models(NIM)
            %
            % ex: batch_nlm_gui.plot_models(obj.currentNIM)

            clf(gcf);
            tl = tiledlayout(gcf,'flow');

            nexttile(tl);
            batch_nlm_gui.plot_xcorr(DNIM.stim,DNIM.resp)


            [~,y0] = DNIM.fit.eval_model(DNIM.resp, DNIM.stimTimeEmbed,1:size(DNIM.stimTimeEmbed,1));
            [~,yr] = DNIM.fit_RectLin.eval_model(DNIM.resp, DNIM.stimTimeEmbed,1:size(DNIM.stimTimeEmbed,1));
            [~,yn] = DNIM.fit_RectLin_NonParam.eval_model(DNIM.resp, DNIM.stimTimeEmbed,1:size(DNIM.stimTimeEmbed,1));

            nexttile(tl);
            p(1) = plot(DNIM.resp,DisplayName="response");
            hold on
            p(2) = plot(y0,DisplayName="model");
            p(3) = plot(yr,DisplayName="model-rect");
            p(4) = plot(yn,DisplayName="model-nonparam");
            hold off
            grid on
            axis tight
            legend(p,Location="southeast")
            title('Result')
            my = max(abs(ylim));


            nexttile(tl); % zoom in on response
            p(1) = plot(DNIM.resp,DisplayName="response");
            hold on
            p(2) = plot(y0,DisplayName="model");
            p(3) = plot(yr,DisplayName="model-rect");
            p(4) = plot(yn,DisplayName="model-nonparam");
            % yline(0)
            hold off
            grid on
            axis tight
            pan('xon')
            mx = min(.3*length(y0),1000);
            xlim([0 mx])
            ylim([-1 1].*my)
            xlabel('samples')
            title(sprintf('zoom'))
        end

        function p = default_params()
            p.Parameter = ["nLags"; "tent_sp"; "stim_dt"; "NSH"; "lamnda_nld2"; "invertResponse"];
            p.Value = [80; 4; 0.001; 5; 500; 1];

            p = struct2table(p);
        end
    end



end