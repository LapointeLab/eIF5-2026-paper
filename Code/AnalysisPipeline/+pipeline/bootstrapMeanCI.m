function bootResult = bootstrapMeanCI(values, molIDs, nBoot)
%BOOTSTRAPMEANCI Nonparametric CLUSTER bootstrap 95% CI for a mean.
%   bootResult = bootstrapMeanCI(values, molIDs, nBoot)
%
%   values  : vector of per-event (or per-observation) values (e.g. each
%             event's mean FRET, or each event's lifetime) already
%             filtered down to whichever group the CI is being computed
%             for (e.g. just the Low-group events).
%   molIDs  : vector, same length as values, giving the molecule each
%             value belongs to. Resampling is done by MOLECULE (draw M
%             molecules with replacement, include ALL of each drawn
%             molecule's values in that resample) -- the same reasoning as
%             pipeline.bootstrapRateCI/bootstrapGaussianCI: events from the
%             same molecule aren't independent, so resampling individual
%             events would understate the true uncertainty whenever a
%             molecule contributes more than one event to the group.
%   nBoot   : number of bootstrap resamples.
%
%   bootResult fields:
%     mean        point estimate (mean of the original values)
%     ci          [lower upper] 95% percentile CI
%     bootMeans   nBoot x 1, all bootstrap resample means
%     nMolecules  number of distinct molecules resampled from (M)

if numel(values) ~= numel(molIDs)
    error('pipeline:bootstrapMeanCI:sizeMismatch', ...
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

bootMeans = nan(nBoot, 1);
for i = 1:nBoot
    sampledIdx = randi(M, M, 1);
    resampled  = vertcat(valuesByMol{sampledIdx});
    bootMeans(i) = mean(resampled, 'omitnan');
end

bootResult.mean       = mean(values, 'omitnan');
bootResult.ci         = prctile(bootMeans, [2.5, 97.5]);
bootResult.bootMeans  = bootMeans;
bootResult.nMolecules = M;

end
