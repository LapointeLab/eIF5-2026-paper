function S = runAssociationTest(onsetFRET, moleculeID_onset, fretThreshold, pEquilibriumHigh, nBoot, progressFcn)
%RUNASSOCIATIONTEST Is the FRET state at binding onset different from equilibrium/chance?
%   S = runAssociationTest(onsetFRET, moleculeID_onset, fretThreshold, pEquilibriumHigh, nBoot, progressFcn)
%
%   Ported from ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m
%   (runAssociationTest local function), generalized only to be a
%   standalone, reusable function -- the statistics are unchanged: a
%   mixed-effects logistic regression (random intercept for molecule) with
%   a fixed offset, testing the observed onset composition against both
%   the aggregate (equilibrium) occupancy and an unbiased 50% reference,
%   plus a molecule-level cluster bootstrap CI on the observed proportion.
%
%   onsetFRET, moleculeID_onset : as from pipeline.buildAssociationOnsetData.
%   fretThreshold     : FRET value at/above which an event's onset counts as "high FRET".
%   pEquilibriumHigh  : the reference aggregate high-FRET occupancy to
%                        compare the onset composition against (see
%                        pipeline.buildDissociationHazardData with k=1,
%                        pooled across all its frames -- the original
%                        script's "equilibrium" reference).
%   nBoot             : number of molecule-cluster bootstrap resamples.
%   progressFcn       : optional, keepGoing = progressFcn(fracDone) after
%                        each bootstrap iteration. Pass [] to skip.
%
%   S fields:
%     nComplexes, nEvents, kHigh, pObservedHigh : distinct molecules,
%         events, count and fraction classified high-FRET at onset
%     betaEquilibrium, pEquilibrium : GLMM intercept/p-value testing
%         onset composition against pEquilibriumHigh
%     beta50, p50                  : same, testing against unbiased 50%
%     ciOnsetBoot                  : 95% molecule-cluster bootstrap CI for pObservedHigh
%     pObservedHigh_boot           : raw bootstrap distribution

if nargin < 6
    progressFcn = [];
end

onsetHigh = onsetFRET >= fretThreshold;
n = numel(onsetHigh);
k = sum(onsetHigh);

S.nComplexes     = numel(unique(moleculeID_onset));
S.nEvents        = n;
S.kHigh          = k;
S.pObservedHigh  = k / n;

onsetTbl = table(double(onsetHigh), categorical(moleculeID_onset), ...
                  'VariableNames', {'onsetHigh', 'moleculeID'});

% vs equilibrium occupancy
offsetValEq = log(pEquilibriumHigh / (1 - pEquilibriumHigh));
mdlEq = fitglme(onsetTbl, 'onsetHigh ~ 1 + (1|moleculeID)', ...
                 'Distribution', 'Binomial', 'Link', 'logit', ...
                 'Offset', repmat(offsetValEq, n, 1));
cEq = mdlEq.Coefficients;
S.betaEquilibrium = cEq.Estimate(strcmp(cEq.Name, '(Intercept)'));
S.pEquilibrium    = cEq.pValue(strcmp(cEq.Name, '(Intercept)'));

% vs unbiased 50/50
mdl50 = fitglme(onsetTbl, 'onsetHigh ~ 1 + (1|moleculeID)', ...
                 'Distribution', 'Binomial', 'Link', 'logit', ...
                 'Offset', zeros(n, 1));
c50 = mdl50.Coefficients;
S.beta50 = c50.Estimate(strcmp(c50.Name, '(Intercept)'));
S.p50    = c50.pValue(strcmp(c50.Name, '(Intercept)'));

% Molecule-level cluster bootstrap (the CI reported for the observed proportion).
uniqueMol = unique(moleculeID_onset);
nMol = numel(uniqueMol);

pObservedHigh_boot = nan(nBoot, 1);
rng('default');
for b = 1:nBoot
    sampledMol = uniqueMol(randi(nMol, nMol, 1));
    idxCell = arrayfun(@(id) find(moleculeID_onset == id), sampledMol, 'UniformOutput', false);
    idxAll = vertcat(idxCell{:});
    pObservedHigh_boot(b) = mean(onsetHigh(idxAll));

    if ~isempty(progressFcn)
        keepGoing = progressFcn(b / nBoot);
        if ~keepGoing
            pObservedHigh_boot = pObservedHigh_boot(1:b);
            break;
        end
    end
end

S.ciOnsetBoot = prctile(pObservedHigh_boot, [2.5 97.5]);
S.pObservedHigh_boot = pObservedHigh_boot;

end
