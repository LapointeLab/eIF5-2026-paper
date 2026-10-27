function cols = getMolCols(molIdx, nChPerMol)
%GETMOLCOLS ttotal/states column indices for the given (global, 1-based)
% molecule indices. Column 1 is shared (time); molecule n occupies the
% nChPerMol columns starting at 2+(n-1)*nChPerMol -- generalizes
% ExampleCode/LL_TIRF_BinTracesByLongEvent_v1.m's hardcoded-3-columns-per-
% molecule getMolCols to this app's arbitrary channel count.
%
%   cols = getMolCols(molIdx, nChPerMol)
%
%   molIdx    : vector of global (1-based) molecule indices.
%   nChPerMol : app.Data.nChPerMol.

molIdx = molIdx(:)';
offsets = (0:nChPerMol - 1)';
cols = reshape((molIdx - 1) * nChPerMol + 2 + offsets, 1, []);

end
