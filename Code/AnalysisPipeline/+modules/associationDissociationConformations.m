function associationDissociationConformations(app)
%ASSOCIATIONDISSOCIATIONCONFORMATIONS FRET conformation at binding onset/offset.
%   Module function: takes the AnalysisPipelineApp instance. Adapted from
%   ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m.
%   Requires app.Data.result (see +pipeline/extractEvents.m) and the
%   Statistics and Machine Learning Toolbox (fitglme, cdfcalc-family).
%
%   A Type dropdown switches between two related but independent analyses,
%   both built from the same per-event bound-duration traces (see
%   pipeline.extractEventSegmentsWithBoundary):
%     Dissociation (end-aligned) - does FRET state (high/low, split at a
%       manual threshold) predict the per-frame PROBABILITY of
%       dissociation on the next frame? Swept across five predictor-frame
%       choices (the terminal frame itself, then 2nd/3rd/4th/5th-to-last)
%       since the terminal frame's own reading can be time-censored by the
%       movie ending mid-event.
%     Association (start-aligned) - what FRET state is present when the
%       channel first binds? Swept across the first five frames of each
%       event, since the very first frame can itself be time-censored (by
%       localization/tracking lag), and compared against both the
%       aggregate (equilibrium) occupancy and an unbiased 50% reference.
%   Statistics: mixed-effects logistic regression (fitglme) plus a
%   molecule-level cluster bootstrap for confidence intervals -- see
%   pipeline.runDissociationHazardTest / pipeline.runAssociationTest.
%
%   Reading events, building the heatmap, and running the full 5-entry
%   frame sweep (up to 5 GLMM fits plus thousands of bootstrap resamples)
%   is nontrivial computation, so -- unlike this app's live-refreshing
%   modules -- everything here is gated behind an explicit "Run Analysis"
%   button. The frame-sweep plot always shows all 5 entries at once (Low
%   FRET vs High FRET dissociation probability, or Observed-at-onset vs
%   Equilibrium high-FRET fraction, each frame's 95% CI plotted as an
%   error bar); the "Stats for frame" dropdown only selects which one
%   entry's precise numeric readout appears in the text panel below it --
%   switching it is instant (redrawn from the cached sweep, no re-fit).
%
%   Frame-sweep results are exported as a CSV (pipeline.writeCsvTable) via
%   this module's own Export CSV button, independent of every other
%   module's result log (see app.appendResultLog) -- the schema (odds
%   ratios, per-frame hazard probabilities, molecule/event counts) doesn't
%   resemble the curve-fit result logs pipeline.buildFitControls/
%   buildGaussianFitControls keep. Column headers mostly match the original
%   script this module was adapted from, except CI columns, which use the
%   same single-column "[lower, upper]" convention (pipeline.formatCI) as
%   every other module's result log rather than the original script's
%   separate LB/UB columns.

MODULE_NAME = 'Association/Dissociation Conformations';
DISSOC_LABELS = {'Final', '2nd to last', '3rd to last', '4th to last', '5th to last'};
ASSOC_LABELS  = {'First', 'Second', 'Third', 'Fourth', 'Fifth'};
PRIMARY_SWEEP_INDEX = 2;   % matches the original script's dissocPrimaryIdx/assocPrimaryIdx

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

% Heatmap kept narrow; the frame-sweep panel gets the lion's share of the
% remaining width so its plot is the one worth spreading out to read.
contentGrid = uigridlayout(layout, [1 3]);
contentGrid.Layout.Row = 2;
contentGrid.ColumnWidth = {360, '1x', 340};
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [0 0 0 0];

% Structurally mirrors sweepPanel below (same title-bar overhead, same
% two-level {'1x',130}/{'1x',24} row split, with the matching rows left
% empty) purely so ax ends up the same height as barAx -- both are
% computed by the exact same row-height arithmetic, rather than
% approximating with a single lump spacer that could drift out of sync if
% either panel's internal layout changes later.
heatmapPanel = uipanel(contentGrid, 'Title', 'Heatmap');
heatmapGrid = uigridlayout(heatmapPanel, [2 1]);
heatmapGrid.RowHeight = {'1x', 130};
heatmapGrid.RowSpacing = 6;
heatmapGrid.Padding = [4 4 4 4];

axGrid = uigridlayout(heatmapGrid, [2 1]);
axGrid.RowHeight = {'1x', 24};
axGrid.Padding = [0 0 0 0];
ax = uiaxes(axGrid);

sweepPanel = uipanel(contentGrid, 'Title', 'Frame-Sweep Result');
sweepGrid = uigridlayout(sweepPanel, [2 1]);
sweepGrid.RowHeight = {'1x', 130};
sweepGrid.RowSpacing = 6;
sweepGrid.Padding = [4 4 4 4];

% barAxGrid's row 2 is deliberately left empty (no export button here --
% see the single combined Export Plot... button in ctrl) purely to keep
% the {'1x',24} split matching heatmapGrid/axGrid's, which is what keeps
% ax and barAx the same height.
barAxGrid = uigridlayout(sweepGrid, [2 1]);
barAxGrid.RowHeight = {'1x', 24};
barAxGrid.Padding = [0 0 0 0];
barAx = uiaxes(barAxGrid);

statsArea = uitextarea(sweepGrid, 'Value', {'No results yet.'}, 'Editable', 'off');

paramsPanel = uipanel(contentGrid, 'Title', 'Parameters');
paramsPanel.Scrollable = 'on';

ctrl = uigridlayout(layout, [1 7]);
ctrl.Layout.Row = 1;
ctrl.ColumnWidth = {70, 150, 60, 170, 50, 140, 150};
ctrl.Padding = [0 0 0 0];

uilabel(ctrl, 'Text', 'Channel:');
chDropdown = uidropdown(ctrl, 'Items', app.Data.result.channelNames, ...
    'ValueChangedFcn', @(~, ~) resetResults());

uilabel(ctrl, 'Text', 'Events:');
eventTypeDropdown = uidropdown(ctrl, ...
    'Items', {'All events', 'First event', 'Subsequent events'}, ...
    'ItemsData', {'all', 'first', 'subsequent'}, ...
    'Value', 'all', ...
    'ValueChangedFcn', @(~, ~) resetResults());

uilabel(ctrl, 'Text', 'Type:');
typeDropdown = uidropdown(ctrl, ...
    'Items', {'Association', 'Dissociation'}, ...
    'ItemsData', {'association', 'dissociation'}, ...
    'Value', 'association', ...
    'ValueChangedFcn', @(~, ~) onTypeChanged());

uibutton(ctrl, 'Text', 'Export Plot...', 'ButtonPushedFcn', @(~, ~) exportBothPlots());

% --- Parameters panel ---
pg = uigridlayout(paramsPanel, [12 2]);
pg.RowHeight = repmat({'fit'}, 1, 12);
pg.ColumnWidth = {'fit', '1x'};
pg.RowSpacing = 6;

uilabel(pg, 'Text', 'FRET threshold:');
thresholdField = uieditfield(pg, 'numeric', 'Value', 0.65, 'Limits', [0 1]);

uilabel(pg, 'Text', 'Window (ms):');
tMaxField = uieditfield(pg, 'numeric', 'Value', 400, 'Limits', [1 Inf]);

uilabel(pg, 'Text', 'FRET bins:');
binsField = uieditfield(pg, 'numeric', 'Value', 50, 'Limits', [2 Inf], 'RoundFractionalValues', 'on');

startFrameLabel = uilabel(pg, 'Text', 'Exclude first N frames:');
startFrameField = uieditfield(pg, 'numeric', 'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
startFrameLabel.Visible = 'off';
startFrameField.Visible = 'off';

normalizeCheckbox = uicheckbox(pg, 'Text', 'Normalize heatmap by time', 'Value', false);
normalizeCheckbox.Layout.Column = [1 2];

smoothCheckbox = uicheckbox(pg, 'Text', 'Smooth FRET axis', 'Value', true, ...
    'ValueChangedFcn', @(~, ~) toggleSmoothing());
smoothCheckbox.Layout.Column = [1 2];

uilabel(pg, 'Text', 'Smoothing sigma:');
smoothSigmaField = uieditfield(pg, 'numeric', 'Value', 2, 'Limits', [0 Inf]);

uilabel(pg, 'Text', 'Bootstrap N:');
bootNField = uieditfield(pg, 'numeric', 'Value', 2000, 'Limits', [10 Inf], 'RoundFractionalValues', 'on');

uilabel(pg, 'Text', 'Stats for frame:');
sweepSelectorDropdown = uidropdown(pg, 'Items', ASSOC_LABELS, 'ItemsData', 1:5, 'Value', PRIMARY_SWEEP_INDEX, ...
    'ValueChangedFcn', @(~, ~) updateStatsText());

runButton = uibutton(pg, 'Text', 'Run Analysis', 'ButtonPushedFcn', @(~, ~) runAnalysis());
runButton.Layout.Column = [1 2];

exportCsvButton = uibutton(pg, 'Text', 'Export CSV...', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) exportSweepCsv());
exportCsvButton.Layout.Column = [1 2];

% Cached state from the most recent Run Analysis; frame-sweep-selector
% changes redraw from this without recomputing anything.
lastSweepResults    = [];
lastPEquilibriumHigh = NaN;
lastFretThreshold   = NaN;
lastAlignment        = '';
lastChName           = '';
lastTypeLabel        = '';
lastBootN            = NaN;

resetResults();

    function toggleSmoothing()
        smoothSigmaField.Enable = smoothCheckbox.Value;
    end

    function onTypeChanged()
        isDissoc = strcmp(typeDropdown.Value, 'dissociation');
        startFrameLabel.Visible = isDissoc;
        startFrameField.Visible = isDissoc;
        if isDissoc
            sweepSelectorDropdown.Items = DISSOC_LABELS;
        else
            sweepSelectorDropdown.Items = ASSOC_LABELS;
        end
        sweepSelectorDropdown.ItemsData = 1:5;
        sweepSelectorDropdown.Value = PRIMARY_SWEEP_INDEX;
        resetResults();
    end

    function resetResults()
        cla(ax);
        title(ax, 'Configure parameters, then click "Run Analysis"');
        cla(barAx);
        statsArea.Value = {'No results yet.'};
        lastSweepResults = [];
        exportCsvButton.Enable = 'off';
    end

    function runAnalysis()
        chName    = chDropdown.Value;
        typeValue = eventTypeDropdown.Value;
        typeLabel = eventTypeDropdown.Items{strcmp(eventTypeDropdown.ItemsData, typeValue)};
        alignment = typeDropdown.Value;

        chIdx     = find(strcmp(app.Data.result.channelNames, chName), 1);
        evListAll = app.Data.result.events{chIdx};
        evList    = pipeline.filterEventsByType(evListAll, typeValue);

        if isempty(evList)
            cla(ax);
            title(ax, sprintf('%s - %s: no data', chName, typeLabel));
            return;
        end

        runButton.Enable = 'off';
        reenable = onCleanup(@() set(runButton, 'Enable', 'on'));
        statsArea.Value = {'Extracting events...'};
        drawnow;

        [segments, preVal, postVal, molIDs] = pipeline.extractEventSegmentsWithBoundary(app, chName, evList);

        threshold       = thresholdField.Value;
        tMax            = tMaxField.Value;
        nBins           = binsField.Value;
        startFrameRel   = startFrameField.Value;
        normalizeByTime = normalizeCheckbox.Value;
        doSmooth        = smoothCheckbox.Value;
        sigma           = smoothSigmaField.Value;
        nBoot           = bootNField.Value;
        Exposure        = app.Data.result.Exposure;

        % --- Heatmap ---
        [Z, timeAxis, fretAxis] = pipeline.buildAlignedFretDensityHeatmap(segments, preVal, postVal, ...
            alignment, Exposure, tMax, startFrameRel, nBins, normalizeByTime, doSmooth, sigma);

        cla(ax);
        imagesc(ax, timeAxis, fretAxis, Z);
        axis(ax, 'xy');
        colormap(ax, flipud(gray(256)));
        cb = colorbar(ax);
        if normalizeByTime
            cb.Label.String = 'Fraction per time bin';
        else
            cb.Label.String = 'Counts';
        end
        pipeline.applyAxesStyle(ax);
        if strcmp(alignment, 'dissociation')
            xlabel(ax, sprintf('Time to event end (ms); last %.0f ms plus 1 frame after end', tMax));
        else
            xlabel(ax, sprintf('Time from event start (ms); first %.0f ms plus 1 frame before start', tMax));
        end
        ylabel(ax, 'FRET efficiency');
        title(ax, sprintf('%s - %s (%s, n = %d events)', chName, typeLabel, alignment, numel(evList)));

        % --- Frame sweep (all 5 entries; the dropdown only picks which is displayed) ---
        % results deliberately NOT preallocated with struct() -- assigning a
        % many-field struct (S) into a preallocated struct array whose
        % fields don't already match exactly fails ("dissimilar
        % structures"), and there's no single-field-only version of S to
        % preallocate with. Indexed assignment from results(1) = S onward
        % creates the array with the right shape automatically, matching
        % the original script's own approach (see its comments).
        if strcmp(alignment, 'dissociation')
            kList = [0 1 2 3 4];
            labels = DISSOC_LABELS;
            for ik = 1:numel(kList)
                statsArea.Value = {sprintf('Running dissociation sweep %d/%d (%s frame)...', ik, numel(kList), labels{ik})};
                drawnow;
                [FRET_hz, dissoc_hz, evID_hz, molID_hz] = pipeline.buildDissociationHazardData(segments, molIDs, kList(ik), startFrameRel);
                S = pipeline.runDissociationHazardTest(FRET_hz, dissoc_hz, evID_hz, molID_hz, threshold, nBoot, []);
                S.label = labels{ik};
                results(ik) = S; %#ok<AGROW>
            end
            pEq = NaN;
        else
            mList = [1 2 3 4 5];
            labels = ASSOC_LABELS;
            % Equilibrium reference: reuse the standard (k=1, "2nd-to-last")
            % dissociation hazard pool, matching the original script.
            [FRET_ref, ~, ~, ~] = pipeline.buildDissociationHazardData(segments, molIDs, 1, startFrameRel);
            pEq = mean(FRET_ref >= threshold);
            for im = 1:numel(mList)
                statsArea.Value = {sprintf('Running association sweep %d/%d (%s frame)...', im, numel(mList), labels{im})};
                drawnow;
                [onsetFRET, molID_on] = pipeline.buildAssociationOnsetData(segments, molIDs, mList(im));
                S = pipeline.runAssociationTest(onsetFRET, molID_on, threshold, pEq, nBoot, []);
                S.label = labels{im};
                results(im) = S; %#ok<AGROW>
            end
        end

        lastSweepResults     = results;
        lastPEquilibriumHigh = pEq;
        lastFretThreshold    = threshold;
        lastAlignment         = alignment;
        lastChName            = chName;
        lastTypeLabel         = typeLabel;
        lastBootN             = nBoot;

        renderSweepPlot();
        updateStatsText();
        exportCsvButton.Enable = 'on';
    end

    function renderSweepPlot()
        %RENDERSWEEPPLOT Plot every sweep entry at once (not just the one
        % selected in the "Stats for frame" dropdown): Low FRET as dark
        % orange open diamonds, High FRET as dark blue open circles
        % (dissociation), or Equilibrium as black open diamonds against
        % Observed-at-onset as blue open circles (association), each with
        % 95% (molecule-cluster bootstrap) CI error bars. Dissociation
        % additionally annotates each frame's high-vs-low p-value.
        if isempty(lastSweepResults)
            return;
        end

        DARK_ORANGE = [0.80 0.40 0.00];
        DARK_BLUE   = [0.00 0.20 0.60];
        BLACK       = [0 0 0];
        ASSOC_BLUE  = [0.00 0.35 0.70];

        n = numel(lastSweepResults);
        xPos = 1:n;

        cla(barAx);
        hold(barAx, 'on');

        if strcmp(lastAlignment, 'dissociation')
            probLow  = arrayfun(@(s) s.probLow, lastSweepResults) * 100;
            probHigh = arrayfun(@(s) s.probHigh, lastSweepResults) * 100;
            ciLowLo  = arrayfun(@(s) s.ciLow(1), lastSweepResults) * 100;
            ciLowHi  = arrayfun(@(s) s.ciLow(2), lastSweepResults) * 100;
            ciHighLo = arrayfun(@(s) s.ciHigh(1), lastSweepResults) * 100;
            ciHighHi = arrayfun(@(s) s.ciHigh(2), lastSweepResults) * 100;

            errLowNeg  = max(0, probLow - ciLowLo);
            errLowPos  = max(0, ciLowHi - probLow);
            errHighNeg = max(0, probHigh - ciHighLo);
            errHighPos = max(0, ciHighHi - probHigh);

            hLow = errorbar(barAx, xPos, probLow, errLowNeg, errLowPos, ...
                'LineStyle', 'none', 'Marker', 'd', 'MarkerSize', 8, 'LineWidth', 1.2, 'CapSize', 6, ...
                'Color', DARK_ORANGE, 'MarkerEdgeColor', DARK_ORANGE, 'MarkerFaceColor', 'none');
            hHigh = errorbar(barAx, xPos, probHigh, errHighNeg, errHighPos, ...
                'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.2, 'CapSize', 6, ...
                'Color', DARK_BLUE, 'MarkerEdgeColor', DARK_BLUE, 'MarkerFaceColor', 'none');

            topY = max(probLow + errLowPos, probHigh + errHighPos);
            yCap = max(topY) * 1.3;
            for i = 1:n
                text(barAx, xPos(i), topY(i) + 0.06 * max(topY), pLabel(lastSweepResults(i).pHigh), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8);
            end
            ylim(barAx, [0, yCap]);

            barAx.XTick = xPos;
            barAx.XTickLabel = DISSOC_LABELS;
            barAx.XTickLabelRotation = 30;
            ylabel(barAx, 'Dissociation probability (%)');
            legend(barAx, [hLow, hHigh], {'Low FRET', 'High FRET'}, 'Location', 'best', 'Box', 'off', 'FontSize', 8);
        else
            pObs = arrayfun(@(s) s.pObservedHigh, lastSweepResults) * 100;
            ciLo = arrayfun(@(s) s.ciOnsetBoot(1), lastSweepResults) * 100;
            ciHi = arrayfun(@(s) s.ciOnsetBoot(2), lastSweepResults) * 100;
            errNeg = max(0, pObs - ciLo);
            errPos = max(0, ciHi - pObs);
            eqVals = repmat(lastPEquilibriumHigh * 100, 1, n);

            hEq = plot(barAx, xPos, eqVals, 'LineStyle', 'none', 'Marker', 'd', 'MarkerSize', 8, 'LineWidth', 1.2, ...
                'Color', BLACK, 'MarkerEdgeColor', BLACK, 'MarkerFaceColor', 'none');
            hObs = errorbar(barAx, xPos, pObs, errNeg, errPos, ...
                'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.2, 'CapSize', 6, ...
                'Color', ASSOC_BLUE, 'MarkerEdgeColor', ASSOC_BLUE, 'MarkerFaceColor', 'none');

            topY = max([pObs + errPos, eqVals]);
            ylim(barAx, [0, max(topY) * 1.25]);

            barAx.XTick = xPos;
            barAx.XTickLabel = ASSOC_LABELS;
            barAx.XTickLabelRotation = 30;
            ylabel(barAx, 'High-FRET fraction (%)');
            legend(barAx, [hObs, hEq], {'Observed at onset', 'Equilibrium'}, 'Location', 'best', 'Box', 'off', 'FontSize', 8);
        end

        hold(barAx, 'off');
        pipeline.applyAxesStyle(barAx);
        % A little more margin than the halfway-to-the-next-frame default
        % (0.5), so frame 1 doesn't sit flush against the y-axis --
        % matching the small first/last-category gap a bar chart has.
        xPad = 0.65;
        xlim(barAx, [1 - xPad, n + xPad]);
        xlabel(barAx, 'Frame');
        title(barAx, 'Frame sweep');
    end

    function updateStatsText()
        if isempty(lastSweepResults)
            return;
        end

        idx = min(sweepSelectorDropdown.Value, numel(lastSweepResults));
        Sp = lastSweepResults(idx);

        if strcmp(lastAlignment, 'dissociation')
            statsText = sprintf(['#complexes=%d, #events=%d\n' ...
                'Odds ratio (high vs low FRET): %.3f, p = %.4g\n' ...
                'High-FRET probability: %.4f [%.4f, %.4f]  (%d/%d frames)\n' ...
                'Low-FRET probability:  %.4f [%.4f, %.4f]  (%d/%d frames)\n' ...
                'Low/High probability ratio: %.2f [%.2f, %.2f]'], ...
                Sp.nComplexes, Sp.nEvents, Sp.oddsRatio, Sp.pHigh, ...
                Sp.probHigh, Sp.ciHigh(1), Sp.ciHigh(2), Sp.nHighDissoc, Sp.nHighFrames, ...
                Sp.probLow, Sp.ciLow(1), Sp.ciLow(2), Sp.nLowDissoc, Sp.nLowFrames, ...
                Sp.probRatio, Sp.ciProbRatio(1), Sp.ciProbRatio(2));
        else
            statsText = sprintf(['#complexes=%d, #events=%d\n' ...
                'Observed high-FRET fraction: %.4f [%.4f, %.4f] (%d/%d events)\n' ...
                '  vs equilibrium (%.4f): deviation = %.3f, p = %.4g\n' ...
                '  vs unbiased 50%%: deviation = %.3f, p = %.4g'], ...
                Sp.nComplexes, Sp.nEvents, Sp.pObservedHigh, Sp.ciOnsetBoot(1), Sp.ciOnsetBoot(2), Sp.kHigh, Sp.nEvents, ...
                lastPEquilibriumHigh, Sp.betaEquilibrium, Sp.pEquilibrium, Sp.beta50, Sp.p50);
        end

        statsArea.Value = strsplit(statsText, newline);
    end

    function exportSweepCsv()
        if isempty(lastSweepResults)
            return;
        end

        % 'Sample' and 'Analyzed events' lead every row so rows copy-pasted
        % together from separate exports (different channels and/or event
        % filters) keep their data identity instead of becoming
        % indistinguishable numbers once combined into one sheet.
        %
        % CI columns use the same convention as every other module's result
        % log (see pipeline.buildFitControls/buildGaussianFitControls): one
        % "<Name> 95% BootstrapCI" column holding a formatted "[lower,
        % upper]" string (pipeline.formatCI), not separate LB/UB columns --
        % this deliberately departs from the original script's exact header
        % text for consistency across the app.
        if strcmp(lastAlignment, 'dissociation')
            header = {'Sample', 'Analyzed events', 'Frame Analyzed', 'Threshold', 'bootstraps', '# complexes', '# events', ...
                'high FRET (HF) rate', 'HF rate 95% BootstrapCI', ...
                'Low FRET (LF) rate', 'LF rate 95% BootstrapCI', ...
                'LF/HF Rate ratio', 'ratio 95% BootstrapCI'};
            rows = cell(numel(lastSweepResults), numel(header));
            for ik = 1:numel(lastSweepResults)
                S = lastSweepResults(ik);
                rows(ik, :) = {lastChName, lastTypeLabel, S.label, lastFretThreshold, lastBootN, S.nComplexes, S.nEvents, ...
                    S.probHigh, pipeline.formatCI(S.ciHigh(1), S.ciHigh(2)), ...
                    S.probLow, pipeline.formatCI(S.ciLow(1), S.ciLow(2)), ...
                    S.probRatio, pipeline.formatCI(S.ciProbRatio(1), S.ciProbRatio(2))};
            end
            suggested = sprintf('%s_%s_dissociationHazard_frameSweep', lastChName, strrep(lastTypeLabel, ' ', ''));
        else
            header = {'Sample', 'Analyzed events', 'Frame Analyzed', 'Threshold', 'bootstraps', '# complexes', '# events', ...
                'Start in high FRET', 'high FRET ratio', 'high FRET ratio 95% BootstrapCI', ...
                'Aggregate (equilibrium) Occupancy, high FRET'};
            rows = cell(numel(lastSweepResults), numel(header));
            for im = 1:numel(lastSweepResults)
                S = lastSweepResults(im);
                rows(im, :) = {lastChName, lastTypeLabel, S.label, lastFretThreshold, lastBootN, S.nComplexes, S.nEvents, ...
                    S.kHigh, S.pObservedHigh, pipeline.formatCI(S.ciOnsetBoot(1), S.ciOnsetBoot(2)), ...
                    lastPEquilibriumHigh};
            end
            suggested = sprintf('%s_%s_associationPreference_frameSweep', lastChName, strrep(lastTypeLabel, ' ', ''));
        end

        [fname, fpath] = uiputfile('*.csv', 'Export frame-sweep results as', [suggested '.csv']);
        if isequal(fname, 0)
            return;
        end

        try
            pipeline.writeCsvTable(fullfile(fpath, fname), header, rows);
        catch ME
            uialert(app.UIFigure, ME.message, 'Export failed');
        end
    end

    function name = suggestedPlotName()
        name = sprintf('AssocDissoc_%s_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''), lastAlignment);
    end

    function exportBothPlots()
        %EXPORTBOTHPLOTS One button, one save-location prompt, exports both
        % plots (heatmap and frame-sweep) as separate .fig/.png/.eps
        % triplets -- '_heatmap'/'_frameSweep' appended to whatever base
        % name the user picks -- rather than a second independent Export
        % Plot... button, matching every other module's one-button
        % convention despite this module having two plots to export.
        [fname, fpath] = uiputfile('*.eps', 'Export plots (.fig/.png/.eps saved for both)', [suggestedPlotName() '.eps']);
        if isequal(fname, 0)
            return;
        end
        [~, name, ~] = fileparts(fname);
        baseName = fullfile(fpath, name);
        % Explicit forceSquare overrides: the heatmap's time-vs-FRET data
        % has a meaningful non-square shape (landscape); the sweep plot is
        % conceptually the same "points + error bars" shape as
        % pipeline.exportCombinedOverlay's panels (square) even though its
        % LIVE view isn't literally axis(barAx,'square') -- that would
        % pillarbox it inside its recently-widened container, which is
        % deliberately non-square on screen.
        pipeline.exportPlot(ax, MODULE_NAME, [baseName '_heatmap'], [], false);
        pipeline.exportPlot(barAx, MODULE_NAME, [baseName '_frameSweep'], [], true);
    end
end

function txt = pLabel(p)
if p < 0.001
    txt = 'p < 0.001';
else
    txt = sprintf('p = %.3g', p);
end
end
