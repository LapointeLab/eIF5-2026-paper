function [M, relFrameAxis, molIDs] = extractSyncedTraces(app, chName, evList)
%EXTRACTSYNCEDTRACES Build a post-synchronized (event-onset-aligned) trace matrix.
%   [M, relFrameAxis, molIDs] = extractSyncedTraces(app, chName, evList)
%
%   For each event in evList, pulls that molecule's FULL continuous trace
%   for chName — not just the bound-frame portion, the whole recording, so
%   a heatmap built from this can show the channel evolving both before and
%   after the sync point — and aligns it so relFrameAxis == 0 corresponds to
%   that event's onFrame.
%
%   This is the piece the original example script (LL_TIRF_Plot_FRET_Heatmap_v2)
%   assumed already existed as `fret_time_series_all`; nothing in the
%   pipeline previously built this "aligned ensemble" matrix, since
%   pipeline.extractEvents only records discrete event boundaries, not a
%   synchronized trace stack.
%
%   app    : AnalysisPipelineApp instance (needs app.Data and app.Data.result).
%   chName : channel name (must resolve against app.Data.channelNames, the
%            ORIGINAL unfiltered list, since ttotal's column layout follows
%            that order — see pipeline.extractEvents).
%   evList : event struct array (e.g. from pipeline.filterEventsByType)
%            whose .onFrame values define the sync points.
%
%   M            : [numel(relFrameAxis) x numel(evList)] matrix, one
%                  aligned column per event. NaN wherever a given event's
%                  sync-relative span doesn't reach that row — every
%                  molecule has complete data over its own 1:nFrames range,
%                  so NaN only appears from the alignment shift itself
%                  (e.g. events near the start/end of the movie), matching
%                  the "unpopulated entries as NaN" convention the original
%                  script's input format expected.
%   relFrameAxis : column vector of integer frame offsets relative to each
%                  event's onFrame (0 = onFrame itself), spanning the union
%                  of every included event's valid range.
%   molIDs       : molecule ID for each column of M (same order as evList).

origIdx   = find(strcmp(app.Data.channelNames, chName), 1);
nChPerMol = app.Data.nChPerMol;
ttotal    = app.Data.ttotal;
nFrames   = app.Data.result.nFrames;

nEvents  = numel(evList);
onFrames = [evList.onFrame];

minRel = 1 - max(onFrames);
maxRel = nFrames - min(onFrames);
relFrameAxis = (minRel:maxRel)';

M = nan(numel(relFrameAxis), nEvents);
molIDs = [evList.mol];

for i = 1:nEvents
    mol   = evList(i).mol;
    col   = origIdx + 1 + (mol - 1) * nChPerMol;
    trace = ttotal(1:nFrames, col);
    rowIdx = (1:nFrames) - onFrames(i) - minRel + 1;
    M(rowIdx, i) = trace;
end

end
