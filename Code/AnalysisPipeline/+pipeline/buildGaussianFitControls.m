function fitUI = buildGaussianFitControls(controlsParent, resultsParent, ax, app, logKey, dataFcn, metaFcn, fitLineColor, fitTag)
%BUILDGAUSSIANFITCONTROLS Wire up the shared 1-4-component Gaussian-mixture
%histogram fitting UI. Mirrors pipeline.buildFitControls' role and
%conventions, but for sum-of-Gaussians fits to normalized histograms
%instead of exponential fits to eCDFs.
%
%   fitUI = buildGaussianFitControls(controlsParent, resultsParent, ax, app, logKey, dataFcn, metaFcn, fitLineColor, fitTag)
%
%   controlsParent : container (e.g. a uipanel) to hold the Gaussian-count
%                    selector, per-component mean guess fields, robust
%                    checkbox, bootstrap-N field, and Fit/Save Fit buttons.
%   resultsParent  : container (e.g. a uipanel) to hold the fitted
%                    parameter/CI/R^2 text output.
%   ax             : uiaxes the fitted curve is overlaid on.
%   app            : AnalysisPipelineApp instance. Clicking Fit is a trial —
%                    it plots and displays the result but does NOT log it.
%                    Only "Save Fit" appends the most recent fit (plus its
%                    bootstrap CI) to the module's own result log.
%   logKey         : string identifying which per-module result log to log
%                    into (see app.appendResultLog) and the default CSV
%                    export filename. Each calling module should use a fixed,
%                    unique logKey so its results never mix with another
%                    module's — pass the SAME logKey to more than one
%                    buildFitControls/buildGaussianFitControls instance only
%                    when they should share one combined log (e.g.
%                    +modules/lifetimeSorting.m's Short and Long panels, which
%                    also set metaFcn's optional Group field so the combined
%                    log's rows can still be told apart).
%   dataFcn        : function handle, () -> [X, Y, n, rawData, molIDs, edges]:
%                    X/Y is the normalized histogram (bin centers/heights)
%                    to fit and plot; n is the number of underlying
%                    observations -- FRAMES, for every current caller (each
%                    pools every frame of every qualifying binding event),
%                    logged as NFrames, NOT the result-log row's NEvents
%                    column (see metaFcn's optional NEvents field);
%                    rawData/molIDs are the underlying
%                    per-observation values and the molecule each belongs
%                    to (same length/order), needed for the molecule-level
%                    bootstrap; edges are the histogram bin edges, needed so
%                    the bootstrap rebuilds the histogram identically each
%                    resample. Must be a handle to a nested function in the
%                    caller (not an anonymous closure over a snapshot), so
%                    it reflects live state when Fit/Save Fit is used.
%   metaFcn        : function handle, () -> struct with fields Module,
%                    Dataset, and EventFilter, describing what is being fit,
%                    for the result-log row, plus two optional fields: Group
%                    (e.g. 'Short'/'Long') to distinguish rows from separate
%                    buildGaussianFitControls instances sharing one logKey,
%                    and NEvents, the true number of underlying binding
%                    events (as opposed to dataFcn's n, which is the number
%                    of pooled frames -- see dataFcn above). NEvents logs as
%                    NaN if omitted. Same live-handle requirement as dataFcn.
%   fitLineColor   : optional, color of the fitted curve (default 'k').
%                    Pass a distinct color when a second, independent
%                    buildGaussianFitControls instance draws on the SAME ax
%                    (e.g. +modules/lifetimeSorting.m's Short/Long overlay),
%                    so the two fit curves stay visually distinguishable.
%   fitTag         : optional, Tag of the fitted curve Line object (default
%                    'pipelineFitCurve'). MUST be distinct per
%                    buildGaussianFitControls instance sharing one ax --
%                    each fit deletes any existing line with this same Tag
%                    before drawing its new one, so two instances using the
%                    default tag on a shared ax would delete each other's
%                    curve.
%
%   Save Fit also runs a nonparametric cluster bootstrap
%   (pipeline.bootstrapGaussianCI, resampling by molecule) on the means,
%   standard deviations and populations — never on a trial Fit, since it means many refits
%   and would be too slow to run on every click. The result-log row always
%   has columns for 4 components (mean1..mean4, std1..std4, each with a
%   fit-CI and bootstrap-CI column; population1..population4, each with a
%   bootstrap-CI column only -- see pipeline.fitGaussianMixture), NaN/blank-filled for any components
%   beyond the selected count, so the schema stays fixed-width regardless of
%   how many Gaussians were used.
%
%   Also adds a "results logged" count + Export CSV control, wired to the
%   module's own result log (app.appendResultLog / app.exportResultLog /
%   app.registerResultLogCountLabel).

if nargin < 8 || isempty(fitLineColor)
    fitLineColor = 'k';
end
if nargin < 9 || isempty(fitTag)
    fitTag = 'pipelineFitCurve';
end

cg = uigridlayout(controlsParent, [11 2]);
cg.RowHeight = [repmat({'fit'}, 1, 9), {15, 'fit'}];
cg.ColumnWidth = {'fit', '1x'};
cg.RowSpacing = 6;

uilabel(cg, 'Text', 'Gaussians:');
gaussCountDropdown = uidropdown(cg, 'Items', {'1', '2', '3', '4'}, 'ItemsData', {1, 2, 3, 4}, ...
    'Value', 1, 'ValueChangedFcn', @(~, ~) updateEquationDisplay());

eqLabel = uilabel(cg, 'Text', '', 'WordWrap', 'on');
eqLabel.Layout.Column = [1 2];

meanLabels = cell(1, 4);
meanFields = cell(1, 4);
defaultMeanGuesses = [0.2, 0.4, 0.6, 0.8];
for ci = 1:4
    meanLabels{ci} = uilabel(cg, 'Text', sprintf('Mean %d guess:', ci));
    meanFields{ci} = uieditfield(cg, 'numeric', 'Value', defaultMeanGuesses(ci), 'Limits', [0 1]);
end

robustCheckbox = uicheckbox(cg, 'Text', 'Robust (bisquare)', 'Value', true);
robustCheckbox.Layout.Column = [1 2];

uilabel(cg, 'Text', 'Bootstrap N:');
bootNField = uieditfield(cg, 'numeric', 'Value', 500, 'Limits', [10 Inf], 'RoundFractionalValues', 'on');

fitButton = uibutton(cg, 'Text', 'Fit', 'ButtonPushedFcn', @(~, ~) runFit());

saveFitButton = uibutton(cg, 'Text', 'Save Fit', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) saveFit());

% Result log (this module's own, independent of every other module): count + export.
logGrid = uigridlayout(cg, [1 2]);
logGrid.Layout.Row = 11;
logGrid.Layout.Column = [1 2];
logGrid.ColumnWidth = {'1x', 'fit'};
logGrid.Padding = [0 0 0 0];
fitLogCountLabel = uilabel(logGrid, 'Text', '0 results logged');
defaultCsvName = [strrep(logKey, ' ', '_') '_results.csv'];
uibutton(logGrid, 'Text', 'Export CSV...', 'ButtonPushedFcn', @(~, ~) app.exportResultLog(logKey, defaultCsvName));
app.registerResultLogCountLabel(logKey, fitLogCountLabel);

rg = uigridlayout(resultsParent, [1 1]);
resultsLabel = uitextarea(rg, 'Value', {'No fit yet.'}, 'Editable', 'off');

updateEquationDisplay();

fitUI = struct('gaussCountDropdown', gaussCountDropdown, 'meanFields', {meanFields}, ...
    'robustCheckbox', robustCheckbox, 'bootNField', bootNField, 'fitButton', fitButton, ...
    'saveFitButton', saveFitButton, 'resultsLabel', resultsLabel, 'eqLabel', eqLabel, ...
    'fitLogCountLabel', fitLogCountLabel, 'reset', @resetFit);

% Most recent trial fit (not yet necessarily saved to the log); Save Fit
% logs exactly this, so re-fitting always overwrites what Save Fit would log.
lastFitResult = [];
lastFitN = [];
lastFitMeta = [];
lastRawData = [];
lastMolIDs = [];
lastEdges = [];

    function updateEquationDisplay()
        nG = gaussCountDropdown.Value;
        terms = arrayfun(@(i) sprintf('a%d*exp(-((x-b%d)/c%d)^2)', i, i, i), 1:nG, 'UniformOutput', false);
        eqLabel.Text = ['y = ' strjoin(terms, ' + ')];
        for gi = 1:4
            isVisible = gi <= nG;
            meanLabels{gi}.Visible = isVisible;
            meanFields{gi}.Visible = isVisible;
        end
    end

    function runFit()
        [X, Y, n, rawData, molIDs, edges] = dataFcn();
        if isempty(X) || isempty(Y)
            uialert(app.UIFigure, 'No data to fit.', 'Fit failed');
            return;
        end

        nG = gaussCountDropdown.Value;
        meanGuess = zeros(1, nG);
        for gi = 1:nG
            meanGuess(gi) = meanFields{gi}.Value;
        end
        opts = struct('meanGuess', meanGuess, 'robust', robustCheckbox.Value);

        try
            result = pipeline.fitGaussianMixture(X, Y, nG, opts);
        catch ME
            uialert(app.UIFigure, ME.message, 'Fit failed');
            return;
        end

        delete(findobj(ax, 'Tag', fitTag));
        xx = linspace(min(X), max(X), 400);
        yy = result.fitobject(xx);
        hold(ax, 'on');
        fitLine = plot(ax, xx, yy, '-', 'Color', fitLineColor, 'LineWidth', 2, 'Tag', fitTag);
        % Excluded from any legend on ax (MATLAB auto-adds newly plotted
        % lines to an existing legend with a generic "dataN" name
        % otherwise) -- relevant when a caller's ax already carries a
        % legend for the data series being fit, e.g.
        % +modules/lifetimeSorting.m's shared Short/Long plot.
        fitLine.Annotation.LegendInformation.IconDisplayStyle = 'off';
        hold(ax, 'off');

        % On-plot mean label: the results text panel isn't part of the
        % exported plot (see pipeline.exportPlot / +modules/summaryFigure.m,
        % which reconstruct/copy only the axes' own content), so the fitted
        % mean(s) need to live on the axes itself to survive into an export.
        % Only the FIT's own CI is known at this point -- saveFit() below
        % re-places this same label once the bootstrap CI is also
        % available. Placed in whichever corner currently has the least
        % data, stacking with any other instance sharing this ax (e.g.
        % +modules/lifetimeSorting.m's Short/Long overlay) -- see
        % pipeline.placeFitLabel.
        pipeline.placeFitLabel(ax, fitTag, buildMeanLines(result), fitLineColor);

        setResultsText(resultsLabel, formatResultsText(result));

        lastFitResult = result;
        lastFitN = n;
        lastFitMeta = metaFcn();
        lastRawData = rawData;
        lastMolIDs = molIDs;
        lastEdges = edges;
        saveFitButton.Enable = 'on';
    end

    function saveFit()
        if isempty(lastFitResult)
            return;
        end

        fitButton.Enable = 'off';
        saveFitButton.Enable = 'off';
        reenable = onCleanup(@() setButtonsEnabled(fitButton, saveFitButton));

        nBoot = bootNField.Value;
        setResultsText(resultsLabel, sprintf('Bootstrapping rate CI (0/%d)...', nBoot));
        drawnow;

        pointMeans = lastFitResult.means;

        try
            boot = pipeline.bootstrapGaussianCI(lastRawData, lastMolIDs, lastEdges, lastFitResult.nGaussians, ...
                lastFitResult.optsUsed, nBoot, @(frac) updateBootProgress(resultsLabel, frac, nBoot), pointMeans);
        catch ME
            uialert(app.UIFigure, ME.message, 'Bootstrap failed');
            setResultsText(resultsLabel, formatResultsText(lastFitResult));
            return;
        end

        row = buildLogRow(lastFitMeta, lastFitN, lastFitResult, boot);
        app.appendResultLog(logKey, row);
        setResultsText(resultsLabel, sprintf('%s\n\n%s\n\n(saved to result log)', ...
            formatResultsText(lastFitResult), formatBootstrapText(boot)));

        % Re-place the on-plot label now that the bootstrap CI (not just
        % the fit's own CI) is available -- see the matching call in
        % runFit() above.
        pipeline.placeFitLabel(ax, fitTag, buildMeanLines(lastFitResult, boot), fitLineColor);
    end

    function resetFit()
        %RESETFIT Clear any trial fit and disable Save Fit. Callers must call
        % this whenever the underlying data changes (e.g. a channel or event-
        % type selection change) — otherwise Save Fit stays enabled and would
        % silently log a fit for data that is no longer what's displayed.
        lastFitResult = [];
        lastFitN = [];
        lastFitMeta = [];
        lastRawData = [];
        lastMolIDs = [];
        lastEdges = [];
        saveFitButton.Enable = 'off';
        setResultsText(resultsLabel, 'No fit yet.');
    end
end

function setButtonsEnabled(fitButton, saveFitButton)
fitButton.Enable = 'on';
saveFitButton.Enable = 'on';
end

function setResultsText(resultsLabel, txt)
%SETRESULTSTEXT Write (possibly multi-line) text into the results uitextarea.
resultsLabel.Value = strsplit(txt, newline);
end

function keepGoing = updateBootProgress(resultsLabel, frac, nBoot)
keepGoing = true;   % no interactive cancel; nBoot is user-adjustable to control run time
done = round(frac * nBoot);
setResultsText(resultsLabel, sprintf('Bootstrapping rate CI (%d/%d)...', done, nBoot));
if mod(done, 10) == 0 || frac == 1
    drawnow limitrate;
end
end

function lines = buildMeanLines(result, boot)
%BUILDMEANLINES On-plot label lines for the fitted mean(s) (see
%pipeline.placeFitLabel): value (plus the component's population when
%there is more than one), then the fit's own 95% CI, then --
%once available -- the molecule-level bootstrap 95% CI (pipeline.
%bootstrapGaussianCI). boot omitted/[] (a trial Fit, before Save Fit has
%run one) means just value + fit CI; runFit() calls this without boot,
%and saveFit() re-calls it with boot once bootstrapping completes, so the
%label grows to include the bootstrap CI without changing what's already
%shown.
hasBoot = nargin >= 2 && ~isempty(boot);
lines = {};
for i = 1:result.nGaussians
    if result.nGaussians == 1
        lines{end+1} = sprintf('Mean: %.3g', result.means(i)); %#ok<AGROW>
    else
        lines{end+1} = sprintf('Mean %d: %.3g (%.0f%%)', i, result.means(i), 100 * result.pops(i)); %#ok<AGROW>
    end
    lines{end+1} = sprintf('Fit 95%% CI: [%.3g, %.3g]', result.means_CI(i, 1), result.means_CI(i, 2)); %#ok<AGROW>
    if hasBoot
        lines{end+1} = sprintf('Boot 95%% CI: [%.3g, %.3g]', boot.means_CI(i, 1), boot.means_CI(i, 2)); %#ok<AGROW>
    end
end
end

function txt = formatResultsText(result)
lines = {};
for i = 1:result.nGaussians
    lines{end+1} = sprintf('Component %d:', i); %#ok<AGROW>
    lines{end+1} = sprintf('  mean = %.4g  [%.4g, %.4g]', ...
        result.means(i), result.means_CI(i, 1), result.means_CI(i, 2)); %#ok<AGROW>
    lines{end+1} = sprintf('  std  = %.4g  [%.4g, %.4g]', ...
        result.stds(i), result.stds_CI(i, 1), result.stds_CI(i, 2)); %#ok<AGROW>
    lines{end+1} = sprintf('  population = %.1f%%', 100 * result.pops(i)); %#ok<AGROW>
end
lines{end+1} = sprintf('R^2 = %.4f', result.gof.rsquare);

txt = strjoin(lines, newline);
end

function txt = formatBootstrapText(boot)
nG = size(boot.means_CI, 1);
lines = {};
lines{end+1} = sprintf('Bootstrap 95%% CI (n=%d/%d resamples, %d molecules):', ...
    boot.nSuccess, boot.nRequested, boot.nMolecules);
for i = 1:nG
    lines{end+1} = sprintf('Component %d: mean [%.4g, %.4g], std [%.4g, %.4g], population [%.1f%%, %.1f%%]', ...
        i, boot.means_CI(i, 1), boot.means_CI(i, 2), boot.stds_CI(i, 1), boot.stds_CI(i, 2), ...
        100 * boot.pops_CI(i, 1), 100 * boot.pops_CI(i, 2)); %#ok<AGROW>
end
txt = strjoin(lines, newline);
end

function row = buildLogRow(meta, n, result, boot)
%BUILDLOGROW One result-log row per saved fit. Same "<Name>", "<Name>_FitCI",
% "<Name>_BootstrapCI" column convention as pipeline.buildFitControls (see
% that file's buildLogRow) -- each CI is one formatted "[lower, upper]"
% string column (pipeline.formatCI), not separate Lower/Upper columns.
row = struct();
row.Module      = string(meta.Module);
row.Dataset     = string(meta.Dataset);
row.EventFilter = string(meta.EventFilter);
if isfield(meta, 'Group')
    row.Group = string(meta.Group);
else
    row.Group = "";
end
row.FitType     = string(sprintf('%d-Gaussian Mixture', result.nGaussians));
% n (from dataFcn) is the number of pooled FRAMES the histogram was built
% from, not the number of binding events -- every current caller pools every
% frame of every qualifying event, so n over-counts events by however many
% frames each one lasts. NEvents is the true event count, supplied via the
% optional meta.NEvents (NaN if a caller doesn't provide it).
if isfield(meta, 'NEvents')
    row.NEvents = meta.NEvents;
else
    row.NEvents = NaN;
end
row.NFrames     = n;
row.NMolecules  = boot.nMolecules;
row.NBootstrap  = boot.nSuccess;

for i = 1:4
    if i <= result.nGaussians
        meanVal = result.means(i); meanCIlo = result.means_CI(i, 1); meanCIhi = result.means_CI(i, 2);
        stdVal  = result.stds(i);  stdCIlo  = result.stds_CI(i, 1);  stdCIhi  = result.stds_CI(i, 2);
        meanBootLo = boot.means_CI(i, 1); meanBootHi = boot.means_CI(i, 2);
        stdBootLo  = boot.stds_CI(i, 1);  stdBootHi  = boot.stds_CI(i, 2);
        popVal     = result.pops(i);
        popBootLo  = boot.pops_CI(i, 1);  popBootHi  = boot.pops_CI(i, 2);
    else
        meanVal = NaN; meanCIlo = NaN; meanCIhi = NaN;
        stdVal  = NaN; stdCIlo  = NaN; stdCIhi  = NaN;
        meanBootLo = NaN; meanBootHi = NaN;
        stdBootLo  = NaN; stdBootHi  = NaN;
        popVal = NaN; popBootLo = NaN; popBootHi = NaN;
    end
    row.(sprintf('Mean%d', i))               = meanVal; %#ok<*SAGROW>
    row.(sprintf('Mean%d_FitCI', i))         = pipeline.formatCI(meanCIlo, meanCIhi);
    row.(sprintf('Mean%d_BootstrapCI', i))   = pipeline.formatCI(meanBootLo, meanBootHi);
    row.(sprintf('Std%d', i))                = stdVal;
    row.(sprintf('Std%d_FitCI', i))          = pipeline.formatCI(stdCIlo, stdCIhi);
    row.(sprintf('Std%d_BootstrapCI', i))    = pipeline.formatCI(stdBootLo, stdBootHi);
    % Population (fraction of fitted area, 0-1): bootstrap CI only, no
    % _FitCI column -- see pipeline.fitGaussianMixture.
    row.(sprintf('Population%d', i))             = popVal;
    row.(sprintf('Population%d_BootstrapCI', i)) = pipeline.formatCI(popBootLo, popBootHi);
end

row.R2 = result.gof.rsquare;
end
