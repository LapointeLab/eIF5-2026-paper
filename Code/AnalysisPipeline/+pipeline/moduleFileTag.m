function tag = moduleFileTag(moduleName)
%MODULEFILETAG Sanitize a module display name (e.g. 'Association/
%Dissociation Conformations') into a filename-safe, alphanumeric-only tag
%(e.g. 'AssociationDissociationConformations').
%
%   Every module's exported .fig/.png/.eps gets this tag appended as a
%   fixed suffix (see pipeline.exportPlot), regardless of what filename
%   the user chose in the save dialog -- so +modules/summaryFigure.m can
%   recover which module produced a given .fig by scanning a folder for
%   this same tag, rather than depending on the user following a naming
%   convention themselves.
tag = regexprep(moduleName, '[^A-Za-z0-9]', '');
end
