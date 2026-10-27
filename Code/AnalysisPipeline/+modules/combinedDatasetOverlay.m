function combinedDatasetOverlay(app)
%COMBINEDDATASETOVERLAY Overlay multiple previously-exported .fig datasets
%into one publication-ready comparison plot.
%   Module function: takes the AnalysisPipelineApp instance. Unlike every
%   other module, this one does NOT require app.Data to be loaded -- it
%   works directly from .fig files exported earlier (by this app's own
%   "Export Plot..." buttons, or any other .fig with the same convention:
%   open-circle markers for data, a plain line for a fit curve), so it can
%   combine datasets from different sessions or different source files.
%
%   Each of up to 10 rows lets you pick a .fig file, name the sample, and
%   choose its color. "Combine & Plot" reads every configured row (see
%   pipeline.extractFigureLines) and overlays them on the live preview,
%   recoloring each sample's data markers and fit line to its assigned
%   color -- everything else about their appearance is standardized so the
%   combined plot looks like one consistent figure rather than a patchwork
%   of each source file's individual style.
%
%   Reading 10 files is nontrivial I/O, and most row edits (renaming,
%   recoloring) don't need it repeated, so combining is a deliberate
%   button rather than auto-triggered on every keystroke, unlike this
%   app's data-driven modules. Display settings (axis labels/ranges, log
%   scale, legend) ARE live against the already-combined data, since
%   changing them needs no file re-read.
%
%   "Export Publication Plot..." (pipeline.exportCombinedOverlay) applies
%   this module's specific fixed publication styling (a constant
%   112.5x112.5pt axes box, dark-gray thin axis lines, outward ticks,
%   black Arial Narrow text, transparent background) rather than the
%   generic per-module styling pipeline.exportPlot gives everything else.

MODULE_NAME = 'Combined Dataset Overlay';
NUM_ROWS = 10;

DEFAULT_COLORS = [
    0.000 0.447 0.741   % blue
    0.850 0.325 0.098   % orange
    0.466 0.674 0.188   % green
    0.494 0.184 0.556   % purple
    0.929 0.694 0.125   % gold
    0.301 0.745 0.933   % cyan
    0.635 0.078 0.184   % dark red
    0.850 0.098 0.600   % magenta
    0.467 0.286 0.070   % brown
    0.000 0.500 0.400   % teal
];

tab = app.getOrCreateTab(MODULE_NAME);

contentGrid = uigridlayout(tab, [1 2]);
contentGrid.ColumnWidth = {440, '1x'};
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [8 8 8 8];

configGrid = uigridlayout(contentGrid, [3 1]);
configGrid.RowHeight = {'1x', 'fit', 'fit'};
configGrid.RowSpacing = 8;
configGrid.Padding = [0 0 0 0];

ax = uiaxes(contentGrid);

% --- Datasets panel: up to NUM_ROWS rows of [Load...][file][name][color][x] ---
datasetsPanel = uipanel(configGrid, 'Title', 'Datasets (.fig files)');
datasetsPanel.Scrollable = 'on';
rowsGrid = uigridlayout(datasetsPanel, [NUM_ROWS 5]);
rowsGrid.RowHeight = repmat({30}, 1, NUM_ROWS);
rowsGrid.ColumnWidth = {60, '1x', 140, 34, 26};
rowsGrid.RowSpacing = 4;
rowsGrid.ColumnSpacing = 6;

% Each row's selected file path lives in rowFileLabels(i).UserData (not a
% private closure variable) so it's externally readable/settable -- lets
% tests (and any future scripting) drive a row without going through the
% blocking uigetfile dialog in onLoadRow.
rowFileLabels = gobjects(1, NUM_ROWS);
rowNameFields = gobjects(1, NUM_ROWS);
rowColorBtns  = gobjects(1, NUM_ROWS);

for i = 1:NUM_ROWS
    uibutton(rowsGrid, 'Text', 'Load...', 'ButtonPushedFcn', @(~, ~) onLoadRow(i));

    rowFileLabels(i) = uilabel(rowsGrid, 'Text', 'No file', 'FontAngle', 'italic', ...
        'FontColor', [0.55 0.55 0.55], 'UserData', '');

    rowNameFields(i) = uieditfield(rowsGrid, 'text', 'Value', '', ...
        'Placeholder', sprintf('Sample %d', i));

    rowColorBtns(i) = uibutton(rowsGrid, 'Text', '', ...
        'BackgroundColor', DEFAULT_COLORS(mod(i - 1, size(DEFAULT_COLORS, 1)) + 1, :), ...
        'ButtonPushedFcn', @(~, ~) onPickColor(i));

    uibutton(rowsGrid, 'Text', char(215), 'Tooltip', 'Clear this row', ...
        'ButtonPushedFcn', @(~, ~) onClearRow(i));
end

% --- Plot settings panel ---
settingsPanel = uipanel(configGrid, 'Title', 'Plot Settings');
sg = uigridlayout(settingsPanel, [8 2]);
sg.RowHeight = repmat({'fit'}, 1, 8);
sg.ColumnWidth = {'fit', '1x'};
sg.RowSpacing = 6;

uilabel(sg, 'Text', 'X label:');
xLabelField = uieditfield(sg, 'text', 'Value', '', 'ValueChangedFcn', @(~, ~) renderPreview());

uilabel(sg, 'Text', 'Y label:');
yLabelField = uieditfield(sg, 'text', 'Value', '', 'ValueChangedFcn', @(~, ~) renderPreview());

uilabel(sg, 'Text', 'Title (optional):');
titleField = uieditfield(sg, 'text', 'Value', '', 'ValueChangedFcn', @(~, ~) renderPreview());

uilabel(sg, 'Text', 'X-axis:');
xScaleSwitch = uiswitch(sg, 'slider', 'Items', {'Linear', 'Log'}, 'Value', 'Linear', ...
    'ValueChangedFcn', @(~, ~) renderPreview());

autoXCheckbox = uicheckbox(sg, 'Text', 'Auto X range', 'Value', true, ...
    'ValueChangedFcn', @(~, ~) toggleRangeEnable());
autoXCheckbox.Layout.Column = [1 2];

xRangeGrid = uigridlayout(sg, [1 2]);
xRangeGrid.Layout.Column = [1 2];
xRangeGrid.Padding = [0 0 0 0];
xRangeGrid.ColumnSpacing = 4;
xMinField = uieditfield(xRangeGrid, 'numeric', 'Value', 0, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) renderPreview());
xMaxField = uieditfield(xRangeGrid, 'numeric', 'Value', 1, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) renderPreview());

autoYCheckbox = uicheckbox(sg, 'Text', 'Auto Y range', 'Value', true, ...
    'ValueChangedFcn', @(~, ~) toggleRangeEnable());
autoYCheckbox.Layout.Column = [1 2];

yRangeGrid = uigridlayout(sg, [1 2]);
yRangeGrid.Layout.Column = [1 2];
yRangeGrid.Padding = [0 0 0 0];
yRangeGrid.ColumnSpacing = 4;
yMinField = uieditfield(yRangeGrid, 'numeric', 'Value', 0, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) renderPreview());
yMaxField = uieditfield(yRangeGrid, 'numeric', 'Value', 1, 'Enable', 'off', 'ValueChangedFcn', @(~, ~) renderPreview());

showLegendCheckbox = uicheckbox(sg, 'Text', 'Show legend', 'Value', true, ...
    'ValueChangedFcn', @(~, ~) renderPreview());
showLegendCheckbox.Layout.Column = [1 2];

% --- Actions ---
actionGrid = uigridlayout(configGrid, [1 2]);
actionGrid.ColumnSpacing = 8;
actionGrid.Padding = [0 0 0 0];
uibutton(actionGrid, 'Text', 'Combine & Plot', 'ButtonPushedFcn', @(~, ~) combineAndPlot());
exportButton = uibutton(actionGrid, 'Text', 'Export Publication Plot...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportCombined());

lastDatasets = struct('SampleName', {}, 'Color', {}, 'DataX', {}, 'DataY', {}, 'FitX', {}, 'FitY', {});
labelsAutoFilled = false;

cla(ax);
title(ax, 'Load .fig files and click "Combine & Plot"');

    function onLoadRow(rowIdx)
        [fname, fpath] = uigetfile('*.fig', sprintf('Select .fig file for row %d', rowIdx));
        if isequal(fname, 0)
            return;
        end
        fullPath = fullfile(fpath, fname);
        rowFileLabels(rowIdx).UserData = fullPath;
        rowFileLabels(rowIdx).Text = fname;
        rowFileLabels(rowIdx).Tooltip = fullPath;
        rowFileLabels(rowIdx).FontAngle = 'normal';
        rowFileLabels(rowIdx).FontColor = [0 0 0];
        if isempty(rowNameFields(rowIdx).Value)
            [~, baseName] = fileparts(fname);
            rowNameFields(rowIdx).Value = baseName;
        end
    end

    function onPickColor(rowIdx)
        c = uisetcolor(rowColorBtns(rowIdx).BackgroundColor, sprintf('Color for row %d', rowIdx));
        if ~isequal(c, 0)
            rowColorBtns(rowIdx).BackgroundColor = c;
        end
    end

    function onClearRow(rowIdx)
        rowFileLabels(rowIdx).UserData = '';
        rowFileLabels(rowIdx).Text = 'No file';
        rowFileLabels(rowIdx).Tooltip = '';
        rowFileLabels(rowIdx).FontAngle = 'italic';
        rowFileLabels(rowIdx).FontColor = [0.55 0.55 0.55];
        rowNameFields(rowIdx).Value = '';
    end

    function toggleRangeEnable()
        xMinField.Enable = ~autoXCheckbox.Value;
        xMaxField.Enable = ~autoXCheckbox.Value;
        yMinField.Enable = ~autoYCheckbox.Value;
        yMaxField.Enable = ~autoYCheckbox.Value;
        renderPreview();
    end

    function combineAndPlot()
        datasets = struct('SampleName', {}, 'Color', {}, 'DataX', {}, 'DataY', {}, 'FitX', {}, 'FitY', {});
        anyFailed = false;

        for rowIdx = 1:NUM_ROWS
            rowPath = rowFileLabels(rowIdx).UserData;
            if isempty(rowPath)
                continue;
            end

            try
                [srcLines, xLbl, yLbl] = pipeline.extractFigureLines(rowPath);
            catch ME
                app.log(sprintf('%s: failed to read "%s": %s', MODULE_NAME, rowPath, ME.message));
                anyFailed = true;
                continue;
            end

            if isempty(srcLines)
                app.log(sprintf('%s: "%s" has no line data to plot (skipped).', MODULE_NAME, rowPath));
                continue;
            end

            if ~labelsAutoFilled
                if isempty(xLabelField.Value) && ~isempty(xLbl)
                    xLabelField.Value = xLbl;
                end
                if isempty(yLabelField.Value) && ~isempty(yLbl)
                    yLabelField.Value = yLbl;
                end
                labelsAutoFilled = true;
            end

            name = rowNameFields(rowIdx).Value;
            if isempty(name)
                name = sprintf('Sample %d', rowIdx);
            end

            entry = struct('SampleName', name, 'Color', rowColorBtns(rowIdx).BackgroundColor, ...
                'DataX', [], 'DataY', [], 'FitX', [], 'FitY', []);

            dataIdx = find([srcLines.isData], 1);
            fitIdx  = find(~[srcLines.isData], 1);
            if ~isempty(dataIdx)
                entry.DataX = srcLines(dataIdx).XData;
                entry.DataY = srcLines(dataIdx).YData;
            end
            if ~isempty(fitIdx)
                entry.FitX = srcLines(fitIdx).XData;
                entry.FitY = srcLines(fitIdx).YData;
            end

            datasets(end + 1) = entry; %#ok<AGROW>
        end

        if isempty(datasets)
            uialert(app.UIFigure, 'No datasets loaded. Use "Load..." to pick at least one .fig file.', 'Nothing to combine');
            return;
        end

        lastDatasets = datasets;
        exportButton.Enable = 'on';
        renderPreview();

        if anyFailed
            app.log(sprintf('%s: some files could not be read; see log above.', MODULE_NAME));
        end
    end

    function renderPreview()
        if isempty(lastDatasets)
            return;
        end

        cla(ax);
        hold(ax, 'on');
        legHandles = gobjects(1, numel(lastDatasets));
        legLabels  = cell(1, numel(lastDatasets));
        for k = 1:numel(lastDatasets)
            d = lastDatasets(k);
            h = gobjects(0);
            if ~isempty(d.DataX)
                % 'Color' is set explicitly here too, not just
                % 'MarkerEdgeColor' -- otherwise MATLAB silently
                % auto-assigns Line.Color from the axes' default color
                % cycling (irrelevant to what's rendered, since
                % LineStyle='none' means MarkerEdgeColor governs the
                % marker's actual appearance either way, but leaving
                % Line.Color inconsistent with the intended sample color
                % is a needless footgun for anything that reads it back).
                h = plot(ax, d.DataX, d.DataY, 'o', 'MarkerSize', 6, 'MarkerEdgeColor', d.Color, ...
                    'MarkerFaceColor', 'none', 'LineWidth', 1, 'LineStyle', 'none', 'Color', d.Color);
            end
            if ~isempty(d.FitX)
                hFit = plot(ax, d.FitX, d.FitY, '-', 'Color', d.Color, 'LineWidth', 1.5);
                if isempty(h)
                    h = hFit;
                end
            end
            legHandles(k) = h;
            legLabels{k}  = d.SampleName;
        end
        hold(ax, 'off');

        pipeline.applyAxesStyle(ax);
        ax.XScale = lower(xScaleSwitch.Value);
        xlabel(ax, xLabelField.Value);
        ylabel(ax, yLabelField.Value);
        if ~isempty(titleField.Value)
            title(ax, titleField.Value);
        else
            title(ax, '');
        end

        if ~autoXCheckbox.Value
            ax.XLim = [xMinField.Value, max(xMaxField.Value, xMinField.Value + eps)];
        end
        if ~autoYCheckbox.Value
            ax.YLim = [yMinField.Value, max(yMaxField.Value, yMinField.Value + eps)];
        end

        if showLegendCheckbox.Value
            % 'best' (overlaying the data if needed) rather than
            % 'eastoutside': keeping the axes box a fixed, predictable
            % size matters more than avoiding legend/data overlap here --
            % an outside legend forces MATLAB to resize the axes to make
            % room for it, and the legend is trivial to reposition
            % afterward (e.g. in Illustrator) if it lands somewhere awkward.
            legend(ax, legHandles, legLabels, 'Location', 'best', 'Interpreter', 'none');
        else
            legend(ax, 'off');
        end
    end

    function exportCombined()
        if isempty(lastDatasets)
            return;
        end
        xLimVals = [];
        if ~autoXCheckbox.Value
            xLimVals = [xMinField.Value, max(xMaxField.Value, xMinField.Value + eps)];
        end
        yLimVals = [];
        if ~autoYCheckbox.Value
            yLimVals = [yMinField.Value, max(yMaxField.Value, yMinField.Value + eps)];
        end

        pipeline.exportCombinedOverlay(lastDatasets, xLabelField.Value, yLabelField.Value, ...
            titleField.Value, lower(xScaleSwitch.Value), xLimVals, yLimVals, showLegendCheckbox.Value, ...
            [], 'CombinedOverlay');
    end
end
