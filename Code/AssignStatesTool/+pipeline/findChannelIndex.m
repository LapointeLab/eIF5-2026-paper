function idx = findChannelIndex(channelNames, pattern)
%FINDCHANNELINDEX Index of the channel whose name contains PATTERN
% (case-insensitive substring match), e.g. 'fret'. Returns [] if no
% channel matches; errors if more than one does, since callers need a
% single unambiguous channel to act on.
%
%   idx = findChannelIndex(channelNames, pattern)

match = cellfun(@(x) ~isempty(strfind(lower(x), lower(pattern))), channelNames); %#ok<STREMP>
idx = find(match);

if numel(idx) > 1
    error('findChannelIndex:ambiguous', ...
        'Multiple channels match ''%s'': %s.', pattern, strjoin(channelNames(idx), ', '));
end

end
