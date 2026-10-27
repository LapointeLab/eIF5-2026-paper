function [segments, preFrameVal, postFrameVal, molIDs] = extractEventSegmentsWithBoundary(app, chName, evList)
%EXTRACTEVENTSEGMENTSWITHBOUNDARY Per-event ON-duration segments, plus the
%one frame immediately before/after each event.
%   [segments, preFrameVal, postFrameVal, molIDs] = extractEventSegmentsWithBoundary(app, chName, evList)
%
%   Generalizes pipeline.extractEventSegments with the one extra piece of
%   context the association/dissociation conformation analysis needs: the
%   channel's value on the single unbound frame immediately before an
%   event starts (for start-aligned/association analysis) and immediately
%   after it ends (for end-aligned/dissociation analysis).
%
%   app    : AnalysisPipelineApp instance (needs app.Data).
%   chName : channel name (must resolve against app.Data.channelNames, the
%            ORIGINAL unfiltered list -- see pipeline.extractEvents).
%   evList : event struct array (e.g. from pipeline.filterEventsByType).
%
%   segments    : 1xnumel(evList) cell array; segments{i} is the same
%                 bound-duration column vector pipeline.extractEventSegments
%                 would return for evList(i).
%   preFrameVal : 1xnumel(evList), the channel's value one frame before
%                 evList(i).onFrame, or NaN if the event starts at frame 1
%                 (no prior frame exists).
%   postFrameVal: 1xnumel(evList), the channel's value one frame after
%                 evList(i).offFrame, or NaN if the event ends on the last
%                 recorded frame.
%   molIDs      : 1xnumel(evList), evList(i).mol for each event (returned
%                 for convenience, since callers doing molecule-level
%                 statistics need it alongside segments/pre/post anyway).

origIdx   = find(strcmp(app.Data.channelNames, chName), 1);
nChPerMol = app.Data.nChPerMol;
ttotal    = app.Data.ttotal;
nFrames   = app.Data.result.nFrames;

nEvents     = numel(evList);
segments    = cell(1, nEvents);
preFrameVal = nan(1, nEvents);
postFrameVal = nan(1, nEvents);
molIDs      = [evList.mol];

for i = 1:nEvents
    mol = evList(i).mol;
    col = origIdx + 1 + (mol - 1) * nChPerMol;
    onFrame  = evList(i).onFrame;
    offFrame = evList(i).offFrame;

    segments{i} = ttotal(onFrame:offFrame, col);

    if onFrame - 1 >= 1
        preFrameVal(i) = ttotal(onFrame - 1, col);
    end
    if offFrame + 1 <= nFrames
        postFrameVal(i) = ttotal(offFrame + 1, col);
    end
end

end
