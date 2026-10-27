function h = plotJitteredPoints(ax, xPos, data, color, jitterHalfWidth)
%PLOTJITTEREDPOINTS Individual data points at xPos, spread by uniform
% horizontal jitter so overlapping values are still visible as distinct
% markers. Small filled circles (no edge), in a fixed pastel blend of
% color toward white to give a lighter-toned overlap cue. Unlike
% Line.Color, MarkerFaceColor rejects a 4-element RGBA both at plot()-call
% construction time and via a property assignment afterward ("Invalid RGB
% triplet") -- MATLAB Line markers have no real per-marker alpha support at
% all, so this pre-blends a flat, fully opaque color instead of true
% transparency (true alpha would require scatter(), which
% pipeline.exportPlot's reconstruction doesn't handle).
%
%   h = plotJitteredPoints(ax, xPos, data, color, jitterHalfWidth)
%
%   Shared by +modules/eventSorting.m and any other module plotting a
%   single group's raw values as a jittered column (e.g.
%   +modules/donorAcceptorCorrelation.m), so the visual convention and the
%   MarkerFaceColor-alpha workaround stay in one place.
POINT_BLEND = 0.35; % fraction of true color kept; rest is blended toward white
blendedColor = POINT_BLEND * color + (1 - POINT_BLEND) * [1 1 1];
data = data(:);
n = numel(data);
jitterX = xPos + (rand(n, 1) - 0.5) * 2 * jitterHalfWidth;
h = plot(ax, jitterX, data, 'o', 'LineStyle', 'none', 'MarkerSize', 3, ...
    'MarkerFaceColor', blendedColor, 'MarkerEdgeColor', 'none');
end
