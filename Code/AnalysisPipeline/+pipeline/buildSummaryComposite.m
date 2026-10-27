function compFig = buildSummaryComposite(pngPaths, moduleNames)
%BUILDSUMMARYCOMPOSITE Build the multi-panel composite figure for
%+modules/summaryFigure.m, from a list of previously-exported .png files.
%   compFig = buildSummaryComposite(pngPaths, moduleNames)
%
%   pngPaths, moduleNames : parallel cell arrays, one entry per LOADED
%   panel (pipeline.scanSummaryFigures already expands every matching file
%   into its own entry, so this can be a large list), in the order panels
%   should be placed (top-left to bottom-right, row-major). Each panel is
%   placed as a raster image by pipeline.placeImagePanel and labeled
%   "<letter>: <name>", A/B/C... (then AA/AB... past 26) assigned in that
%   same order.
%
%   Panel size is FIXED regardless of how many panels there are -- the
%   page grows taller to fit more rows instead of shrinking panels to fit
%   a fixed page. This tool pulls in every matching export
%   (pipeline.scanSummaryFigures), which for an active dataset can
%   legitimately mean dozens of panels (several event-type filters per
%   module, both directions of Association/Dissociation Conformations,
%   etc.), and a summary meant for scrolling through digitally has no
%   reason to fit a printed page -- shrinking panels to force that would
%   make the whole thing illegible. Width is capped at a fixed number of
%   columns instead, so panels stay comfortably sized left-to-right too.
%
%   Returns the figure handle (Visible off, Units 'inches'); the caller is
%   responsible for both displaying/capturing it (a live preview) and
%   closing it once done -- this function does not save or close it
%   itself, so the same composite can be reused for both a preview render
%   and the final .png/.eps export without rebuilding it twice.

MAX_COLS = 4;
PAGE_W = 11;
PANEL_H = 2.6;
MARGIN_X = 0.4;
MARGIN_Y_TOP = 0.3;
MARGIN_Y_BOTTOM = 0.3;
GAP_X = 0.3;
GAP_Y = 0.35;
CAPTION_H = 0.4;

n = numel(pngPaths);
if numel(moduleNames) ~= n
    error('pipeline:buildSummaryComposite:sizeMismatch', 'pngPaths and moduleNames must be the same length.');
end

if n == 0
    compFig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', 'Position', [0 0 PAGE_W 1]);
    return;
end

% sqrt(n) gives a roughly square grid; clamped to at least 1 column and at
% most MAX_COLS so panels never get impractically narrow on a wide run.
NCOLS = min(MAX_COLS, max(1, ceil(sqrt(n))));
NROWS = ceil(n / NCOLS);

panelW = (PAGE_W - 2 * MARGIN_X - (NCOLS - 1) * GAP_X) / NCOLS;
rowStride = PANEL_H + CAPTION_H + GAP_Y;
PAGE_H = MARGIN_Y_TOP + MARGIN_Y_BOTTOM + NROWS * (PANEL_H + CAPTION_H) + (NROWS - 1) * GAP_Y;

compFig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', 'Position', [0 0 PAGE_W PAGE_H]);

for i = 1:n
    row = floor((i - 1) / NCOLS);
    col = mod(i - 1, NCOLS);
    x = MARGIN_X + col * (panelW + GAP_X);
    yPanelTop = PAGE_H - MARGIN_Y_TOP - CAPTION_H - row * rowStride;
    yPanelBottom = yPanelTop - PANEL_H;
    label = sprintf('%s: %s', pipeline.panelLetter(i), moduleNames{i});
    pipeline.placeImagePanel(pngPaths{i}, compFig, [x, yPanelBottom, panelW, PANEL_H], label, CAPTION_H);
end

end
