% Parameters
max_frames = 11; % Maximum frames to plot for each event
line_alpha = 0.2; % Define transparency (0 = fully transparent, 1 = fully opaque)
line_thickness = 2; % Line thickness

% User-defined number of lines to plot
user_defined_lines = 200;

% User-defined FRET ranges for color-coding
orange_range = [0, 0.6];
blue_range = [0.61, 1.2];

% Dynamically determine the number of events in fret_time_series
total_events = size(fret_time_series, 2);

% Adjust the number of lines to plot if user-defined exceeds available events
lines_to_plot = min(user_defined_lines, total_events);

% Figure for the FRET series line plot
figure;
hold on;

% Loop through each event to plot
lines_plotted = 0;
for i = 1:total_events
    if lines_plotted >= lines_to_plot
        break; % Stop plotting when reaching user-defined number
    end

    event_data = fret_time_series(:, i); % FRET values for current event

    % Find indices of all valid (non-NaN) frames
    valid_indices = find(~isnan(event_data));

    % Plot only if there are at least 3 valid frames
    if numel(valid_indices) >= 6
        start_index = valid_indices(2); % Second valid frame
        end_index = valid_indices(end - 1); % Second-to-last valid frame

        % Ensure plotting does not exceed max_frames
        plot_end = min(start_index + max_frames - 2, end_index);

        % Determine color based on second valid frame FRET value
        second_frame_fret = event_data(valid_indices(2));
        if second_frame_fret >= orange_range(1) && second_frame_fret <= orange_range(2)
            line_color = [1, 0.5, 0, line_alpha]; % Light gray
        elseif second_frame_fret >= blue_range(1) && second_frame_fret <= blue_range(2)
            line_color = [0, 0, 0.5, line_alpha]; % Blue
        else
            continue; % Skip event outside specified ranges
        end

        % Plot the FRET series
        plot(start_index:plot_end, event_data(start_index:plot_end), 'Color', line_color, 'LineWidth', line_thickness);
        lines_plotted = lines_plotted + 1;
    end
end

% Customize plot
xlabel('Time (Frames)');
ylabel('FRET Efficiency');
title(['Time Evolution of FRET Efficiencies (Color-Coded by Second Frame FRET State)']);
xlim([2, max_frames]);
ylim([0, 1.2]);
hold off;