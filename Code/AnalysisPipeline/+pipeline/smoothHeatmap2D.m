function Zs = smoothHeatmap2D(Z, sigma)
%SMOOTHHEATMAP2D Separable 2D Gaussian smoothing via conv2 with replicate-
%padded boundaries (matching imgaussfilt's default Padding behavior) — no
%Image Processing Toolbox dependency (avoids relying on imgaussfilt itself).
%Plain zero-padded 'same' convolution would artificially dim bins near the
%edges of a matrix, which matters here since real data mass often sits
%close to an edge (e.g. a FRET population near 0 or 1).
%
%   Zs = smoothHeatmap2D(Z, sigma)
%   sigma : standard deviation, in bins, of the Gaussian kernel. sigma <= 0
%           returns Z unchanged.
%
%   Shared so pipeline.buildSyncHeatmap and any module that needs to toggle
%   smoothing on/off (or retune it) without re-binning from scratch can both
%   apply this same smoothing step to an already-computed count matrix.

if sigma <= 0
    Zs = Z;
    return;
end

radius = max(1, ceil(3 * sigma));
x = -radius:radius;
kernel = exp(-(x .^ 2) / (2 * sigma ^ 2));
kernel = kernel / sum(kernel);

rowIdx = [ones(1, radius), 1:size(Z, 1), size(Z, 1) * ones(1, radius)];
colIdx = [ones(1, radius), 1:size(Z, 2), size(Z, 2) * ones(1, radius)];
Zpad = Z(rowIdx, colIdx);

Zs = conv2(kernel(:), kernel(:)', Zpad, 'valid');

end
