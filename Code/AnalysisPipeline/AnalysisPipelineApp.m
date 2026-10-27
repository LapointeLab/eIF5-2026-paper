classdef AnalysisPipelineApp < handle
    %ANALYSISPIPELINEAPP GUI shell for single-molecule kinetics analyses.
    %   Load a *_state_assign.mat file, then run one or more analysis modules
    %   against it. Each module is a standalone function registered in
    %   registerModules(); its button and result tab are generated automatically.
    %
    %   To add a new module:
    %     1. Write +modules/yourModule.m taking the app as its only argument.
    %        Use app.Data.result (see +pipeline/extractEvents.m) for the data,
    %        and app.getOrCreateTab(title) to get a uitab to draw into.
    %     2. Add one line to registerModules() below.

    properties (Access = public)
        UIFigure
        TabGroup
        Data = []   % populated by onLoadData/extractAndSummarize; see +pipeline/extractEvents.m
        ResultLogs   % per-module result tables, keyed by logKey; see appendResultLog/exportResultLog. containers.Map, built in the constructor (a property default would be a handle object shared by every AnalysisPipelineApp instance).
    end

    properties (Access = private, Constant)
        % Minimum window size below which a module's ctrl row (Channel/Type
        % dropdowns, extra per-module controls, Export button) can start
        % running out of horizontal room and getting clipped with no
        % scrollbar to reach the rest -- e.g. FRET State Lifetime's
        % Threshold field, the widest ctrl row as of this writing (measured
        % content width ~940px + the 300px left panel + grid spacing/padding
        % ~= 1290px; this adds headroom for future modules with even more
        % controls). Deliberately NOT sized to keep any module's flexible
        % content columns (e.g. Association/Dissociation Conformations'
        % frame-sweep plot) at some preferred width -- those resize
        % gracefully on their own, so there's no correctness reason to
        % force a larger floor than the ctrl row actually needs, and doing
        % so just prevents shrinking the window to fit smaller screens.
        MinFigureWidth = 1350
        MinFigureHeight = 650
    end

    properties (Access = private)
        MainGrid
        LoadButton
        FileLabel
        MinEventFramesField
        StatusArea
        AnalysisModulesGrid
        PlottingModulesGrid
        ModuleButtons
        ModuleRegistry = struct('Name', {}, 'Fcn', {}, 'Category', {}, 'RequiresData', {})
        ResultLogCountLabels   % per logKey: every registered "N results logged" label, across all open module tabs. containers.Map, built in the constructor; see ResultLogs.
    end

    methods (Access = public)
        function app = AnalysisPipelineApp()
            app.ResultLogs = containers.Map('KeyType', 'char', 'ValueType', 'any');
            app.ResultLogCountLabels = containers.Map('KeyType', 'char', 'ValueType', 'any');
            app.buildUI();
            app.registerModules();
            app.createModuleButtons();
        end

        function tab = getOrCreateTab(app, title)
            %GETORCREATETAB Return a fresh (emptied) uitab with the given title,
            % reusing an existing tab of the same title if the module has run before.
            existing = findobj(app.TabGroup.Children, 'Title', title);
            if ~isempty(existing)
                tab = existing(1);
                delete(tab.Children);
            else
                tab = uitab(app.TabGroup, 'Title', title);
                tab.Tooltip = 'Right-click to close this tab';
                cm = uicontextmenu(app.UIFigure);
                uimenu(cm, 'Text', 'Close Tab', 'MenuSelectedFcn', @(~, ~) app.closeTab(tab));
                tab.ContextMenu = cm;
            end
            app.TabGroup.SelectedTab = tab;
        end

        function log(app, msg)
            %LOG Append a line (or multiple newline-separated lines) to the status panel.
            existingLines = app.StatusArea.Value;
            if isequal(existingLines, {''})
                existingLines = {};
            end
            newLines = strsplit(msg, newline);
            app.StatusArea.Value = [existingLines(:); newLines(:)];
            scroll(app.StatusArea, 'bottom');
        end

        function loadDataFromFile(app, fullPath)
            %LOADDATAFROMFILE Load and validate a *_state_assign.mat file, then
            % extract events. Split out from the Load-Data button callback so it
            % can be called directly (e.g. from tests) without the file dialog.
            try
                d = load(fullPath);
            catch ME
                uialert(app.UIFigure, ME.message, 'Failed to load file');
                return;
            end

            try
                [d, legacyNote] = pipeline.applyLegacyDefaults(d);
            catch ME
                uialert(app.UIFigure, ME.message, 'Invalid file');
                return;
            end

            required = {'states', 'ttotal', 'channelNames', 'nChPerMol'};
            missing = required(~isfield(d, required));
            if ~isempty(missing)
                uialert(app.UIFigure, sprintf('File is missing required variable(s): %s', strjoin(missing, ', ')), ...
                    'Invalid file');
                return;
            end

            [~, name, ext] = fileparts(fullPath);

            app.Data = struct();
            app.Data.states       = d.states;
            app.Data.ttotal       = d.ttotal;
            app.Data.channelNames = d.channelNames;
            app.Data.nChPerMol    = d.nChPerMol;
            app.Data.fileName     = [name ext];

            app.FileLabel.Text = [name ext];
            if ~isempty(legacyNote)
                app.log(legacyNote);
            end
            app.extractAndSummarize();
        end

        function runModule(app, idx)
            %RUNMODULE Run a registered module by index. Public so modules can
            % be exercised directly (tests, scripting) as well as from buttons.
            try
                app.ModuleRegistry(idx).Fcn(app);
            catch ME
                app.log(sprintf('ERROR in "%s": %s', app.ModuleRegistry(idx).Name, ME.message));
                uialert(app.UIFigure, ME.message, sprintf('%s failed', app.ModuleRegistry(idx).Name));
            end
        end

        function appendResultLog(app, logKey, row)
            %APPENDRESULTLOG Append one result row (struct, scalar fields) to the
            % named per-module result log, identified by logKey (see
            % pipeline.buildFitControls, pipeline.buildGaussianFitControls,
            % +modules/eventSorting.m). Each module gets its own independent
            % table, kept for the lifetime of the app (so it survives closing
            % and reopening that module's tab) but never mixed with any other
            % module's results — columns are aligned rather than requiring an
            % exact match like plain table vertcat does, so e.g. two fits with
            % different Gaussian component counts can still share one table.
            T = struct2table(row, 'AsArray', true);
            if ~isKey(app.ResultLogs, logKey) || isempty(app.ResultLogs(logKey))
                app.ResultLogs(logKey) = T;
            else
                app.ResultLogs(logKey) = AnalysisPipelineApp.appendRowAligned(app.ResultLogs(logKey), T);
            end

            app.refreshResultLogCountLabels(logKey);
        end

        function registerResultLogCountLabel(app, logKey, lbl)
            %REGISTERRESULTLOGCOUNTLABEL Register a "N results logged" uilabel
            % (created by pipeline.buildFitControls/buildGaussianFitControls in
            % some module's panel) to be kept in sync with the named per-module
            % result log. A logKey can be shared by more than one panel (e.g.
            % +modules/lifetimeSorting.m's Short and Long sub-tabs both log into
            % the same module-level table), so every live label registered under
            % that key needs updating, not just the most recently created one.
            if ~isKey(app.ResultLogCountLabels, logKey)
                app.ResultLogCountLabels(logKey) = gobjects(1, 0);
            end
            labels = app.ResultLogCountLabels(logKey);
            valid = isgraphics(labels);
            app.ResultLogCountLabels(logKey) = [labels(valid), lbl];
            app.refreshResultLogCountLabels(logKey);
        end

        function exportResultLog(app, logKey, defaultFileName)
            %EXPORTRESULTLOG Save the named per-module result log to a CSV file.
            if ~isKey(app.ResultLogs, logKey) || isempty(app.ResultLogs(logKey))
                uialert(app.UIFigure, 'No results logged yet.', 'Nothing to export');
                return;
            end

            [fname, fpath] = uiputfile('*.csv', 'Save results as', defaultFileName);
            if isequal(fname, 0)
                return;
            end

            try
                writetable(app.ResultLogs(logKey), fullfile(fpath, fname));
            catch ME
                uialert(app.UIFigure, ME.message, 'Export failed');
            end
        end
    end

    methods (Access = private)
        function enforceMinimumFigureSize(app)
            %ENFORCEMINIMUMFIGURESIZE Snap the window back if shrunk below
            % MinFigureWidth/MinFigureHeight. uifigure has no native
            % minimum-size property, so this is the standard workaround:
            % react to SizeChangedFcn and re-clamp. The width/height check
            % below makes this self-terminating (setting Position re-fires
            % this callback, but the second time through, both dimensions
            % already equal-or-exceed the minimum, so nothing changes and
            % it stops).
            pos = app.UIFigure.Position;
            newW = max(pos(3), app.MinFigureWidth);
            newH = max(pos(4), app.MinFigureHeight);
            if newW ~= pos(3) || newH ~= pos(4)
                app.UIFigure.Position = [pos(1), pos(2), newW, newH];
            end
        end

        function closeTab(app, tab)
            %CLOSETAB Delete a module's result tab. The next click of the module's
            % button just rebuilds it via getOrCreateTab, so this is non-destructive.
            delete(tab);
            keys = app.ResultLogCountLabels.keys;
            for i = 1:numel(keys)
                labels = app.ResultLogCountLabels(keys{i});
                app.ResultLogCountLabels(keys{i}) = labels(isgraphics(labels));
            end
        end

        function refreshResultLogCountLabels(app, logKey)
            if isKey(app.ResultLogs, logKey)
                n = height(app.ResultLogs(logKey));
            else
                n = 0;
            end
            if n == 1
                txt = '1 result logged';
            else
                txt = sprintf('%d results logged', n);
            end
            if ~isKey(app.ResultLogCountLabels, logKey)
                return;
            end
            labels = app.ResultLogCountLabels(logKey);
            for i = 1:numel(labels)
                if isgraphics(labels(i))
                    labels(i).Text = txt;
                end
            end
        end

        function buildUI(app)
            app.UIFigure = uifigure('Name', 'Single-Molecule Kinetics Analysis', 'Position', [100 100 1450 760]);
            % SizeChangedFcn never fires while AutoResizeChildren is 'on'
            % (the uifigure default) -- disabling it is safe here since the
            % whole window is one uigridlayout, which already handles
            % proportional resizing on its own regardless of this setting.
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.SizeChangedFcn = @(~, ~) app.enforceMinimumFigureSize();
            app.MainGrid = uigridlayout(app.UIFigure, [1 2]);
            app.MainGrid.ColumnWidth = {300, '1x'};

            % --- Left control panel ---
            leftPanel = uigridlayout(app.MainGrid, [4 1]);
            leftPanel.RowHeight = {'fit', 'fit', 'fit', '1x'};
            leftPanel.RowSpacing = 10;
            leftPanel.Padding = [0 0 0 0];

            dataPanel = uipanel(leftPanel, 'Title', 'Data');
            dataGrid = uigridlayout(dataPanel, [3 1]);
            dataGrid.RowHeight = {'fit', 'fit', 'fit'};

            app.LoadButton = uibutton(dataGrid, 'Text', 'Load State-Assignment File...', ...
                'ButtonPushedFcn', @(~, ~) app.onLoadData());

            app.FileLabel = uilabel(dataGrid, 'Text', 'No file loaded', 'FontAngle', 'italic');

            minFrameGrid = uigridlayout(dataGrid, [1 2]);
            minFrameGrid.ColumnWidth = {'fit', 'fit'};
            minFrameGrid.Padding = [0 0 0 0];
            uilabel(minFrameGrid, 'Text', 'Min event frames:');
            app.MinEventFramesField = uieditfield(minFrameGrid, 'numeric', 'Value', 1, ...
                'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~, ~) app.onMinEventFramesChanged());

            analysisPanel = uipanel(leftPanel, 'Title', 'Analysis');
            app.AnalysisModulesGrid = uigridlayout(analysisPanel, [1 1]);

            plottingPanel = uipanel(leftPanel, 'Title', 'Plotting');
            app.PlottingModulesGrid = uigridlayout(plottingPanel, [1 1]);

            statusPanel = uipanel(leftPanel, 'Title', 'Status');
            statusGrid = uigridlayout(statusPanel, [1 1]);
            app.StatusArea = uitextarea(statusGrid, 'Value', {''}, 'Editable', 'off');

            % --- Right results area ---
            app.TabGroup = uitabgroup(app.MainGrid);
        end

        function registerModules(app)
            app.ModuleRegistry(end+1) = struct('Name', 'Binding Lifetime Kinetics', ...
                'Fcn', @modules.bindingLifetimeKinetics, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Association Kinetics', ...
                'Fcn', @modules.associationKinetics, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'FRET Efficiency Distribution', ...
                'Fcn', @modules.fretEfficiencyDistribution, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Post-Sync FRET Heatmap', ...
                'Fcn', @modules.fretHeatmap, 'Category', 'Plotting', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'FRET Evolution', ...
                'Fcn', @modules.fretEvolution, 'Category', 'Plotting', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'FRET State Lifetime', ...
                'Fcn', @modules.fretStateLifetime, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Combined Dataset Overlay', ...
                'Fcn', @modules.combinedDatasetOverlay, 'Category', 'Plotting', 'RequiresData', false);
            app.ModuleRegistry(end+1) = struct('Name', 'Association/Dissociation Conformations', ...
                'Fcn', @modules.associationDissociationConformations, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Event Sorting by Mean FRET', ...
                'Fcn', @modules.eventSorting, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Event Sorting by Lifetime', ...
                'Fcn', @modules.lifetimeSorting, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Donor-Acceptor Correlation', ...
                'Fcn', @modules.donorAcceptorCorrelation, 'Category', 'Analysis', 'RequiresData', true);
            app.ModuleRegistry(end+1) = struct('Name', 'Summary Figure', ...
                'Fcn', @modules.summaryFigure, 'Category', 'Plotting', 'RequiresData', false);
            % Add future modules here. Category must be 'Analysis' or 'Plotting'
            % (see createModuleButtons), matching which left-panel section the
            % module's button appears in. RequiresData = false only for a module
            % that works independently of a loaded state-assignment file (e.g.
            % one combining previously-exported .fig files, like Combined
            % Dataset Overlay) -- its button starts enabled immediately rather
            % than waiting for extractAndSummarize's post-load Enable pass.
        end

        function createModuleButtons(app)
            % Buttons are grouped into the Analysis/Plotting panels by
            % Category, but app.ModuleButtons stays a flat array indexed by
            % ModuleRegistry position (not by on-screen position), since
            % runModule(idx) and the Enable-toggle loop in
            % extractAndSummarize both address buttons by that registry index.
            n = numel(app.ModuleRegistry);
            app.ModuleButtons = gobjects(1, n);

            categories = {app.ModuleRegistry.Category};
            analysisIdx = find(strcmp(categories, 'Analysis'));
            plottingIdx = find(strcmp(categories, 'Plotting'));

            app.AnalysisModulesGrid.RowHeight = repmat({'fit'}, 1, max(numel(analysisIdx), 1));
            for k = 1:numel(analysisIdx)
                i = analysisIdx(k);
                b = uibutton(app.AnalysisModulesGrid, 'Text', app.ModuleRegistry(i).Name, ...
                    'Enable', app.enableStrFor(i));
                b.ButtonPushedFcn = @(~, ~) app.runModule(i);
                app.ModuleButtons(i) = b;
            end

            app.PlottingModulesGrid.RowHeight = repmat({'fit'}, 1, max(numel(plottingIdx), 1));
            for k = 1:numel(plottingIdx)
                i = plottingIdx(k);
                b = uibutton(app.PlottingModulesGrid, 'Text', app.ModuleRegistry(i).Name, ...
                    'Enable', app.enableStrFor(i));
                b.ButtonPushedFcn = @(~, ~) app.runModule(i);
                app.ModuleButtons(i) = b;
            end
        end

        function s = enableStrFor(app, i)
            %ENABLESTRFOR 'on' if module i works without loaded data, else 'off'
            % (enabled later, once extractAndSummarize runs after a data load).
            if app.ModuleRegistry(i).RequiresData
                s = 'off';
            else
                s = 'on';
            end
        end

        function onLoadData(app)
            [fname, fpath] = uigetfile({'*.mat', 'State-assignment files (*.mat)'}, ...
                'Select a state-assignment file (*_assigned_corrected.mat, or an older ttotal/states .mat)');
            if isequal(fname, 0)
                return;
            end
            app.loadDataFromFile(fullfile(fpath, fname));
        end

        function onMinEventFramesChanged(app)
            if isempty(app.Data)
                return;
            end
            app.extractAndSummarize();
        end

        function extractAndSummarize(app)
            [onLevel, notes] = pipeline.detectOnLevels(app.Data.states, app.Data.channelNames, app.Data.nChPerMol);
            minEventFrames = app.MinEventFramesField.Value;

            try
                result = pipeline.extractEvents(app.Data.states, app.Data.ttotal, app.Data.channelNames, ...
                    app.Data.nChPerMol, onLevel, minEventFrames);
            catch ME
                uialert(app.UIFigure, ME.message, 'Event extraction failed');
                return;
            end

            app.Data.onLevel        = onLevel;
            app.Data.minEventFrames = minEventFrames;
            app.Data.result         = result;

            app.log(sprintf('--- Loaded %s ---', app.Data.fileName));
            app.log(sprintf('%d molecules | %d frames | %.4f s/frame', ...
                result.molecules, result.nFrames, result.Exposure));
            for k = 1:numel(notes)
                app.log(['Note: ' notes{k}]);
            end
            for k = 1:numel(result.channelNames)
                app.log(sprintf('%-10s on-level=%g: %d events across %d molecules', ...
                    result.channelNames{k}, result.onLevel(k), result.eventCounts(k), ...
                    numel(unique([result.events{k}.mol]))));
            end

            for i = 1:numel(app.ModuleButtons)
                app.ModuleButtons(i).Enable = 'on';
            end
        end
    end

    methods (Static, Access = private)
        function combined = appendRowAligned(existing, newRow)
            %APPENDROWALIGNED Vertically concatenate two tables whose column sets
            % may differ, filling any column missing from one side with NaN
            % (numeric columns) or a missing string (text columns) rather than
            % erroring like plain [T1;T2] does when variable names don't match.
            existingVars = existing.Properties.VariableNames;
            newVars      = newRow.Properties.VariableNames;

            onlyInExisting = setdiff(existingVars, newVars, 'stable');
            onlyInNew      = setdiff(newVars, existingVars, 'stable');

            for i = 1:numel(onlyInExisting)
                name = onlyInExisting{i};
                newRow.(name) = AnalysisPipelineApp.missingFiller(existing.(name), height(newRow));
            end
            for i = 1:numel(onlyInNew)
                name = onlyInNew{i};
                existing.(name) = AnalysisPipelineApp.missingFiller(newRow.(name), height(existing));
            end

            allVars  = [existingVars, onlyInNew];
            combined = [existing(:, allVars); newRow(:, allVars)];
        end

        function v = missingFiller(exampleColumn, n)
            %MISSINGFILLER n missing values of the same type as exampleColumn.
            if isstring(exampleColumn)
                v = repmat(string(missing), n, 1);
            elseif iscell(exampleColumn)
                v = repmat({''}, n, 1);
            else
                v = nan(n, 1);
            end
        end
    end
end
