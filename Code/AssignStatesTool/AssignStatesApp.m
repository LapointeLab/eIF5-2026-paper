classdef AssignStatesApp < handle
    %ASSIGNSTATESAPP GUI for the vbFRET manual state-assignment workflow.
    %   Covers the whole path from a raw SPARTAN .traces file, through
    %   launching vbFRET and merging its Analysis Summary, to visually
    %   reviewing/correcting per-molecule state assignments and saving a
    %   *_assigned_corrected.mat file for AnalysisPipelineApp.
    %
    %   See ExampleCode/ for the four manual scripts this app replaces
    %   (LL_trace_to_TIRF.m, assign_states_vbFRET.m, LL_AssignStates_v1.m)
    %   and +pipeline/ for their generalized, testable function forms.

    properties (Access = public)
        UIFigure
        Data = []   % see loadDataStruct: .ttotal .states .channelNames .nChPerMol .nMol .currentMol .fileName
    end

    properties (Access = private, Constant)
        MinFigureWidth = 1200
        MinFigureHeight = 700
    end

    properties (Access = private)
        MainGrid

        % --- Data/pipeline panel ---
        FileLabel
        StatusArea
        ThresholdField

        % --- Review controls ---
        MolField
        MolCountLabel
        TitleLabel
        ChannelDropdown
        NumStatesField
        ActiveStateDropdown

        % --- Axes ---
        TopAxes
        BottomAxes
        TopLines        % one line handle per channel
        BottomRefLine    % raw active-channel trace (thin, reference)
        BottomStateLine  % assigned-state step line (thick, dashed)

        % --- Click-driven assignment state machine (see onAxesClicked) ---
        PendingAction = ''            % '', 'region', 'threshold', or 'erase'
        PendingClicks = zeros(0, 2)   % accumulated [x y] data-coordinate clicks for PendingAction

        % --- Hand-rolled drag-to-zoom-box (see onAxesMouseDown) ---
        DragAxes                      % axes the current drag started on, or []
        DragStartPoint = []           % [x y] data-coordinate start point of the current drag
        DragRect                      % live rubber-band rectangle graphics object, or []
    end

    methods (Access = public)
        function app = AssignStatesApp()
            app.buildUI();
        end
    end

    %% ------------------------------------------------------------------
    %  Data/pipeline callbacks. Public (not just button callbacks) so they
    %  can be exercised directly for scripting/testing, matching
    %  AnalysisPipelineApp's loadDataFromFile/runModule convention.
    %% ------------------------------------------------------------------
    methods (Access = public)
        function onAssignStates(app)
            %ONASSIGNSTATES Entry point for the "Assign States" button in
            % BOTH the 2-Color and 3/4-Color panels -- identical code, per
            % the shared review screen, just reached from either menu.
            % Accepts a raw .traces file (imports it) or an existing
            % ttotal/states .mat (opens it) and lands on the review screen
            % either way.
            app.pickAndLoadDataFile();
        end

        function ok = pickAndLoadDataFile(app)
            %PICKANDLOADDATAFILE Prompt for, and load, either a raw SPARTAN
            % .traces file (converted via pipeline.importTraces) or an
            % existing ttotal/states .mat file. Returns true if data was
            % loaded, false if the user canceled or loading failed.
            ok = false;
            [fname, fpath] = uigetfile({'*.mat;*.traces;*.rawtraces', ...
                'Data files (*.mat, *.traces, *.rawtraces)'}, ...
                'Select a data file (raw .traces, or a ttotal/states .mat)');
            if isequal(fname, 0)
                return;
            end
            fullPath = fullfile(fpath, fname);
            [~, ~, ext] = fileparts(fullPath);

            if any(strcmpi(ext, {'.traces', '.rawtraces'}))
                try
                    [ttotal, states, channelNames, nChPerMol] = pipeline.importTraces(fullPath); %#ok<PROP>
                catch ME
                    uialert(app.UIFigure, ME.message, 'Import failed');
                    app.log(['Import failed: ' ME.message]);
                    return;
                end
                d = struct('ttotal', ttotal, 'states', states, ...
                    'channelNames', {channelNames}, 'nChPerMol', nChPerMol); %#ok<PROP>
                app.loadDataStruct(d, fname);
                app.log(sprintf('Imported "%s" (%d molecules, %d channels/molecule: %s).', ...
                    fname, app.Data.nMol, app.Data.nChPerMol, strjoin(app.Data.channelNames, ', ')));
            else
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
                    uialert(app.UIFigure, sprintf('File is missing required variable(s): %s', ...
                        strjoin(missing, ', ')), 'Invalid file');
                    return;
                end
                app.loadDataStruct(d, fname);
                if ~isempty(legacyNote)
                    app.log(legacyNote);
                end
                resumeNote = '';
                if isfield(d, 'currentMol')
                    app.Data.currentMol = max(1, min(app.Data.nMol, double(d.currentMol)));
                    resumeNote = sprintf(' (resuming at molecule %d)', app.Data.currentMol);
                end
                app.log(sprintf('Opened "%s" (%d molecules)%s.', fname, app.Data.nMol, resumeNote));
                app.resetAxesForNewMolecule();
            end
            ok = true;
        end

        function ok = ensureDataLoaded(app)
            %ENSUREDATALOADED Used by steps (like Merge vbFRET Summary)
            % that need a ttotal source but aren't preceded by their own
            % explicit import button -- prompts for one only if nothing is
            % loaded yet.
            if ~isempty(app.Data)
                ok = true;
                return;
            end
            app.log('No data loaded yet -- select a ttotal source file (raw .traces or .mat) first.');
            ok = app.pickAndLoadDataFile();
        end

        function onLaunchVbFret(app)
            try
                vbFRET();
                app.log(['Launched vbFRET. In vbFRET: load your best_fret.traces file, set max ' ...
                    'states to 3, use >=20 iterations, then File > Save Data > Save Analysis ' ...
                    'Summary (name it to end in _vbFRET-states) when done.']);
            catch ME
                if contains(ME.message, 'Unrecognized function or variable') || ...
                        strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
                    uialert(app.UIFigure, ['vbFRET was not found on the MATLAB path. Add its ' ...
                        'folder (e.g. ebfret-gui) via Home > Set Path, then try again.'], ...
                        'vbFRET not found');
                else
                    uialert(app.UIFigure, ME.message, 'Failed to launch vbFRET');
                end
                app.log(['Failed to launch vbFRET: ' ME.message]);
            end
        end

        function onMergeVbFret(app)
            %ONMERGEVBFRET Needs TWO files: the ttotal source (raw .traces
            % or a converted .mat) and the vbFRET Analysis Summary
            % (*_vbFRET-states.mat). If neither is loaded yet, an upfront
            % dialog says so before the two file pickers run in turn. The
            % merged result is auto-saved as *_vbFRET-states_assigned.mat
            % (this lab's naming convention -- see the written workflow),
            % so this step needs no separate manual Save.
            if isempty(app.Data)
                uiconfirm(app.UIFigure, sprintf(['Merging a vbFRET Analysis Summary needs TWO files:\n\n' ...
                    '1) The ttotal source -- your raw .traces file, or an already-\n' ...
                    '   converted ttotal/states .mat\n' ...
                    '2) The vbFRET Analysis Summary (usually named ..._vbFRET-states.mat)\n\n' ...
                    'You will be prompted for each in turn, starting with the ttotal source.']), ...
                    'Two files needed', 'Options', {'OK'}, 'Icon', 'info');
            end
            if ~app.ensureDataLoaded()
                return;
            end

            [fname, fpath] = uigetfile('*.mat', ...
                'Select the vbFRET Analysis Summary file (usually named ..._vbFRET-states.mat)');
            if isequal(fname, 0)
                return;
            end
            try
                d = load(fullfile(fpath, fname));
            catch ME
                uialert(app.UIFigure, ME.message, 'Failed to load file');
                return;
            end
            if ~isfield(d, 'path')
                uialert(app.UIFigure, ['File does not contain a ''path'' variable (expected ' ...
                    'from vbFRET''s Analysis Summary export).'], 'Invalid file');
                return;
            end

            threshold = app.ThresholdField.Value;
            try
                app.Data.states = pipeline.mergeVbFretSummary(app.Data.ttotal, app.Data.states, ...
                    app.Data.channelNames, app.Data.nChPerMol, d.path, threshold);
            catch ME
                uialert(app.UIFigure, ME.message, 'Merge failed');
                app.log(['Merge failed: ' ME.message]);
                return;
            end
            app.log(sprintf('Merged vbFRET summary "%s" at threshold %.4g.', fname, threshold));

            % Auto-save, following this lab's ..._vbFRET-states_assigned.mat
            % convention: append "_assigned" to the vbFRET summary's own
            % filename, saved alongside it.
            [~, vbfretBase] = fileparts(fname);
            outName = [vbfretBase '_assigned.mat'];
            outPath = fullfile(fpath, outName);
            S = struct('ttotal', app.Data.ttotal, 'states', app.Data.states, ...
                'channelNames', {app.Data.channelNames}, 'nChPerMol', app.Data.nChPerMol);
            try
                save(outPath, '-struct', 'S');
                app.Data.fileName = outName;
                app.FileLabel.Text = outName;
                app.log(sprintf('Automatically saved merged assignment to "%s".', outPath));
            catch ME
                uialert(app.UIFigure, ME.message, ...
                    'Auto-save failed (the merge is still in memory -- use Save As to save it manually)');
                app.log(['Auto-save failed: ' ME.message]);
            end

            app.drawMolecule();
        end

        function onSaveAs(app)
            if isempty(app.Data)
                uialert(app.UIFigure, 'Nothing to save yet.', 'No data loaded');
                return;
            end
            defaultName = 'assigned_corrected.mat';
            if ~isempty(app.Data.fileName)
                [~, base] = fileparts(app.Data.fileName);
                defaultName = [base '_assigned_corrected.mat'];
            end
            [fname, fpath] = uiputfile('*.mat', 'Save corrected assignment as', defaultName);
            if isequal(fname, 0)
                return;
            end
            S = struct();
            S.ttotal       = app.Data.ttotal;
            S.states       = app.Data.states;
            S.channelNames = app.Data.channelNames;
            S.nChPerMol    = app.Data.nChPerMol;
            try
                save(fullfile(fpath, fname), '-struct', 'S');
            catch ME
                uialert(app.UIFigure, ME.message, 'Save failed');
                return;
            end
            app.log(sprintf('Saved corrected assignment to "%s".', fname));
        end

        function onSaveProgress(app)
            if isempty(app.Data)
                uialert(app.UIFigure, 'Nothing to save yet.', 'No data loaded');
                return;
            end
            defaultName = 'assign_progress.mat';
            if ~isempty(app.Data.fileName)
                [~, base] = fileparts(app.Data.fileName);
                defaultName = [base '_progress.mat'];
            end
            [fname, fpath] = uiputfile('*.mat', 'Save progress as', defaultName);
            if isequal(fname, 0)
                return;
            end
            S = struct();
            S.ttotal       = app.Data.ttotal;
            S.states       = app.Data.states;
            S.channelNames = app.Data.channelNames;
            S.nChPerMol    = app.Data.nChPerMol;
            S.currentMol   = app.Data.currentMol;
            try
                save(fullfile(fpath, fname), '-struct', 'S');
            catch ME
                uialert(app.UIFigure, ME.message, 'Save failed');
                return;
            end
            app.log(sprintf('Saved progress to "%s" (molecule %d of %d).', ...
                fname, app.Data.currentMol, app.Data.nMol));
        end

        function onExportTrace(app)
            %ONEXPORTTRACE Export the current molecule's two plots (raw
            % channels on top, active channel + assigned states below) as
            % .fig, .eps or .png -- one format per export, chosen by the
            % file-type dropdown in the save dialog (or a typed extension).
            if isempty(app.Data)
                uialert(app.UIFigure, 'Nothing to export yet.', 'No data loaded');
                return;
            end
            base = 'trace';
            if ~isempty(app.Data.fileName)
                [~, base] = fileparts(app.Data.fileName);
            end
            defaultName = sprintf('%s_mol%d.fig', base, app.Data.currentMol);
            filters = {'*.fig', 'MATLAB Figure (*.fig)'; ...
                       '*.eps', 'EPS vector graphic (*.eps)'; ...
                       '*.png', 'PNG image (*.png)'};
            [fname, fpath, filterIdx] = uiputfile(filters, 'Export trace as', defaultName);
            if isequal(fname, 0)
                return;
            end
            % A typed extension wins; otherwise use the dropdown's choice.
            exts = {'.fig', '.eps', '.png'};
            [~, ~, ext] = fileparts(fname);
            if ~ismember(lower(ext), exts)
                fname = [fname exts{filterIdx}];
            end
            try
                app.exportTraceToFile(fullfile(fpath, fname));
            catch ME
                uialert(app.UIFigure, ME.message, 'Export failed');
                app.log(['Export failed: ' ME.message]);
                return;
            end
            app.log(sprintf('Exported molecule %d to "%s".', app.Data.currentMol, fname));
        end

        function exportTraceToFile(app, fullPath)
            %EXPORTTRACETOFILE Rebuild the current molecule's two plots on a
            % standard (classic) figure and save it as .fig/.eps/.png,
            % chosen by fullPath's extension. Always the FULL time range
            % regardless of the on-screen zoom. Split out from onExportTrace
            % so it can be driven without the file dialog.
            %
            % Rebuilt from the plotted data rather than copyobj'd: copying a
            % uiaxes keeps it a UIAxes even inside a classic figure, which
            % doesn't reopen as a normal editable .fig.
            [~, ~, ext] = fileparts(fullPath);
            ext = lower(ext);
            if ~ismember(ext, {'.fig', '.eps', '.png'})
                error('AssignStatesApp:badExportFormat', ...
                    'Unsupported export format "%s" (use .fig, .eps or .png).', ext);
            end

            t = app.Data.ttotal(:, 1);
            fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'pixels', ...
                'Position', [100 100 1000 700], 'NumberTitle', 'off', ...
                'Name', sprintf('Molecule %d', app.Data.currentMol));
            cleanupObj = onCleanup(@() close(fig)); %#ok<NASGU>

            tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            axTop = nexttile(tl);
            hold(axTop, 'on');
            for k = 1:numel(app.TopLines)
                plot(axTop, app.TopLines(k).XData, app.TopLines(k).YData, ...
                    'Color', app.TopLines(k).Color, 'LineWidth', 1, ...
                    'DisplayName', app.TopLines(k).DisplayName);
            end
            hold(axTop, 'off');
            legend(axTop, 'Location', 'northeast');
            title(axTop, sprintf('Molecule %d of %d -- raw channel traces', ...
                app.Data.currentMol, app.Data.nMol));
            ylabel(axTop, 'Intensity, A.U.');
            grid(axTop, 'on');

            axBot = nexttile(tl);
            hold(axBot, 'on');
            chName = app.ChannelDropdown.Value;
            plot(axBot, app.BottomRefLine.XData, app.BottomRefLine.YData, ...
                'Color', app.BottomRefLine.Color, 'LineWidth', 1, 'DisplayName', [chName ' (raw)']);
            plot(axBot, app.BottomStateLine.XData, app.BottomStateLine.YData, '--k', ...
                'LineWidth', app.BottomStateLine.LineWidth, 'DisplayName', 'assigned state (scaled)');
            hold(axBot, 'off');
            legend(axBot, 'Location', 'northeast');
            title(axBot, sprintf('Active channel "%s" + assigned states', chName));
            xlabel(axBot, 'Time, s');
            ylabel(axBot, 'Intensity, A.U.');
            grid(axBot, 'on');

            linkaxes([axTop, axBot], 'x');
            xlim(axTop, [min(t) max(t)]);

            switch ext
                case '.fig'
                    % Visible restored so the saved figure opens normally
                    % rather than inheriting this offscreen working state.
                    fig.Visible = 'on';
                    savefig(fig, fullPath);
                case '.eps'
                    exportgraphics(fig, fullPath, 'ContentType', 'vector');
                case '.png'
                    exportgraphics(fig, fullPath, 'Resolution', 300);
            end
        end

        function loadDataStruct(app, d, fileName)
            %LOADDATASTRUCT Populate app.Data from a struct with
            % ttotal/states/channelNames/nChPerMol (already validated by
            % the caller) and refresh the review screen.
            app.Data = struct();
            app.Data.ttotal       = d.ttotal;
            app.Data.states       = d.states;
            app.Data.channelNames = d.channelNames;
            app.Data.nChPerMol    = double(d.nChPerMol);
            app.Data.nMol         = (size(d.ttotal, 2) - 1) / app.Data.nChPerMol;
            app.Data.currentMol   = 1;
            app.Data.fileName     = fileName;

            app.FileLabel.Text = fileName;
            app.ChannelDropdown.Items = app.Data.channelNames;
            fretIdx = pipeline.findChannelIndex(app.Data.channelNames, 'fret');
            if ~isempty(fretIdx)
                app.ChannelDropdown.Value = app.Data.channelNames{fretIdx};
            else
                app.ChannelDropdown.Value = app.Data.channelNames{1};
            end

            app.buildTopLines();
            app.resetAxesForNewMolecule();
        end
    end

    %% ------------------------------------------------------------------
    %  Review/correction: navigation, assignment, plotting. Public for the
    %  same scripting/testing reason as the block above.
    %% ------------------------------------------------------------------
    methods (Access = public)
        function onKeyPress(app, event)
            if isempty(app.Data)
                return;
            end
            switch event.Key
                case 'rightarrow'
                    app.acceptNext();
                case 'leftarrow'
                    app.goBack();
                case 'n'
                    app.acceptNext();
                case 'p'
                    app.goBack();
                case 'semicolon'
                    app.eraseCurrent();
                case 'shift'
                    app.regionAssign();
                case 't'
                    app.thresholdAssign();
                case {'u', 'slash'}
                    app.resetZoom();
                case {'return', 'enter'}
                    app.eraseEventAtClick();
                case 'escape'
                    app.cancelPendingAction();
                otherwise
                    % States are numbered from 1 (State 1 = OFF, State 2 =
                    % ON, ...) to match the keyboard's own 1..9,0 row, so
                    % pressing digit d selects state d directly (no off-by-
                    % one); '0' is state 10, following that same row.
                    if numel(event.Character) == 1 && ismember(event.Character, '1':'9')
                        idx = str2double(event.Character);
                        if idx <= app.NumStatesField.Value
                            app.ActiveStateDropdown.Value = app.ActiveStateDropdown.Items{idx};
                        end
                    elseif strcmp(event.Character, '0')
                        idx = 10;
                        if idx <= app.NumStatesField.Value
                            app.ActiveStateDropdown.Value = app.ActiveStateDropdown.Items{idx};
                        end
                    end
            end
        end

        function acceptNext(app)
            if isempty(app.Data)
                return;
            end
            if app.Data.currentMol < app.Data.nMol
                app.Data.currentMol = app.Data.currentMol + 1;
                app.resetAxesForNewMolecule();
            else
                app.log('Already at the last molecule.');
            end
        end

        function goBack(app)
            if isempty(app.Data)
                return;
            end
            if app.Data.currentMol > 1
                app.Data.currentMol = app.Data.currentMol - 1;
                app.resetAxesForNewMolecule();
            else
                app.log('Already at the first molecule.');
            end
        end

        function onMolFieldChanged(app)
            if isempty(app.Data)
                return;
            end
            val = round(app.MolField.Value);
            val = max(1, min(app.Data.nMol, val));
            app.MolField.Value = val;
            app.Data.currentMol = val;
            app.resetAxesForNewMolecule();
        end

        function eraseCurrent(app)
            if isempty(app.Data)
                return;
            end
            col = app.activeChannelCol();
            app.Data.states(:, col) = 0;
            app.log(sprintf('Erased states for molecule %d, channel "%s".', ...
                app.Data.currentMol, app.ChannelDropdown.Value));
            app.drawMolecule();
        end

        function regionAssign(app)
            %REGIONASSIGN Arms click-driven region assignment: the next two
            % clicks on either axes (handled by onAxesClicked) set the
            % region bounds. Deliberately does NOT use ginput -- ginput
            % resolves its target figure via gcf, and gcf does not track
            % uifigure at all (confirmed: calling gcf with only a uifigure
            % open silently creates a brand-new, disconnected plain Figure
            % window and waits for clicks there instead). Axes
            % ButtonDownFcn + event.IntersectionPoint is the App-Designer-
            % native equivalent and never touches gcf.
            if isempty(app.Data)
                return;
            end
            app.armPendingAction('region');
            app.log('Region assign: click twice on the plot to set the region bounds...');
        end

        function thresholdAssign(app)
            %THRESHOLDASSIGN Arms click-driven threshold assignment (see
            % regionAssign for why this is click-armed rather than ginput).
            if isempty(app.Data)
                return;
            end
            app.armPendingAction('threshold');
            app.log(['Threshold assign: click twice -- the x of both clicks sets the region, ' ...
                'the y of the 2nd click sets the threshold...']);
        end

        function eraseEventAtClick(app)
            %ERASEEVENTATCLICK Arms click-driven single-event erase: the
            % next click on either axes (handled by onAxesClicked) finds
            % the contiguous run of assigned state at/nearest that click
            % and zeroes just that run -- not the entire molecule. Bound to
            % Enter/Return so pressing Enter then clicking removes one
            % unwanted event without bracketing it with a region-assign at
            % state 0.
            if isempty(app.Data)
                return;
            end
            app.armPendingAction('erase');
            app.log('Erase event: click once on (or near) the event to erase...');
        end

        function armPendingAction(app, action)
            app.PendingAction = action;
            app.PendingClicks = zeros(0, 2);
            % Crosshair cursor is the only visible sign a click-mode is
            % active (there's no ginput-style modal dialog anymore), so
            % it's the cue the user has to go by.
            app.UIFigure.Pointer = 'crosshair';
        end

        function disarmPendingAction(app)
            %DISARMPENDINGACTION Silently clear pending-click state (used
            % after a successful click sequence, and when navigating away
            % mid-sequence). See cancelPendingAction for the user-facing,
            % logged version (Escape).
            app.PendingAction = '';
            app.PendingClicks = zeros(0, 2);
            app.UIFigure.Pointer = 'arrow';
        end

        function cancelPendingAction(app)
            if ~isempty(app.PendingAction)
                app.log(sprintf('Cancelled %s.', app.PendingAction));
            end
            app.disarmPendingAction();
        end

        function onAxesMouseDown(app, src, event)
            %ONAXESMOUSEDOWN ButtonDownFcn for TopAxes/BottomAxes, installed
            % once and never toggled. Branches on whether a click-driven
            % action is armed:
            %   armed  -> onAxesClicked (region/threshold/erase click capture)
            %   idle   -> starts a hand-rolled drag-to-zoom-box gesture
            %             (onDragMotion/onDragUp), so the two never fight
            %             over the same click.
            %
            % This does NOT use MATLAB's built-in zoom()/Interactions
            % zoom modes for the idle case. Both were tried and rejected:
            %   - Interactions=zoomInteraction doesn't provide drag-to-zoom
            %     at all -- per `help zoomInteraction`, it only does
            %     scroll/pinch zoom.
            %   - Classic zoom() (ExampleCode's `zoom on`) does provide
            %     drag-to-zoom via matlab.graphics.interaction.webmodes.
            %     zoomWeb, but confirmed by testing: while active it force-
            %     clears the figure's KeyPressFcn/WindowKeyPressFcn to
            %     empty and BLOCKS re-assigning them ("Setting the
            %     WindowKeyPressFcn property is not permitted while this
            %     mode is active"), restoring the original value only when
            %     zoom is turned back off. Since box-zoom needs to be on by
            %     default (i.e. almost always), that made keyboard
            %     navigation almost always dead too.
            % Implementing the drag rectangle by hand avoids MATLAB's
            % interactive-mode manager entirely, so nothing ever reserves
            % WindowKeyPressFcn.
            if isempty(app.Data)
                return;
            end
            if ~isempty(app.PendingAction)
                app.onAxesClicked(event);
                return;
            end

            pt = event.IntersectionPoint;
            app.DragAxes = src;
            app.DragStartPoint = pt(1:2);
            app.DragRect = rectangle(src, 'Position', [pt(1), pt(2), eps, eps], ...
                'EdgeColor', [0.15, 0.45, 0.85], 'LineWidth', 1.25, 'LineStyle', '--');
            app.UIFigure.WindowButtonMotionFcn = @(~, ~) app.onDragMotion();
            app.UIFigure.WindowButtonUpFcn = @(~, ~) app.onDragUp();
        end

        function onDragMotion(app)
            if isempty(app.DragAxes) || ~isvalid(app.DragAxes) || isempty(app.DragRect) || ~isvalid(app.DragRect)
                return;
            end
            cp = app.DragAxes.CurrentPoint;
            x1 = cp(1, 1);
            y1 = cp(1, 2);
            x0 = app.DragStartPoint(1);
            y0 = app.DragStartPoint(2);
            app.DragRect.Position = [min(x0, x1), min(y0, y1), abs(x1 - x0), abs(y1 - y0)];
        end

        function onDragUp(app)
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];

            ax = app.DragAxes;
            app.clearDragRect();
            app.DragAxes = [];
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            cp = ax.CurrentPoint;
            x0 = app.DragStartPoint(1);
            y0 = app.DragStartPoint(2);
            x1 = cp(1, 1);
            y1 = cp(1, 2);

            % A plain click (negligible movement) is not a zoom -- ignore
            % it rather than snapping to a razor-thin box on every click.
            curXLim = xlim(ax);
            curYLim = ylim(ax);
            if abs(x1 - x0) < 0.01 * diff(curXLim) || abs(y1 - y0) < 0.01 * diff(curYLim)
                return;
            end

            xlim(ax, sort([x0, x1]));
            ylim(ax, sort([y0, y1]));
        end

        function clearDragRect(app)
            if ~isempty(app.DragRect) && isvalid(app.DragRect)
                delete(app.DragRect);
            end
            app.DragRect = [];
        end

        function onAxesClicked(app, event)
            %ONAXESCLICKED Collects clicks for whichever action
            % regionAssign/thresholdAssign/eraseEventAtClick armed, and
            % performs it once enough clicks have been collected. Called
            % from onAxesMouseDown only while an action is armed.
            if isempty(app.Data) || isempty(app.PendingAction)
                return;
            end
            pt = event.IntersectionPoint;
            app.PendingClicks(end + 1, :) = pt(1:2);

            switch app.PendingAction
                case 'erase'
                    app.finishEraseEventAtClick(app.PendingClicks(1, 1));
                    app.disarmPendingAction();
                case 'region'
                    if size(app.PendingClicks, 1) >= 2
                        app.finishRegionAssign(app.PendingClicks(1, 1), app.PendingClicks(2, 1));
                        app.disarmPendingAction();
                    else
                        app.log('Region assign: click the 2nd boundary point...');
                    end
                case 'threshold'
                    if size(app.PendingClicks, 1) >= 2
                        app.finishThresholdAssign(app.PendingClicks(1, 1), app.PendingClicks(2, 1), ...
                            app.PendingClicks(2, 2));
                        app.disarmPendingAction();
                    else
                        app.log('Threshold assign: click the 2nd point (its height sets the threshold)...');
                    end
            end
        end

        function finishRegionAssign(app, x1, x2)
            t = app.Data.ttotal(:, 1);
            [startF, finishF] = pipeline.regionToFrames(x1, x2, t);
            col = app.activeChannelCol();
            val = app.activeStateValue();
            app.Data.states(startF:finishF, col) = val;
            app.log(sprintf('Assigned state %d to frames %d-%d (molecule %d, channel "%s").', ...
                val, startF, finishF, app.Data.currentMol, app.ChannelDropdown.Value));
            app.drawMolecule();
        end

        function finishThresholdAssign(app, x1, x2, yThreshold)
            t = app.Data.ttotal(:, 1);
            [startF, finishF] = pipeline.regionToFrames(x1, x2, t);
            col = app.activeChannelCol();
            val = app.activeStateValue();
            trace = app.Data.ttotal(:, col);
            mask = false(size(trace));
            mask(startF:finishF) = true;
            mask = mask & (trace > yThreshold);
            app.Data.states(mask, col) = val;
            app.log(sprintf('Threshold-assigned state %d above %.4g within frames %d-%d (molecule %d, channel "%s").', ...
                val, yThreshold, startF, finishF, app.Data.currentMol, app.ChannelDropdown.Value));
            app.drawMolecule();
        end

        function finishEraseEventAtClick(app, xClick)
            t = app.Data.ttotal(:, 1);
            frame = round(interp1(t, 1:numel(t), xClick, 'linear', 'extrap'));
            frame = max(1, min(numel(t), frame));

            col = app.activeChannelCol();
            vec = app.Data.states(:, col);

            if vec(frame) == 0
                onIdx = find(vec ~= 0);
                if isempty(onIdx)
                    app.log('No assigned event near that click.');
                    return;
                end
                [~, nearest] = min(abs(onIdx - frame));
                frame = onIdx(nearest);
            end

            val = vec(frame);
            lo = frame;
            while lo > 1 && vec(lo - 1) == val
                lo = lo - 1;
            end
            hi = frame;
            while hi < numel(vec) && vec(hi + 1) == val
                hi = hi + 1;
            end

            app.Data.states(lo:hi, col) = 0;
            app.log(sprintf('Erased event at frames %d-%d (molecule %d, channel "%s").', ...
                lo, hi, app.Data.currentMol, app.ChannelDropdown.Value));
            app.drawMolecule();
        end

        function resetZoom(app)
            %RESETZOOM Reset both axes back to their full view -- x (shared,
            % via linkaxes) back to the full time range, and y (independent
            % per axes, since the top/bottom plots use different scales)
            % back to auto-fit, undoing any manual pan/zoom on either.
            if isempty(app.Data)
                return;
            end
            t = app.Data.ttotal(:, 1);
            xlim(app.TopAxes, [min(t) max(t)]);
            app.TopAxes.YLimMode = 'auto';
            app.BottomAxes.YLimMode = 'auto';
        end

        function onNumStatesChanged(app)
            % Labels are 1-indexed (State 1 = OFF, ...) to match the digit-
            % key picker in onKeyPress; activeStateValue() still converts
            % back to a 0-indexed stored value (position - 1), so OFF is
            % still written as 0 -- unchanged from before, and still
            % consistent with mergeVbFretSummary's 0/1 output and
            % AnalysisPipelineApp's expectations.
            n = round(app.NumStatesField.Value);
            app.NumStatesField.Value = n;
            items = arrayfun(@(k) sprintf('State %d', k), 1:n, 'UniformOutput', false);
            if n == 2
                items = {'State 1 (OFF)', 'State 2 (ON)'};
            end
            prevVal = app.ActiveStateDropdown.Value;
            app.ActiveStateDropdown.Items = items;
            if ismember(prevVal, items)
                app.ActiveStateDropdown.Value = prevVal;
            else
                app.ActiveStateDropdown.Value = items{end};
            end
        end

        function col = activeChannelCol(app)
            chIdx = find(strcmp(app.Data.channelNames, app.ChannelDropdown.Value), 1);
            molCols = pipeline.getMolCols(app.Data.currentMol, app.Data.nChPerMol);
            col = molCols(chIdx);
        end

        function val = activeStateValue(app)
            items = app.ActiveStateDropdown.Items;
            idx = find(strcmp(items, app.ActiveStateDropdown.Value), 1);
            val = idx - 1;
        end

        function colors = channelColors(app, channelNames)
            %CHANNELCOLORS Fixed house colors for the well-known channel
            % names (donor = green, acceptor = dark purple, fret = bright
            % blue); any other channel name (e.g. a 4-color experiment's
            % extra dye) falls back to MATLAB's default line color order.
            n = numel(channelNames);
            fallback = lines(max(n, 1));
            colors = zeros(n, 3);
            for k = 1:n
                name = lower(channelNames{k});
                if contains(name, 'donor')
                    colors(k, :) = [0, 0.6, 0];
                elseif contains(name, 'acceptor')
                    colors(k, :) = [0.45, 0, 0.55];
                elseif contains(name, 'fret')
                    colors(k, :) = [0, 0, 1];
                else
                    colors(k, :) = fallback(k, :);
                end
            end
        end

        function buildTopLines(app)
            cla(app.TopAxes);
            cla(app.BottomAxes);
            nCh = app.Data.nChPerMol;
            colors = app.channelColors(app.Data.channelNames);
            hold(app.TopAxes, 'on');
            app.TopLines = gobjects(1, nCh);
            for k = 1:nCh
                % HitTest/PickableParts off so a click on a line passes
                % through to the axes' ButtonDownFcn (onAxesMouseDown)
                % instead of being swallowed by the line itself.
                app.TopLines(k) = plot(app.TopAxes, NaN, NaN, 'Color', colors(k, :), ...
                    'DisplayName', app.Data.channelNames{k}, 'HitTest', 'off', 'PickableParts', 'none');
            end
            hold(app.TopAxes, 'off');
            legend(app.TopAxes, app.TopLines, 'Location', 'northeast');

            hold(app.BottomAxes, 'on');
            app.BottomRefLine = plot(app.BottomAxes, NaN, NaN, 'b', 'HitTest', 'off', 'PickableParts', 'none');
            app.BottomStateLine = plot(app.BottomAxes, NaN, NaN, '--k', 'LineWidth', 1.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            hold(app.BottomAxes, 'off');
            linkaxes([app.TopAxes, app.BottomAxes], 'x');
        end

        function resetAxesForNewMolecule(app)
            app.disarmPendingAction();
            app.MolField.Value = app.Data.currentMol;
            app.drawMolecule();
            % Full reset (x and y, both axes) on every molecule change, so
            % a zoom used on one trace doesn't carry over to the next.
            app.resetZoom();
        end

        function drawMolecule(app)
            if isempty(app.Data)
                return;
            end
            c = app.Data.currentMol;
            t = app.Data.ttotal(:, 1);
            molCols = pipeline.getMolCols(c, app.Data.nChPerMol);

            for k = 1:app.Data.nChPerMol
                app.TopLines(k).XData = t;
                app.TopLines(k).YData = app.Data.ttotal(:, molCols(k));
            end

            activeCol = app.activeChannelCol();
            rawTrace = app.Data.ttotal(:, activeCol);
            stateTrace = app.Data.states(:, activeCol);

            app.BottomRefLine.XData = t;
            app.BottomRefLine.YData = rawTrace;

            maxRaw = max(rawTrace, [], 'omitnan');
            maxState = max(stateTrace, [], 'omitnan');
            if maxRaw > 0 && maxState > 0
                scale = 0.9 * maxRaw / maxState;
            else
                scale = 1;
            end
            app.BottomStateLine.XData = t;
            app.BottomStateLine.YData = stateTrace * scale;

            nBouts = pipeline.countBouts(stateTrace);
            app.TitleLabel.Text = sprintf('Molecule %d of %d -- %d assigned event(s) on "%s"', ...
                c, app.Data.nMol, nBouts, app.ChannelDropdown.Value);
            app.MolCountLabel.Text = sprintf('of %d', app.Data.nMol);
        end
    end

    %% ------------------------------------------------------------------
    %  Shared/status helpers
    %% ------------------------------------------------------------------
    methods (Access = private)
        function log(app, msg)
            existingLines = app.StatusArea.Value;
            if isequal(existingLines, {''})
                existingLines = {};
            end
            newLines = strsplit(msg, newline);
            app.StatusArea.Value = [existingLines(:); newLines(:)];
            scroll(app.StatusArea, 'bottom');
        end

        function enforceMinimumFigureSize(app)
            pos = app.UIFigure.Position;
            newW = max(pos(3), app.MinFigureWidth);
            newH = max(pos(4), app.MinFigureHeight);
            if newW ~= pos(3) || newH ~= pos(4)
                app.UIFigure.Position = [pos(1), pos(2), newW, newH];
            end
        end

        function buildUI(app)
            app.UIFigure = uifigure('Name', 'Assign States', 'Position', [80 80 1450 850]);
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.SizeChangedFcn = @(~, ~) app.enforceMinimumFigureSize();
            % WindowKeyPressFcn (not KeyPressFcn) -- fires for every key
            % press regardless of which component has focus, which matters
            % because clicking/dragging on the axes (see onAxesMouseDown)
            % can shift focus there.
            app.UIFigure.WindowKeyPressFcn = @(~, event) app.onKeyPress(event);

            app.MainGrid = uigridlayout(app.UIFigure, [1 2]);
            app.MainGrid.ColumnWidth = {240, '1x'};

            ctrlFontSize = 11;

            % --- Left panel: pipeline entry points, save, status, help ---
            leftPanel = uigridlayout(app.MainGrid, [5 1]);
            leftPanel.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
            leftPanel.RowSpacing = 6;
            leftPanel.Padding = [0 0 0 0];

            % 2-Color FRET: Analyze with vbFRET -> Merge vbFRET Summary -> Assign States
            twoColorPanel = uipanel(leftPanel, 'Title', '2-Color FRET');
            twoColorGrid = uigridlayout(twoColorPanel, [3 1]);
            twoColorGrid.RowHeight = {26, 26, 26};
            twoColorGrid.RowSpacing = 4;
            twoColorGrid.Padding = [4 4 4 4];

            uibutton(twoColorGrid, 'Text', 'Analyze with vbFRET', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onLaunchVbFret());

            mergeGrid = uigridlayout(twoColorGrid, [1 3]);
            mergeGrid.ColumnWidth = {'fit', 44, '1x'};
            mergeGrid.ColumnSpacing = 4;
            mergeGrid.Padding = [0 0 0 0];
            uilabel(mergeGrid, 'Text', 'Thr:', 'FontSize', ctrlFontSize);
            app.ThresholdField = uieditfield(mergeGrid, 'numeric', 'Value', 0.1, 'Limits', [0 1], ...
                'FontSize', ctrlFontSize);
            uibutton(mergeGrid, 'Text', 'Merge vbFRET Summary...', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onMergeVbFret());

            uibutton(twoColorGrid, 'Text', 'Assign States', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onAssignStates());

            % 3/4-Color FRET: straight to manual assignment, no vbFRET step
            multiColorPanel = uipanel(leftPanel, 'Title', '3/4-Color FRET');
            multiColorGrid = uigridlayout(multiColorPanel, [1 1]);
            multiColorGrid.RowHeight = {26};
            multiColorGrid.Padding = [4 4 4 4];
            uibutton(multiColorGrid, 'Text', 'Assign States', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onAssignStates());

            % Save: independent of which pipeline menu was used to get here
            savePanel = uipanel(leftPanel, 'Title', 'Save');
            saveGrid = uigridlayout(savePanel, [2 1]);
            saveGrid.RowHeight = {26, 26};
            saveGrid.RowSpacing = 4;
            saveGrid.Padding = [4 4 4 4];
            uibutton(saveGrid, 'Text', 'Save Progress...', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onSaveProgress());
            uibutton(saveGrid, 'Text', 'Save As _assigned_corrected.mat...', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onSaveAs());

            statusPanel = uipanel(leftPanel, 'Title', 'Status');
            statusGrid = uigridlayout(statusPanel, [1 1]);
            statusGrid.Padding = [4 4 4 4];
            app.StatusArea = uitextarea(statusGrid, 'Value', {''}, 'Editable', 'off', 'FontSize', 10);

            helpPanel = uipanel(leftPanel, 'Title', 'File / Keyboard');
            helpGrid = uigridlayout(helpPanel, [2 1]);
            helpGrid.RowHeight = {'fit', 'fit'};
            helpGrid.RowSpacing = 4;
            helpGrid.Padding = [4 4 4 4];
            app.FileLabel = uilabel(helpGrid, 'Text', 'No file loaded', 'FontAngle', 'italic', ...
                'FontSize', 10);
            uilabel(helpGrid, 'Text', sprintf([...
                '\x2192/n next    \x2190/p back\n' ...
                '; erase all    Enter+click erase event\n' ...
                'Shift+click(x2) region    t+click(x2) threshold\n' ...
                'u or / zoom reset    Esc cancel click\n' ...
                '1-9,0 active state']), ...
                'FontSize', 10, 'VerticalAlignment', 'top');

            % --- Right panel: review & correct -- plots dominate the space ---
            rightPanel = uigridlayout(app.MainGrid, [4 1]);
            rightPanel.RowHeight = {'fit', 'fit', 'fit', '1x'};
            rightPanel.RowSpacing = 4;
            rightPanel.Padding = [4 4 4 4];

            app.TitleLabel = uilabel(rightPanel, 'Text', 'No data loaded', ...
                'FontWeight', 'bold', 'FontSize', 13);

            ctrlGrid = uigridlayout(rightPanel, [1 9]);
            ctrlGrid.ColumnWidth = repmat({'fit'}, 1, 9);
            ctrlGrid.RowHeight = {24};
            ctrlGrid.ColumnSpacing = 6;
            ctrlGrid.Padding = [0 0 0 0];

            uilabel(ctrlGrid, 'Text', 'Molecule:', 'FontSize', ctrlFontSize);
            app.MolField = uieditfield(ctrlGrid, 'numeric', 'Value', 1, 'Limits', [1 Inf], ...
                'FontSize', ctrlFontSize, 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~, ~) app.onMolFieldChanged());
            app.MolCountLabel = uilabel(ctrlGrid, 'Text', 'of 0', 'FontSize', ctrlFontSize);

            uilabel(ctrlGrid, 'Text', 'Channel:', 'FontSize', ctrlFontSize);
            app.ChannelDropdown = uidropdown(ctrlGrid, 'Items', {'--'}, 'FontSize', ctrlFontSize, ...
                'ValueChangedFcn', @(~, ~) app.drawMolecule());

            uilabel(ctrlGrid, 'Text', '# States:', 'FontSize', ctrlFontSize);
            app.NumStatesField = uieditfield(ctrlGrid, 'numeric', 'Value', 2, 'Limits', [1 10], ...
                'FontSize', ctrlFontSize, 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~, ~) app.onNumStatesChanged());

            uilabel(ctrlGrid, 'Text', 'Active state:', 'FontSize', ctrlFontSize);
            app.ActiveStateDropdown = uidropdown(ctrlGrid, 'FontSize', ctrlFontSize, ...
                'Items', {'State 1 (OFF)', 'State 2 (ON)'}, 'Value', 'State 2 (ON)');

            btnGrid = uigridlayout(rightPanel, [1 8]);
            btnGrid.ColumnWidth = repmat({'fit'}, 1, 8);
            btnGrid.RowHeight = {26};
            btnGrid.ColumnSpacing = 6;
            btnGrid.Padding = [0 0 0 0];
            uibutton(btnGrid, 'Text', sprintf('Accept & Next (%s)', char(8594)), 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.acceptNext());
            uibutton(btnGrid, 'Text', sprintf('Back (%s)', char(8592)), 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.goBack());
            uibutton(btnGrid, 'Text', 'Erase All (;)', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.eraseCurrent());
            uibutton(btnGrid, 'Text', sprintf('Erase Event (%s)', char(8629)), 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.eraseEventAtClick());
            uibutton(btnGrid, 'Text', 'Region Assign (Shift)', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.regionAssign());
            uibutton(btnGrid, 'Text', 'Threshold Assign (t)', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.thresholdAssign());
            uibutton(btnGrid, 'Text', 'Reset Zoom (u//)', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.resetZoom());
            uibutton(btnGrid, 'Text', 'Export Trace...', 'FontSize', ctrlFontSize, ...
                'ButtonPushedFcn', @(~, ~) app.onExportTrace());

            plotGrid = uigridlayout(rightPanel, [2 1]);
            plotGrid.RowHeight = {'1x', '1x'};
            plotGrid.RowSpacing = 4;
            plotGrid.Padding = [0 0 0 0];
            app.TopAxes = uiaxes(plotGrid);
            title(app.TopAxes, 'Raw channel traces');
            ylabel(app.TopAxes, 'Intensity, A.U.');
            grid(app.TopAxes, 'on');
            app.TopAxes.ButtonDownFcn = @(src, event) app.onAxesMouseDown(src, event);

            app.BottomAxes = uiaxes(plotGrid);
            title(app.BottomAxes, 'Active channel + assigned states');
            xlabel(app.BottomAxes, 'Time, s');
            ylabel(app.BottomAxes, 'Intensity, A.U.');
            grid(app.BottomAxes, 'on');
            app.BottomAxes.ButtonDownFcn = @(src, event) app.onAxesMouseDown(src, event);
            % Box-zoom (click-drag a rectangle to zoom into it) is on by
            % default on both axes via onAxesMouseDown's hand-rolled drag
            % handling -- see its comment for why this doesn't use
            % zoom()/Interactions.
        end
    end
end
