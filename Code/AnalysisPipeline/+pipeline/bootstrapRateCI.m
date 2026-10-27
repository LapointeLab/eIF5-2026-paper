function bootResult = bootstrapRateCI(lifetimes, molIDs, order, opts, nBoot, progressFcn, pointB, pointD)
%BOOTSTRAPRATECI Nonparametric CLUSTER bootstrap 95% CI for the fitted rate constant(s).
%   bootResult = bootstrapRateCI(lifetimes, molIDs, order, opts, nBoot, progressFcn, pointB, pointD)
%
%   lifetimes   : vector of the underlying per-event observations (e.g.
%                 quantized lifetimes) that the CDF being fit was built from.
%   molIDs      : vector, same length and order as lifetimes, giving the
%                 molecule each event belongs to. Resampling is done by
%                 MOLECULE, not by individual event: each bootstrap replicate
%                 draws M molecules with replacement (M = number of distinct
%                 molecules present) and includes ALL of each drawn
%                 molecule's events. This is a cluster/block bootstrap.
%                 Plain event-level resampling would treat every event as an
%                 independent draw, which understates the true uncertainty
%                 whenever a molecule contributes more than one event (e.g.
%                 the "All events"/"Subsequent events" filters) and molecules
%                 are kinetically heterogeneous — a common situation in
%                 single-molecule data. For filters with exactly one event
%                 per molecule (e.g. "First event"), this is mathematically
%                 identical to plain event resampling, so it's safe to always
%                 resample by molecule regardless of which filter is active.
%   order       : 1 or 2, as in pipeline.fitExponential.
%   opts        : struct passed to pipeline.fitExponential on every
%                 iteration (b0, d0, robust) — use the SAME settings as the
%                 point-estimate fit (e.g. result.optsUsed from
%                 pipeline.fitExponential) so the bootstrap reflects that fit.
%   nBoot       : number of bootstrap resamples requested.
%   progressFcn : optional function handle, called as
%                 keepGoing = progressFcn(fracDone) after each iteration.
%                 Return false to stop early (e.g. user cancellation) — the
%                 CI is then computed from whatever resamples completed.
%                 Pass [] to skip progress reporting.
%   pointB, pointD : the ORIGINAL point-estimate fit's b (and, order==2, d).
%                 Required for order==2: the double-exponential model is
%                 symmetric under swapping (a,b) <-> (1-a,d), so different
%                 resamples can converge with the "fast" rate landing in
%                 either slot ("label switching"). Each iteration's (b,d) is
%                 assigned to whichever of {as-is, swapped} is closer to
%                 (pointB,pointD), so the pooled b/d distributions stay
%                 anchored to the same physical rate as the original fit
%                 instead of being a scrambled mixture of both. Unused for
%                 order==1.
%
%   bootResult fields:
%     b_CI        [lower upper] 95% percentile CI for b
%     d_CI        [lower upper] 95% percentile CI for d (order==2 only; [] otherwise)
%     bValues     all successful bootstrap b estimates (column vector)
%     dValues     all successful bootstrap d estimates (order==2 only; [] otherwise)
%     nSuccess    number of resamples that fit successfully and were used for the CI
%     nRequested  nBoot, as given
%     nMolecules  number of distinct molecules resampled from (M)
%
%   Resamples that error (e.g. non-convergence) are skipped rather than
%   aborting the whole bootstrap.
%
%   Shared across modules: any module fitting pipeline.fitExponential can
%   reuse this rather than reimplementing the resampling loop.

if nargin < 6
    progressFcn = [];
end
if order == 2 && (nargin < 8 || isempty(pointB) || isempty(pointD))
    error('pipeline:bootstrapRateCI:missingPointEstimate', ...
        'pointB and pointD (the original fit''s rates) are required for order==2, to resolve label-switching.');
end
if numel(lifetimes) ~= numel(molIDs)
    error('pipeline:bootstrapRateCI:sizeMismatch', ...
        'lifetimes and molIDs must be the same length (one molecule ID per event).');
end

% Pre-group events by molecule once; each bootstrap iteration then just
% resamples which molecules (and how many times) to include, rather than
% re-scanning the full event list every time.
uniqueMols  = unique(molIDs);
M           = numel(uniqueMols);
eventsByMol = cell(1, M);
for k = 1:M
    eventsByMol{k} = lifetimes(molIDs == uniqueMols(k));
end

bValues = nan(nBoot, 1);
dValues = nan(nBoot, 1);
nCompleted = 0;

for i = 1:nBoot
    sampledIdx = randi(M, M, 1);
    resampled  = [eventsByMol{sampledIdx}];

    [P, X] = cdfcalc(resampled);
    P(1) = [];

    try
        r = pipeline.fitExponential(X, P, order, opts);
        if order == 1
            bValues(i) = r.coeffValues.b;
        else
            bi = r.coeffValues.b;
            di = r.coeffValues.d;
            errSame = abs(bi - pointB) + abs(di - pointD);
            errSwap = abs(di - pointB) + abs(bi - pointD);
            if errSwap < errSame
                [bi, di] = deal(di, bi);
            end
            bValues(i) = bi;
            dValues(i) = di;
        end
    catch
        % Skip a resample that fails to converge; leave as NaN.
    end

    nCompleted = i;
    if ~isempty(progressFcn)
        keepGoing = progressFcn(i / nBoot);
        if ~keepGoing
            break;
        end
    end
end

bValues = bValues(1:nCompleted);
bValues = bValues(~isnan(bValues));

bootResult.b_CI       = prctile(bValues, [2.5, 97.5]);
bootResult.bValues    = bValues;
bootResult.nSuccess   = numel(bValues);
bootResult.nRequested = nBoot;
bootResult.nMolecules = M;

if order == 2
    dValues = dValues(1:nCompleted);
    dValues = dValues(~isnan(dValues));
    bootResult.d_CI    = prctile(dValues, [2.5, 97.5]);
    bootResult.dValues = dValues;
else
    bootResult.d_CI    = [];
    bootResult.dValues = [];
end

end
