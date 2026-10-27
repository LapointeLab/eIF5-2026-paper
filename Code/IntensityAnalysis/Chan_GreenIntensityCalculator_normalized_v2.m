% ============================================================
% ANALYZE GREEN INTENSITY OF NON-BINDING EVENTS
%
% For each molecule:
% 1. Trim leading/trailing zero-padding based on the FRET column
% 2. Find continuous states == 0 non-binding events
% 3. Count non-binding events
% 4. Remove first and last frame of each event
% 5. Calculate average green intensity for each non-binding event
% 6. Convert intensity from A.U. to photon-equivalent units
% 7. Calculate average green intensity per molecule
%
% FINAL OUTPUTS:
% - Original intensity data in A.U.
% - Converted intensity data
% - Total number of non-binding events
% - Total number of valid non-binding events
% - Average green intensity per molecule
% - Average green intensity per non-binding event
% - Median green intensity per non-binding event
% - Histogram 1: normalized density, A.U.
% - Histogram 2: normalized density, photon-equivalent units
% - CFTOOL variables
% - Excel export
%
% HISTOGRAM NORMALIZATION:
%
% Probability:
%     count / total number of events
%
% Normalized density:
%     count / (total number of events * bin width)
%
% Therefore:
%
%     sum(density * bin width) = 1
%
% CFTOOL VARIABLES:
%
%     X = GREEN INTENSITY
%     Y = NORMALIZED DENSITY
%
% ============================================================


% ============================================================
% CLEAR PREVIOUS ANALYSIS VARIABLES
% ============================================================

clear avg_green_intensity
clear avg_green_photons
clear event_avg_green_intensity
clear event_avg_green_photons
clear filtered_green_pool
clear filtered_green_photon_pool
clear num_filtered_frames
clear num_nonbinding_events

clear normalized_density_AU
clear normalized_density_photons

clear X_green_intensity_AU
clear Y_normalized_density_AU

clear X_green_intensity_photons
clear Y_normalized_density_photons

clear median_event_green_intensity
clear median_event_green_photons


% ============================================================
% CONVERSION FACTOR
%
% 1 A.U. = 0.25 photon-equivalent units
% ============================================================

conversion_factor = 0.25;


% ============================================================
% HISTOGRAM BIN SIZE
% ============================================================

% Original bin size
bin_size_AU = 30;

% Equivalent photon bin size
bin_size_photons = ...
    bin_size_AU * conversion_factor;


% ============================================================
% GET DATA DIMENSIONS
% ============================================================

[r, total_cols] = size(ttotal);

% Column 1 = time
% Every molecule has 3 columns
nmol = (total_cols - 1) / 3;

fprintf('%d molecules x %d frames\n', nmol, r);


% ============================================================
% INITIALIZE VARIABLES
% ============================================================

% ------------------------------------------------------------
% MOLECULE-LEVEL RESULTS
% ------------------------------------------------------------

avg_green_intensity = nan(nmol, 1);

avg_green_photons = nan(nmol, 1);

filtered_green_pool = cell(nmol, 1);

filtered_green_photon_pool = cell(nmol, 1);

num_filtered_frames = zeros(nmol, 1);

num_nonbinding_events = zeros(nmol, 1);


% ------------------------------------------------------------
% EVENT-LEVEL RESULTS
% ------------------------------------------------------------

event_avg_green_intensity = [];

event_avg_green_photons = [];

event_molecule_number = [];

event_number = [];


% ============================================================
% LOOP THROUGH EACH MOLECULE
% ============================================================

for c = 1:nmol

    % --------------------------------------------------------
    % GET GREEN INTENSITY, FRET, AND STATE
    %
    % Column 1       = time
    % 3*c - 1        = green intensity
    % 3*c            = red intensity
    % 3*c + 1        = FRET / state
    % --------------------------------------------------------

    green_intensity = ttotal(:, 3*c - 1);

    % FRET column used to trim zero padding
    fret = ttotal(:, 3*c + 1);

    % State column used to identify non-binding events
    state = states(:, 3*c + 1);


    % --------------------------------------------------------
    % TRIM LEADING AND TRAILING ZERO PADDING
    % BASED ON FRET COLUMN
    % --------------------------------------------------------

    valid_frames = find(fret ~= 0);

    if isempty(valid_frames)

        fprintf('Molecule %d: No valid FRET frames\n', c);

        continue

    end


    trim_start = min(valid_frames);
    trim_end   = max(valid_frames);

    trimmed_indices = trim_start:trim_end;


    % --------------------------------------------------------
    % GET STATES WITHIN TRIMMED REGION
    % --------------------------------------------------------

    trimmed_state = state(trimmed_indices);


    % --------------------------------------------------------
    % FIND ALL FRAMES WHERE STATE = 0
    % --------------------------------------------------------

    off_frames_local = find(trimmed_state == 0);


    if isempty(off_frames_local)

        fprintf('Molecule %d: 0 non-binding events\n', c);

        continue

    end


    % --------------------------------------------------------
    % IDENTIFY START AND END OF EACH CONTINUOUS
    % NON-BINDING EVENT
    % --------------------------------------------------------

    event_start_local = ...
        off_frames_local([true; diff(off_frames_local) > 1]);

    event_end_local = ...
        off_frames_local([diff(off_frames_local) > 1; true]);


    % Convert back to original frame numbers
    event_start = trimmed_indices(event_start_local);
    event_end   = trimmed_indices(event_end_local);


    % --------------------------------------------------------
    % COUNT NON-BINDING EVENTS
    % --------------------------------------------------------

    num_nonbinding_events(c) = length(event_start);

    fprintf('\nMolecule %d: %d non-binding events\n', ...
        c, num_nonbinding_events(c));


    % --------------------------------------------------------
    % INITIALIZE FILTERED POOLS
    % --------------------------------------------------------

    filtered_pool = [];

    filtered_photon_pool = [];


    % ========================================================
    % LOOP THROUGH EACH NON-BINDING EVENT
    % ========================================================

    for i = 1:length(event_start)

        start_frame = event_start(i);

        end_frame = event_end(i);

        event_length = ...
            end_frame - start_frame + 1;


        % ----------------------------------------------------
        % ONLY PROCESS EVENTS WITH AT LEAST 3 FRAMES
        %
        % Remove first and last frame
        % ----------------------------------------------------

        if event_length >= 3

            trimmed_frames = ...
                start_frame + 1 : end_frame - 1;


            % ------------------------------------------------
            % GREEN INTENSITY
            % ------------------------------------------------

            event_green_intensity = ...
                green_intensity(trimmed_frames);


            % ------------------------------------------------
            % CONVERT TO PHOTON-EQUIVALENT UNITS
            % ------------------------------------------------

            event_green_photons = ...
                event_green_intensity * conversion_factor;


            % ------------------------------------------------
            % EVENT AVERAGES
            % ------------------------------------------------

            event_average = ...
                mean(event_green_intensity);

            event_average_photons = ...
                mean(event_green_photons);


            % ------------------------------------------------
            % STORE EVENT RESULTS
            % ------------------------------------------------

            event_avg_green_intensity = ...
                [event_avg_green_intensity; ...
                 event_average];


            event_avg_green_photons = ...
                [event_avg_green_photons; ...
                 event_average_photons];


            event_molecule_number = ...
                [event_molecule_number; c];


            event_number = ...
                [event_number; i];


            % ------------------------------------------------
            % ADD TO MOLECULE POOLS
            % ------------------------------------------------

            filtered_pool = ...
                [filtered_pool; ...
                 event_green_intensity];


            filtered_photon_pool = ...
                [filtered_photon_pool; ...
                 event_green_photons];


            % ------------------------------------------------
            % DISPLAY EVENT RESULT
            % ------------------------------------------------

            fprintf(['  Event %d: %d frames -> ' ...
                     'Average = %.2f A.U. = %.2f photons\n'], ...
                     i, ...
                     length(trimmed_frames), ...
                     event_average, ...
                     event_average_photons);

        else

            fprintf(['  Event %d: %d frames -> ' ...
                     'Excluded (too short after trimming)\n'], ...
                     i, ...
                     event_length);

        end

    end


    % ========================================================
    % SAVE RESULTS FOR CURRENT MOLECULE
    % ========================================================

    filtered_green_pool{c} = filtered_pool;

    filtered_green_photon_pool{c} = ...
        filtered_photon_pool;

    num_filtered_frames(c) = ...
        length(filtered_pool);


    % --------------------------------------------------------
    % CALCULATE AVERAGE INTENSITY PER MOLECULE
    % --------------------------------------------------------

    if ~isempty(filtered_pool)

        avg_green_intensity(c) = ...
            mean(filtered_pool);

        avg_green_photons(c) = ...
            mean(filtered_photon_pool);


        fprintf(['Molecule %d final average = %.2f A.U. = ' ...
                 '%.2f photons (n = %d filtered frames)\n'], ...
                 c, ...
                 avg_green_intensity(c), ...
                 avg_green_photons(c), ...
                 num_filtered_frames(c));

    else

        fprintf('Molecule %d: No valid frames after trimming\n', c);

    end

end


% ============================================================
% TOTAL NUMBER OF NON-BINDING EVENTS
% ============================================================

total_nonbinding_events = ...
    sum(num_nonbinding_events);

total_valid_nonbinding_events = ...
    length(event_avg_green_intensity);


fprintf('\n================================================\n');

fprintf('TOTAL NON-BINDING EVENTS: %d\n', ...
    total_nonbinding_events);

fprintf('TOTAL VALID NON-BINDING EVENTS AFTER TRIMMING: %d\n', ...
    total_valid_nonbinding_events);

fprintf('================================================\n');


% ============================================================
% COMBINE ALL FILTERED DATA
% ============================================================

all_filtered_green_intensity = [];

all_filtered_green_photons = [];


for c = 1:nmol

    if ~isempty(filtered_green_pool{c})

        all_filtered_green_intensity = ...
            [all_filtered_green_intensity; ...
             filtered_green_pool{c}];

        all_filtered_green_photons = ...
            [all_filtered_green_photons; ...
             filtered_green_photon_pool{c}];

    end

end


% ============================================================
% OVERALL FRAME-WEIGHTED AVERAGE
% ============================================================

if ~isempty(all_filtered_green_intensity)

    overall_avg_green_intensity = ...
        mean(all_filtered_green_intensity);

    overall_avg_green_photons = ...
        mean(all_filtered_green_photons);

else

    overall_avg_green_intensity = NaN;

    overall_avg_green_photons = NaN;

end


fprintf('\n================================================\n');
fprintf('OVERALL AVERAGE GREEN INTENSITY\n');

fprintf('A.U.: %.2f\n', ...
    overall_avg_green_intensity);

fprintf('Photon-equivalent units: %.2f\n', ...
    overall_avg_green_photons);

fprintf('Total filtered frames: %d\n', ...
    length(all_filtered_green_intensity));

fprintf('================================================\n');


% ============================================================
% AVERAGE OF NON-BINDING EVENT AVERAGES
%
% Each event contributes equally
% ============================================================

if ~isempty(event_avg_green_intensity)

    overall_avg_event_intensity = ...
        mean(event_avg_green_intensity);

    overall_avg_event_photons = ...
        mean(event_avg_green_photons);

else

    overall_avg_event_intensity = NaN;

    overall_avg_event_photons = NaN;

end


fprintf('\n================================================\n');
fprintf('AVERAGE GREEN INTENSITY PER NON-BINDING EVENT\n');

fprintf('A.U.: %.2f\n', ...
    overall_avg_event_intensity);

fprintf('Photon-equivalent units: %.2f\n', ...
    overall_avg_event_photons);

fprintf('================================================\n');


% ============================================================
% MEDIAN OF NON-BINDING EVENT AVERAGES
% ============================================================

if ~isempty(event_avg_green_intensity)

    median_event_green_intensity = ...
        median(event_avg_green_intensity);

    median_event_green_photons = ...
        median(event_avg_green_photons);

else

    median_event_green_intensity = NaN;

    median_event_green_photons = NaN;

end


% ============================================================
% MEDIAN OF ALL FILTERED FRAMES
% ============================================================

if ~isempty(all_filtered_green_intensity)

    median_filtered_green_intensity = ...
        median(all_filtered_green_intensity);

    median_filtered_green_photons = ...
        median(all_filtered_green_photons);

else

    median_filtered_green_intensity = NaN;

    median_filtered_green_photons = NaN;

end


% ============================================================
% DISPLAY MEDIANS
% ============================================================

fprintf('\n================================================\n');
fprintf('MEDIAN GREEN INTENSITY RESULTS\n');
fprintf('================================================\n');

fprintf('Median of non-binding event averages:\n');

fprintf('  %.2f A.U.\n', ...
    median_event_green_intensity);

fprintf('  %.2f photon-equivalent units\n', ...
    median_event_green_photons);

fprintf('\nMedian of filtered frames:\n');

fprintf('  %.2f A.U.\n', ...
    median_filtered_green_intensity);

fprintf('  %.2f photon-equivalent units\n', ...
    median_filtered_green_photons);

fprintf('================================================\n');


% ============================================================
% CREATE MOLECULE RESULTS TABLE
% ============================================================

results = table( ...
    (1:nmol)', ...
    avg_green_intensity, ...
    avg_green_photons, ...
    num_filtered_frames, ...
    num_nonbinding_events, ...
    'VariableNames', ...
    {'Molecule', ...
     'Average_Green_Intensity_AU', ...
     'Average_Green_Intensity_Photons', ...
     'Number_of_Filtered_Frames', ...
     'Number_of_NonBinding_Events'} );


% ============================================================
% CREATE NON-BINDING EVENT RESULTS TABLE
% ============================================================

event_results = table( ...
    event_molecule_number, ...
    event_number, ...
    event_avg_green_intensity, ...
    event_avg_green_photons, ...
    'VariableNames', ...
    {'Molecule', ...
     'Event_Number', ...
     'Average_Green_Intensity_AU', ...
     'Average_Green_Intensity_Photons'} );


% ============================================================
% CREATE SUMMARY TABLE
% ============================================================

summary_results = table( ...
    total_nonbinding_events, ...
    total_valid_nonbinding_events, ...
    overall_avg_green_intensity, ...
    overall_avg_green_photons, ...
    overall_avg_event_intensity, ...
    overall_avg_event_photons, ...
    median_event_green_intensity, ...
    median_event_green_photons, ...
    median_filtered_green_intensity, ...
    median_filtered_green_photons, ...
    length(all_filtered_green_intensity), ...
    conversion_factor, ...
    'VariableNames', ...
    {'Total_NonBinding_Events', ...
     'Valid_NonBinding_Events', ...
     'Overall_Frame_Weighted_Average_AU', ...
     'Overall_Frame_Weighted_Average_Photons', ...
     'Overall_Event_Average_AU', ...
     'Overall_Event_Average_Photons', ...
     'Median_Event_Intensity_AU', ...
     'Median_Event_Intensity_Photons', ...
     'Median_Filtered_Frame_Intensity_AU', ...
     'Median_Filtered_Frame_Intensity_Photons', ...
     'Total_Filtered_Frames', ...
     'Conversion_Factor'} );


% ============================================================
% DISPLAY FINAL RESULTS
% ============================================================

disp(' ');
disp('================================================');
disp('MOLECULE RESULTS');
disp('================================================');

disp(results);


disp(' ');
disp('================================================');
disp('NON-BINDING EVENT RESULTS');
disp('================================================');

disp(event_results);


disp(' ');
disp('================================================');
disp('SUMMARY RESULTS');
disp('================================================');

disp(summary_results);


% ============================================================
% HISTOGRAM 1
%
% AVERAGE GREEN INTENSITY PER NON-BINDING EVENT
% ORIGINAL A.U.
%
% X-axis = GREEN INTENSITY
% Y-axis = NORMALIZED DENSITY
%
% Density:
%
%     count / (N * bin_width)
%
% Therefore:
%
%     sum(density * bin_width) = 1
% ============================================================

histogram_data_AU = ...
    event_avg_green_intensity( ...
    ~isnan(event_avg_green_intensity));


if ~isempty(histogram_data_AU)

    % --------------------------------------------------------
    % DEFINE BIN EDGES
    % --------------------------------------------------------

    min_bin_AU = ...
        floor(min(histogram_data_AU) / ...
        bin_size_AU) * bin_size_AU;

    max_bin_AU = ...
        ceil(max(histogram_data_AU) / ...
        bin_size_AU) * bin_size_AU;

    bin_edges_AU = ...
        min_bin_AU : ...
        bin_size_AU : ...
        max_bin_AU + bin_size_AU;


    % --------------------------------------------------------
    % HISTOGRAM COUNTS
    % --------------------------------------------------------

    [counts_AU, edges_AU] = ...
        histcounts(histogram_data_AU, ...
        bin_edges_AU);


    % --------------------------------------------------------
    % BIN CENTERS
    % --------------------------------------------------------

    bin_centers_AU = ...
        edges_AU(1:end-1) + ...
        diff(edges_AU)/2;


    % --------------------------------------------------------
    % NORMALIZED DENSITY
    %
    % count / (N * bin width)
    % --------------------------------------------------------

    N_AU = numel(histogram_data_AU);

    normalized_density_AU = ...
        counts_AU ./ ...
        (N_AU * bin_size_AU);


    % --------------------------------------------------------
    % CHECK AREA
    % --------------------------------------------------------

    histogram_area_AU = ...
        sum(normalized_density_AU * bin_size_AU);


    % --------------------------------------------------------
    % SMOOTH DENSITY
    % --------------------------------------------------------

    smooth_density_AU = ...
        smoothdata(normalized_density_AU, ...
        'gaussian', 5);


    % ========================================================
    % CFTOOL VARIABLES
    %
    % X = GREEN INTENSITY
    % Y = NORMALIZED DENSITY
    % ========================================================

    X_green_intensity_AU = ...
        bin_centers_AU(:);

    Y_normalized_density_AU = ...
        normalized_density_AU(:);


    % --------------------------------------------------------
    % PLOT
    % --------------------------------------------------------

    figure;

    histogram(histogram_data_AU, ...
        bin_edges_AU, ...
        'Normalization', 'pdf');

    hold on;

    plot(bin_centers_AU, ...
        smooth_density_AU, ...
        '-', ...
        'LineWidth', 2);


    % --------------------------------------------------------
    % MEDIAN LINE
    % --------------------------------------------------------

    xline(median_event_green_intensity, ...
        '--', ...
        sprintf('Median = %.2f A.U.', ...
        median_event_green_intensity), ...
        'LineWidth', 2, ...
        'LabelVerticalAlignment', 'bottom');


    % --------------------------------------------------------
    % LABELS
    % --------------------------------------------------------

    xlabel('Average Green Intensity per Non-Binding Event (A.U.)', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    ylabel('Normalized Density', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    title(['Normalized Density of Average Green Intensity ' ...
           'per Non-Binding Event ' ...
           '(Bin = ' num2str(bin_size_AU) ' A.U.)'], ...
        'FontSize', 14, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    set(gca, ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    grid on;

    hold off;


    % --------------------------------------------------------
    % DISPLAY RESULTS
    % --------------------------------------------------------

    fprintf('\n================================================\n');
    fprintf('A.U. HISTOGRAM\n');
    fprintf('================================================\n');

    fprintf('Total valid non-binding events: %d\n', N_AU);

    fprintf('Bin size: %.2f A.U.\n', ...
        bin_size_AU);

    fprintf('Median event intensity: %.2f A.U.\n', ...
        median_event_green_intensity);

    fprintf('Area under normalized density: %.4f\n', ...
        histogram_area_AU);

    fprintf('================================================\n');

else

    warning('No valid non-binding events available for A.U. histogram.');

    X_green_intensity_AU = [];
    Y_normalized_density_AU = [];

end


% ============================================================
% HISTOGRAM 2
%
% AVERAGE GREEN INTENSITY PER NON-BINDING EVENT
% PHOTON-EQUIVALENT UNITS
%
% X-axis = GREEN INTENSITY
% Y-axis = NORMALIZED DENSITY
% ============================================================

histogram_data_photons = ...
    event_avg_green_photons( ...
    ~isnan(event_avg_green_photons));


if ~isempty(histogram_data_photons)

    % --------------------------------------------------------
    % DEFINE BIN EDGES
    % --------------------------------------------------------

    min_bin_photons = ...
        floor(min(histogram_data_photons) / ...
        bin_size_photons) * bin_size_photons;

    max_bin_photons = ...
        ceil(max(histogram_data_photons) / ...
        bin_size_photons) * bin_size_photons;

    bin_edges_photons = ...
        min_bin_photons : ...
        bin_size_photons : ...
        max_bin_photons + bin_size_photons;


    % --------------------------------------------------------
    % HISTOGRAM COUNTS
    % --------------------------------------------------------

    [counts_photons, edges_photons] = ...
        histcounts(histogram_data_photons, ...
        bin_edges_photons);


    % --------------------------------------------------------
    % BIN CENTERS
    % --------------------------------------------------------

    bin_centers_photons = ...
        edges_photons(1:end-1) + ...
        diff(edges_photons)/2;


    % --------------------------------------------------------
    % NORMALIZED DENSITY
    %
    % count / (N * bin width)
    % --------------------------------------------------------

    N_photons = ...
        numel(histogram_data_photons);

    normalized_density_photons = ...
        counts_photons ./ ...
        (N_photons * bin_size_photons);


    % --------------------------------------------------------
    % CHECK AREA
    % --------------------------------------------------------

    histogram_area_photons = ...
        sum(normalized_density_photons * ...
        bin_size_photons);


    % --------------------------------------------------------
    % SMOOTH DENSITY
    % --------------------------------------------------------

    smooth_density_photons = ...
        smoothdata(normalized_density_photons, ...
        'gaussian', 5);


    % ========================================================
    % CFTOOL VARIABLES
    %
    % X = GREEN INTENSITY
    % Y = NORMALIZED DENSITY
    % ========================================================

    X_green_intensity_photons = ...
        bin_centers_photons(:);

    Y_normalized_density_photons = ...
        normalized_density_photons(:);


    % --------------------------------------------------------
    % PLOT
    % --------------------------------------------------------

    figure;

    histogram(histogram_data_photons, ...
        bin_edges_photons, ...
        'Normalization', 'pdf');

    hold on;

    plot(bin_centers_photons, ...
        smooth_density_photons, ...
        '-', ...
        'LineWidth', 2);


    % --------------------------------------------------------
    % MEDIAN LINE
    % --------------------------------------------------------

    xline(median_event_green_photons, ...
        '--', ...
        sprintf('Median = %.2f', ...
        median_event_green_photons), ...
        'LineWidth', 2, ...
        'LabelVerticalAlignment', 'bottom');


    % --------------------------------------------------------
    % LABELS
    % --------------------------------------------------------

    xlabel(['Average Green Intensity per Non-Binding Event ' ...
            '(Photon-Equivalent Units)'], ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    ylabel('Normalized Density', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    title(['Normalized Density of Average Green Intensity ' ...
           'per Non-Binding Event ' ...
           '(Bin = ' num2str(bin_size_photons) ...
           ' Photon-Equivalent Units)'], ...
        'FontSize', 14, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    set(gca, ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    grid on;

    hold off;


    % --------------------------------------------------------
    % DISPLAY RESULTS
    % --------------------------------------------------------

    fprintf('\n================================================\n');
    fprintf('PHOTON HISTOGRAM\n');
    fprintf('================================================\n');

    fprintf('Total valid non-binding events: %d\n', ...
        N_photons);

    fprintf('Bin size: %.2f photon-equivalent units\n', ...
        bin_size_photons);

    fprintf('Median event intensity: %.2f photon-equivalent units\n', ...
        median_event_green_photons);

    fprintf('Area under normalized density: %.4f\n', ...
        histogram_area_photons);

    fprintf('================================================\n');

else

    warning('No valid non-binding events available for photon histogram.');

    X_green_intensity_photons = [];
    Y_normalized_density_photons = [];

end


% ============================================================
% CREATE HISTOGRAM RESULTS TABLE
%
% X = GREEN INTENSITY
% Y = NORMALIZED DENSITY
%
% These tables are directly usable for CFTOOL.
% ============================================================

if ~isempty(X_green_intensity_AU)

    histogram_AU_results = table( ...
        X_green_intensity_AU, ...
        Y_normalized_density_AU, ...
        counts_AU(:), ...
        repmat(bin_size_AU, ...
        length(counts_AU), 1), ...
        'VariableNames', ...
        {'Green_Intensity_AU', ...
         'Normalized_Density', ...
         'Number_of_Events', ...
         'Bin_Width_AU'} );

else

    histogram_AU_results = table();

end


if ~isempty(X_green_intensity_photons)

    histogram_photons_results = table( ...
        X_green_intensity_photons, ...
        Y_normalized_density_photons, ...
        counts_photons(:), ...
        repmat(bin_size_photons, ...
        length(counts_photons), 1), ...
        'VariableNames', ...
        {'Green_Intensity_Photons', ...
         'Normalized_Density', ...
         'Number_of_Events', ...
         'Bin_Width_Photons'} );

else

    histogram_photons_results = table();

end


% ============================================================
% CREATE MEDIAN TABLE
% ============================================================

median_results = table( ...
    median_event_green_intensity, ...
    median_event_green_photons, ...
    median_filtered_green_intensity, ...
    median_filtered_green_photons, ...
    'VariableNames', ...
    {'Median_Event_Green_Intensity_AU', ...
     'Median_Event_Green_Intensity_Photons', ...
     'Median_Filtered_Frame_Green_Intensity_AU', ...
     'Median_Filtered_Frame_Green_Intensity_Photons'} );


% ============================================================
% EXPORT RESULTS TO EXCEL
% ============================================================

filename = ...
    'green_intensity_nonbinding_event_analysis.xlsx';


% ------------------------------------------------------------
% Sheet 1: Molecule results
% ------------------------------------------------------------

writetable(results, ...
    filename, ...
    'Sheet', 'Molecule Results');


% ------------------------------------------------------------
% Sheet 2: Individual non-binding events
% ------------------------------------------------------------

writetable(event_results, ...
    filename, ...
    'Sheet', 'Non-Binding Events');


% ------------------------------------------------------------
% Sheet 3: Overall summary
% ------------------------------------------------------------

writetable(summary_results, ...
    filename, ...
    'Sheet', 'Overall Summary');


% ------------------------------------------------------------
% Sheet 4: A.U. histogram
% ------------------------------------------------------------

writetable(histogram_AU_results, ...
    filename, ...
    'Sheet', 'Histogram AU');


% ------------------------------------------------------------
% Sheet 5: Photon histogram
% ------------------------------------------------------------

writetable(histogram_photons_results, ...
    filename, ...
    'Sheet', 'Histogram Photons');


% ------------------------------------------------------------
% Sheet 6: Medians
% ------------------------------------------------------------

writetable(median_results, ...
    filename, ...
    'Sheet', 'Medians');


% ============================================================
% FINAL OUTPUT INFORMATION
% ============================================================

fprintf('\n================================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('================================================\n');

fprintf('\nTotal non-binding events: %d\n', ...
    total_nonbinding_events);

fprintf('Total valid non-binding events: %d\n', ...
    total_valid_nonbinding_events);


fprintf('\nMEDIANS\n');

fprintf('Median event green intensity:\n');

fprintf('  %.2f A.U.\n', ...
    median_event_green_intensity);

fprintf('  %.2f photon-equivalent units\n', ...
    median_event_green_photons);


fprintf('\nMedian filtered-frame green intensity:\n');

fprintf('  %.2f A.U.\n', ...
    median_filtered_green_intensity);

fprintf('  %.2f photon-equivalent units\n', ...
    median_filtered_green_photons);


fprintf('\nHISTOGRAM NORMALIZATION\n');

fprintf('A.U. bin size: %.2f A.U.\n', ...
    bin_size_AU);

fprintf('Photon bin size: %.2f photon-equivalent units\n', ...
    bin_size_photons);


if ~isempty(X_green_intensity_AU)

    fprintf('A.U. density area: %.4f\n', ...
        histogram_area_AU);

end


if ~isempty(X_green_intensity_photons)

    fprintf('Photon density area: %.4f\n', ...
        histogram_area_photons);

end


% ============================================================
% CFTOOL VARIABLES
% ============================================================

fprintf('\nCFTOOL VARIABLES\n');

fprintf('\nA.U. histogram:\n');
fprintf('X = X_green_intensity_AU\n');
fprintf('Y = Y_normalized_density_AU\n');

fprintf('\nPhoton histogram:\n');
fprintf('X = X_green_intensity_photons\n');
fprintf('Y = Y_normalized_density_photons\n');


fprintf('\nExcel file:\n');
fprintf('%s\n', filename);

fprintf('================================================\n');
