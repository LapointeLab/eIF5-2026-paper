function h = plotCDFMarkers(ax, X, Y, color)
%PLOTCDFMARKERS Plot CDF-style data as open circles with a thick edge.
%   h = plotCDFMarkers(ax, X, Y, color)
%   Shared marker style so CDF (and similar) plots look consistent across
%   modules. color defaults to black; pass an RGB triplet when multiple
%   series share one axes and need to stay visually distinct (e.g.
%   +modules/lifetimeSorting.m's Short/Long overlay).

if nargin < 4 || isempty(color)
    color = 'k';
end

h = plot(ax, X, Y, 'o', 'MarkerSize', 7, 'MarkerEdgeColor', color, ...
    'MarkerFaceColor', 'none', 'LineWidth', 1.5, 'LineStyle', 'none');

end
