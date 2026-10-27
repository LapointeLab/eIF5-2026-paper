function placeFitLabel(ax, instanceTag, lines, color, fontSize, fontName)
%PLACEFITLABEL Place a small on-plot text label (fitted rate(s) or
%mean(s)) on ax, in whichever of the 4 axes corners actually turns out
%clear of nearby data once the label is drawn -- so the label doesn't sit
%on top of the curve/points it's summarizing. Used by
%pipeline.buildFitControls and pipeline.buildGaussianFitControls so every
%fit-value label across the app places itself the same way.
%
%   pipeline.placeFitLabel(ax, instanceTag, lines, color)
%
%   instanceTag : identifies THIS label among any others sharing ax (e.g.
%                 'shortFitCurve'/'longFitCurve' for
%                 +modules/lifetimeSorting.m's overlaid Short/Long fits).
%                 The label's own Tag is derived from this
%                 ('pipelineFitLabel_<instanceTag>') and any existing label
%                 with that same Tag is deleted and replaced. Also fixes
%                 this label's stacking SLOT among any siblings in the
%                 same corner: sorted ALPHABETICALLY, not by which one
%                 happens to already be on ax, so re-placing one instance
%                 (e.g. Save Fit updating it with a bootstrap CI, which
%                 changes its own line count) can't bump it into another
%                 instance's slot.
%   lines       : cell array of strings, ONE VALUE PER LINE (e.g.
%                 {'k_1 = 1.06 s^{-1}', 'k_2 = 0.297 s^{-1}'}, not a single
%                 comma-joined line) -- keeps each candidate corner
%                 narrower, which both looks better and is less likely to
%                 need multiple retries below to clear the data.
%   color       : text color (default black; pass the fit curve's own
%                 color so a label stays visually paired with its curve,
%                 e.g. lifetimeSorting.m's Short/Long overlay).
%   fontSize    : optional, default 8. pipeline.exportPlot passes 6 (with
%                 fontName 'Arial Narrow') when re-placing a label already
%                 on the LIVE axes onto its own small reconstructed
%                 export panel -- verifying overlap has to happen at the
%                 label's ACTUAL rendered font size on whichever axes it
%                 will actually be viewed on, since the same text can
%                 occupy a very different fraction of a much smaller
%                 panel than it did on the live view.
%   fontName    : optional; default axes/text font if omitted.
%
%   All 4 corners are tried in order of a quick density estimate
%   (fewest data points nearby first); each candidate is actually DRAWN
%   and its real rendered Extent checked against every data point/legend
%   box before being accepted -- a fixed-fraction "is this corner roughly
%   empty" guess (an earlier version of this function) can't know how
%   WIDE a specific label's longest line (e.g. a bootstrap CI string) will
%   render, and got a data-dense corner wrong exactly when that guess was
%   too narrow. Falls back to the least-bad (fewest overlapping points)
%   corner if none come back perfectly clear.
%
%   Every OTHER placeFitLabel-family label already on ax (matched by the
%   shared 'pipelineFitLabel_' tag prefix) that landed in the SAME corner
%   is re-laid-out too, not just counted -- if this call is the one that
%   changes this label's own line count (Save Fit adding a bootstrap CI to
%   what was a 2-line trial-fit label), a sibling placed against the OLD
%   line count would otherwise be left with a stale gap or overlap. Doing
%   the whole corner's stack fresh every call keeps it correct regardless
%   of which instance was updated last or how many times.

if nargin < 4 || isempty(color)
    color = [0 0 0];
end
if nargin < 5 || isempty(fontSize)
    fontSize = 8;
end
if nargin < 6
    fontName = '';
end

tag = ['pipelineFitLabel_' instanceTag];
delete(findobj(ax, 'Tag', tag));

[dataX, dataY] = collectHazardPoints(ax);
corners = rankCorners(ax, dataX, dataY, numel(lines));

bestOverlap = Inf;
bestTxt = gobjects(0);
bestCorner = corners{1};
for ci = 1:numel(corners)
    [txt, nOverlap] = tryPlaceAt(ax, tag, lines, color, corners{ci}, dataX, dataY, fontSize, fontName);
    if nOverlap < bestOverlap
        if ~isempty(bestTxt) && isvalid(bestTxt)
            delete(bestTxt);
        end
        bestOverlap = nOverlap;
        bestTxt = txt;
        bestCorner = corners{ci};
    else
        delete(txt);
    end
    if bestOverlap == 0
        break;
    end
end
corner = bestCorner;

% Re-lay-out every family label sharing this corner (including the one
% just placed), in stable alphabetical-by-instanceTag order.
yl = ylim(ax);
ySpan = diff(yl);
lineStep = 0.06 * ySpan; % vertical stacking step per text line, in data units
if any(strcmp(corner, {'topright', 'topleft'}))
    anchorY = yl(2); dirSign = -1;
else
    anchorY = yl(1); dirSign = 1;
end

familyLabels = findobj(ax, '-regexp', 'Tag', '^pipelineFitLabel_');
isSameCorner = arrayfun(@(o) isstruct(o.UserData) && isequal(o.UserData.corner, corner), familyLabels);
sameCorner = familyLabels(isSameCorner);
if numel(sameCorner) > 1
    tags = arrayfun(@(o) string(o.UserData.instanceTag), sameCorner);
    [~, order] = sort(tags);
    sameCorner = sameCorner(order);
    cumLines = 0;
    for k = 1:numel(sameCorner)
        pos = sameCorner(k).Position;
        pos(2) = anchorY + dirSign * cumLines * lineStep;
        sameCorner(k).Position = pos;
        cumLines = cumLines + sameCorner(k).UserData.nLines;
    end
end

end

function [txt, nOverlap] = tryPlaceAt(ax, tag, lines, color, corner, dataX, dataY, fontSize, fontName)
%TRYPLACEAT Draw the label at corner, then count how many hazard points
%(pipeline.collectHazardPoints) fall inside its ACTUAL rendered Extent --
%at fontSize/fontName, i.e. however it will really be viewed on ax, since
%the same text occupies a different fraction of a differently-sized axes
%(see pipeline.exportPlot's own call, re-verifying a label already placed
%on the live view against its much smaller reconstructed export panel).
xl = xlim(ax);
yl = ylim(ax);
switch corner
    case 'topright'
        x = xl(2); y = yl(2); hAlign = 'right'; vAlign = 'top';
    case 'topleft'
        x = xl(1); y = yl(2); hAlign = 'left'; vAlign = 'top';
    case 'bottomright'
        x = xl(2); y = yl(1); hAlign = 'right'; vAlign = 'bottom';
    otherwise % 'bottomleft'
        x = xl(1); y = yl(1); hAlign = 'left'; vAlign = 'bottom';
end

extraArgs = {};
if ~isempty(fontName)
    extraArgs = {'FontName', fontName};
end
txt = text(ax, x, y, strjoin(lines, newline), 'Tag', tag, ...
    'UserData', struct('corner', corner, 'nLines', numel(lines), 'instanceTag', extractAfter(tag, 'pipelineFitLabel_')), ...
    'FontSize', fontSize, 'Color', color, 'HorizontalAlignment', hAlign, 'VerticalAlignment', vAlign, ...
    'BackgroundColor', [1 1 1], 'Margin', 1, extraArgs{:});

ext = txt.Extent; % [x y w h], data units, regardless of axis scale
inBox = dataX >= ext(1) & dataX <= ext(1) + ext(3) & dataY >= ext(2) & dataY <= ext(2) + ext(4);
nOverlap = sum(inBox);
end

function [allX, allY] = collectHazardPoints(ax)
%COLLECTHAZARDPOINTS Every point a placeFitLabel label should avoid
%covering: data markers, the smooth fit curve itself (a thin curve
%passing through a spot is still something text placed over it would
%visually cross), and -- since a legend is a sibling of ax, not one of
%its Children, so it isn't caught by walking ax.Children -- several
%points sampled across the legend's own box, if ax has one. Without the
%legend points, a label and a 'best'-placed legend could independently
%land on the same spot, each blind to the other.
allX = [];
allY = [];
allChildren = ax.Children;
for k = 1:numel(allChildren)
    c = allChildren(k);
    if strcmp(c.Type, 'line') || strcmp(c.Type, 'errorbar')
        allX = [allX; c.XData(:)]; %#ok<AGROW>
        allY = [allY; c.YData(:)]; %#ok<AGROW>
    end
end

[legX, legY] = legendBoxInDataCoords(ax);
if ~isempty(legX)
    [gx, gy] = meshgrid(linspace(legX(1), legX(2), 5), linspace(legY(1), legY(2), 5));
    allX = [allX; gx(:)];
    allY = [allY; gy(:)];
end
end

function corners = rankCorners(ax, allX, allY, nLines)
%RANKCORNERS All 4 corner names, ordered by a quick density estimate
%(fewest hazard points nearby first) -- a first-pass ranking for
%placeFitLabel to try candidates in, refined there by actually drawing
%each and checking its real rendered extent (a coarse density estimate
%alone can't know how wide the specific text will render).
%
%   Density is evaluated in VISUAL space, not raw data values -- on a
%   log-scaled axis (e.g. +pipeline/buildCDFModule.m's own X-axis Linear/
%   Log switch), "the rightmost 35% of the data range" in raw linear
%   values is a razor-thin sliver right at the axis maximum, nowhere near
%   the visually-right portion of the plot a viewer would call "the right
%   side" -- silently misjudging density otherwise.
xl = xlim(ax);
yl = ylim(ax);
if strcmp(ax.XScale, 'log')
    xtform = @log10;
else
    xtform = @(v) v;
end
if strcmp(ax.YScale, 'log')
    ytform = @log10;
else
    ytform = @(v) v;
end

xlV = xtform(xl);
ylV = ytform(yl);
xSpan = diff(xlV);
ySpan = diff(ylV);
xFrac = 0.35;
yFrac = min(0.6, max(0.3, nLines * 0.09));

allXV = xtform(allX);
allYV = ytform(allY);

names   = {'topright', 'topleft', 'bottomright', 'bottomleft'};
xRanges = {[xlV(2) - xFrac * xSpan, xlV(2)], [xlV(1), xlV(1) + xFrac * xSpan], ...
    [xlV(2) - xFrac * xSpan, xlV(2)], [xlV(1), xlV(1) + xFrac * xSpan]};
yRanges = {[ylV(2) - yFrac * ySpan, ylV(2)], [ylV(2) - yFrac * ySpan, ylV(2)], ...
    [ylV(1), ylV(1) + yFrac * ySpan], [ylV(1), ylV(1) + yFrac * ySpan]};

counts = zeros(1, 4);
for i = 1:4
    inBox = allXV >= xRanges{i}(1) & allXV <= xRanges{i}(2) & allYV >= yRanges{i}(1) & allYV <= yRanges{i}(2);
    counts(i) = sum(inBox);
end
[~, order] = sort(counts);
corners = names(order);
end

function [boxX, boxY] = legendBoxInDataCoords(ax)
%LEGENDBOXINDATACOORDS [x1 x2], [y1 y2] data-coordinate bounding box of
%ax's own legend, or both [] if ax has none. A legend has no direct
%back-reference property to its axes, so the one belonging to ax is found
%by matching its PlotChildren against ax's own children instead.
boxX = [];
boxY = [];

fig = ancestor(ax, 'figure');
lgds = findobj(fig, 'Type', 'legend');
lgd = [];
for i = 1:numel(lgds)
    pc = lgds(i).PlotChildren;
    for j = 1:numel(pc)
        if isvalid(pc(j)) && isequal(ancestor(pc(j), 'axes'), ax)
            lgd = lgds(i);
            break;
        end
    end
    if ~isempty(lgd)
        break;
    end
end
if isempty(lgd)
    return;
end

% Position, in pixels, is relative to the same parent container ax and
% lgd share (true whenever legend(ax, ...) was used to create it) --
% converting both to the SAME units makes their boxes directly comparable
% before mapping the legend's into ax's data coordinate frame via its
% own pixel Position + XLim/YLim.
origAxUnits = ax.Units;
origLgdUnits = lgd.Units;
ax.Units = 'pixels';
lgd.Units = 'pixels';
axPos = ax.Position;
lgdPos = lgd.Position;
ax.Units = origAxUnits;
lgd.Units = origLgdUnits;

% Pixel position maps LINEARLY to log10(data value) on a log-scaled axis,
% not to the raw data value -- interpolate in whichever space (log10 or
% linear) actually corresponds to pixels, then convert back, or a log
% axis's box would come out badly wrong (see the matching note in
% rankCorners above).
xl = xlim(ax);
yl = ylim(ax);
isXLog = strcmp(ax.XScale, 'log');
isYLog = strcmp(ax.YScale, 'log');
if isXLog, xlV = log10(xl); else, xlV = xl; end
if isYLog, ylV = log10(yl); else, ylV = yl; end

fracX1 = (lgdPos(1) - axPos(1)) / axPos(3);
fracX2 = (lgdPos(1) + lgdPos(3) - axPos(1)) / axPos(3);
fracY1 = (lgdPos(2) - axPos(2)) / axPos(4);
fracY2 = (lgdPos(2) + lgdPos(4) - axPos(2)) / axPos(4);

boxXV = xlV(1) + [fracX1, fracX2] * diff(xlV);
boxYV = ylV(1) + [fracY1, fracY2] * diff(ylV);

if isXLog, boxX = 10 .^ boxXV; else, boxX = boxXV; end
if isYLog, boxY = 10 .^ boxYV; else, boxY = boxYV; end
end
