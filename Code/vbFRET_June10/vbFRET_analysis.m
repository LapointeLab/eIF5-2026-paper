%% Analyze the data from a vbFRET output file
% Produces an output than can be used to fit a gaussian as well as a bar
% graph detailing the distribution FRET states

%Initialization
[datafile,datapath] = uigetfile( '*.mat', 'Choose a file');
load(datafile);

disp(' ')
framerate = input('What framerate was this captured at in ms -> ','s');
framerate = str2double(framerate);

FRET_frames = [];
states_num = [];
cy3_lifetimes = [];
cy5_lifetimes = [];
nmols = size(data,2);
time_coeff = framerate/1000;

threshold = 0.15

%loops over all molecules, extracts the non-zero FRET state values
for i=1:nmols
    current_states = path{1,i};
    current_states(current_states < threshold) = 0;
    current_states(current_states >= threshold) = 1;
    current_FRET = FRET{1,i} .* current_states;
    current_FRET(current_FRET == 0) = [];
    FRET_frames = [FRET_frames; current_FRET];
    state_means = vbFRETsummary{1,i}.mu;
    state_means(state_means < threshold) = [];
    curr_states_num = size(state_means,2);
    states_num = [states_num, curr_states_num];
    cy3_lifetime = size(current_states,1)*time_coeff;
    cy3_lifetimes = [cy3_lifetimes, cy3_lifetime];
    cy5_vals = path2D{1,i}(:,2) .* current_states;
    cy5_vals(cy5_vals == 0) = [];
    cy5_lifetime = size(cy5_vals,1)*time_coeff;
    cy5_lifetimes = [cy5_lifetimes, cy5_lifetime];
end

%creates vector of the number of states
max_states = max(states_num);
min_states = max(min(states_num),1);
num_states = min_states:1:max_states;
num_states_fp = min_states:1:max_states+1;

%computes the lifetime probabilities for both dyes
[P_lifetime_Cy5 X_lifetime_Cy5] = cdfcalc(cy5_lifetimes);
 P_lifetime_Cy5(1) = []; 
[P_lifetime_Cy3 X_lifetime_Cy3] = cdfcalc(cy3_lifetimes);
 P_lifetime_Cy3(1) = [];

X = linspace(-0.2,1.2, 51);
N = size(FRET_frames);
Y = histcounts(FRET_frames,X);
Y_norm = Y(1,:)/N(1,1);
X_bin = (X(1:50) + X(2:51) ) ./2;

y = histcounts(states_num, num_states_fp);
y_norm = y(1,:)/nmols;

figure()
bar(num_states, y_norm)
ylabel('Probability')
xlabel('Number of states')
