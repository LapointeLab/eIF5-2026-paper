function cols = getMolCols(molIdx, nChPerMol)
%GETMOLCOLS ttotal/states column indices for the given (global, 1-based)
% molecule indices. Column 1 is shared (time); molecule n occupies the
% nChPerMol columns starting at 2+(n-1)*nChPerMol -- generalizes
% ExampleCode/LL_AssignStates_v1.m's hardcoded-3-columns-per-molecule
% indexing (3*c-1, 3*c, 3*c+1) to this app's arbitrary channel count, and
% matches AnalysisPipelineBuild/+pipeline/getMolCols.m's convention so
% files produced here line up with that downstream app.
%
%   cols = getMolCols(molIdx, nChPerMol)
%
%   molIdx    : vector of global (1-based) molecule indices.
%   nChPerMol : channels per molecule.

molIdx = double(molIdx(:)');
nChPerMol = double(nChPerMol);
offsets = (0:nChPerMol - 1)';
cols = reshape((molIdx - 1) * nChPerMol + 2 + offsets, 1, []);

end
