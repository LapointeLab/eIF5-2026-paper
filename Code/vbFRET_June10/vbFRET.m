function varargout = vbFRET(varargin)
% Main file for vbFRET gui
% last edited fall 2009 by Jonathan E Bronson (jeb2126@columbia.edu) for 
% http://vbfret.sourceforge.net
% VBFRET M-file for vbFRET.fig
%      VBFRET, by itself, creates a new VBFRET or raises the existing
%      singleton*.
%
%      H = VBFRET returns the handle to a new VBFRET or the handle to
%      the existing singleton*.
%
%      VBFRET('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in VBFRET.M with the given input arguments.
%
%      VBFRET('Property','Value',...) creates a new VBFRET or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before vbFRET_OpeningFunction gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to vbFRET_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help vbFRET

% Last Modified by GUIDE v2.5 10-Jul-2009 13:02:56

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @vbFRET_OpeningFcn, ...
                   'gui_OutputFcn',  @vbFRET_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT
%%

% --- Executes just before vbFRET is made visible.
function vbFRET_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to vbFRET (see VARARGIN)

% Choose default command line output for vbFRET
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% use try/catch to make sure these variables are only initialized once
try
    foo =  handles.dat;
catch
    % add vbFRET src folder to path
    mpath = fileparts(mfilename('fullpath'));
    if isunix
        addpath(['/' mpath]);
        addpath(['/' mpath '/src']);
        addpath(['/' mpath '/ext_src']);
    else
        addpath(mpath);
        addpath([mpath '\src']);
        addpath([mpath '\ext_src']);
    end
    
    %%% initialize data structures
    handles.dat = init_dat();               % holds data
    handles.fit_par = [];                   % will hold best fit parameters
    handles.plot = init_plot();             % plot options
    handles.debleach = debleach_defaults(); % options for photobleach removal
    handles.analysis = analysis_defaults(); % get default settings for data analysis
    set(handles.analyzeData_pushbutton,'UserData', 0) % flag denoting when analysis is running

    % make the plot type and plot dimension button groups
    set(handles.plotType_buttongroup,'SelectionChangeFcn',@plotType_buttongroup_SelectionChangeFcn);
    set(handles.plotDimension_buttongroup,'SelectionChangeFcn',@plotDimension_buttongroup_SelectionChangeFcn);
    
    % initialize main gui display
    handles = init_main_gui_disp(handles);

    % init plot background
    plotFRET(handles.axes1, handles.dat, handles.plot, get(handles.plot1_slider,'Value'));
    
%     % this command asks the user to confirm closing of GUI
%     %%% set(handles.figure1,'CloseRequestFcn','closeGUI');
%     set(handles.figure1,'CloseRequestFcn',@closeGUI);

    % Update handles structure
    guidata(hObject, handles);
end

% UIWAIT makes vbFRET wait for user response (see UIRESUME)
% uiwait(handles.figure1);

%%
% --- Outputs from this function are returned to the command line.
function varargout = vbFRET_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

%%
% show fit points checkbox
function showFitPoints_checkbox_Callback(hObject, eventdata, handles)
%if checked
if get(hObject,'Value')
    handles.plot.fit_pts= 1;
else
    handles.plot.fit_pts = 0;
end

%update plot
plotFRET(handles.axes1, handles.dat, handles.plot, get(handles.plot1_slider,'Value'));

% Update handles structure
guidata(hObject, handles);


%%
% show data points checkbox 
function showDataPoints_checkbox_Callback(hObject, eventdata, handles)
%if checked
if get(hObject,'Value')
    handles.plot.data_pts = 1;
else
    handles.plot.data_pts = 0;
end
%update plot
plotFRET(handles.axes1, handles.dat, handles.plot, get(handles.plot1_slider,'Value'));

% Update handles structure
guidata(hObject, handles);

%%
% editText holding Kmin
function minK_editText_Callback(hObject, eventdata, handles)
% make sure input is an allowed value
input = round(str2num(get(hObject,'String')));

if (isempty(input))
     set(hObject,'String','1');
else
     % value must be >= 1
     set(hObject,'String',num2str(max(1,input(1))));
end

%update handles
handles.analysis.minK = str2num(get(hObject,'String'));
guidata(hObject, handles);

%%
% createfunction for editText holding Kmin
function minK_editText_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%
% editText holding Kmax
function maxK_editText_Callback(hObject, eventdata, handles)
% make sure input is an allowed value
input = round(str2num(get(hObject,'String')));

if (isempty(input))
     set(hObject,'String','1');
else
     % value must be >= 1
     set(hObject,'String',num2str(max(1,input(1))));
end

%update handles
handles.analysis.maxK = str2num(get(hObject,'String'));
guidata(hObject, handles);

%%
% createfunction for editText holding Kmax
function maxK_editText_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%
% editText for number of restarts
function numrestarts_editText_Callback(hObject, eventdata, handles)
% make sure input is an allowed value
input = round(str2num(get(hObject,'String')));

if (isempty(input))
     set(hObject,'String','1');
else
     % value must be >= 1
     set(hObject,'String',num2str(max(1,input(1))));
end

%update handles
handles.analysis.numrestarts = str2num(get(hObject,'String'));
guidata(hObject, handles);

%%
% createfunction for number of restarts editText
function numrestarts_editText_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%
% checkbox to see if user wants to enter his/her own guesses
function guessFRETstates_checkbox_Callback(hObject, eventdata, handles)
% enable/disable guessFRETstates_editText
if get(hObject,'Value')
    set(handles.guessFRETstates_editText,'Enable','on');
    handles.analysis.use_guess = 1;
else
    set(handles.guessFRETstates_editText,'Enable','off');
    handles.analysis.use_guess = 0;
end

%update handles
guidata(hObject, handles);

%%
% editText holding the user input guessed states
function guessFRETstates_editText_Callback(hObject, eventdata, handles)

% make sure input is an allowed value
[handles.analysis.guess] = read_guess(get(hObject,'String'));

% check that a valid guess was entered, if not set exist_guess = false
if isempty(handles.analysis.guess)
    handles.analysis.exist_guess = 0;
else
    handles.analysis.exist_guess = 1;
end

%update handles
guidata(hObject, handles);

%%
function guessFRETstates_editText_CreateFcn(hObject, eventdata, handles)
    
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%
% plot slider edit text: displays trace name and will jump to a new trace
% if the name is typed in
function plot1Slider_editText_Callback(hObject, eventdata, handles)

%obtains the slider value from the slider component
sliderString = get(handles.plot1Slider_editText,'String');

%convert from string to number
sliderNum = find(ismember(handles.dat.labels,sliderString),1);

%warn if user enters an invalid string and return to original trace
if isempty(sliderNum)
    msgboxText{1} = sprintf('%s is not one of the traces currently loaded.',sliderString);
    msgbox(msgboxText,'Invalid Trace Name', 'none');    
    set(handles.plot1Slider_editText,'String',handles.dat.labels{get(handles.plot1_slider,'Value')});
    return
end

n = sliderNum;
N = length(handles.dat.labels);

%update slider and fraction box
set(handles.plot1_slider,'Value',sliderNum)
set(handles.plot1SliderFraction_editText,'String',sprintf('%d of %d',n,N));

% update plot if applicable
plotFRET(handles.axes1, handles.dat, handles.plot, n);

% Update handles structure
guidata(hObject, handles);

%%
function plot1Slider_editText_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%
% the slide bar to scroll through traces
function plot1_slider_Callback(hObject, eventdata, handles)
% slider value can only be a whole number
sliderValue = round(get(handles.plot1_slider,'Value'));
set(handles.plot1_slider,'Value',sliderValue);

n = sliderValue;
N = length(handles.dat.labels);

% update fraction and label edit texts 
set(handles.plot1Slider_editText,'String',handles.dat.labels{sliderValue});
set(handles.plot1SliderFraction_editText,'String',sprintf('%d of %d',n,N));

% update plot if applicable
plotFRET(handles.axes1, handles.dat, handles.plot, n);
%update handles
guidata(hObject, handles);

%%
function plot1_slider_CreateFcn(hObject, eventdata, handles)

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

%%
% editText showing the trace number ( n of N )
function plot1SliderFraction_editText_Callback(hObject, eventdata, handles)

N = length(handles.dat.labels);

% make sure input is an allowed value
input = regexp(get(hObject,'String'), '\d+','match');

if (isempty(input) || sum(str2num(input{1}) == 1:N) == 0)
    n = get(handles.plot1_slider,'Value');
    set(handles.plot1SliderFraction_editText,'String',sprintf('%d of %d',n,N));
    return
end

n = str2num(input{1});

%update slider and fraction edit text and label edit text
set(handles.plot1_slider,'Value',n)
set(handles.plot1SliderFraction_editText,'String',sprintf('%d of %d',n,N));
set(handles.plot1Slider_editText,'String',handles.dat.labels{n});

% update plot if applicable
plotFRET(handles.axes1, handles.dat, handles.plot, n);

% Update handles structure
guidata(hObject, handles);

%%
function plot1SliderFraction_editText_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%
% enlarge plot radio button 
function enlargePlot_radiobutton_Callback(hObject, eventdata, handles)
% open up a new figure window with the current plot
set(hObject,'Value',0);
figure
h = axes;
plotFRET(h, handles.dat, handles.plot, get(handles.plot1_slider,'Value'));

%%
% buttongroup toggling between plotting in 1D and 2D
function plotDimension_buttongroup_SelectionChangeFcn(hObject, eventdata)

%retrieve GUI data, i.e. the handles structure
handles = guidata(hObject); 
 
switch get(eventdata.NewValue,'Tag')   % Get Tag of selected object
    case 'plot1D_radiobutton'
        handles.plot.dim = 1;
    case 'plot2D_radiobutton'
        handles.plot.dim = 2;
end
 
%update plot
n = get(handles.plot1_slider,'Value');
plotFRET(handles.axes1, handles.dat, handles.plot, n);

%updates the handles structure
guidata(hObject, handles);

%%
% button group toggling between plot raw and plot fit
function plotType_buttongroup_SelectionChangeFcn(hObject, eventdata)

%retrieve GUI data, i.e. the handles structure
handles = guidata(hObject); 
 
switch get(eventdata.NewValue,'Tag')   % Get Tag of selected object
    case 'plotRaw_radiobutton'
        handles.plot.type = 'r';
    case 'plotAnalyzed_radiobutton'
        if isempty(handles.dat.z_hat) 
            set(handles.plotRaw_radiobutton,'Value',1)
            set(handles.plotAnalyzed_radiobutton,'Value',0)
            return
        end
        handles.plot.type = 'a';
end
 
%update plot
n = get(handles.plot1_slider,'Value');
plotFRET(handles.axes1, handles.dat, handles.plot, n);

%updates the handles structure
guidata(hObject, handles);

%%
% Analyze data pushbutton
function analyzeData_pushbutton_Callback(hObject, eventdata, handles)
% do nothing if data isn't loaded yet or if already running
if isempty(handles.dat.FRET) || (get(handles.analyzeData_pushbutton,'UserData') == 1)
    return
end

% flag lets program know whether analysis is running or not
set(handles.analyzeData_pushbutton,'UserData', 1)

% update gui display
set(handles.analyzeData_pushbutton,'String','Analyzing Data...')
set(handles.msgBox_staticText,'String','Analyzing data...');
handles.plot.dim = handles.analysis.dim;
handles.plot.type = 'a';
handles = init_main_gui_disp(handles);

% inactivate any analysis settings fields until analysis is done/cleared
freezeSettings(1)

%if autosave is active, ask for file name
if isequal(get(handles.autosaveFile,'Label'),'Disable Autosave') &&... 
    (handles.analysis.cur_trace == -1 || isempty(handles.analysis.auto_name))
    [handles.analysis] = get_autosave_name(handles.analysis);
end

% if it's disabeled, then clear autosave name so FRETanalysis knows not to
% autosave
if isequal(get(handles.autosaveFile,'Label'),'Enable Autosave')
    handles.analysis.auto_name = {};
end

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% actually perform FRET inference here
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[handles.dat handles.analysis handles.fit_par] = FRETanalysis();

% set(handles.msgBox_staticText,'String','Analysis complete');

% reactivate analysis settings fields if analysis complete
if handles.analysis.cur_trace == -1
    % flag lets program know whether analysis is running or not
    set(handles.analyzeData_pushbutton,'UserData', 0);
    freezeSettings(0);
end

%if autosave is active (i.e. an autosave name was entered)
%autosave
if ~isempty(handles.analysis.auto_name)
    save_autosave(handles.dat, handles.fit_par, handles.plot, handles.debleach, handles.analysis);
end


%update handles
guidata(hObject, handles);


%%
% pause analysis pushbutton
function pauseAnalysis_pushButton_Callback(hObject, eventdata, handles)
% do nothing if data isn't being analyzed
if get(handles.analyzeData_pushbutton,'UserData') == 0
    return
end
set(handles.analyzeData_pushbutton,'UserData', 0)
set(handles.analyzeData_pushbutton,'String','Resume Analysis')    
% Update handles structure
guidata(hObject, handles);
%%
% clear analysis pushbutton
function clearAnalysis_pushbutton_Callback(hObject, eventdata, handles)
% avoid problems from double clicking
set(hObject,'Enable','inactive')
% error if analysis is running
if get(handles.analyzeData_pushbutton,'UserData') == 1
    flag.type = 'pushed during analysis';
    flag.problem = 'pushbutton';
    vbFRETerrors(flag) 
    return
end

% run clear analysis function
clearAnalysisFxn();

% reactivate button
set(hObject,'Enable','on')

%%
% open loadData GUI
function loadDataFile_Callback(hObject, eventdata, handles)
% open load data GUI
loadData();

%%
% open saveSession GUI
function saveSessionFile_Callback(hObject, eventdata, handles)%%%%%%%%%%%%%%%%%%%%%%%%%%
% open save results gui
saveResults()

% Update handles structure
guidata(hObject, handles);

%%
% disable/enable autosave
function autosaveFile_Callback(hObject, eventdata, handles)
% don't allow to change during data analysis
if get(handles.analyzeData_pushbutton,'UserData') == 1
    flag.type = 'pushed during analysis';
    flag.problem = 'pushbutton';
    vbFRETerrors(flag) 
    return
end

if isequal(get(hObject,'Label'),'Disable Autosave');
    set(hObject,'Label','Enable Autosave');
    handles.analysis.auto_save = 0;
    msgboxText{1} = sprintf('Autosave disabled.');
    uiwait(msgbox(msgboxText,'', 'none'));
else
    set(hObject,'Label','Disable Autosave');
    handles.analysis.auto_save = 1;
    msgboxText{1} = sprintf('Autosave enabled.');
    uiwait(msgbox(msgboxText,'', 'none'));
end

% Update handles structure
guidata(hObject, handles);

%%
% reset vbFRET
function resetFile_Callback(hObject, eventdata, handles)
% error if analysis is running
if get(handles.analyzeData_pushbutton,'UserData') == 1
    flag.type = 'pushed during analysis';
    flag.problem = 'pushbutton';
    vbFRETerrors(flag) 
    return
end

%clear everything
handles.dat = init_dat();               % holds data
handles.fit_par = [];                   % will hold best fit parameters
handles.plot = init_plot();             % plot options
handles.debleach = debleach_defaults(); % options for photobleach removal
handles.analysis = analysis_defaults(); % get default settings for data analysis

%update vbFRET with all plot slidebar settings
update_plot_slidebar(handles.dat);

% initialize main gui display
handles = init_main_gui_disp(handles);

% clear message box
set(handles.msgBox_staticText,'String','');

% reset text of analyze data button
set(handles.analyzeData_pushbutton,'String','Analyze Data!')

% make sure pointer is arrow
set(handles.figure1,'Pointer','arrow')

% Update handles structure
guidata(hObject, handles);

%%
% exit vbFRET
function exitFile_Callback(hObject, eventdata, handles)
% sadly, there's no way to check if any other vbFRET GUIs (i.e. loadData)
% are open without actually opening them...
close(vbFRET)
%%
% open delete traces GUI
function deleteTraces_Callback(hObject, eventdata, handles)
deleteTraces();

%%
% open debleach traces GUI
function debleachTraces_Callback(hObject, eventdata, handles)
debleachTraces();

%%
% open advanced analysis settings GUI
function advancedAnalysisSettings_Callback(hObject, eventdata, handles)
advancedAnalysisSettings();

%%
function advancedPlotSettings_Callback(hObject, eventdata, handles)%%%%%%%%%%%%%%
% open plot settings GUI
plotSettings();

%%
% save users settings as default so they always load when user opens vbFRET
function makeDefaultSettings_Callback(hObject, eventdata, handles)

% get folder to save settings in
mpath = fileparts(mfilename('fullpath'));
if isunix
    mpath = ['/' mpath '/src'];
else
    mpath = [mpath '\src'];
end

% create new default settings
write_defaults_plot(handles,mpath);
write_defaults_debleach(handles,mpath);
write_defaults_analysis(handles,mpath);
msgboxText{1} = sprintf('New default settings successfully saved.');
uiwait(msgbox(msgboxText,'', 'none'));

%%
% restore default settings that came with the program
function restoreOriginalSettings_Callback(hObject, eventdata, handles)

% get folder to save settings in
mpath = fileparts(mfilename('fullpath'));
if isunix
    mpath = ['/' mpath '/src'];
else
    mpath = [mpath '\src'];
end

%%% load default settings that came with the program into a data structure
settings.plot = init_plot_bkup();             % plot options
settings.debleach = debleach_defaults_bkup(); % options for photobleach removal
settings.analysis = analysis_defaults_bkup(); % get default settings for data analysis

% save them as the defaults
write_defaults_plot(settings,mpath);
write_defaults_debleach(settings,mpath);
write_defaults_analysis(settings,mpath);
msgboxText{1} = sprintf('Original default settings successfully restored. Changes will take effect next time you open vbFRET.');
uiwait(msgbox(msgboxText,'', 'none'));


%%
function rawHistPostAnalysis_Callback(hObject, eventdata, handles)
% 1D histogram of raw FRET data
%return if no data loaded yet
if isempty(handles.dat.raw)
    return
end
% error if try to save while running analysis
if get(handles.analyzeData_pushbutton,'UserData') == 1
    flag.type = 'pushed during analysis';
    flag.problem = 'pushbutton';
    vbFRETerrors(flag) ;
    return
end

%notice this is a cell array!
prompt={'Number of bins' 'X min/max' 'Y min/max'};
%name of the dialog box
name='';
%number of lines visible for your input
numlines=1;
defaultName = {'50', 'Default', 'Default'};
%creates the dialog box. the user input is stored into a cell array
hist_params = inputdlg(prompt,name,numlines,defaultName);
if isempty(hist_params)
    return
end
%already made sure z_hat_db not empty
if handles.plot.blur_rm*handles.analysis.remove_blur
    FRET = handles.dat.FRET_db;
    title_str = 'FRET Blur-Cleaned Data Histogram';
else
    FRET = handles.dat.FRET;
    title_str = 'FRET Data Histogram';
end

fret = [];
for n = 1:length(FRET)
    if isempty(FRET{n})
        continue
    end
    fret = [fret FRET{n}'];
end

xlims = str2num(hist_params{2});
% if user entered two numbers use them to define xlimits
if length(xlims) == 2 
    fret(fret < min(xlims)) = [];
    fret(fret > max(xlims)) = [];
end
figure
h = axes;
% use nbins if user entered number 
if length(str2num(hist_params{1})) == 1
    hist(h,fret,str2num(hist_params{1}));
else
    hist(h,fret);
end
if length(xlims) == 2 
    xlim([min(xlims) max(xlims)])
end
ylims = str2num(hist_params{3});
if length(ylims) == 2 
    ylim([min(ylims) max(ylims)])
end

xlabel('FRET')
ylabel('Number of data points')
title(title_str);

%%
function meanHistPostAnalysis_Callback(hObject, eventdata, handles)%%%%%%%%%%
% 1D histogram of idealized FRET data
%return if no data loaded yet
if isempty(handles.dat.raw)
    return
end
% error if try to save while running analysis
if get(handles.analyzeData_pushbutton,'UserData') == 1
    flag.type = 'pushed during analysis';
    flag.problem = 'pushbutton';
    vbFRETerrors(flag) ;
    return
end

% warnings and errors if incomplete data plotted
stop_flag = incomplete_data_check(handles.plot.blur_rm,handles.analysis.remove_blur,handles.dat);
if stop_flag
    return
end

%notice this is a cell array!
prompt={'Number of bins' 'X min/max' 'Y min/max'};
%name of the dialog box
name='';
%number of lines visible for your input
numlines=1;
defaultName = {'50', 'Default', 'Default'};
%creates the dialog box. the user input is stored into a cell array
hist_params = inputdlg(prompt,name,numlines,defaultName);
if isempty(hist_params)
    return
end
%already made sure z_hat_db not empty
if handles.plot.blur_rm*handles.analysis.remove_blur
    xhat = handles.dat.x_hat_db(1,:);
    title_str = 'Idealized Blur-Cleaned Data Histogram';
else
    xhat = handles.dat.x_hat(1,:);
    title_str = 'Idealized Data Histogram';
end

xall = [];
for n = 1:length(xhat)
    if isempty(xhat{n})
        continue
    end
    xall = [xall xhat{n}'];
end

xlims = str2num(hist_params{2});
% if user entered two numbers use them to define xlimits
if length(xlims) == 2 
    xall(xall < min(xlims)) = [];
    xall(xall > max(xlims)) = [];
end
figure
h = axes;
% use nbins if user entered number 
if length(str2num(hist_params{1})) == 1
    hist(h,xall,str2num(hist_params{1}));
else
    hist(h,xall);
end
if length(xlims) == 2 
    xlim([min(xlims) max(xlims)])
end
ylims = str2num(hist_params{3});
if length(ylims) == 2 
    ylim([min(ylims) max(ylims)])
end

xlabel('FRET')
ylabel('Number of data points')
title(title_str)
%%
function statesHistPostAnalysis_Callback(hObject, eventdata, handles)
% plot histogram of the number of states fit to each trace

%return if no data loaded yet
% error if try to save while running analysis
if get(handles.analyzeData_pushbutton,'UserData') == 1
    flag.type = 'pushed during analysis';
    flag.problem = 'pushbutton';
    vbFRETerrors(flag) ;
    return
end

% warnings and errors if incomplete data plotted
stop_flag = incomplete_data_check(handles.plot.blur_rm,handles.analysis.remove_blur,handles.dat);
if stop_flag
    return
end

%already made sure z_hat_db not empty
if handles.plot.blur_rm*handles.analysis.remove_blur
    zhat = handles.dat.z_hat_db;
else
    zhat = handles.dat.z_hat;
end
hist_vec = zeros(1,handles.analysis.maxK);

for n = 1:length(zhat)
    if isempty(zhat{n})
        continue
    end
    Kn = length(unique(zhat{n}));
    if Kn > length(hist_vec)
        hist_vec(Kn) = 0;
    end
    hist_vec(Kn) = hist_vec(Kn) + 1;
end
figure
h = axes;
bar(h,hist_vec);
xlabel('Number of states')
ylabel('Number of traces')

%%
function fileMenu_Callback(hObject, eventdata, handles)
% no code needed for this callback

function tracesMenu_Callback(hObject, eventdata, handles)
% no code needed for this callback

function optionsMenu_Callback(hObject, eventdata, handles)
% no code needed for this callback

function PostAnalysisMenu_Callback(hObject, eventdata, handles)
% no code needed for this callback


%%
function [analysis] = get_autosave_name(analysis)
%notice this is a cell array!
prompt={'Autosave name:'};
 
%name of the dialog box
name='Autosave Name';
 
%number of lines visible for your input
numlines=1;
 
% default autosave name is vbFRET_date_time
d_t = clock;
defaultName = {sprintf('vbFRETautosave_D%02d%02d%02d_T%02d%02d',d_t(2),d_t(3),d_t(1)-2000,d_t(4),d_t(5))};
 
%creates the dialog box. the user input is stored into a cell array
save_name = inputdlg(prompt,name,numlines,defaultName);

if isempty(save_name)
    analysis.auto_name = {};
else
    % make sure file extension is .mat
    [filePath,fileName,ext] = fileparts(save_name{1});
    save_name = fullfile(filePath,[fileName '.mat']);
    % save autosave name 
    analysis.auto_name = save_name;
end



%%
function [array_out] = read_guess(str_in)
% this function takes a string of numeric text and puts each line of it
% into a vector. The vectors are then stored as cells of a cell array. If
% the line of numbers is separated by ';' ':' or '|' then the line of data
% is stored as a 2 column array.If the text is not all numeric a warning is
% generated.

array_out = [];
% remove white space
str_in = strtrim(str_in);


%do nothing if no string was input
if isempty(str_in);
    return
end

% determine if string is 1D or 2D, '; : | \ /' are allowed break lines
breakl = find(str_in == ';' | str_in == '|' | str_in == '/' | str_in == '\');

% if not, store the whole line as a vector
if isempty(breakl)
    array_out = str2num(str_in)';
% otherwise split the line in two (1:first break) and (first break + 1:
% 2nd break/end)
else
    % for now, vbFRET only works in 1D
    % v1 = str2num(str_in(1:breakl(1)-1));
    % v2 = str2num(str_in(breakl(1)+1:end));

    % make sure v1 and v2 are the same size
    % equal_length = length(v1) == length(v2);
    
    % if equal_length
    %    array_out = [v1;v2]';
    % else
    %    array_out = [];
    %end
    array_out = str2num(str_in(1:breakl(1)-1))';
end
% warn if a non number character was used or if the strings were the wrong
% size
if isempty(array_out)
    if exist('equal_length','var') && equal_length == 0
        flag.type = 'guess_string';
        flag.problem = 'guess_string_2D';
        vbFRETerrors(flag);
    else
        flag.type = 'guess_string';
        flag.problem = 'non_numeric';
        vbFRETerrors(flag);
    end
end

