%% nlm gui examples

% make sure the code is recognized along Matlab's path
addpath(genpath("H:\My Drive\CONSULTING\CLIENTS\Singer_Josh"))


%% example 1: simplest implementation

batch_nlm_gui


%% example 2a: programmatically specify data

h = batch_nlm_gui; % where h is an object of type `batch_nlm_gui`

h.dataroot = "H:\My Drive\CONSULTING\CLIENTS\Singer_Josh\ON_Alpha\c06_20201215"; % specify data root
h.regexpPattern = "**\*avg.dat"; % find all files within the dataroot matching this pattern


%% example 2b: programmatically specify data and run analysis
h.fileSelection = true; % select all files (false by default)
h.run; % run analysis on selected files



%% example 3: alternative syntax

h = batch_nlm_gui(regexpPattern="**\*avg.dat", ...
    dataroot="H:\My Drive\CONSULTING\CLIENTS\Singer_Josh\BackgroundArchive\083010p4");