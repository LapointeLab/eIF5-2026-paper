function letter = panelLetter(i)
%PANELLETTER Spreadsheet-style panel label for index i (1-based): A, B,
%... Z, AA, AB, ... -- used by pipeline.buildSummaryComposite, which can
%legitimately place more than 26 panels (see +modules/summaryFigure.m).
letter = '';
while i > 0
    r = mod(i - 1, 26);
    letter = [char('A' + r), letter]; %#ok<AGROW>
    i = floor((i - 1) / 26);
end
end
