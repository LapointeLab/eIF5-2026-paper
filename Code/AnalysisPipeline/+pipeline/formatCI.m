function s = formatCI(lo, hi)
%FORMATCI Format a confidence interval as one compact "[lower, upper]"
% string, for a single CSV column per CI rather than separate Lower/Upper
% columns. Returns "" if either bound is NaN (e.g. a Gaussian component
% beyond the fitted count, or an order-1 exponential fit's unused second
% rate).
if isnan(lo) || isnan(hi)
    s = "";
else
    s = string(sprintf('[%.4g, %.4g]', lo, hi));
end
end
