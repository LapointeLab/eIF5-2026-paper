function [FRET_hazard, dissociate_hazard, eventID_hazard, moleculeID_hazard] = buildDissociationHazardData(segments, molIDs, k, startFrameRel)
%BUILDDISSOCIATIONHAZARDDATA Per-frame (FRET, "did dissociation happen next") pairs for one predictor-frame offset.
%   [FRET_hazard, dissociate_hazard, eventID_hazard, moleculeID_hazard] = buildDissociationHazardData(segments, molIDs, k, startFrameRel)
%
%   Adapted from ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m.
%   For each event, walks every frame from startFrameRel up to (roughly)
%   the event's last frame, pairing that frame's FRET value with whether
%   dissociation occurred k frames later:
%     k == 0 : the terminal frame predicts itself (every frame from
%              startFrameRel to the event's last frame; outcome = true
%              only on the last frame itself). This is the original,
%              potentially time-censored definition (the last recorded
%              frame's dissociation "prediction" trivially came true by
%              construction, and might not reflect the true dissociation
%              instant if the event was cut off by the movie ending).
%     k >= 1 : frame position predicts dissociation k frames ahead (the
%              event's last frame is excluded as a predictor -- an event
%              shorter than k+1 frames contributes nothing for this k).
%
%   segments, molIDs : as from pipeline.extractEventSegmentsWithBoundary
%                       (or pipeline.extractEventSegments; molIDs from evList.mol).
%   k               : 0 = terminal frame; N>=1 = N frames before the
%                     terminal frame.
%   startFrameRel   : first frame position (1-based, within the event) to
%                     include as a predictor.
%
%   FRET_hazard       : column vector, FRET value at each predictor frame.
%   dissociate_hazard : column vector (logical), whether dissociation
%                       occurred k frames after that predictor frame.
%   eventID_hazard    : column vector, index into segments each row came from.
%   moleculeID_hazard : column vector, molecule ID each row came from.

FRET_hazard       = [];
dissociate_hazard = [];
eventID_hazard     = [];
moleculeID_hazard   = [];

for ev = 1:numel(segments)
    E = segments{ev};
    lastRel = numel(E);
    molID = molIDs(ev);

    if k == 0
        frames = (startFrameRel:lastRel)';
        outcome = (frames == lastRel);
    else
        if lastRel < (k + 1)
            continue;
        end
        frames = (startFrameRel:(lastRel - k))';
        outcome = ((frames + k) == lastRel);
    end

    FRET_hazard       = [FRET_hazard; E(frames)]; %#ok<AGROW>
    dissociate_hazard = [dissociate_hazard; outcome]; %#ok<AGROW>
    eventID_hazard     = [eventID_hazard; repmat(ev, numel(frames), 1)]; %#ok<AGROW>
    moleculeID_hazard   = [moleculeID_hazard; repmat(molID, numel(frames), 1)]; %#ok<AGROW>
end

end
