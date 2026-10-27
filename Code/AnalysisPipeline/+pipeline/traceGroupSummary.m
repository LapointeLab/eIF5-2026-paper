function line = traceGroupSummary(indent, mols, molIDs, values)
%TRACEGROUPSUMMARY One summary line: median of values pooled across ALL
% events/observations belonging to the given molecules (not just whichever
% one qualified them for the group), matching
% ExampleCode/LL_TIRF_BinTracesByLongEvent_v1.m's own pooling approach.
%
%   line = traceGroupSummary(indent, mols, molIDs, values)
%
%   indent  : text prepended to the line (e.g. '  ' for a nested look).
%   mols    : vector of molecule indices in this group ([] -> 'N/A').
%   molIDs  : vector, same length as values, giving the molecule each
%             value belongs to.
%   values  : vector of per-event/per-observation values to pool and
%             summarize (e.g. lifetime, or mean FRET per event).

if isempty(mols)
    line = [indent 'median (pooled events) = N/A'];
    return;
end
pooled = values(ismember(molIDs, mols));
line = sprintf('%smedian (pooled events, n=%d) = %.4g', indent, numel(pooled), median(pooled, 'omitnan'));

end
