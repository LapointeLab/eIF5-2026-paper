function S = runDissociationHazardTest(FRET_hazard, dissociate_hazard, eventID_hazard, moleculeID_hazard, fretThreshold, nBoot, progressFcn)
%RUNDISSOCIATIONHAZARDTEST Does FRET state predict per-frame dissociation probability?
%   S = runDissociationHazardTest(FRET_hazard, dissociate_hazard, eventID_hazard, moleculeID_hazard, fretThreshold, nBoot, progressFcn)
%
%   Ported from ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m
%   (runDissociationHazardTest local function), generalized only to be a
%   standalone, reusable function -- the statistics are unchanged: a
%   mixed-effects logistic regression with nested random intercepts for
%   molecule and event, plus a molecule-level cluster bootstrap for the
%   confidence intervals on the per-frame dissociation probabilities.
%
%   FRET_hazard, dissociate_hazard, eventID_hazard, moleculeID_hazard :
%       as from pipeline.buildDissociationHazardData.
%   fretThreshold : FRET value at/above which a frame counts as "high FRET".
%   nBoot         : number of molecule-cluster bootstrap resamples.
%   progressFcn   : optional, keepGoing = progressFcn(fracDone) after each
%                   bootstrap iteration. Pass [] to skip.
%
%   S fields:
%     nComplexes, nEvents      : distinct molecules / events contributing
%     betaHigh, pHigh, oddsRatio : GLMM coefficient, p-value, and odds
%                                  ratio for "high FRET" predicting dissociation
%     probHigh, probLow        : observed per-frame dissociation probability,
%                                 high- vs low-FRET frames
%     nHighFrames, nLowFrames, nHighDissoc, nLowDissoc : underlying counts
%     probRatio                : probLow / probHigh
%     ciHigh, ciLow            : 95% molecule-cluster bootstrap CI for probHigh/probLow
%     ciProbRatio              : 95% bootstrap CI for probRatio
%     probHigh_boot, probLow_boot, probRatio_boot : raw bootstrap distributions

if nargin < 7
    progressFcn = [];
end

highFRET = FRET_hazard >= fretThreshold;

S.nComplexes = numel(unique(moleculeID_hazard));
S.nEvents    = numel(unique(eventID_hazard));

hazTbl = table(FRET_hazard, double(highFRET), double(dissociate_hazard), ...
               categorical(eventID_hazard), categorical(moleculeID_hazard), ...
               'VariableNames', {'FRET', 'highFRET', 'dissociate', 'eventID', 'moleculeID'});

mdl = fitglme(hazTbl, 'dissociate ~ highFRET + (1|moleculeID) + (1|eventID)', ...
              'Distribution', 'Binomial', 'Link', 'logit');

coefTbl = mdl.Coefficients;
S.betaHigh  = coefTbl.Estimate(strcmp(coefTbl.Name, 'highFRET'));
S.pHigh     = coefTbl.pValue(strcmp(coefTbl.Name, 'highFRET'));
S.oddsRatio = exp(S.betaHigh);

S.probHigh     = mean(dissociate_hazard(highFRET));
S.probLow      = mean(dissociate_hazard(~highFRET));
S.nHighFrames  = sum(highFRET);
S.nLowFrames   = sum(~highFRET);
S.nHighDissoc  = sum(dissociate_hazard(highFRET));
S.nLowDissoc   = sum(dissociate_hazard(~highFRET));
S.probRatio    = S.probLow / S.probHigh;

% Molecule-level cluster bootstrap (the CI reported for these probabilities).
uniqueMol = unique(moleculeID_hazard);
nMol = numel(uniqueMol);

probHigh_boot = nan(nBoot, 1);
probLow_boot  = nan(nBoot, 1);

rng('default');
for b = 1:nBoot
    sampledMol = uniqueMol(randi(nMol, nMol, 1));
    idxCell = arrayfun(@(id) find(moleculeID_hazard == id), sampledMol, 'UniformOutput', false);
    idxAll = vertcat(idxCell{:});

    hf_b = highFRET(idxAll);
    ds_b = dissociate_hazard(idxAll);

    probHigh_boot(b) = mean(ds_b(hf_b));
    probLow_boot(b)  = mean(ds_b(~hf_b));

    if ~isempty(progressFcn)
        keepGoing = progressFcn(b / nBoot);
        if ~keepGoing
            probHigh_boot = probHigh_boot(1:b);
            probLow_boot  = probLow_boot(1:b);
            break;
        end
    end
end

S.ciHigh = prctile(probHigh_boot, [2.5 97.5]);
S.ciLow  = prctile(probLow_boot,  [2.5 97.5]);

S.probRatio_boot = probLow_boot ./ probHigh_boot;
S.ciProbRatio = prctile(S.probRatio_boot, [2.5 97.5]);

S.probHigh_boot = probHigh_boot;
S.probLow_boot  = probLow_boot;

end
