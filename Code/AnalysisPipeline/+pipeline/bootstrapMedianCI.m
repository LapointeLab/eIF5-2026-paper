function bootResult = bootstrapMedianCI(values, molIDs, nBoot)
%BOOTSTRAPMEDIANCI Nonparametric CLUSTER bootstrap 95% CI for a median.
%   bootResult = bootstrapMedianCI(values, molIDs, nBoot)
%
%   Same molecule-level cluster resampling as pipeline.bootstrapMeanCI (see
%   that file), just summarizing each resample with the median instead of
%   the mean -- the more robust point estimate for a bounded, often-skewed
%   statistic (e.g. a Pearson correlation coefficient, confined to
%   [-1, 1]; see +modules/donorAcceptorCorrelation.m).
%
%   values  : vector of per-event (or per-observation) values, already
%             filtered down to whichever group the CI is being computed for.
%   molIDs  : vector, same length as values, giving the molecule each
%             value belongs to. Resampling is done by MOLECULE (draw M
%             molecules with replacement, include ALL of each drawn
%             molecule's values in that resample) -- events from the same
%             molecule aren't independent, so resampling individual events
%             would understate the true uncertainty whenever a molecule
%             contributes more than one event to the group.
%   nBoot   : number of bootstrap resamples.
%
%   bootResult fields:
%     median        point estimate (median of the original values)
%     ci            [lower upper] 95% percentile CI
%     bootMedians   nBoot x 1, all bootstrap resample medians
%     nMolecules    number of distinct molecules resampled from (M)

if numel(values) ~= numel(molIDs)
    error('pipeline:bootstrapMedianCI:sizeMismatch', ...
        'values and molIDs must be the same length (one molecule ID per value).');
end

values = values(:);
molIDs = molIDs(:);

uniqueMols  = unique(molIDs);
M           = numel(uniqueMols);
valuesByMol = cell(1, M);
for k = 1:M
    valuesByMol{k} = values(molIDs == uniqueMols(k));
end

bootMedians = nan(nBoot, 1);
for i = 1:nBoot
    sampledIdx = randi(M, M, 1);
    resampled  = vertcat(valuesByMol{sampledIdx});
    bootMedians(i) = median(resampled, 'omitnan');
end

bootResult.median      = median(values, 'omitnan');
bootResult.ci          = prctile(bootMedians, [2.5, 97.5]);
bootResult.bootMedians = bootMedians;
bootResult.nMolecules  = M;

end
