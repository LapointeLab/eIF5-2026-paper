function h = plotPointCI(ax, xPos, value, ci)
%PLOTPOINTCI Black point-estimate+95%-CI marker at xPos, layered on top of
% a group's jittered points (see pipeline.plotJitteredPoints) so the
% summary statistic reads as distinct from the raw data it was computed
% from.
%
%   h = plotPointCI(ax, xPos, value, ci)
%
%   value : the point estimate (a mean, a median, whatever statistic ci
%           is a bootstrap interval for).
%   ci    : [lower upper] 95% CI, e.g. from pipeline.bootstrapMeanCI's
%           .ci or pipeline.bootstrapMedianCI's .ci.
%
%   Deliberately generic over which point estimate is being plotted --
%   +modules/eventSorting.m plots a bootstrap MEAN this way,
%   +modules/donorAcceptorCorrelation.m a bootstrap MEDIAN (Pearson r is
%   bounded and often skewed, so median is the more robust summary there)
%   -- the marker itself doesn't need to know or care which.
h = errorbar(ax, xPos, value, value - ci(1), ci(2) - value, ...
    'LineStyle', 'none', 'Marker', 's', 'MarkerSize', 8, 'LineWidth', 1.5, 'CapSize', 8, ...
    'Color', 'k', 'MarkerFaceColor', 'k');
end
