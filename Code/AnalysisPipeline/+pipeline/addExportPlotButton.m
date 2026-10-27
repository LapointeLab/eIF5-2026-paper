function btn = addExportPlotButton(parent, ax, moduleTag, suggestedNameFcn)
%ADDEXPORTPLOTBUTTON Add an "Export Plot..." button wired to pipeline.exportPlot.
%   btn = addExportPlotButton(parent, ax, moduleTag, suggestedNameFcn)
%
%   parent           : container (e.g. a uigridlayout cell) to hold the button.
%   ax               : uiaxes to export when clicked.
%   moduleTag        : the calling module's display name, forwarded to
%                       pipeline.exportPlot (see that file) so every export
%                       carries a fixed, module-identifying filename
%                       suffix.
%   suggestedNameFcn : function handle, () -> char/string, giving the
%                      suggested base filename for the save dialog. Should be
%                      a handle to a nested function in the caller (not an
%                      anonymous closure over a snapshot) so it reflects
%                      live state (current channel/selection) at click time.
%                      Optional; defaults to always suggesting 'plot'.
%
%   Thin UI wrapper so any module can add one-click, publication-ready plot
%   export (.fig/.png/.eps) without reimplementing the dialog wiring.

if nargin < 4 || isempty(suggestedNameFcn)
    suggestedNameFcn = @() 'plot';
end

btn = uibutton(parent, 'Text', 'Export Plot...', ...
    'ButtonPushedFcn', @(~, ~) pipeline.exportPlot(ax, moduleTag, [], suggestedNameFcn()));

end
