%% RecalcFretAndResetStates
% Standalone batch script. For every *_progress.mat in this folder it:
%   1. Recomputes the FRET channel of every molecule as A/(D+A), using the
%      donor/acceptor/fret columns located by channel NAME (not hardcoded
%      column positions), with a low-signal guard (see settings below).
%   2. Sets every entry of the states matrix to 0 (all states OFF).
%   3. Saves the result as <name>_recalc_progress.mat next to the original
%      (originals are never modified), keeping every other variable
%      (channelNames, nChPerMol, currentMol, ...) unchanged.
%   4. Opens each saved result in its own AssignStatesApp window.
%
% Run from anywhere:  RecalcFretAndResetStates

%% ---- Settings ----------------------------------------------------------
guardThreshold = 50;    % frames with (donor + acceptor) < this get guardValue
guardValue     = 0;     % value written to guarded frames (0 matches the
                        % existing masked frames; use NaN to mark them instead)
openApps       = true;  % open each recalculated file in AssignStatesApp
inputPattern   = '*_progress.mat';
outputTag      = '_recalc';   % <name>_progress.mat -> <name>_recalc_progress.mat

%% ---- Setup -------------------------------------------------------------
folder = fileparts(mfilename('fullpath'));
addpath(folder);   % AssignStatesApp.m and +pipeline must be on the path

listing = dir(fullfile(folder, inputPattern));
listing = listing(~endsWith({listing.name}, [outputTag '_progress.mat']));  % skip our own outputs
if isempty(listing)
    error('RecalcFretAndResetStates:noFiles', 'No files matching %s in %s.', inputPattern, folder);
end

outPaths = {};
outNames = {};

%% ---- Process each file -------------------------------------------------
for f = 1:numel(listing)
    inName = listing(f).name;
    S = load(fullfile(folder, inName));
    try
        S = pipeline.applyLegacyDefaults(S);   % old ttotal/states-only files -> 2-color
    catch ME
        warning('RecalcFretAndResetStates:skip', '%s: %s -- skipped.', inName, ME.message);
        continue;
    end

    required = {'ttotal', 'states', 'channelNames', 'nChPerMol'};
    missing = required(~isfield(S, required));
    if ~isempty(missing)
        warning('RecalcFretAndResetStates:skip', '%s is missing %s -- skipped.', ...
            inName, strjoin(missing, ', '));
        continue;
    end

    nCh  = double(S.nChPerMol);
    nMol = (size(S.ttotal, 2) - 1) / nCh;
    if nMol ~= round(nMol)
        error('RecalcFretAndResetStates:badShape', ...
            '%s: ttotal has %d columns, not 1 + nMol*%d.', inName, size(S.ttotal, 2), nCh);
    end

    donorIdx    = pipeline.findChannelIndex(S.channelNames, 'donor');
    acceptorIdx = pipeline.findChannelIndex(S.channelNames, 'acceptor');
    fretIdx     = pipeline.findChannelIndex(S.channelNames, 'fret');
    if isempty(donorIdx) || isempty(acceptorIdx) || isempty(fretIdx)
        error('RecalcFretAndResetStates:noChannel', ...
            '%s: need channels containing "donor", "acceptor" and "fret"; found: %s.', ...
            inName, strjoin(S.channelNames, ', '));
    end

    molCols  = pipeline.getMolCols(1:nMol, nCh);
    donorCols    = molCols(donorIdx:nCh:end);
    acceptorCols = molCols(acceptorIdx:nCh:end);
    fretCols     = molCols(fretIdx:nCh:end);

    D = S.ttotal(:, donorCols);
    A = S.ttotal(:, acceptorCols);
    oldFret = S.ttotal(:, fretCols);

    total = D + A;
    newFret = A ./ total;
    guarded = (total < guardThreshold) | (total == 0);
    newFret(guarded) = guardValue;

    S.ttotal(:, fretCols) = newFret;

    nStatesCleared = nnz(S.states);
    S.states = zeros(size(S.states), 'like', S.states);

    % ---- Report ----
    % The old values were stored at single precision, so compare with a
    % tolerance rather than ==.
    wasMasked = (oldFret == 0);
    sameValue = abs(oldFret - newFret) < 1e-4 | (isnan(oldFret) & isnan(newFret));
    fprintf('\n%s\n', inName);
    fprintf('  molecules: %d, frames: %d\n', nMol, size(S.ttotal, 1));
    fprintf('  FRET frames that were 0 before:                 %d (%.1f%%)\n', ...
        nnz(wasMasked), 100 * nnz(wasMasked) / numel(wasMasked));
    fprintf('  FRET frames guarded now (D+A < %g):            %d (%.1f%%)\n', ...
        guardThreshold, nnz(guarded), 100 * nnz(guarded) / numel(guarded));
    fprintf('  previously-0 frames that now have a value:      %d\n', nnz(wasMasked & ~guarded));
    fprintf('  previously-nonzero frames now guarded (lost):   %d\n', nnz(~wasMasked & guarded));
    fprintf('  previously-nonzero, unguarded frames unchanged: %d of %d\n', ...
        nnz(~wasMasked & ~guarded & sameValue), nnz(~wasMasked & ~guarded));
    fprintf('  state entries cleared to 0: %d\n', nStatesCleared);

    % ---- Save ----
    outName = strrep(inName, '_progress.mat', [outputTag '_progress.mat']);
    save(fullfile(folder, outName), '-struct', 'S');
    fprintf('  saved: %s\n', outName);

    outPaths{end + 1} = fullfile(folder, outName); %#ok<SAGROW>
    outNames{end + 1} = outName;                   %#ok<SAGROW>
end

%% ---- Open each result in AssignStatesApp -------------------------------
apps = {};
if openApps
    for k = 1:numel(outPaths)
        d = load(outPaths{k});
        app = AssignStatesApp();
        app.loadDataStruct(d, outNames{k});
        if isfield(d, 'currentMol')   % resume where the file says, as the app's own Open does
            app.Data.currentMol = max(1, min(app.Data.nMol, double(d.currentMol)));
            app.resetAxesForNewMolecule();
        end
        apps{end + 1} = app; %#ok<SAGROW>
    end
    fprintf('\nOpened %d file(s) in AssignStatesApp (handles in variable "apps").\n', numel(apps));
end
