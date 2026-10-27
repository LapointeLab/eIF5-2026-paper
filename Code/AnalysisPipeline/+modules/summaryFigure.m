function summaryFigure(app)
%SUMMARYFIGURE Assemble a one-page, multi-panel summary figure from
%previously-exported .png files, automatically -- one panel per plot this
%app can produce, pulled straight from a folder.
%   Module function: takes the AnalysisPipelineApp instance. Like
%   +modules/combinedDatasetOverlay.m, this does NOT require app.Data to be
%   loaded -- it works entirely from .png files exported earlier by this
%   app's own "Export Plot..." / "Export All Plots..." buttons, so it can
%   pull panels from different sessions or different source datasets.
%
%   "Choose Folder..." picks a directory; "Scan Folder" (see
%   pipeline.scanSummaryFigures) looks for every module's exported .png by
%   its fixed module-tag filename suffix (pipeline.exportPlot /
%   pipeline.moduleFileTag -- automatic, not something the user has to name
%   files for) and reports what it found. EVERY matching file becomes its
%   own panel, not just the newest -- a plot type (module, or module +
%   sub-plot tag for one that exports more than one distinct plot, e.g.
%   Association/Dissociation Conformations' heatmap + frame-sweep) is
%   routinely exported more than once with genuinely different content (a
%   different channel, event-type filter, or the association vs.
%   dissociation direction), and this is meant to be exhaustive, not
%   curated: a folder with a lot of exports in it produces a large summary
%   page, which is fine -- this is meant for scrolling through digitally,
%   not fitting on a printed sheet. A plot type never exported in that
%   folder is simply skipped -- panel letters (A, B, C...) stay contiguous
%   across however many panels were actually found, in registry order.
%
%   Each panel is placed as a plain raster image -- the exact pixels
%   pipeline.exportPlot already wrote, not a re-derived copy -- so the
%   summary looks identical to that individual publication-tuned export
%   rather than an approximation of it. This is a deliberate simplicity-
%   over-vector-fidelity trade: an earlier version instead copied graphics
%   objects out of each module's .fig (pipeline.placeFigPanel, since
%   removed) so this composite's own .eps stayed true vector, but that
%   reconstruction visibly drifted from the individual exports (font
%   scaling, line widths, alpha handling each a fresh place to diverge).
%   The actual panel placement/layout is
%   pipeline.buildSummaryComposite / pipeline.placeImagePanel -- this
%   module is just the folder-scan UI and the preview/export wiring
%   around them.
%
%   "Generate Summary" builds the composite and shows a preview. "Export
%   Summary Figure..." saves that same composite as both .png (600 DPI)
%   and .eps -- the .eps embeds each panel as the same raster (not
%   re-vectorized), consistent with how the panels were placed.

MODULE_NAME = 'Summary Figure';

tab = app.getOrCreateTab(MODULE_NAME);

contentGrid = uigridlayout(tab, [1 2]);
contentGrid.ColumnWidth = {420, '1x'};
contentGrid.ColumnSpacing = 8;
contentGrid.Padding = [8 8 8 8];

leftGrid = uigridlayout(contentGrid, [3 1]);
leftGrid.RowHeight = {'fit', '1x', 'fit'};
leftGrid.RowSpacing = 8;
leftGrid.Padding = [0 0 0 0];

% --- Folder picker ---
folderGrid = uigridlayout(leftGrid, [1 3]);
folderGrid.ColumnWidth = {'fit', '1x', 'fit'};
folderGrid.Padding = [0 0 0 0];
folderGrid.ColumnSpacing = 6;
uibutton(folderGrid, 'Text', 'Choose Folder...', 'ButtonPushedFcn', @(~, ~) onChooseFolder());
folderLabel = uilabel(folderGrid, 'Text', 'No folder selected', 'FontAngle', 'italic', 'FontColor', [0.55 0.55 0.55]);
scanButton = uibutton(folderGrid, 'Text', 'Scan Folder', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) onScanFolder());

% --- Scan results (read-only: what was found, so auto-detection isn't a black box) ---
resultsPanel = uipanel(leftGrid, 'Title', 'Panels Found');
resultsGrid = uigridlayout(resultsPanel, [1 1]);
resultsGrid.Padding = [0 0 0 0];
resultsArea = uitextarea(resultsGrid, 'Value', {'Choose a folder and click "Scan Folder".'}, 'Editable', 'off');

% --- Actions ---
actionGrid = uigridlayout(leftGrid, [1 2]);
actionGrid.ColumnSpacing = 8;
actionGrid.Padding = [0 0 0 0];
uibutton(actionGrid, 'Text', 'Generate Summary', 'ButtonPushedFcn', @(~, ~) generateSummary());
exportButton = uibutton(actionGrid, 'Text', 'Export Summary Figure...', 'Enable', 'off', ...
    'ButtonPushedFcn', @(~, ~) exportSummary());

% --- Preview ---
previewAx = uiaxes(contentGrid);
previewAx.XTick = [];
previewAx.YTick = [];
previewAx.Box = 'on';
title(previewAx, 'Choose a folder, scan it, then click "Generate Summary"');

chosenFolder = '';
lastScanResults = [];
hasScanned = false;
lastCompositeFig = [];

    function onChooseFolder()
        folder = uigetdir(pwd, 'Choose folder containing exported .png files');
        if isequal(folder, 0)
            return;
        end
        chosenFolder = folder;
        folderLabel.Text = folder;
        folderLabel.Tooltip = folder;
        folderLabel.FontAngle = 'normal';
        folderLabel.FontColor = [0 0 0];
        scanButton.Enable = 'on';
    end

    function onScanFolder()
        [lastScanResults, notFoundLabels] = pipeline.scanSummaryFigures(chosenFolder);
        hasScanned = true;
        lines = cell(1, numel(lastScanResults) + numel(notFoundLabels));
        for k = 1:numel(lastScanResults)
            lines{k} = sprintf('[x] %s', lastScanResults(k).DisplayLabel);
        end
        for k = 1:numel(notFoundLabels)
            lines{numel(lastScanResults) + k} = sprintf('[ ] %s', notFoundLabels{k});
        end
        resultsArea.Value = lines;
        app.log(sprintf('%s: scanned "%s", found %d panel(s).', MODULE_NAME, chosenFolder, numel(lastScanResults)));
    end

    function generateSummary()
        if ~hasScanned
            uialert(app.UIFigure, 'Scan a folder first.', 'Nothing to summarize');
            return;
        end
        if isempty(lastScanResults)
            uialert(app.UIFigure, 'No panels found in this folder. Export some plots first, then re-scan.', 'Nothing to summarize');
            return;
        end

        loadedPaths = {lastScanResults.FilePath};
        loadedLabels = {lastScanResults.DisplayLabel};

        if ~isempty(lastCompositeFig) && isvalid(lastCompositeFig)
            close(lastCompositeFig);
        end

        try
            compFig = pipeline.buildSummaryComposite(loadedPaths, loadedLabels);
        catch ME
            uialert(app.UIFigure, ME.message, 'Generate failed');
            return;
        end
        lastCompositeFig = compFig;

        tmpPreview = [tempname '.png'];
        exportgraphics(compFig, tmpPreview, 'Resolution', 150);
        img = imread(tmpPreview);
        delete(tmpPreview);

        cla(previewAx);
        image(previewAx, img);
        previewAx.XTick = [];
        previewAx.YTick = [];
        previewAx.DataAspectRatio = [1 1 1];
        title(previewAx, sprintf('%d panel(s)', numel(loadedPaths)));

        exportButton.Enable = 'on';
        app.log(sprintf('%s: generated composite with %d panel(s).', MODULE_NAME, numel(loadedPaths)));
    end

    function exportSummary()
        if isempty(lastCompositeFig) || ~isvalid(lastCompositeFig)
            return;
        end
        [fname, fpath] = uiputfile('*.png', 'Export summary figure (.png and .eps both saved)', 'SummaryFigure.png');
        if isequal(fname, 0)
            return;
        end
        [~, name, ~] = fileparts(fname);
        baseName = fullfile(fpath, name);

        exportgraphics(lastCompositeFig, [baseName '.png'], 'Resolution', 600);
        % Each panel is already a placed raster image (pipeline.placeImagePanel),
        % so this .eps embeds that same raster per panel rather than
        % re-vectorizing it -- there's no line/marker content of its own on
        % this composite to need EPS's alpha workaround (contrast
        % pipeline.exportPlot, which draws real vector content).
        exportgraphics(lastCompositeFig, [baseName '.eps'], 'ContentType', 'vector');

        app.log(sprintf('%s: exported "%s.png" and "%s.eps".', MODULE_NAME, baseName, baseName));
    end

end
