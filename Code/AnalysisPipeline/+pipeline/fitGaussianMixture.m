function result = fitGaussianMixture(X, Y, nGaussians, opts)
%FITGAUSSIANMIXTURE Fit a sum of Gaussians to histogram data via the Curve
%Fitting Toolbox's built-in gauss1..gauss4 library models (the same engine
%cftool wraps).
%
%   result = fitGaussianMixture(X, Y, nGaussians, opts)
%
%   X, Y       : histogram bin centers and (normalized) heights.
%   nGaussians : 1, 2, 3, or 4.
%   opts       : struct, fields:
%                  meanGuess - 1xnGaussians vector of initial mean guesses
%                              (default: evenly spaced across [0,1])
%                  robust    - true/false, use bisquare robust fitting (default false)
%
%   Model: y = sum_{i=1}^{nGaussians} a_i * exp(-((x-b_i)/c_i)^2)
%     a_i = amplitude, b_i = mean (bounded to [0,1]), c_i relates to the
%     standard deviation by c_i = sigma_i * sqrt(2) (MATLAB's library
%     Gaussian parameterization, not the same as the usual sigma directly).
%
%   Components are returned SORTED by fitted mean, ascending, so "component
%   1" consistently means "the lowest-mean population" regardless of
%   whatever coefficient order the underlying optimizer converged to.
%
%   result fields:
%     nGaussians
%     equation       human-readable equation string
%     fitobject      cfit object (callable, e.g. result.fitobject(x))
%     gof            goodness-of-fit struct from fit() (rsquare, adjrsquare, rmse, sse)
%     means, means_CI     nGaussians x 1, nGaussians x 2 (95% CI [lower upper])
%     stds, stds_CI       nGaussians x 1, nGaussians x 2
%     amps, amps_CI       nGaussians x 1, nGaussians x 2 (amplitude; not a
%                         primary reported quantity, kept for plotting/context)
%     pops                nGaussians x 1, each component's population: its
%                         fraction of the fitted curve's total area,
%                         a_i*c_i / sum_j(a_j*c_j) (the integral of a_i*exp(...)
%                         is a_i*c_i*sqrt(pi); the sqrt(pi) cancels). Sums to
%                         1. No fit CI (a ratio of fitted coefficients);
%                         pipeline.bootstrapGaussianCI gives its bootstrap CI.
%     optsUsed
%
%   Shared across modules: any analysis needing multi-Gaussian histogram
%   fitting should call this rather than reimplementing it.

if nargin < 4
    opts = struct();
end
if ~isfield(opts, 'meanGuess') || isempty(opts.meanGuess)
    opts.meanGuess = linspace(0.2, 0.8, nGaussians);
end
if ~isfield(opts, 'robust') || isempty(opts.robust)
    opts.robust = false;
end
if numel(opts.meanGuess) ~= nGaussians
    error('pipeline:fitGaussianMixture:meanGuessMismatch', ...
        'opts.meanGuess must have one value per Gaussian (%d expected, %d given).', ...
        nGaussians, numel(opts.meanGuess));
end
if nGaussians < 1 || nGaussians > 4
    error('pipeline:fitGaussianMixture:invalidOrder', 'nGaussians must be 1-4, got %g.', nGaussians);
end

X = X(:);
Y = Y(:);

ft = fittype(sprintf('gauss%d', nGaussians));

ampGuess   = max(Y) / nGaussians;
widthGuess = 0.1;   % initial guess for c (~ sigma*sqrt(2))

startPoint = zeros(1, 3 * nGaussians);
lower      = zeros(1, 3 * nGaussians);
upper      = zeros(1, 3 * nGaussians);
for i = 1:nGaussians
    idx = (i - 1) * 3;
    startPoint(idx + 1) = ampGuess;
    startPoint(idx + 2) = opts.meanGuess(i);
    startPoint(idx + 3) = widthGuess;
    lower(idx + 1) = 0;    upper(idx + 1) = Inf;   % amplitude > 0
    lower(idx + 2) = 0;    upper(idx + 2) = 1;     % mean confined to FRET efficiency range
    lower(idx + 3) = 0;    upper(idx + 3) = Inf;   % width > 0
end

fo = fitoptions('Method', 'NonlinearLeastSquares', 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);
if opts.robust
    fo.Robust = 'Bisquare';
end

[fitobject, gof] = fit(X, Y, ft, fo);

coeffs = coeffvalues(fitobject);
ci     = confint(fitobject);   % 2 x 3*nGaussians, columns matching coeffnames order a1,b1,c1,a2,b2,c2,...

amps    = coeffs(1:3:end);
means   = coeffs(2:3:end);
widthsC = coeffs(3:3:end);
stds    = widthsC / sqrt(2);

ampsCI  = [ci(1, 1:3:end)', ci(2, 1:3:end)'];
meansCI = [ci(1, 2:3:end)', ci(2, 2:3:end)'];
stdsCI  = [ci(1, 3:3:end)', ci(2, 3:3:end)'] / sqrt(2);

[means, order] = sort(means);
amps    = amps(order);
stds    = stds(order);
ampsCI  = ampsCI(order, :);
meansCI = meansCI(order, :);
stdsCI  = stdsCI(order, :);
widthsC = widthsC(order);

areas = amps .* widthsC;
pops  = areas / sum(areas);

result.nGaussians = nGaussians;
result.equation   = sprintf('y = sum of %d Gaussian(s): a_i * exp(-((x-b_i)/c_i)^2)', nGaussians);
result.fitobject  = fitobject;
result.gof        = gof;
result.means      = means(:);
result.means_CI   = meansCI;
result.stds       = stds(:);
result.stds_CI    = stdsCI;
result.amps       = amps(:);
result.amps_CI    = ampsCI;
result.pops       = pops(:);
result.optsUsed   = opts;

end
