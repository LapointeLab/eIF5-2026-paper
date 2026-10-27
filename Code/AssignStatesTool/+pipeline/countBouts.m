function n = countBouts(vec)
%COUNTBOUTS Number of contiguous runs of an assigned (nonzero) state in
% VEC. Generalizes the ON-event counter in ExampleCode/LL_AssignStates_v1.m
% (which counted gaps between indices of a binary column) to any state
% encoding, via a standard run-start count.
%
%   n = countBouts(vec)

isOn = vec(:) ~= 0;
d = diff([false; isOn; false]);
n = sum(d == 1);

end
