function q = quantizeToExposure(values, exposure)
%QUANTIZETOEXPOSURE Round time values onto the nearest whole-frame (exposure) step.
%   q = quantizeToExposure(values, exposure)
%
%   Frame-count-based durations/times are only physically meaningful to
%   whole-frame resolution, but the recorded timestamp vector (ttotal
%   column 1) accumulates tiny floating-point error (~1e-15 scale) from
%   repeated addition across many frames. Left alone, that noise makes
%   cdfcalc's unique() treat physically identical durations as distinct
%   values, producing spurious extra points on eCDF plots. This collapses
%   that noise back onto the true frame grid before such analyses.
%
%   Shared across modules: any frame-count-based duration/time CDF is
%   expected to need this same cleanup.

q = round(values / exposure) * exposure;

end
