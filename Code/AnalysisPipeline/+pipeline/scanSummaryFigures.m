function [results, notFoundLabels] = scanSummaryFigures(folder)
%SCANSUMMARYFIGURES Find every .png in folder matching each plot this app
%can produce.
%   [results, notFoundLabels] = scanSummaryFigures(folder)
%
%   Every module tags its exported .png with a fixed "_<ModuleTag>" suffix
%   (pipeline.exportPlot / pipeline.moduleFileTag), automatically,
%   regardless of what filename the user chose -- this scans folder for
%   those suffixes so +modules/summaryFigure.m can assemble a composite
%   without the user manually picking each file. .png (not .fig) is what
%   gets composited -- see pipeline.placeImagePanel -- since it's the
%   exact, already publication-tuned pixels pipeline.exportPlot wrote,
%   with nothing to re-derive or drift from.
%
%   A module that exports more than one distinct plot (Association/
%   Dissociation Conformations' heatmap + frame-sweep; Donor-Acceptor
%   Correlation's histogram/points/scatter trio) is matched by both its
%   own sub-plot suffix and its module tag; every other module is matched
%   by module tag alone.
%
%   EVERY matching file becomes its own panel -- not just the newest. A
%   module is routinely exported more than once for the same plot type
%   with genuinely different content (a different channel, a different
%   event-type filter, the association vs. dissociation direction in
%   Association/Dissociation Conformations...), and dropping all but the
%   latest silently threw those away. This is meant to be exhaustive, not
%   curated -- a folder with a lot of exports in it produces a large
%   summary page, which is fine (see +modules/summaryFigure.m).
%
%   results : struct array, one entry PER MATCHED FILE (so a plot type
%             exported 3 times produces 3 entries), in registry order,
%             each internally sorted by filename for a stable, predictable
%             order run to run. Fields:
%               DisplayLabel  "<panel type> -- <distinguishing name>",
%                              the distinguishing part being the matched
%                              filename with its known suffix and
%                              extension stripped (whatever the user typed
%                              or a module's own suggested name put there,
%                              e.g. channel/event-type -- the only
%                              information available to tell two exports
%                              of the same plot type apart).
%               ModuleName    the owning module's display name
%               FilePath      absolute path to the matched .png
%   notFoundLabels : cell array of panel-type labels with zero matches
%             (e.g. a module never run/exported in this folder), for
%             UI feedback.

REGISTRY = {
    'Binding Lifetime Kinetics',               '',                'Binding Lifetime Kinetics'
    'Association Kinetics',                    '',                'Association Kinetics'
    'FRET Efficiency Distribution',            '',                'FRET Efficiency Distribution'
    'Post-Sync FRET Heatmap',                  '',                'Post-Sync FRET Heatmap'
    'FRET Evolution',                          '',                'FRET Evolution'
    'FRET State Lifetime',                     '',                'FRET State Lifetime'
    'Combined Dataset Overlay',                '',                'Combined Dataset Overlay'
    'Association/Dissociation Conformations',  'heatmap',         'Association/Dissociation Conformations (Heatmap)'
    'Association/Dissociation Conformations',  'frameSweep',      'Association/Dissociation Conformations (Frame Sweep)'
    'Event Sorting by Mean FRET',              '',                'Event Sorting by Mean FRET'
    'Event Sorting by Lifetime',               '',                'Event Sorting by Lifetime'
    'Donor-Acceptor Correlation',              'histogram',       'Donor-Acceptor Correlation (Histogram)'
    'Donor-Acceptor Correlation',              'pointsCI',        'Donor-Acceptor Correlation (Points + CI)'
    'Donor-Acceptor Correlation',              'donorVsAcceptor', 'Donor-Acceptor Correlation (Donor vs Acceptor)'
    };

allFigs = dir(fullfile(folder, '*.png'));
allNames = {allFigs.name};

results = struct('DisplayLabel', {}, 'ModuleName', {}, 'FilePath', {});
notFoundLabels = {};

for i = 1:size(REGISTRY, 1)
    moduleName = REGISTRY{i, 1};
    subSuffix  = REGISTRY{i, 2};
    panelLabel = REGISTRY{i, 3};
    tag = pipeline.moduleFileTag(moduleName);
    if isempty(subSuffix)
        suffix = ['_' tag '.png'];
    else
        suffix = ['_' subSuffix '_' tag '.png'];
    end

    matchIdx = find(endsWith(allNames, suffix));
    if isempty(matchIdx)
        notFoundLabels{end + 1} = panelLabel; %#ok<AGROW>
        continue;
    end

    matchNames = allNames(matchIdx);
    [~, sortOrder] = sort(matchNames);
    matchIdx = matchIdx(sortOrder);

    for m = 1:numel(matchIdx)
        thisName = allNames{matchIdx(m)};
        distinguishing = thisName(1:end - numel(suffix));
        entry.DisplayLabel = sprintf('%s -- %s', panelLabel, distinguishing);
        entry.ModuleName = moduleName;
        entry.FilePath = fullfile(folder, thisName);
        results(end + 1) = entry; %#ok<AGROW>
    end
end

end
