function [onsetFRET, moleculeID_onset] = buildAssociationOnsetData(segments, molIDs, m)
%BUILDASSOCIATIONONSETDATA FRET value at the m-th frame of each event long enough to have one.
%   [onsetFRET, moleculeID_onset] = buildAssociationOnsetData(segments, molIDs, m)
%
%   Adapted from ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m.
%   Frame 1 is an event's binding-onset frame (potentially time-censored,
%   e.g. by localization/tracking lag); frame 2 is the first "clean" one.
%
%   segments, molIDs : as from pipeline.extractEventSegmentsWithBoundary
%                       (or pipeline.extractEventSegments; molIDs from evList.mol).
%   m               : which frame position (1-based, within the event) to sample.
%
%   onsetFRET        : column vector, FRET value at frame m of each event
%                       with at least m frames.
%   moleculeID_onset : column vector, molecule ID each row came from.

onsetFRET        = [];
moleculeID_onset = [];

for ev = 1:numel(segments)
    E = segments{ev};
    lastRel = numel(E);
    molID = molIDs(ev);

    if lastRel >= m
        onsetFRET(end+1, 1)        = E(m); %#ok<AGROW>
        moleculeID_onset(end+1, 1) = molID; %#ok<AGROW>
    end
end

end
