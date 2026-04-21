%% trace_to_TIRF_CA
% Carlos Alvarado 1.15.2021
% Takes a traces file and converts it into ttotal format for use with TIRF
% scripts

traces = loadTraces();

donor = traces.donor;
acceptor = traces.acceptor;
fret = traces.fret;
time = traces.time;
time = time + traces.sampling;

[nMols, nFrames] = size(donor);

ttotal = zeros(nFrames, nMols*3+1);
ttotal(:,2:3:end) = donor';
ttotal(:,3:3:end) = acceptor';
ttotal(:,4:3:end) = fret';
ttotal(:,1) = time' / 1000;

clear acceptor donor fret nFrames nMols time traces

