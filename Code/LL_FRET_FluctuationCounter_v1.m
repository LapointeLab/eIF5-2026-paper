% Define the matrix 'data' where each column represents FRET efficiencies for a spot.
% Replace this with your actual data.
data = fret_time_series; % Example data with 100 frames and 10 spots

% Define user-defined thresholds
user_value1 = 0.65; % Lower threshold
user_value2 = 0.66; % Upper threshold

% Calculate the number of frames with valid data (non-NaN values) for each spot
num_valid_frames = sum(~isnan(data), 1);

% Find spots with data in at least 5 frames
min_frames = 16;
max_frames = 50;
%spots_with_min_frames = num_valid_frames >= 5;
%spots_with_min_frames = num_valid_frames >= 4 & num_valid_frames <= 5;
%spots_with_min_frames = num_valid_frames >= 10 & num_valid_frames <= 50;
spots_with_min_frames = num_valid_frames >= min_frames & num_valid_frames <= max_frames;

% Count the number of spots with at least 5 frames of data
num_spots_min_frames = sum(spots_with_min_frames);

% Filter the data to only include spots with at least 5 frames of data
filtered_data = data(:, spots_with_min_frames);

% Check for at least two consecutive frames below user_value1 and above user_value2
below_threshold_consecutive = any(conv2(filtered_data < user_value1, [1; 1], 'same') == 2, 1);
above_threshold_consecutive = any(conv2(filtered_data > user_value2, [1; 1], 'same') == 2, 1);
both_thresholds_consecutive = below_threshold_consecutive & above_threshold_consecutive;

% Count the number of spots meeting the consecutive thresholds
num_below_threshold_consecutive = sum(below_threshold_consecutive);
num_above_threshold_consecutive = sum(above_threshold_consecutive);
num_both_thresholds_consecutive = sum(both_thresholds_consecutive);

% Calculate the average number of frames 
avg_frames = mean(num_valid_frames);

% Display the results
disp(['Number of binding events analyzed: ', num2str(num_spots_min_frames)]);
disp(['Average number of frames per spot: ', num2str(avg_frames)]);
disp(['Binding events with number of frames between ', num2str(min_frames),' and ', num2str(max_frames)]);
disp(['Number of binding events with at least two consecutive frames with FRET values < ', num2str(user_value1), ': ', num2str(num_below_threshold_consecutive)]);
disp(['Number of binding events with at least two consecutive frames with FRET values > ', num2str(user_value2), ': ', num2str(num_above_threshold_consecutive)]);
disp(['Number of binding events with at least two consecutive frames both < ', num2str(user_value1), ' and > ', num2str(user_value2), ': ', num2str(num_both_thresholds_consecutive)]);
