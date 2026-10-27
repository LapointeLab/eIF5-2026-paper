function [d, note] = applyLegacyDefaults(d)
%APPLYLEGACYDEFAULTS Make an old-format ttotal/states file loadable.
% Before multi-color support, the lab's .mat files held only ttotal and
% states, always 2-color data with 3 columns per molecule
% (donor, acceptor, fret). When a loaded struct has ttotal and states but
% NEITHER channelNames nor nChPerMol, this fills in
% channelNames = {'donor','acceptor','fret'} and nChPerMol = 3.
% Any other combination is returned untouched, so the caller's usual
% "missing required variable(s)" check still reports it.
%
% Keep this file identical in AssignStatesTool/+pipeline and
% AnalysisPipeline/+pipeline.
%
%   [d, note] = applyLegacyDefaults(d)
%
%   d    : struct from load(). Returned with channelNames/nChPerMol added
%          if (and only if) the file is old-format.
%   note : char; a one-line message for the status log when defaults were
%          applied, '' otherwise.
%
% Errors (id 'applyLegacyDefaults:badShape') if an old-format file cannot be
% 2-color: ttotal and states differ in size, or (columns - 1) is not a
% multiple of 3.

note = '';

if ~all(isfield(d, {'ttotal', 'states'})) || any(isfield(d, {'channelNames', 'nChPerMol'}))
    return;
end

if ~isequal(size(d.ttotal), size(d.states))
    error('applyLegacyDefaults:badShape', ...
        ['Old-format file: ttotal is %d x %d but states is %d x %d. ' ...
         'They must be the same size.'], ...
        size(d.ttotal, 1), size(d.ttotal, 2), size(d.states, 1), size(d.states, 2));
end

nData = size(d.ttotal, 2) - 1;
if nData < 3 || mod(nData, 3) ~= 0
    error('applyLegacyDefaults:badShape', ...
        ['Old-format file (no channelNames/nChPerMol) is assumed to be 2-color ' ...
         '(3 columns per molecule), but ttotal has %d data columns after the ' ...
         'time column, which is not a multiple of 3.'], nData);
end

d.channelNames = {'donor', 'acceptor', 'fret'};
d.nChPerMol    = 3;
note = sprintf(['Old-format file (only ttotal and states): assuming 2-color data, ' ...
    '3 channels/molecule (donor, acceptor, fret), %d molecules.'], nData / 3);
end
