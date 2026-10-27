function fretHeatmap(app)
%FRETHEATMAP Post-synchronized time x FRET-efficiency heatmap for a chosen channel.
%   Module function: takes the AnalysisPipelineApp instance. Adapted from
%   ExampleCode/LL_TIRF_Plot_FRET_Heatmap_v2.m: pools an ensemble of traces
%   aligned to each included event's own binding onset (t = 0), bins each
%   relative-time slice into a FRET-efficiency histogram, and renders the
%   result as a filled contour heatmap (time x FRET efficiency x frequency).
%
%   Unlike the original script, this module builds its own synchronized
%   trace matrix directly from app.Data.result's event list (the original
%   assumed a `fret_time_series_all` matrix already existed in the base
%   workspace) — see pipeline.extractSyncedTraces. Each event's FULL
%   continuous trace is used (not just its bound-frame portion), so the
%   heatmap can show FRET evolving both before and after the sync point.
%
%   Purely a visualization module: no fitting, no fit log. Requires
%   app.Data.result (see +pipeline/extractEvents.m).
%
%   Parameters split into three responsiveness tiers:
%     - Channel, Events, Time bin, Intensity bins: change the underlying
%       data, so trigger a full re-extract + re-bin (raw, unsmoothed;
%       cached as the "raw" matrix).
%     - Smoothing on/off, Smoothing width: re-applies (or skips)
%       pipeline.smoothHeatmap2D on the cached raw matrix — no re-binning.
%     - Contour levels, Color scale (auto/manual + its fields), X-window
%       start/end: pure display parameters, applied by replotting the
%       already-computed matrix — instant, no recomputation at all.

MODULE_NAME = 'Post-Sync FRET Heatmap';

% Colorblind-friendly light-gray-to-blue sequential colormap, matching the
% original example script.
BLUE_ANCHORS = [245 245 245; 222 235 247; 210 227 243; 198 219 239; ...
                178 210 232; 158 202 225; 132 188 219; 107 174 214; ...
                86 160 206; 66 146 198; 49 129 189; 33 113 181; ...
                20 97 168; 8 81 156; 8 64 131; 8 48 107] / 255;

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

contentGrid = uigridlayout(layout, [1 2]);
contentGrid.Layout.Row = 2;
contentGrid.ColumnWidth = {'1x', 260};
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [0 0 0 0];

ax = uiaxes(contentGrid);

paramsPanel = uipanel(contentGrid, 'Title', 'Parameters');

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

% --- Parameters panel ---
pg = uigridlayout(paramsPanel, [11 2]);
pg.RowHeight = repmat({'fit'}, 1, 11);
pg.ColumnWidth = {'fit', '1x'};
pg.RowSpacing = 6;

uilabel(pg, 'Text', 'Time bin (frames):');
tBinField = uieditfield(pg, 'numeric', 'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Intensity bins:');
iBinsField = uieditfield(pg, 'numeric', 'Value', 50, 'Limits', [2 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

smoothCheckbox = uicheckbox(pg, 'Text', 'Enable smoothing', 'Value', false, ...
    'ValueChangedFcn', @(~, ~) toggleSmoothing());
smoothCheckbox.Layout.Column = [1 2];

uilabel(pg, 'Text', 'Smoothing (bins):');
smoothField = uieditfield(pg, 'numeric', 'Value', 1, 'Limits', [0 Inf], 'Enable', 'off', ...
    'ValueChangedFcn', @(~, ~) applySmoothingAndReplot());

uilabel(pg, 'Text', 'Contour levels:');
levelsField = uieditfield(pg, 'numeric', 'Value', 100, 'Limits', [2 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) replotOnly());

manualColorCheckbox = uicheckbox(pg, 'Text', 'Manual color scale', 'Value', false, ...
    'ValueChangedFcn', @(~, ~) toggleColorMode());
manualColorCheckbox.Layout.Column = [1 2];

uilabel(pg, 'Text', 'Color cap %ile:');
colorCapField = uieditfield(pg, 'numeric', 'Value', 99, 'Limits', [1 100], ...
    'ValueChangedFcn', @(~, ~) replotOnly());

uilabel(pg, 'Text', 'Color min:');
colorMinField = uieditfield(pg, 'numeric', 'Value', 0, 'Enable', 'off', ...
    'ValueChangedFcn', @(~, ~) replotOnly());

uilabel(pg, 'Text', 'Color max:');
colorMaxField = uieditfield(pg, 'numeric', 'Value', 1, 'Enable', 'off', ...
    'ValueChangedFcn', @(~, ~) replotOnly());

uilabel(pg, 'Text', 'Window start (s):');
winStartField = uieditfield(pg, 'numeric', 'Value', -0.1, ...
    'ValueChangedFcn', @(~, ~) replotOnly());

uilabel(pg, 'Text', 'Window end (s):');
winEndField = uieditfield(pg, 'numeric', 'Value', 1, ...
    'ValueChangedFcn', @(~, ~) replotOnly());

% Cached state. lastZRaw is the unsmoothed count matrix (expensive to
% produce: extraction + binning); lastZ is what's currently displayed
% (either lastZRaw itself or a smoothed copy of it) — cheap to recompute
% from lastZRaw whenever the smoothing toggle/width changes.
lastZRaw = [];
lastZ = [];
lastTimeAxis = [];
lastIntensityAxis = [];
lastChName = '';
lastTypeLabel = '';

runAnalysis();

    function runAnalysis()
        chName    = chDropdown.Value;
        typeValue = eventTypeDropdown.Value;
        typeLabel = eventTypeDropdown.Items{strcmp(eventTypeDropdown.ItemsData, typeValue)};
        lastChName = chName;
        lastTypeLabel = typeLabel;

        chIdx     = find(strcmp(app.Data.result.channelNames, chName), 1);
        evListAll = app.Data.result.events{chIdx};
        evList    = pipeline.filterEventsByType(evListAll, typeValue);

        if isempty(evList)
            cla(ax);
            title(ax, sprintf('%s - %s: no data', chName, typeLabel));
            lastZRaw = []; lastZ = []; lastTimeAxis = []; lastIntensityAxis = [];
            return;
        end

        [M, relFrameAxis] = pipeline.extractSyncedTraces(app, chName, evList);
        [Z, timeAxis, intensityAxis] = pipeline.buildSyncHeatmap(M, relFrameAxis, app.Data.result.Exposure, ...
            tBinField.Value, iBinsField.Value, 0);   % always raw here; smoothing applied separately below

        lastZRaw = Z;
        lastTimeAxis = timeAxis;
        lastIntensityAxis = intensityAxis;

        applySmoothingAndReplot();
    end

    function toggleSmoothing()
        smoothField.Enable = smoothCheckbox.Value;
        applySmoothingAndReplot();
    end

    function applySmoothingAndReplot()
        if isempty(lastZRaw)
            return;
        end
        if smoothCheckbox.Value
            lastZ = pipeline.smoothHeatmap2D(lastZRaw, smoothField.Value);
        else
            lastZ = lastZRaw;
        end
        replotOnly();
    end

    function toggleColorMode()
        colorCapField.Enable = ~manualColorCheckbox.Value;
        colorMinField.Enable = manualColorCheckbox.Value;
        colorMaxField.Enable = manualColorCheckbox.Value;
        replotOnly();
    end

    function replotOnly()
        if isempty(lastZ)
            return;
        end

        cla(ax);
        levels = max(2, round(levelsField.Value));
        contourf(ax, lastTimeAxis, lastIntensityAxis, lastZ, levels, 'LineStyle', 'none');

        x_anchors = linspace(0, 1, size(BLUE_ANCHORS, 1));
        x_full = linspace(0, 1, 256);
        ax.Colormap = interp1(x_anchors, BLUE_ANCHORS, x_full, 'pchip');

        if manualColorCheckbox.Value
            cmin = colorMinField.Value;
            cmax = max(colorMaxField.Value, cmin + 1e-9);
        else
            positiveVals = lastZ(lastZ > 0);
            if isempty(positiveVals)
                cmin = 0; cmax = 1;
            else
                cmin = 0;
                cmax = prctile(positiveVals, colorCapField.Value);
                if isnan(cmax) || cmax <= 0
                    cmax = max(lastZ(:));
                end
            end
            % Seed the manual fields with the current auto-computed range,
            % so switching to manual mode starts from what's already shown
            % instead of jumping to stale/default values.
            colorMinField.Value = cmin;
            colorMaxField.Value = cmax;
        end
        ax.CLim = [cmin cmax];

        pipeline.applyAxesStyle(ax);
        xlim(ax, [winStartField.Value, winEndField.Value]);
        ylim(ax, [0 1]);
        xlabel(ax, 'Time (s)');
        ylabel(ax, 'FRET Efficiency');
        title(ax, sprintf('%s - %s', lastChName, lastTypeLabel));

        cb = colorbar(ax);
        cb.Label.String = 'Frequency';
    end

    function name = suggestedPlotName()
        name = sprintf('FRETHeatmap_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
    end
end
