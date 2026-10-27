function [startF, finishF] = regionToFrames(x1, x2, t)
%REGIONTOFRAMES Convert two x-axis click positions (in the units of the
% time vector T) into clamped frame indices, low-to-high. Uses interp1
% against T directly (rather than assuming a fixed frame interval, as
% ExampleCode/LL_AssignStates_MultiColor.m's regionToFrames did via
% round(x/t(1))) so it also works for non-uniform sampling.
%
%   [startF, finishF] = regionToFrames(x1, x2, t)

lo = min(x1, x2);
hi = max(x1, x2);

startF  = max(1,         round(interp1(t, 1:numel(t), lo, 'linear', 'extrap')));
finishF = min(numel(t),  round(interp1(t, 1:numel(t), hi, 'linear', 'extrap')));

end
