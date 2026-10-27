function fretStateLifetime(app)
%FRETSTATELIFETIME Lifetime of low/high FRET states during individual binding events.
%   Module function: takes the AnalysisPipelineApp instance. Built on the
%   shared pipeline.buildCDFModule scaffold (channel + type selector -> eCDF
%   + exponential fit), which also handles the plot, export, and fit UI.
%   Adapted from ExampleCode/LL_TIRF_FRET_StateLifetimeAnalyzer_v1.m.
%
%   Unlike the original script, which classified every frame of a
%   continuous per-spot trace using two threshold RANGES (low/high, with an
%   undefined gap between them), this module restricts the analysis to each
%   individual binding event's bound duration only (see
%   pipeline.extractEventSegments) and uses a single user-editable threshold:
%   a frame's FRET value is "low" at or below the threshold, "high" above
%   it. Within each event, contiguous runs of low/high FRET are timed —
%   exactly the original script's run-length logic (see
%   pipeline.runLengthDurations), generalized to work per-event instead of
%   per-continuous-trace.
%
%   Requires app.Data.result (see +pipeline/extractEvents.m) and the
%   Statistics and Machine Learning Toolbox (cdfcalc).

thresholdField = [];   % assigned by addThresholdControl; read by computeStateLifetimes

pipeline.buildCDFModule(app, 'FRET State Lifetime', ...
    {'Low FRET state', 'High FRET state'}, {'low', 'high'}, 'low', ...
    'State lifetime (s)', @computeStateLifetimes, @addThresholdControl, ...
    ['Low and High FRET state results share one log: each Save Fit adds a row ' ...
    '(see the EventFilter column), and Export CSV saves both together in one file.']);

    function addThresholdControl(ctrl, onDataChanged)
        uilabel(ctrl, 'Text', 'Threshold:');
        thresholdField = uieditfield(ctrl, 'numeric', 'Value', 0.65, 'Limits', [0 1], ...
            'ValueChangedFcn', @(~, ~) onDataChanged());
    end

    function [rawTimes, molIDs] = computeStateLifetimes(app, chName, typeValue)
        chIdx  = find(strcmp(app.Data.result.channelNames, chName), 1);
        evList = app.Data.result.events{chIdx};
        segments = pipeline.extractEventSegments(app, chName, evList);

        threshold   = thresholdField.Value;
        exposure    = app.Data.result.Exposure;
        targetState = 1;
        if strcmp(typeValue, 'high')
            targetState = 2;
        end

        rawTimes = [];
        molIDs   = [];
        for i = 1:numel(segments)
            seg = segments{i};
            seg = seg(~isnan(seg));
            if isempty(seg)
                continue;
            end

            state = ones(size(seg));      % 1 = low FRET (<= threshold)
            state(seg > threshold) = 2;   % 2 = high FRET (> threshold)

            durations = pipeline.runLengthDurations(state, targetState, exposure);
            rawTimes = [rawTimes, durations]; %#ok<AGROW>
            molIDs   = [molIDs, repmat(evList(i).mol, 1, numel(durations))]; %#ok<AGROW>
        end
    end
end
