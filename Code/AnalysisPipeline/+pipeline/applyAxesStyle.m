function applyAxesStyle(ax)
%APPLYAXESSTYLE Apply the shared plot house style to a uiaxes.
%   Outward tick marks, no grid lines, and a larger, more readable font.
%   Shared across modules so plot appearance stays consistent as more
%   analyses are added.

ax.TickDir = 'out';
ax.XGrid   = 'off';
ax.YGrid   = 'off';
ax.FontSize = 13;
ax.Box = 'off';

end
