%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Analyze the kinetics of multiple binding events on the same complex

% Ask the user to enter the exposure time (in seconds)
%%% Exposure is the time duration for each frame, calculated as the inverse of framerate
Exposure = input('Enter the Exposure Time in seconds (1/framerate) -> ');

% Ask the user to enter a frame count cutoff to define "long" events
%%%% We want to examine longer events to ensure that we get the same
%%%% distribution as for all events
Cutoff = input('Enter the number of frames you want to set as the cutoff for a multiple frame event -> ');

%ttotal contains the fluorescent intensity and calculated FRET efficiency data from SPARTAN and vbFRET
%%%Column 1 contains the frame number, which we later on convert to actual times
%%%Column 2 contains the fluorescent intensity of each frame of the DONOR dye of molecule 1
%%%Column 3 contains the fluorescent intensity of each frame of the ACCEPTOR dye of molecule 1
%%%Column 4 contains the calculated FRET EFFICIENCY of each frame (i.e. row) of molecule 1
%%%Columns 2-4 repeat for every molecule in the data set

%states contains the FRET ON and OFF states as determined by vbFRET and you during the manual correction process
%Data are organized as in ttotal;
%Column n+3 contains the FRET states, where 0 = OFF and 1 = ON
%%%%%So column 4 contains the determined states for molecule 1, column  for molecule 2, and so on

% Get the dimensions of the 'ttotal' data matrix
% r: number of rows (frames), c: number of columns (molecules)
[r, c] = size(ttotal);

% Initialize arrays to store binding arrival and departure times for each molecule
%we'll use these to determine kinetics later
Cy5_uncorrected_arrivaltimes = zeros(1, c);
Cy5_uncorrected_departuretimes = zeros(1, c);

% Extract state data for each molecule, ignoring the first column, which is just the frame number
% 'red_HMM' now represents the state of each molecule in each frame
red_HMM = states(:, 2:end);

% Add an initial row of zeros to handle cases where events start at the first frame
% Also add a row of zeros at the end to maintain matrix dimensions
red_HMM(1, :) = zeros(1, size(red_HMM, 2));
red_HMM(end, :) = zeros(1, size(red_HMM, 2));

% Calculate the difference between each frame to detect state changes
% Positive values indicate binding, negative values indicate dissociation
red_diff = diff(red_HMM);

% Initialize variables for storing data related to binding events
% n0: current frame index
n0 = 1;

% Arrays to store all binding events and their durations
red_association = [];
red_lifetime = [];
events = [];

% Arrays to store the first binding event specifically
red_firstassociation = [];
red_firstlifetime = [];

% Arrays for subsequent binding events on each molecule
red_reassociation = [];
red_subsequent_lifetimes = [];

% Loop through each molecule to detect binding events
for i = 1:c-1
    % Identify the frames where each molecule binds and unbinds
    red_transit_up = find(red_diff(:, i) > 0); % Start of binding
    red_transit_down = find(red_diff(:, i) < 0); % End of binding
    events = [events; numel(red_transit_up)]; % Record number of events per molecule
    
    % Check if there are any binding events on this molecule
    if ~isempty(red_transit_up)
        % Calculate durations of each binding event and time between events
        red_lifetime = [red_lifetime; red_transit_down - red_transit_up];
        red_association = [red_association; red_transit_up - [0; red_transit_down(1:end-1)]];
      
        % Record the time and duration of the first binding event
        red_firstassociation = [red_firstassociation; red_transit_up(1)];
        red_firstlifetime = [red_firstlifetime; red_transit_down(1) - red_transit_up(1)];
        
        % Record the times and durations of subsequent binding events
        red_reassociation = [red_reassociation; red_transit_up(2:end) - red_transit_down(1:end-1)];
        red_subsequent_lifetimes = [red_subsequent_lifetimes; red_transit_down(2:end) - red_transit_up(2:end)];
    end
end

% Convert frame counts to time by multiplying by the Exposure time
red_association = red_association * Exposure;
red_lifetime = red_lifetime * Exposure;

% Convert times for first and subsequent events
red_firstassociation = red_firstassociation * Exposure;
red_firstlifetime = red_firstlifetime * Exposure;
red_reassociation = red_reassociation * Exposure;
red_subsequent_lifetimes = red_subsequent_lifetimes * Exposure;

% Calculate cumulative distribution functions (CDFs) for each type of event data
[P_red_association, X_red_association] = cdfcalc(red_association); P_red_association(1) = [];
[P_red_lifetime, X_red_lifetime] = cdfcalc(red_lifetime); P_red_lifetime(1) = [];
[P_red_firstassociation, X_red_firstassociation] = cdfcalc(red_firstassociation); P_red_firstassociation(1) = [];
[P_red_firstlifetime, X_red_firstlifetime] = cdfcalc(red_firstlifetime); P_red_firstlifetime(1) = [];
[P_red_reassociation, X_red_reassociation] = cdfcalc(red_reassociation); P_red_reassociation(1) = [];
[P_red_subsequent_lifetimes, X_red_subsequent_lifetime] = cdfcalc(red_subsequent_lifetimes); P_red_subsequent_lifetimes(1) = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Retrieve FRET efficiencies for each event

% Initialize arrays to store FRET efficiencies and related statistics
intensities_blue = [];
intensities_mean_per_event = [];
intensities_STD_per_event = [];
intensities_blue_multiframes = [];
intensities_blue_mean_per_event_multiframes = [];
intensities_blue_trimmed = [];
intensities_blue_multiframes_trimmed = [];

% Determine the number of molecules and frame times
[r, c] = size(states);
nmol = (c - 1) / 3;
t = ttotal(:, 1);

% Loop through each molecule to calculate FRET efficiencies for each event
for n = 1:nmol
    vec = (states(:, n * 3 + 1))'; % Extract the state data for each molecule
    if max(vec) == 0
        % Skip molecule if no binding events are detected
    else
        p = 1;
        while p < r
            % Find the start of an event where the molecule binds
            start_index = find(vec == 1, 1, 'first');
            if isempty(start_index) == 0
                % Mark frames before the event start as processed
                vec(1:(start_index - 1)) = 2;
                % Find the end of the event (unbinding)
                end_index = find(vec == 0, 1, 'first');
                
                % Calculate duration of the event and FRET efficiency
                lifetime = t(end_index - 1) - t(start_index);
                intensities_blue = [intensities_blue ttotal(start_index:end_index - 1, 3 * n + 1)'];
                intensities_mean_per_event = [intensities_mean_per_event mean(ttotal(start_index:end_index - 1, 3 * n + 1))];
                intensities_STD_per_event = [intensities_STD_per_event std(ttotal(start_index:end_index - 1, 3 * n + 1))];
                
                % Retrieve FRET efficiencies for events longer than Cutoff
                if start_index < end_index - Cutoff
                    intensities_blue_multiframes = [intensities_blue_multiframes ttotal(start_index:end_index - 1, 3 * n + 1)'];
                    intensities_blue_mean_per_event_multiframes = [intensities_blue_mean_per_event_multiframes mean(ttotal(start_index:end_index - 1, 3 * n + 1))];
                end
                % Mark frames in this event as processed and move to next unprocessed frame
                vec(1:end_index) = 2;
                p = end_index;
            else
                p = r; % Exit loop if no more events found
            end
        end
    end
end

% Remove outliers from intensity data
intensities_blue_trimmed = intensities_blue;
intensities_blue_trimmed(intensities_blue_trimmed > 1.2) = [];
intensities_blue_trimmed(intensities_blue_trimmed < 0.00) = [];

% Set up histogram bins and calculate normalized frequency distribution for intensities
X = linspace(0, 1.2, 51);
N = size(intensities_blue_trimmed);
Y_all = histcounts(intensities_blue_trimmed, X);
Y_all_norm = Y_all(1, :) / N(1, 2);
X_bin = (X(1:50) + X(2:51)) / 2;

% Repeat for longer events
intensities_blue_multiframes_trimmed = intensities_blue_multiframes;
intensities_blue_multiframes_trimmed(intensities_blue_multiframes_trimmed > 1.2) = [];
intensities_blue_multiframes_trimmed(intensities_blue_multiframes_trimmed < 0.05) = [];

X = linspace(0, 1.2, 51);
N = size(intensities_blue_multiframes_trimmed);
Y_multi = histcounts(intensities_blue_multiframes_trimmed, X);
Y_multi_norm = Y_multi(1, :) / N(1, 2);
X_bin = (X(1:50) + X(2:51)) / 2;
