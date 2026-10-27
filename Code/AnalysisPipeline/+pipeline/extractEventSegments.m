function segments = extractEventSegments(app, chName, evList)
%EXTRACTEVENTSEGMENTS Per-event ON-duration trace segments for a channel.
%   segments = extractEventSegments(app, chName, evList)
%
%   For each event in evList, pulls that molecule's raw channel trace over
%   exactly its bound duration (onFrame:offFrame). Unlike
%   pipeline.extractSyncedTraces, which keeps each event's FULL recording
%   for ensemble alignment against a common relative-time axis, this keeps
%   only the ON-state span itself — what a per-event "evolution right after
%   binding" plot needs, with no cross-event alignment or padding.
%
%   app    : AnalysisPipelineApp instance (needs app.Data).
%   chName : channel name (must resolve against app.Data.channelNames, the
%            ORIGINAL unfiltered list, since ttotal's column layout follows
%            that order — see pipeline.extractEvents).
%   evList : event struct array (e.g. from pipeline.filterEventsByType).
%
%   segments : 1xnumel(evList) cell array; segments{i} is a column vector
%              of length evList(i).offFrame - evList(i).onFrame + 1, row 1
%              corresponding to evList(i).onFrame.

origIdx   = find(strcmp(app.Data.channelNames, chName), 1);
nChPerMol = app.Data.nChPerMol;
ttotal    = app.Data.ttotal;

nEvents  = numel(evList);
segments = cell(1, nEvents);

for i = 1:nEvents
    mol = evList(i).mol;
    col = origIdx + 1 + (mol - 1) * nChPerMol;
    segments{i} = ttotal(evList(i).onFrame:evList(i).offFrame, col);
end

end
