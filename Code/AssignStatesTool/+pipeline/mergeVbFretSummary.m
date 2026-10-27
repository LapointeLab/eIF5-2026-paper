function states = mergeVbFretSummary(ttotal, states, channelNames, nChPerMol, vbfretPath, threshold)
%MERGEVBFRETSUMMARY Threshold vbFRET's idealized path and write it into
% the FRET channel's column of STATES. Function form of
% ExampleCode/assign_states_vbFRET.m's logic, generalized off that
% script's hardcoded "3*i+1" column offset (which assumed exactly 3
% channels/molecule) to arbitrary nChPerMol via pipeline.getMolCols, and
% auto-detecting the FRET channel by name instead of assuming it's always
% the 3rd column.
%
%   states = mergeVbFretSummary(ttotal, states, channelNames, nChPerMol, vbfretPath, threshold)
%
%   vbfretPath : the `path` cell array from vbFRET's Analysis Summary
%                export (one cell per molecule, each a per-frame
%                idealized FRET trace).
%   threshold  : scalar; frames with idealized FRET > threshold are
%                assigned state 1, else state 0.

fretIdx = pipeline.findChannelIndex(channelNames, 'fret');
if isempty(fretIdx)
    error('mergeVbFretSummary:noFretChannel', ...
        'No channel name containing ''fret'' found in channelNames.');
end

assignedStates = double(cell2mat(vbfretPath) > threshold);

nMol = size(assignedStates, 2);
expectedMol = (size(ttotal, 2) - 1) / nChPerMol;
if nMol ~= expectedMol
    error('mergeVbFretSummary:molCountMismatch', ...
        'vbFRET path has %d molecule(s) but ttotal implies %d.', nMol, expectedMol);
end
if size(assignedStates, 1) ~= size(ttotal, 1)
    error('mergeVbFretSummary:frameCountMismatch', ...
        'vbFRET path has %d frame(s) but ttotal has %d.', size(assignedStates, 1), size(ttotal, 1));
end

molCols  = pipeline.getMolCols(1:nMol, nChPerMol);
fretCols = molCols(fretIdx:nChPerMol:end);

states(:, fretCols) = assignedStates;

end
