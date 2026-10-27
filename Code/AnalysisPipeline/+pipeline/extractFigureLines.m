function [lines, xLabelStr, yLabelStr] = extractFigureLines(figPath)
%EXTRACTFIGURELINES Read a .fig file's line data without displaying it.
%   [lines, xLabelStr, yLabelStr] = extractFigureLines(figPath)
%
%   Opens the figure invisibly, pulls every Line object from its first
%   axes, classifies each as a marker-point "data" series or a line-only
%   "fit" series -- the convention every plot this app exports already
%   follows (see pipeline.plotCDFMarkers for data markers, and
%   pipeline.buildFitControls / pipeline.buildGaussianFitControls for fit
%   curves) -- and closes the source figure again. Works on any .fig
%   following that marker-vs-line convention, not just ones this app
%   produced.
%
%   lines : struct array, one entry per Line object found, fields:
%     XData, YData  : as in the source line
%     isData        : true if Marker ~= 'none' (a data-point series);
%                     false for a line-only series (e.g. a fit curve)
%   xLabelStr, yLabelStr : the source axes' XLabel/YLabel strings, so a
%     caller combining several files can suggest axis labels from the
%     first one read rather than starting blank.
%
%   Returns an empty 0x0 struct array (with these fields) and empty label
%   strings if the file has no axes or no line children (e.g. a
%   contour/heatmap-only figure -- this function is for combining
%   single-series data+fit plots like the CDF/histogram modules produce,
%   not multi-line or contour plots).

fig = openfig(figPath, 'invisible');
cleanupObj = onCleanup(@() close(fig));

lines = struct('XData', {}, 'YData', {}, 'isData', {});
xLabelStr = '';
yLabelStr = '';

axArray = findobj(fig, 'Type', 'axes');
if isempty(axArray)
    return;
end
ax = axArray(1);
xLabelStr = ax.XLabel.String;
yLabelStr = ax.YLabel.String;

srcLines = findobj(ax, 'Type', 'line');
for i = 1:numel(srcLines)
    sl = srcLines(i);
    lines(end+1).XData = sl.XData; %#ok<AGROW>
    lines(end).YData   = sl.YData;
    lines(end).isData  = ~strcmp(sl.Marker, 'none');
end

end
