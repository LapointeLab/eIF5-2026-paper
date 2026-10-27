function filtered = filterEventsByType(evList, type)
%FILTEREVENTSBYTYPE Filter an event struct array by event order within its molecule.
%   filtered = filterEventsByType(evList, type)
%
%   evList : struct array as produced by pipeline.extractEvents (must have
%            an .eventNum field, 1 = first event on that molecule).
%   type   : 'all' | 'first' | 'subsequent' (case-insensitive)
%              'all'        - every event, unfiltered
%              'first'      - only each molecule's first event (eventNum == 1)
%              'subsequent' - every event after each molecule's first (eventNum > 1)
%
%   Shared across modules so "which events to analyze" stays a single,
%   consistent concept rather than being reimplemented per module.

switch lower(type)
    case 'all'
        filtered = evList;
    case 'first'
        filtered = evList([evList.eventNum] == 1);
    case 'subsequent'
        filtered = evList([evList.eventNum] > 1);
    otherwise
        error('pipeline:filterEventsByType:invalidType', ...
            'Unknown event type "%s". Expected ''all'', ''first'', or ''subsequent''.', type);
end

end
