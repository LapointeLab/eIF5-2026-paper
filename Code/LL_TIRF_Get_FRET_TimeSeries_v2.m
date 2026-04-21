%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Retrieve FRET efficiency time series for each event type

[r, c] = size(states);
nmol = (c - 1) / 3;
t = ttotal(:, 1);
max_frames = r;

% Initialize output matrices
fret_time_series_all = NaN(max_frames, 0);
fret_time_series_first = NaN(max_frames, 0);
fret_time_series_subsequent = NaN(max_frames, 0);

% Loop through each molecule
for n = 1:nmol
    vec = (states(:, n * 3 + 1))';

    % Skip this molecule if no binding events are recorded
    if max(vec) == 0
        continue;
    end

    first_event_found = false;
    p = 1;
    while p < r
        % Find the start of the next binding event
        start_index = find(vec == 1, 1, 'first');
        if isempty(start_index)
            break;
        end

        % Mark previous frames as processed
        vec(1:(start_index - 1)) = 2;

        % Find the end of the current binding event
        end_index = find(vec == 0, 1, 'first');
        if isempty(end_index)
            break;
        end

        % Extract FRET efficiency for this event
        event_fret_series = ttotal(start_index:end_index - 1, 3 * n + 1)';
        event_fret_series_padded = NaN(max_frames, 1);
        event_fret_series_padded(1:length(event_fret_series)) = event_fret_series;

        % Append to all-events matrix
        fret_time_series_all = [fret_time_series_all, event_fret_series_padded];

        % Append to first or subsequent event matrix
        if ~first_event_found
            fret_time_series_first = [fret_time_series_first, event_fret_series_padded];
            first_event_found = true;
        else
            fret_time_series_subsequent = [fret_time_series_subsequent, event_fret_series_padded];
        end

        % Mark frames of this event as processed and advance
        vec(1:end_index) = 2;
        p = end_index;
    end
end

% Clear temporary variables
clear red_transit_down red_transit_up N n0 num_events r t max_events ...
    event_std i lifetime max_frames c event_mean event_means n vec ...
    p start_index end_index event_fret_series event_fret_series_padded ...
    first_event_found;
