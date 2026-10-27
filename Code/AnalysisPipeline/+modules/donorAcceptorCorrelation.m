function donorAcceptorCorrelation(app)
%DONORACCEPTORCORRELATION Within-event donor/acceptor intensity anti-correlation, a FRET sanity check.
%   Module function: takes the AnalysisPipelineApp instance. Adapted from
%   ExampleCode/LL_TIRF_Get_D_A_TimeSeries_v1.m.
%
%   Assumes 2-color data: channel 1 is the donor's raw intensity, channel 2
%   is the acceptor's raw intensity, and channel 3 (or whichever channel
%   carries real ON/OFF state data) is the calculated FRET channel that
%   defines binding events -- donor/acceptor carry no state of their own
%   (see pipeline.extractEvents), matching this app's established
%   single-FRET-pair data convention.
%
%   For each binding event, computes the within-event Pearson correlation
%   between the RAW donor and acceptor intensities. Genuine FRET predicts
%   anti-correlation (donor intensity drops as acceptor intensity rises,
%   since energy transfer moves excitation from one fluorophore to the
%   other); a lack of anti-correlation for a meaningful fraction of events
%   can flag bleed-through, non-specific binding, or other artifacts worth
%   investigating before trusting the FRET values those events produced.
%
%   Purely a diagnostic module: no fitting, no fit log -- its own
%   dedicated per-event and summary CSV exports instead (see below), the
%   same "own independent export, not the shared result log" pattern as
%   +modules/eventSorting.m and +modules/associationDissociationConformations.m.
%
%   Three plots, exported together as one set via a single Export Plot...
%   button (matching +modules/associationDissociationConformations.m's
%   exportBothPlots precedent for a module with more than one axes):
%     - Histogram of per-event Pearson r (probability-normalized), with
%       the median r marked and two user-adjustable reference lines
%       (default -0.5 dashed, -0.7 dotted).
%     - Per-event Pearson r as jittered points + a molecule-level cluster
%       bootstrap median/95% CI marker (pipeline.bootstrapMedianCI,
%       pipeline.plotJitteredPoints/plotPointCI) -- the same points+CI
%       visual convention as +modules/eventSorting.m (deliberately NOT the
%       original script's hand-drawn violin plot, dropped app-wide in
%       favor of points+CI), but bootstrapping the MEDIAN rather than the
%       mean -- Pearson r is bounded to [-1, 1] and often skewed for real
%       data, so median is the more robust point estimate here.
%     - Pooled donor vs acceptor intensity scatter (every valid frame of
%       every valid event), with a corner-to-corner diagonal reference.
%
%   Every plotted element uses plot()/errorbar() rather than MATLAB's
%   native histogram()/scatter()/xline() -- pipeline.exportPlot's
%   reconstruction only knows how to copy 'line'/'errorbar'/'text' graphics
%   objects (see that file), so anything else would silently vanish from
%   the exported .eps/.png/.fig.

MODULE_NAME = 'Donor-Acceptor Correlation';
DEFAULT_REF1 = -0.5;
DEFAULT_REF2 = -0.7;

if isempty(app.Data) || ~isfield(app.Data, 'result')
    uialert(app.UIFigure, 'Load a state-assignment file first.', 'No data loaded');
    return;
end

if isempty(app.Data.result.channelNames)
    uialert(app.UIFigure, 'No channels with detected binding states were found in this file.', 'No usable channels');
    return;
end

if app.Data.nChPerMol < 2
    uialert(app.UIFigure, ...
        'This module assumes 2-color data (donor + acceptor channels); this file has fewer than 2 channels per molecule.', ...
        'Incompatible data');
    return;
end

tab = app.getOrCreateTab(MODULE_NAME);

layout = uigridlayout(tab, [3 1]);
layout.RowHeight = {96, 350, 130};

ctrl = uigridlayout(layout, [2 6]);
ctrl.Layout.Row = 1;
ctrl.ColumnWidth = {100, 150, 100, 170, 130, 130};
ctrl.RowSpacing = 4;
ctrl.Padding = [0 0 0 0];

chLabel = uilabel(ctrl, 'Text', 'Channel:');
chLabel.Layout.Row = 1; chLabel.Layout.Column = 1;
chDropdown = uidropdown(ctrl, 'Items', app.Data.result.channelNames, ...
    'ValueChangedFcn', @(~, ~) recompute());
chDropdown.Layout.Row = 1; chDropdown.Layout.Column = 2;

evLabel = uilabel(ctrl, 'Text', 'Events:');
evLabel.Layout.Row = 1; evLabel.Layout.Column = 3;
eventTypeDropdown = uidropdown(ctrl, ...
    'Items', {'All events', 'First event', 'Subsequent events'}, ...
    'ItemsData', {'all', 'first', 'subsequent'}, ...
    'Value', 'all', ...
    'ValueChangedFcn', @(~, ~) recompute());
eventTypeDropdown.Layout.Row = 1; eventTypeDropdown.Layout.Column = 4;

minFramesLabel = uilabel(ctrl, 'Text', 'Min event frames:');
minFramesLabel.Layout.Row = 1; minFramesLabel.Layout.Column = 5;
minFramesField = uieditfield(ctrl, 'numeric', 'Value', 5, 'Limits', [2 Inf], ...
    'RoundFractionalValues', 'on', 'ValueChangedFcn', @(~, ~) recompute());
minFramesField.Layout.Row = 1; minFramesField.Layout.Column = 6;

ref1Label = uilabel(ctrl, 'Text', 'Ref line 1:');
ref1Label.Layout.Row = 2; ref1Label.Layout.Column = 1;
ref1Field = uieditfield(ctrl, 'numeric', 'Value', DEFAULT_REF1, 'Limits', [-1 1], ...
    'ValueChangedFcn', @(~, ~) replotOnly());
ref1Field.Layout.Row = 2; ref1Field.Layout.Column = 2;

ref2Label = uilabel(ctrl, 'Text', 'Ref line 2:');
ref2Label.Layout.Row = 2; ref2Label.Layout.Column = 3;
ref2Field = uieditfield(ctrl, 'numeric', 'Value', DEFAULT_REF2, 'Limits', [-1 1], ...
    'ValueChangedFcn', @(~, ~) replotOnly());
ref2Field.Layout.Row = 2; ref2Field.Layout.Column = 4;

bootNLabel = uilabel(ctrl, 'Text', 'Bootstrap N:');
bootNLabel.Layout.Row = 2; bootNLabel.Layout.Column = 5;
bootNField = uieditfield(ctrl, 'numeric', 'Value', 2000, 'Limits', [10 Inf], ...
    'RoundFractionalValues', 'on', 'ValueChangedFcn', @(~, ~) recompute());
bootNField.Layout.Row = 2; bootNField.Layout.Column = 6;

contentGrid = uigridlayout(layout, [1 3]);
contentGrid.Layout.Row = 2;
contentGrid.ColumnWidth = {330, 330, 330};
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [0 0 0 0];

histPanel = uipanel(contentGrid, 'Title', 'Pearson r Histogram');
histGrid = uigridlayout(histPanel, [1 1]);
histGrid.Padding = [4 4 4 4];
axHist = uiaxes(histGrid);

pointsPanel = uipanel(contentGrid, 'Title', 'Pearson r: Points + Bootstrap CI');
pointsGrid = uigridlayout(pointsPanel, [1 1]);
pointsGrid.Padding = [4 4 4 4];
axPoints = uiaxes(pointsGrid);

scatterPanel = uipanel(contentGrid, 'Title', 'Donor vs Acceptor (pooled)');
scatterGrid = uigridlayout(scatterPanel, [1 1]);
scatterGrid.Padding = [4 4 4 4];
axScatter = uiaxes(scatterGrid);

% Statistics + export actions sit below the plots as one horizontal strip
% (rather than a fourth narrow column) so the plot panels above can be
% sized close to square instead of stretched to the tab's full height.
bottomGrid = uigridlayout(layout, [1 2]);
bottomGrid.Layout.Row = 3;
bottomGrid.ColumnWidth = {'1x', 220};
bottomGrid.ColumnSpacing = 8;
bottomGrid.Padding = [0 0 0 0];

statsPanel = uipanel(bottomGrid, 'Title', 'Statistics');
statsPanelGrid = uigridlayout(statsPanel, [1 1]);
statsPanelGrid.Padding = [4 4 4 4];
statsArea = uitextarea(statsPanelGrid, 'Value', {'No results yet.'}, 'Editable', 'off');

actionsPanel = uipanel(bottomGrid, 'Title', 'Actions');
actionsGrid = uigridlayout(actionsPanel, [3 1]);
actionsGrid.RowSpacing = 4;
actionsGrid.Padding = [4 4 4 4];
exportPlotButton = uibutton(actionsGrid, 'Text', 'Export Plot...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportAllPlots());
exportCsvButton = uibutton(actionsGrid, 'Text', 'Export CSV...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportEventCsv());
exportSummaryCsvButton = uibutton(actionsGrid, 'Text', 'Export Summary CSV...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportSummaryCsv());

% Cached state from the most recent recompute(), read by replotOnly() and
% the export callbacks at the moment they're used.
lastChName    = '';
lastTypeLabel = '';
lastMolIDs    = [];
lastLenVals   = [];
lastRVals     = [];
lastValid     = [];
lastDonorSegs = {};
lastAcceptorSegs = {};
lastMedianBoot = [];

recompute();

    function recompute()
        chName    = chDropdown.Value;
        typeValue = eventTypeDropdown.Value;
        typeLabel = eventTypeDropdown.Items{strcmp(eventTypeDropdown.ItemsData, typeValue)};

        chIdx     = find(strcmp(app.Data.result.channelNames, chName), 1);
        evListAll = app.Data.result.events{chIdx};
        evList    = pipeline.filterEventsByType(evListAll, typeValue);

        lastChName    = chName;
        lastTypeLabel = typeLabel;

        cla(axHist); cla(axPoints); cla(axScatter);
        if isempty(evList)
            title(axHist, sprintf('%s - %s: no data', chName, typeLabel));
            statsArea.Value = {'No events.'};
            exportPlotButton.Enable = 'off';
            exportCsvButton.Enable = 'off';
            exportSummaryCsvButton.Enable = 'off';
            lastMolIDs = []; lastLenVals = []; lastRVals = []; lastValid = [];
            lastDonorSegs = {}; lastAcceptorSegs = {}; lastMedianBoot = [];
            return;
        end

        donorName    = app.Data.channelNames{1};
        acceptorName = app.Data.channelNames{2};
        donorSegs    = pipeline.extractEventSegments(app, donorName, evList);
        acceptorSegs = pipeline.extractEventSegments(app, acceptorName, evList);
        molIDs       = [evList.mol]';

        nEvents  = numel(evList);
        minFrames = minFramesField.Value;
        rVals   = nan(nEvents, 1);
        lenVals = nan(nEvents, 1);
        for k = 1:nEvents
            D = donorSegs{k};
            A = acceptorSegs{k};
            v = ~isnan(D) & ~isnan(A);
            lenVals(k) = sum(v);
            if lenVals(k) < minFrames || std(D(v)) == 0 || std(A(v)) == 0
                continue;
            end
            rVals(k) = corr(D(v), A(v), 'type', 'Pearson');
        end
        valid = ~isnan(rVals);

        lastMolIDs       = molIDs;
        lastLenVals      = lenVals;
        lastRVals        = rVals;
        lastValid        = valid;
        lastDonorSegs    = donorSegs;
        lastAcceptorSegs = acceptorSegs;

        % Molecule-level cluster bootstrap 95% CI of the median (needs >= 2
        % distinct molecules among the valid events to resample from).
        validMolIDs = molIDs(valid);
        if numel(unique(validMolIDs)) >= 2
            lastMedianBoot = pipeline.bootstrapMedianCI(rVals(valid), validMolIDs, bootNField.Value);
        else
            lastMedianBoot = [];
        end

        replotOnly();

        exportPlotButton.Enable        = 'on';
        exportCsvButton.Enable         = 'on';
        exportSummaryCsvButton.Enable  = 'on';
    end

    function replotOnly()
        if isempty(lastValid)
            return;
        end

        chName    = lastChName;
        typeLabel = lastTypeLabel;
        rVals     = lastRVals;
        valid     = lastValid;
        validR    = rVals(valid);
        nValid    = nnz(valid);
        ref1      = ref1Field.Value;
        ref2      = ref2Field.Value;

        % --- Histogram ---
        cla(axHist);
        if nValid > 0
            edges   = linspace(-1, 1, 31);
            counts  = histcounts(validR, edges);
            heights = counts / sum(counts);
            centers = (edges(1:end-1) + edges(2:end)) / 2;
            pipeline.plotCDFMarkers(axHist, centers, heights);
            hold(axHist, 'on');
            medR  = median(validR);
            yTop  = max(heights) * 1.15;
            plot(axHist, [medR medR], [0 yTop], '-', 'Color', [0.8 0 0], 'LineWidth', 1.5);
            text(axHist, medR, yTop, sprintf(' median = %.2f', medR), 'Color', [0.8 0 0], ...
                'HorizontalAlignment', 'left', 'FontSize', 9);
            plot(axHist, [ref1 ref1], [0 yTop], '--', 'Color', [0.4 0.4 0.4]);
            plot(axHist, [ref2 ref2], [0 yTop], ':', 'Color', [0.4 0.4 0.4]);
            hold(axHist, 'off');
        end
        pipeline.applyAxesStyle(axHist);
        axis(axHist, 'square');
        xlim(axHist, [-1 1]);
        xlabel(axHist, 'Donor-Acceptor Pearson r');
        ylabel(axHist, 'Fraction of events');
        title(axHist, sprintf('%s - %s (n = %d valid)', chName, typeLabel, nValid));

        % --- Points + bootstrap CI ---
        cla(axPoints);
        hold(axPoints, 'on');
        if nValid > 0
            pipeline.plotJitteredPoints(axPoints, 1, validR, [0.2 0.2 0.2], 0.15);
        end
        if ~isempty(lastMedianBoot)
            pipeline.plotPointCI(axPoints, 1, lastMedianBoot.median, lastMedianBoot.ci);
        end
        plot(axPoints, [0.4 1.6], [ref1 ref1], '--', 'Color', [0.4 0.4 0.4]);
        plot(axPoints, [0.4 1.6], [ref2 ref2], ':', 'Color', [0.4 0.4 0.4]);
        hold(axPoints, 'off');
        pipeline.applyAxesStyle(axPoints);
        axis(axPoints, 'square');
        axPoints.XTick = 1;
        axPoints.XTickLabel = {sprintf('n = %d events', nValid)};
        xlim(axPoints, [0.4 1.6]);
        ylim(axPoints, [-1 1]);
        ylabel(axPoints, 'Donor-Acceptor Pearson r');
        title(axPoints, sprintf('%s - %s', chName, typeLabel));

        % --- Pooled Donor vs Acceptor scatter ---
        cla(axScatter);
        Dall = [];
        Aall = [];
        for k = find(valid)'
            D = lastDonorSegs{k};
            A = lastAcceptorSegs{k};
            v = ~isnan(D) & ~isnan(A);
            Dall = [Dall; D(v)]; %#ok<AGROW>
            Aall = [Aall; A(v)]; %#ok<AGROW>
        end
        if ~isempty(Dall)
            POINT_BLEND = 0.35;
            blended = POINT_BLEND * [0 0 0] + (1 - POINT_BLEND) * [1 1 1];
            plot(axScatter, Dall, Aall, 'o', 'LineStyle', 'none', 'MarkerSize', 3, ...
                'MarkerFaceColor', blended, 'MarkerEdgeColor', 'none');
            hold(axScatter, 'on');
            axis(axScatter, 'tight');
            lims = axis(axScatter);
            plot(axScatter, [lims(1) lims(2)], [lims(3) lims(4)], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
            hold(axScatter, 'off');
        end
        pipeline.applyAxesStyle(axScatter);
        axis(axScatter, 'square');
        xlabel(axScatter, 'Donor intensity');
        ylabel(axScatter, 'Acceptor intensity');
        title(axScatter, sprintf('%s - %s (pooled, n = %d events)', chName, typeLabel, nValid));

        % --- Statistics panel ---
        nMolValid = numel(unique(lastMolIDs(valid)));
        statsArea.Value = { ...
            sprintf('Total events: %d', numel(valid)) ...
            sprintf('Valid (>= %d frames, nonzero variance): %d', minFramesField.Value, nValid) ...
            sprintf('Invalid (skipped): %d', nnz(~valid)) ...
            sprintf('Molecules (valid events): %d', nMolValid) ...
            '' ...
            medianCILine(validR, lastMedianBoot, bootNField.Value) ...
        };
    end

    function exportAllPlots()
        [fname, fpath] = uiputfile('*.eps', 'Export plots (.fig/.png/.eps saved for all three)', [suggestedPlotName() '.eps']);
        if isequal(fname, 0)
            return;
        end
        [~, name, ~] = fileparts(fname);
        baseName = fullfile(fpath, name);
        pipeline.exportPlot(axHist, MODULE_NAME, [baseName '_histogram']);
        pipeline.exportPlot(axPoints, MODULE_NAME, [baseName '_pointsCI']);
        pipeline.exportPlot(axScatter, MODULE_NAME, [baseName '_donorVsAcceptor']);
    end

    function exportEventCsv()
        if isempty(lastValid)
            return;
        end

        header = {'Sample', 'Analyzed events', 'Molecule', 'Event length (frames)', 'Donor-Acceptor Pearson r', 'Valid'};
        n = numel(lastValid);
        rows = cell(n, numel(header));
        for i = 1:n
            rows(i, :) = {lastChName, lastTypeLabel, lastMolIDs(i), lastLenVals(i), lastRVals(i), lastValid(i)};
        end

        suggested = sprintf('DonorAcceptorCorrelation_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
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
        if isempty(lastValid)
            return;
        end

        valid  = lastValid;
        validR = lastRVals(valid);

        row = struct();
        row.Module          = "Donor-Acceptor Correlation";
        row.Dataset          = string(lastChName);
        row.EventFilter      = string(lastTypeLabel);
        row.MinEventFrames   = minFramesField.Value;
        row.ReferenceLine1   = ref1Field.Value;
        row.ReferenceLine2   = ref2Field.Value;
        row.NEvents          = numel(valid);
        row.NValid           = nnz(valid);
        row.NInvalid         = nnz(~valid);
        row.NMolecules_Valid = numel(unique(lastMolIDs(valid)));

        if isempty(lastMedianBoot)
            row.Median_PearsonR             = median(validR, 'omitnan');
            row.Median_PearsonR_BootstrapCI = "";
        else
            row.Median_PearsonR             = lastMedianBoot.median;
            row.Median_PearsonR_BootstrapCI = pipeline.formatCI(lastMedianBoot.ci(1), lastMedianBoot.ci(2));
        end
        row.NBootstrap = bootNField.Value;

        T = struct2table(row, 'AsArray', true);

        suggested = sprintf('DonorAcceptorCorrelation_Summary_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
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

    function name = suggestedPlotName()
        name = sprintf('DonorAcceptorCorrelation_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
    end
end

function line = medianCILine(validR, boot, nBootReq)
%MEDIANCILINE One stats-panel line reporting the bootstrap median/CI of
% the valid events' Pearson r, or an explanatory placeholder when there
% were too few distinct molecules for the bootstrap to run (see
% recompute()). Median, not mean -- Pearson r is bounded to [-1, 1] and
% often skewed for real data, so median is the more robust point estimate
% here, unlike this app's other points+CI modules (e.g.
% +modules/eventSorting.m), which summarize the mean.
if isempty(boot)
    line = sprintf('Median Pearson r: %.3f (95%% CI N/A, need >=2 molecules)', median(validR, 'omitnan'));
else
    line = sprintf('Median Pearson r: %.3f, 95%% CI [%.3f, %.3f] (bootstrap N=%d, %d molecules)', ...
        boot.median, boot.ci(1), boot.ci(2), nBootReq, boot.nMolecules);
end
end
