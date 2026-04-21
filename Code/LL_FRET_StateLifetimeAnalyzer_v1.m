% Define the matrix 'fret_time_series' where each column represents FRET efficiencies for a spot.
% Replace this with your actual data.
fret_time_series; % Example data with 100 frames and 10 spots

% Define state thresholds
low_fret_threshold = [0, 0.65];
high_fret_threshold = [0.66, 1.0];

% Define exposure time (in seconds)
exposure_time = 0.02; % 20 ms

% Initialize arrays to store all lifetimes
all_low_lifetimes = [];
all_high_lifetimes = [];

for spot = 1:size(fret_time_series, 2)
    % Extract the FRET data for the current spot
    spot_data = fret_time_series(:, spot);
    
    % Identify valid data (non-NaN values)
    valid_data = ~isnan(spot_data);
    spot_data = spot_data(valid_data);
    
    % Skip spots with no valid data
    if isempty(spot_data)
        continue;
    end
    
    % Classify states: 1 for low FRET, 2 for high FRET, 0 for undefined
    state = zeros(size(spot_data));
    state(spot_data >= low_fret_threshold(1) & spot_data <= low_fret_threshold(2)) = 1;
    state(spot_data >= high_fret_threshold(1) & spot_data <= high_fret_threshold(2)) = 2;
    
    % Skip if state is entirely undefined
    if all(state == 0)
        continue;
    end
    
    % Calculate lifetimes for low and high states
    low_durations = [];
    high_durations = [];
    
    current_duration = 1;
    current_state = state(1);
    for i = 2:length(state)
        if state(i) == current_state
            current_duration = current_duration + 1;
        else
            % Save the duration for the current state
            if current_state == 1
                low_durations = [low_durations; current_duration * exposure_time];
            elseif current_state == 2
                high_durations = [high_durations; current_duration * exposure_time];
            end
            % Reset for the new state
            current_duration = 1;
            current_state = state(i);
        end
    end
    % Save the final state's duration
    if current_state == 1
        low_durations = [low_durations; current_duration * exposure_time];
    elseif current_state == 2
        high_durations = [high_durations; current_duration * exposure_time];
    end
    
    % Append to the global arrays
    all_low_lifetimes = [all_low_lifetimes; low_durations];
    all_high_lifetimes = [all_high_lifetimes; high_durations];
end

% Ensure results are column vectors
all_low_lifetimes = reshape(all_low_lifetimes, [], 1);
all_high_lifetimes = reshape(all_high_lifetimes, [], 1);

[P_all_high_lifetimes, X_all_high_lifetimes] = cdfcalc(all_high_lifetimes); P_all_high_lifetimes(1) = [];
[P_all_low_lifetimes, X_all_low_lifetimes] = cdfcalc(all_low_lifetimes); P_all_low_lifetimes(1) = [];


% Display confirmation
disp('Lifetimes (in seconds) have been calculated and stored in variables: all_low_lifetimes and all_high_lifetimes.');

% Clear temporary variables
clear low_fret_threshold high_fret_threshold exposure_time;
clear spot spot_data valid_data state transitions;
clear low_durations high_durations current_duration current_state;
clear valid_state_indices;