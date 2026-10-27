function lifetimeSorting(app)
%LIFETIMESORTING Sort binding events by lifetime into short-/long-lived
%groups, and compare FRET efficiency distributions between them on one
%shared plot.
%   Module function: takes the AnalysisPipelineApp instance. Adapted from
%   ExampleCode/LL_TIRF_BinTracesByLongEvent_v1.m (lifetime-based binning +
%   saved group files). Sibling module +modules/eventSorting.m covers the
%   opposite direction (sort by mean FRET, compare lifetime via a
%   points+bootstrap-CI plot).
%
%   Two user-adjustable bounds (seconds) split each channel's events into
%   Short/Middle (excluded)/Long lifetime groups -- setting both bounds
%   equal collapses this to a clean two-way split. For EACH group, every
%   FRAME during a qualifying event contributes its FRET efficiency value
%   (same "only while actually bound" pooling as
%   +modules/fretEfficiencyDistribution.m), plotted as its own normalized
%   50-bin histogram (dark blue circles for Short, dark orange for Long) on
%   ONE SHARED axes, so the two distributions are directly comparable.
%   Independent 1-4-component Gaussian-mixture fit controls
%   (pipeline.buildGaussianFitControls) let Short and Long each be fit
%   separately -- Fit draws that group's curve, colored to match its
%   markers, on the SAME shared axes (a distinct Tag per instance keeps
%   the two fit curves from deleting each other; see
%   pipeline.buildGaussianFitControls) -- and logged to this module's own
%   result log, shared between Short and Long (distinguished by the Group
%   column) but independent of every other module's log. Short's and Long's
%   controls live in their own
%   sub-tab rather than a shared panel, so whichever is active gets the
%   full generous space fretEfficiencyDistribution.m's own single Outputs
%   panel uses -- picking more Gaussian components reveals more "Mean N
%   guess:" rows, and a fixed-size shared panel couldn't reliably fit both
%   groups' controls at once without the extra rows pushing the Fit/Save
%   Fit buttons out of view.
%
%   A trace-level view mirrors +modules/eventSorting.m's: a molecule
%   "qualifies" for a group if any of its events falls in that group.
%   Molecules qualifying for exactly one group (not both, not neither) can
%   be saved as two separate .mat files via "Save Binned Groups...", in the
%   same ttotal/states format pipeline.loadDataFromFile expects (plus
%   channelNames/nChPerMol) -- the direct generalization of
%   LL_TIRF_BinTracesByLongEvent_v1's own long/short group .mat save.

NBINS = 50;
EDGES = linspace(0, 1, NBINS + 1);
DARK_BLUE   = [0.00 0.20 0.60];
DARK_ORANGE = [0.80 0.40 0.00];

if isempty(app.Data) || ~isfield(app.Data, 'result')
    uialert(app.UIFigure, 'Load a state-assignment file first.', 'No data loaded');
    return;
end

if isempty(app.Data.result.channelNames)
    uialert(app.UIFigure, 'No channels with detected binding states were found in this file.', 'No usable channels');
    return;
end

tab = app.getOrCreateTab('Event Sorting by Lifetime');

% Header row is ~10% taller than a bare-minimum fit (126 vs 60px), giving
% the Channel/Events/bound controls some breathing room -- the plot/fit-
% tabs/Statistics row below ('1x') absorbs that space automatically, i.e.
% shrinks by the same ~10% it would otherwise have gotten.
layout = uigridlayout(tab, [2 1]);
layout.RowHeight = {126, '1x'};

% Two control rows (Channel/Events/Export on top, Short/Long bound below)
% share layout's first row via a nested [2 1] grid.
mainCtrl = uigridlayout(layout, [2 1]);
mainCtrl.Layout.Row = 1;
mainCtrl.RowHeight = {63, 63};
mainCtrl.Padding = [0 0 0 0];

ctrl = uigridlayout(mainCtrl, [1 5]);
ctrl.Layout.Row = 1;
ctrl.ColumnWidth = {70, 150, 60, 170, 170};
ctrl.Padding = [0 0 0 0];

uilabel(ctrl, 'Text', 'Channel:');
chDropdown = uidropdown(ctrl, 'Items', app.Data.result.channelNames, ...
    'ValueChangedFcn', @(~, ~) onChannelChanged());

uilabel(ctrl, 'Text', 'Events:');
eventTypeDropdown = uidropdown(ctrl, ...
    'Items', {'All events', 'First event', 'Subsequent events'}, ...
    'ItemsData', {'all', 'first', 'subsequent'}, ...
    'Value', 'all', ...
    'ValueChangedFcn', @(~, ~) recompute());

uibutton(ctrl, 'Text', 'Export Plot...', 'ButtonPushedFcn', @(~, ~) exportPlotButton());

boundCtrl = uigridlayout(mainCtrl, [1 4]);
boundCtrl.Layout.Row = 2;
boundCtrl.ColumnWidth = {110, 100, 110, 100};
boundCtrl.Padding = [0 0 0 0];

uilabel(boundCtrl, 'Text', 'Short bound (≤, s):');
shortBoundField = uieditfield(boundCtrl, 'numeric', 'Value', 0.2, 'ValueChangedFcn', @(~, ~) recompute());

uilabel(boundCtrl, 'Text', 'Long bound (≥, s):');
longBoundField = uieditfield(boundCtrl, 'numeric', 'Value', 0.6, 'ValueChangedFcn', @(~, ~) recompute());

% Square plot (axis(ax,'square'), matching fretEfficiencyDistribution.m)
% doesn't need the full tab width, so it gets a fixed column sized to a
% comfortable square rather than stretching across everything -- the width
% that frees up goes to Short/Long's fit controls and Statistics.
%
% Short and Long each sit in their OWN sub-tab (not stacked/side-by-side
% panels) so whichever is active gets the FULL available height -- the
% same generous space fretEfficiencyDistribution.m's own single Outputs
% panel uses. Picking more Gaussian components reveals more "Mean N
% guess:" rows and can need more vertical room than a fixed-height half- or
% third-height panel provides; a uipanel's Scrollable option can't rescue
% that, since a uigridlayout child always reports itself as exactly
% matching its parent's size (even while ITS OWN children silently
% overflow), so Scrollable never has anything to detect -- this sidesteps
% the problem entirely by not needing to fit two panels' worth of controls
% into the screen at once. The shared plot below keeps showing both
% groups' fits regardless of which tab is active, since that only depends
% on the plot's own axes, not on which control panel is visible.
mainGrid = uigridlayout(layout, [1 3]);
mainGrid.Layout.Row = 2;
mainGrid.ColumnWidth = {420, '1x', 260};
mainGrid.ColumnSpacing = 8;
mainGrid.Padding = [0 0 0 0];

plotPanel = uipanel(mainGrid, 'Title', 'FRET Efficiency Distribution: Short vs Long');
plotGrid = uigridlayout(plotPanel, [1 1]);
plotGrid.Padding = [4 4 4 4];
ax = uiaxes(plotGrid);

fitTabGroup = uitabgroup(mainGrid);
shortTab = uitab(fitTabGroup, 'Title', 'Short Binding Events');
longTab  = uitab(fitTabGroup, 'Title', 'Long Binding Events');

[shortOutputsPanel, shortKineticsPanel] = buildFitControlPanel(shortTab);
[longOutputsPanel, longKineticsPanel] = buildFitControlPanel(longTab);

sidePanel = uigridlayout(mainGrid, [2 1]);
sidePanel.RowHeight = {'1x', 'fit'};
sidePanel.Padding = [0 0 0 0];

statsPanel = uipanel(sidePanel, 'Title', 'Statistics');
statsGrid = uigridlayout(statsPanel, [1 1]);
statsGrid.Padding = [4 4 4 4];
statsArea = uitextarea(statsGrid, 'Value', {'No results yet.'}, 'Editable', 'off');

saveBinnedButton = uibutton(sidePanel, 'Text', 'Save Binned Groups...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) saveBinnedGroups());

% Live current-dataset state, read by the Gaussian-fit UIs' data/meta
% functions and by Save Binned Groups at the moment they're used.
lastChName    = '';
lastTypeLabel = '';
shortX = []; shortY = []; shortN = 0; shortRaw = []; shortMolIDs = [];
longX = []; longY = []; longN = 0; longRaw = []; longMolIDs = [];
lastShortNEvents = 0;
lastLongNEvents  = 0;
lastLongOnlyMols  = [];
lastShortOnlyMols = [];
shortResetFitUI = [];
longResetFitUI  = [];

recompute();
% Short and Long share one logKey/result log deliberately -- both panels
% fit the SAME module's data, just split by lifetime group, so their saved
% fits belong together in one CSV (distinguished by the Group column that
% currentFitMetaShort/Long set), not two separate files.
resultLogKey = 'Event Sorting by Lifetime';
shortFitUI = pipeline.buildGaussianFitControls(shortOutputsPanel, shortKineticsPanel, ax, app, resultLogKey, ...
    @currentFitDataShort, @currentFitMetaShort, DARK_BLUE, 'shortFitCurve');
longFitUI  = pipeline.buildGaussianFitControls(longOutputsPanel, longKineticsPanel, ax, app, resultLogKey, ...
    @currentFitDataLong, @currentFitMetaLong, DARK_ORANGE, 'longFitCurve');
shortResetFitUI = shortFitUI.reset;
longResetFitUI  = longFitUI.reset;

    function onChannelChanged()
        autoSuggestBounds();
        recompute();
    end

    function autoSuggestBounds()
        % Reset Short/Long to the tertile split of the new channel's own
        % event lifetimes -- a sensible starting point regardless of
        % dataset timescale. Left alone on any other control change so a
        % user's own edits aren't silently clobbered.
        chName = chDropdown.Value;
        chIdx  = find(strcmp(app.Data.result.channelNames, chName), 1);
        evList = pipeline.filterEventsByType(app.Data.result.events{chIdx}, eventTypeDropdown.Value);
        if isempty(evList)
            return;
        end
        vals = [evList.lifetime];
        shortBoundField.Value = prctile(vals, 33);
        longBoundField.Value  = prctile(vals, 67);
    end

    function recompute()
        if ~isempty(shortResetFitUI)
            shortResetFitUI();
        end
        if ~isempty(longResetFitUI)
            longResetFitUI();
        end

        chName    = chDropdown.Value;
        typeValue = eventTypeDropdown.Value;
        typeLabel = eventTypeDropdown.Items{strcmp(eventTypeDropdown.ItemsData, typeValue)};

        chIdx     = find(strcmp(app.Data.result.channelNames, chName), 1);
        evListAll = app.Data.result.events{chIdx};
        evList    = pipeline.filterEventsByType(evListAll, typeValue);

        lastChName    = chName;
        lastTypeLabel = typeLabel;

        cla(ax);
        if isempty(evList)
            title(ax, 'no data');
            statsArea.Value = {'No events.'};
            saveBinnedButton.Enable = 'off';
            shortX = []; shortY = []; shortN = 0; shortRaw = []; shortMolIDs = [];
            longX = []; longY = []; longN = 0; longRaw = []; longMolIDs = [];
            lastShortNEvents = 0;
            lastLongNEvents  = 0;
            return;
        end

        lifetimeVals = [evList.lifetime]';
        molIDs       = [evList.mol]';

        shortB = min(shortBoundField.Value, longBoundField.Value);
        longB  = max(shortBoundField.Value, longBoundField.Value);

        isShort = lifetimeVals <= shortB;
        isLong  = lifetimeVals >= longB;
        lastShortNEvents = nnz(isShort);
        lastLongNEvents  = nnz(isLong);
        isMid   = ~isShort & ~isLong;

        [shortRaw, shortMolIDs] = pooledFRETValues(app, chName, evList(isShort));
        [longRaw, longMolIDs]   = pooledFRETValues(app, chName, evList(isLong));

        pipeline.applyAxesStyle(ax);
        axis(ax, 'square');
        hold(ax, 'on');
        legHandles = gobjects(0);
        legLabels  = {};
        if ~isempty(shortRaw)
            [shortX, shortY, shortN] = normalizedHistogram(shortRaw, EDGES);
            h = pipeline.plotCDFMarkers(ax, shortX, shortY, DARK_BLUE);
            legHandles(end + 1) = h; legLabels{end + 1} = sprintf('Short (n=%d)', nnz(isShort));
        else
            shortX = []; shortY = []; shortN = 0;
        end
        if ~isempty(longRaw)
            [longX, longY, longN] = normalizedHistogram(longRaw, EDGES);
            h = pipeline.plotCDFMarkers(ax, longX, longY, DARK_ORANGE);
            legHandles(end + 1) = h; legLabels{end + 1} = sprintf('Long (n=%d)', nnz(isLong));
        else
            longX = []; longY = []; longN = 0;
        end
        hold(ax, 'off');
        if ~isempty(legHandles)
            legend(ax, legHandles, legLabels, 'Location', 'best', 'Box', 'off');
        end
        xlabel(ax, 'FRET Efficiency');
        ylabel(ax, 'Normalized frequency');
        title(ax, sprintf('%s - %s', chName, typeLabel));

        % --- Trace-level binning (same Short/Long group definitions, at the molecule level) ---
        uniqueMols = unique(molIDs);
        hasLong  = false(size(uniqueMols));
        hasShort = false(size(uniqueMols));
        for im = 1:numel(uniqueMols)
            idx = (molIDs == uniqueMols(im));
            hasLong(im)  = any(isLong(idx));
            hasShort(im) = any(isShort(idx));
        end
        longOnlyMask  = hasLong & ~hasShort;
        shortOnlyMask = hasShort & ~hasLong;
        bothMask      = hasLong & hasShort;
        neitherMask   = ~hasLong & ~hasShort;

        longOnlyMols  = uniqueMols(longOnlyMask);
        shortOnlyMols = uniqueMols(shortOnlyMask);

        statsArea.Value = { ...
            '=== Event-level ===' ...
            sprintf('Total events: %d  (molecules: %d)', numel(evList), numel(uniqueMols)) ...
            sprintf('Sort factor: Lifetime (s)   bounds: [%.4g, %.4g]', shortB, longB) ...
            sprintf('  Short (<= %.4g s): %d events, %d frames', shortB, nnz(isShort), shortN) ...
            sprintf('  Mid   (excluded): %d events', nnz(isMid)) ...
            sprintf('  Long  (>= %.4g s): %d events, %d frames', longB, nnz(isLong), longN) ...
            '' ...
            '=== Trace-level (molecules qualifying for a group) ===' ...
            'A molecule "qualifies" for Long/Short if any of its events falls in that group.' ...
            sprintf('Long-only:  %d molecules', nnz(longOnlyMask)) ...
            pipeline.traceGroupSummary('  ', longOnlyMols, molIDs, lifetimeVals) ...
            sprintf('Short-only: %d molecules', nnz(shortOnlyMask)) ...
            pipeline.traceGroupSummary('  ', shortOnlyMols, molIDs, lifetimeVals) ...
            sprintf('Both (qualify for Long and Short): %d molecules', nnz(bothMask)) ...
            sprintf('Neither (all events in excluded middle): %d molecules', nnz(neitherMask)) ...
            '' ...
            '"Save Binned Groups..." saves the full traces of Long-only and' ...
            'Short-only molecules as two separate .mat files (mutually' ...
            'exclusive by construction); Both/Neither molecules are not' ...
            'included in either file.' ...
        };

        lastLongOnlyMols  = longOnlyMols;
        lastShortOnlyMols = shortOnlyMols;
        saveBinnedButton.Enable = (~isempty(longOnlyMols) || ~isempty(shortOnlyMols));
    end

    function [X, Y, n, rawData, molIDs, edges] = currentFitDataShort()
        X = shortX; Y = shortY; n = shortN; rawData = shortRaw; molIDs = shortMolIDs; edges = EDGES;
    end

    function meta = currentFitMetaShort()
        meta = struct('Module', 'Event Sorting by Lifetime', 'Dataset', lastChName, ...
            'EventFilter', lastTypeLabel, 'Group', 'Short', 'NEvents', lastShortNEvents);
    end

    function [X, Y, n, rawData, molIDs, edges] = currentFitDataLong()
        X = longX; Y = longY; n = longN; rawData = longRaw; molIDs = longMolIDs; edges = EDGES;
    end

    function meta = currentFitMetaLong()
        meta = struct('Module', 'Event Sorting by Lifetime', 'Dataset', lastChName, ...
            'EventFilter', lastTypeLabel, 'Group', 'Long', 'NEvents', lastLongNEvents);
    end

    function name = suggestedPlotName()
        name = sprintf('EventSortingByLifetime_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
    end

    function exportPlotButton()
        pipeline.exportPlot(ax, 'Event Sorting by Lifetime', [], suggestedPlotName());
    end

    function saveBinnedGroups()
        if isempty(lastLongOnlyMols) && isempty(lastShortOnlyMols)
            return;
        end

        [fname, fpath] = uiputfile('*.mat', 'Save binned groups as (base name, _longGroup/_shortGroup appended)', ...
            [suggestedPlotName() '.mat']);
        if isequal(fname, 0)
            return;
        end
        [~, name, ~] = fileparts(fname);
        baseName = fullfile(fpath, name);

        nChPerMol = app.Data.nChPerMol;
        savedWhich = {};

        if ~isempty(lastLongOnlyMols)
            writeGroupMat([baseName '_longGroup.mat'], lastLongOnlyMols, nChPerMol);
            savedWhich{end + 1} = sprintf('%d long-group', numel(lastLongOnlyMols));
        end
        if ~isempty(lastShortOnlyMols)
            writeGroupMat([baseName '_shortGroup.mat'], lastShortOnlyMols, nChPerMol);
            savedWhich{end + 1} = sprintf('%d short-group', numel(lastShortOnlyMols));
        end

        uialert(app.UIFigure, sprintf('Saved %s molecule(s).', strjoin(savedWhich, ' and ')), ...
            'Saved', 'Icon', 'success');
    end

    function writeGroupMat(filePath, molIdx, nChPerMol)
        cols = [1, pipeline.getMolCols(molIdx, nChPerMol)];
        S = struct();
        S.ttotal       = app.Data.ttotal(:, cols);
        S.states       = app.Data.states(:, cols);
        S.channelNames = app.Data.channelNames;
        S.nChPerMol    = nChPerMol;
        save(filePath, '-struct', 'S');
    end
end

function [outputsPanel, kineticsPanel] = buildFitControlPanel(parent)
%BUILDFITCONTROLPANEL One group's Gaussian-fit controls+results panel
% (Kinetics gets the flexible remaining width, Outputs a fixed width),
% matching +modules/fretEfficiencyDistribution.m's own proportions -- no ax
% here, since both groups share ONE plot instead of each having their own.
% parent is expected to be a uitab (see the fitTabGroup in the main
% function) so this group gets the tab's full area, the same generous
% space fretEfficiencyDistribution.m's own single Outputs panel gets.
groupGrid = uigridlayout(parent, [1 2]);
groupGrid.ColumnWidth = {'1x', 220};
groupGrid.ColumnSpacing = 8;
groupGrid.Padding = [4 4 4 4];

kineticsPanel = uipanel(groupGrid, 'Title', 'Kinetics');
kineticsPanel.Layout.Column = 1;

outputsPanel = uipanel(groupGrid, 'Title', 'Outputs');
outputsPanel.Layout.Column = 2;
end

function [rawValues, molIDs] = pooledFRETValues(app, chName, evSubset)
%POOLEDFRETVALUES Pool FRET efficiency values from ttotal during ON frames
% of evSubset (same "only while bound" pooling as
% +modules/fretEfficiencyDistribution.m's computeFRETValues, generalized to
% take an explicit event subset instead of re-deriving one from a type
% filter).
origIdx   = find(strcmp(app.Data.channelNames, chName), 1);
nChPerMol = app.Data.nChPerMol;
ttotal    = app.Data.ttotal;

rawValues = [];
molIDs    = [];
for i = 1:numel(evSubset)
    mol  = evSubset(i).mol;
    col  = origIdx + 1 + (mol - 1) * nChPerMol;
    vals = ttotal(evSubset(i).onFrame:evSubset(i).offFrame, col)';
    rawValues = [rawValues, vals]; %#ok<AGROW>
    molIDs    = [molIDs, repmat(mol, 1, numel(vals))]; %#ok<AGROW>
end
end

function [X, Y, n] = normalizedHistogram(rawValues, edges)
%NORMALIZEDHISTOGRAM Bin-height-normalized histogram (heights sum to 1,
% not a probability density), matching
% +modules/fretEfficiencyDistribution.m's own convention.
counts = histcounts(rawValues, edges);
n      = sum(counts);
Y      = counts / n;
X      = (edges(1:end - 1) + edges(2:end)) / 2;
end
