function result = extractEvents(states, ttotal, channelNames, nChPerMol, onLevel, minEventFrames)
%EXTRACTEVENTS Detect per-channel binding events from a state-assignment matrix.
%   Generalizes the event-extraction logic from LL_kinetics_3color/4color_generic
%   to an arbitrary number of channels, so the same code path works for
%   2-color, 3-color, 4-color, single-FRET-pair, etc. data without hardcoded
%   channel counts or assumptions about which channel name carries the state.
%
%   result = extractEvents(states, ttotal, channelNames, nChPerMol, onLevel, minEventFrames)
%
%   states, ttotal, channelNames, nChPerMol : as produced by LL_AssignStates_MultiColor
%   onLevel         : numeric vector, one ON-state value per channel, in the
%                     same order as channelNames (see pipeline.detectOnLevels).
%                     A channel with onLevel = NaN has no real state data
%                     (e.g. donor/acceptor columns in single-FRET-pair data,
%                     which are always present but carry no ON/OFF state of
%                     their own) and is left out of the result entirely.
%   minEventFrames  : minimum event duration in frames to keep (default 1).
%
%   result fields:
%     channelNames  cell array of channel names that had real state data
%                   (channels with onLevel = NaN are excluded)
%     onLevel       the onLevel vector used, filtered to match channelNames
%     molecules     number of molecules
%     nFrames       number of frames
%     t             time vector, seconds (ttotal column 1)
%     Exposure      seconds per frame
%     events        1xN cell array (N = numel(channelNames)); each cell is a
%                   struct array of events with fields:
%                     mol, eventNum, onFrame, offFrame, onTime, offTime, lifetime
%     eventCounts   number of events detected per channel

if nargin < 6 || isempty(minEventFrames)
    minEventFrames = 1;
end

numCh = numel(channelNames);

if numel(onLevel) ~= numCh
    error('pipeline:extractEvents:onLevelMismatch', ...
        'onLevel must have one value per channel (%d expected, %d given).', ...
        numCh, numel(onLevel));
end

t         = ttotal(:, 1);
nFrames   = numel(t);
molecules = (size(ttotal, 2) - 1) / nChPerMol;

validIdx = find(~isnan(onLevel));
nValid   = numel(validIdx);

result.channelNames = channelNames(validIdx);
result.onLevel       = onLevel(validIdx);
result.molecules     = molecules;
result.nFrames       = nFrames;
result.t              = t;
result.Exposure       = t(2) - t(1);
result.events         = cell(1, nValid);
result.eventCounts    = zeros(1, nValid);

for j = 1:nValid
    k = validIdx(j);
    chStates = states(:, k + 1 : nChPerMol : end);   % [nFrames x molecules]

    evList = struct('mol', {}, 'eventNum', {}, ...
                     'onFrame', {}, 'offFrame', {}, ...
                     'onTime', {}, 'offTime', {}, 'lifetime', {});
    eIdx = 0;

    for n = 1:molecules
        onFrames = find(chStates(:, n) == onLevel(k));
        if isempty(onFrames)
            continue;
        end

        % Boundaries of each continuous ON run (works even if the run
        % extends to the very first or very last frame).
        gaps    = find(diff(onFrames) > 1);
        starts  = onFrames([1; gaps + 1]);
        endings = onFrames([gaps; end]);

        evCount = 0;
        for ev = 1:numel(starts)
            durFrames = endings(ev) - starts(ev) + 1;
            if durFrames < minEventFrames
                continue;
            end
            evCount = evCount + 1;
            eIdx    = eIdx + 1;
            evList(eIdx).mol      = n;
            evList(eIdx).eventNum = evCount;
            evList(eIdx).onFrame  = starts(ev);
            evList(eIdx).offFrame = endings(ev);
            evList(eIdx).onTime   = t(starts(ev));
            evList(eIdx).offTime  = t(endings(ev));
            evList(eIdx).lifetime = t(endings(ev)) - t(starts(ev));
        end
    end

    result.events{j}      = evList;
    result.eventCounts(j) = numel(evList);
end

end
