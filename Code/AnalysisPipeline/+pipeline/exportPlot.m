function exportPlot(ax, moduleTag, baseName, suggestedName, forceSquare)
%EXPORTPLOT Export a uiaxes plot to .fig, .png, and .eps as a small,
%publication-ready panel, matching pipeline.exportCombinedOverlay's house
%style so every module's exported plots look consistent.
%   pipeline.exportPlot(ax, moduleTag)                        - prompts for a save location
%   pipeline.exportPlot(ax, moduleTag, baseName)               - saves directly to <baseName>_<tag>.fig/.png/.eps
%   pipeline.exportPlot(ax, moduleTag, [], suggestedName)      - prompts, pre-filling suggestedName
%   pipeline.exportPlot(ax, moduleTag, baseName, [], forceSquare) - override panel shape (see below)
%
%   moduleTag : the calling module's display name (e.g. 'Binding Lifetime
%               Kinetics'), sanitized via pipeline.moduleFileTag and
%               appended as a fixed "_<tag>" suffix on every file this
%               call writes, regardless of what baseName/the save dialog
%               produced. This is how +modules/summaryFigure.m identifies
%               which module a given .fig on disk came from when it scans
%               a folder -- automatic and independent of how the user
%               happened to name the file, rather than a naming
%               convention the user has to remember to follow. A module
%               that exports more than one distinct plot (e.g.
%               +modules/donorAcceptorCorrelation.m's histogram/points/
%               scatter trio) additionally puts its OWN sub-plot suffix
%               (e.g. "_histogram") on baseName before calling this, so
%               the final name carries both: "<user text>_histogram_DonorAcceptorCorrelation".
%
%   forceSquare : optional. true forces a 112.5x112.5pt square panel
%                 (matching pipeline.exportCombinedOverlay's own
%                 calibrated size, for plots that are conceptually the
%                 same shape as its data-points-plus-fit-line panels);
%                 false forces a 150x112.5pt landscape panel, for plots
%                 whose data has a meaningful non-square character (a
%                 heatmap, a multi-trace plot) that a literal square would
%                 visually compress or stretch; [] or omitted (the
%                 default) auto-detects from the source axes'
%                 PlotBoxAspectRatioMode -- 'manual' (i.e. the module
%                 already called `axis(ax,'square')` for its own live
%                 view, as every CDF/histogram/scatter-style module does)
%                 means square, 'auto' means landscape.
%
%   Handles line-based plots (CDF/histogram markers, fit curves,
%   errorbar-based scatter plots, text annotations, and a legend if
%   present), filled-contour heatmaps (pipeline.buildSyncHeatmap-style
%   plots), and image-based heatmaps (imagesc-style plots, e.g.
%   +modules/associationDissociationConformations.m), since copyobj-ing
%   any of these uiaxes children keeps it a uifigure-only type with the
%   same Property-Editor limitations described below.
%
%   Rebuilds the plot on a genuine classic axes/figure (not a uiaxes copy)
%   in a separate offscreen figure — not a screenshot of the small GUI
%   panel — with:
%     - a fixed-size axes box (112.5x112.5pt square, or 150x112.5pt
%       landscape -- see forceSquare above), so panels from different
%       modules sit consistently in a multi-panel paper figure
%     - transparent background (no white box to delete before placing the
%       panel into a paper figure), no grid, box off
%     - mid-to-dark gray (0.3,0.3,0.3) axis lines/ticks, 0.5pt wide,
%       pointing outward, long enough to read clearly at this size
%     - Arial Narrow, black text (tick labels, axis labels, title,
%       legend, colorbar), sized for a small panel
%     - marker/line sizes capped at small-panel-appropriate values,
%       regardless of how large they're drawn in the live in-app preview
%       (which is sized for on-screen work, not a printed panel)
%   Then exports:
%     .fig  - true classic MATLAB figure (matlab.graphics.axis.Axes, not
%             UIAxes), so it reopens with full Edit Plot / Property Editor
%             support rather than the read-only-ish uifigure equivalent.
%             copyobj-ing a uiaxes keeps it a UIAxes even inside a classic
%             figure container, which is why this reconstructs the plot
%             from its underlying data instead of copying the object.
%     .png  - 600 DPI raster, for quick previews/slides
%     .eps  - vector output (ContentType 'vector'), so lines/markers/text
%             stay as editable paths in Illustrator rather than a flattened
%             raster image
%
%   The live GUI axes (ax) is left untouched; all reconstruction happens on
%   a temporary classic figure that is discarded after export.

if nargin < 5
    forceSquare = [];
end
if nargin < 4
    suggestedName = 'plot';
end

if nargin < 3 || isempty(baseName)
    [fname, fpath] = uiputfile('*.eps', 'Export plot (.fig/.png/.eps all saved)', [char(suggestedName) '.eps']);
    if isequal(fname, 0)
        return;
    end
    [~, name, ~] = fileparts(fname);
    baseName = fullfile(fpath, name);
end

baseName = [baseName '_' pipeline.moduleFileTag(moduleTag)];

if isempty(forceSquare)
    forceSquare = strcmp(ax.PlotBoxAspectRatioMode, 'manual');
end

GRAY = [0.3 0.3 0.3];
BLACK = [0 0 0];
if forceSquare
    AXIS_W = 112.5;
    AXIS_H = 112.5;
else
    AXIS_W = 150;
    AXIS_H = 112.5;
end
MARGIN_L  = 40;
MARGIN_B  = 32;
MARGIN_TR = 15;

% A colorbar is a sibling of ax in the container hierarchy (not one of its
% Children), so it needs extra canvas width reserved for it up front,
% before the figure is even created.
hasColorbar = ~isempty(findobj(ancestor(ax, 'figure'), 'Type', 'colorbar'));
if hasColorbar
    marginRightForColorbar = 55;
else
    marginRightForColorbar = 0;
end

figTmp = figure('Visible', 'off', 'Color', 'none', 'Units', 'points', 'Position', ...
    [100 100, AXIS_W + MARGIN_L + MARGIN_TR + marginRightForColorbar, AXIS_H + MARGIN_B + MARGIN_TR]);
cleanupObj = onCleanup(@() close(figTmp));

axNew = axes(figTmp, 'Units', 'points');
axNew.Position = [MARGIN_L, MARGIN_B, AXIS_W, AXIS_H];

srcContour = findobj(ax, 'Type', 'contour');
if ~isempty(srcContour)
    % Filled-contour heatmap: recreate with the same data/levels, then copy
    % the colormap, color limits, and colorbar (a colorbar is a sibling of
    % ax in the container hierarchy, not a child of it, hence searching the
    % ancestor figure rather than ax itself).
    contourf(axNew, srcContour.XData, srcContour.YData, srcContour.ZData, ...
        srcContour.LevelList, 'LineStyle', srcContour.LineStyle, 'Fill', srcContour.Fill);
    axNew.Colormap = ax.Colormap;
    axNew.CLim = ax.CLim;
    % contourf() auto-scales axNew to the full extent of the data arrays
    % passed in, which is NOT necessarily the user's chosen view -- a
    % module's own x/y-axis window controls (e.g. fretHeatmap.m's x-axis
    % limit field) restrict ax.XLim/YLim directly without slicing the
    % underlying data, so that restriction must be copied explicitly too.
    axNew.XLim = ax.XLim;
    axNew.YLim = ax.YLim;

    srcColorbar = findobj(ancestor(ax, 'figure'), 'Type', 'colorbar');
    if ~isempty(srcColorbar)
        cbNew = colorbar(axNew);
        cbNew.Label.String = srcColorbar(1).Label.String;
        % colorbar() makes MATLAB auto-shrink axNew to share the figure with
        % it, silently overriding the fixed Position set above (the same
        % behavior already confirmed for an 'eastoutside' legend in
        % pipeline.exportCombinedOverlay) -- re-assert the intended size now
        % that the colorbar's own layout pass has already run.
        axNew.Position = [MARGIN_L, MARGIN_B, AXIS_W, AXIS_H];
    end
elseif ~isempty(findobj(ax, 'Type', 'image'))
    % Image-based heatmap (imagesc): recreate with the same CData/axes
    % extent, then copy colormap/CLim/colorbar exactly as for the contour
    % case above. image() doesn't auto-scale axes limits to its data the
    % way plot()/contourf() do, so XLim/YLim are copied explicitly too.
    srcImage = findobj(ax, 'Type', 'image');
    srcImage = srcImage(1);
    image(axNew, 'XData', srcImage.XData, 'YData', srcImage.YData, 'CData', srcImage.CData, ...
        'CDataMapping', srcImage.CDataMapping);
    axNew.YDir = ax.YDir;
    axNew.XLim = ax.XLim;
    axNew.YLim = ax.YLim;
    axNew.Colormap = ax.Colormap;
    axNew.CLim = ax.CLim;

    srcColorbar = findobj(ancestor(ax, 'figure'), 'Type', 'colorbar');
    if ~isempty(srcColorbar)
        cbNew = colorbar(axNew);
        cbNew.Label.String = srcColorbar(1).Label.String;
        % See the matching re-assertion in the contour branch above: the
        % colorbar's own layout pass silently overrides the fixed Position
        % set earlier.
        axNew.Position = [MARGIN_L, MARGIN_B, AXIS_W, AXIS_H];
    end
else
    % Line-based plot (CDF/histogram markers, fit curves, frame-sweep
    % scatter+error-bar plots with p-value text annotations): recreate
    % each line/errorbar/text object from the source uiaxes, in original
    % stacking order (Children is listed most-recently-added-first), then
    % reconstruct a legend if the source had one. Marker/line sizes are
    % capped, not copied verbatim -- the live preview is sized for
    % on-screen work at a much larger scale than this panel.
    MAX_MARKER_SIZE  = 4;
    MAX_LINE_WIDTH   = 0.75; % connecting/fit lines (Marker == 'none')
    MAX_MARKER_LINE_WIDTH = 0.5; % marker outlines (open circles/diamonds etc.) -- thinner than a fit line so they don't look heavy at this panel size
    MAX_CAP_SIZE     = 6;

    hold(axNew, 'on');
    srcChildren = flipud(ax.Children);
    legendMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
    deferredFitLabels = struct('instanceTag', {}, 'lines', {}, 'color', {});
    for i = 1:numel(srcChildren)
        c = srcChildren(i);
        switch c.Type
            case 'line'
                % Line.Color never exposes a 4th (alpha) element on
                % read-back, even when the line was originally drawn with
                % one (e.g. FRET Evolution's semi-transparent overlaid
                % traces) -- if the source line tagged its alpha in
                % UserData (see +modules/fretEvolution.m), append it here
                % so the reconstructed line keeps its transparency instead
                % of silently rendering opaque. Note this only works for
                % Color: MarkerFaceColor/MarkerEdgeColor reject a 4-element
                % RGBA both at plot()-call time and via a property
                % assignment afterward ("Invalid RGB triplet") -- MATLAB
                % Line markers have no real alpha support at all, so any
                % module wanting a translucent marker fill pre-blends a
                % flat opaque color itself instead (see
                % pipeline.plotJitteredPoints).
                lineColor = c.Color;
                if isscalar(c.UserData) && isnumeric(c.UserData) && c.UserData >= 0 && c.UserData <= 1
                    lineColor = [lineColor, c.UserData]; %#ok<AGROW>
                end
                % A pure line (no marker, e.g. a fit curve) gets the fit-line
                % width; anything with a marker (data points, open
                % circles/diamonds) gets the thinner marker-outline width,
                % since Marker edge stroke width is governed by this same
                % LineWidth property.
                if strcmp(c.Marker, 'none')
                    thisLineWidth = MAX_LINE_WIDTH;
                else
                    thisLineWidth = MAX_MARKER_LINE_WIDTH;
                end
                newObj = plot(axNew, c.XData, c.YData, 'Color', lineColor, 'LineStyle', c.LineStyle, ...
                    'LineWidth', min(c.LineWidth, thisLineWidth), 'Marker', c.Marker, ...
                    'MarkerSize', min(c.MarkerSize, MAX_MARKER_SIZE), ...
                    'MarkerEdgeColor', c.MarkerEdgeColor, 'MarkerFaceColor', c.MarkerFaceColor, ...
                    'Tag', c.Tag, 'UserData', c.UserData);
                % UserData carries the alpha tag itself (used just above to
                % build lineColor) onto the NEW line, not just its effect on
                % Color -- without this, the alpha-preblend step below (and
                % any later re-export of this SAVED .fig, e.g.
                % +modules/summaryFigure.m) can't detect which lines need
                % it, since Line.Color never reports its own 4th element
                % back on read-back either.
                legendMap(double(c)) = newObj;

            case 'errorbar'
                newObj = errorbar(axNew, c.XData, c.YData, c.YNegativeDelta, c.YPositiveDelta, ...
                    'LineStyle', c.LineStyle, 'LineWidth', min(c.LineWidth, MAX_MARKER_LINE_WIDTH), 'Marker', c.Marker, ...
                    'MarkerSize', min(c.MarkerSize, MAX_MARKER_SIZE), 'Color', c.Color, ...
                    'MarkerEdgeColor', c.MarkerEdgeColor, 'MarkerFaceColor', c.MarkerFaceColor, ...
                    'CapSize', min(c.CapSize, MAX_CAP_SIZE), 'Tag', c.Tag);
                legendMap(double(c)) = newObj;

            case 'text'
                if startsWith(c.Tag, 'pipelineFitLabel_')
                    % Deferred, not copied verbatim -- see below, after
                    % axNew has its final XLim/YLim/legend. pipeline.
                    % placeFitLabel picked this corner by checking overlap
                    % against the LIVE axes at its own (much larger) size;
                    % simply copying that position here would carry over
                    % a placement decision made for a different-sized
                    % canvas, silently wrong exactly when the smaller
                    % panel makes the same text occupy a larger fraction
                    % of it (see the module's own placeFitLabel calls).
                    deferredFitLabels(end + 1) = struct( ...
                        'instanceTag', extractAfter(c.Tag, 'pipelineFitLabel_'), ...
                        'lines', {cellstr(c.String)}, 'color', c.Color); %#ok<AGROW>

                else
                    text(axNew, c.Position(1), c.Position(2), c.String, ...
                        'HorizontalAlignment', c.HorizontalAlignment, 'VerticalAlignment', c.VerticalAlignment, ...
                        'FontSize', 6, 'FontWeight', c.FontWeight, 'Color', BLACK, 'FontName', 'Arial Narrow', 'Tag', c.Tag);
                end
        end
    end
    hold(axNew, 'off');

    % plot()/errorbar() auto-scale axNew to the data's own extent, which
    % silently drops any manual XLim/YLim padding the source axes had
    % beyond that extent (e.g. the frame-sweep plot's margin around its
    % outermost points in +modules/associationDissociationConformations.m)
    % -- copy the source's actual limits explicitly so the export matches
    % what's shown live, the same way the contour/image branches above
    % already do.
    axNew.XLim = ax.XLim;
    axNew.YLim = ax.YLim;

    % Copied here already (not just in the unconditional copy near the end
    % of this function that covers every branch) because the deferred fit
    % labels placed below need axNew.XScale/YScale correct BEFORE that
    % happens -- pipeline.placeFitLabel's corner-picking treats a log axis
    % very differently from a linear one.
    axNew.XScale = ax.XScale;
    axNew.YScale = ax.YScale;

    % Same reasoning for tick marks/labels: plot()/errorbar() auto-generate
    % axNew's ticks from the data, silently dropping any custom categorical
    % labels the source axes had set explicitly (e.g. Event Sorting's "Low
    % Mean FRET (n=..)" / "High Mean FRET (n=..)", or the frame-sweep
    % plot's "Final"/"2nd to last"/etc. in
    % +modules/associationDissociationConformations.m) -- without this the
    % export shows meaningless auto-numbered ticks instead.
    axNew.XTick = ax.XTick;
    axNew.YTick = ax.YTick;
    axNew.XTickLabel = ax.XTickLabel;
    axNew.YTickLabel = ax.YTickLabel;
    axNew.XTickLabelRotation = ax.XTickLabelRotation;
    axNew.YTickLabelRotation = ax.YTickLabelRotation;

    % Now that axNew has its final XLim/YLim/XScale/YScale and every
    % line/errorbar it will ever have, place any deferred rate/mean
    % label(s) for real -- BEFORE legend reconstruction below, whose own
    % overlap-avoidance logic needs to see them already placed to avoid
    % landing on top of one.
    for li = 1:numel(deferredFitLabels)
        d = deferredFitLabels(li);
        pipeline.placeFitLabel(axNew, d.instanceTag, d.lines, d.color, 6, 'Arial Narrow');
    end

    % A legend is a sibling of ax in the container hierarchy,
    % not one of its Children, and its PlotChildren point at the SOURCE
    % line/errorbar handles -- legendMap (built above, keyed by each
    % source handle's unique numeric ID) recovers the corresponding
    % freshly-created handles on axNew to legend against instead.
    srcLegend = findobj(ancestor(ax, 'figure'), 'Type', 'legend');
    if ~isempty(srcLegend)
        srcHandles = srcLegend(1).PlotChildren;
        newHandles = gobjects(1, numel(srcHandles));
        allFound = true;
        for hi = 1:numel(srcHandles)
            key = double(srcHandles(hi));
            if isKey(legendMap, key)
                newHandles(hi) = legendMap(key);
            else
                allFound = false;
                break;
            end
        end
        if allFound && ~isempty(newHandles)
            % 'best' (overlay-capable) rather than copying the source's own
            % Location: keeping the axes box a fixed, predictable size
            % matters more than avoiding legend/data overlap, and an
            % outside-positioned legend would force MATLAB to shrink the
            % axes to make room for it (see pipeline.exportCombinedOverlay,
            % where this was confirmed empirically).
            newLegend = legend(axNew, newHandles, srcLegend(1).String, 'Location', 'best', ...
                'Box', 'off', 'FontSize', 6, 'TextColor', BLACK);

            % 'best' only avoids the DATA it's plotted against -- it has no
            % idea this panel might also carry an on-plot rate/mean label
            % (pipeline.placeFitLabel; reconstructed above as a 'text'
            % child, Tag prefixed 'pipelineFitLabel_'), so the two can
            % land in the same corner. If so, try each of legend()'s other
            % built-in INSIDE-axes corners in turn (never an outside one,
            % for the same axes-size reason 'best' was chosen over the
            % source's own Location above) until one doesn't share a
            % corner with any such label, identified by the HorizontalAlignment/
            % VerticalAlignment already copied onto it (a cheap proxy for
            % "which corner it's anchored to" that needs no extra
            % bookkeeping) -- falling back to the original 'best' spot if
            % none of them clear it either.
            %
            % newLegend.Location itself is unusable for figuring out which
            % corner 'best' actually resolved to -- it keeps reporting
            % 'best' even after MATLAB has picked a concrete spot, rather
            % than updating to read e.g. 'northeast' -- so that spot has
            % to be read back from the legend's own resolved Position
            % instead, compared against the axes box's own center.
            fitLabels = findobj(axNew, 'Type', 'text', '-regexp', 'Tag', '^pipelineFitLabel_');
            if ~isempty(fitLabels)
                labelCorners = arrayfun(@textCornerOf, fitLabels, 'UniformOutput', false);
                corners   = {'topright', 'topleft', 'bottomright', 'bottomleft'};
                locations = {'northeast', 'northwest', 'southeast', 'southwest'};

                origLgdUnits = newLegend.Units;
                newLegend.Units = axNew.Units; % 'points' -- comparable to axNew.Position below
                lgdPos = newLegend.Position;
                newLegend.Units = origLgdUnits;
                axPos = axNew.Position;
                isRight = (lgdPos(1) + lgdPos(3) / 2) >= (axPos(1) + axPos(3) / 2);
                isTop   = (lgdPos(2) + lgdPos(4) / 2) >= (axPos(2) + axPos(4) / 2);
                if isTop && isRight
                    curCorner = 'topright';
                elseif isTop
                    curCorner = 'topleft';
                elseif isRight
                    curCorner = 'bottomright';
                else
                    curCorner = 'bottomleft';
                end

                if any(strcmp(labelCorners, curCorner))
                    for ci = 1:numel(locations)
                        if ~strcmp(corners{ci}, curCorner) && ~any(strcmp(labelCorners, corners{ci}))
                            newLegend.Location = locations{ci};
                            break;
                        end
                    end
                end
            end
        end
    end
end

axNew.XScale = ax.XScale;
axNew.YScale = ax.YScale;

axNew.LineWidth  = 0.5;
axNew.XColor     = GRAY;
axNew.YColor     = GRAY;
axNew.TickDir    = 'out';
axNew.TickLength = [0.025, 0.025];
axNew.Box        = 'off';
axNew.XGrid      = 'off';
axNew.YGrid      = 'off';
axNew.FontSize   = 7;
axNew.FontName   = 'Arial Narrow';
axNew.Color      = 'none';

% Tick label TEXT is black, independent of the gray axis lines/tick marks
% above (XColor/YColor govern the line+ticks; the ruler's own
% TickLabelColor governs just the number text and can be set separately).
axNew.XAxis.TickLabelColor = BLACK;
axNew.YAxis.TickLabelColor = BLACK;

xlabel(axNew, ax.XLabel.String, 'FontSize', 8, 'Color', BLACK, 'FontName', 'Arial Narrow');
ylabel(axNew, ax.YLabel.String, 'FontSize', 8, 'Color', BLACK, 'FontName', 'Arial Narrow');
title(axNew, ax.Title.String, 'FontSize', 8, 'FontWeight', 'normal', 'Color', BLACK, 'FontName', 'Arial Narrow');

% Style the reconstructed colorbar (contour/image branches above) to match:
% black readable text: a colorbar's line/tick/label color is one unified
% property (no XColor-vs-TickLabelColor-style split like a regular axes
% ruler has), so this favors legible black text/ticks over matching the
% axes' gray exactly.
cbNew = findobj(figTmp, 'Type', 'colorbar');
if ~isempty(cbNew)
    cbNew.Color = BLACK;
    cbNew.FontName = 'Arial Narrow';
    cbNew.FontSize = 7;
    cbNew.Label.FontName = 'Arial Narrow';
    cbNew.Label.FontSize = 8;
    cbNew.Label.Color = BLACK;
    % The default colorbar is oversized for a panel this small -- shrink
    % the color swatch bar itself (tick labels/label reflow automatically)
    % to ~35% of its default width and 50% of its default height, keeping
    % it vertically centered on its original span.
    cbNew.Units = 'points';
    oldCbPos = cbNew.Position;
    newCbWidth = oldCbPos(3) * 0.35;
    newCbHeight = oldCbPos(4) * 0.5;
    newCbBottom = oldCbPos(2) + (oldCbPos(4) - newCbHeight) / 2;
    cbNew.Position = [oldCbPos(1), newCbBottom, newCbWidth, newCbHeight];
end

% Saved with Visible restored to 'on' so the .fig opens normally later,
% rather than inheriting this function's offscreen working state.
figTmp.Visible = 'on';
% print(), not exportgraphics(), for the .png: exportgraphics's own "tight"
% bounding-box crop can badly miscompute for this small, transparent-
% background axes -- confirmed by reproducing a real bug report (a
% Binding Lifetime Kinetics export rendering with most of the eCDF cropped
% away and the axes badly rescaled) down to exportgraphics specifically:
% axNew's own XLim/YLim/Position were all verified correct immediately
% before the call, and print() of that SAME figure at that SAME moment
% renders correctly, so the defect is in exportgraphics's crop/rescale
% step, not anything about the reconstructed plot itself. Both already
% fall back to a white background here regardless (transparency isn't
% supported for PNG on this platform either way -- see the .eps export
% below, which is unaffected and stays on exportgraphics for its vector
% ContentType).
print(figTmp, [baseName '.png'], '-dpng', '-r600');

% EPS/PostScript cannot represent true alpha transparency at all (unlike
% PNG) -- passing through a semi-transparent line's real RGBA color (or
% RGBA marker face/edge color, e.g. +modules/eventSorting.m's filled
% points) would either get silently dropped (rendering fully saturated) or
% produce the "very faint but fully opaque" artifact seen in practice. For
% any line carrying an alpha tag in UserData (see
% +modules/fretEvolution.m), swap in a color pre-blended against white at a
% fixed, predictable export opacity just for the .eps, then restore the
% true RGBA color afterward so the already-exported .png and the
% about-to-be-saved .fig keep genuine, correctly-compositing transparency.
EPS_EXPORT_ALPHA = 0.5;
alphaLines = findobj(figTmp, 'Type', 'line');
isAlphaTagged = arrayfun(@(o) isscalar(o.UserData) && isnumeric(o.UserData) && o.UserData >= 0 && o.UserData <= 1, alphaLines);
alphaLines = alphaLines(isAlphaTagged);
origLineColors = cell(1, numel(alphaLines));
for k = 1:numel(alphaLines)
    origLineColors{k} = alphaLines(k).Color;
    baseRGB = origLineColors{k}(1:3);
    alphaLines(k).Color = EPS_EXPORT_ALPHA * baseRGB + (1 - EPS_EXPORT_ALPHA) * [1 1 1];
end
exportgraphics(figTmp, [baseName '.eps'], 'ContentType', 'vector', 'BackgroundColor', 'none');
for k = 1:numel(alphaLines)
    alphaLines(k).Color = origLineColors{k};
end

% The .fig is for interactive editing/reuse, not a fixed print size the way
% .eps/.png (already exported above, at the true small panel size) need to
% be -- scale the whole figure up before saving it so it opens at a
% comfortable, clickable size instead of the tiny print-precise panel.
FIG_SCALE = 4;
figTmp.Position(3) = (AXIS_W + MARGIN_L + MARGIN_TR + marginRightForColorbar) * FIG_SCALE;
figTmp.Position(4) = (AXIS_H + MARGIN_B + MARGIN_TR) * FIG_SCALE;
axNew.Position = [MARGIN_L, MARGIN_B, AXIS_W, AXIS_H] * FIG_SCALE;
cbFigScale = findobj(figTmp, 'Type', 'colorbar');
if ~isempty(cbFigScale)
    % A colorbar's Position (including the width shrink applied above) was
    % computed entirely in the small pre-scale coordinate frame and, unlike
    % axNew.Position, is never touched by the scalableProps sweep below --
    % without this, the .fig would keep a tiny sliver colorbar next to a
    % now-4x-bigger axes. All 4 elements scale uniformly by FIG_SCALE, the
    % same way axNew.Position above does, to preserve the same relative
    % layout at the larger size.
    cbFigScale.Units = 'points';
    cbFigScale.Position = cbFigScale.Position * FIG_SCALE;
end
% Color 'none' (transparent, for the .eps/.png already exported above) is
% only meaningful for image export -- an actually-opened, on-screen .fig
% renders a 'none' figure/axes as solid black, making the black
% text/markers/lines invisible against it. A .fig is meant to be viewed and
% edited in MATLAB, so it gets a normal white background instead.
figTmp.Color = 'white';
axNew.Color = 'white';
scalableProps = {'LineWidth', 'MarkerSize', 'CapSize'};
for p = 1:numel(scalableProps)
    scaledObjs = findall(figTmp, '-property', scalableProps{p});
    for k = 1:numel(scaledObjs)
        scaledObjs(k).(scalableProps{p}) = scaledObjs(k).(scalableProps{p}) * FIG_SCALE;
    end
end
% FontSize is set to a flat value, not scaled by FIG_SCALE like the other
% properties above -- scaling the small panel's 7/8pt text by 4x (28/32pt)
% is too large once the figure itself is also 4x bigger; 18pt reads
% comfortably at this figure size regardless of what the small-panel size
% was.
FIG_FONT_SIZE = 18;
fontObjs = findall(figTmp, '-property', 'FontSize');
for k = 1:numel(fontObjs)
    fontObjs(k).FontSize = FIG_FONT_SIZE;
end
cbScale = findobj(figTmp, 'Type', 'colorbar');
if ~isempty(cbScale)
    % A colorbar's Label is a Text object but not reachable through the
    % standard Children hierarchy the sweep above walks, so it needs its
    % own explicit sizing.
    cbScale.Label.FontSize = FIG_FONT_SIZE;
end
savefig(figTmp, [baseName '.fig']);

end

function corner = textCornerOf(txt)
%TEXTCORNEROF Which of 'topright'/'topleft'/'bottomright'/'bottomleft' a
%text object is anchored to, read off its own HorizontalAlignment/
%VerticalAlignment -- a cheap proxy for "which corner" that needs no
%extra bookkeeping, since pipeline.placeFitLabel always sets both to
%anchor its on-plot rate/mean labels at one of these four corners, and
%this function's own reconstruction of a 'text' child (see the 'case
%''text''' branch above) copies both straight from the source.
if strcmp(txt.VerticalAlignment, 'top')
    vpart = 'top';
else
    vpart = 'bottom';
end
if strcmp(txt.HorizontalAlignment, 'right')
    hpart = 'right';
else
    hpart = 'left';
end
corner = [vpart hpart];
end
