function fretEfficiencyDistribution(app)
%FRETEFFICIENCYDISTRIBUTION Plot a normalized FRET efficiency histogram for a
%chosen channel, fit with a sum of 1-4 Gaussians.
%   Module function: takes the AnalysisPipelineApp instance. Requires
%   app.Data.result (see +pipeline/extractEvents.m) and the Statistics and
%   Machine Learning Toolbox.
%
%   FRET efficiency values are pooled only from frames during a binding
%   event on the selected channel (consistent with the original analysis
%   this pipeline replaces — FRET efficiency is only physically meaningful
%   while the labeled species is actually bound). The event set contributing
%   frames can be restricted to All events / First event / Subsequent
%   events per molecule via pipeline.filterEventsByType, same as the other
%   modules.
%
%   Histogram: 50 bins spanning [0, 1], height normalized by the number of
%   in-range points so the shape is comparable across experiments with
%   different total frame/event counts, independent of bin width (bin
%   heights sum to 1, this is not a probability density). Plotted as open
%   circles (pipeline.plotCDFMarkers), matching the other modules' style.
%
%   Fitting: pipeline.fitGaussianMixture / pipeline.bootstrapGaussianCI via
%   pipeline.buildGaussianFitControls, the histogram/Gaussian-mixture
%   counterpart of pipeline.buildFitControls used by the eCDF modules.

MODULE_NAME = 'FRET Efficiency Distribution';
NBINS = 50;
EDGES = linspace(0, 1, NBINS + 1);

if isempty(app.Data) || ~isfield(app.Data, 'result')
    uialert(app.UIFigure, 'Load a state-assignment file first.', 'No data loaded');
    return;
end

if isempty(app.Data.result.channelNames)
    uialert(app.UIFigure, 'No channels with detected binding states were found in this file.', 'No usable channels');
    return;
end

tab = app.getOrCreateTab(MODULE_NAME);

layout = uigridlayout(tab, [2 1]);
layout.RowHeight = {50, '1x'};

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

ctrl = uigridlayout(layout, [1 5]);
ctrl.Layout.Row = 1;
ctrl.ColumnWidth = {70, 150, 60, 170, 120};
ctrl.Padding = [0 0 0 0];

uilabel(ctrl, 'Text', 'Channel:');
chDropdown = uidropdown(ctrl, 'Items', app.Data.result.channelNames, ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(ctrl, 'Text', 'Events:');
eventTypeDropdown = uidropdown(ctrl, ...
    'Items', {'All events', 'First event', 'Subsequent events'}, ...
    'ItemsData', {'all', 'first', 'subsequent'}, ...
    'Value', 'all', ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

pipeline.addExportPlotButton(ctrl, ax, MODULE_NAME, @suggestedPlotName);

% Live current-dataset state, updated by runAnalysis and read by the fit
% controls / export button at the moment they're used (must be nested
% functions, not anonymous closures, so they see current values rather than
% a stale snapshot).
lastX = [];
lastY = [];
lastN = 0;
lastNEvents = 0;
lastRaw = [];
lastMol = [];
lastChName = '';
lastTypeLabel = '';
resetFitUI = [];   % assigned once buildGaussianFitControls returns; see runAnalysis

runAnalysis();
fitUI = pipeline.buildGaussianFitControls(rightPanel, bottomPanel, ax, app, MODULE_NAME, @currentFitData, @currentFitMeta);
resetFitUI = fitUI.reset;

    function runAnalysis()
        % Every control in this module (Channel, Events) changes the
        % underlying data, so any trial/saved-but-uncommitted fit is always
        % stale here and Save Fit must be disabled — unlike buildCDFModule,
        % there's no purely-cosmetic trigger (no X-axis toggle) to exempt.
        if ~isempty(resetFitUI)
            resetFitUI();
        end

        chName    = chDropdown.Value;
        typeValue = eventTypeDropdown.Value;
        typeLabel = eventTypeDropdown.Items{strcmp(eventTypeDropdown.ItemsData, typeValue)};

        [rawValues, molIDs, nEvents] = computeFRETValues(app, chName, typeValue);

        cla(ax);
        pipeline.applyAxesStyle(ax);
        axis(ax, 'square');

        lastChName = chName;
        lastTypeLabel = typeLabel;
        lastNEvents = nEvents;

        if isempty(rawValues)
            title(ax, sprintf('%s - %s: no data', chName, typeLabel));
            lastX = []; lastY = []; lastN = 0; lastRaw = []; lastMol = [];
            return;
        end

        counts  = histcounts(rawValues, EDGES);
        inRange = sum(counts);
        Y = counts / inRange;
        X = (EDGES(1:end-1) + EDGES(2:end)) / 2;

        pipeline.plotCDFMarkers(ax, X, Y);
        xlabel(ax, 'FRET Efficiency');
        ylabel(ax, 'Normalized frequency');
        title(ax, sprintf('%s - %s (n = %d frames)', chName, typeLabel, inRange));

        lastX = X;
        lastY = Y;
        lastN = inRange;
        lastRaw = rawValues;
        lastMol = molIDs;
    end

    function [X, Y, n, rawData, molIDs, edges] = currentFitData()
        X = lastX;
        Y = lastY;
        n = lastN;
        rawData = lastRaw;
        molIDs = lastMol;
        edges = EDGES;
    end

    function meta = currentFitMeta()
        meta = struct('Module', MODULE_NAME, 'Dataset', lastChName, 'EventFilter', lastTypeLabel, ...
            'NEvents', lastNEvents);
    end

    function name = suggestedPlotName()
        name = sprintf('FRETEfficiency_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
    end
end

function [rawValues, molIDs, nEvents] = computeFRETValues(app, chName, typeValue)
% Pull FRET efficiency values from ttotal during ON frames only, for the
% events selected by typeValue. chName's column position must be resolved
% against the ORIGINAL (unfiltered) channel list, since app.Data.result
% may have dropped channels with no state data (see pipeline.extractEvents),
% but ttotal's column layout still follows the original channel order.
origIdx   = find(strcmp(app.Data.channelNames, chName), 1);
nChPerMol = app.Data.nChPerMol;
ttotal    = app.Data.ttotal;

chIdx     = find(strcmp(app.Data.result.channelNames, chName), 1);
evListAll = app.Data.result.events{chIdx};
evList    = pipeline.filterEventsByType(evListAll, typeValue);
nEvents   = numel(evList);

rawValues = [];
molIDs    = [];
for i = 1:numel(evList)
    mol   = evList(i).mol;
    col   = origIdx + 1 + (mol - 1) * nChPerMol;
    vals  = ttotal(evList(i).onFrame:evList(i).offFrame, col)';
    rawValues = [rawValues, vals]; %#ok<AGROW>
    molIDs    = [molIDs, repmat(mol, 1, numel(vals))]; %#ok<AGROW>
end
end
