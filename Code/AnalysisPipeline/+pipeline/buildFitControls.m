function fitUI = buildFitControls(controlsParent, resultsParent, ax, app, logKey, dataFcn, metaFcn, resultLogNote)
%BUILDFITCONTROLS Wire up the shared single/double-exponential CDF fitting UI.
%   fitUI = buildFitControls(controlsParent, resultsParent, ax, app, logKey, dataFcn, metaFcn)
%
%   controlsParent : container (e.g. a uipanel) to hold the fit-type toggle,
%                    equation display, rate guess fields, robust checkbox,
%                    and the Fit button.
%   resultsParent  : container (e.g. a uipanel) to hold the fitted
%                    parameter/CI/R^2 text output.
%   ax             : uiaxes the fitted curve is overlaid on (smooth black line).
%   app            : AnalysisPipelineApp instance. Clicking Fit is a trial —
%                    it plots and displays the result but does NOT log it.
%                    Only "Save Fit" appends the most recent fit to the
%                    module's own result log (see app.appendResultLog /
%                    app.exportResultLog), so trying several guesses/settings
%                    doesn't clutter the log with intermediate attempts.
%   logKey         : string identifying which per-module result log to log
%                    into (see app.appendResultLog) and the default CSV
%                    export filename. Each calling module should use a fixed,
%                    unique logKey so its results never mix with another
%                    module's — pass the SAME logKey to more than one
%                    buildFitControls/buildGaussianFitControls instance only
%                    when they should share one combined log (e.g.
%                    +modules/lifetimeSorting.m's Short and Long panels).
%   dataFcn        : function handle, () -> [X, Y, n, rawData, molIDs],
%                    returning the CURRENT data to fit: X/Y is the eCDF (n =
%                    number of underlying events), rawData is the underlying
%                    per-event vector (e.g. quantized lifetimes) the eCDF was
%                    built from, and molIDs is the molecule each entry of
%                    rawData belongs to (same length/order) — needed so Save
%                    Fit's bootstrap can resample by molecule rather than by
%                    individual event (see pipeline.bootstrapRateCI). Must be
%                    a handle to a nested function in the caller (not an
%                    anonymous function closing over a snapshot), so it
%                    reflects live state at the moment Fit/Save Fit is used.
%   metaFcn        : function handle, () -> struct with fields Module,
%                    Dataset, and EventFilter, describing what is being fit,
%                    for the result-log row. Same live-handle requirement as
%                    dataFcn. Module is a fixed string identifying the
%                    calling module (e.g. 'Binding Lifetime Kinetics').
%
%   Save Fit also runs a nonparametric cluster bootstrap
%   (pipeline.bootstrapRateCI, resampling by molecule) on the rate
%   constant(s) only — never on a trial Fit, since it means many refits and
%   would be too slow to run on every click. The bootstrap CI is shown in
%   the results text and included as extra columns in the result log.
%
%   Also adds a "results logged" count + Export CSV control at the bottom of
%   controlsParent, wired to the module's own result log
%   (app.appendResultLog / app.exportResultLog / app.registerResultLogCountLabel).
%   resultLogNote  : optional. When a caller's Type dropdown (or similar)
%                    can log more than one kind of row into this SAME
%                    logKey -- e.g. +modules/fretStateLifetime.m's Low/High
%                    FRET state -- Save Fit for each just appends another
%                    row (never overwrites; distinguished by the row's own
%                    EventFilter value) and Export CSV always exports the
%                    whole shared table together. That's easy to read as a
%                    bug ("my other result disappeared") if a user expects
%                    two separate files instead, so resultLogNote is shown
%                    as a small note under the Export CSV control
%                    explaining it. Omitted/empty (the default) shows
%                    nothing, unchanged from before this parameter existed.
%
%   Shared across modules so every analysis needing single/double
%   exponential CDF fitting gets identical UI, math, and logging for free.

if nargin < 8
    resultLogNote = '';
end

if isempty(resultLogNote)
    cg = uigridlayout(controlsParent, [9 2]);
    cg.RowHeight = [repmat({'fit'}, 1, 7), {15, 'fit'}];
else
    cg = uigridlayout(controlsParent, [10 2]);
    cg.RowHeight = [repmat({'fit'}, 1, 7), {15, 'fit', 'fit'}];
end
cg.ColumnWidth = {'fit', '1x'};
cg.RowSpacing = 6;

uilabel(cg, 'Text', 'Fit type:');
fitTypeDropdown = uidropdown(cg, 'Items', {'Single exponential', 'Double exponential'}, ...
    'ItemsData', {1, 2}, 'Value', 1, 'ValueChangedFcn', @(~, ~) updateEquationDisplay());

eqLabel = uilabel(cg, 'Text', '', 'WordWrap', 'on');
eqLabel.Layout.Column = [1 2];

uilabel(cg, 'Text', 'b0 guess:');
b0Field = uieditfield(cg, 'numeric', 'Value', 0.1);

d0Label = uilabel(cg, 'Text', 'd0 guess:');
d0Field = uieditfield(cg, 'numeric', 'Value', 0.01);

robustCheckbox = uicheckbox(cg, 'Text', 'Robust (bisquare)', 'Value', true);
robustCheckbox.Layout.Column = [1 2];

uilabel(cg, 'Text', 'Bootstrap N:');
bootNField = uieditfield(cg, 'numeric', 'Value', 500, 'Limits', [10 Inf], 'RoundFractionalValues', 'on');

fitButton = uibutton(cg, 'Text', 'Fit', 'ButtonPushedFcn', @(~, ~) runFit());

saveFitButton = uibutton(cg, 'Text', 'Save Fit', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) saveFit());

% Result log (this module's own, independent of every other module): count + export.
logGrid = uigridlayout(cg, [1 2]);
logGrid.Layout.Row = 9;
logGrid.Layout.Column = [1 2];
logGrid.ColumnWidth = {'1x', 'fit'};
logGrid.Padding = [0 0 0 0];
fitLogCountLabel = uilabel(logGrid, 'Text', '0 results logged');
defaultCsvName = [strrep(logKey, ' ', '_') '_results.csv'];
uibutton(logGrid, 'Text', 'Export CSV...', 'ButtonPushedFcn', @(~, ~) app.exportResultLog(logKey, defaultCsvName));
app.registerResultLogCountLabel(logKey, fitLogCountLabel);

if ~isempty(resultLogNote)
    noteLabel = uilabel(cg, 'Text', resultLogNote, 'FontAngle', 'italic', ...
        'FontColor', [0.5 0.5 0.5], 'FontSize', 10, 'WordWrap', 'on');
    noteLabel.Layout.Row = 10;
    noteLabel.Layout.Column = [1 2];
end

rg = uigridlayout(resultsParent, [1 1]);
resultsLabel = uitextarea(rg, 'Value', {'No fit yet.'}, 'Editable', 'off');

updateEquationDisplay();

fitUI = struct('fitTypeDropdown', fitTypeDropdown, 'b0Field', b0Field, 'd0Field', d0Field, ...
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

    function updateEquationDisplay()
        isDouble = fitTypeDropdown.Value == 2;
        if isDouble
            eqLabel.Text = 'y = a*(1-exp(-b*(x+f))) + (1-a)*(1-exp(-d*(x+f)))';
        else
            eqLabel.Text = 'y = 1-exp(-b*(x+f))   [a = 1, fixed]';
        end
        d0Label.Visible = isDouble;
        d0Field.Visible = isDouble;
    end

    function runFit()
        [X, Y, n, rawData, molIDs] = dataFcn();
        if isempty(X) || isempty(Y)
            uialert(app.UIFigure, 'No data to fit.', 'Fit failed');
            return;
        end

        order = fitTypeDropdown.Value;
        opts = struct('b0', b0Field.Value, 'd0', d0Field.Value, 'robust', robustCheckbox.Value);

        try
            result = pipeline.fitExponential(X, Y, order, opts);
        catch ME
            uialert(app.UIFigure, ME.message, 'Fit failed');
            return;
        end

        delete(findobj(ax, 'Tag', 'pipelineFitCurve'));
        xx = linspace(min(X), max(X), 400);
        yy = result.fitobject(xx);
        hold(ax, 'on');
        plot(ax, xx, yy, 'k-', 'LineWidth', 2, 'Tag', 'pipelineFitCurve');
        hold(ax, 'off');

        % On-plot rate label: the results text panel isn't part of the
        % exported plot (see pipeline.exportPlot / +modules/summaryFigure.m,
        % which reconstruct/copy only the axes' own content), so the fitted
        % rate(s) need to live on the axes itself to survive into an export.
        % Only the FIT's own CI is known at this point -- saveFit() below
        % re-places this same label once the bootstrap CI is also
        % available. Placed in whichever corner currently has the least
        % data -- see pipeline.placeFitLabel.
        pipeline.placeFitLabel(ax, 'pipelineFitCurve', buildRateLines(result));

        setResultsText(resultsLabel, formatResultsText(result));

        lastFitResult = result;
        lastFitN = n;
        lastFitMeta = metaFcn();
        lastRawData = rawData;
        lastMolIDs = molIDs;
        saveFitButton.Enable = 'on';
    end

    function saveFit()
        if isempty(lastFitResult)
            return;
        end

        % Disable both buttons for the duration so a bootstrap can't be
        % triggered again (or a trial Fit run) while one is already in
        % flight; guaranteed to re-enable on any exit path, error included.
        fitButton.Enable = 'off';
        saveFitButton.Enable = 'off';
        reenable = onCleanup(@() setButtonsEnabled(fitButton, saveFitButton));

        nBoot = bootNField.Value;
        setResultsText(resultsLabel, sprintf('Bootstrapping rate CI (0/%d)...', nBoot));
        drawnow;

        pointD = [];
        if lastFitResult.order == 2
            pointD = lastFitResult.coeffValues.d;
        end

        try
            boot = pipeline.bootstrapRateCI(lastRawData, lastMolIDs, lastFitResult.order, lastFitResult.optsUsed, nBoot, ...
                @(frac) updateBootProgress(resultsLabel, frac, nBoot), lastFitResult.coeffValues.b, pointD);
        catch ME
            uialert(app.UIFigure, ME.message, 'Bootstrap failed');
            setResultsText(resultsLabel, formatResultsText(lastFitResult));
            return;
        end

        row = buildLogRow(lastFitMeta, lastFitN, lastFitResult, boot);
        app.appendResultLog(logKey, row);
        setResultsText(resultsLabel, sprintf('%s\n\n%s\n\n(saved to result log)', ...
            formatResultsText(lastFitResult), formatBootstrapText(lastFitResult.order, boot)));

        % Re-place the on-plot label now that the bootstrap CI (not just
        % the fit's own CI) is available -- see the matching call in
        % runFit() above.
        pipeline.placeFitLabel(ax, 'pipelineFitCurve', buildRateLines(lastFitResult, boot));
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
% uitextarea takes Value as a cell array of lines, not a single string with
% embedded newlines, so split explicitly rather than assigning txt directly.
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

function lines = buildRateLines(result, boot)
%BUILDRATELINES On-plot label lines for the fitted rate(s) (see
%pipeline.placeFitLabel): value, then the fit's own 95% CI, then --
%once available -- the molecule-level bootstrap 95% CI (pipeline.
%bootstrapRateCI). boot omitted/[] (a trial Fit, before Save Fit has run
%one) means just value + fit CI; runFit() calls this without boot, and
%saveFit() re-calls it with boot once bootstrapping completes, so the
%label grows to include the bootstrap CI without changing what's already
%shown.
c  = result.coeffValues;
ci = result.coeffCI;
hasBoot = nargin >= 2 && ~isempty(boot);

lines = {};
if result.order == 1
    lines{end+1} = sprintf('k = %.3g s^{-1}', c.b);
    lines{end+1} = sprintf('Fit 95%% CI: [%.3g, %.3g]', ci.b(1), ci.b(2));
    if hasBoot
        lines{end+1} = sprintf('Boot 95%% CI: [%.3g, %.3g]', boot.b_CI(1), boot.b_CI(2));
    end
else
    lines{end+1} = sprintf('k_1 = %.3g s^{-1}', c.b);
    lines{end+1} = sprintf('Fit 95%% CI: [%.3g, %.3g]', ci.b(1), ci.b(2));
    if hasBoot
        lines{end+1} = sprintf('Boot 95%% CI: [%.3g, %.3g]', boot.b_CI(1), boot.b_CI(2));
    end
    lines{end+1} = sprintf('k_2 = %.3g s^{-1}', c.d);
    lines{end+1} = sprintf('Fit 95%% CI: [%.3g, %.3g]', ci.d(1), ci.d(2));
    if hasBoot
        lines{end+1} = sprintf('Boot 95%% CI: [%.3g, %.3g]', boot.d_CI(1), boot.d_CI(2));
    end
end
end

function txt = formatResultsText(result)
c  = result.coeffValues;
ci = result.coeffCI;

lines = {};
if isnan(ci.a(1))
    lines{end+1} = sprintf('a = %.4g (fixed)', c.a);
else
    lines{end+1} = sprintf('a = %.4g  [%.4g, %.4g]', c.a, ci.a(1), ci.a(2));
end
lines{end+1} = sprintf('b = %.4g s^-1  [%.4g, %.4g]', c.b, ci.b(1), ci.b(2));
if result.order == 2
    lines{end+1} = sprintf('d = %.4g s^-1  [%.4g, %.4g]', c.d, ci.d(1), ci.d(2));
end
lines{end+1} = sprintf('f = %.4g  [%.4g, %.4g]', c.f, ci.f(1), ci.f(2));
lines{end+1} = sprintf('R^2 = %.4f', result.gof.rsquare);

txt = strjoin(lines, newline);
end

function txt = formatBootstrapText(order, boot)
lines = {};
lines{end+1} = sprintf('Bootstrap 95%% CI (n=%d/%d resamples, %d molecules):', ...
    boot.nSuccess, boot.nRequested, boot.nMolecules);
lines{end+1} = sprintf('b: [%.4g, %.4g]', boot.b_CI(1), boot.b_CI(2));
if order == 2
    lines{end+1} = sprintf('d: [%.4g, %.4g]', boot.d_CI(1), boot.d_CI(2));
end
txt = strjoin(lines, newline);
end

function row = buildLogRow(meta, n, result, boot)
%BUILDLOGROW One result-log row per saved fit. Column naming convention
% (shared with pipeline.buildGaussianFitControls, and with
% +modules/eventSorting.m's summary export): a value column named after
% what it is, immediately followed by "<Name>_FitCI" (the fit's own
% confidence interval, straight from coeffCI) and, where a bootstrap was
% run, "<Name>_BootstrapCI" (the molecule-level cluster-bootstrap interval)
% — each CI is ONE column holding a formatted "[lower, upper]" string
% (pipeline.formatCI) rather than separate Lower/Upper columns.
c  = result.coeffValues;
ci = result.coeffCI;

if result.order == 1
    fitTypeStr = 'Single exponential';
    rate2 = NaN; rate2FitLo = NaN; rate2FitHi = NaN;
    rate2BootLo = NaN; rate2BootHi = NaN;
else
    fitTypeStr = 'Double exponential';
    rate2 = c.d; rate2FitLo = ci.d(1); rate2FitHi = ci.d(2);
    rate2BootLo = boot.d_CI(1); rate2BootHi = boot.d_CI(2);
end

row = struct();
row.Module              = string(meta.Module);
row.Dataset              = string(meta.Dataset);
row.EventFilter          = string(meta.EventFilter);
row.FitType              = string(fitTypeStr);
row.NEvents              = n;
row.NMolecules           = boot.nMolecules;
row.NBootstrap           = boot.nSuccess;
row.Fraction_Rate1       = c.a;
row.Fraction_Rate1_FitCI = pipeline.formatCI(ci.a(1), ci.a(2));
row.Rate1_perSec         = c.b;
row.Rate1_perSec_FitCI       = pipeline.formatCI(ci.b(1), ci.b(2));
row.Rate1_perSec_BootstrapCI = pipeline.formatCI(boot.b_CI(1), boot.b_CI(2));
row.Rate2_perSec         = rate2;
row.Rate2_perSec_FitCI       = pipeline.formatCI(rate2FitLo, rate2FitHi);
row.Rate2_perSec_BootstrapCI = pipeline.formatCI(rate2BootLo, rate2BootHi);
row.TimeOffset_sec       = c.f;
row.TimeOffset_sec_FitCI = pipeline.formatCI(ci.f(1), ci.f(2));
row.R2                   = result.gof.rsquare;
end
