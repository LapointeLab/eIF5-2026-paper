function placeImagePanel(pngPath, destFig, slotPosition, label, captionHeight)
%PLACEIMAGEPANEL Place a previously-exported .png (see pipeline.exportPlot)
%into one panel of a composite figure (see +modules/summaryFigure.m), as a
%plain raster image.
%
%   pipeline.placeImagePanel(pngPath, destFig, slotPosition, label, captionHeight)
%
%   pngPath       : path to a .png previously written by pipeline.exportPlot
%                   (600 DPI, transparent background, already carrying this
%                   app's full publication styling -- gray axes, Arial
%                   Narrow text, correctly alpha-blended semi-transparent
%                   lines, colorbar sizing, everything this app's
%                   individual-panel export was tuned for).
%   destFig       : the composite figure to place the panel into. Must have
%                   Units 'inches' -- slotPosition/captionHeight are both
%                   in that same unit, in absolute inches (not normalized
%                   0-1 fractions), since pipeline.buildSummaryComposite
%                   computes the whole figure's final size FROM the panels
%                   it places rather than fitting panels into a
%                   predetermined page.
%   slotPosition  : [x y w h] in inches, the panel's own image box (NOT
%                   including its caption above -- see captionHeight). The
%                   image is letterboxed/pillarboxed to fit inside this
%                   box at its own true aspect ratio (never stretched),
%                   then centered within it.
%   label         : panel label string (e.g. 'A: Binding Lifetime
%                   Kinetics -- S1'), placed in a caption strip above the
%                   image.
%   captionHeight : height in inches of that caption strip, spanning the
%                   image's full width, immediately above slotPosition.
%
%   Deliberately simple: a .png is the FINAL, exact pixels of a panel this
%   app already spent a lot of tuning on (see pipeline.exportPlot) -- an
%   earlier version of this tool instead re-derived each panel's graphics
%   objects from its .fig (pipeline.placeFigPanel, now removed) so the
%   composite's own .eps export could stay true vector, but that
%   reconstruction couldn't perfectly reproduce every formatting detail
%   (font scaling, line widths, alpha handling...) and drifted visibly
%   from the individual export it was supposed to match. Placing the .png
%   as-is guarantees the summary panel looks IDENTICAL to that export, at
%   the cost of the composite's own .eps embedding a raster (not true
%   vector) for each panel.

[img, ~, alpha] = imread(pngPath);
imgH = size(img, 1);
imgW = size(img, 2);
imgAspect = imgW / imgH;

slotAspect = slotPosition(3) / slotPosition(4);
if imgAspect > slotAspect
    % image is relatively wider than the slot -- fit to width, letterbox vertically
    w = slotPosition(3);
    h = w / imgAspect;
else
    h = slotPosition(4);
    w = h * imgAspect;
end
x = slotPosition(1) + (slotPosition(3) - w) / 2;
y = slotPosition(2) + (slotPosition(4) - h) / 2;

ax = axes(destFig, 'Units', 'inches', 'Position', [x, y, w, h]);
h_img = image(ax, img);
if ~isempty(alpha)
    % pipeline.exportPlot writes a transparent-background PNG (no white
    % box to delete before placing the panel elsewhere) -- without this,
    % the "transparent" pixels' arbitrary underlying RGB values (often
    % black) would paint over the composite's own white page background
    % instead of blending into it.
    h_img.AlphaData = double(alpha) / 255;
end
axis(ax, 'off');
axis(ax, 'image');

if nargin >= 4 && ~isempty(label)
    if nargin < 5 || isempty(captionHeight)
        captionHeight = 0.35;
    end
    % Interpreter 'none': label's distinguishing part comes straight from
    % a source filename (pipeline.scanSummaryFigures), which routinely has
    % underscores -- the default TeX interpreter reads "_x" as a subscript
    % operator, silently mangling the caption instead of showing it as
    % literal text.
    annotation(destFig, 'textbox', 'Units', 'inches', ...
        'Position', [slotPosition(1), slotPosition(2) + slotPosition(4), slotPosition(3), captionHeight], ...
        'String', label, 'FontSize', 9, 'FontWeight', 'bold', 'FontName', 'Arial', 'Interpreter', 'none', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'FitBoxToText', 'off');
end

end
