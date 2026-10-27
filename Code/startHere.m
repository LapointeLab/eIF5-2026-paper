%% startHere
% Sets up MATLAB to use the analysis apps for
% "A codon-sensitive conformational switch gates commitment to translation
% start sites". Run it once each time you start MATLAB:
%
%   >> run('<where you put the repository>/Code/startHere.m')
%
% It adds the apps (and the bundled vbFRET) to the MATLAB path for this
% session only, checks for the toolboxes the Analysis Pipeline needs, and
% prints how to open the apps. Nothing on your computer is changed
% permanently. See Code/README.md for step-by-step instructions.

codeDir = fileparts(mfilename('fullpath'));
repoDir = fileparts(codeDir);

% The apps need their own folder on the path (their +pipeline / +modules
% package folders are found from there). genpath skips package folders.
addpath(fullfile(codeDir, 'AssignStatesTool'));
addpath(fullfile(codeDir, 'AnalysisPipeline'));
addpath(fullfile(codeDir, 'IntensityAnalysis'));
addpath(genpath(fullfile(codeDir, 'vbFRET_June10')));

fprintf('\neIF5 paper analysis code is on the MATLAB path for this session.\n\n');

% ---- Checks ---------------------------------------------------------------
if verLessThan('matlab', '23.2')
    fprintf(['  Note: the apps were developed in MATLAB R2023b. You are running %s;\n' ...
             '  older releases may not support every feature.\n\n'], version('-release'));
end

needed = {'curvefit', 'Curve Fitting Toolbox'; ...
          'stats',    'Statistics and Machine Learning Toolbox'};
for k = 1:size(needed, 1)
    if isempty(ver(needed{k, 1}))
        fprintf(['  Missing: %s. The Analysis Pipeline needs it for fitting;\n' ...
                 '  Assign States works without it.\n\n'], needed{k, 2});
    end
end

% ---- What to do next ------------------------------------------------------
fprintf('Open an app by typing its name in the Command Window:\n');
fprintf('  AssignStatesApp       - look at single-molecule traces and their ON/OFF assignments\n');
fprintf('  AnalysisPipelineApp   - binding kinetics, FRET distributions and conformations\n\n');
fprintf('Then click Load and choose a .mat file from one of the Figure folders, e.g.\n');
fprintf('  %s\n\n', fullfile(repoDir, 'Figure 3', '20241209_IRES-AUG_eIF5-WT', ...
    'IRES-AUG_eIF5-WT_analyzed.mat'));
fprintf('Step-by-step instructions: %s\n\n', fullfile(codeDir, 'README.md'));

clear codeDir repoDir needed k
