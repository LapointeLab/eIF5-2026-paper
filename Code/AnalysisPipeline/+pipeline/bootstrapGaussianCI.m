function bootResult = bootstrapGaussianCI(values, molIDs, edges, nGaussians, opts, nBoot, progressFcn, pointMeans)
%BOOTSTRAPGAUSSIANCI Nonparametric CLUSTER bootstrap 95% CI for Gaussian-mixture means/std devs/populations.
%   bootResult = bootstrapGaussianCI(values, molIDs, edges, nGaussians, opts, nBoot, progressFcn, pointMeans)
%
%   values      : vector of the underlying per-frame observations (e.g. FRET
%                 efficiency values) that the histogram being fit was built from.
%   molIDs      : vector, same length and order as values, giving the
%                 molecule each observation belongs to. Resampling is done
%                 by MOLECULE (draw M molecules with replacement, include
%                 ALL of each drawn molecule's values) — the same reasoning
%                 as pipeline.bootstrapRateCI: frames from the same molecule
%                 aren't independent, so resampling individual frames would
%                 understate the true uncertainty.
%   edges       : histogram bin edges used to rebuild the normalized
%                 histogram each iteration (must match the point-estimate's
%                 binning, e.g. linspace(0,1,51)).
%   nGaussians  : 1-4.
%   opts        : struct passed to pipeline.fitGaussianMixture on every
%                 iteration (meanGuess, robust) — use the SAME settings as
%                 the point-estimate fit (e.g. result.optsUsed).
%   nBoot       : number of bootstrap resamples requested.
%   progressFcn : optional function handle, keepGoing = progressFcn(fracDone).
%                 Return false to stop early — the CI is then computed from
%                 whatever resamples completed. Pass [] to skip.
%   pointMeans  : the ORIGINAL point-estimate fit's means (nGaussians x 1,
%                 already sorted ascending). Required whenever nGaussians > 1:
%                 the mixture model is symmetric under permuting components,
%                 so different resamples can converge with components in a
%                 different order ("label switching") — sorting by mean
%                 alone isn't enough once two components' means are close
%                 enough to plausibly swap rank between the point estimate
%                 and a noisy resample. Each iteration's fitted components
%                 are matched to pointMeans via whichever permutation (brute
%                 force; nGaussians <= 4, so at most 24) minimizes total
%                 mean distance, keeping the pooled per-component
%                 distributions anchored to the same physical population.
%
%   bootResult fields:
%     means_CI, stds_CI, pops_CI          nGaussians x 2 percentile 95% CIs
%     meansValues, stdsValues, popsValues nSuccess x nGaussians, the raw
%                                         (component-matched) bootstrap
%                                         estimates (pops: see
%                                         pipeline.fitGaussianMixture)
%     nSuccess    number of resamples that fit successfully and were used
%     nRequested  nBoot, as given
%     nMolecules  number of distinct molecules resampled from (M)
%
%   Shared across modules: any module fitting pipeline.fitGaussianMixture
%   can reuse this rather than reimplementing the resampling loop.

if nargin < 7
    progressFcn = [];
end
if nGaussians > 1 && (nargin < 8 || isempty(pointMeans))
    error('pipeline:bootstrapGaussianCI:missingPointEstimate', ...
        'pointMeans (the original fit''s sorted means) is required when nGaussians > 1, to resolve label-switching.');
end
if numel(values) ~= numel(molIDs)
    error('pipeline:bootstrapGaussianCI:sizeMismatch', ...
        'values and molIDs must be the same length (one molecule ID per observation).');
end

uniqueMols  = unique(molIDs);
M           = numel(uniqueMols);
valuesByMol = cell(1, M);
for k = 1:M
    valuesByMol{k} = values(molIDs == uniqueMols(k));
end

binCenters = (edges(1:end-1) + edges(2:end)) / 2;
perms_ = perms(1:nGaussians);   % all component orderings, for label-switching resolution

meansValues = nan(nBoot, nGaussians);
stdsValues  = nan(nBoot, nGaussians);
popsValues  = nan(nBoot, nGaussians);
nCompleted  = 0;

for i = 1:nBoot
    sampledIdx = randi(M, M, 1);
    resampled  = [valuesByMol{sampledIdx}];

    counts  = histcounts(resampled, edges);
    inRange = sum(counts);

    if inRange > 0
        y = counts / inRange;

        try
            r = pipeline.fitGaussianMixture(binCenters, y, nGaussians, opts);
            m = r.means;   % already sorted ascending
            s = r.stds;
            w = r.pops;

            if nGaussians > 1
                bestCost = Inf;
                bestPerm = 1:nGaussians;
                for p = 1:size(perms_, 1)
                    cost = sum(abs(m(perms_(p, :)) - pointMeans));
                    if cost < bestCost
                        bestCost = cost;
                        bestPerm = perms_(p, :);
                    end
                end
                m = m(bestPerm);
                s = s(bestPerm);
                w = w(bestPerm);
            end

            meansValues(i, :) = m;
            stdsValues(i, :)  = s;
            popsValues(i, :)  = w;
        catch
            % Skip a resample that fails to converge; leave as NaN.
        end
    end

    nCompleted = i;
    if ~isempty(progressFcn)
        keepGoing = progressFcn(i / nBoot);
        if ~keepGoing
            break;
        end
    end
end

meansValues = meansValues(1:nCompleted, :);
stdsValues  = stdsValues(1:nCompleted, :);
popsValues  = popsValues(1:nCompleted, :);
validRows   = ~any(isnan(meansValues), 2);
meansValues = meansValues(validRows, :);
stdsValues  = stdsValues(validRows, :);
popsValues  = popsValues(validRows, :);

bootResult.means_CI    = [prctile(meansValues, 2.5, 1)', prctile(meansValues, 97.5, 1)'];
bootResult.stds_CI     = [prctile(stdsValues, 2.5, 1)', prctile(stdsValues, 97.5, 1)'];
bootResult.pops_CI     = [prctile(popsValues, 2.5, 1)', prctile(popsValues, 97.5, 1)'];
bootResult.meansValues = meansValues;
bootResult.stdsValues  = stdsValues;
bootResult.popsValues  = popsValues;
bootResult.nSuccess    = size(meansValues, 1);
bootResult.nRequested  = nBoot;
bootResult.nMolecules  = M;

end
