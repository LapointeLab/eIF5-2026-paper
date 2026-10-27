function fretEvolution(app)
%FRETEVOLUTION Per-event FRET trajectories right after binding onset.
%   Module function: takes the AnalysisPipelineApp instance. Adapted from
%   ExampleCode/LL_TIRF_Plot_FRET_Evolution_v2.m: for each included event,
%   plots the channel's raw value over its bound duration (one line per
%   event, semi-transparent so overlapping traces show density), skipping
%   the first and last frame of the event as transition artifacts and
%   color-coding each trace by its value at the second frame.
%
%   Unlike the original script, which assumed a `fret_time_series` matrix
%   already existed in the base workspace (one column per event, aligned so
%   row 1 = that event's binding onset, NaN-padded past its offset), this
%   module pulls each event's bound-duration segment directly from
%   app.Data — see pipeline.extractEventSegments.
%
%   Purely a visualization module: no fitting, no fit log. Requires
%   app.Data.result (see +pipeline/extractEvents.m).

MODULE_NAME = 'FRET Evolution';

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

uilabel(pg, 'Text', 'Max frames to plot:');
maxFramesField = uieditfield(pg, 'numeric', 'Value', 11, 'Limits', [2 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Min event frames:');
minFramesField = uieditfield(pg, 'numeric', 'Value', 6, 'Limits', [3 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Number of lines:');
numLinesField = uieditfield(pg, 'numeric', 'Value', 200, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Line transparency:');
alphaField = uieditfield(pg, 'numeric', 'Value', 0.2, 'Limits', [0 1], ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Line width:');
lineWidthField = uieditfield(pg, 'numeric', 'Value', 4, 'Limits', [0.1 Inf], ...
    'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Orange range:');
orangeGrid = uigridlayout(pg, [1 2]);
orangeGrid.Padding = [0 0 0 0];
orangeGrid.ColumnSpacing = 4;
orangeMinField = uieditfield(orangeGrid, 'numeric', 'Value', 0, 'ValueChangedFcn', @(~, ~) runAnalysis());
orangeMaxField = uieditfield(orangeGrid, 'numeric', 'Value', 0.6, 'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Blue range:');
blueGrid = uigridlayout(pg, [1 2]);
blueGrid.Padding = [0 0 0 0];
blueGrid.ColumnSpacing = 4;
blueMinField = uieditfield(blueGrid, 'numeric', 'Value', 0.61, 'ValueChangedFcn', @(~, ~) runAnalysis());
blueMaxField = uieditfield(blueGrid, 'numeric', 'Value', 1.2, 'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Y-axis min:');
yMinField = uieditfield(pg, 'numeric', 'Value', 0, 'ValueChangedFcn', @(~, ~) runAnalysis());

uilabel(pg, 'Text', 'Y-axis max:');
yMaxField = uieditfield(pg, 'numeric', 'Value', 1.2, 'ValueChangedFcn', @(~, ~) runAnalysis());

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

        cla(ax);

        if isempty(evList)
            title(ax, sprintf('%s - %s: no data', chName, typeLabel));
            return;
        end

        segments = pipeline.extractEventSegments(app, chName, evList);

        maxFrames  = maxFramesField.Value;
        minFrames  = minFramesField.Value;
        numLines   = numLinesField.Value;
        lineAlpha  = alphaField.Value;
        lineWidth  = lineWidthField.Value;
        orangeMin  = orangeMinField.Value;
        orangeMax  = orangeMaxField.Value;
        blueMin    = blueMinField.Value;
        blueMax    = blueMaxField.Value;

        hold(ax, 'on');
        linesPlotted = 0;
        for i = 1:numel(segments)
            if linesPlotted >= numLines
                break;
            end

            seg = segments{i};
            validIdx = find(~isnan(seg));
            if numel(validIdx) < minFrames
                continue;
            end

            startIdx = validIdx(2);
            endIdx   = validIdx(end - 1);
            plotEnd  = min(startIdx + maxFrames - 2, endIdx);

            secondVal = seg(validIdx(2));
            if secondVal >= orangeMin && secondVal <= orangeMax
                lineColor = [0.80, 0.40, 0.00, lineAlpha];
            elseif secondVal >= blueMin && secondVal <= blueMax
                lineColor = [0.00, 0.20, 0.60, lineAlpha];
            else
                continue;
            end

            % UserData carries the alpha value separately because Line.Color
            % never exposes the 4th (alpha) element on read-back, even
            % though passing it to 'Color' at creation does render it --
            % pipeline.exportPlot needs this to reproduce the transparency
            % when reconstructing the plot on a fresh axes for export.
            plot(ax, startIdx:plotEnd, seg(startIdx:plotEnd), 'Color', lineColor, 'LineWidth', lineWidth, ...
                'UserData', lineAlpha);
            linesPlotted = linesPlotted + 1;
        end
        hold(ax, 'off');

        pipeline.applyAxesStyle(ax);
        xlim(ax, [2, maxFrames]);
        ylim(ax, [yMinField.Value, yMaxField.Value]);
        xlabel(ax, 'Frame (relative to binding onset)');
        ylabel(ax, 'FRET Efficiency');
        title(ax, sprintf('%s - %s (n = %d traces)', chName, typeLabel, linesPlotted));
    end

    function name = suggestedPlotName()
        name = sprintf('FRETEvolution_%s_%s', lastChName, strrep(lastTypeLabel, ' ', ''));
    end
end
