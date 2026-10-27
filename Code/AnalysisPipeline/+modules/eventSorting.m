function eventSorting(app)
%EVENTSORTING Sort binding events by mean FRET, and compare event lifetime
%(and counting statistics) between the resulting Low/High groups.
%   Module function: takes the AnalysisPipelineApp instance. Adapted from
%   ExampleCode/LL_TIRF_MeanFRET_Lifetime_Analyzer_v1.m (event-level sort)
%   and ExampleCode/LL_TIRF_BinTracesByLongEvent_v1.m (trace-level binning
%   + saved group files), combined per user request into one module. A
%   sibling module, +modules/lifetimeSorting.m, covers the opposite
%   direction (sort by lifetime, compare FRET efficiency distributions) --
%   split out separately since that comparison is a full Gaussian-mixture
%   histogram fit, not a simple points+CI plot like this one.
%
%   Every event (see pipeline.extractEvents) gets its own mean FRET
%   (average of pipeline.extractEventSegments over the event's ON span).
%   Two user-adjustable bounds split events into Low/Middle
%   (excluded)/High groups by mean FRET -- setting both bounds equal
%   collapses this to a clean two-way split, matching the flexibility
%   requested over a fixed single- or double-threshold design. Each
%   group's LIFETIME is plotted as its individual (jittered, small, filled,
%   semi-transparent) data points plus a molecule-level cluster bootstrap
%   95% CI of the group mean (pipeline.bootstrapMeanCI, the same
%   cluster-resampling approach as pipeline.bootstrapRateCI/
%   bootstrapGaussianCI elsewhere in this app), drawn as a black
%   mean+errorbar marker layered on top of the points. Counting statistics
%   and a Wilcoxon rank-sum test (exploratory, given this module's
%   qualitative framing) are also reported.
%
%   A secondary trace-level view reuses the SAME Low/High group
%   definitions at the molecule level: a molecule "qualifies" for a group
%   if any of its events falls in that group. Molecules qualifying for
%   exactly one group (not both, not neither) can be saved as two separate
%   .mat files via "Save Binned Groups...", in the same ttotal/states
%   format pipeline.loadDataFromFile expects (plus channelNames/nChPerMol,
%   so the saved subsets can be reloaded directly into this app for
%   downstream analysis) -- a generalization of
%   LL_TIRF_BinTracesByLongEvent_v1's long/short group .mat save to this
%   module's two-bound Low/High system.

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

tab = app.getOrCreateTab('Event Sorting by Mean FRET');

layout = uigridlayout(tab, [2 1]);
layout.RowHeight = {130, '1x'};

% Three rows of controls, every child given an explicit Layout.Row/Column --
% relying on auto-flow placement previously left more children than the
% grid had declared columns, silently truncating dropdown/button text
% ("Mea...", a cut-off "Export Plot..."); explicit placement avoids that
% class of bug regardless of how many controls this row ever grows to.
ctrl = uigridlayout(layout, [3 6]);
ctrl.Layout.Row = 1;
ctrl.ColumnWidth = {150, 120, 160, 170, 100, 150};
ctrl.RowSpacing = 4;
ctrl.Padding = [0 0 0 0];

chLabel = uilabel(ctrl, 'Text', 'Channel:');
chLabel.Layout.Row = 1; chLabel.Layout.Column = 1;
chDropdown = uidropdown(ctrl, 'Items', app.Data.result.channelNames, ...
    'ValueChangedFcn', @(~, ~) onChannelChanged());
chDropdown.Layout.Row = 1; chDropdown.Layout.Column = 2;

evLabel = uilabel(ctrl, 'Text', 'Events:');
evLabel.Layout.Row = 1; evLabel.Layout.Column = 3;
eventTypeDropdown = uidropdown(ctrl, ...
    'Items', {'All events', 'First event', 'Subsequent events'}, ...
    'ItemsData', {'all', 'first', 'subsequent'}, ...
    'Value', 'all', ...
    'ValueChangedFcn', @(~, ~) recompute());
eventTypeDropdown.Layout.Row = 1; eventTypeDropdown.Layout.Column = 4;

% Bound-field labels carry the comparison direction directly (Mean FRET is
% a unitless 0-1 efficiency, so no unit suffix is needed) -- "Low bound:" /
% "High bound:" alone didn't say which way the inequality went.
lowBoundLabel = uilabel(ctrl, 'Text', 'Low bound (≤):');
lowBoundLabel.Layout.Row = 2; lowBoundLabel.Layout.Column = 1;
lowBoundField = uieditfield(ctrl, 'numeric', 'Value', 0.3, 'ValueChangedFcn', @(~, ~) recompute());
lowBoundField.Layout.Row = 2; lowBoundField.Layout.Column = 2;

highBoundLabel = uilabel(ctrl, 'Text', 'High bound (≥):');
highBoundLabel.Layout.Row = 2; highBoundLabel.Layout.Column = 3;
highBoundField = uieditfield(ctrl, 'numeric', 'Value', 0.6, 'ValueChangedFcn', @(~, ~) recompute());
highBoundField.Layout.Row = 2; highBoundField.Layout.Column = 4;

yScaleLabel = uilabel(ctrl, 'Text', 'Y-axis:');
yScaleLabel.Layout.Row = 2; yScaleLabel.Layout.Column = 5;
yScaleSwitch = uiswitch(ctrl, 'slider', 'Items', {'Linear', 'Log'}, 'Value', 'Linear', ...
    'ValueChangedFcn', @(~, ~) recompute());
yScaleSwitch.Layout.Row = 2; yScaleSwitch.Layout.Column = 6;

bootNLabel = uilabel(ctrl, 'Text', 'Bootstrap N:');
bootNLabel.Layout.Row = 3; bootNLabel.Layout.Column = 1;
bootNField = uieditfield(ctrl, 'numeric', 'Value', 2000, 'Limits', [10 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) recompute());
bootNField.Layout.Row = 3; bootNField.Layout.Column = 2;

contentGrid = uigridlayout(layout, [1 3]);
contentGrid.Layout.Row = 2;
contentGrid.ColumnWidth = {'1x', 320, 220};
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [0 0 0 0];

plotPanel = uipanel(contentGrid, 'Title', 'Lifetime: Data Points + Bootstrap 95% CI');
plotGrid = uigridlayout(plotPanel, [1 1]);
plotGrid.Padding = [4 4 4 4];
ax = uiaxes(plotGrid);

statsPanel = uipanel(contentGrid, 'Title', 'Statistics');
statsGrid = uigridlayout(statsPanel, [1 1]);
statsGrid.Padding = [4 4 4 4];
statsArea = uitextarea(statsGrid, 'Value', {'No results yet.'}, 'Editable', 'off');

actionsPanel = uipanel(contentGrid, 'Title', 'Actions');
actionsGrid = uigridlayout(actionsPanel, [5 1]);
actionsGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x'};
actionsGrid.Padding = [4 4 4 4];
pipeline.addExportPlotButton(actionsGrid, ax, 'Event Sorting by Mean FRET', @suggestedPlotName);
exportCsvButton = uibutton(actionsGrid, 'Text', 'Export CSV...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportEventCsv());
exportSummaryCsvButton = uibutton(actionsGrid, 'Text', 'Export Summary CSV...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportSummaryCsv());
saveBinnedButton = uibutton(actionsGrid, 'Text', 'Save Binned Groups...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) saveBinnedGroups());

% Cached state from the most recent recompute(), read by the export/save
% callbacks at the moment they're used.
lastChName       = '';
lastTypeLabel    = '';
lastMeanFRET     = [];
lastLifetime     = [];
lastMolIDs       = [];
lastGroupLabel   = {};
lastHighOnlyMols = [];
lastLowOnlyMols  = [];
lastLowBound  = [];
lastHighBound = [];
lastLowBoot   = [];
lastHighBoot  = [];
lastPVal      = [];
lastNLow      = 0;
lastNMid      = 0;
lastNHigh     = 0;
lastNMolTotal = 0;
lastNBootReq  = 0;

recompute();

    function onChannelChanged()
        autoSuggestBounds();
        recompute();
    end

    function autoSuggestBounds()
        % Reset Low/High to the tertile split of the new channel's mean-FRET
        % values -- a sensible starting point regardless of dataset. Left
        % alone on any other control change so a user's own edits aren't
        % silently clobbered.
        chName = chDropdown.Value;
        chIdx  = find(strcmp(app.Data.result.channelNames, chName), 1);
        evList = pipeline.filterEventsByType(app.Data.result.events{chIdx}, eventTypeDropdown.Value);
        if isempty(evList)
            return;
        end
        segments = pipeline.extractEventSegments(app, chName, evList);
        vals = cellfun(@mean, segments);
        lowBoundField.Value  = prctile(vals, 33);
        highBoundField.Value = prctile(vals, 67);
    end

    function recompute()
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
            title(ax, sprintf('%s - %s: no data', chName, typeLabel));
            statsArea.Value = {'No events.'};
            exportCsvButton.Enable = 'off';
            exportSummaryCsvButton.Enable = 'off';
            saveBinnedButton.Enable = 'off';
            return;
        end

        segments     = pipeline.extractEventSegments(app, chName, evList);
        meanFRET     = cellfun(@mean, segments)';
        lifetimeVals = [evList.lifetime]';
        molIDs       = [evList.mol]';

        lowB  = min(lowBoundField.Value, highBoundField.Value);
        highB = max(lowBoundField.Value, highBoundField.Value);

        isLow  = meanFRET <= lowB;
        isHigh = meanFRET >= highB;
        isMid  = ~isLow & ~isHigh;

        groupLabel = repmat({'Middle (excluded)'}, numel(evList), 1);
        groupLabel(isLow)  = {'Low'};
        groupLabel(isHigh) = {'High'};

        % --- Individual lifetime data points + molecule-level cluster bootstrap 95% CI of the mean ---
        JITTER_HALF_WIDTH = 0.15;
        nBootReq = bootNField.Value;
        lowMolIDs  = molIDs(isLow);
        highMolIDs = molIDs(isHigh);

        hold(ax, 'on');
        pipeline.plotJitteredPoints(ax, 1, lifetimeVals(isLow),  DARK_BLUE, JITTER_HALF_WIDTH);
        pipeline.plotJitteredPoints(ax, 2, lifetimeVals(isHigh), DARK_ORANGE, JITTER_HALF_WIDTH);

        % Bootstrap needs at least 2 distinct molecules to resample from;
        % below that a CI isn't meaningful, so the mean/CI marker (and the
        % stats-panel line below) is simply skipped for that group.
        lowBoot  = [];
        highBoot = [];
        if numel(unique(lowMolIDs)) >= 2
            lowBoot = pipeline.bootstrapMeanCI(lifetimeVals(isLow), lowMolIDs, nBootReq);
            pipeline.plotPointCI(ax, 1, lowBoot.mean, lowBoot.ci);
        end
        if numel(unique(highMolIDs)) >= 2
            highBoot = pipeline.bootstrapMeanCI(lifetimeVals(isHigh), highMolIDs, nBootReq);
            pipeline.plotPointCI(ax, 2, highBoot.mean, highBoot.ci);
        end
        hold(ax, 'off');

        ax.XTick = [1 2];
        ax.XTickLabel = {sprintf('Low Mean FRET (n=%d)', nnz(isLow)), ...
                          sprintf('High Mean FRET (n=%d)', nnz(isHigh))};
        xlim(ax, [0.4, 2.6]);
        ax.YScale = lower(yScaleSwitch.Value);
        ylabel(ax, 'Lifetime (s)');
        title(ax, sprintf('%s - %s (n = %d events)', chName, typeLabel, numel(evList)));
        pipeline.applyAxesStyle(ax);

        % --- Event-level statistics ---
        nMolTotal = numel(unique(molIDs));
        if nnz(isLow) >= 2 && nnz(isHigh) >= 2
            try
                pVal = ranksum(lifetimeVals(isLow), lifetimeVals(isHigh));
            catch
                pVal = NaN;
            end
        else
            pVal = NaN;
        end

        eventLines = { ...
            '=== Event-level ===' ...
            sprintf('Total events: %d  (molecules: %d)', numel(evList), nMolTotal) ...
            sprintf('Sort factor: Mean FRET   bounds: [%.4g, %.4g]', lowB, highB) ...
            sprintf('  Low  (<= %.4g): %d events', lowB, nnz(isLow)) ...
            sprintf('  Mid  (excluded): %d events', nnz(isMid)) ...
            sprintf('  High (>= %.4g): %d events', highB, nnz(isHigh)) ...
            '' ...
            sprintf('Lifetime (s), all events:  mean = %.4g, median = %.4g, SD = %.4g', ...
                mean(lifetimeVals, 'omitnan'), median(lifetimeVals, 'omitnan'), std(lifetimeVals, 'omitnan')) ...
            meanCILine('Lifetime (s)', 'Low group', lowBoot, nBootReq) ...
            meanCILine('Lifetime (s)', 'High group', highBoot, nBootReq) ...
            sprintf('Low vs High Lifetime (s), rank-sum p = %.4g (exploratory)', pVal) ...
        };

        % --- Trace-level binning (same Low/High group definitions, at the molecule level) ---
        uniqueMols = unique(molIDs);
        hasHigh = false(size(uniqueMols));
        hasLow  = false(size(uniqueMols));
        for im = 1:numel(uniqueMols)
            idx = (molIDs == uniqueMols(im));
            hasHigh(im) = any(isHigh(idx));
            hasLow(im)  = any(isLow(idx));
        end
        highOnlyMask = hasHigh & ~hasLow;
        lowOnlyMask  = hasLow & ~hasHigh;
        bothMask     = hasHigh & hasLow;
        neitherMask  = ~hasHigh & ~hasLow;

        highOnlyMols = uniqueMols(highOnlyMask);
        lowOnlyMols  = uniqueMols(lowOnlyMask);

        traceLines = { ...
            '=== Trace-level (molecules qualifying for a group) ===' ...
            sprintf('A molecule "qualifies" for High/Low if any of its events falls in that group.') ...
            sprintf('High-only: %d molecules', nnz(highOnlyMask)) ...
            pipeline.traceGroupSummary('  ', highOnlyMols, molIDs, lifetimeVals) ...
            sprintf('Low-only:  %d molecules', nnz(lowOnlyMask)) ...
            pipeline.traceGroupSummary('  ', lowOnlyMols, molIDs, lifetimeVals) ...
            sprintf('Both (qualify for High and Low): %d molecules', nnz(bothMask)) ...
            sprintf('Neither (all events in excluded middle): %d molecules', nnz(neitherMask)) ...
            '' ...
            '"Save Binned Groups..." saves the full traces of High-only and' ...
            'Low-only molecules as two separate .mat files (mutually' ...
            'exclusive by construction); Both/Neither molecules are not' ...
            'included in either file.' ...
        };

        statsArea.Value = [eventLines, {''}, traceLines];

        lastMeanFRET     = meanFRET;
        lastLifetime     = lifetimeVals;
        lastMolIDs       = molIDs;
        lastGroupLabel   = groupLabel;
        lastHighOnlyMols = highOnlyMols;
        lastLowOnlyMols  = lowOnlyMols;
        lastLowBound  = lowB;
        lastHighBound = highB;
        lastLowBoot   = lowBoot;
        lastHighBoot  = highBoot;
        lastPVal      = pVal;
        lastNLow      = nnz(isLow);
        lastNMid      = nnz(isMid);
        lastNHigh     = nnz(isHigh);
        lastNMolTotal = nMolTotal;
        lastNBootReq  = nBootReq;

        exportCsvButton.Enable        = 'on';
        exportSummaryCsvButton.Enable = 'on';
        saveBinnedButton.Enable = (~isempty(highOnlyMols) || ~isempty(lowOnlyMols));
    end

    function exportEventCsv()
        if isempty(lastMolIDs)
            return;
        end

        header = {'Sample', 'Analyzed events', 'Molecule', 'Mean FRET', 'Lifetime (s)', 'Group'};
        n = numel(lastMolIDs);
        rows = cell(n, numel(header));
        for i = 1:n
            rows(i, :) = {lastChName, lastTypeLabel, lastMolIDs(i), lastMeanFRET(i), lastLifetime(i), ...
                lastGroupLabel{i}};
        end

        suggested = sprintf('EventSortingByFRET_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
        [fname, fpath] = uiputfile('*.csv', 'Export per-event data as', [suggested '.csv']);
        if isequal(fname, 0)
            return;
        end

        try
            pipeline.writeCsvTable(fullfile(fpath, fname), header, rows);
        catch ME
            uialert(app.UIFigure, ME.message, 'Export failed');
        end
    end

    function exportSummaryCsv()
        if isempty(lastMolIDs)
            return;
        end

        row = struct();
        row.Module          = "Event Sorting by Mean FRET";
        row.Dataset          = string(lastChName);
        row.EventFilter      = string(lastTypeLabel);
        row.LowBound         = lastLowBound;
        row.HighBound        = lastHighBound;
        row.NMolecules_Total = lastNMolTotal;
        row.NEvents_Low      = lastNLow;
        row.NEvents_Mid      = lastNMid;
        row.NEvents_High     = lastNHigh;
        row.NBootstrap       = lastNBootReq;

        [lowMean, lowCI, lowNMol]   = groupBootFields(lastLowBoot);
        [highMean, highCI, highNMol] = groupBootFields(lastHighBoot);

        row.Lifetime_Low_Mean        = lowMean;
        row.Lifetime_Low_BootstrapCI = lowCI;
        row.NMolecules_Low           = lowNMol;

        row.Lifetime_High_Mean        = highMean;
        row.Lifetime_High_BootstrapCI = highCI;
        row.NMolecules_High           = highNMol;

        row.RankSum_p = lastPVal;

        T = struct2table(row, 'AsArray', true);

        suggested = sprintf('EventSortingByFRET_Summary_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
        [fname, fpath] = uiputfile('*.csv', 'Export summary statistics as', [suggested '.csv']);
        if isequal(fname, 0)
            return;
        end

        try
            writetable(T, fullfile(fpath, fname));
        catch ME
            uialert(app.UIFigure, ME.message, 'Export failed');
        end
    end

    function saveBinnedGroups()
        if isempty(lastHighOnlyMols) && isempty(lastLowOnlyMols)
            return;
        end

        [fname, fpath] = uiputfile('*.mat', 'Save binned groups as (base name, _highGroup/_lowGroup appended)', ...
            [suggestedPlotName() '.mat']);
        if isequal(fname, 0)
            return;
        end
        [~, name, ~] = fileparts(fname);
        baseName = fullfile(fpath, name);

        nChPerMol = app.Data.nChPerMol;
        savedWhich = {};

        if ~isempty(lastHighOnlyMols)
            writeGroupMat([baseName '_highGroup.mat'], lastHighOnlyMols, nChPerMol);
            savedWhich{end + 1} = sprintf('%d high-group', numel(lastHighOnlyMols));
        end
        if ~isempty(lastLowOnlyMols)
            writeGroupMat([baseName '_lowGroup.mat'], lastLowOnlyMols, nChPerMol);
            savedWhich{end + 1} = sprintf('%d low-group', numel(lastLowOnlyMols));
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

    function name = suggestedPlotName()
        name = sprintf('EventSortingByFRET_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
    end
end

function [meanVal, ciStr, nMol] = groupBootFields(boot)
%GROUPBOOTFIELDS Pull the summary-CSV fields out of a pipeline.bootstrapMeanCI
% result, or NaN/blank placeholders when the group had too few distinct
% molecules for the bootstrap to run (see recompute()). bootstrapMeanCI
% always runs every requested resample (unlike bootstrapRateCI/
% bootstrapGaussianCI, a mean can't fail to fit), so there is no per-group
% "N successful" to report here -- see lastNBootReq for the requested count.
if isempty(boot)
    meanVal = NaN;
    ciStr = "";
    nMol = NaN;
else
    meanVal = boot.mean;
    ciStr = pipeline.formatCI(boot.ci(1), boot.ci(2));
    nMol = boot.nMolecules;
end
end

function line = meanCILine(otherName, groupLabel, boot, nBootReq)
%MEANCILINE One stats-panel line reporting a group's bootstrap mean/CI, or
% an explanatory placeholder when the group had too few distinct molecules
% for the bootstrap to run (see pipeline.bootstrapMeanCI).
if isempty(boot)
    line = sprintf('%s, %s:  mean/CI N/A (need >=2 molecules)', otherName, groupLabel);
else
    line = sprintf('%s, %s:  mean = %.4g, 95%% CI [%.4g, %.4g] (bootstrap N=%d, %d molecules)', ...
        otherName, groupLabel, boot.mean, boot.ci(1), boot.ci(2), nBootReq, boot.nMolecules);
end
end
