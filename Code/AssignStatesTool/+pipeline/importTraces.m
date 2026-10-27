function [ttotal, states, channelNames, nChPerMol] = importTraces(filename)
%IMPORTTRACES Convert a SPARTAN .traces file into ttotal/states format.
% Function form of ExampleCode/LL_trace_to_TIRF.m's logic (already
% generalized there to 2/3/4 color via traces.channelNames), split out so
% AssignStatesApp can call it directly instead of relying on workspace
% variables and a save-file dialog.
%
%   [ttotal, states, channelNames, nChPerMol] = importTraces(filename)
%
%   filename : path to a SPARTAN .traces file. If omitted or not a char,
%              loadTraces() shows its own file picker.
%
%   ttotal       - [nFrames x (nMols*nCh + 1)]. Column 1 is time in
%                  seconds. Remaining columns are grouped per molecule:
%                  [ch1 ch2 ... chN] for mol 1, then mol 2, etc. Channel
%                  order follows SPARTAN wavelength order (fluorescence
%                  channels first, then FRET channels).
%   states       - zero matrix, same size as ttotal.
%   nChPerMol    - number of data channels per molecule.
%   channelNames - cell array of channel names in ttotal's column order.

if nargin < 1
    traces = loadTraces();
else
    traces = loadTraces(filename);
end

chNames = traces.channelNames;
nCh     = numel(chNames);
[nMols, nFrames] = size(traces.(chNames{1}));

time = traces.time;
time = time + traces.sampling;

ttotal = zeros(nFrames, nMols*nCh + 1);
ttotal(:,1) = time' / 1000;

for k = 1:nCh
    ttotal(:, k+1 : nCh : end) = traces.(chNames{k})';
end

states       = zeros(size(ttotal));
nChPerMol    = nCh;
channelNames = chNames;

end
