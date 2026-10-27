function [onLevel, notes] = detectOnLevels(states, channelNames, nChPerMol)
%DETECTONLEVELS Auto-detect the ON-state numeric value for each channel.
%   Avoids hardcoding per-dye constants (Cy2=50, Cy3=100, ...) or assumptions
%   about which channel name carries the state (e.g. "exclude channels named
%   fret") in the app: reads the nonzero values actually present in each
%   channel's state column instead. Different experiment types put the
%   meaningful ON/OFF state in different channels — multi-dye codetection
%   data usually has it per dye channel, single-FRET-pair data usually has
%   it in the fret channel with donor/acceptor state columns left at zero —
%   so every channel is scanned and channels with no state data simply
%   report 0 events downstream.
%
%   [onLevel, notes] = detectOnLevels(states, channelNames, nChPerMol)
%
%   onLevel : numeric vector, one value per channel in channelNames.
%   notes   : cell array of human-readable strings flagging channels where the
%             on-level had to be guessed (no data, or more than one nonzero
%             value present) so the caller can surface a warning to the user.

numCh = numel(channelNames);
onLevel = zeros(1, numCh);
notes   = {};

for k = 1:numCh
    colVals = states(:, k + 1 : nChPerMol : end);
    nz = unique(colVals(colVals ~= 0));

    if isempty(nz)
        onLevel(k) = NaN;
        notes{end+1} = sprintf('%s: no nonzero state values found in this channel; excluded from event reporting.', ...
            channelNames{k}); %#ok<AGROW>
    elseif isscalar(nz)
        onLevel(k) = nz;
    else
        onLevel(k) = max(nz);
        notes{end+1} = sprintf('%s: multiple state values found (%s); defaulting on-level to %g \x2014 verify this matches your state-assignment convention.', ...
            channelNames{k}, strjoin(string(nz), ', '), max(nz)); %#ok<AGROW>
    end
end

end
