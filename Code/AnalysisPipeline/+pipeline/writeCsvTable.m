function writeCsvTable(filePath, headerCells, dataRows)
%WRITECSVTABLE Minimal CSV writer that preserves exact header text.
%   writeCsvTable(filePath, headerCells, dataRows)
%
%   Ported from ExampleCode/LL_TIRF_Association_Dissociation_Conformations_v3.m
%   (writeCSVTable local function). Writes headerCells verbatim as the
%   first row (including spaces, %, #, parentheses, and embedded commas
%   via quoting) rather than routing through MATLAB's table/writetable,
%   which sanitizes column names into valid MATLAB identifiers and would
%   mangle a header like 'high FRET (HF) rate' into something unreadable.
%
%   filePath    : full path (including .csv extension) to write.
%   headerCells : 1xN cell array of header strings.
%   dataRows    : MxN cell array; numeric values are formatted with %.6g,
%                 char/string values are CSV-escaped and written as-is.

fid = fopen(filePath, 'w');
if fid == -1
    error('pipeline:writeCsvTable:openFailed', 'Could not open %s for writing.', filePath);
end
cleanupObj = onCleanup(@() fclose(fid));

headerStrs = cellfun(@csvEscapeField, headerCells, 'UniformOutput', false);
fprintf(fid, '%s\n', strjoin(headerStrs, ','));

for i = 1:size(dataRows, 1)
    rowStrs = cell(1, size(dataRows, 2));
    for j = 1:size(dataRows, 2)
        v = dataRows{i, j};
        if ischar(v) || isstring(v)
            rowStrs{j} = csvEscapeField(char(v));
        else
            rowStrs{j} = num2str(v, '%.6g');
        end
    end
    fprintf(fid, '%s\n', strjoin(rowStrs, ','));
end

end

function s = csvEscapeField(s)
s = char(s);
if any(s == ',') || any(s == '"')
    s = ['"', strrep(s, '"', '""'), '"'];
end
end
