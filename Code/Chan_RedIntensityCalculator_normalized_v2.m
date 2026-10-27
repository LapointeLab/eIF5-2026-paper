% ============================================================
% ANALYZE RED INTENSITY OF BINDING EVENTS
%
% Original intensity units are preserved.
%
% Conversion:
%   1 intensity AU = 0.25 e-
%
% Therefore:
%   Converted intensity = intensity AU * 0.25
%
% OUTPUTS:
% - Total number of binding events
% - Total number of valid binding events
% - Average red intensity per molecule
% - Average red intensity per binding event
% - Median red intensity
% - Median red intensity per binding event
% - Normalized histograms
% - CFTOOL X/Y variables
% - Excel export
%
% HISTOGRAMS:
% 1. Filtered frame intensity (A.U.)
% 2. Filtered frame intensity (photons/e-)
% 3. Average intensity per binding event (A.U.)
% 4. Average intensity per binding event (photons/e-)
% ============================================================


% ============================================================
% CLEAR PREVIOUS ANALYSIS VARIABLES
% ============================================================

clear avg_red_intensity
clear event_avg_red_intensity
clear filtered_red_pool
clear num_filtered_frames
clear num_binding_events

clear avg_red_intensity_photons
clear filtered_red_pool_photons
clear event_avg_red_intensity_photons

clear event_molecule_number
clear event_number


% ============================================================
% CONVERSION FACTOR
% ============================================================

intensity_to_photons = 0.25;


% ============================================================
% GET DATA DIMENSIONS
% ============================================================

[r, total_cols] = size(ttotal);

% Column 1 = time
% Every molecule has 3 columns

nmol = (total_cols - 1) / 3;


% ============================================================
% INITIALIZE VARIABLES
% ============================================================

% ------------------------------------------------------------
% ORIGINAL INTENSITY UNITS (A.U.)
% ------------------------------------------------------------

avg_red_intensity = nan(nmol, 1);

filtered_red_pool = cell(nmol, 1);

num_filtered_frames = zeros(nmol, 1);

num_binding_events = zeros(nmol, 1);


% ------------------------------------------------------------
% CONVERTED INTENSITY UNITS
% ------------------------------------------------------------

avg_red_intensity_photons = nan(nmol, 1);

filtered_red_pool_photons = cell(nmol, 1);


% ------------------------------------------------------------
% BINDING EVENT AVERAGES
% ------------------------------------------------------------

event_avg_red_intensity = [];

event_avg_red_intensity_photons = [];


% ------------------------------------------------------------
% EVENT METADATA
% ------------------------------------------------------------

event_molecule_number = [];

event_number = [];


% ============================================================
% LOOP THROUGH EACH MOLECULE
% ============================================================

for c = 1:nmol

    % --------------------------------------------------------
    % COLUMN STRUCTURE
    %
    % Column 1       = time
    % 3*c - 1        = green intensity
    % 3*c            = red intensity
    % 3*c + 1        = state/FRET
    % --------------------------------------------------------

    red_intensity = ttotal(:, 3*c);

    state = states(:, 3*c+1);


    % --------------------------------------------------------
    % CONVERT RED INTENSITY
    % --------------------------------------------------------

    red_intensity_photons = ...
        red_intensity * intensity_to_photons;


    % --------------------------------------------------------
    % FIND ALL BINDING FRAMES
    % --------------------------------------------------------

    on_frames = find(state == 1);


    % --------------------------------------------------------
    % SKIP MOLECULE IF NO BINDING EVENTS
    % --------------------------------------------------------

    if isempty(on_frames)

        fprintf('Molecule %d: 0 binding events\n', c);

        continue

    end


    % --------------------------------------------------------
    % IDENTIFY START AND END OF EACH BINDING EVENT
    % --------------------------------------------------------

    event_start = ...
        on_frames([true; diff(on_frames) > 1]);

    event_end = ...
        on_frames([diff(on_frames) > 1; true]);


    % --------------------------------------------------------
    % COUNT TOTAL BINDING EVENTS
    % --------------------------------------------------------

    num_binding_events(c) = ...
        length(event_start);


    fprintf('\nMolecule %d: %d binding events\n', ...
        c, num_binding_events(c));


    % --------------------------------------------------------
    % INITIALIZE FILTERED POOLS
    % --------------------------------------------------------

    filtered_pool = [];

    filtered_pool_photons = [];


    % ========================================================
    % LOOP THROUGH EACH BINDING EVENT
    % ========================================================

    for i = 1:length(event_start)

        start_frame = event_start(i);

        end_frame = event_end(i);


        % Event length

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
            % ORIGINAL RED INTENSITY
            % ------------------------------------------------

            event_red_intensity = ...
                red_intensity(trimmed_frames);


            % ------------------------------------------------
            % CONVERTED RED INTENSITY
            % ------------------------------------------------

            event_red_intensity_photons = ...
                red_intensity_photons(trimmed_frames);


            % ------------------------------------------------
            % EVENT AVERAGES
            % ------------------------------------------------

            event_average = ...
                mean(event_red_intensity);

            event_average_photons = ...
                mean(event_red_intensity_photons);


            % ------------------------------------------------
            % STORE EVENT AVERAGES
            % ------------------------------------------------

            event_avg_red_intensity = ...
                [event_avg_red_intensity; ...
                 event_average];


            event_avg_red_intensity_photons = ...
                [event_avg_red_intensity_photons; ...
                 event_average_photons];


            % ------------------------------------------------
            % STORE EVENT METADATA
            % ------------------------------------------------

            event_molecule_number = ...
                [event_molecule_number; c];

            event_number = ...
                [event_number; i];


            % ------------------------------------------------
            % ADD FRAMES TO FILTERED POOL
            % ------------------------------------------------

            filtered_pool = ...
                [filtered_pool; ...
                 event_red_intensity];


            filtered_pool_photons = ...
                [filtered_pool_photons; ...
                 event_red_intensity_photons];


            % ------------------------------------------------
            % DISPLAY EVENT RESULT
            % ------------------------------------------------

            fprintf(['  Event %d: %d frames -> ' ...
                     'Average red intensity = %.2f A.U. ' ...
                     '(%.2f photons/e-)\n'], ...
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

    filtered_red_pool{c} = ...
        filtered_pool;

    filtered_red_pool_photons{c} = ...
        filtered_pool_photons;


    num_filtered_frames(c) = ...
        length(filtered_pool);


    % --------------------------------------------------------
    % CALCULATE MOLECULE AVERAGES
    % --------------------------------------------------------

    if ~isempty(filtered_pool)

        avg_red_intensity(c) = ...
            mean(filtered_pool);

        avg_red_intensity_photons(c) = ...
            mean(filtered_pool_photons);


        fprintf(['Molecule %d final average red intensity = ' ...
                 '%.2f A.U. (%.2f photons/e-) ' ...
                 '(n = %d filtered frames)\n'], ...
                 c, ...
                 avg_red_intensity(c), ...
                 avg_red_intensity_photons(c), ...
                 num_filtered_frames(c));

    else

        fprintf(['Molecule %d: No valid frames after trimming\n'], ...
            c);

    end

end


% ============================================================
% TOTAL NUMBER OF BINDING EVENTS
% ============================================================

total_binding_events = ...
    sum(num_binding_events);


total_valid_binding_events = ...
    length(event_avg_red_intensity);


fprintf('\n================================================\n');

fprintf('TOTAL BINDING EVENTS: %d\n', ...
    total_binding_events);

fprintf('TOTAL VALID BINDING EVENTS AFTER TRIMMING: %d\n', ...
    total_valid_binding_events);

fprintf('================================================\n');


% ============================================================
% COMBINE ALL FILTERED FRAMES
% ============================================================

all_filtered_red_intensity = [];

all_filtered_red_intensity_photons = [];


for c = 1:nmol

    if ~isempty(filtered_red_pool{c})

        all_filtered_red_intensity = ...
            [all_filtered_red_intensity; ...
             filtered_red_pool{c}];


        all_filtered_red_intensity_photons = ...
            [all_filtered_red_intensity_photons; ...
             filtered_red_pool_photons{c}];

    end

end


% ============================================================
% OVERALL FRAME-WEIGHTED AVERAGE
% ============================================================

if ~isempty(all_filtered_red_intensity)

    overall_avg_red_intensity = ...
        mean(all_filtered_red_intensity);

    overall_avg_red_intensity_photons = ...
        mean(all_filtered_red_intensity_photons);

else

    overall_avg_red_intensity = NaN;

    overall_avg_red_intensity_photons = NaN;

end


% ============================================================
% OVERALL EVENT-WEIGHTED AVERAGE
%
% EACH BINDING EVENT CONTRIBUTES EQUALLY
% ============================================================

if ~isempty(event_avg_red_intensity)

    overall_avg_event_intensity = ...
        mean(event_avg_red_intensity);

    overall_avg_event_intensity_photons = ...
        mean(event_avg_red_intensity_photons);

else

    overall_avg_event_intensity = NaN;

    overall_avg_event_intensity_photons = NaN;

end


% ============================================================
% MEDIANS
% ============================================================

if ~isempty(all_filtered_red_intensity)

    median_red_intensity = ...
        median(all_filtered_red_intensity);

    median_red_intensity_photons = ...
        median(all_filtered_red_intensity_photons);

else

    median_red_intensity = NaN;

    median_red_intensity_photons = NaN;

end


if ~isempty(event_avg_red_intensity)

    median_event_red_intensity = ...
        median(event_avg_red_intensity);

    median_event_red_intensity_photons = ...
        median(event_avg_red_intensity_photons);

else

    median_event_red_intensity = NaN;

    median_event_red_intensity_photons = NaN;

end


% ============================================================
% DISPLAY SUMMARY
% ============================================================

fprintf('\n================================================\n');
fprintf('OVERALL RED INTENSITY RESULTS\n');
fprintf('================================================\n');

fprintf('Frame-weighted average:\n');
fprintf('  %.2f A.U.\n', ...
    overall_avg_red_intensity);

fprintf('  %.2f photons/e-\n', ...
    overall_avg_red_intensity_photons);


fprintf('\nEvent-weighted average:\n');
fprintf('  %.2f A.U.\n', ...
    overall_avg_event_intensity);

fprintf('  %.2f photons/e-\n', ...
    overall_avg_event_intensity_photons);


fprintf('\nMedian of filtered frames:\n');
fprintf('  %.2f A.U.\n', ...
    median_red_intensity);

fprintf('  %.2f photons/e-\n', ...
    median_red_intensity_photons);


fprintf('\nMedian of binding event averages:\n');
fprintf('  %.2f A.U.\n', ...
    median_event_red_intensity);

fprintf('  %.2f photons/e-\n', ...
    median_event_red_intensity_photons);

fprintf('================================================\n');


% ============================================================
% CREATE MOLECULE RESULTS TABLE
% ============================================================

results = table( ...
    (1:nmol)', ...
    avg_red_intensity, ...
    avg_red_intensity_photons, ...
    num_filtered_frames, ...
    num_binding_events, ...
    'VariableNames', ...
    {'Molecule', ...
     'Average_Red_Intensity_AU', ...
     'Average_Red_Intensity_Photons', ...
     'Number_of_Filtered_Frames', ...
     'Number_of_Binding_Events'} );


% ============================================================
% CREATE BINDING EVENT RESULTS TABLE
% ============================================================

event_results = table( ...
    event_molecule_number, ...
    event_number, ...
    event_avg_red_intensity, ...
    event_avg_red_intensity_photons, ...
    'VariableNames', ...
    {'Molecule', ...
     'Event_Number', ...
     'Average_Red_Intensity_AU', ...
     'Average_Red_Intensity_Photons'} );


% ============================================================
% CREATE SUMMARY TABLE
% ============================================================

summary_results = table( ...
    total_binding_events, ...
    total_valid_binding_events, ...
    intensity_to_photons, ...
    overall_avg_red_intensity, ...
    overall_avg_red_intensity_photons, ...
    overall_avg_event_intensity, ...
    overall_avg_event_intensity_photons, ...
    median_red_intensity, ...
    median_red_intensity_photons, ...
    median_event_red_intensity, ...
    median_event_red_intensity_photons, ...
    length(all_filtered_red_intensity), ...
    'VariableNames', ...
    {'Total_Binding_Events', ...
     'Valid_Binding_Events', ...
     'Conversion_Factor_e_per_AU', ...
     'Overall_Frame_Weighted_Average_AU', ...
     'Overall_Frame_Weighted_Average_Photons', ...
     'Overall_Event_Average_AU', ...
     'Overall_Event_Average_Photons', ...
     'Median_Frame_Intensity_AU', ...
     'Median_Frame_Intensity_Photons', ...
     'Median_Event_Intensity_AU', ...
     'Median_Event_Intensity_Photons', ...
     'Total_Filtered_Frames'} );


% ============================================================
% DISPLAY RESULTS
% ============================================================

disp(' ');
disp('================================================');
disp('MOLECULE RESULTS');
disp('================================================');

disp(results);


disp(' ');
disp('================================================');
disp('BINDING EVENT RESULTS');
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
% FILTERED FRAME INTENSITY
% ORIGINAL A.U.
%
% X = RED INTENSITY
% Y = NORMALIZED DENSITY
% ============================================================

bin_size_frame_AU = 30;

histogram_data_frame_AU = ...
    all_filtered_red_intensity( ...
    ~isnan(all_filtered_red_intensity));


if ~isempty(histogram_data_frame_AU)

    min_bin = ...
        floor(min(histogram_data_frame_AU) / ...
        bin_size_frame_AU) * bin_size_frame_AU;

    max_bin = ...
        ceil(max(histogram_data_frame_AU) / ...
        bin_size_frame_AU) * bin_size_frame_AU;


    bin_edges_frame_AU = ...
        min_bin:bin_size_frame_AU: ...
        max_bin + bin_size_frame_AU;


    [counts_frame_AU, edges_frame_AU] = ...
        histcounts(histogram_data_frame_AU, ...
        bin_edges_frame_AU);


    bin_centers_frame_AU = ...
        edges_frame_AU(1:end-1) + ...
        diff(edges_frame_AU)/2;


    % Normalized density

    normalized_density_frame_AU = ...
        counts_frame_AU / sum(counts_frame_AU);


    % Smooth normalized density

    smooth_density_frame_AU = ...
        smoothdata(normalized_density_frame_AU, ...
        'gaussian', 5);


    % --------------------------------------------------------
    % CFTOOL VARIABLES
    %
    % X = RED INTENSITY
    % Y = NORMALIZED DENSITY
    % --------------------------------------------------------

    X_frame_AU = ...
        bin_centers_frame_AU(:);

    Y_frame_normalized_density_AU = ...
        normalized_density_frame_AU(:);


    figure;

    histogram(histogram_data_frame_AU, ...
        bin_edges_frame_AU, ...
        'Normalization', 'probability');

    hold on;


    plot(bin_centers_frame_AU, ...
        smooth_density_frame_AU, ...
        '-', ...
        'LineWidth', 2);


    xline(median_red_intensity, ...
        '--', ...
        sprintf('Median = %.2f A.U.', ...
        median_red_intensity), ...
        'LineWidth', 2, ...
        'LabelVerticalAlignment', 'bottom');


    xlabel('Red Intensity (A.U.)', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    ylabel('Normalized Density', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    title(['Normalized Distribution of Filtered Red Intensity ' ...
        '(Bin = ' num2str(bin_size_frame_AU) ' A.U.)'], ...
        'FontSize', 14, ...
        'FontWeight', 'bold');

    set(gca, ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    grid on;

    hold off;

end


% ============================================================
% HISTOGRAM 2
%
% FILTERED FRAME INTENSITY
% PHOTONS/E-
% ============================================================

bin_size_frame_photons = ...
    bin_size_frame_AU * intensity_to_photons;


histogram_data_frame_photons = ...
    all_filtered_red_intensity_photons( ...
    ~isnan(all_filtered_red_intensity_photons));


if ~isempty(histogram_data_frame_photons)

    min_bin_photons = ...
        floor(min(histogram_data_frame_photons) / ...
        bin_size_frame_photons) * ...
        bin_size_frame_photons;

    max_bin_photons = ...
        ceil(max(histogram_data_frame_photons) / ...
        bin_size_frame_photons) * ...
        bin_size_frame_photons;


    bin_edges_frame_photons = ...
        min_bin_photons: ...
        bin_size_frame_photons: ...
        max_bin_photons + ...
        bin_size_frame_photons;


    [counts_frame_photons, edges_frame_photons] = ...
        histcounts(histogram_data_frame_photons, ...
        bin_edges_frame_photons);


    bin_centers_frame_photons = ...
        edges_frame_photons(1:end-1) + ...
        diff(edges_frame_photons)/2;


    normalized_density_frame_photons = ...
        counts_frame_photons / ...
        sum(counts_frame_photons);


    smooth_density_frame_photons = ...
        smoothdata(normalized_density_frame_photons, ...
        'gaussian', 5);


    % CFTOOL variables

    X_frame_photons = ...
        bin_centers_frame_photons(:);

    Y_frame_normalized_density_photons = ...
        normalized_density_frame_photons(:);


    figure;

    histogram(histogram_data_frame_photons, ...
        bin_edges_frame_photons, ...
        'Normalization', 'probability');

    hold on;


    plot(bin_centers_frame_photons, ...
        smooth_density_frame_photons, ...
        '-', ...
        'LineWidth', 2);


    xline(median_red_intensity_photons, ...
        '--', ...
        sprintf('Median = %.2f photons/e-', ...
        median_red_intensity_photons), ...
        'LineWidth', 2, ...
        'LabelVerticalAlignment', 'bottom');


    xlabel('Red Intensity (Photons/e-)', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    ylabel('Normalized Density', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    title(['Normalized Distribution of Filtered Red Intensity ' ...
        '(Bin = ' ...
        num2str(bin_size_frame_photons) ...
        ' photons/e-)'], ...
        'FontSize', 14, ...
        'FontWeight', 'bold');

    set(gca, ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    grid on;

    hold off;

end


% ============================================================
% HISTOGRAM 3
%
% AVERAGE RED INTENSITY PER BINDING EVENT
% ORIGINAL A.U.
%
% X = RED INTENSITY
% Y = NORMALIZED DENSITY
% ============================================================

bin_size_event_AU = 30;

histogram_data_event_AU = ...
    event_avg_red_intensity( ...
    ~isnan(event_avg_red_intensity));


if ~isempty(histogram_data_event_AU)

    min_bin_event = ...
        floor(min(histogram_data_event_AU) / ...
        bin_size_event_AU) * ...
        bin_size_event_AU;

    max_bin_event = ...
        ceil(max(histogram_data_event_AU) / ...
        bin_size_event_AU) * ...
        bin_size_event_AU;


    bin_edges_event_AU = ...
        min_bin_event: ...
        bin_size_event_AU: ...
        max_bin_event + ...
        bin_size_event_AU;


    [counts_event_AU, edges_event_AU] = ...
        histcounts(histogram_data_event_AU, ...
        bin_edges_event_AU);


    bin_centers_event_AU = ...
        edges_event_AU(1:end-1) + ...
        diff(edges_event_AU)/2;


    % --------------------------------------------------------
    % NORMALIZED DENSITY
    % --------------------------------------------------------

    normalized_density_event_AU = ...
        counts_event_AU / sum(counts_event_AU);


    smooth_density_event_AU = ...
        smoothdata(normalized_density_event_AU, ...
        'gaussian', 5);


    % --------------------------------------------------------
    % CFTOOL VARIABLES
    %
    % THESE ARE THE MAIN VARIABLES FOR FITTING
    % --------------------------------------------------------

    X_event_AU = ...
        bin_centers_event_AU(:);

    Y_event_normalized_density_AU = ...
        normalized_density_event_AU(:);


    figure;

    histogram(histogram_data_event_AU, ...
        bin_edges_event_AU, ...
        'Normalization', 'probability');

    hold on;


    plot(bin_centers_event_AU, ...
        smooth_density_event_AU, ...
        '-', ...
        'LineWidth', 2);


    xline(median_event_red_intensity, ...
        '--', ...
        sprintf('Median = %.2f A.U.', ...
        median_event_red_intensity), ...
        'LineWidth', 2, ...
        'LabelVerticalAlignment', 'bottom');


    xlabel('Average Red Intensity per Binding Event (A.U.)', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    ylabel('Normalized Density', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    title(['Normalized Distribution of Average Red Intensity ' ...
        'per Binding Event ' ...
        '(Bin = ' num2str(bin_size_event_AU) ' A.U.)'], ...
        'FontSize', 14, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    set(gca, ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    grid on;

    hold off;

else

    warning('No valid binding events available.');

end


% ============================================================
% HISTOGRAM 4
%
% AVERAGE RED INTENSITY PER BINDING EVENT
% PHOTONS/E-
% ============================================================

bin_size_event_photons = ...
    bin_size_event_AU * intensity_to_photons;


histogram_data_event_photons = ...
    event_avg_red_intensity_photons( ...
    ~isnan(event_avg_red_intensity_photons));


if ~isempty(histogram_data_event_photons)

    min_bin_event_photons = ...
        floor(min(histogram_data_event_photons) / ...
        bin_size_event_photons) * ...
        bin_size_event_photons;

    max_bin_event_photons = ...
        ceil(max(histogram_data_event_photons) / ...
        bin_size_event_photons) * ...
        bin_size_event_photons;


    bin_edges_event_photons = ...
        min_bin_event_photons: ...
        bin_size_event_photons: ...
        max_bin_event_photons + ...
        bin_size_event_photons;


    [counts_event_photons, edges_event_photons] = ...
        histcounts(histogram_data_event_photons, ...
        bin_edges_event_photons);


    bin_centers_event_photons = ...
        edges_event_photons(1:end-1) + ...
        diff(edges_event_photons)/2;


    normalized_density_event_photons = ...
        counts_event_photons / ...
        sum(counts_event_photons);


    smooth_density_event_photons = ...
        smoothdata(normalized_density_event_photons, ...
        'gaussian', 5);


    % --------------------------------------------------------
    % CFTOOL VARIABLES
    % --------------------------------------------------------

    X_event_photons = ...
        bin_centers_event_photons(:);

    Y_event_normalized_density_photons = ...
        normalized_density_event_photons(:);


    figure;

    histogram(histogram_data_event_photons, ...
        bin_edges_event_photons, ...
        'Normalization', 'probability');

    hold on;


    plot(bin_centers_event_photons, ...
        smooth_density_event_photons, ...
        '-', ...
        'LineWidth', 2);


    xline(median_event_red_intensity_photons, ...
        '--', ...
        sprintf('Median = %.2f photons/e-', ...
        median_event_red_intensity_photons), ...
        'LineWidth', 2, ...
        'LabelVerticalAlignment', 'bottom');


    xlabel('Average Red Intensity per Binding Event (Photons/e-)', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    ylabel('Normalized Density', ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    title(['Normalized Distribution of Average Red Intensity ' ...
        'per Binding Event ' ...
        '(Bin = ' ...
        num2str(bin_size_event_photons) ...
        ' photons/e-)'], ...
        'FontSize', 14, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    set(gca, ...
        'FontSize', 12, ...
        'FontName', 'Arial', ...
        'FontWeight', 'bold');

    grid on;

    hold off;

else

    warning('No valid binding events available.');

end


% ============================================================
% EXPORT FRAME-LEVEL RESULTS
% ============================================================

frame_molecule_number = [];

frame_red_intensity = [];

frame_red_intensity_photons = [];


for c = 1:nmol

    if ~isempty(filtered_red_pool{c})

        nframes = ...
            length(filtered_red_pool{c});


        frame_molecule_number = ...
            [frame_molecule_number; ...
             repmat(c, nframes, 1)];


        frame_red_intensity = ...
            [frame_red_intensity; ...
             filtered_red_pool{c}];


        frame_red_intensity_photons = ...
            [frame_red_intensity_photons; ...
             filtered_red_pool_photons{c}];

    end

end


frame_results = table( ...
    frame_molecule_number, ...
    frame_red_intensity, ...
    frame_red_intensity_photons, ...
    'VariableNames', ...
    {'Molecule', ...
     'Red_Intensity_AU', ...
     'Red_Intensity_Photons'} );


% ============================================================
% CREATE HISTOGRAM / CFTOOL RESULTS TABLES
% ============================================================

frame_histogram_AU_results = table( ...
    X_frame_AU, ...
    Y_frame_normalized_density_AU, ...
    'VariableNames', ...
    {'Red_Intensity_Bin_Center_AU', ...
     'Normalized_Density'} );


frame_histogram_photons_results = table( ...
    X_frame_photons, ...
    Y_frame_normalized_density_photons, ...
    'VariableNames', ...
    {'Red_Intensity_Bin_Center_Photons', ...
     'Normalized_Density'} );


event_histogram_AU_results = table( ...
    X_event_AU, ...
    Y_event_normalized_density_AU, ...
    'VariableNames', ...
    {'Average_Red_Intensity_Bin_Center_AU', ...
     'Normalized_Density'} );


event_histogram_photons_results = table( ...
    X_event_photons, ...
    Y_event_normalized_density_photons, ...
    'VariableNames', ...
    {'Average_Red_Intensity_Bin_Center_Photons', ...
     'Normalized_Density'} );


% ============================================================
% EXPORT RESULTS TO EXCEL
% ============================================================

excel_filename = ...
    'Red_Intensity_Binding_Event_Normalized_Results.xlsx';


% Sheet 1

writetable(results, ...
    excel_filename, ...
    'Sheet', 'Molecule Results');


% Sheet 2

writetable(event_results, ...
    excel_filename, ...
    'Sheet', 'Binding Event Results');


% Sheet 3

writetable(summary_results, ...
    excel_filename, ...
    'Sheet', 'Summary');


% Sheet 4

writetable(frame_results, ...
    excel_filename, ...
    'Sheet', 'Filtered Frame Data');


% Sheet 5

writetable(frame_histogram_AU_results, ...
    excel_filename, ...
    'Sheet', 'Frame Histogram AU');


% Sheet 6

writetable(frame_histogram_photons_results, ...
    excel_filename, ...
    'Sheet', 'Frame Histogram Photons');


% Sheet 7

writetable(event_histogram_AU_results, ...
    excel_filename, ...
    'Sheet', 'Event Histogram AU');


% Sheet 8

writetable(event_histogram_photons_results, ...
    excel_filename, ...
    'Sheet', 'Event Histogram Photons');


% ============================================================
% FINAL EXPORT INFORMATION
% ============================================================

fprintf('\n================================================\n');
fprintf('EXCEL EXPORT COMPLETE\n');
fprintf('File: %s\n', excel_filename);

fprintf('\nConversion:\n');
fprintf('1 intensity A.U. = %.2f e-\n', ...
    intensity_to_photons);

fprintf('\nHistogram bin sizes:\n');
fprintf('Frame histogram: %d A.U. = %.2f photons/e-\n', ...
    bin_size_frame_AU, ...
    bin_size_frame_photons);

fprintf('Event histogram: %d A.U. = %.2f photons/e-\n', ...
    bin_size_event_AU, ...
    bin_size_event_photons);

fprintf('\nCFTOOL variables available:\n');

fprintf('X_frame_AU\n');
fprintf('Y_frame_normalized_density_AU\n');

fprintf('X_frame_photons\n');
fprintf('Y_frame_normalized_density_photons\n');

fprintf('X_event_AU\n');
fprintf('Y_event_normalized_density_AU\n');

fprintf('X_event_photons\n');
fprintf('Y_event_normalized_density_photons\n');

fprintf('================================================\n');