function [Z, timeAxis, fretAxis, nSamplesPerTime] = buildAlignedFretDensityHeatmap(segments, preFrameVal, postFrameVal, ...
    alignment, Exposure, tMax_ms, startFrameRel, nFretBins, normalizeByTime, doSmoothY, sigmaBins)
%BUILDALIGNEDFRETDENSITYHEATMAP End- or start-aligned FRET density heatmap
%around a set of binding events.
%   [Z, timeAxis, fretAxis, nSamplesPerTime] = buildAlignedFretDensityHeatmap(segments, preFrameVal, postFrameVal, alignment, Exposure, tMax_ms, startFrameRel, nFretBins, normalizeByTime, doSmoothY, sigmaBins)
%
%   Adapted from ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m.
%   For 'dissociation' (end-aligned): each event contributes up to the
%   last tMax_ms of its bound-duration trace, aligned so the event's last
%   frame sits at t=0, PLUS the one frame immediately after the event ends
%   (t = +one frame) if that frame exists -- the first unbound frame after
%   dissociation. For 'association' (start-aligned): each event
%   contributes up to the first tMax_ms of its trace, aligned so the first
%   frame sits at t=0, PLUS the one frame immediately before the event
%   starts (t = -one frame) if it exists -- the last unbound frame before
%   binding.
%
%   segments, preFrameVal, postFrameVal : as returned by
%       pipeline.extractEventSegmentsWithBoundary for the same evList.
%   alignment      : 'dissociation' or 'association'.
%   Exposure       : seconds per frame.
%   tMax_ms        : how many milliseconds of each event to include.
%   startFrameRel  : dissociation only -- exclude the first N frames of
%                    each event from the window (1 = no exclusion).
%                    Ignored for 'association' (matching the original
%                    script, which never excludes association's onset frames).
%   nFretBins      : number of FRET-efficiency bins spanning [0, 1].
%   normalizeByTime: true to normalize each time-bin's column to sum to 1
%                    (a "fraction per time bin" density instead of raw counts).
%   doSmoothY      : true to apply 1D Gaussian smoothing along the FRET
%                    axis only (not across time), matching the original
%                    script -- sigmaBins is its standard deviation in bins.
%
%   Z        : [nFretBins x numel(timeAxis)] matrix (rows = FRET, matching
%              imagesc(timeAxis, fretAxis, Z) with axis xy).
%   timeAxis : ms, one value per output time bin, negative-to-positive
%              (0 = event end for dissociation, event start for association).
%   fretAxis : bin centers spanning [0, 1].
%   nSamplesPerTime : number of samples contributing to each time bin.

dt_ms = Exposure * 1000;
nWin  = round(tMax_ms / dt_ms);

switch lower(alignment)
    case 'dissociation'
        timeAxis = [(-(nWin - 1):0) * dt_ms, dt_ms];
    case 'association'
        timeAxis = [-dt_ms, (0:(nWin - 1)) * dt_ms];
    otherwise
        error('pipeline:buildAlignedFretDensityHeatmap:invalidAlignment', ...
            'alignment must be ''dissociation'' or ''association'', got ''%s''.', alignment);
end
nTimeBins = numel(timeAxis);

yEdges = linspace(0, 1, nFretBins + 1);
fretAxis = (yEdges(1:end-1) + yEdges(2:end)) / 2;
xEdges = [timeAxis(1) - dt_ms/2, timeAxis + dt_ms/2];

timeVals = [];
fretVals = [];
nSamplesPerTime = zeros(nTimeBins, 1);

for i = 1:numel(segments)
    E = segments{i};
    lastRel = numel(E);

    switch lower(alignment)
        case 'dissociation'
            if lastRel < startFrameRel
                continue;
            end
            takeLen  = min(lastRel, nWin);
            winStart = max(lastRel - takeLen + 1, startFrameRel);
            winEnd   = lastRel;
            if winEnd < winStart
                continue;
            end

            Ew = E(winStart:winEnd);
            eventFrames = winStart:winEnd;
            binIdx = nWin - (lastRel - eventFrames);
            tUse = timeAxis(binIdx);

            timeVals = [timeVals; tUse(:)]; %#ok<AGROW>
            fretVals = [fretVals; Ew(:)]; %#ok<AGROW>
            for ii = 1:numel(binIdx)
                nSamplesPerTime(binIdx(ii)) = nSamplesPerTime(binIdx(ii)) + 1;
            end

            if ~isnan(postFrameVal(i))
                timeVals = [timeVals; timeAxis(end)]; %#ok<AGROW>
                fretVals = [fretVals; postFrameVal(i)]; %#ok<AGROW>
                nSamplesPerTime(nTimeBins) = nSamplesPerTime(nTimeBins) + 1;
            end

        case 'association'
            takeLen = min(lastRel, nWin);
            Ew = E(1:takeLen);
            eventFrames = 1:takeLen;
            binIdx = eventFrames + 1;
            tUse = timeAxis(binIdx);

            timeVals = [timeVals; tUse(:)]; %#ok<AGROW>
            fretVals = [fretVals; Ew(:)]; %#ok<AGROW>
            for ii = 1:numel(binIdx)
                nSamplesPerTime(binIdx(ii)) = nSamplesPerTime(binIdx(ii)) + 1;
            end

            if ~isnan(preFrameVal(i))
                timeVals = [timeVals; timeAxis(1)]; %#ok<AGROW>
                fretVals = [fretVals; preFrameVal(i)]; %#ok<AGROW>
                nSamplesPerTime(1) = nSamplesPerTime(1) + 1;
            end
    end
end

N = histcounts2(timeVals, fretVals, xEdges, yEdges);
if normalizeByTime
    rowSums = sum(N, 2);
    rowSums(rowSums == 0) = 1;
    N = N ./ rowSums;
end

Z = N';

if doSmoothY && sigmaBins > 0
    y = (-round(6 * sigmaBins)):(round(6 * sigmaBins));
    g = exp(-(y .^ 2) / (2 * sigmaBins ^ 2));
    g = g / sum(g);
    Z = conv2(Z, g', 'same');   % smooths along the FRET (row) axis only
end

end
