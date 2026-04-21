%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Exposure = input('Enter the Exposure Time in seconds (1/framerate) -> ');
high_FRET = input('Enter the lower bound of the high FRET state -> ');
low_FRET = input('Enter the upper bound of the low FRET state -> ');

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

% Initialize variables for storing data related to binding events
% n0: current frame index
n0 = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Retrieve FRET efficiencies for each event

% Initialize arrays to store FRET efficiencies and related statistics
lifetime = [];
intensities_blue = [];
mean_intensity = [];
intensities_mean_per_event = [];
intensities_STD_per_event = [];

lifetimes_all = [];
lifetimes_high_FRET = [];
lifetimes_low_FRET = [];

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
                lifetime = end_index - start_index;
                lifetime = lifetime * Exposure;
                lifetimes_all = [lifetimes_all; lifetime];
                intensities_blue = [intensities_blue ttotal(start_index:end_index - 1, 3 * n + 1)'];
                mean_intensity = mean(ttotal(start_index:end_index - 1, 3 * n + 1));
                intensities_mean_per_event = [intensities_mean_per_event; mean_intensity];
                intensities_STD_per_event = [intensities_STD_per_event; std(ttotal(start_index:end_index - 1, 3 * n + 1))];
                
                % Retrieve FRET efficiencies for events longer than Cutoff
                if mean_intensity > high_FRET
                    lifetimes_high_FRET = [lifetimes_high_FRET; lifetime];
                end
                
                if mean_intensity < low_FRET
                    lifetimes_low_FRET = [lifetimes_low_FRET; lifetime];
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

[P_lifetimes_all, X_lifetimes_all] = cdfcalc(lifetimes_all); P_lifetimes_all(1) = [];
[P_lifetimes_high_FRET, X_lifetimes_high_FRET] = cdfcalc(lifetimes_high_FRET); P_lifetimes_high_FRET(1) = [];
[P_lifetimes_low_FRET, X_lifetimes_low_FRET] = cdfcalc(lifetimes_low_FRET); P_lifetimes_low_FRET(1) = [];


clear c end_index start_index n n0 p r t vec mean_intensity lifetime

