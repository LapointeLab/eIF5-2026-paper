function exportCombinedOverlay(datasets, xLabelText, yLabelText, titleText, xScale, xLimVals, yLimVals, showLegend, baseName, suggestedName)
%EXPORTCOMBINEDOVERLAY Export a multi-dataset overlay as a small,
%publication-ready panel (.fig/.png/.eps).
%   exportCombinedOverlay(datasets, xLabelText, yLabelText, titleText, xScale, xLimVals, yLimVals, showLegend, baseName, suggestedName)
%
%   datasets   : struct array, one entry per combined sample, fields:
%                  SampleName, Color (1x3 RGB)
%                  DataX, DataY  (data-point series; [] if this sample has none)
%                  FitX, FitY    (fit-curve series; [] if this sample has none)
%   xLabelText, yLabelText : axis label text.
%   titleText  : plot title text, or '' for no title (publication panels
%                usually don't carry one -- captions live in the paper text).
%   xScale     : 'linear' or 'log'.
%   xLimVals, yLimVals : [lo hi] to apply manually, or [] for auto.
%   showLegend : true/false.
%   baseName   : as in pipeline.exportPlot -- [] to prompt via uiputfile.
%   suggestedName : suggested filename when prompting.
%
%   Styling is fixed, not user-configurable -- unlike the generic
%   pipeline.exportPlot (used by every other module's single-dataset
%   plots), this module has its own specific publication requirements:
%     - a 112.5x112.5 point axes box (150x150 shrunk 25%; text and line
%       widths stay at their original size, so this only makes the
%       plotted area itself smaller, not what's drawn in it)
%     - 3pt data markers (4pt shrunk 25%)
%     - mid-to-dark gray (0.3,0.3,0.3) axis lines/ticks, 0.5pt wide
%     - ticks pointing outward, long enough to read clearly at this size
%     - Arial Narrow, black text (labels, tick labels, title), sized for
%       a small panel (legible but not oversized)
%     - transparent background (no white box to delete before placing the
%       panel into a paper figure), no grid, box off
%     - open-circle data markers, solid fit lines, each dataset's marker
%       and fit sharing its assigned color so a legend maps color -> sample
%     - legend placed WHEREVER MATLAB judges least likely to cover data
%       ('best'), free to overlap the plot -- keeping the axes box a fixed
%       size across exports matters far more than legend placement, which
%       is one drag in Illustrator; an outside-positioned legend, by
%       contrast, forces MATLAB to silently resize the axes to make room
%       for it, so 'best' is also what keeps the axes box genuinely
%       constant regardless of legend content.
%
%   Exports the whole temporary figure (not just the axes, as
%   pipeline.exportPlot does), consistent even though a 'best'-placed
%   legend no longer needs the wider crop an outside legend did.

if nargin < 9 || isempty(baseName)
    [fname, fpath] = uiputfile('*.eps', 'Export combined plot (.fig/.png/.eps all saved)', [char(suggestedName) '.eps']);
    if isequal(fname, 0)
        return;
    end
    [~, name, ~] = fileparts(fname);
    baseName = fullfile(fpath, name);
end

% Fixed module-identifying suffix, matching pipeline.exportPlot's own
% convention -- this function has exactly one caller
% (+modules/combinedDatasetOverlay.m), so the tag is hardcoded rather than
% threaded through as a parameter. Lets +modules/summaryFigure.m recover
% "this .fig came from Combined Dataset Overlay" by scanning a folder.
baseName = [baseName '_' pipeline.moduleFileTag('Combined Dataset Overlay')];

GRAY      = [0.3 0.3 0.3];
BLACK     = [0 0 0];
AXIS_SIZE = 112.5;   % points (150 shrunk 25%)
MARGIN_L  = 40;
MARGIN_B  = 32;
MARGIN_TR = 15;

figTmp = figure('Visible', 'off', 'Color', 'none', 'Units', 'points', ...
    'Position', [100 100, AXIS_SIZE + MARGIN_L + MARGIN_TR, AXIS_SIZE + MARGIN_B + MARGIN_TR]);
cleanupObj = onCleanup(@() close(figTmp));

axNew = axes(figTmp, 'Units', 'points');
axNew.Position = [MARGIN_L, MARGIN_B, AXIS_SIZE, AXIS_SIZE];

hold(axNew, 'on');
legHandles = gobjects(1, numel(datasets));
legLabels  = cell(1, numel(datasets));
for k = 1:numel(datasets)
    d = datasets(k);
    h = gobjects(0);
    if ~isempty(d.DataX)
        % 'Color' set explicitly alongside 'MarkerEdgeColor' -- otherwise
        % MATLAB silently auto-assigns Line.Color from the axes' default
        % color cycling instead (irrelevant to what's rendered, since
        % LineStyle='none' means MarkerEdgeColor governs the marker's
        % actual appearance, but leaves Line.Color inconsistent with the
        % intended sample color for anything that reads it back later).
        h = plot(axNew, d.DataX, d.DataY, 'o', 'MarkerSize', 3, 'MarkerEdgeColor', d.Color, ...
            'MarkerFaceColor', 'none', 'LineWidth', 0.5, 'LineStyle', 'none', 'Color', d.Color);
    end
    if ~isempty(d.FitX)
        hFit = plot(axNew, d.FitX, d.FitY, '-', 'Color', d.Color, 'LineWidth', 0.75);
        if isempty(h)
            h = hFit;
        end
    end
    legHandles(k) = h;
    legLabels{k}  = d.SampleName;
end
hold(axNew, 'off');

axNew.XScale     = xScale;
axNew.LineWidth  = 0.5;
axNew.XColor     = GRAY;
axNew.YColor     = GRAY;
axNew.TickDir    = 'out';
axNew.TickLength = [0.025, 0.025];
axNew.Box        = 'off';
axNew.XGrid      = 'off';
axNew.YGrid      = 'off';
axNew.FontSize   = 7;
axNew.FontName   = 'Arial Narrow';
axNew.Color      = 'none';

% Tick label TEXT is black, independent of the gray axis lines/tick marks
% above (ax.XColor/YColor govern the line+ticks; the ruler's own
% TickLabelColor governs just the number text and can be set separately).
axNew.XAxis.TickLabelColor = BLACK;
axNew.YAxis.TickLabelColor = BLACK;

xlabel(axNew, xLabelText, 'FontSize', 8, 'Color', BLACK);
ylabel(axNew, yLabelText, 'FontSize', 8, 'Color', BLACK);
if ~isempty(titleText)
    title(axNew, titleText, 'FontSize', 8, 'FontWeight', 'normal', 'Color', BLACK);
end

if ~isempty(xLimVals)
    axNew.XLim = xLimVals;
end
if ~isempty(yLimVals)
    axNew.YLim = yLimVals;
end

if showLegend && numel(datasets) > 0
    lg = legend(axNew, legHandles, legLabels, 'Location', 'best', ...
        'Box', 'off', 'FontSize', 6, 'Interpreter', 'none', 'TextColor', BLACK);
    lg.ItemTokenSize = [12, 10];
end

figTmp.Visible = 'on';
exportgraphics(figTmp, [baseName '.png'], 'Resolution', 600, 'BackgroundColor', 'none');
exportgraphics(figTmp, [baseName '.eps'], 'ContentType', 'vector', 'BackgroundColor', 'none');

% The .fig is for interactive editing/reuse, not a fixed print size the way
% .eps/.png (already exported above, at the true small panel size) need to
% be -- scale the whole figure up before saving it so it opens at a
% comfortable, clickable size instead of the tiny print-precise panel.
FIG_SCALE = 4;
figTmp.Position(3) = (AXIS_SIZE + MARGIN_L + MARGIN_TR) * FIG_SCALE;
figTmp.Position(4) = (AXIS_SIZE + MARGIN_B + MARGIN_TR) * FIG_SCALE;
axNew.Position = [MARGIN_L, MARGIN_B, AXIS_SIZE, AXIS_SIZE] * FIG_SCALE;
% Color 'none' (transparent, for the .eps/.png already exported above) is
% only meaningful for image export -- an actually-opened, on-screen .fig
% renders a 'none' figure/axes as solid black, making the black
% text/markers/lines invisible against it. A .fig is meant to be viewed and
% edited in MATLAB, so it gets a normal white background instead.
figTmp.Color = 'white';
axNew.Color = 'white';
scalableProps = {'LineWidth', 'MarkerSize', 'CapSize'};
for p = 1:numel(scalableProps)
    scaledObjs = findall(figTmp, '-property', scalableProps{p});
    for k = 1:numel(scaledObjs)
        scaledObjs(k).(scalableProps{p}) = scaledObjs(k).(scalableProps{p}) * FIG_SCALE;
    end
end
% FontSize is set to a flat value, not scaled by FIG_SCALE like the other
% properties above -- scaling the small panel's 6/7/8pt text by 4x is too
% large once the figure itself is also 4x bigger; 18pt reads comfortably at
% this figure size regardless of what the small-panel size was.
FIG_FONT_SIZE = 18;
fontObjs = findall(figTmp, '-property', 'FontSize');
for k = 1:numel(fontObjs)
    fontObjs(k).FontSize = FIG_FONT_SIZE;
end
savefig(figTmp, [baseName '.fig']);

end
