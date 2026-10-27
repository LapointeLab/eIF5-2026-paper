function result = fitExponential(X, Y, order, opts)
%FITEXPONENTIAL Fit a single- or double-exponential CDF model via the Curve
%Fitting Toolbox (the same engine cftool wraps).
%
%   result = fitExponential(X, Y, order, opts)
%
%   X, Y  : data to fit (e.g. quantized cdfcalc output). Row or column vectors.
%   order : 1 (single exponential) or 2 (double exponential)
%   opts  : struct, fields:
%             b0     - initial guess for rate b (default 0.1)
%             d0     - initial guess for rate d, order==2 only (default 0.01)
%             robust - true/false, use bisquare robust fitting (default false)
%
%   Models (fit directly to the CDF, not the survival function):
%     order==1:  y = 1 - exp(-b*(x+f))                                  [a fixed = 1]
%     order==2:  y = a*(1 - exp(-b*(x+f))) + (1-a)*(1 - exp(-d*(x+f)))
%       a = proportion of observed events, bounded [0,1]. Single-exponential
%           fits assume every event belongs to the one population, so a is
%           fixed at 1 rather than fitted (there is nothing for a second
%           term to compete with).
%       b, d = rate constants (s^-1), bounded > 0
%       f = fudge factor, unconstrained
%
%   result fields:
%     order        as given
%     equation     human-readable equation string
%     fitobject    cfit object (callable, e.g. result.fitobject(x))
%     gof          goodness-of-fit struct from fit() (rsquare, adjrsquare, rmse, sse)
%     coeffNames   cell array of coefficient names actually fit, e.g. {'b','f'} for order 1
%     coeffValues  struct mapping name -> value, always including 'a' (fixed
%                  at 1 with no CI when order==1, fitted when order==2) so
%                  callers don't need to special-case single vs double.
%     coeffCI      struct mapping name -> [lower upper] 95% confidence interval;
%                  coeffCI.a = [NaN NaN] when order==1, since a is fixed, not fitted.
%     nPoints      numel(X)
%
%   Shared across modules: any analysis needing single/double exponential
%   CDF fitting should call this rather than reimplementing it.

if nargin < 4
    opts = struct();
end
if ~isfield(opts, 'b0') || isempty(opts.b0)
    opts.b0 = 0.1;
end
if ~isfield(opts, 'd0') || isempty(opts.d0)
    opts.d0 = 0.01;
end
if ~isfield(opts, 'robust') || isempty(opts.robust)
    opts.robust = false;
end

X = X(:);
Y = Y(:);

switch order
    case 1
        ft = fittype('1-exp(-b*(x+f))', 'independent', 'x', 'coefficients', {'b', 'f'});
        startPoint = [opts.b0, 0];
        lower      = [0, -Inf];
        upper      = [Inf, Inf];
        equation   = 'y = 1 - exp(-b*(x+f))   [a fixed = 1]';
    case 2
        ft = fittype('a*(1-exp(-b*(x+f)))+(1-a)*(1-exp(-d*(x+f)))', ...
            'independent', 'x', 'coefficients', {'a', 'b', 'd', 'f'});
        startPoint = [1, opts.b0, opts.d0, 0];
        lower      = [0, 0, 0, -Inf];
        upper      = [1, Inf, Inf, Inf];
        equation   = 'y = a*(1 - exp(-b*(x+f))) + (1-a)*(1 - exp(-d*(x+f)))';
    otherwise
        error('pipeline:fitExponential:invalidOrder', 'order must be 1 (single) or 2 (double), got %g.', order);
end

fo = fitoptions('Method', 'NonlinearLeastSquares', 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);
if opts.robust
    fo.Robust = 'Bisquare';
end

[fitobject, gof] = fit(X, Y, ft, fo);

names  = coeffnames(fitobject);
values = coeffvalues(fitobject);
ci     = confint(fitobject);   % 2 x numel(names): [lower; upper]

coeffValues = struct();
coeffCI     = struct();
for i = 1:numel(names)
    coeffValues.(names{i}) = values(i);
    coeffCI.(names{i})     = ci(:, i)';
end

if order == 1
    % Not a fitted parameter for the single-exponential model; fixed by
    % assumption, so no confidence interval applies. Populated anyway so
    % callers can treat coeffValues.a/coeffCI.a uniformly across order 1 and 2.
    coeffValues.a = 1;
    coeffCI.a     = [NaN, NaN];
end

result.order        = order;
result.equation     = equation;
result.fitobject    = fitobject;
result.gof          = gof;
result.coeffNames   = names;
result.coeffValues  = coeffValues;
result.coeffCI      = coeffCI;
result.nPoints      = numel(X);
result.optsUsed     = opts;   % resolved (defaults filled in); lets callers (e.g. a bootstrap) reuse identical settings

end
