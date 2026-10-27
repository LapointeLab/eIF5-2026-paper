function [Z, timeAxis, intensityAxis] = buildSyncHeatmap(M, relFrameAxis, Exposure, tBinFrames, iBins, smoothSigma)
%BUILDSYNCHEATMAP Bin a synchronized trace matrix into a 2D time x intensity histogram.
%   [Z, timeAxis, intensityAxis] = buildSyncHeatmap(M, relFrameAxis, Exposure, tBinFrames, iBins, smoothSigma)
%
%   M, relFrameAxis : as returned by pipeline.extractSyncedTraces.
%   Exposure        : seconds per frame, for converting relFrameAxis to time.
%   tBinFrames      : number of consecutive relative-frame rows pooled per
%                     time bin (1 = no pooling, finest time resolution).
%   iBins           : number of intensity bins spanning [0, 1].
%   smoothSigma     : standard deviation, in bins, of the 2D Gaussian
%                     smoothing kernel applied to the raw counts; 0 (or
%                     omitted) disables smoothing. NaN values in M (from
%                     the alignment padding) are ignored by the binning
%                     step, same as MATLAB's histcounts default behavior.
%
%   Z             : [iBins x numel(timeAxis)] matrix of (optionally
%                   smoothed) raw counts — not normalized, matching the
%                   original script's convention of relying on a
%                   percentile-capped color scale rather than per-column
%                   normalization.
%   timeAxis      : seconds, one value per output time bin (bin start).
%   intensityAxis : bin centers spanning [0, 1].
%
%   Shared so any future synchronized-ensemble heatmap can reuse the same
%   binning/smoothing math.

if nargin < 6 || isempty(smoothSigma)
    smoothSigma = 0;
end

nRel = numel(relFrameAxis);
nTimeBins = ceil(nRel / tBinFrames);

edges = linspace(0, 1, iBins + 1);
intensityAxis = (edges(1:end-1) + edges(2:end)) / 2;

Z = zeros(iBins, nTimeBins);
timeAxis = zeros(1, nTimeBins);

for b = 1:nTimeBins
    rowStart = (b - 1) * tBinFrames + 1;
    rowEnd   = min(b * tBinFrames, nRel);
    sliceVals = M(rowStart:rowEnd, :);
    Z(:, b) = histcounts(sliceVals(:), edges)';
    timeAxis(b) = relFrameAxis(rowStart) * Exposure;
end

if smoothSigma > 0
    Z = pipeline.smoothHeatmap2D(Z, smoothSigma);
end

end
