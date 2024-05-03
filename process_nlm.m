function D = process_nlm(RESPONSE,STIM,params)
% D = process_nlm(RESPONSE,STIM,params)


% default parameters
P.invertResponse = false;
P.nLags = 80; %80; 90; % formerly 60, 100
P.tent_sp = 4; %12 15; % formerly 4, 12, 20
P.stim_dt = 0.001;
P.NSH = 5;  
% P.dummyRepXVindx = linspace(1,1000,1000)
P.lamda_nld2 = 500;

% assign parameters with no checking
if nargin >= 3 && ~isempty(params)
    for p = string(fieldnames(params))'
        P.(p) = params.(p);
    end
end

D.stim = STIM(:);
clear STIM

D.stimMean = mean(D.stim);
nrm = std(D.stim); 
D.stim = (D.stim-D.stimMean)/nrm;

if P.invertResponse, RESPONSE = -RESPONSE; end

D.resp = RESPONSE;
clear RESPONSE

D.respMean = mean(D.resp);
nrm = std(D.resp);
D.resp = (D.resp - D.respMean) / nrm;

D.Sparams0 = NIM.create_stim_params([P.nLags 1 1], ...
    'stim_dt', P.stim_dt, ...
    'tent_spacing', P.tent_sp);


% create_time_embedding: Create T x nLags 'Xmatrix' representing the 
% relevant stimulus history at each time point
D.stimTimeEmbed = NIM.create_time_embedding(D.stim, D.Sparams0); 



% DS: SHIFTS D BY NSH SAMPLES (DEFAULT=5). UNSURE WHAT IS THE PURPOSE OF THIS.
D.cur = NIM.shift_mat_zpad(D.resp,P.NSH); 


D.NT = size(D.stimTimeEmbed,1);



% generate_XVfolds: Generates Uindx and XVindx to use for fold-Xval.
[D.Uindx,D.XVindx] = NIM.generate_XVfolds(D.NT);





% Linear model [~1min]
% Single contrast fits
D.fit = NIM(D.Sparams0, ...
    {'lin'}, 1, ...
    'd2t', 1000, ...
    'spkNL', 'lin', ...
    'noise_dist', 'gaussian');
D.fit = D.fit.fit_filters(D.cur, D.stimTimeEmbed, D.Uindx);
D.fit = D.fit.reg_path2(D.cur, D.stimTimeEmbed, D.Uindx, D.XVindx, 'lambdaID', 'd2t');


% cross-validated performance of models at each contrast -- models fit to particular contrast condition do best (larger numbers better)
D.LLmat = D.fit.eval_model(D.cur, D.stimTimeEmbed, D.XVindx);




% Add rectification [~2min]
D.fit_RectLin = D.fit;
D.fit_RectLin.subunits(1).NLtype = 'rectlin';
D.fit_RectLin = D.fit_RectLin.fit_filters(D.cur, D.stimTimeEmbed, D.Uindx);
D.fit_RectLin = D.fit_RectLin.reg_path2(D.cur, D.stimTimeEmbed, D.Uindx, D.XVindx, 'lambdaID', 'd2t');


D.LLmat(2,:) = D.fit_RectLin.eval_model(D.cur, D.stimTimeEmbed, D.XVindx);


% Non-parametric LN
D.fit_RectLin_NonParam = D.fit_RectLin.init_nonpar_NLs(D.stimTimeEmbed, 'lambda_nld2', P.lamda_nld2); 

D.fit_RectLin_NonParam = D.fit_RectLin_NonParam.fit_upstreamNLs(D.cur, D.stimTimeEmbed, D.Uindx);
D.fit_RectLin_NonParam = D.fit_RectLin_NonParam.reg_path2(D.cur, D.stimTimeEmbed, D.Uindx, D.XVindx, 'lambdaID', 'nld2');
D.fit_RectLin_NonParam = D.fit_RectLin_NonParam.fit_filters(D.cur, D.stimTimeEmbed, D.Uindx);


D.LLmat(3,:) = D.fit_RectLin_NonParam.eval_model(D.cur, D.stimTimeEmbed, D.XVindx);



D.Timestamp = datetime("now");

D.params = P;








