function durations = runLengthDurations(state, targetState, exposure)
%RUNLENGTHDURATIONS Durations of each contiguous run of a target state.
%   durations = runLengthDurations(state, targetState, exposure)
%
%   state       : vector of integer state labels, one per frame (e.g. from
%                 thresholding a trace into low/high state at each frame).
%   targetState : which state label's run lengths to return.
%   exposure    : seconds per frame; converts frame counts to seconds.
%
%   durations   : row vector, one entry per contiguous run of targetState
%                 found in state, in seconds, in the order the runs occur.

state = state(:);
durations = [];
if isempty(state)
    return;
end

runStarts = [1; find(diff(state) ~= 0) + 1];
runEnds   = [runStarts(2:end) - 1; numel(state)];
runStates = state(runStarts);

isTarget  = runStates == targetState;
durations = ((runEnds(isTarget) - runStarts(isTarget) + 1) * exposure)';

end
