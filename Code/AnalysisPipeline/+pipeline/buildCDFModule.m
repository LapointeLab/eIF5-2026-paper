function buildCDFModule(app, moduleName, typeItems, typeItemsData, defaultTypeValue, xLabelText, computeDataFcn, extraControlsFcn, resultLogNote)
%BUILDCDFMODULE Shared scaffold for a "channel + type -> eCDF + exponential fit" module.
%   buildCDFModule(app, moduleName, typeItems, typeItemsData, defaultTypeValue, xLabelText, computeDataFcn, extraControlsFcn, resultLogNote)
%
%   app               : AnalysisPipelineApp instance.
%   moduleName        : tab title, and the fit-log "Module" identifier for
%                        every fit saved from this module (e.g.
%                        'Binding Lifetime Kinetics', 'Association Kinetics').
%   typeItems         : cell array of display strings for the "Type"
%                        dropdown (e.g. {'All events','First event','Subsequent events'}).
%   typeItemsData     : cell array of matching values, same length as
%                        typeItems, passed to computeDataFcn as typeValue.
%   defaultTypeValue  : which typeItemsData entry is selected by default.
%   xLabelText        : x-axis label for the plot, e.g. 'Lifetime (s)'.
%   computeDataFcn    : function handle, (app, channelName, typeValue) ->
%                        [rawTimes, molIDs] — the UNQUANTIZED per-event time
%                        values to analyze and the molecule each one belongs
%                        to (same length and order as rawTimes). This
%                        scaffold handles quantization, the eCDF, plotting,
%                        export, and the fit UI; computeDataFcn only answers
%                        "which numbers, from which molecules".
%   extraControlsFcn  : optional function handle, (ctrl, onDataChanged) -> [].
%                        Lets a module add its own controls (e.g. a
%                        threshold field) into the same ctrl row, appended
%                        after the built-in ones. Any control that changes
%                        what computeDataFcn would return must call
%                        onDataChanged() from its ValueChangedFcn — a handle
%                        to a full re-run (equivalent to a Channel/Type
%                        change: resets any in-progress fit) — the same way
%                        computeDataFcn itself is expected to read that
%                        control's current value via a shared closure
%                        variable (see +modules/fretStateLifetime.m).
%   resultLogNote     : optional; forwarded to pipeline.buildFitControls
%                        (see that file) -- a small note shown under
%                        Export CSV when this module's own Type dropdown
%                        can log more than one kind of row into one shared
%                        table (e.g. +modules/fretStateLifetime.m's Low/
%                        High FRET state).
%
%   Shared by every module built on "channel + type -> exponential CDF fit"
%   (see +modules/bindingLifetimeKinetics.m, +modules/associationKinetics.m),
%   so layout, plot styling, export, and fitting stay identical across
%   modules and a fix here benefits all of them.

if nargin < 9
    resultLogNote = '';
end
if nargin < 8
    extraControlsFcn = [];
end

if isempty(app.Data) || ~isfield(app.Data, 'result')
    uialert(app.UIFigure, 'Load a state-assignment file first.', 'No data loaded');
    return;
end

if isempty(app.Data.result.channelNames)
    uialert(app.UIFigure, 'No channels with detected binding states were found in this file.', 'No usable channels');
    return;
end

tab = app.getOrCreateTab(moduleName);

layout = uigridlayout(tab, [2 1]);
layout.RowHeight = {50, '1x'};

% Plot top-left; right sidebar holds fit controls, bottom strip holds fit results.
contentGrid = uigridlayout(layout, [2 2]);
contentGrid.Layout.Row = 2;
contentGrid.RowHeight = {'1x', 140};
contentGrid.ColumnWidth = {'1x', 240};
contentGrid.RowSpacing = 8;
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [0 0 0 0];

ax = uiaxes(contentGrid);
ax.Layout.Row = 1;
ax.Layout.Column = 1;

rightPanel = uipanel(contentGrid, 'Title', 'Outputs');
rightPanel.Layout.Row = [1 2];
rightPanel.Layout.Column = 2;

bottomPanel = uipanel(contentGrid, 'Title', 'Kinetics');
bottomPanel.Layout.Row = 2;
bottomPanel.Layout.Column = 1;

hasExtraControls = ~isempty(extraControlsFcn);
baseColumnWidth = {70, 150, 60, 170, 60, 100, 120};
if hasExtraControls
    ctrl = uigridlayout(layout, [1 9]);
    ctrl.ColumnWidth = [baseColumnWidth, {'fit', 'fit'}];
else
    ctrl = uigridlayout(layout, [1 7]);
    ctrl.ColumnWidth = baseColumnWidth;
end
ctrl.Layout.Row = 1;
ctrl.Padding = [0 0 0 0];

uilabel(ctrl, 'Text', 'Channel:');
chDropdown = uidropdown(ctrl, 'Items', app.Data.result.channelNames, ...
    'ValueChangedFcn', @(~, ~) runAnalysis(true));

uilabel(ctrl, 'Text', 'Type:');
typeDropdown = uidropdown(ctrl, 'Items', typeItems, 'ItemsData', typeItemsData, ...
    'Value', defaultTypeValue, 'ValueChangedFcn', @(~, ~) runAnalysis(true));

uilabel(ctrl, 'Text', 'X-axis:');
xScaleSwitch = uiswitch(ctrl, 'slider', ...
    'Items', {'Linear', 'Log'}, ...
    'Value', 'Linear', ...
    'ValueChangedFcn', @(~, ~) runAnalysis(false));

pipeline.addExportPlotButton(ctrl, ax, moduleName, @suggestedPlotName);

if hasExtraControls
    extraControlsFcn(ctrl, @() runAnalysis(true));
end

% Live current-dataset state, updated by runAnalysis and read by the fit
% controls / export button at the moment they're used (must be nested
% functions, not anonymous closures, so they see current values rather than
% a stale snapshot).
lastX = [];
lastP = [];
lastN = 0;
lastRaw = [];
lastMol = [];
lastChName = '';
lastTypeLabel = '';
resetFitUI = [];   % assigned once buildFitControls returns; see runAnalysis

runAnalysis(true);
fitUI = pipeline.buildFitControls(rightPanel, bottomPanel, ax, app, moduleName, @currentFitData, @currentFitMeta, resultLogNote);
resetFitUI = fitUI.reset;

    function runAnalysis(dataChanged)
        % dataChanged: true when the channel/type selection changed (the
        % underlying data is different, so any trial/saved-but-uncommitted
        % fit is now stale and Save Fit must be disabled); false for a
        % purely cosmetic change (X-axis scale) that doesn't affect what
        % Save Fit would log, so an existing fit stays valid and usable.
        if dataChanged && ~isempty(resetFitUI)
            resetFitUI();
        end

        chName    = chDropdown.Value;
        typeValue = typeDropdown.Value;
        typeLabel = typeDropdown.Items{strcmp(typeDropdown.ItemsData, typeValue)};

        [rawTimes, molIDs] = computeDataFcn(app, chName, typeValue);

        cla(ax);
        pipeline.applyAxesStyle(ax);
        axis(ax, 'square');
        ax.XScale = lower(xScaleSwitch.Value);

        lastChName = chName;
        lastTypeLabel = typeLabel;

        if isempty(rawTimes)
            title(ax, sprintf('%s - %s: no data', chName, typeLabel));
            lastX = []; lastP = []; lastN = 0; lastRaw = []; lastMol = [];
            return;
        end

        % Quantize onto the frame grid: the recorded timestamp vector accumulates
        % ~1e-15-scale floating-point noise across frames, which otherwise makes
        % cdfcalc treat identical durations/times as distinct x-values.
        quantized = pipeline.quantizeToExposure(rawTimes, app.Data.result.Exposure);
        [P, X] = cdfcalc(quantized);
        P(1) = [];
        pipeline.plotCDFMarkers(ax, X, P);
        xlabel(ax, xLabelText);
        ylabel(ax, 'Cumulative fraction');
        ylim(ax, [0, 1]);
        title(ax, sprintf('%s - %s CDF (n = %d)', chName, typeLabel, numel(quantized)));

        lastX = X;
        lastP = P;
        lastN = numel(quantized);
        lastRaw = quantized;
        lastMol = molIDs;
    end

    function [X, Y, n, rawData, molIDs] = currentFitData()
        X = lastX;
        Y = lastP;
        n = lastN;
        rawData = lastRaw;
        molIDs = lastMol;
    end

    function meta = currentFitMeta()
        meta = struct('Module', moduleName, 'Dataset', lastChName, 'EventFilter', lastTypeLabel);
    end

    function name = suggestedPlotName()
        name = sprintf('%s_%s_%s', strrep(moduleName, ' ', ''), lastChName, strrep(lastTypeLabel, ' ', ''));
    end
end
