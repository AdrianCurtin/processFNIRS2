function varargout = exploreFNIRS(varargin) % exploreFNIRS(data,timeShiftTo0,blStart,blEnd,blockStart,blockEnd,plotStart,plotEnd,barSegmentLength)
% exploreFNIRS is a program which organizes experimental FNIRS data into an exportable table, or for plotting
%		Accepts a cell array of FNIRS structs (ideally with populated FNIRS.info fields and timeshifted so that the task/segment of interest starts at t=0 or the same time)
%		Use the Groupby buttons to specify important grouping levels such as Session X Condition or Group X Trial depending on your variables of interest
%		Behavioral and FNIRS data is averaged by default according to the within subject heirarchy options
%			ie: a subjects average score is the average of their sessions each of which is the average of all trials (this hierarchy can be changed in the GUI)
%			Alternatively averaging can be set to Flat to change it so that subject data is averaged without respect to experimental hierarchy (necessary for LME models)
%			ie: a subjects average score is the average of all their scores regardless of how many trials are in each session
%		Plots are generated based on your groupby selection and the number of optodes/biomarkers you have selected to plot simultaneously
%			There is an additional plotby button which allows one of the groupby factors to be used to split plots based on that factor
%			(Otherwise all groups show up as different colors on the same plot)
%		A variable from the info field may be assigned as a groupby factor (best used for non-numeric data)
%		A second variable from the info field may be plotted and optionally used as a covariate in the LME outputs
%		Plot colors may be selected automatically using defined color maps (or a mycolorfunc you define)
%			Additionally manual colors may be saved/loaded in a 3x10color csv file (rows are r,g,b (from 0 to 1) and each column is a color)
%		Exported data will come out as a CSV file with all barchart timepoints and All biomarkers for the currently selected groups (in wide format)
%			Exporting as a MAT file will also contain grand average structs and other data

% Todo
%	Implement units in plots (currently just assumes uM)
%	Implement efficiency plots
%	Implement post-hoc for LME
%	Implement GLM approach for tepmoral data
%	Implement region of interest grouping for channels
%	Implement more flexible LME model options
%	Better/3D parametric plots
%	Parametric plots for correlation
%	Ability to plot/analyze aux data

% Change Log
% 3/19/2019 Added ability to get mean and average values for Auxillary
%           channels, Channels are exported currently when uising Long Format only
%            Also changed long format output to default to channelXbiomarker instead of channel only for columns
% 2/4/2019  Renamed .Total to .HbTotal
% 1/25/2019	Added multi biomarker plotting for Topographic maps
%           Added long format biomarker export
% 1/24/2019 Changed default behavior to disable single entry or unused info fields
%			Added internal wide table merging
%			Added support for LME model building (outputs when enabled and a barchart is produced, or topographic map)
%			Currently supports two model structures     Time*BioM*Factor1*Factor2.... (all interactions) or Time*BioM*Factor1+Time*BioM*Factor2+.... (minimal interactions)
%				Optionally uses infofield as a covariate  Time*BioM*InfoCov*(Factor1+/*Factor2+/*Factor3...) (follows same rules above for interactions
%			Added ability to plot topographic maps using LME models
% 1/18/2019 Added ability to use separate info  field as a groupby parameter
%			Added support for shaded error bars in scatter plots
%			Added ability to sort manual GUI colors (up/down)
% 1/17/2019 Added support for shaded error bars in temporal plots
%			Added support for scatterplots (using the info field data from barchart)
%				Includes nonparametric modes, correlation statistics, errors, and more
% 1/16/2019 Added support for datacursor in plots to visualize information
% 			Added ability to fix ylimits automatically or manually assign them
%			Added ability of one groupby parameter to be used to split plots (plotby)
%			Added support for categorical count in infofield barcharts
% 1/15/2019 Added ability to plot data from info field as barchart
%			Added support for exporting barchartdata as mat file 
%			Added support and configuration for hierarchical averaging (within subject averaging to prevent multisampling of participants)
% 1/14/2019 Added support for variable arguments to assign values to baseline,block, plot,times, automatic time shifting and other parameters
% 			Now missing values are labeled as missing
%			Added support for subgroups
%			Added support for grandAverage plots (temporal)
%			Added grandaverage error plot support
%			Added default biomarker color scheme
%			Added option to mark baseline&task start/end with vertical lines
%			Added ability to export barchart data (merged with original table) as CSV
%			Added ability to plot barcharts
%			Added ability to defined and load custom colors
% 1/13/2019 Added ability to plot individual FNIRS data (temporal)
%			Added grandaverage resampling for all segments
% 1/12/2019 Initial Version
	

% EXPLOREFNIRS MATLAB code for exploreFNIRS.fig
%      EXPLOREFNIRS, by itself, creates a new EXPLOREFNIRS or raises the existing
%      singleton*.
%
%      H = EXPLOREFNIRS returns the handle to a new EXPLOREFNIRS or the handle to
%      the existing singleton*.
%
%      EXPLOREFNIRS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in EXPLOREFNIRS.M with the given input arguments.
%
%      EXPLOREFNIRS('Property','Value',...) creates a new EXPLOREFNIRS or raises
%      the existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before exploreFNIRS_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to exploreFNIRS_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help exploreFNIRS

% Last Modified by GUIDE v2.5 04-Jul-2019 02:02:40

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @exploreFNIRS_OpeningFcn, ...
                   'gui_OutputFcn',  @exploreFNIRS_OutputFcn, ...
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

% --- Executes just before exploreFNIRS is made visible.
function exploreFNIRS_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to exploreFNIRS (see VARARGIN)

% Choose default command line output for exploreFNIRS
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

initialize_gui(hObject, handles, false);

global ExFNIRS

if(~isfield(ExFNIRS,'defaultRootPath'))
    [ExFNIRS_folder,~,~] = fileparts(mfilename('fullpath'));
    ExFNIRS.defaultRootPath=ExFNIRS_folder;
    curdir=cd;
    cd(ExFNIRS.defaultRootPath);
    addpath('base_functions','GUI','functions');
    cd(curdir);
end

set(handles.text_versInfo,'String',exploreFNIRS.versInfo());

warning('OFF','MATLAB:table:RowsAddedExistingVars')
p=inputParser;

validScalarNum = @(x) isnumeric(x) && isscalar(x);
validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);

if(~isfield(ExFNIRS,'settings')||~isfield(ExFNIRS.settings,'baseline_start'))
    ExFNIRS.settings.baseline_start=0;
    ExFNIRS.settings.baseline_end=5;
    ExFNIRS.settings.block_start=5;
    ExFNIRS.settings.block_end=65;
    ExFNIRS.settings.plot_start=[];
    ExFNIRS.settings.plot_end=[];
    ExFNIRS.settings.barchart_resample_size=60;
    ExFNIRS.settings.timeShiftTo0=true;
    ExFNIRS.settings.ChannelMode='fNIR';  % valid is fNIR, ROI, and Aux
    ExFNIRS.settings.ChannelModes={1,'fNIR';2,'ROI';3,'Aux'};
    ExFNIRS.settings.processRaw=get(handles.checkbox_process_raw,'Value');
    ExFNIRS.settings.LME_use_intercept=get(handles.checkbox_LME_use_intercept,'Value');
    ExFNIRS.settings.LME_use_discreteTime=get(handles.checkbox_discreteTime,'Value');
    ExFNIRS.settings.LME_randomFxStr='1|SubjectID';
    ExFNIRS.settings.LME_use_customStr=get(handles.checkbox_lme_usecustom,'Value');
    ExFNIRS.settings.topoSigThrehold={'p',0.05};
    ExFNIRS.settings.LME_customStr='';
    ExFNIRS.settings.use_info=true;
    ExFNIRS.settings.use_group=get(handles.checkbox_use_group,'Value');
    ExFNIRS.settings.plot_temporal_y0=get(handles.checkbox_yaxis,'Value');
    ExFNIRS.dataHierarchy={'SubjectID','Session','Condition','Trial','Block'};
end


addOptional(p,'filename','',@ischar);
addOptional(p,'data',[],@iscell); % Your data, as a cell of FNIRS structs (ideally with populated info fields and the task of interest starting at t=0)
addOptional(p,'timeShiftTo0',ExFNIRS.settings.timeShiftTo0,@islogical); %Specifies whether to automatically shift the start of the FNIRS period to 0, 
		%best practice though is to turn this off and do it yourself before hand so that task starts at 0s and the baseline is before/after/during. See setT0fnirs()
addOptional(p,'blStart', ExFNIRS.settings.baseline_start,validScalarNum);  %Time at which baseline starts (absolute)
addOptional(p,'blEnd',ExFNIRS.settings.baseline_end,validScalarNum);	%Time at which baseline ends (absolute)
addOptional(p,'blockStart',ExFNIRS.settings.block_start,validScalarNum); %Time at which block or task starts (absolute)
addOptional(p,'blockEnd',ExFNIRS.settings.block_end,validScalarNum); %Time at which block or task ends (absolute)
addOptional(p,'plotStart',ExFNIRS.settings.plot_start,validScalarNum); %Default parameter for lower xlimit on plots (affects which models are displayed in barcharts and which timepoints are included)
addOptional(p,'plotEnd',ExFNIRS.settings.plot_end,validScalarNum); %Default parameter for upper xlimit on plots (see above note)
addOptional(p,'barSegmentLength', ExFNIRS.settings.barchart_resample_size,validScalarPosNum); %Default averaging/binning period for barcharts AND relevant export information  

parse(p,varargin{:});

if(~isempty(p.Results.data)||~isfield(ExFNIRS,'data'))
    ExFNIRS.data=p.Results.data;
    
    if(size(ExFNIRS.data,2)>size(ExFNIRS.data,1))
        ExFNIRS.data=ExFNIRS.data';
    end
elseif(~isempty(p.Results.filename))
   exploreFNIRS.LoadEx(p.results.filename);
end



    


ExFNIRS.settings.baseline_start=p.Results.blStart;
ExFNIRS.settings.baseline_end=p.Results.blEnd;
ExFNIRS.settings.block_start=p.Results.blockStart;
ExFNIRS.settings.block_end=p.Results.blockEnd;
ExFNIRS.settings.plot_start=p.Results.plotStart;
ExFNIRS.settings.plot_end=p.Results.plotEnd;
ExFNIRS.settings.barchart_resample_size=p.Results.barSegmentLength;



segInfoVars={'Session','Trial','Block','Condition','Time'};
randFxStr{1}='1|SubjectID';
for i=2:2:length(segInfoVars)*2
   randFxStr{i}=sprintf('%s|SubjectID',segInfoVars{(i)/2}); 
   randFxStr{i+1}=sprintf('-1+%s|SubjectID',segInfoVars{(i)/2}); 
end

set(handles.popupmenu_lmer_randomeffects,'String',randFxStr);
ExFNIRS.settings.LME_randomFxStrs=randFxStr;

if(ExFNIRS.settings.processRaw)
    set(handles.listbox_raw_methods,'Enable','on');
else
    set(handles.listbox_raw_methods,'Enable','off');
    set(handles.listbox_raw_methods,'Value',1);
end




if(isempty(ExFNIRS.settings.plot_start))
   ExFNIRS.settings.plot_start=min(0,ExFNIRS.settings.block_start);
end

if(isempty(ExFNIRS.settings.plot_end))
   ExFNIRS.settings.plot_end=ExFNIRS.settings.block_end;
end



ExFNIRS.settings.within_sub_avg_mode=get(handles.popupmenu_within_sub_avg,'Value'); %0 none, 1 flat, 2 hierarchy

set(handles.listbox_hierarchy,'String',ExFNIRS.dataHierarchy(2:end));

ExFNIRS.settings.timeShiftTo0=p.Results.timeShiftTo0;

set(handles.edit_baseline_start,'String',sprintf('%.2f',ExFNIRS.settings.baseline_start));
set(handles.edit_baseline_end,'String',sprintf('%.2f',ExFNIRS.settings.baseline_end));
set(handles.edit_block_start,'String',sprintf('%.2f',ExFNIRS.settings.block_start));
set(handles.edit_block_end,'String',sprintf('%.2f',ExFNIRS.settings.block_end));
set(handles.edit_plot_start,'String',sprintf('%.2f',ExFNIRS.settings.plot_start));
set(handles.edit_plot_end,'String',sprintf('%.2f',ExFNIRS.settings.plot_end));
set(handles.edit_barchart_resample_size,'String',sprintf('%.2f',ExFNIRS.settings.barchart_resample_size));

set(handles.checkbox_process_raw,'Value',ExFNIRS.settings.processRaw);
strs=get(handles.popupmenu_info_group,'String');
val=get(handles.popupmenu_info_group,'Value');
if(~iscell(strs))
    selStr=strs;
else
    selStr=strs{val};
end
ExFNIRS.settings.curInfoGroup=selStr;



strs=get(handles.popupmenu_groupby_info_field,'String');
val=get(handles.popupmenu_groupby_info_field,'Value');

if(~iscell(strs))
    selStr=strs;
else
    selStr=strs{val};
end

ExFNIRS.settings.curInfoGroupBy=selStr;


if(isempty(ExFNIRS.data))
    error('Must supply data!');
end

fsArray=nan(length(ExFNIRS.data(:)));
for i=length(ExFNIRS.data):-1:1
    if(isempty(ExFNIRS.data{i}))
        ExFNIRS.data(i)=[];
        continue;
    end
    if(isfield(ExFNIRS.data{i},'time'))
       fsArray(i)=median(diff(ExFNIRS.data{i}.time)); 
    end
    
    if( ExFNIRS.settings.timeShiftTo0)
        ExFNIRS.data{i}=processFNIRS2.Data.SetT0(ExFNIRS.data{i},min(ExFNIRS.data{i}.time));
    end
    
    if(isfield(ExFNIRS.data{i},'info'))
        ExFNIRS.data{i}.info.rowID=i;
    end
end

estimatedFS=nanmedian(fsArray(:));

subIdAuto=1;

for i=1:length(ExFNIRS.data)
   if((~isfield(ExFNIRS.data{i},'raw')&&~isfield(ExFNIRS.data{i},'HbO'))||(length(ExFNIRS.data{i}.time)==1&&(isnan(ExFNIRS.data{i}.time)))||sum(sum(~isnan(ExFNIRS.data{i}.raw(:,2:end)),1),2)==0) %info only
       ExFNIRS.data{i}.time=nan;
       ExFNIRS.data{i}.info.missingFNIRS=1;
   else
       ExFNIRS.data{i}.info.missingFNIRS=0;
       
       if(~isfield(ExFNIRS.data{i}.info,'Group')||isempty(ExFNIRS.data{i}.info.Group))
           ExFNIRS.data{i}.info.Group='Missing';
       end
       
       if(~isfield(ExFNIRS.data{i}.info,'SubjectID')||isempty(ExFNIRS.data{i}.info.SubjectID))
           ExFNIRS.data{i}.info.SubjectID=sprintf('Missing%i',subIdAuto);
           subIdAuto=subIdAutp+1;
       end
       
       if(~isfield(ExFNIRS.data{i}.info,'Subgroup')||isempty(ExFNIRS.data{i}.info.Subgroup))
           ExFNIRS.data{i}.info.Subgroup='Missing';
       end
       
       if(~isfield(ExFNIRS.data{i}.info,'Session')||isempty(ExFNIRS.data{i}.info.Session))
           ExFNIRS.data{i}.info.Session='Missing';
       end
       
       if(~isfield(ExFNIRS.data{i}.info,'Trial')||isempty(ExFNIRS.data{i}.info.Trial))
           ExFNIRS.data{i}.info.Trial='Missing';
       end
       
       if(~isfield(ExFNIRS.data{i}.info,'Block')||isempty(ExFNIRS.data{i}.info.Block))
           ExFNIRS.data{i}.info.Block='Missing';
       end
       
       if(~isfield(ExFNIRS.data{i}.info,'Condition')||isempty(ExFNIRS.data{i}.info.Condition))
           ExFNIRS.data{i}.info.Condition='Missing';
       end
   end
end

ExFNIRS.dataTable=BuildSegmentInfoTable(ExFNIRS.data);


ExFNIRS.settings.updateOnChange=get(handles.checkbox_auto_update,'Value');


set(handles.popupmenu_info_field,'String',ExFNIRS.dataTable.Properties.VariableNames);
set(handles.popupmenu_info_field,'Value',length(ExFNIRS.dataTable.Properties.VariableNames));
strs=get(handles.popupmenu_info_field,'String');
val=get(handles.popupmenu_info_field,'Value');
selStr=strs{val};
ExFNIRS.settings.curInfoStr=selStr;

set(handles.popupmenu_groupby_info_field,'String',ExFNIRS.dataTable.Properties.VariableNames);
set(handles.popupmenu_groupby_info_field,'Value',1);
strs=get(handles.popupmenu_groupby_info_field,'String');
val=get(handles.popupmenu_groupby_info_field,'Value');
selStr=strs{val};
ExFNIRS.settings.curInfoGroupBy=selStr;

popupmenu_groupby_info_field_Callback([], [], handles); %update fieldbox



segInfoVars={'SubjectID','Group','Subgroup','Session','Trial','Block','Condition'};


for v =1:length(segInfoVars)
   if(~ismember(segInfoVars{v},ExFNIRS.dataTable.Properties.VariableNames))
        ExFNIRS.dataTable.(segInfoVars{v})=strings(size(ExFNIRS.dataTable,1),1);
        ExFNIRS.dataTable.(segInfoVars{v})(:,1)='Missing';
   elseif(isnumeric(ExFNIRS.dataTable.(segInfoVars{v})(1)))
       nIdx=isnan(ExFNIRS.dataTable.(segInfoVars{v}));
       if(any(nIdx))
          warning('Missing value to deal with'); 
       end
       %ExFNIRS.dataTable.(segInfoVars{v})(nIdx)=
   elseif(isstring(ExFNIRS.dataTable.(segInfoVars{v})(1)))
       nIdx=strcmp(ExFNIRS.dataTable.(segInfoVars{v}),'');
       ExFNIRS.dataTable.(segInfoVars{v})(nIdx)='Missing'; 
   end
end


%processFNIRS2('UseDeviceCFG','device_fNIR1200.cfg');
processFNIRS2('blLength',0); %use global mean for import

%ExFNIRS.settings=[];

ExFNIRS.settings.plotby=[];

ExFNIRS.settings.plotby.SubjectID=get(handles.checkbox_subjectID_plotby,'Value');
ExFNIRS.settings.plotby.Group=get(handles.checkbox_group_plotby,'Value');
ExFNIRS.settings.plotby.Session=get(handles.checkbox_session_plotby,'Value');
ExFNIRS.settings.plotby.Trial=get(handles.checkbox_trial_plotby,'Value');
ExFNIRS.settings.plotby.Condition=get(handles.checkbox_condition_plotby,'Value');
ExFNIRS.settings.plotby.Block=get(handles.checkbox_block_plotby,'Value');
ExFNIRS.settings.plotby.InfoGroupBy=get(handles.checkbox_block_plotby,'Value');

ExFNIRS.settings.plot_grandaverage_feature='Mean';
ExFNIRS.settings.plot_grandaverage=get(handles.checkbox_plot_grandaverage,'Value');
ExFNIRS.settings.plot_individual=get(handles.checkbox_plot_all_data,'Value');
ExFNIRS.settings.plot_error=get(handles.checkbox_plot_error,'Value');
ExFNIRS.settings.plot_error_multiply=str2num(get(handles.edit_error_multiplier,'String'));
ExFNIRS.settings.plot_task_lines=get(handles.checkbox_mark_task,'Value');
idx=get(handles.popupmenu_errorbar_style,'Value');
strs=get(handles.popupmenu_errorbar_style,'String');
ExFNIRS.settings.plot_error_style=strs{idx};
idx=get(handles.popupmenu_errorbar_feature,'Value');
strs=get(handles.popupmenu_errorbar_feature,'String');
ExFNIRS.settings.plot_error_feature=strs{idx};

ExFNIRS.settings.plot_legend_mode=2; %1 none %2 last fig %3 all

ExFNIRS.settings.grandavg_resample_size=estimatedFS;
set(handles.edit_grandavg_resample_size,'String',sprintf('%.3f',ExFNIRS.settings.grandavg_resample_size));
%ExFNIRS.settings.code_missing=get(handles.checkbox_code_nan,'Value');

ExFNIRS.settings.plot_bar_ga=get(handles.checkbox_plot_barchart_ga,'Value');
ExFNIRS.settings.plot_bar_all=get(handles.checkbox_plot_barchart_all_points,'Value');
ExFNIRS.settings.plot_bar_err_mult=str2double(get(handles.edit_bar_error_multiplier,'String'));
ExFNIRS.settings.plot_bar_err_feature='SEM';
ExFNIRS.settings.plot_bar_err=get(handles.checkbox_plot_barchart_error,'Value');
ExFNIRS.settings.plot_bar_feature='Mean';

ExFNIRS.settings.plot_scatter_err=get(handles.checkbox_plot_scatter_error,'Value');
ExFNIRS.settings.plot_scatter_err_mult=str2double(get(handles.edit_scatter_error_multiplier,'String'));
ExFNIRS.settings.plot_scatter_nonparametric=get(handles.checkbox_plot_scatter_nonparametric,'Value');
ExFNIRS.settings.plot_scatter_line=get(handles.checkbox_plot_scatter_line,'Value');
idx=get(handles.popupmenu_scatter_error_feature,'Value');
strs=get(handles.popupmenu_scatter_error_feature,'String');
ExFNIRS.settings.plot_scatter_err_feature=strs{idx};
ExFNIRS.settings.plot_scatter_extend=get(handles.checkbox_plot_scatter_extend,'Value');
idx=get(handles.popupmenu_scatter_error_style,'Value');
strs=get(handles.popupmenu_scatter_error_style,'String');
ExFNIRS.settings.plot_scatter_error_style=strs{idx};
ExFNIRS.settings.plot_scatter_flipxy=get(handles.checkbox_plot_scatter_flipxy,'Value');

ExFNIRS.settings.LME_enable=get(handles.checkbox_LME_enable,'Value');
ExFNIRS.settings.LME_all_interactions=get(handles.checkbox_LME_all_interactions,'Value');
ExFNIRS.settings.LME_info_covariate=get(handles.checkbox_LME_info_covariate,'Value');

ExFNIRS.settings.export_replace_missing_9999=get(handles.checkbox_export_9999,'Value');

ExFNIRS.settings.use_group=get(handles.checkbox_use_group,'Value');
if(ExFNIRS.settings.use_group)
    set(handles.listbox_group,'Enable','on');
    set(handles.listbox_subgroup,'Enable','off');
else
    set(handles.listbox_group,'Enable','off');
    set(handles.listbox_subgroup,'Enable','on');
end

ExFNIRS.settings.ylim_manual=get(handles.checkbox_ylim_manual,'Value');
ExFNIRS.settings.ylim_fixed=get(handles.checkbox_ylim_fixed,'Value');
ExFNIRS.settings.ylim_manual_min=str2num(get(handles.edit_ylim_min,'String'));
ExFNIRS.settings.ylim_manual_max=str2num(get(handles.edit_ylim_max,'String'));

ExFNIRS.settings.guiColor=ones(10,3);
ExFNIRS.settings.use_gui_color=get(handles.checkbox_gui_colors,'Value');

[exF_folder,name,ext] = fileparts(mfilename('fullpath'));
loadGUIcolors(sprintf('%s/prefs/%s',exF_folder,'exploreFNIRS_defaultColors.csv'),handles);

idx=get(handles.popupmenu_colors,'Value');
strs=get(handles.popupmenu_colors,'String');
ExFNIRS.settings.cmap=str2func(strs{idx});

PopulateGUIfields(ExFNIRS.dataTable,handles);
strsRaw=get(handles.listbox_raw_methods,'String');
strsOxy=get(handles.listbox_oxy_methods,'String');

ExFNIRS.processedData=cell(length(strsOxy)*length(strsRaw),3);
ExFNIRS.numProcessed=0;

if(isfield(ExFNIRS,'UpdateNeeded')&&ExFNIRS.UpdateNeeded==4)
    ExFNIRS.UpdateNeeded=3;
end

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end


% UIWAIT makes exploreFNIRS wait for user response (see UIRESUME)
% uiwait(handles.figure1);

function outTable=BuildSegmentInfoTable(FNIRS_array)
    
warning off MATLAB:table:RowsAddedExistingVars

global ProgressHandles

if(isempty(FNIRS_array))
    return;
else
    pf2_base.closeProgressHandles();
    
    numF=length(FNIRS_array);
    hF=waitbar(0,sprintf('ExploreFNIRS\nBuilding Table: Row %i of %i',1,numF));
    
    outTable=table();
    for i=1:numF
        try
            waitbar(i/numF,hF,sprintf('ExploreFNIRS\nBuilding Table: Row %i of %i',i,numF));
        catch
            hF=waitbar(i/numF,0,sprintf('ExploreFNIRS\nBuilding Table: Row %i of %i',i,numF));
        end
       curFNIRseg=FNIRS_array{i};
       
       if(~isfield(curFNIRseg,'info'))
           warning('All fNIRS segments must have a .info section');
           continue;
       end
       curFields=fields(curFNIRseg.info);
       for j=1:length(curFields)
           curFieldName=curFields{j};

           curField=curFNIRseg.info.(curFieldName);
           
           if(isempty(curField)||(isnumeric(curField)&&length(curField)==1)||ischar(curField)||(istable(curField)&&size(curField,1)==1&&size(curField,2)==1))
              if(istable(curField)&&size(curField,1)==1&&size(curField,2)==1)
                  curField=curField{1,1};
              end
               
              if(ismember(curFieldName,outTable.Properties.VariableNames)&&~isempty(curField))
                  outTable.(curFieldName)(i,1)=curField;
              elseif(~isempty(curField))
                  if(ischar(curField)) % adds columns
                      outTable.(curFieldName)=strings(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=curField;
                  elseif(isstring(curField))
                      outTable.(curFieldName)=strings(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=curField;
                  elseif(isnumeric(curField))
                      outTable.(curFieldName)=nan(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=curField;
                  elseif(islogical(curField))
                      outTable.(curFieldName)=nan(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=curField;
                  end
                  
              end
           end
       end
    end
    close(hF);
end
    
function PopulateGUIfields(dataTable,handles)

global ExFNIRS

uSub=unique(dataTable.('SubjectID'));
uGroup=unique(dataTable.('Group'));
uSubgroup=unique(dataTable.('Subgroup'));
uSession=unique(dataTable.('Session'));
uTrial=unique(dataTable.('Trial'));
uCondition=unique(dataTable.('Condition'));
uBlock=unique(dataTable.('Block'));


set(handles.listbox_subjectID,'String',uSub);
set(handles.listbox_subjectID,'Value',1:length(uSub));
if(length(uSub)==1)
    set(handles.listbox_subjectID,'Enable','off');
    set(handles.checkbox_subjectID_plotby,'Enable','off');
    set(handles.checkbox_subjectID_plotby,'Value',0);
    ExFNIRS.settings.plotby.SubjectID=0;
end
set(handles.listbox_group,'String',uGroup);
set(handles.listbox_group,'Value',1:length(uGroup));
if(length(uGroup)==1)
    set(handles.listbox_group,'Enable','off');
    set(handles.checkbox_use_group,'Enable','off');
end
set(handles.listbox_subgroup,'String',uSubgroup);
set(handles.listbox_subgroup,'Value',1:length(uSubgroup));
if(length(uSubgroup)==1)
    set(handles.listbox_subgroup,'Enable','off');
    set(handles.checkbox_use_subgroup,'Enable','off');
    set(handles.checkbox_use_subgroup,'Value',0);
end

if(length(uGroup)==1&&length(uSubgroup)==1)
    set(handles.checkbox_group_plotby,'Enable','off');
    set(handles.checkbox_group_plotby,'Value',0);
    ExFNIRS.settings.plotby.Group=0;
elseif(length(uGroup)==1&&length(uSubgroup)>1)
    set(handles.checkbox_use_group,'Value',0);
    set(handles.checkbox_use_subgroup,'Value',1);
end

set(handles.listbox_session,'String',uSession);
set(handles.listbox_session,'Value',1:length(uSession));
if(length(uSession)==1)
    set(handles.listbox_session,'Enable','off');
    set(handles.checkbox_session_plotby,'Enable','off');
    set(handles.checkbox_session_plotby,'Value',0);
    ExFNIRS.settings.plotby.Session=0;
end
set(handles.listbox_trial,'String',uTrial);
set(handles.listbox_trial,'Value',1:length(uTrial));
if(length(uTrial)==1)
    set(handles.listbox_trial,'Enable','off');
    set(handles.checkbox_trial_plotby,'Enable','off');
    set(handles.checkbox_trial_plotby,'Value',0);
    ExFNIRS.settings.plotby.Trial=0;
end
set(handles.listbox_condition,'String',uCondition);
set(handles.listbox_condition,'Value',1:length(uCondition));
if(length(uCondition)==1)
    set(handles.listbox_condition,'Enable','off');
    set(handles.checkbox_condition_plotby,'Enable','off');
    set(handles.checkbox_condition_plotby,'Value',0);
    ExFNIRS.settings.plotby.Condition=0;
end
set(handles.listbox_block,'String',uBlock);
set(handles.listbox_block,'Value',1:length(uBlock));
if(length(uBlock)==1)
    set(handles.listbox_block,'Enable','off');
    set(handles.checkbox_block_plotby,'Enable','off');
    set(handles.checkbox_block_plotby,'Value',0);
    ExFNIRS.settings.plotby.Block=0;
end


curRawMethods=processFNIRS2_configureMethods('currentRawMethodsCallback',1,[],handles);
if(~isempty(curRawMethods))
   set(handles.listbox_raw_methods,'String',curRawMethods); 
end
curOxyMethods=processFNIRS2_configureMethods('currentOxyMethodsCallback',1,[],handles);
if(~isempty(curOxyMethods))
   set(handles.listbox_oxy_methods,'String',curOxyMethods); 
end

setExChannelMode('ROI',handles,true)%initialize ROI fields
setExChannelMode('fNIR',handles);



% --- Outputs from this function are returned to the command line.
function varargout = exploreFNIRS_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;




% --------------------------------------------------------------------
function initialize_gui(fig_handle, handles, isreset)
% If the metricdata field is present and the reset flag is false, it means
% we are we are just re-initializing a GUI by calling it from the cmd line
% while it is up. So, bail out as we dont want to reset the data.


% Update handles structure
guidata(handles.figure1, handles);


% --- Executes on selection change in listbox_subjectID.
function listbox_subjectID_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_subjectID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_subjectID contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_subjectID

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

function flagForUpdate(UpdateNeeded,handles)

global ExFNIRS


if(~isfield(ExFNIRS,'UpdateNeeded'))
   ExFNIRS.UpdateNeeded=3; 
end

if(UpdateNeeded>0)
    if(ExFNIRS.UpdateNeeded<UpdateNeeded)
        ExFNIRS.UpdateNeeded=UpdateNeeded; %2 indicates fNIRS data needs to be reprocessed as well
                                           % 3 indicates fNIRS must be
                                           % reprocessed entirely
    end
    set(handles.pushbutton_process_selection,'BackgroundColor','Red');
    updateSelectedTable(handles,false);
else
    ExFNIRS.UpdateNeeded=false;
    set(handles.pushbutton_process_selection,'BackgroundColor','Green');
end

% --- Executes during object creation, after setting all properties.
function listbox_subjectID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_subjectID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_group.
function listbox_group_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_group (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_group contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_group
global ExFNIRS
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end
% --- Executes during object creation, after setting all properties.
function listbox_group_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_group (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_session.
function listbox_session_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_session (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_session contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_session
global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function listbox_session_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_session (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_trial.
function listbox_trial_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_trial (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_trial contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_trial
global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function listbox_trial_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_trial (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_condition.
function listbox_condition_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_condition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_condition contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_condition
global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function listbox_condition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_condition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_group_select_all.
function pushbutton_group_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_group_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

if(ExFNIRS.settings.use_group)
    strs=get(handles.listbox_group,'String');
    if(iscell(strs)||ismatrix(strs))
        set(handles.listbox_group,'Value',[1:size(strs,1)]);
    end
else
    strs=get(handles.listbox_subgroup,'String');
    if(iscell(strs)||ismatrix(strs))
        set(handles.listbox_subgroup,'Value',[1:size(strs,1)]);
    end
end



if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in pushbutton_group_select_none.
function pushbutton_group_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_group_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS
if(ExFNIRS.settings.use_group)
    set(handles.listbox_group,'Value',[]);
else
    set(handles.listbox_subgroup,'Value',[]);
end
% --- Executes on button press in pushbutton_session_select_all.
function pushbutton_session_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_session_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_session,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_session,'Value',[1:size(strs,1)]);
end

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in pushbutton_session_select_none.
function pushbutton_session_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_session_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.listbox_session,'Value',[]);

% --- Executes on button press in pushbutton_trial_select_all.
function pushbutton_trial_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_trial_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_trial,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_trial,'Value',[1:size(strs,1)]);
end

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in pushbutton_trial_select_none.
function pushbutton_trial_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_trial_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.listbox_trial,'Value',[]);

% --- Executes on button press in pushbutton_condition_select_all.
function pushbutton_condition_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_condition_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_condition,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_condition,'Value',[1:size(strs,1)]);
end

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in pushbutton_condition_select_none.
function pushbutton_condition_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_condition_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.listbox_condition,'Value',[]);



% --- Executes on button press in pushbutton_subjectID_select_all.
function pushbutton_subjectID_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_subjectID_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_subjectID,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_subjectID,'Value',[1:size(strs,1)]);
end

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in pushbutton_subjectID_select_none.
function pushbutton_subjectID_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_subjectID_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.listbox_subjectID,'Value',[]);



function edit_baseline_start_Callback(hObject, eventdata, handles)
% hObject    handle to edit_baseline_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_baseline_start as text
%        str2double(get(hObject,'String')) returns contents of edit_baseline_start as a double

global ExFNIRS
ExFNIRS.settings.baseline_start=str2num(get(handles.edit_baseline_start,'String'));
set(handles.edit_baseline_start,'String',sprintf('%.2f',ExFNIRS.settings.baseline_start));

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(2,handles);
end


% --- Executes during object creation, after setting all properties.
function edit_baseline_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_baseline_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_baseline_end_Callback(hObject, eventdata, handles)
% hObject    handle to edit_baseline_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_baseline_end as text
%        str2double(get(hObject,'String')) returns contents of edit_baseline_end as a double
global ExFNIRS
ExFNIRS.settings.baseline_end=str2num(get(handles.edit_baseline_end,'String'));
set(handles.edit_baseline_end,'String',sprintf('%.2f',ExFNIRS.settings.baseline_end));

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(2,handles);
end

% --- Executes during object creation, after setting all properties.
function edit_baseline_end_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_baseline_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function edit_block_start_Callback(hObject, eventdata, handles)
% hObject    handle to edit_block_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_block_start as text
%        str2double(get(hObject,'String')) returns contents of edit_block_start as a double

global ExFNIRS
ExFNIRS.settings.block_start=str2num(get(handles.edit_block_start,'String'));
set(handles.edit_block_start,'String',sprintf('%.2f',ExFNIRS.settings.block_start));



% --- Executes during object creation, after setting all properties.
function edit_block_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_block_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_block_end_Callback(hObject, eventdata, handles)
% hObject    handle to edit_block_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_block_end as text
%        str2double(get(hObject,'String')) returns contents of edit_block_end as a double

global ExFNIRS
ExFNIRS.settings.block_end=str2num(get(handles.edit_block_end,'String'));
set(handles.edit_block_end,'String',sprintf('%.2f',ExFNIRS.settings.block_end));

% --- Executes during object creation, after setting all properties.
function edit_block_end_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_block_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_plot_start_Callback(hObject, eventdata, handles)
% hObject    handle to edit_plot_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_plot_start as text
%        str2double(get(hObject,'String')) returns contents of edit_plot_start as a double

global ExFNIRS
ExFNIRS.settings.plot_start=str2num(get(handles.edit_plot_start,'String'));
set(handles.edit_plot_start,'String',sprintf('%.2f',ExFNIRS.settings.plot_start));


% --- Executes during object creation, after setting all properties.
function edit_plot_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_plot_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_plot_end_Callback(hObject, eventdata, handles)
% hObject    handle to edit_plot_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_plot_end as text
%        str2double(get(hObject,'String')) returns contents of edit_plot_end as a double

global ExFNIRS
ExFNIRS.settings.plot_end=str2num(get(handles.edit_plot_end,'String'));
set(handles.edit_plot_end,'String',sprintf('%.2f',ExFNIRS.settings.plot_end));

% --- Executes during object creation, after setting all properties.
function edit_plot_end_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_plot_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_barchart_resample_size_Callback(hObject, eventdata, handles)
% hObject    handle to edit_barchart_resample_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_barchart_resample_size as text
%        str2double(get(hObject,'String')) returns contents of edit_barchart_resample_size as a double

global ExFNIRS
ExFNIRS.settings.barchart_resample_size=str2num(get(handles.edit_barchart_resample_size,'String'));
set(handles.edit_barchart_resample_size,'String',sprintf('%.2f',ExFNIRS.settings.barchart_resample_size));

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(2,handles);
end



% --- Executes during object creation, after setting all properties.
function edit_barchart_resample_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_barchart_resample_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on selection change in listbox_optode.
function listbox_optode_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_optode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_optode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_optode


% --- Executes during object creation, after setting all properties.
function listbox_optode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_optode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_optodes_select_all.
function pushbutton_optodes_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_optodes_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_optode,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_optode,'Value',[1:size(strs,1)]);
end

% --- Executes on button press in pushbutton_optodes_select_none.
function pushbutton_optodes_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_optodes_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.listbox_optode,'Value',[]);

% --- Executes on selection change in listbox_biomarker.
function listbox_biomarker_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_biomarker (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_biomarker contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_biomarker


% --- Executes during object creation, after setting all properties.
function listbox_biomarker_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_biomarker (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function updateSelectedTable(handles,processDataNow)

if(nargin<2)
    processDataNow=true;
else
    processDataNow=false;
end

global ExFNIRS

pf2_base.closeProgressHandles();

ExFNIRS.selectedTable=table();
ExFNIRS.selectedFNIR=cell(0);

strs=get(handles.listbox_subjectID,'String');
selectedStrs=get(handles.listbox_subjectID,'Value');
selectedSubs=strs(selectedStrs,:);
if(isnumeric(ExFNIRS.dataTable.('SubjectID')))
    selectedSubs=str2num(selectedSubs);
else
   if(~iscell(selectedSubs))
       selectedSubs={selectedSubs};
   end
   
   missingIdx=strcmp('Missing',selectedSubs);
   %selectedSubs(missingIdx)={''};
end
selSubIdx=ismember(ExFNIRS.dataTable.('SubjectID'),selectedSubs);

strs=get(handles.listbox_condition,'String');
selectedStrs=get(handles.listbox_condition,'Value');
selectedCondition=strs(selectedStrs,:);
if(isnumeric(ExFNIRS.dataTable.('Condition')))
    selectedCondition=str2num(selectedCondition);
else
   if(~iscell(selectedCondition))
       selectedCondition={selectedCondition};
   end
   
   missingIdx=strcmp('Missing',selectedCondition);
   %selectedCondition(missingIdx)={''};
end
selConditionIdx=ismember(ExFNIRS.dataTable.('Condition'),selectedCondition);

strs=get(handles.listbox_session,'String');
selectedStrs=get(handles.listbox_session,'Value');
selectedSession=strs(selectedStrs,:);
if(isnumeric(ExFNIRS.dataTable.('Session')))
    selectedSession=str2num(selectedSession);
else
   if(~iscell(selectedSession))
       selectedSession={selectedSession};
   end
   
   missingIdx=strcmp('Missing',selectedSession);
   %selectedSession(missingIdx)={''};
end
selSessionIdx=ismember(ExFNIRS.dataTable.('Session'),selectedSession);

strs=get(handles.listbox_block,'String');
selectedStrs=get(handles.listbox_block,'Value');
selectedBlock=strs(selectedStrs,:);
if(isnumeric(ExFNIRS.dataTable.('Block')))
    selectedBlock=str2num(selectedBlock);
else
   if(~iscell(selectedBlock))
       selectedBlock={selectedBlock};
   end
   
   missingIdx=strcmp('Missing',selectedBlock);
   %selectedBlock(missingIdx)={''};
end
selBlockIdx=ismember(ExFNIRS.dataTable.('Block'),selectedBlock);

if(ExFNIRS.settings.use_group)
    strs=get(handles.listbox_group,'String');
    selectedStrs=get(handles.listbox_group,'Value');
    selectedGroup=strs(selectedStrs,:);
    if(isnumeric(ExFNIRS.dataTable.('Group')))
        selectedGroup=str2num(selectedGroup);
    else
       if(~isempty(selectedGroup)&&~iscell(selectedGroup))
           selectedGroup={selectedGroup};
       end

       missingIdx=strcmp('Missing',selectedGroup);
       %selectedGroup(missingIdx)={''};
    end
    selGroupIdx=ismember(ExFNIRS.dataTable.('Group'),selectedGroup);
else
    strs=get(handles.listbox_subgroup,'String');
    selectedStrs=get(handles.listbox_subgroup,'Value');
    selectedGroup=strs(selectedStrs,:);
    if(isnumeric(ExFNIRS.dataTable.('Subgroup')))
        selectedGroup=str2num(selectedGroup);
    else
       if(~isempty(selectedGroup)&&~iscell(selectedGroup))
           selectedGroup={selectedGroup};
       end

       missingIdx=strcmp('Missing',selectedGroup);
       %selectedGroup(missingIdx)={''};
    end
    selGroupIdx=ismember(ExFNIRS.dataTable.('Subgroup'),selectedGroup);
end

strs=get(handles.listbox_trial,'String');
selectedStrs=get(handles.listbox_trial,'Value');
selectedTrial=strs(selectedStrs,:);
if(isnumeric(ExFNIRS.dataTable.('Trial')))
    selectedTrial=str2num(selectedTrial);
else
   if(~iscell(selectedTrial))
       selectedTrial={selectedTrial};
   end
   
   missingIdx=strcmp('Missing',selectedTrial);
   selectedTrial(missingIdx)={''};
end
selTrialIdx=ismember(ExFNIRS.dataTable.('Trial'),selectedTrial);

if(ExFNIRS.settings.use_info)
    cInfoGBYstring=ExFNIRS.settings.curInfoGroupBy;
    strs=get(handles.listbox_info_groupby,'String');
    selectedStrs=get(handles.listbox_info_groupby,'Value');
    selectedInfoG=strs(selectedStrs,:);
    if(isnumeric(ExFNIRS.dataTable{1,cInfoGBYstring}))
        tblStrs=num2str(ExFNIRS.dataTable{:,cInfoGBYstring},'%.2f');
        if(~iscell(selectedInfoG))
            selectedInfoG={selectedInfoG};
        end
        selInfoGIdx=ismember(tblStrs,selectedInfoG);
    else
        selInfoGIdx=ismember(ExFNIRS.dataTable.(cInfoGBYstring),selectedInfoG);
    end
end

sellFullIdx=selSubIdx&selConditionIdx&selSessionIdx&selBlockIdx&selGroupIdx&selTrialIdx;

if(ExFNIRS.settings.use_info)
    sellFullIdx=sellFullIdx&selInfoGIdx;
end

if(~any(sellFullIdx))
    statusTextStr='No data matching selection';
    ExFNIRS.statusGroupByStr='Ungrouped';
    set(handles.text_status_text,'String',statusTextStr);
    set(handles.text_status,'String','0 Segments in\n0 Group(s)');
    set(handles.popupmenu_info_group,'String',{''});
    return
end

ExFNIRS.selectedTable=ExFNIRS.dataTable(sellFullIdx,:);



subColIdx=find(strcmp('SubjectID',ExFNIRS.dataTable.Properties.VariableNames));
groupColIdx=find(strcmp('Group',ExFNIRS.dataTable.Properties.VariableNames));
subgroupColIdx=find(strcmp('Subgroup',ExFNIRS.dataTable.Properties.VariableNames));
sessionColIdx=find(strcmp('Session',ExFNIRS.dataTable.Properties.VariableNames));
conditionColIdx=find(strcmp('Condition',ExFNIRS.dataTable.Properties.VariableNames));
trialColIdx=find(strcmp('Trial',ExFNIRS.dataTable.Properties.VariableNames));
blockColIdx=find(strcmp('Block',ExFNIRS.dataTable.Properties.VariableNames));

if(ExFNIRS.settings.use_group)
    gPlotByGroup=[ExFNIRS.settings.plotby.Group,0];
else
    gPlotByGroup=[0,ExFNIRS.settings.plotby.Group];
end

groubbyIdxEnable=[ExFNIRS.settings.plotby.SubjectID,ExFNIRS.settings.plotby.Group&&ExFNIRS.settings.use_group,ExFNIRS.settings.plotby.Group&&~ExFNIRS.settings.use_group,...
    ExFNIRS.settings.plotby.Session,ExFNIRS.settings.plotby.Condition,ExFNIRS.settings.plotby.Trial,ExFNIRS.settings.plotby.Block];
groupbyIdx=[subColIdx,groupColIdx,subgroupColIdx,sessionColIdx,conditionColIdx,trialColIdx,blockColIdx].*groubbyIdxEnable;
groupbyIdx=groupbyIdx(groupbyIdx>0);

if(ExFNIRS.settings.plotby.InfoGroupBy)
    groupbyIdx=[groupbyIdx,find(strcmp(cInfoGBYstring,ExFNIRS.dataTable.Properties.VariableNames))];
end

[groupbyRows,ia,gbyIdx]=unique(ExFNIRS.selectedTable(:,groupbyIdx));

processMinTime=min([ExFNIRS.settings.baseline_start,ExFNIRS.settings.block_start,ExFNIRS.settings.plot_start]);
processMaxTime=max([ExFNIRS.settings.baseline_end,ExFNIRS.settings.block_end,ExFNIRS.settings.plot_end]);

if(isfield(ExFNIRS,'gby'))
    rmfield(ExFNIRS,'gby');
end
ExFNIRS.gby=[];
ExFNIRS.groupByVars=groupbyRows.Properties.VariableNames;

statusTextStr='Grouping data by ';
ExFNIRS.statusGroupByStr='';
for i=1:length(ExFNIRS.groupByVars)
    statusTextStr=sprintf('%s %s X ', statusTextStr,ExFNIRS.groupByVars{i});
    if(i==1)
        ExFNIRS.statusGroupByStr=ExFNIRS.groupByVars{i};
    else
        ExFNIRS.statusGroupByStr=sprintf('%s X ', ExFNIRS.statusGroupByStr,ExFNIRS.groupByVars{i});
    end
end

statusTextStr(end-2:end)=[];
ExFNIRS.statusGroupByStr(end-2:end)=[];


if(isempty(ExFNIRS.groupByVars))
    statusTextStr='Data is ungrouped';
    ExFNIRS.statusGroupByStr='Ungrouped';
end


set(handles.text_status_text,'String',statusTextStr);

updateInfoGroupByVars(handles);

set(handles.text_status,'String',sprintf('%i Observations in\n%i Group(s)',size(ExFNIRS.selectedTable,1),max(gbyIdx)));



if(processDataNow)
    processCurrentFunction(handles);
    
    if(~isfield(ExFNIRS,'curProcessedData')||isempty(ExFNIRS.curProcessedData))
       flagForUpdate(3,handles);
       error('No processed data yet!'); 
    end

    ExFNIRS.selectedFNIR=ExFNIRS.curProcessedData(sellFullIdx,:);
    
    
    preprocessFNIRSData();
    processSelectedTable(handles,sellFullIdx,gbyIdx);
end

function preprocessFNIRSData()
global ExFNIRS
if(ExFNIRS.UpdateNeeded==2||~isfield(ExFNIRS,'curPreprocessedFNIR'))
    
    pf2_base.closeProgressHandles();

     numSegs2Process=size(ExFNIRS.curProcessedData,1);

    global ProgressHandles
    ProgressHandles.h.hF=waitbar(0,sprintf('ExploreFNIRS\nResampling and baselining fNIRS %i of %i',1,numSegs2Process));
    hF=ProgressHandles.h.hF;

   
    ExFNIRS.curPreprocessedFNIR=[];
    ExFNIRS.curPreprocessedFNIR.fNIR=ExFNIRS.curProcessedData;
    ExFNIRS.curPreprocessedFNIR.baseline=cell(size(ExFNIRS.curProcessedData));
    ExFNIRS.curPreprocessedFNIR.gbyFNIRS=ExFNIRS.curProcessedData;
    ExFNIRS.curPreprocessedFNIR.gbyFNIRS_blk=cell(size(ExFNIRS.curProcessedData));

    for i=1:numSegs2Process
        
       try
            waitbar(i/numSegs2Process,hF,sprintf('ExploreFNIRS\nResampling and baselining fNIRS %i of %i',i,numSegs2Process));
       catch

       end
        ExFNIRS.curPreprocessedFNIR.baseline{i}=processFNIRS2.Data.Split(ExFNIRS.curPreprocessedFNIR.fNIR{i},ExFNIRS.settings.baseline_start,ExFNIRS.settings.baseline_end); %baselineining is handled in processing section
        ExFNIRS.curPreprocessedFNIR.gbyFNIRS{i}.time=ExFNIRS.curPreprocessedFNIR.gbyFNIRS{i}.time-ExFNIRS.settings.block_start; %change time so that 0 is start of block
        ExFNIRS.curPreprocessedFNIR.gbyFNIRS_blk{i}=processFNIRS2.Data.Resample(ExFNIRS.curPreprocessedFNIR.gbyFNIRS{i}, ExFNIRS.settings.barchart_resample_size,'centerOnT0',true,'timeOutMode','start','blfNIR',ExFNIRS.curPreprocessedFNIR.baseline{i},'averageAux',true);
        
        ExFNIRS.curPreprocessedFNIR.gbyFNIRS{i}=processFNIRS2.Data.Resample(ExFNIRS.curPreprocessedFNIR.gbyFNIRS{i}, ExFNIRS.settings.grandavg_resample_size,'centerOnT0',true,'timeOutMode','start','blfNIR',ExFNIRS.curPreprocessedFNIR.baseline{i},'averageAux',true);
    end

    try
        close(hF);
    catch
    
end
else

    ExFNIRS.UpdateNeeded=true; % mark that data was preprocesed
end

function processSelectedTable(handles,sellFullIdx,gbyIdx)
global ExFNIRS
pf2_base.closeProgressHandles();


global ProgressHandles
ProgressHandles.h.hF=waitbar(0,sprintf('ExploreFNIRS\nProcessing Group %i of %i',1,max(gbyIdx)));
hF=ProgressHandles.h.hF;

numSegs2Process=size(ExFNIRS.selectedTable,1);

ExFNIRS.gbyFlat=[];
ExFNIRS.gbyFlat.fNIR=ExFNIRS.curPreprocessedFNIR.fNIR(sellFullIdx,:);
ExFNIRS.gbyFlat.baseline=ExFNIRS.curPreprocessedFNIR.baseline(sellFullIdx,:);
ExFNIRS.gbyFlat.gbyFNIRS=ExFNIRS.curPreprocessedFNIR.gbyFNIRS(sellFullIdx,:);
ExFNIRS.gbyFlat.gbyFNIRS_blk=ExFNIRS.curPreprocessedFNIR.gbyFNIRS_blk(sellFullIdx,:);
ExFNIRS.gbyFlat.gbyIndex=gbyIdx;


for i=1:max(gbyIdx)
    try
        waitbar(i/max(gbyIdx),hF,sprintf('ExploreFNIRS\nProcessing Group %i of %i',i,max(gbyIdx)));
    catch
        
    end
    ExFNIRS.gby(i).gbyTables=ExFNIRS.selectedTable(gbyIdx==i,:); 
    ExFNIRS.gby(i).gbyFNIRS=ExFNIRS.gbyFlat.gbyFNIRS(gbyIdx==i,:);
    ExFNIRS.gby(i).gbyFNIRS_blk=ExFNIRS.gbyFlat.gbyFNIRS_blk(gbyIdx==i,:);
    
    
    if(ExFNIRS.settings.within_sub_avg_mode==1)
       hArg=[]; 
       ExFNIRS.settings.within_sub_avg_mode_label='None';
    elseif(ExFNIRS.settings.within_sub_avg_mode==2)
        hArg=ExFNIRS.gby(i).gbyTables(:,'SubjectID');
        ExFNIRS.settings.within_sub_avg_mode_label='Flat';
    elseif(ExFNIRS.settings.within_sub_avg_mode==3)
        hArg=ExFNIRS.gby(i).gbyTables(:,ExFNIRS.dataHierarchy);
        ExFNIRS.settings.within_sub_avg_mode_label='Hierarchy';
    end
    ExFNIRS.gby(i).gbyGrand=grandAvgFNIRS(ExFNIRS.gby(i).gbyFNIRS,false,[],false,hArg,false,false);
    ExFNIRS.gby(i).gbyGrandBar=grandAvgFNIRS(ExFNIRS.gby(i).gbyFNIRS_blk,false, ExFNIRS.settings.barchart_resample_size,true,hArg,false,true);
    ExFNIRS.gby(i).gbyGrandBarFlat=grandAvgFNIRS(ExFNIRS.gby(i).gbyFNIRS_blk,false, ExFNIRS.settings.barchart_resample_size,true,ExFNIRS.gby(i).gbyTables(:,'SubjectID'),false,true);
    try
        close(eHf);
    catch
    end
end

set(handles.text_status,'String',sprintf('%i Segments in\n%i Group(s)',numSegs2Process,max(gbyIdx)));
try
    close(hF);
catch
    
end


flagForUpdate(false,handles);


function updateInfoGroupByVars(handles)
global ExFNIRS

plotInfoVars=cell(length(ExFNIRS.groupByVars)+1,1);
plotInfoVars{1}='';
plotInfoVars(2:end,1)=ExFNIRS.groupByVars;
set(handles.popupmenu_info_group,'String',plotInfoVars);


[a,b]=ismember(ExFNIRS.settings.curInfoGroup,plotInfoVars);

if(a==1)
   set(handles.popupmenu_info_group,'Value',b);
else
    set(handles.popupmenu_info_group,'Value',1);
end

function processCurrentFunction(handles)

global ExFNIRS

if(ExFNIRS.UpdateNeeded==4)
    error('Dataset has been updated, please close and repoen ExFNIRS');
end

if(ExFNIRS.UpdateNeeded==3)

strsRaw=get(handles.listbox_raw_methods,'String');
selectedStrs=get(handles.listbox_raw_methods,'Value');
cur_raw_method=strsRaw(selectedStrs,:);

strsOxy=get(handles.listbox_oxy_methods,'String');
selectedStrs=get(handles.listbox_oxy_methods,'Value');
cur_oxy_method=strsOxy(selectedStrs,:);

if(~isfield(ExFNIRS,'processedData'))
    ExFNIRS.processedData=cell(length(strsOxy)*length(strsRaw),3);
    ExFNIRS.numProcessed=0;
end

if(ExFNIRS.settings.processRaw)
    exploreFNIRS.processMethods(cur_raw_method,cur_oxy_method);
else
    exploreFNIRS.processMethods([],cur_oxy_method);
end

[strsOxy,iOxy]=processFNIRS2.Methods.Oxy();
[strsRaw,iRaw]=processFNIRS2.Methods.Raw();

set(handles.listbox_oxy_methods,'String',strsOxy);
set(handles.listbox_oxy_methods,'Value',find(iOxy));
set(handles.listbox_raw_methods,'String',strsRaw);
set(handles.listbox_raw_methods,'Value',find(iRaw));

ExFNIRS.UpdateNeeded=2;

end

% --- Executes on button press in pushbutton_biomarker_select_all.
function pushbutton_biomarker_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_biomarker_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_biomarker,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_biomarker,'Value',[1:size(strs,1)]);
end

% --- Executes on button press in pushbutton_biomarker_select_none.
function pushbutton_biomarker_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_biomarker_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.listbox_biomarker,'Value',[]);


% --- Executes on selection change in listbox_raw_methods.
function listbox_raw_methods_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_raw_methods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_raw_methods contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_raw_methods
global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end

% --- Executes during object creation, after setting all properties.
function listbox_raw_methods_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_raw_methods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_oxy_methods.
function listbox_oxy_methods_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_oxy_methods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_oxy_methods contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_oxy_methods
global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end


% --- Executes during object creation, after setting all properties.
function listbox_oxy_methods_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_oxy_methods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_plot_temporal.
function pushbutton_plot_temporal_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_plot_temporal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

if(ExFNIRS.UpdateNeeded)
    updateSelectedTable(handles);
end

if(~isfield(ExFNIRS,'gby'))
    warning('No groups match selection criteria');
    return;
end
curInfoGroup=ExFNIRS.settings.curInfoGroup;

gbyVars=ExFNIRS.groupByVars;
if(~isempty(curInfoGroup)&&~strcmp(curInfoGroup,'(Time)'))
    [ismem,idx]=ismember(curInfoGroup,gbyVars);
    if(ismem)
        gbyVars(idx)=[];
        useCurInfoGroup=true;
    else
        useCurInfoGroup=false;
    end
else
    useCurInfoGroup=false;
end


numGroups=length(ExFNIRS.gby);

biomStrs=get(handles.listbox_biomarker,'String');
selBioM=get(handles.listbox_biomarker,'Value');
selectedBioM=biomStrs(selBioM);
numBioM=length(selBioM);

optStrs=get(handles.listbox_optode,'String');
selOpt=get(handles.listbox_optode,'Value');
selectedOptStr=optStrs(selOpt',:);
%selectedOpt=str2num(selectedOpt);
selectedOpt=selOpt;
numOpt=length(selectedOpt);

if(numOpt==0||numGroups==0||numBioM==0)
    return;
end

if(ExFNIRS.settings.ylim_fixed)
    ExFNIRS.settings.ylim_fixed_min=inf;
    ExFNIRS.settings.ylim_fixed_max=-inf;
end

curInfoGby=cell(0);

for g=1:numGroups
    gbyStrs{g}='';
   if(~isempty(ExFNIRS.gby(g).gbyTables))
       for i=1:length(gbyVars)
           gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(ExFNIRS.gby(g).gbyTables.(gbyVars{i})(1)));
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(ExFNIRS.gby(g).gbyTables.(curInfoGroup)(1));
       end
   end 
   if(~isempty(gbyStrs{g}))
        gbyStrs{g}(end)='';
   end
end

[uCurInfoG,firstCurIdx,uCurIdx]=unique(cellstr(curInfoGby));

numCurInfoG=length(uCurInfoG);

numUgroups=length(unique(cellstr(gbyStrs)));

uCurGIdxCount=nan(size(uCurIdx));
for i =1:numCurInfoG
    uCurGIdxCount(uCurIdx==i)=1:sum(uCurIdx==i);
end

if(numUgroups==1)
    num2Plot=numBioM;
    plotGroupByBioM=true;
    bioColorTable=table2cell(pf2_base.getBioColors());
    cIndex=[];
    for i=1:length(bioColorTable)
        cIndex(i,:)=bioColorTable{i};
    end
else
    num2Plot=numUgroups;
    plotGroupByBioM=false;
    if(ExFNIRS.settings.use_gui_color)
        cIndex=ExFNIRS.settings.guiColor(1:numUgroups,:);
    else
        cIndex=ExFNIRS.settings.cmap(numUgroups);%linspecer(num2Plot,'qualitative');
    end
end


errorFeature=ExFNIRS.settings.plot_error_feature;
errMulitply=ExFNIRS.settings.plot_error_multiply;
plotFeature=ExFNIRS.settings.plot_grandaverage_feature;

if(strcmp(plotFeature,'Count')&&ExFNIRS.settings.plot_grandaverage)
  plotFeature='N';
  plotCount=true;
else
    plotCount=false;
end


if(~plotGroupByBioM)
    if(numOpt>1&&numCurInfoG>1)
        xType='channels';
        yType='groupby';
        figType='bioM';
        numSubX=numOpt;
        numSubY=numCurInfoG;
    elseif(numOpt==1&&numCurInfoG>1)
        xType='bioM';
        yType='groupby';
        figType='';
        numSubX=numBioM;
        numSubY=numCurInfoG;
    elseif(numCurInfoG<=1&&numOpt>1)
        xType='channels';
        yType='bioM';
        figType='';
        numSubX=numOpt;
        numSubY=numBioM;
    else
        xType='bioM';
        yType='';
        figType='';
        numSubX=numBioM;
        numSubY=1;
    end
else %plot with biomarkers embedded
    if(numOpt>=1&&numCurInfoG>1)
        xType='channels';
        yType='groupby';
        figType='';
        numSubX=numOpt;
        numSubY=numCurInfoG;
    elseif(numCurInfoG<=1&&numOpt>1)
        xType='channels';
        yType='';
        figType='';
        numSubX=numOpt;
        numSubY=1;
    else
        xType='';
        yType='';
        figType='';
        numSubX=1;
        numSubY=1;
    end
end



switch(figType)
    case 'bioM'
        for i=1:numBioM
            sH{i,1}.h=figure(900+i);
            clf(sH{i,1}.h);
            dcm_obj = datacursormode(sH{i,1}.h);
            set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
            for s=1:(numSubX*numSubY)
                xInd=rem(s,numSubX);
                if(xInd==0)
                    xInd=numSubX;
                end
                h=subplot(numSubY,numSubX,s);
                if(ExFNIRS.settings.plot_temporal_y0)
                    yh=plot([ExFNIRS.settings.plot_start-ExFNIRS.settings.block_start,ExFNIRS.settings.plot_end-ExFNIRS.settings.block_start],[0,0],'k');
                    set(yh,'HandleVisibility','off');
                end
                sH{i,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                legend(h, 'off');
            end
            multiPlot=true;
        end
    otherwise
        sH{1,1}.h=figure(900);
        clf(sH{1,1}.h);
        dcm_obj = datacursormode(sH{1,1}.h);
        set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
        for s=1:(numSubX*numSubY)
            xInd=rem(s,numSubX);
            if(xInd==0)
                xInd=numSubX;
            end
            h=subplot(numSubY,numSubX,s);
            if(ExFNIRS.settings.plot_temporal_y0)
                yh=plot([ExFNIRS.settings.plot_start-ExFNIRS.settings.block_start,ExFNIRS.settings.plot_end-ExFNIRS.settings.block_start],[0,0],'k');
                set(yh,'HandleVisibility','off');
            end
            sH{1,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
            legend(h, 'off');
        end
        multiPlot=false;
end

curSx=1;
curSy=1;
curFigIdx=[1,1];

for chIdx=1:numOpt
    ch=selectedOpt(chIdx);
    gStrs=cell(num2Plot,1);
    for b=1:numBioM
        bioM=selectedBioM(b);
        if(iscell(bioM))
            bioM=bioM{1};
        end
        
        if(~plotGroupByBioM)
            gStrs=cell(num2Plot,1);
        end
        
        hGrandErr1=cell(num2Plot,1);
        hGrandErr2=cell(num2Plot,1);
        
        for g=1:numGroups
            if(useCurInfoGroup)
                curGroupInfoIdx=uCurIdx(g);
                curUgroupIdx=uCurGIdxCount(g);
            else
                curGroupInfoIdx=1;
                curUgroupIdx=g;
            end
            
            
            if(strcmp(figType,'bioM'))
                curFigH=sH{b,1};
            else
               curFigH=sH{1,1}; 
            end
            
            switch(xType)
                case 'channels'
                    curSx=chIdx;
                case 'bioM'
                    curSx=b;
                case 'groupby'
                    curSx=curGroupInfoIdx;
            end
                
            switch(yType)
                case 'channels'
                    curSy=chIdx;
                case 'bioM'
                    curSy=b;
                case 'groupby'
                    curSy=curGroupInfoIdx;
            end
            
            if(curSy==numSubY&&curSx==numSubX)
                lastSubplot=true;
            else
                lastSubplot=false;
            end
            
            curFNIRS=ExFNIRS.gby(g).gbyFNIRS;
            curGrand=ExFNIRS.gby(g).gbyGrand;
            
            
            hold(curFigH.subH{curSy,curSx},'on');
            if(ExFNIRS.settings.plot_individual&&~plotCount)
               for i=1:length(curFNIRS)
                   if(~isfield(curFNIRS{i},'HbO'))
                       continue;
                   end
                   if(~isfield(curFigH,'legendHandles'))
                       if(plotGroupByBioM)
                            curFigH.legendHandles{curSy,curSx}.h=cell(numBioM,1);
                       else
                           curFigH.legendHandles{curSy,curSx}.h=cell(numUgroups,1);
                       end
                   end
                   
                   switch ExFNIRS.settings.ChannelMode
                       case 'fNIR'
                           data2plot=curFNIRS{i};
                       case 'ROI'
                           if(~pf2_base.isnestedfield(curGrand,'ROI.HbO.data'))
                              error('ROI data must be calculated using a build ROI step');
                           end
                          if(~isempty(curFNIRS{i})&&isfield(curFNIRS{i},'ROI'))
                           data2plot=curFNIRS{i}.ROI;
                          else
                             data2plot=[]; 
                          end
                          
                       case 'Aux'
                           
                   end
                   
                  if(plotGroupByBioM)
                      if(~isempty(data2plot))
                          h=plot(curFigH.subH{curSy,curSx},curFNIRS{i}.time,data2plot.(bioM)(:,ch),'color',cIndex(b,:));
                          set(h,'Tag',getFormattedTrialString(curFNIRS{i}));
                          if(ExFNIRS.settings.plot_grandaverage||~isempty(curFigH.legendHandles{curSy,curSx}.h{b}))
                            set(h.Annotation.LegendInformation,'IconDisplayStyle','off'); 
                          end
                          gStrs{b}=selectedBioM{b};
                          curFigH.legendHandles{curSy,curSx}.h{b}=h;
                      end
                  else
                      if(~isempty(data2plot.(bioM))&&isfield(data2plot,bioM))
                      h=plot(curFigH.subH{curSy,curSx},curFNIRS{i}.time,data2plot.(bioM)(:,ch),'color',cIndex(curUgroupIdx,:));
                      set(h,'Tag',getFormattedTrialString(curFNIRS{i}));
                      if(ExFNIRS.settings.plot_grandaverage||~isempty(curFigH.legendHandles{curSy,curSx}.h{curUgroupIdx}))
                          if(~isempty(h))
                             set(h.Annotation.LegendInformation,'IconDisplayStyle','off'); 
                          end
                      end
                      gStrs{curUgroupIdx}=gbyStrs{g}; 
                      curFigH.legendHandles{curSy,curSx}.h{curUgroupIdx}=h;
                      end
                  end
                  
                  
                  
                  hold on;
               end
            end

            if(ExFNIRS.settings.plot_grandaverage)
                  switch(ExFNIRS.settings.ChannelMode)
                      case 'fNIR'
                          data2plot=curGrand.(bioM);
                      case 'ROI'
                          if(~pf2_base.isnestedfield(curGrand,'ROI.HbO.data'))
                              warning('ROI data must be calculated using a build ROI step');
                              data2plot=[];
                          else
                            data2plot=curGrand.ROI.(bioM);
                          end
                      case 'Aux'
           
                  end
                  
                  
                  if(~isempty(data2plot))
                      if(plotGroupByBioM)
                          hGrand=plot(curFigH.subH{curSy,curSx},curGrand.time,data2plot.(plotFeature)(:,ch),'LineWidth',3,'color',cIndex(b,:));
                      else
                          hGrand=plot(curFigH.subH{curSy,curSx},curGrand.time,data2plot.(plotFeature)(:,ch),'LineWidth',3,'color',cIndex(curUgroupIdx,:));
                      end

                      if(numUgroups>1||numBioM==1)&&~isempty(gbyStrs{g})
                           gStrs{curUgroupIdx}=gbyStrs{g}; 
                           set(hGrand,'Tag',sprintf('%s: %s',plotFeature,gStrs{curUgroupIdx}));
                           curFigH.legendHandles{curSy,curSx}.hG{curUgroupIdx}=hGrand;
                      elseif(~multiPlot)
                           gStrs{b}=selectedBioM{b};
                           set(hGrand,'Tag',sprintf('%s: %s',plotFeature,gStrs{b}));
                           curFigH.legendHandles{curSy,curSx}.hG{b}=hGrand;
                      end
                  end
                  
                  
            end
            
            if(ExFNIRS.settings.plot_error&&~plotCount)
                errStyle=ExFNIRS.settings.plot_error_style;
                plotShaded=false;
                
                switch(errStyle)
                    case 'Dashed'
                        errStyle='--';
                        lineWidth=2;
                    case 'Fine'
                        errStyle='-';
                        lineWidth=0.5;
                    case 'Shaded'
                        errStyle='-';
                        lineWidth=0.5;
                        plotShaded=true;
                    otherwise
                        error('Unspecified error style');
                end
                     
                if(plotGroupByBioM)
                    errColor=cIndex(b,:);
                    errColor=errColor+(1-errColor)*0.55;
                else
                    errColor=cIndex(curUgroupIdx,:);
                    errColor=errColor+(1-errColor)*0.55;
                end
                
                switch ExFNIRS.settings.ChannelMode
                    case 'fNIR'
                        data2plot=curGrand.(bioM);
                    case 'ROI'
                        if(pf2_base.isnestedfield(curGrand,'ROI.HbO'))
                        data2plot=curGrand.ROI.(bioM);
                        else
                           data2plot=[]; 
                        end
                    case 'Aux'
                end
                
                if(~isempty(data2plot))
                    if(strcmp(errorFeature,'MaxMin'))
                      upperError=data2plot.Max(:,ch);
                      lowerError=data2plot.Min(:,ch);
                    else
                      upperError=data2plot.(plotFeature)(:,ch)+data2plot.(errorFeature)(:,ch)*errMulitply;
                      lowerError=data2plot.(plotFeature)(:,ch)-data2plot.(errorFeature)(:,ch)*errMulitply;
                    end


                    if(plotShaded)
                          errAlpha=0.15;
                          yPatch=[lowerError',fliplr(upperError')];
                          xPatch=[curGrand.time',fliplr(curGrand.time')];
                          xPatch(isnan(yPatch))=[];
                          yPatch(isnan(yPatch))=[];

                          hPatch=patch(curFigH.subH{curSy,curSx},xPatch,yPatch,-1,'facecolor',errColor,'edgecolor','none','facealpha',errAlpha);
                          if(~isempty(hPatch))
                              set(hPatch,'HitTest','off');
                              set(hPatch,'HandleVisibility','off');

                              set(hPatch.Annotation.LegendInformation,'IconDisplayStyle','off'); 
                          end
                    end

                    if(plotGroupByBioM)
                          hGrandErr1{b}=plot(curFigH.subH{curSy,curSx},curGrand.time,upperError,'lineStyle',errStyle,'LineWidth',lineWidth,'color',errColor);
                          hGrandErr2{b}=plot(curFigH.subH{curSy,curSx},curGrand.time,lowerError,'lineStyle',errStyle,'LineWidth',lineWidth,'color',errColor);
                          set(hGrandErr1{b}.Annotation.LegendInformation,'IconDisplayStyle','off'); 
                          set(hGrandErr2{b}.Annotation.LegendInformation,'IconDisplayStyle','off');
                          curFigH.legendHandles{curSy,curSx}.hE{b}=hGrandErr1{b};
                    else
                          hGrandErr1{g}=plot(curFigH.subH{curSy,curSx},curGrand.time,upperError,'lineStyle',errStyle,'LineWidth',lineWidth,'color',errColor);
                          hGrandErr2{g}=plot(curFigH.subH{curSy,curSx},curGrand.time,lowerError,'lineStyle',errStyle,'LineWidth',lineWidth,'color',errColor);
                          set(hGrandErr1{g}.Annotation.LegendInformation,'IconDisplayStyle','off'); 
                          set(hGrandErr2{g}.Annotation.LegendInformation,'IconDisplayStyle','off'); 
                          curFigH.legendHandles{curSy,curSx}.hE{g}=hGrandErr1{g};
                    end



                    if(~plotGroupByBioM)
                       gAerrStrs{g}=sprintf('%s: %s',errorFeature,gbyStrs{g}); 
                       set(hGrandErr1{g},'Tag',gAerrStrs{g});
                       set(hGrandErr2{g},'Tag',gAerrStrs{g});
                    else
                       gAerrStrs{b}=sprintf('%s: %s',errorFeature,selectedBioM{b}); 
                       set(hGrandErr1{b},'Tag',gAerrStrs{b});
                       set(hGrandErr2{b},'Tag',gAerrStrs{b});
                    end
                end
            end
            
            switch ExFNIRS.settings.ChannelMode
                case 'fNIR'
                    chNamePart=sprintf('Opt. %i',ch);
                    chNamePartLong=sprintf('Optode %i',ch);
                case 'ROI'
                    chNamePart=selectedOptStr{chIdx};
                    chNamePartLong=sprintf('ROI: %s',selectedOptStr{chIdx});
                case 'Aux'
            end
            
            if(~plotGroupByBioM) 
                ylbl=sprintf('\\Delta[%s] (\\muM)',bioM);
                if(plotCount)
                    ylbl=(sprintf('N %s',ylbl));
                end
                if(ExFNIRS.settings.plot_error)
                    ylbl=(sprintf('%s (%s)',ylbl,ExFNIRS.settings.plot_error_feature));
                end
                ylbl=(sprintf('%s %s',chNamePart,ylbl));
            elseif(plotGroupByBioM)
                ylbl=sprintf('\\Delta[X] (\\muM)');
                if(plotCount)
                    ylbl=(sprintf('N %s',ylbl));
                end
                if(ExFNIRS.settings.plot_error)
                    ylbl=(sprintf('%s (%s)',ylbl,ExFNIRS.settings.plot_error_feature));
                end
                ylbl=(sprintf('%s %s',chNamePart,ylbl));
                
                
            end
            
            switch(xType)
                case 'channels'
                    title(curFigH.subH{curSy,curSx},chNamePartLong);
                case 'bioM'
                    title(curFigH.subH{curSy,curSx},bioM);
                case 'groupby'
                    title(curFigH.subH{curSy,curSx},uCurInfoG{curGroupInfoIdx});
                otherwise 
            end
            
            switch(yType)
                case 'channels'
                    ylbl={chNamePartLong;ylbl};
                case 'bioM'
                    ylbl={bioM;ylbl};
                case 'groupby'
                    ylbl={uCurInfoG{curGroupInfoIdx};ylbl};
                otherwise 
            end
            ylabel(curFigH.subH{curSy,curSx},ylbl);
            
        if(ExFNIRS.settings.ylim_fixed)
            xlim(curFigH.subH{curSy,curSx},[ExFNIRS.settings.plot_start-ExFNIRS.settings.block_start,ExFNIRS.settings.plot_end-ExFNIRS.settings.block_start]);
            ylim(curFigH.subH{curSy,curSx},'auto');
            cylim=ylim(curFigH.subH{curSy,curSx});
            ExFNIRS.settings.ylim_fixed_min=min(ExFNIRS.settings.ylim_fixed_min,cylim(1));
            ExFNIRS.settings.ylim_fixed_max=max(ExFNIRS.settings.ylim_fixed_max,cylim(2));
        elseif(ExFNIRS.settings.ylim_manual&&~plotCount)
            ylim(curFigH.subH{curSy,curSx},[ExFNIRS.settings.ylim_manual_min,ExFNIRS.settings.ylim_manual_max]);
        else
            ylim(curFigH.subH{curSy,curSx},'auto');
        end

        curYlim=ylim(curFigH.subH{curSy,curSx});
        if(plotCount)
            ExFNIRS.settings.ylim_fixed_min=0;
            ylim(curFigH.subH{curSy,curSx},[0,curYlim(2)]);
        end


        end
        

    end
end

if(plotCount)
    ExFNIRS.settings.ylim_fixed_min=0;
end


for i=1:size(sH,1)
    for b=1:size(sH,2)
        for x=1:numSubX
            for y=1:numSubY
                xlabel(sH{i,b}.subH{y,x},'Time (s)');
                xlim(sH{i,b}.subH{y,x},[ExFNIRS.settings.plot_start-ExFNIRS.settings.block_start,ExFNIRS.settings.plot_end-ExFNIRS.settings.block_start]);
                
                if(ExFNIRS.settings.ylim_fixed)
                    ylim(sH{i,b}.subH{y,x},[ExFNIRS.settings.ylim_fixed_min,ExFNIRS.settings.ylim_fixed_max]);
                end

                if(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&(x==numSubX&&y==numSubY)))
                    if(ExFNIRS.settings.plot_grandaverage)
                        curHandles=curFigH.legendHandles{curSy,curSx}.hG;
                    elseif(ExFNIRS.settings.plot_individual)
                        curHandles=curFigH.legendHandles{curSy,curSx}.h;
                    elseif(ExFNIRS.settings.plot_error)
                        curHandles=curFigH.legendHandles{curSy,curSx}.hE;
                    end
                    legendGFXstrs=cell(0);
                    for h=1:length(curHandles)
                       if(~isempty(gStrs{h}))
                           %set(curHandles{h}.Annotation.LegendInformation,'IconDisplayStyle','on'); 
                           legendGFXstrs(h)=gStrs(h);
                       else

                       end
                    end
                    legend(sH{i,b}.subH{y,x},legendGFXstrs(:)');
                end

                if(ExFNIRS.settings.plot_task_lines)
                    pf2_base.external.vline(sH{i,b}.subH{y,x},[ExFNIRS.settings.baseline_start-ExFNIRS.settings.block_start,ExFNIRS.settings.baseline_end-ExFNIRS.settings.block_start],{'--k','HandleVisibility','off'});
                    pf2_base.external.vline(sH{i,b}.subH{y,x},[ExFNIRS.settings.block_start-ExFNIRS.settings.block_start,ExFNIRS.settings.block_end-ExFNIRS.settings.block_start],{'--r','HandleVisibility','off'});
                end
                
                hold(sH{i,b}.subH{y,x},'off');
            end
        end
        
        addDebugAnnotation(sH{i,b}.h);
        switch(figType)
            case 'bioM'
                pf2_base.external.suptitle(sH{i,b}.h,selectedBioM{i});
            otherwise
                
        end
    end
end

    
function addDebugAnnotation(figHandle)
global ExFNIRS
curTime = datetime(now,'ConvertFrom','datenum');
debugString=sprintf('%s\n%s (%s)\n%s',ExFNIRS.curMethodName,ExFNIRS.statusGroupByStr,ExFNIRS.settings.within_sub_avg_mode_label,curTime);

debugString(debugString==('_'))='-';
th=annotation(figHandle,'textbox',[0 0 0.1 1],'String',debugString,'FitBoxToText','on');
th.FontSize = 6;
th.LineStyle='none';
th.HorizontalAlignment='left';
th.VerticalAlignment='bottom';
curPos=th.Position;


function possibleStr=num2strOrNot(possibleStr)
if(iscell(possibleStr))
    for i=1:length(possibleStr)
       if(~ischar(possibleStr{i})&&isnumeric(possibleStr{i}))
            possibleStr{i}=num2str(possibleStr{i}); 
       end
    end
elseif(~ischar(possibleStr)&&isnumeric(possibleStr))
    possibleStr=num2str(possibleStr);
end



function outStr=getFormattedTrialString(fNIR)

if(~isfield(fNIR,'info'))
    outStr='Missing Info';
    return;
end

outStr='';

subStr=num2strOrNot(fNIR.info.SubjectID);
groupStr=num2strOrNot(fNIR.info.Group);
sessionStr=num2strOrNot(fNIR.info.Session);
conditionStr=num2strOrNot(fNIR.info.Condition);
trialStr=num2strOrNot(fNIR.info.Trial);
blockStr=num2strOrNot(fNIR.info.Block);

useID=true&&~isempty(subStr);
useGroup=true&&~isempty(groupStr);
useSession=true&&~isempty(sessionStr);
useCondition=true&&~isempty(conditionStr);
useTrial=true&&~isempty(trialStr);
useBlock=true&&~isempty(blockStr);

if(useID)
    outStr=sprintf('%sSubjectID:%s\n',outStr,subStr);
end
if(useGroup)
    outStr=sprintf('%sGroup:%s\n',outStr,groupStr);
end
if(useSession)
    outStr=sprintf('%sSession:%s\n',outStr,sessionStr);
end
if(useCondition)
    outStr=sprintf('%sCondition:%s\n',outStr,conditionStr);
end
if(useTrial)
    outStr=sprintf('%sTrial:%s\n',outStr,trialStr);
end
if(useBlock)
    outStr=sprintf('%sBlock:%s\n',outStr,blockStr);
end

outStr(end)='';


  
    





% --- Executes on button press in checkbox_subjectID_plotby.
function checkbox_subjectID_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_subjectID_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_subjectID_plotby
global ExFNIRS
ExFNIRS.settings.plotby.SubjectID=get(handles.checkbox_subjectID_plotby,'Value');

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in checkbox_group_plotby.
function checkbox_group_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_group_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_group_plotby
global ExFNIRS
ExFNIRS.settings.plotby.Group=get(handles.checkbox_group_plotby,'Value');
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in checkbox_session_plotby.
function checkbox_session_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_session_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_session_plotby
global ExFNIRS
ExFNIRS.settings.plotby.Session=get(handles.checkbox_session_plotby,'Value');
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in checkbox_trial_plotby.
function checkbox_trial_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_trial_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_trial_plotby
global ExFNIRS
ExFNIRS.settings.plotby.Trial=get(handles.checkbox_trial_plotby,'Value');
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in checkbox_condition_plotby.
function checkbox_condition_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_condition_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_condition_plotby
global ExFNIRS
ExFNIRS.settings.plotby.Condition=get(handles.checkbox_condition_plotby,'Value');
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in pushbutton_export_csv.
function pushbutton_export_csv_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_export_csv (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

if(ExFNIRS.UpdateNeeded)
    updateSelectedTable(handles);
end

if(isempty(ExFNIRS.selectedTable)||isempty(ExFNIRS.gby))
    return;
end

answerFormat = questdlg(sprintf('Select Export Table Format:\n\nWide Format: 1 row per segment, 1 column per biomarkerXchannelXtimepoint\nLong Format 1 row per timepointXsegment, 1 column per channelXbiomarker\n'), ...
	'Table Format', ...
	'Wide Format','Long Format','Cancel','Wide Format');

if strcmp(answerFormat,'Cancel')
    return
end

curTimes=[];
for i=1:length(ExFNIRS.gby)
    curTimes=[curTimes;ExFNIRS.gby(i).gbyGrandBar.segmentTimes];
end
curTimes=unique(curTimes,'row');

fprintf('Current Block Times:')
display(curTimes)


fprintf('Current Viewing Window %.1f to %.1fs\n',ExFNIRS.settings.plot_start,ExFNIRS.settings.plot_end);
fprintf('Current Task Period %.1f:s to %.1fs\n',ExFNIRS.settings.block_start,ExFNIRS.settings.block_end);


answerTime = questdlg(sprintf('Choose times to export:\n\nCurrent sampling size is: %.1fs\n\nCurrent Viewing Window: %.1f to %.1fs\nCurrent Task Period %.1f:s to %.1fs\n\nNote: Incomplete bins will not be exported',ExFNIRS.settings.barchart_resample_size,ExFNIRS.settings.plot_start,ExFNIRS.settings.plot_end,ExFNIRS.settings.block_start,ExFNIRS.settings.block_end), ...
	'Export Time Selection', ...
	'All Times','Viewing Window','Baseline to Task','Viewing Window');%'All Times','Viewing Window','Baseline to Task','Task Only','Cancel','Baseline to Task');

switch(answerTime)
    case 'All Times'
        t_min=min(curTimes(:,1));
        t_max=max(curTimes(:,3));
    case 'Viewing Window'
        t_start=ExFNIRS.settings.plot_start;
        t_end=ExFNIRS.settings.plot_end;
    case 'Baseline to Task'
        t_start=min(ExFNIRS.settings.baseline_start,ExFNIRS.settings.block_start);
        t_end=max(ExFNIRS.settings.baseline_end,ExFNIRS.settings.block_end);
    case 'Task Only'
        t_start=ExFNIRS.settings.block_start;
        t_end=ExFNIRS.settings.block_end;
end

startIdx=curTimes(:,1)>=t_start;
endIdx=curTimes(:,3)<=t_end;
curTimes=curTimes(startIdx&endIdx,:);

fprintf('Exporting Times:')
display(curTimes);



% Handle response
switch answerFormat
    case 'Wide Format'
        exportWideTable(curTimes(:,1));
    case 'Long Format'
        exportLongTable(curTimes(:,1));
    case 'Cancel'

end

function myTable=remove9999(myTable)

for c=1:size(myTable,2)
    if(isnumeric(myTable{:,c}))
        myTable{myTable{:,c}==-9999,c}=nan;
    elseif(iscell(myTable{:,c})&&(ischar(myTable{:,c}{1})||isstring(myTable{:,c}{1})))
        myTable{strcmp('-9999',myTable{:,c}),c}={''};
    end
end

function myTable=nan_to_9999(myTable)

for c=1:size(myTable,2)
    if(isnumeric(myTable{:,c}))
        myTable{isnan(myTable{:,c}),c}=-9999;
    elseif(iscell(myTable{:,c})&&(ischar(myTable{:,c}{1})||isstring(myTable{:,c}{1})))
        myTable{strcmp('',myTable{:,c}),c}={'-9999'};
    end
end

function writeLogFile(logFileName,path)

global ExFNIRS

settings=ExFNIRS.settings;

fullPath=sprintf('%s/%s',path,logFileName);
fileID = fopen(fullPath,'w');
versInfo=exploreFNIRS.versInfo();
fprintf(fileID,'%s\n',versInfo);
fprintf(fileID,'Exported %s\n',datestr(datetime('now')));

fprintf(fileID,'Group By: %s\n',ExFNIRS.statusGroupByStr);
fprintf(fileID,'Cur Method: %s\n',ExFNIRS.curMethodName);
fprintf(fileID,'Averaging Method: %s\n',settings.within_sub_avg_mode_label);
fprintf(fileID,'GrandAvg Resample Size: %.2f\n',settings.grandavg_resample_size);
fprintf(fileID,'Resample Size: %.2f\n',settings.barchart_resample_size);
fprintf(fileID,'Baseline Start: %.2f\n',settings.baseline_start);
fprintf(fileID,'Baseline End: %.2f\n',settings.baseline_end);
fprintf(fileID,'Block Start: %.2f\n',settings.block_start);
fprintf(fileID,'Block End: %.2f\n',settings.block_end);
fprintf(fileID,'Feature: %s\n',settings.plot_bar_feature);

fprintf(fileID,'\n');

rawMethodDescrip=processFNIRS2.Methods.Raw.DescribeMethod();
fprintf(fileID,'%s\n',rawMethodDescrip);
oxyMethodDescrip=processFNIRS2.Methods.Oxy.DescribeMethod();
fprintf(fileID,'%s\n',oxyMethodDescrip);


fclose(fileID);

function exportWideTable(times)

global ExFNIRS

bioMList={'HbO','HbR','HbDiff','HbTotal','CBSI'};

if(isempty(ExFNIRS.selectedTable))
    return;
end

[file, pathname] = uiputfile({'*.csv';'*.mat';'*.*'},'Export Segment Table');
if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
    return
end

if(strcmp(lower(file(end-3:end)),'mat'))
    exportMAT=true;
else
    exportMAT=false;
end

logFileName=sprintf('%s_wide.log',file(1:end-4));

exportTable=mergeGbyTablesWide(ExFNIRS.gby,bioMList,[],times,true,true);

if(ExFNIRS.settings.export_replace_missing_9999)
    exportTable=nan_to_9999(exportTable);
else
    exportTable=remove9999(exportTable);
end

numGroups=length(ExFNIRS.gby);

if(exportMAT)
    grandAvgData=cell(1,numGroups);
    grandAvgBarData=cell(1,numGroups);
end

for g=1:numGroups
    curGby=ExFNIRS.gby(g);
    
    if(isempty(curGby))
        continue;
    end
    
    
    if(exportMAT)
        grandAvgData{g}=curGby.gbyGrand; 
        grandAvgBarData{g}=curBarGA;
    end
  
end


%if(ExFNIRS.settings.code_missing)
%    disp('Not yet enabled');
%end

if(~exportMAT)
    writetable(exportTable, sprintf('%s/%s',pathname,file),'QuoteStrings',true);
else
    save(sprintf('%s/%s',pathname,file),'exportTable','grandAvgData','grandAvgBarData');
end

writeLogFile(logFileName,pathname);

fprintf('Data exported to %s\n',sprintf('%s/%s',pathname,file));

function exportLongTable(times)

global ExFNIRS

bioMList={'HbO','HbR','HbDiff','HbTotal','CBSI'};

if(isempty(ExFNIRS.selectedTable))
    return;
end

[file, pathname] = uiputfile({'*.csv';'*.mat';'*.*'},'Export Segment Table');
if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
    return
end

if(strcmp(lower(file(end-3:end)),'mat'))
    exportMAT=true;
else
    exportMAT=false;
end

logFileName=sprintf('%s_long.log',file(1:end-4));


exportTable=mergeGbyTablesLong(ExFNIRS.gby,bioMList,[],times,true,true);


if(ExFNIRS.settings.export_replace_missing_9999)
    exportTable=nan_to_9999(exportTable);
else
    exportTable=remove9999(exportTable);
end


numGroups=length(ExFNIRS.gby);

if(exportMAT)
    grandAvgData=cell(1,numGroups);
    grandAvgBarData=cell(1,numGroups);
end

for g=1:numGroups
    curGby=ExFNIRS.gby(g);
    
    if(isempty(curGby))
        continue;
    end
    
    
    if(exportMAT)
        grandAvgData{g}=curGby.gbyGrand; 
        grandAvgBarData{g}=curBarGA;
    end
  
end


%if(ExFNIRS.settings.code_missing)
%    disp('Not yet enabled');
%end

if(~exportMAT)
    writetable(exportTable, sprintf('%s/%s',pathname,file),'QuoteStrings',true);
else
    save(sprintf('%s/%s',pathname,file),'exportTable','grandAvgData','grandAvgBarData');
end

writeLogFile(logFileName,pathname);

fprintf('Data exported to %s\n',sprintf('%s%s',pathname,file));



function mergedTables=mergeGbyTablesWide(gbyTables,bioMarkers,channels,times,exportAux,exportROI)
% hObject    handle to pushbutton_export_csv (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if(nargin<6)
    exportROI=false;
end

if(nargin<5)
    exportAux=false;
end

if(nargin<4)
    times=[];
end


if(nargin<3)
    channels=[];
end

if(isempty(channels))
    emptyChannelFlag=true;
else
   emptyChannelFlag=false; 
end


if((~exportROI&&~exportAux)||emptyChannelFlag) %isempty used when exporting all data
    exportFNIR=true;
else
    exportFNIR=false;
end



if(nargin<2)
    bioMarkers={'HbO','HbR','HbDiff','HbTotal','CBSI'};
end

mergedTables=table();%ExFNIRS.selectedTable;


if(isempty(gbyTables))
    mergedTables=[];
    return;
end



for g=1:length(gbyTables)
    curGby=gbyTables(g);
    
    if(isempty(curGby))
        continue;
    end
    
    if(iscell(curGby)&&length(curGby)==1)
       curGby=curGby{1}; 
    end
    
    curBarGA=curGby.gbyGrandBarFlat;
    tempTable=curGby.gbyTables;
   
    
    %numRows=size(tempTable,1);
    if(emptyChannelFlag&&exportFNIR)
        numCh=size(curBarGA.HbO.data,2);
        channels=1:numCh;
    elseif(exportFNIR)
       numCh=length(channels); 
    else
       numCh=0; 
    end
    
    if(emptyChannelFlag&&exportROI&&pf2_base.isnestedfield(curBarGA,'ROI.HbO'))
        numROI=size(curBarGA.ROI.HbO.data,2);
        ROIs=1:numROI;
    elseif(exportFNIR&&pf2_base.isnestedfield(curBarGA,'ROI.HbO'))
       numROI=size(curBarGA.ROI.HbO.data,2);
       ROIs=1:numROI;
    else
       numROI=0; 
    end
    
    if(isempty(times))
        numTimes=length(curBarGA.time);
        times=curBarGA.time;
    else
        numTimes=length(times);
    end

    numBarGATimes=length(curBarGA.time);
    
    if(exportFNIR)
        for b=1:length(bioMarkers)
            curBioM=bioMarkers{b};
            for c=1:numCh
                chNum=channels(c);
                for t=1:numBarGATimes
                    if(ismember(curBarGA.time(t),times))
                   if(numTimes==1)
                      varName=sprintf('%s_Opt%i',curBioM,chNum); 
                   else
                      varName=sprintf('%s_Opt%i_t%.0f',curBioM,chNum,curBarGA.time(t)); 
                   end
                   varName(varName=='-')='_';
                   tempTable.(varName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curBarGA.(curBioM).data(t,chNum,:),[3,1,2]);
                    end
                end
            end
        end
    end
    
    if(exportROI&&pf2_base.isnestedfield(curBarGA,'ROI.HbO'))
        for b=1:length(bioMarkers)
            curBioM=bioMarkers{b};
            for c=1:numROI
                chNum=ROIs(c);
                for t=1:numBarGATimes
                    if(ismember(curBarGA.time(t),times))
                       if(numTimes==1)
                          varName=sprintf('%s_ROI%i',curBioM,chNum); 
                       else
                          varName=sprintf('%s_ROI%i_t%.0f',curBioM,chNum,curBarGA.time(t)); 
                       end
                       varName(varName=='-')='_';
                       tempTable.(varName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curBarGA.ROI.(curBioM).data(t,chNum,:),[3,1,2]);
                    end
                end
            end
        end
    end
    
     if(exportAux&&isfield(curBarGA,'Aux'))
         warning('To-do add AUX fields to export wide'); % trouble is syncing up timing between each
%         curAuxFields=fields(curBarGA.Aux);
%         for aux=1:length(curAuxFields)
%            curAuxName=curAuxFields{aux};
%            curAux= curBarGA.Aux.(curAuxName);
%            numAuxCh=size(curAux.data,2);
%            if(numAuxCh==1)
%                 newAuxName=sprintf('aux_%s',curAuxName);
%                 tempTable.(newAuxName)(:,1)=nan;
%                 tempTable.(newAuxName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curAux.data(tDataIdx,1,:),[3,1,2]);
%            else
%                for ch=1:numAuxCh
%                    newAuxName=sprintf('aux_%s_%i',curAuxName,ch);
%                    tempTable.(newAuxName)(:,1)=nan;
%                    tempTable.(newAuxName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curAux.data(tDataIdx,ch,:),[3,1,2]);
%                end
%            end
% 
%         end
     end
    
    mergedTables=mergeTables(mergedTables,tempTable);
end

function mergedTables=mergeGbyTablesLong(gbyTables,bioMarkers,channels,times,exportAux,exportROI)
% hObject    handle to pushbutton_export_csv (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if(nargin<6)
    exportROI=false;
end

if(nargin<5)
    exportAux=false;
end

if(nargin<4)
    times=[];
end

if(nargin<3)
    channels=[];
end

if(isempty(channels))
   emptyChannelFlag=true;
else
    emptyChannelFlag=false;
end

if((~exportROI&&~exportAux)) % export parameters by themself, or all channels
   exportFNIR=true; 
elseif(isempty(channels)) %used in mass export
   exportFNIR=true; 
else
    exportFNIR=false;
end



if(nargin<2)
    bioMarkers={'HbO','HbR','HbDiff','HbTotal','CBSI'};
end
    
mergedTables=table();%ExFNIRS.selectedTable;



if(isempty(gbyTables))
    mergedTables=[];
    return;
end



for g=1:length(gbyTables)
    curGby=gbyTables(g);
    
    if(isempty(curGby))
        continue;
    end
    
    if(iscell(curGby)&&length(curGby)==1)
       curGby=curGby{1}; 
    end
    
    curBarGA=curGby.gbyGrandBarFlat;

    if(exportROI&&(emptyChannelFlag)&&pf2_base.isnestedfield(curBarGA,'ROI.HbO.data'))
       numROI=size(curBarGA.ROI.HbO.data,2);
       ROIs=1:numROI;
    elseif(exportROI&&~emptyChannelFlag&&pf2_base.isnestedfield(curBarGA,'ROI.HbO.data'))
        numROI=length(channels);
        ROIs=channels;
    else
       numROI=0; 
    end
    
    %numRows=size(tempTable,1);
    if(emptyChannelFlag&&exportFNIR)
        numCh=size(curBarGA.HbO.data,2);
        channels=1:numCh;
    elseif(exportFNIR)
       numCh=length(channels); 
    else
       numCH=0; 
    end
    if(isempty(times))
        numTimes=length(curBarGA.time);
        times=curBarGA.time;
    else
        numTimes=length(times);
    end
    
    for tIdx=1:numTimes
        t=times(tIdx);
        tempTable=curGby.gbyTables;
        tDataIdx=find(curBarGA.time==t,1);
        if(isempty(tDataIdx))
            continue;
        end
        t_end=curBarGA.segmentTimes(tDataIdx,3);
        %tempTable.('BioM')(:,1)=string(curBioM);
        tempTable.('Time')(:,1)=string(num2str(round(t),'%.0f'));
        tempTable.('TimeStart')(:,1)=string(num2str(t,'%.2f'));
        tempTable.('TimeEnd')(:,1)=string(num2str(t_end,'%.2f'));

        if(exportFNIR&&~isempty(bioMarkers))
            for b=1:length(bioMarkers)
                curBioM=bioMarkers{b};

                for c=1:numCh
                    chNum=channels(c);
                    chName=sprintf('Opt%i_%s',chNum,curBioM); 


                    tempTable.(chName)(:,1)=nan;
                    tempTable.(chName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curBarGA.(curBioM).data(tDataIdx,chNum,:),[3,1,2]);
                    tempTable.(chName)(tempTable{:,'missingFNIRS'}==1,1)=nan;
                end

            end
        end
        
        if(exportROI&&~isempty(bioMarkers)&&pf2_base.isnestedfield(curBarGA,'ROI.HbO.data'))
            for b=1:length(bioMarkers)
                curBioM=bioMarkers{b};

                for c=1:numROI
                    chNum=ROIs(c);
                    chName=sprintf('ROI%i_%s',chNum,curBioM); 


                    tempTable.(chName)(:,1)=nan;
                    tempTable.(chName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curBarGA.ROI.(curBioM).data(tDataIdx,chNum,:),[3,1,2]);
                    tempTable.(chName)(tempTable{:,'missingFNIRS'}==1,1)=nan;

                end

            end
        end

        if(exportAux&&isfield(curBarGA,'Aux'))
            curAuxFields=fields(curBarGA.Aux);
            for aux=1:length(curAuxFields)
               curAuxName=curAuxFields{aux};
               curAux= curBarGA.Aux.(curAuxName);
               numAuxCh=size(curAux.data,2);
               if(numAuxCh==1)
                    newAuxName=sprintf('aux_%s',curAuxName);
                    tempTable.(newAuxName)(:,1)=nan;
                    tempTable.(newAuxName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curAux.data(tDataIdx,1,:),[3,1,2]);
                    tempTable.(newAuxName)(tempTable{:,'missingFNIRS'}==1,1)=nan;
               else
                   for ch=1:numAuxCh
                       newAuxName=sprintf('aux_%s_%i',curAuxName,ch);
                       tempTable.(newAuxName)(:,1)=nan;
                       tempTable.(newAuxName)(tempTable{:,'missingFNIRS'}==0,1)=permute(curAux.data(tDataIdx,ch,:),[3,1,2]);
                       tempTable.(newAuxName)(tempTable{:,'missingFNIRS'}==1,1)=nan;
                   end
               end

            end
        end

        mergedTables=mergeTables(mergedTables,tempTable);
    end
    
    %else % No fnirs info
    %    tempTable=curGby.gbyTables;
    %    mergedTables=mergeTables(mergedTables,tempTable);
    %end
    
    
end


function mergedTables=mergeTables(table1,table2)

if(isempty(table1))
    mergedTables=table2;
    return;
elseif(isempty(table2))
    mergedTables=table1;
    return;
end

t1Vars=table1.Properties.VariableNames;
t2Vars=table2.Properties.VariableNames;
  
for i=1:length(t1Vars)
    curVar=t1Vars{i};
    if(~ismember(curVar,t2Vars))
        if(ischar(curVar))
            table2.(curVar)=strings(size(table2,1),1);
        elseif(isnumeric(curVar))
            table2.(curVar)=nan(size(table2,1),1);
        end
    end
end

for i=1:length(t2Vars)
    curVar=t2Vars{i};
    if(~ismember(curVar,t1Vars))
        if(ischar(curVar))
            table1.(curVar)=strings(size(table1,1),1);
        elseif(isnumeric(curVar))
            table1.(curVar)=nan(size(table1,1),1);
        end
    end
end

mergedTables=[table1;table2];

          



% --- Executes on button press in checkbox_plot_all_data.
function checkbox_plot_all_data_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_all_data (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_all_data
global ExFNIRS
ExFNIRS.settings.plot_individual=get(handles.checkbox_plot_all_data,'Value');

% --- Executes on button press in checkbox_plot_grandaverage.
function checkbox_plot_grandaverage_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_grandaverage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_grandaverage
global ExFNIRS
ExFNIRS.settings.plot_grandaverage=get(handles.checkbox_plot_grandaverage,'Value');

% --- Executes on selection change in popupmenu_grandaverage_feature.
function popupmenu_grandaverage_feature_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_grandaverage_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_grandaverage_feature contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_grandaverage_feature
global ExFNIRS
idx=get(handles.popupmenu_grandaverage_feature,'Value');
strs=get(handles.popupmenu_grandaverage_feature,'String');
ExFNIRS.settings.plot_grandaverage_feature=strs{idx};

% --- Executes during object creation, after setting all properties.
function popupmenu_grandaverage_feature_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_grandaverage_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_error.
function checkbox_plot_error_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_error (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_error
global ExFNIRS
ExFNIRS.settings.plot_error=get(handles.checkbox_plot_error,'Value');

% --- Executes on selection change in popupmenu_errorbar_feature.
function popupmenu_errorbar_feature_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_errorbar_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_errorbar_feature contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_errorbar_feature

global ExFNIRS
idx=get(handles.popupmenu_errorbar_feature,'Value');
strs=get(handles.popupmenu_errorbar_feature,'String');
ExFNIRS.settings.plot_error_feature=strs{idx};

% --- Executes during object creation, after setting all properties.
function popupmenu_errorbar_feature_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_errorbar_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_error_multiplier_Callback(hObject, eventdata, handles)
% hObject    handle to edit_error_multiplier (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_error_multiplier as text
%        str2double(get(hObject,'String')) returns contents of edit_error_multiplier as a double
global ExFNIRS
ExFNIRS.settings.plot_error_multiply=str2num(get(handles.edit_error_multiplier,'String'));
set(handles.edit_error_multiplier,'String',sprintf('%.1f',ExFNIRS.settings.plot_error_multiply));

% --- Executes during object creation, after setting all properties.
function edit_error_multiplier_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_error_multiplier (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_barchart_ga.
function checkbox_plot_barchart_ga_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_barchart_ga (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_barchart_ga
global ExFNIRS
ExFNIRS.settings.plot_bar_ga=get(handles.checkbox_plot_barchart_ga,'Value');

% --- Executes on selection change in popupmenu_feature.
function popupmenu_feature_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_feature contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_feature


% --- Executes during object creation, after setting all properties.
function popupmenu_feature_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_code_nan.
function checkbox_code_nan_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_code_nan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_code_nan
global ExFNIRS
ExFNIRS.settings.code_missing=get(handles.checkbox_code_nan,'Value');

% --- Executes on selection change in listbox_block.
function listbox_block_Callback(hObject, eventdata, handles)           
% hObject    handle to listbox_block (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_block contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_block
global ExFNIRS
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes during object creation, after setting all properties.
function listbox_block_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_block (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_block_select_all.
function pushbutton_block_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_block_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_block,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_block,'Value',[1:size(strs,1)]);
end

global ExFNIRS
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in pushbutton_block_select_none.
function pushbutton_block_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_block_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.listbox_block,'Value',[]);

% --- Executes on button press in checkbox_block_plotby.
function checkbox_block_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_block_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_block_plotby
global ExFNIRS
ExFNIRS.settings.plotby.Block=get(handles.checkbox_block_plotby,'Value');
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in pushbutton_refresh_methods.
function pushbutton_refresh_methods_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_refresh_methods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

curRawMethods=processFNIRS2_configureMethods('currentRawMethodsCallback',hObject,handles);
if(~isempty(curRawMethods))
   set(handles.listbox_raw_methods,'String',curRawMethods); 
end
curOxyMethods=processFNIRS2_configureMethods('currentOxyMethodsCallback',hObject,handles);
if(~isempty(curOxyMethods))
   set(handles.listbox_oxy_methods,'String',curOxyMethods); 
end

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end


% --- Executes on button press in pushbutton_import_raw.
function pushbutton_import_raw_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_import_raw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
processFNIRS2('ImportOxyMethods','');

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end



% --- Executes on button press in pushbutton_import_oxy.
function pushbutton_import_oxy_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_import_oxy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
processFNIRS2('ImportRawMethods','');

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end


% --- Executes on button press in pushbutton_clear_processed.
function pushbutton_clear_processed_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_clear_processed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS
strsRaw=get(handles.listbox_raw_methods,'String');
strsOxy=get(handles.listbox_oxy_methods,'String');

ExFNIRS.processedData=cell(length(strsOxy)*length(strsRaw),3);
ExFNIRS.numProcessed=0;

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end



function edit_grandavg_resample_size_Callback(hObject, eventdata, handles)
% hObject    handle to edit_grandavg_resample_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_grandavg_resample_size as text
%        str2double(get(hObject,'String')) returns contents of edit_grandavg_resample_size as a double
global ExFNIRS
ExFNIRS.settings.grandavg_resample_size=str2num(get(handles.edit_grandavg_resample_size,'String'));
set(handles.edit_grandavg_resample_size,'String',sprintf('%.3f',ExFNIRS.settings.grandavg_resample_size));

strsRaw=get(handles.listbox_raw_methods,'String');
strsOxy=get(handles.listbox_oxy_methods,'String');

ExFNIRS.processedData=cell(length(strsOxy)*length(strsRaw),3);
ExFNIRS.numProcessed=0;

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
   flagForUpdate(2,handles); 
end

% --- Executes during object creation, after setting all properties.
function edit_grandavg_resample_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_grandavg_resample_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function txt = myDataTipUpdateFcn(pointDataTip, event_obj)

 hAxes=get(pointDataTip,'Parent');
 pos = event_obj.Position;
 selectedObjectTag=event_obj.Target.Tag;
 
 if(~isempty(selectedObjectTag))
     txt={sprintf('%s\nt=%.2f, y=%.2f',selectedObjectTag,pos(1),pos(2))};
 else
     txt = {sprintf('t=%.2f, y=%.2f',pos(1),pos(2))};
 end
%disp(['You clicked X:',num2str(pos(1)),', Y:',num2str(pos(2))]);
    

 


% --- Executes on button press in pushbutton_plot_barchart.
function pushbutton_plot_barchart_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_plot_barchart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

plot_barchart(handles, true,false);

function plot_barchart(handles, showBarChart,showTopo)

global ExFNIRS

if(ExFNIRS.UpdateNeeded)
    updateSelectedTable(handles);
end

multiPlot=false;

if(~isfield(ExFNIRS,'gby'))
    warning('No groups match selection criteria');
    return;
end

curInfoGroup=ExFNIRS.settings.curInfoGroup;

gbyVars=ExFNIRS.groupByVars;
if(~isempty(curInfoGroup)&&~strcmp(curInfoGroup,'(Time)'))
    [ismem,idx]=ismember(curInfoGroup,gbyVars);
    if(ismem)
        gbyVars(idx)=[];
        useCurInfoGroup=true;
    else
        useCurInfoGroup=false;
    end
else
    useCurInfoGroup=false;
end

numGroups=length(ExFNIRS.gby);

biomStrs=get(handles.listbox_biomarker,'String');
selBioM=get(handles.listbox_biomarker,'Value');
selectedBioM=biomStrs(selBioM);
numBioM=length(selBioM);

optStrs=get(handles.listbox_optode,'String');
selOpt=get(handles.listbox_optode,'Value');
selectedOptStr=optStrs(selOpt',:);
numOpt=length(selOpt);

if(numOpt==0||numGroups==0||numBioM==0)
    return;
end


if(ExFNIRS.settings.ylim_fixed)
    ExFNIRS.settings.ylim_fixed_min=inf;
    ExFNIRS.settings.ylim_fixed_max=-inf;
end

if(showBarChart)
    multiPlot=false;
    ExFNIRS.figHandles.main=figure(1000);
    clf(ExFNIRS.figHandles.main);
    cla(ExFNIRS.figHandles.main);
    addDebugAnnotation(ExFNIRS.figHandles.main);
    dcm_obj = datacursormode(ExFNIRS.figHandles.main);
    set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
    % end
end

gbyStrs=cell(numGroups,1);
curInfoGby=cell(0);

for g=1:numGroups
    gbyStrs{g}='';
   if(~isempty(ExFNIRS.gby(g).gbyTables))
       for i=1:length(gbyVars)
           gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(ExFNIRS.gby(g).gbyTables.(gbyVars{i})(1)));
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(ExFNIRS.gby(g).gbyTables.(curInfoGroup)(1));
       end
   end 
   if(~isempty(gbyStrs{g}))
        gbyStrs{g}(end)='';
   end
end

[numUgroups]=length(unique(cellstr(gbyStrs)));

if(numUgroups==1&&~showTopo)
    num2Plot=numBioM;
    plotGroupByBioM=true;
    cCell=table2cell(pf2_base.getBioColors());
    for i=1:length(cCell)
        cIndex(i,:)=cCell{i};
    end
    cIndex=cIndex(selBioM,:);
else
    num2Plot=numGroups;
    plotGroupByBioM=false;
    if(ExFNIRS.settings.use_gui_color)
        cIndex=ExFNIRS.settings.guiColor(1:numUgroups,:);
    else
        cIndex=ExFNIRS.settings.cmap(numUgroups);%linspecer(num2Plot,'qualitative');
    end
end



barChartTimes=[];
barChartEndTimes=[];
for i=1:numGroups
    if(isempty(ExFNIRS.gby(i).gbyGrandBar))
        curGrandTime=[];
        curGrandEndTime=[];
    else
        curGrandTime=ExFNIRS.gby(i).gbyGrandBar.segmentTimes(:,1);
        curGrandEndTime=ExFNIRS.gby(i).gbyGrandBar.segmentTimes(:,3);
    end
    barChartTimes=[barChartTimes;curGrandTime];
    barChartEndTimes=[barChartEndTimes;curGrandEndTime];
end
barChartTimes=sort(unique(round(barChartTimes)));
barChartEndTimes=sort(unique(round(barChartEndTimes)));

[uCurInfoG,firstCurIdx,uCurIdx]=unique(cellstr(curInfoGby));
numCurInfoG=max(uCurIdx);
uCurGIdxCount=nan(size(uCurIdx));
for i =1:numCurInfoG
    uCurGIdxCount(uCurIdx==i)=1:sum(uCurIdx==i);
end

if(~useCurInfoGroup||isnan(numCurInfoG))
   useCurInfoGroup=false;
   numCurInfoG=1; 
   uCurInfoG='';
end

validBarChartTimesIdx=barChartEndTimes<=ExFNIRS.settings.plot_end&barChartTimes>=ExFNIRS.settings.plot_start;
barChartTimes=barChartTimes(validBarChartTimesIdx);
barChartEndTimes=barChartEndTimes(validBarChartTimesIdx);
numChartTimes=length(barChartTimes);

for i=1:length(barChartTimes)
   barChartTimeStrings{i}=sprintf('%i-%i',barChartTimes(i),barChartEndTimes(i)); 
end

errorFeature=ExFNIRS.settings.plot_bar_err_feature;
plotFeature=ExFNIRS.settings.plot_bar_feature;

if(strcmp(plotFeature,'Count')&&ExFNIRS.settings.plot_bar_ga)
  plotFeature='N';
  plotCount=true;
else
    plotCount=false;
end

if(plotGroupByBioM)
    subplotHandles=cell(numOpt,1);
else
    subplotHandles=cell(numOpt*numBioM,1);
end

subplotGby=subplotHandles;
numCharts=length(subplotHandles);


for chIdx=1:numOpt
    ch=selOpt(chIdx);
    %legendGFXhandles{1}=[];
    %legendGFXstrs{1}=cell(0);
    if(plotGroupByBioM)
        barChartData{1}=nan(numCurInfoG,numBioM,3);
        num2Plot=numBioM;
    elseif(numUgroups>1)
        for i=1:numBioM
            barChartData{i}=nan(numChartTimes,numUgroups,3);
        end
        num2Plot=numUgroups;
    else
        barChartData{1}=nan(numCurInfoG,1,3);
    
    end
    
    chartGby=cell(size(subplotHandles));
    
    %barChartTimes=times;
    
    gAStrs=cell(num2Plot,1);
    gAerrStrs=cell(num2Plot,1);
    
    for b=1:numBioM
        bioM=selectedBioM(b);
        if(iscell(bioM))
            bioM=bioM{1};
        end
        
        
        if(numUgroups>1)
            curChart=b;
        else
            curChart=1;
        end
        
        for g=1:numGroups
            
            curFNIRS=ExFNIRS.gby(g).gbyFNIRS_blk;
            curGrand=ExFNIRS.gby(g).gbyGrandBar;
            

            if(isfield(chartGby{curChart},'gby'))
                chartGby{curChart}.gby(end+1)=ExFNIRS.gby(g);
            else
                chartGby{curChart}.gby(1)=ExFNIRS.gby(g);
                chartGby{curChart}.curCh=ch;
                if(plotGroupByBioM)
                    chartGby{curChart}.curBioM=selectedBioM;
                else
                    chartGby{curChart}.curBioM=selectedBioM(b);
                end
            end
            
            
            if(useCurInfoGroup)
                curGroupInfoIdx=uCurIdx(g);
                curGroupIdxOffset=(curGroupInfoIdx-1)*numChartTimes;
                curUgroupIdx=uCurGIdxCount(g);
            else
                curGroupInfoIdx=g;
                curGroupIdxOffset=0;
                curUgroupIdx=g;
            end
            
            if(isempty(curGrand))
                if(plotGroupByBioM)
                    barChartData{curChart}(:,b,1:3)=nan;
                    
                else
                    barChartData{curChart}(:,curUgroupIdx,1:3)=nan;
                end
                
               if(numUgroups>1||numBioM==1)
                    gAStrs{curUgroupIdx,curChart}=sprintf('%s',gbyStrs{g}); 
               elseif(numBioM>1&&~multiPlot)
                    gAStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
               end
                
               continue; 
            end
            
            if(ExFNIRS.settings.plot_bar_ga)
                  [timeIdx,timeIdxRev]=ismember(round(curGrand.time),barChartTimes);
                  timeIdxRev=timeIdxRev(timeIdxRev>0);
                  
                  switch(ExFNIRS.settings.ChannelMode)
                      case 'fNIR'
                          data2plot=curGrand.(bioM);
                      case 'ROI'
                          if(~pf2_base.isnestedfield(curGrand,'ROI.HbO.data'))
                              error('ROI data must be calculated using a build ROI step');
                          end
                          
                          data2plot=curGrand.ROI.(bioM);
                      case 'Aux'
           
                  end
   
                  if(plotGroupByBioM)
                      barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,1)=data2plot.(plotFeature)(timeIdx,ch);
                  else
                      barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,1)=data2plot.(plotFeature)(timeIdx,ch);
                  end
                  if(numUgroups>1||numBioM==1)
                       gAStrs{curUgroupIdx,curChart}=sprintf('%s',gbyStrs{g}); 
                  elseif(numBioM>1)
                       gAStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
                  end
            end
            
            if(ExFNIRS.settings.plot_bar_err&&~plotCount)
                  
                  errMulitply=ExFNIRS.settings.plot_bar_err_mult;
                  [timeIdx,timeIdxRev]=ismember(round(curGrand.time),barChartTimes);
                  timeIdxRev=timeIdxRev(timeIdxRev>0);
                  ga2plot=curGrand.(bioM);
                  if(strcmp(errorFeature,'MaxMin'))
                      if(plotGroupByBioM)
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=ga2plot.Max(timeIdx,ch);
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,3)=ga2plot.Min(timeIdx,ch);
                      else
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,2)=ga2plot.Max(timeIdx,ch);
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,3)=ga2plot.Min(timeIdx,ch);
                      end
                  else
                      if(plotGroupByBioM)
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=ga2plot.(errorFeature)(timeIdx,ch)*errMulitply;
                      else
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,2)=ga2plot.(errorFeature)(timeIdx,ch)*errMulitply;
                      end
                  end
                  if(numUgroups>1||numBioM==1)
                       gAErrStrs{curGroupInfoIdx,curChart}=sprintf('%s',gbyStrs{curGroupInfoIdx}); 
                  elseif(numBioM>1&&~multiPlot)
                       gAErrStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
                  end
            else
                    barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=0;
                    barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,3)=0;
                  if(numUgroups>1||numBioM==1)
                       gAErrStrs{curGroupInfoIdx,curChart}=''; 
                  elseif(numBioM>1&&~multiPlot)
                       gAErrStrs{b,curChart}=''; 
                  end 
            end
          end
    
    end
    
    
    
    for curChart=1:length(barChartData)
        if(isempty(barChartData{curChart}))
            warning('All data is missing');
            continue;
        elseif(sum(~isnan(barChartData{curChart}(:,:,1)))==0)
            warning('All data is missing');
            continue;
        end
        if(~plotGroupByBioM)
                lastPlotNum=numBioM*numOpt;
                if(numOpt>1)
                    curSubplotIdx=chIdx+(numOpt*(curChart-1));
                    
                    numX=numBioM;
                    numY=numOpt;
                    subplotGby{curSubplotIdx}=chartGby{curChart};
                else
                    curSubplotIdx=chIdx+(numOpt*(curChart-1));
                    numX=1;
                    numY=numBioM;
                    subplotGby{curSubplotIdx}=chartGby{curChart};
                end
        else
                lastPlotNum=numOpt;
                curSubplotIdx=chIdx;
                numX=1;
                numY=numOpt;
                subplotGby{curSubplotIdx}=chartGby{curChart};
        end
        if(~showBarChart)
            continue;
        end
        subplotHandles{curSubplotIdx}=subplot(numX,numY,curSubplotIdx);
        
        if(useCurInfoGroup&&numChartTimes>1)
            xBarLabels=cell(numChartTimes*numCurInfoG,1);
            timeStrs=num2str(round(barChartTimes));
            for g=1:numCurInfoG
                for t=1:numChartTimes
                    xBarLabels{(g-1)*numChartTimes+t}=sprintf('%s-%ss',curInfoGby{firstCurIdx(g)},timeStrs(t,:));
                end
            end
        elseif(useCurInfoGroup&&numChartTimes==1)
            xBarLabels=cell(numChartTimes*numCurInfoG,1);
            for g=1:numCurInfoG
                    xBarLabels{g}=curInfoGby{firstCurIdx(g)};
            end
        else
            xBarLabels=barChartTimeStrings;
        end
    
        if(ExFNIRS.settings.plot_bar_err)
            pf2_base.external.barweb(barChartData{curChart}(:,:,1),barChartData{curChart}(:,:,2),1,xBarLabels, [], [], [], cIndex,[],gAStrs,[],'hide');
            ylimLower=min(min(barChartData{curChart}(:,:,1)))-max(max(barChartData{curChart}(:,:,2)));
            ylimUpper=max(max(barChartData{curChart}(:,:,1)))+max(max(barChartData{curChart}(:,:,2)));
            yrange=ylimUpper-ylimLower;
            ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
            
        else
            pf2_base.external.barweb(barChartData{curChart}(:,:,1),[],1,xBarLabels, [], [], [], cIndex,[],gAStrs,[],'hide');
            ylimLower=min(min(barChartData{curChart}(:,:,1)));
            ylimUpper=max(max(barChartData{curChart}(:,:,1)));
            yrange=ylimUpper-ylimLower;
            
        end
        
        if(ExFNIRS.settings.ylim_fixed)
            ylim([min(ylimLower-0.05*yrange,0),max(ylimUpper+0.05*yrange,0)]);
            cylim=ylim;
            ExFNIRS.settings.ylim_fixed_min=min(cylim(1),ExFNIRS.settings.ylim_fixed_min);
            ExFNIRS.settings.ylim_fixed_max=max(cylim(2),ExFNIRS.settings.ylim_fixed_max);
        elseif(ExFNIRS.settings.ylim_manual&&~plotCount)
            ylim([ExFNIRS.settings.ylim_manual_min,ExFNIRS.settings.ylim_manual_max]);
        else
            ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
        end
        
        if(numBioM==1||numUgroups>1)  
            if(numBioM==1)
                bioM=selectedBioM(curChart);
                if(iscell(bioM))
                    bioM=bioM{1};
                end
                if(plotCount)
                    ylabel(sprintf('%s \\Delta[%s] (\\muM)',plotFeature,bioM));
                else
                    ylabel(sprintf('%s \\Delta[%s] (\\muM)  +/- (%s)',plotFeature,bioM,errorFeature));
                end
            else
                bioM=selectedBioM(curChart);
                 if(iscell(bioM))
                    bioM=bioM{1};
                end
                if(plotCount)
                    ylabel(sprintf('%s \\Delta[%s] (\\muM)',plotFeature,bioM));
                else
                    ylabel(sprintf('%s \\Delta[%s] (\\muM)  +/- (%s)',plotFeature,bioM,errorFeature));
                end
                
            end
        elseif(numBioM==b)
            if(plotCount)
                ylabel(sprintf('%s \\Delta[%s] (\\muM)',plotFeature,'X'));
            else
                ylabel(sprintf('%s \\Delta[%s] (\\muM)  +/- (%s)',plotFeature,'X',errorFeature));
            end
        end
        
        
        switch ExFNIRS.settings.ChannelMode
            case 'fNIR'
                title(sprintf('Optode %i',ch));
            case 'ROI'
                title(sprintf('ROI: %s',optStrs{ch}));
            case 'Aux'
                
        end
        
        if(useCurInfoGroup&&numChartTimes==1)
            xlabel(sprintf('%s (t=%s)',curInfoGroup,barChartTimeStrings{1}));
        elseif(useCurInfoGroup)
            xlabel(sprintf('Time (s) x %s',curInfoGroup));
        else
            xlabel('Time (s)');
        end
        
        if((numBioM>1||numUgroups>1)&&(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&curSubplotIdx==lastPlotNum)))
            for i=1:size(gAStrs,1)
               if(isnumeric(gAStrs{i,curChart}))
                   gAStrs{i,curChart}='';
               end
            end
            legend(gAStrs(:,curChart));
            legend boxoff;
        end
        hold off;
    end
end

if(plotCount)
   ExFNIRS.settings.ylim_fixed_min=0; 
end

ExFNIRS.curChartModels=cell(0);
ExFNIRS.curChartModelsAIC=[];
ExFNIRS.curChartModelsCoefficents=cell(0);
ExFNIRS.curChartModelsCoefficents_pval=table();
ExFNIRS.curChartModelsCoefficents_tstat=table();
ExFNIRS.curChartModelsCoefficents_df=table();
ExFNIRS.curChartModelsANOVA=cell(0);
ExFNIRS.curChartModelsANOVACoefficents_pval=table();
ExFNIRS.curChartModelsANOVACoefficents_Fstat=table();
ExFNIRS.curChartModelsANOVACoefficents_df1=table();
ExFNIRS.curChartModelsANOVACoefficents_df2=table();

if(ExFNIRS.settings.LME_enable)
    fprintf('Generating Models...\nAccessed at ExFNIRS.curChartModels\n')
end


 LME_topo_mode='anova';
for sH=1:length(subplotHandles)
    
    if(ExFNIRS.settings.LME_enable&&isfield(subplotGby{sH},'gby'))
        switch (ExFNIRS.settings.ChannelMode)
            case 'fNIR'
                mergedTables{sH}=mergeGbyTablesLong(subplotGby{sH}.gby,subplotGby{sH}.curBioM,subplotGby{sH}.curCh,barChartTimes,false,false);
                varNameStart='Opt';
        
            case 'ROI'     
                mergedTables{sH}=mergeGbyTablesLong(subplotGby{sH}.gby,subplotGby{sH}.curBioM,subplotGby{sH}.curCh,barChartTimes,false,true);
                varNameStart='ROI';
        
            case 'Aux'
                mergedTables{sH}=mergeGbyTablesLong(subplotGby{sH}.gby,subplotGby{sH}.curBioM,subplotGby{sH}.curCh,barChartTimes,true,false);
                varNameStart='Aux';
        end
        x=ExFNIRS.groupByVars;
        curLMEGbyString='';
        mdlPrtString='';
        
        useAllInteractions=ExFNIRS.settings.LME_all_interactions;
        
        basicMdlStrings=cell(0);
        if(numChartTimes>1)
            basicMdlStrings{length(basicMdlStrings)+1}='Time';
        end
        
        if(ExFNIRS.settings.LME_info_covariate)
            basicMdlStrings{length(basicMdlStrings)+1}=ExFNIRS.settings.curInfoStr;
        end
%         if(plotGroupByBioM&&numBioM>1)
%             %basicMdlStrings{length(basicMdlStrings)+1}='BioM';
%             warning('GroupBy Biomarker Plots not supported yet\n Only using first biomarker');
%         end
        
        for z=1:length(basicMdlStrings)
            if(z==1)
                mdlPrtString=basicMdlStrings{z};
            else
                mdlPrtString=sprintf('%s*%s',mdlPrtString,basicMdlStrings{z});
            end
        end
        
        if(isempty(mdlPrtString))
            mdlPrtString='1';
        end

        
        if(useAllInteractions)
            curLMEGbyString=mdlPrtString;
            for i=1:length(x)
                curLMEGbyString=sprintf('%s*%s',curLMEGbyString,x{i});
            end
        else
            for i=1:length(x)
                curLMEGbyString=sprintf('%s+%s*%s',curLMEGbyString,mdlPrtString,x{i});
            end
            if(~isempty(curLMEGbyString))
                curLMEGbyString(1)=[];
            end

            
        end
        
        
        
        if(ExFNIRS.settings.LME_use_customStr&&~isempty(ExFNIRS.settings.LME_customStr))
            lmeString=sprintf('%s%i_%s~%s+(%s)',varNameStart,subplotGby{sH}.curCh,subplotGby{sH}.curBioM{1},ExFNIRS.settings.LME_customStr,ExFNIRS.settings.LME_randomFxStr);
        elseif(ExFNIRS.settings.LME_use_intercept)
            lmeString=sprintf('%s%i_%s~%s+(%s)',varNameStart,subplotGby{sH}.curCh,subplotGby{sH}.curBioM{1},curLMEGbyString,ExFNIRS.settings.LME_randomFxStr);
        else
            lmeString=sprintf('%s%i_%s~-1+%s+(%s)',varNameStart,subplotGby{sH}.curCh,subplotGby{sH}.curBioM{1},curLMEGbyString,ExFNIRS.settings.LME_randomFxStr);
            
        end

        try
            if((~ExFNIRS.settings.LME_use_discreteTime||strcmp(LME_topo_mode,'anova'))&&numChartTimes>1)
                mergedTables{sH}.Time=str2double(mergedTables{sH}.Time);
            end
            
            
            
            curChartLME{sH}=fitlme(mergedTables{sH},lmeString);
          %   curChartLME_emm{sH}= pf2_base.external.emmeans(curChartLME{sH}, {'orig'}, 'effects');
%             h = emmip(curChartLME_emm{sH},'orig');
            
            switch (ExFNIRS.settings.ChannelMode)
                case 'fNIR'
                         chName=sprintf('Opt%i',subplotGby{sH}.curCh);
                case 'ROI'     
                         chName=sprintf('ROI%i_%s',subplotGby{sH}.curCh,optStrs{subplotGby{sH}.curCh});
                case 'Aux'
            end

           
            fprintf('Chart %i LME model: %s',sH,chName);
            if(~plotGroupByBioM)
                fprintf(' [%s]',subplotGby{sH}.curBioM{1});
            end
            if(useAllInteractions)
                fprintf(' - All Interactions\n');
            else
                fprintf(' - No Interactions\n');
            end
            ExFNIRS.curChartModels{sH}=curChartLME{sH};
            ExFNIRS.curChartModelsAIC(sH)=curChartLME{sH}.ModelCriterion.AIC;
            ExFNIRS.curChartModelsCoefficents{sH}=curChartLME{sH}.Coefficients;
            ExFNIRS.curChartModelsANOVA{sH}=curChartLME{sH}.anova;
            
            anovaNames=curChartLME{sH}.anova.Term;
            
            for a=1:length(anovaNames)
               str=anovaNames{a};
               str(str=='('|str==')')=''; % replace shitty characters
               str(str==':'|str=='_')=''; % replace shitty characters
               str(str==' '|str=='-')=''; % replace shitty characters
               anovaNames{a}=str;
            end
            
            varNames=curChartLME{sH}.Coefficients.Name;
            for v=1:length(varNames)
               str=varNames{v};
               str(str=='('|str==')')=''; % replace shitty characters
               str(str==':'|str=='_')=''; % replace shitty characters
               str(str==' '|str=='-')=''; % replace shitty characters
               varNames{v}=str;
            end
            
            if(true)%~plotGroupByBioM)
                curBioM=subplotGby{sH}.curBioM{1};
                curRowName=sprintf('%s_%s',chName,curBioM);
                
                
                
                
                ExFNIRS.curChartModelsANOVACoefficents_pval{curRowName,anovaNames}= ExFNIRS.curChartModelsANOVA{sH}.pValue';
                ExFNIRS.curChartModelsANOVACoefficents_Fstat{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.FStat';
                if(ismember('DF2',properties(ExFNIRS.curChartModelsANOVA{sH})))
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF2';
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF1';
                else
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF';
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=zeros(size(ExFNIRS.curChartModelsANOVA{sH}.DF'));
                end
                
                
                

                
                ExFNIRS.curChartModelsCoefficents_pval{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.pValue';
                ExFNIRS.curChartModelsCoefficents_tstat{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.tStat';
                ExFNIRS.curChartModelsCoefficents_df{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.DF';
                ExFNIRS.curChartModels_ch(sH)=subplotGby{sH}.curCh;
            else
                curBioM=subplotGby{sH}.curBioM{1};
                curRowName=sprintf('%s_%s',chName,curBioM);
                ExFNIRS.curChartModelsCoefficents_pval{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.pValue';
                ExFNIRS.curChartModelsCoefficents_tstat{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.tStat';
                ExFNIRS.curChartModelsCoefficents_df{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.DF';
                
                
                ExFNIRS.curChartModelsANOVACoefficents_pval{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.pValue';
                ExFNIRS.curChartModelsANOVACoefficents_Fstat{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.FStat';
                if(ismember('DF2',properties(ExFNIRS.curChartModelsANOVA{sH})))
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF2';
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF1';
                else
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF';
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=zeros(size(ExFNIRS.curChartModelsANOVA{sH}.DF'));
                end
                
                ExFNIRS.curChartModels_ch(sH)=subplotGby{sH}.curCh;
            end
            disp(curChartLME{sH});
            disp(curChartLME{sH}.anova);
        catch ME
            fprintf(2,'Could not generate model for figure %i\n',sH);
            fprintf(2,'\nLME: %s\n',lmeString);
            fprintf(2,ME.message);
            fprintf(2,'\n');
        end
    end
    
    
    if(showBarChart&&ExFNIRS.settings.ylim_fixed)
        set(subplotHandles{sH},'YLim',[ExFNIRS.settings.ylim_fixed_min, ExFNIRS.settings.ylim_fixed_max]);
    end
end

doublePlotWithFDR=false;
FDRfound=false;

if(showTopo)
    if(~ExFNIRS.settings.LME_enable)
        warning('LME must be enabled');
    else
        
        topoH=figure(2000);
        clf(topoH);
        addDebugAnnotation(topoH);
        
        chNames=ExFNIRS.curChartModelsCoefficents_tstat.Properties.RowNames;
        coefNames=ExFNIRS.curChartModelsCoefficents_tstat.Properties.VariableNames;
        numCoeff=size(ExFNIRS.curChartModelsCoefficents_tstat,2);
        
        numANOVA=size(ExFNIRS.curChartModelsANOVACoefficents_Fstat,2);
        anovaNames=ExFNIRS.curChartModelsANOVACoefficents_Fstat.Properties.VariableNames;
        
         for z=1:length(chNames)
            temp=strsplit(chNames{z},'_');
             switch (ExFNIRS.settings.ChannelMode)
                case 'fNIR'
                         chArr(z)=sscanf(temp{1},'Opt%i');
                case 'ROI'     
                         chArr(z)=sscanf(temp{1},'ROI%i');
                case 'Aux'
            end
            
            bioMarr(z)=temp(end);
         end
         bioMLabel=cell(0,0);
        
        
         
        if(true)%~plotGroupByBioM)
            for b=1:numBioM
              switch(LME_topo_mode)
                    case 'coef'
                        for c=1:numCoeff
                            fNIR_t{b,c}=nan(2,8);
                            fNIR_p{b,c}=nan(2,8);
                            fNIR_df{b,c}=nan(2,8);
                        end
                  case 'anova'
                        for a=1:numANOVA
                            fNIR_f{b,a}=nan(2,8);
                            fNIR_p{b,a}=nan(2,8);
                            fNIR_df{b,a}=nan(2,8);
                            fNIR_df2{b,a}=nan(2,8);
                        end

              end
            end


            
            for coefIdx=1:size(ExFNIRS.curChartModelsCoefficents_tstat,1)
                    
               curCh= chArr(coefIdx);
               curIdx=[rem(curCh-1,2)+1,1+floor((curCh-0.01)/2)];
               curChName=chNames(coefIdx);

               b_idx=strcmp(bioMarr{coefIdx},selectedBioM);
               bioMLabel(b)=selectedBioM(b_idx);
               switch(LME_topo_mode)
                    case 'coef'
   
                       for c=1:numCoeff

                           fNIR_t{b_idx,c}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsCoefficents_tstat{curChName,coefNames(c)};
                           fNIR_p{b_idx,c}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsCoefficents_pval{curChName,coefNames(c)};
                           fNIR_df{b_idx,c}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsCoefficents_df{curChName,coefNames(c)};
                       end
                   case 'anova'
                       for a=1:numANOVA

                           fNIR_f{b_idx,a}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsANOVACoefficents_Fstat{curChName,anovaNames(a)};
                           fNIR_p{b_idx,a}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsANOVACoefficents_pval{curChName,anovaNames(a)};
                           fNIR_df{b_idx,a}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsANOVACoefficents_df1{curChName,anovaNames(a)};
                           fNIR_df2{b_idx,a}(curIdx(1),curIdx(2))=ExFNIRS.curChartModelsANOVACoefficents_df2{curChName,anovaNames(a)};
                       end
               end
            end
                   
            for b=1:numBioM
                if(b==1)
                   sigStr=sprintf('Thresholded at %s=%.2f',ExFNIRS.settings.topoSigThrehold{1},ExFNIRS.settings.topoSigThrehold{2});
                   th=annotation(topoH,'textbox',[0,1,0,0],'String',sigStr,'FitBoxToText','on'); 
                end
               switch(LME_topo_mode)
                    case 'coef'
                        for c=1:numCoeff
                            subplot(numBioM,numCoeff,c+(b-1)*numCoeff)
                            curT=fNIR_t{b,c};
                            curP=fNIR_p{b,c};
                            curDf=fNIR_df{b,c};
                            
                            

                            curQ=performFDR(curP);

                            if(any(curQ<0.05))
                                FDRfound=true;
                                %FDR RESULTS FOUND
                            end

                            switch(ExFNIRS.settings.ChannelMode)
                                case 'fNIR'
                                    interpolateNIR(curT,'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',curP,'TitleText',coefNames{c})%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                case 'ROI'
                                    roiInfo=ExFNIRS.currentROI;
                                    interpolateNIR(mapROIvaluesToCh(roiInfo,curT),'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',mapROIvaluesToCh(roiInfo,curP),'TitleText',coefNames{c})%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                            end
                            if(c==1) % first column
                                ylabel(selectedBioM(b));
                            end
                        end
                   case 'anova'
                       for a=1:numANOVA
                            subplot(numBioM,numANOVA,a+(b-1)*numANOVA)
                            curF=fNIR_f{b,a};
                            curP=fNIR_p{b,a};
                            curDf1=fNIR_df{b,a};
                            curDf2=fNIR_df2{b,a};
                            
                            [curQ,curK]=performFDR(curP,ExFNIRS.settings.topoSigThrehold{2});
                            [curQ_rev,curK_rev]=performFDR_reverse(curP,ExFNIRS.settings.topoSigThrehold{2});
                            
                            estimateFPval=finv(ones(size(curF(:)))*(1-ExFNIRS.settings.topoSigThrehold{2}), curDf1(:), curDf2(:));
                            estimateFPval_q=finv(ones(size(curF(:)))*(1-ExFNIRS.settings.topoSigThrehold{2}/curK), curDf1(:), curDf2(:));
                            estimateFPval_qrev=finv(ones(size(curF(:)))*(1-ExFNIRS.settings.topoSigThrehold{2}/curK_rev), curDf1(:), curDf2(:));
                            
                            switch(ExFNIRS.settings.topoSigThrehold{1})
                                case 'p'

                                case 'q'
                                    estimateFPval=estimateFPval_q;
                                case 'qReverse'
                                    estimateFPval=estimateFPval_qrev;
                            end
                            
                            estimatedPval_min=nanmin(estimateFPval);
                            
                            if(any(curF(:)>=estimatedPval_min))
                                
                                titleSTR=anovaNames{a};

                                if(any(curQ<0.05))
                                    FDRfound=true;
                                    titleSTR=sprintf('%s*',anovaNames{a});
                                    %FDR RESULTS FOUND
                                end

                                switch(ExFNIRS.settings.ChannelMode)
                                    case 'fNIR'
                                        interpolateNIR(curF,'Mode','fstat','fontSize',12,'transparent',true,'lowerThreshold',estimatedPval_min,'TitleText',titleSTR)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                    case 'ROI'
                                        roiInfo=ExFNIRS.currentROI;
                                        interpolateNIR(mapROIvaluesToCh(roiInfo,curF),'Mode','fstat','fontSize',12,'transparent',true,'lowerThreshold',estimatedPval_min,'TitleText',titleSTR)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                end
                                if(a==1) % first column
                                    curAxes=gca;
                                    axesPos=curAxes.OuterPosition;
                                    th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',selectedBioM(b),'FitBoxToText','on');
                                end
                            else
                                plot(0,0);
                                curAxes=gca;
                                axesPos=curAxes.OuterPosition;
                                axis off
                                title(sprintf('%s_N_S',anovaNames{a}));
                                if(a==1) % first column
                                    th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',selectedBioM(b),'FitBoxToText','on');
                                end
                            end
                        end
                       
               end
            end
        end
        
        if(doublePlotWithFDR&&FDRfound)
            topoHfdr=figure(2001);
            clf(topoHfdr);
            addDebugAnnotation(topoHfdr);


                for b=1:numBioM
                    switch(LME_topo_mode)
                     case 'coef'
                        for c=1:numCoeff
                            subplot(numBioM,numCoeff,c+(b-1)*numCoeff)
                            curT=fNIR_t{b,c};
                            curP=fNIR_p{b,c};
                            curQ=performFDR(curP);

                            switch(ExFNIRS.settings.ChannelMode)
                                case 'fNIR'
                                    interpolateNIR(curT,'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',curQ,'TitleText',coefNames{c})%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                case 'ROI'
                                    roiInfo=ExFNIRS.currentROI;
                                    interpolateNIR(mapROIvaluesToCh(roiInfo,curT),'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',mapROIvaluesToCh(roiInfo,curQ),'TitleText',coefNames{c})%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
        %                             maxVal=nanmax([nanmax(abs(curT(:))),1]);
        %                             minVal=nanmin([maxVal+0.1;abs(curT(curP<0.05))]);
        %                             if(maxVal<=minVal)
        %                                 minVal=maxVal;
        %                                 maxVal=maxVal+0.05;
        %                             end
        %                             
        %                             numROI=size(ExFNIRS.currentROI,1);
        %                             vals=abs(curT(1:numROI));
        %                             processFNIRS2.Data.Plot.InterpolateROIvalues(roiInfo,vals,minVal,maxVal,1,coefNames{c},'tstat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                            end
                            if(c==1) % first column
                                ylabel(selectedBioM(b));
                            end
                        end
                        case 'anova'
                           for a=1:numANOVA
                            subplot(numBioM,numANOVA,a+(b-1)*numANOVA)
                            curT=fNIR_f{b,a};
                            curP=fNIR_p{b,a};
                            curQ=performFDR(curP);

                            switch(ExFNIRS.settings.ChannelMode)
                                case 'fNIR'
                                    interpolateNIR(curT,'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',curQ,'TitleText',numANOVA{a})%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                case 'ROI'
                                    roiInfo=ExFNIRS.currentROI;
                                    interpolateNIR(mapROIvaluesToCh(roiInfo,curT),'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',mapROIvaluesToCh(roiInfo,curQ),'TitleText',numANOVA{a})%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
        %                             maxVal=nanmax([nanmax(abs(curT(:))),1]);
        %                             minVal=nanmin([maxVal+0.1;abs(curT(curP<0.05))]);
        %                             if(maxVal<=minVal)
        %                                 minVal=maxVal;
        %                                 maxVal=maxVal+0.05;
        %                             end
        %                             
        %                             numROI=size(ExFNIRS.currentROI,1);
        %                             vals=abs(curT(1:numROI));
        %                             processFNIRS2.Data.Plot.InterpolateROIvalues(roiInfo,vals,minVal,maxVal,1,coefNames{c},'tstat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                            end
                            if(a==1) % first column
                                ylabel(selectedBioM(b));
                            end
                        end
                            
                    end
                end
            suptitle('FDR Edition');
        end
        
    end
end

function [qvalues,k,passed]=performFDR(pvalues,pThreshold)
% Performs FDR correction per #CITATION HERE
if(nargin<2)
    pThreshold=0.05;
end

qvalues=nan(size(pvalues));

kVals=nan(size(pvalues(:)));

[pSorted,pIdx]=sort(pvalues(:));       
numP=length(pSorted);

for i=1:numP
    k=numP-i+1;
    qThreshold=pThreshold/k;
    qvalues(pIdx(i))=pvalues(pIdx(i))*k;
    
    
    kVals(pIdx(i))=k;
    if(any(qvalues(pIdx(i))>pThreshold))
        break;
    end
end

qvalues=pvalues*k;
qvalues(qvalues>1)=1;
passed=qvalues<=pThreshold;

if(any(passed(:)))
   k=min(kVals(passed(:)));
   qvalues=pvalues*k;
end
    
        
function [qvalues,k,passed]=performFDR_reverse(pvalues,pThreshold)
% Performs FDR correction per #CITATION HERE
if(nargin<2)
    pThreshold=0.05;
end

qvalues=nan(size(pvalues));

[pSorted,pIdx]=sort(pvalues(:));       
numP=length(pSorted);
k=length(pvalues(:));
numNan=sum(isnan(pvalues(:)));

for i=numNan:numP-1
    k=i+1;
    qThreshold=pThreshold/k;
    if(sum(pvalues(:)>qThreshold)>=(numP-i))
        qvalues=pvalues*k;
        
       break; 
    end
    
end

qvalues(qvalues>1)=1;
passed=qvalues<=pThreshold;

    

% --- Executes on selection change in popupmenu_bar_feature.
function popupmenu_bar_feature_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_bar_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_bar_feature contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_bar_feature

global ExFNIRS
idx=get(handles.popupmenu_bar_feature,'Value');
strs=get(handles.popupmenu_bar_feature,'String');
ExFNIRS.settings.plot_bar_feature=strs{idx};

% --- Executes during object creation, after setting all properties.
function popupmenu_bar_feature_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_bar_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_barchart_error.
function checkbox_plot_barchart_error_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_barchart_error (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_barchart_error

global ExFNIRS
ExFNIRS.settings.plot_bar_err=get(handles.checkbox_plot_barchart_error,'Value');

% --- Executes on selection change in popupmenu_bar_error_feature.
function popupmenu_bar_error_feature_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_bar_error_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_bar_error_feature contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_bar_error_feature
global ExFNIRS
idx=get(handles.popupmenu_bar_error_feature,'Value');
strs=get(handles.popupmenu_bar_error_feature,'String');
ExFNIRS.settings.plot_bar_err_feature=strs{idx};


% --- Executes during object creation, after setting all properties.
function popupmenu_bar_error_feature_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_bar_error_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_bar_error_multiplier_Callback(hObject, eventdata, handles)
% hObject    handle to edit_bar_error_multiplier (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_bar_error_multiplier as text
%        str2double(get(hObject,'String')) returns contents of edit_bar_error_multiplier as a double
global ExFNIRS
ExFNIRS.settings.plot_bar_err_mult=str2double(get(handles.edit_bar_error_multiplier,'String'));
set(handles.edit_bar_error_multiplier,'String',sprintf('%.1f',ExFNIRS.settings.plot_bar_err_mult));

% --- Executes during object creation, after setting all properties.
function edit_bar_error_multiplier_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_bar_error_multiplier (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_barchart_all_points.
function checkbox_plot_barchart_all_points_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_barchart_all_points (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_barchart_all_points

global ExFNIRS
ExFNIRS.settings.plot_bar_all=get(handles.checkbox_plot_barchart_all_points,'Value');

% --- Executes on button press in checkbox_mark_task.
function checkbox_mark_task_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_mark_task (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_mark_task
global ExFNIRS
ExFNIRS.settings.plot_task_lines=get(handles.checkbox_mark_task,'Value');

% --- Executes on button press in checkbox_shaded_err.
function checkbox_shaded_err_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_shaded_err (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_shaded_err

global ExFNIRS
ExFNIRS.settings.plot_error_shaded=get(handles.checkbox_shaded_err,'Value');


% --- Executes on button press in checkbox_auto_update.
function checkbox_auto_update_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_auto_update (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_auto_update
global ExFNIRS
ExFNIRS.settings.updateOnChange=get(handles.checkbox_auto_update,'Value');

if(ExFNIRS.settings.updateOnChange&&ExFNIRS.UpdateNeeded)
    updateSelectedTable(handles);
end


% --- Executes on selection change in listbox_subgroup.
function listbox_subgroup_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_subgroup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_subgroup contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_subgroup


global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function listbox_subgroup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_subgroup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_use_group.
function checkbox_use_group_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_use_group (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_use_group
global ExFNIRS
ExFNIRS.settings.use_group=get(handles.checkbox_use_group,'Value');
set(handles.checkbox_use_subgroup,'Value',~ExFNIRS.settings.use_group);
if(ExFNIRS.settings.use_group)
    set(handles.listbox_group,'Enable','on');
    set(handles.listbox_subgroup,'Enable','off');
else
    set(handles.listbox_group,'Enable','off');
    set(handles.listbox_subgroup,'Enable','on');
end

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end
% --- Executes on button press in checkbox_use_subgroup.
function checkbox_use_subgroup_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_use_subgroup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_use_subgroup

global ExFNIRS
ExFNIRS.settings.use_group=~get(handles.checkbox_use_subgroup,'Value');
set(handles.checkbox_use_group,'Value',ExFNIRS.settings.use_group);

if(ExFNIRS.settings.use_group)
    set(handles.listbox_group,'Enable','on');
    set(handles.listbox_subgroup,'Enable','off');
else
    set(handles.listbox_group,'Enable','off');
    set(handles.listbox_subgroup,'Enable','on');
end

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on selection change in popupmenu_colors.
function popupmenu_colors_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_colors (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_colors contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_colors
global ExFNIRS
idx=get(handles.popupmenu_colors,'Value');
strs=get(handles.popupmenu_colors,'String');
ExFNIRS.settings.cmap=str2func(strs{idx});

% --- Executes during object creation, after setting all properties.
function popupmenu_colors_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_colors (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_auto_color.
function checkbox_auto_color_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_auto_color (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_auto_color
global ExFNIRS
ExFNIRS.settings.use_gui_color=~get(handles.checkbox_auto_color,'Value');
set(handles.checkbox_gui_colors,'Value',ExFNIRS.settings.use_gui_color);

% --- Executes on button press in checkbox_gui_colors.
function checkbox_gui_colors_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_gui_colors (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_gui_colors
global ExFNIRS
ExFNIRS.settings.use_gui_color=get(handles.checkbox_gui_colors,'Value');
set(handles.checkbox_auto_color,'Value',~ExFNIRS.settings.use_gui_color);

% --- Executes on button press in pushbutton_gui_color_1.
function pushbutton_gui_color_1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(1,:)=uisetcolor(ExFNIRS.settings.guiColor(1,:));
set(handles.pushbutton_gui_color_1,'ForegroundColor',ExFNIRS.settings.guiColor(1,:))


% --- Executes on button press in pushbutton_gui_color_3.
function pushbutton_gui_color_3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(3,:)=uisetcolor(ExFNIRS.settings.guiColor(3,:));
set(handles.pushbutton_gui_color_3,'ForegroundColor',ExFNIRS.settings.guiColor(3,:))

% --- Executes on button press in pushbutton_gui_color_5.
function pushbutton_gui_color_5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(5,:)=uisetcolor(ExFNIRS.settings.guiColor(5,:));
set(handles.pushbutton_gui_color_5,'ForegroundColor',ExFNIRS.settings.guiColor(5,:))

% --- Executes on button press in pushbutton_gui_color_7.
function pushbutton_gui_color_7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(7,:)=uisetcolor(ExFNIRS.settings.guiColor(7,:));
set(handles.pushbutton_gui_color_7,'ForegroundColor',ExFNIRS.settings.guiColor(7,:))

% --- Executes on button press in pushbutton_gui_color_9.
function pushbutton_gui_color_9_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(9,:)=uisetcolor(ExFNIRS.settings.guiColor(9,:));
set(handles.pushbutton_gui_color_9,'ForegroundColor',ExFNIRS.settings.guiColor(9,:))

% --- Executes on button press in pushbutton_gui_color_2.
function pushbutton_gui_color_2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(2,:)=uisetcolor(ExFNIRS.settings.guiColor(2,:));
set(handles.pushbutton_gui_color_2,'ForegroundColor',ExFNIRS.settings.guiColor(2,:))

% --- Executes on button press in pushbutton_gui_color_4.
function pushbutton_gui_color_4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(4,:)=uisetcolor(ExFNIRS.settings.guiColor(4,:));
set(handles.pushbutton_gui_color_4,'ForegroundColor',ExFNIRS.settings.guiColor(4,:))

% --- Executes on button press in pushbutton_gui_color_6.
function pushbutton_gui_color_6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(6,:)=uisetcolor(ExFNIRS.settings.guiColor(6,:));
set(handles.pushbutton_gui_color_6,'ForegroundColor',ExFNIRS.settings.guiColor(6,:))

% --- Executes on button press in pushbutton_gui_color_8.
function pushbutton_gui_color_8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(8,:)=uisetcolor(ExFNIRS.settings.guiColor(8,:));
set(handles.pushbutton_gui_color_8,'ForegroundColor',ExFNIRS.settings.guiColor(8,:))

% --- Executes on button press in pushbutton_gui_color_10.
function pushbutton_gui_color_10_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS

ExFNIRS.settings.guiColor(10,:)=uisetcolor(ExFNIRS.settings.guiColor(10,:));
set(handles.pushbutton_gui_color_10,'ForegroundColor',ExFNIRS.settings.guiColor(10,:))

% --- Executes on button press in pushbutton_gui_color_save.
function pushbutton_gui_color_save_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[file, pathname] = uiputfile({'*.csv';'*.*'},'Export colors list');
if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
    return
end
global ExFNIRS
csvwrite(sprintf('%s/%s',pathname,file),ExFNIRS.settings.guiColor);
% --- Executes on button press in pushbutton_gui_color_load.
function pushbutton_gui_color_load_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_load (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[file, pathname] = uigetfile({'*.csv';'*.*'},'Import colors list');
if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
    return
end

loadGUIcolors(sprintf('%s/%s',pathname,file),handles);

function loadGUIcolors(csvPath,handles)
global ExFNIRS
cRead=csvread(csvPath);

if(size(cRead,1)<=10&&size(cRead,2)==3)
    cRead(cRead>1)=1;
    cRead(cRead<0)=0;
    ExFNIRS.settings.guiColor(1:size(cRead,1),:)=cRead;
    
    updateButtonListColors(handles);
    set(handles.listbox_color_order,'String',cellstr(num2str([1:10]')));
    set(handles.listbox_color_order,'Value',1);

else
    
    error('Expected a (1-10)x3 RGB color matrix');
end


% --- Executes on selection change in popupmenu_legend_mode.
function popupmenu_legend_mode_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_legend_mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_legend_mode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_legend_mode
global ExFNIRS
ExFNIRS.settings.plot_legend_mode=get(handles.popupmenu_legend_mode,'Value');

% --- Executes during object creation, after setting all properties.
function popupmenu_legend_mode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_legend_mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_process_selection.
function pushbutton_process_selection_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_process_selection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

updateSelectedTable(handles);


% --- Executes on selection change in listbox_hierarchy.
function listbox_hierarchy_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_hierarchy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_hierarchy contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_hierarchy
global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function listbox_hierarchy_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_hierarchy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_move_hierarchy_up.
function pushbutton_move_hierarchy_up_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_move_hierarchy_up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

hierarchyStr=get(handles.listbox_hierarchy,'String');
hierarchyVal=get(handles.listbox_hierarchy,'Value');

numHstr=length(hierarchyStr);
if(hierarchyVal==1)
    return;
else
    newInd=[1:hierarchyVal-2,hierarchyVal,hierarchyVal-1,(hierarchyVal+1):numHstr];
    newInd(newInd>numHstr)=[];
    set(handles.listbox_hierarchy,'String',hierarchyStr(newInd));
    set(handles.listbox_hierarchy,'Value',hierarchyVal-1);
end

hierarchyStr=get(handles.listbox_hierarchy,'String');

global ExFNIRS
ExFNIRS.dataHierarchy(2:numHstr+1)=hierarchyStr;


if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes on button press in pushbutton_move_hierarchy_down.
function pushbutton_move_hierarchy_down_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_move_hierarchy_down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hierarchyStr=get(handles.listbox_hierarchy,'String');
hierarchyVal=get(handles.listbox_hierarchy,'Value');

numHstr=length(hierarchyStr);
if(hierarchyVal==numHstr)
    return;
else
    newInd=[1:hierarchyVal-1,hierarchyVal+1,hierarchyVal,(hierarchyVal+2):numHstr];
    newInd(newInd>numHstr)=[];
    set(handles.listbox_hierarchy,'String',hierarchyStr(newInd));
    set(handles.listbox_hierarchy,'Value',hierarchyVal+1);
end

hierarchyStr=get(handles.listbox_hierarchy,'String');
global ExFNIRS
ExFNIRS.dataHierarchy(2:numHstr+1)=hierarchyStr;

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on selection change in popupmenu_within_sub_avg.
function popupmenu_within_sub_avg_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_within_sub_avg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_within_sub_avg contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_within_sub_avg
global ExFNIRS
ExFNIRS.settings.within_sub_avg_mode=get(handles.popupmenu_within_sub_avg,'Value');

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function popupmenu_within_sub_avg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_within_sub_avg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_infoData_barchart.
function pushbutton_infoData_barchart_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_infoData_barchart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global ExFNIRS

if(ExFNIRS.UpdateNeeded)
   updateSelectedTable(handles); 
end

if(~isfield(ExFNIRS,'gby'))
    warning('No groups match selection criteria');
    return;
end

curInfoGroup=ExFNIRS.settings.curInfoGroup;

gbyVars=ExFNIRS.groupByVars;
if(~isempty(curInfoGroup)&&~strcmp(curInfoGroup,'(Time)'))
    [ismem,idx]=ismember(curInfoGroup,gbyVars);
    if(ismem)
        gbyVars(idx)=[];
        useCurInfoGroup=true;
    else
        useCurInfoGroup=false;
    end
else
        
    useCurInfoGroup=false;
end



numGroups=length(ExFNIRS.gby);

if(numGroups==0)
    return;
end

ExFNIRS.figHandles.main=figure(1100);
clf(ExFNIRS.figHandles.main)
cla(ExFNIRS.figHandles.main);
dcm_obj = datacursormode(ExFNIRS.figHandles.main);
set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
% end

num2Plot=numGroups;


gbyStrs=cell(numGroups,1);
curInfoGby=cell(0);
subplotGby=[];
gbyIdx=nan(numGroups,1);

for g=1:numGroups
    gbyStrs{g}='';
   if(~isempty(ExFNIRS.gby(g).gbyTables))
       for i=1:length(gbyVars)
           gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(ExFNIRS.gby(g).gbyTables.(gbyVars{i})(1)));
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(ExFNIRS.gby(g).gbyTables.(curInfoGroup)(1));
       end
   end 
   if(~isempty(gbyStrs{g}))
    gbyStrs{g}(end)='';
   end
end

[uGbyStrs,~,uGroupIdx]=unique(cellstr(gbyStrs));
numUgroups=length(uGbyStrs);


if(ExFNIRS.settings.use_gui_color)
    cIndex=ExFNIRS.settings.guiColor(1:numUgroups,:);
else
    cIndex=ExFNIRS.settings.cmap(numUgroups);%linspecer(num2Plot,'qualitative');
end



if(useCurInfoGroup)
    [uCurInfoG,a,uCurIdx]=unique(cellstr(curInfoGby));
    numCurInfoG=length(uCurInfoG);
    barChartData=nan(max(uCurIdx),numUgroups,3);
else
    barChartData=nan(1,numUgroups,3);
    uCurInfoG='';
    numCurInfoG=1;
end

errorFeature=ExFNIRS.settings.plot_bar_err_feature;
plotFeature=ExFNIRS.settings.plot_bar_feature;
    
gAStrs=cell(numUgroups,1);
gAerrStrs=cell(numUgroups,1);
    
 
curInfoStr=ExFNIRS.settings.curInfoStr;

if(ExFNIRS.settings.within_sub_avg_mode==3)
    dataH=ExFNIRS.dataHierarchy;
elseif(ExFNIRS.settings.within_sub_avg_mode==2)
    dataH='SubjectID';
else
    dataH=[];
end

barGroup=zeros(numCurInfoG,1);

for g=1:numGroups
    curTable=ExFNIRS.gby(g).gbyTables;
    curData=curTable(:,curInfoStr);
    subplotGby.gby(g)=ExFNIRS.gby(g);
    
    if(useCurInfoGroup)
        cBarSec=uCurIdx(g); % which section to put the bar in 
        curBarGroup=uGroupIdx(g);
    else
       cBarSec=1;
       curBarGroup=g;
    end
    
    curData=table2array(curData);
    
    if(isstring(curData))
       warning('Strings return count');
       [~,~,curData]=unique(curData);
       plotFeature='Count';
       % return;
    end
    curData(curData==-9999)=nan;
    
    %switch modes here
    if(strcmp(plotFeature,'Count'))
        curHAvg=length(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
    elseif(strcmp(plotFeature,'Mean'))
        curHAvg=nanmean(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
    elseif(strcmp(plotFeature,'Median'))
        curHAvg=nanmedian(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
    else
        error('Unknown parameter');
        %curHAvg=nanmedian(hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
    end
    
    

    if(ExFNIRS.settings.plot_bar_ga)
          barChartData(cBarSec,curBarGroup,1)=curHAvg;
          gAStrs{curBarGroup}=sprintf('%s',uGbyStrs{curBarGroup}); 
    end

    if(ExFNIRS.settings.plot_bar_err)
        if(~strcmp(plotFeature,'Count'))

          errMulitply=ExFNIRS.settings.plot_bar_err_mult;
         
          gaFeat=curHAvg;
          
          if(strcmp(errorFeature,'MaxMin'))
              curHerr=nanmax(hierarchicalAverage(curData,curTable(:,dataH),@nanmax));
                  
              barChartData(cBarSec,curBarGroup,2)=curHerr;
              curHerr=nanmin(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmin));
              barChartData(cBarSec,curBarGroup,3)=curHerr;
          elseif(strcmp(errorFeature,'SD'))
              curHerr=nanstd(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
              barChartData(cBarSec,curBarGroup,2)=curHerr*errMulitply;
          elseif(strcmp(errorFeature,'SEM'))
              curHerr=nanstd(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
              curN=length(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
              curHerr=curHerr/sqrt(curN);
              barChartData(cBarSec,curBarGroup,2)=curHerr*errMulitply;
          end
          
          gAErrStrs{curBarGroup}=sprintf('%s',gbyStrs{g});
        else
            curHerr=0;
            barChartData(cBarSec,curBarGroup,2)=curHerr;
            gAErrStrs{curBarGroup}='';
        end
    end

end
    
    
    

if(isempty(barChartData))
    warning('All data is missing');
    return
elseif(sum(~isnan(barChartData(:,:,1)))==0)
    warning('All data is missing');
    return
end

if(ExFNIRS.settings.plot_bar_err)
    pf2_base.external.barweb(barChartData(:,:,1),barChartData(:,:,2),1,uCurInfoG, [], [], [], cIndex,[],gAStrs,[],'hide');
    ylimLower=min(min(barChartData(:,:,1)))-max(max(barChartData(:,:,2)));
    ylimUpper=max(max(barChartData(:,:,1)))+max(max(barChartData(:,:,2)));
    yrange=ylimUpper-ylimLower;
    ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
    ylabel(sprintf('%s %s   +/- (%s)',plotFeature,curInfoStr,errorFeature));
    
    if(useCurInfoGroup)
       title(sprintf('%s by %s',curInfoStr,curInfoGroup)); 
       xlabel(curInfoGroup);
    end
else
    pf2_base.external.barweb(barChartData(:,:,1),[],1,uCurInfoG, [], [], [], cIndex,[],gAStrs,[],'hide');
    ylimLower=min(min(barChartData(:,:,1)));
    ylimUpper=max(max(barChartData(:,:,1)));
    yrange=ylimUpper-ylimLower;
    ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
    ylabel(sprintf('%s %s   +/- (%s)',plotFeature,curInfoStr,errorFeature));
    
    if(useCurInfoGroup)
       title(sprintf('%s by %s',curInfoStr,curInfoGroup)); 
       xlabel(curInfoGroup);
    end
end

if(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2))
    legend(gAStrs(:));
    legend boxoff;
end

fprintf('Info Table Values\n');
for i=1:length(gAStrs(:))
    fprintf('%s\tMean %.2f\tError: %.2f\n',gAStrs{i},barChartData(1,i,1),barChartData(1,i,2));
end
        
hold off;
   
if(ExFNIRS.settings.LME_enable)
    x=ExFNIRS.groupByVars;
    curLMEGbyString='';

    useAllInteractions=ExFNIRS.settings.LME_all_interactions;

    %mdlPrtString='Time';

    if(useAllInteractions)
        
        for i=1:length(x)
            curLMEGbyString=sprintf('%s*%s',curLMEGbyString,x{i});
        end
    else
        for i=1:length(x)
             curLMEGbyString=sprintf('%s+%s',curLMEGbyString,x{i});
        end
    end
    
    if(~isempty(curLMEGbyString))
        curLMEGbyString(1)=[];
    end
    
    
    if(ExFNIRS.settings.LME_use_customStr&&~isempty(ExFNIRS.settings.LME_customStr))
        lmeString=sprintf('%s~%s+(%s)',ExFNIRS.settings.curInfoStr,ExFNIRS.settings.LME_customStr,ExFNIRS.settings.LME_randomFxStr);
    elseif(ExFNIRS.settings.LME_use_intercept)
        lmeString=sprintf('%s~%s+(%s)',ExFNIRS.settings.curInfoStr,curLMEGbyString,ExFNIRS.settings.LME_randomFxStr);
    else
       lmeString=sprintf('%s~-1+%s+(%s)',ExFNIRS.settings.curInfoStr,curLMEGbyString,ExFNIRS.settings.LME_randomFxStr);
    end
    

    try
        curInfoChartLME=fitlme(ExFNIRS.selectedTable,lmeString);
%         curInfoChartLME_emm= pf2_base.external.emmeans(curInfoChartLME, {'orig'}, 'effects');
%         h = emmip(curInfoChartLME_emm,'orig');

        fprintf('Info Chart LME model: %s',ExFNIRS.settings.curInfoStr);
        if(useAllInteractions)
            fprintf(' - All Interactions\n');
        else
            fprintf(' - No Interactions\n');
        end
        ExFNIRS.curInfoChartModel=curInfoChartLME;
        disp(curInfoChartLME);
        disp(curInfoChartLME.anova);
    catch ME
        warning('Could not generate model for info figure %s',ExFNIRS.settings.curInfoStr);
        warning(ME.message);
    end
end
     

% --- Executes on selection change in popupmenu_info_field.
function popupmenu_info_field_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_info_field (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_info_field contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_info_field
global ExFNIRS

strs=get(handles.popupmenu_info_field,'String');
val=get(handles.popupmenu_info_field,'Value');

selStr=strs{val};

ExFNIRS.settings.curInfoStr=selStr;

% --- Executes during object creation, after setting all properties.
function popupmenu_info_field_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_info_field (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in popupmenu_info_group.
function popupmenu_info_group_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_info_group (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_info_group contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_info_group

global ExFNIRS

strs=get(handles.popupmenu_info_group,'String');
val=get(handles.popupmenu_info_group,'Value');

selStr=strs{val};

ExFNIRS.settings.curInfoGroup=selStr;

updateInfoGroupByVars(handles);

% --- Executes during object creation, after setting all properties.
function popupmenu_info_group_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_info_group (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_ylim_fixed.
function checkbox_ylim_fixed_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_ylim_fixed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_ylim_fixed
global ExFNIRS

ExFNIRS.settings.ylim_fixed=get(handles.checkbox_ylim_fixed,'Value');

if(ExFNIRS.settings.ylim_fixed)
   set(handles.checkbox_ylim_manual,'Value',0); 
   ExFNIRS.settings.ylim_manual=false;
end

% --- Executes on button press in checkbox_ylim_manual.
function checkbox_ylim_manual_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_ylim_manual (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_ylim_manual

global ExFNIRS

ExFNIRS.settings.ylim_manual=get(handles.checkbox_ylim_manual,'Value');

if(ExFNIRS.settings.ylim_manual)
   set(handles.checkbox_ylim_fixed,'Value',0); 
   ExFNIRS.settings.ylim_fixed=false;
end


function edit_ylim_min_Callback(hObject, eventdata, handles)
% hObject    handle to edit_ylim_min (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_ylim_min as text
%        str2double(get(hObject,'String')) returns contents of edit_ylim_min as a double
global ExFNIRS

ExFNIRS.settings.ylim_manual_min=str2double(get(handles.edit_ylim_min,'String'));
set(handles.edit_ylim_min,'String',sprintf('%.2f',ExFNIRS.settings.ylim_manual_min));

% --- Executes during object creation, after setting all properties.
function edit_ylim_min_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_ylim_min (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_ylim_max_Callback(hObject, eventdata, handles)
% hObject    handle to edit_ylim_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_ylim_max as text
%        str2double(get(hObject,'String')) returns contents of edit_ylim_max as a double
global ExFNIRS

ExFNIRS.settings.ylim_manual_max=str2double(get(handles.edit_ylim_max,'String'));
set(handles.edit_ylim_max,'String',sprintf('%.2f',ExFNIRS.settings.ylim_manual_max));

% --- Executes during object creation, after setting all properties.
function edit_ylim_max_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_ylim_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_plot_scatter.
function pushbutton_plot_scatter_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_plot_scatter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% if one timepoint 
% 	if multi biomarker + multichannels
% 	groupby x channels (fig biomarker)
% 	if 1 biomarker + mult channels
% 	groupby x channels
% 	if 1 channel + mult biomarker
% 	groupby x biomarkers
% 	if 1 channel + 1 biomarker
% 	groupby
% if 1 groups
% 	biomarker mode
% 	if 1 timepoint
% 	groupby x channels
% 	if multi timepoints
% 	groupby x time   (fig channels)
% if no groupby
% 	if one timepoint
% 		biomarker x channels
% 	if multitimepoints & multi channel
% 		time x channels (fig biomarker)
% 	if multitimepoints & 1 channel
% 		time x biomarker


global ExFNIRS


if(ExFNIRS.UpdateNeeded)
   updateSelectedTable(handles); 
end

if(~isfield(ExFNIRS,'gby'))
    warning('No groups match selection criteria');
    return;
end

curInfoGroup=ExFNIRS.settings.curInfoGroup;

gbyVars=ExFNIRS.groupByVars;
if(~isempty(curInfoGroup)&&~strcmp(curInfoGroup,'(Time)'))
    [ismem,idx]=ismember(curInfoGroup,gbyVars);
    if(ismem)
        gbyVars(idx)=[];
        useCurInfoGroup=true;
    else
        useCurInfoGroup=false;
    end
else
    useCurInfoGroup=false;
end

numGroups=length(ExFNIRS.gby);

biomStrs=get(handles.listbox_biomarker,'String');
selBioM=get(handles.listbox_biomarker,'Value');
selectedBioM=biomStrs(selBioM);
numBioM=length(selBioM);

optStrs=get(handles.listbox_optode,'String');
selOpt=get(handles.listbox_optode,'Value');
selectedOptStr=optStrs(selOpt',:);
numOpt=length(selOpt);

if(numOpt==0||numGroups==0||numBioM==0)
    return;
end


if(ExFNIRS.settings.ylim_fixed)
    ExFNIRS.settings.ylim_fixed_min=inf;
    xlim_fixed_min=inf;
    ExFNIRS.settings.ylim_fixed_max=-inf;
    xlim_fixed_max=-inf;
end


% end

gbyStrs=cell(numGroups,1);
curInfoGby=cell(0);

for g=1:numGroups
    gbyStrs{g}='';
   if(~isempty(ExFNIRS.gby(g).gbyTables))
       for i=1:length(gbyVars)
           gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(ExFNIRS.gby(g).gbyTables.(gbyVars{i})(1)));
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(ExFNIRS.gby(g).gbyTables.(curInfoGroup)(1));
       end
   end 
   if(~isempty(gbyStrs{g}))
        gbyStrs{g}(end)='';
   end
end

numUgroups=length(unique(cellstr(gbyStrs)));

if(numUgroups==1)
    num2Plot=numBioM;
    plotGroupByBioM=true;
    temp=table2cell(pf2_base.getBioColors())';
    for i=1:size(temp,1)
       cIndex(i,:)=temp{i,:}; 
    end
    cIndex=cIndex(selBioM,:);
else
    num2Plot=numGroups;
    plotGroupByBioM=false;
    if(ExFNIRS.settings.use_gui_color)
        cIndex=ExFNIRS.settings.guiColor(1:numUgroups,:);
    else
        cIndex=ExFNIRS.settings.cmap(numUgroups);%linspecer(num2Plot,'qualitative');
    end
end



barChartTimes=[];
for i=1:numGroups
    curGrandTime=ExFNIRS.gby(i).gbyGrandBar.time;
    barChartTimes=[barChartTimes;curGrandTime];
end
barChartTimes=sort(unique(round(barChartTimes)));

[uCurInfoG,firstCurIdx,uCurIdx]=unique(cellstr(curInfoGby));
numCurInfoG=max(uCurIdx);
uCurGIdxCount=nan(size(uCurIdx));
for i =1:numCurInfoG
    uCurGIdxCount(uCurIdx==i)=1:sum(uCurIdx==i);
end

if(~useCurInfoGroup||isnan(numCurInfoG))
   useCurInfoGroup=false;
   numCurInfoG=1; 
   uCurInfoG='';
end


barChartTimes=barChartTimes(barChartTimes<ExFNIRS.settings.plot_end&barChartTimes>=ExFNIRS.settings.plot_start);
numChartTimes=length(barChartTimes);
errorFeature=ExFNIRS.settings.plot_bar_err_feature;
plotFeature=ExFNIRS.settings.plot_bar_feature;

if(strcmp(plotFeature,'Count')&&ExFNIRS.settings.plot_bar_ga)
    plotFeature='N';
    plotCount=true;
else
    plotCount=false;
end

if(plotGroupByBioM)
    subplotHandles=cell(numOpt*numCurInfoG*numChartTimes,1);
else
    subplotHandles=cell(numOpt*numBioM*numChartTimes*numCurInfoG,1);
end

if(~plotGroupByBioM)
	if(numChartTimes>1)
		if(numOpt>1&&numCurInfoG>1)
			xType='groupby';
			yType='time';
			figType='bio,channels';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
		elseif(numOpt==1&&numCurInfoG>1)
			xType='groupby';
			yType='time';
			figType='bioM';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='time';
			yType='channels';
			figType='bioM';
            numSubX=numChartTimes;
            numSubY=numOpt;
		else
			xType='time';
			yType='bioM';
			figType='';
            numSubX=numChartTimes;
            numSubY=numBioM;
		end
	else
		if(numOpt>1&&numCurInfoG>1)
			xType='groupby';
			yType='channels';
			figType='bioM';
            numSubX=numCurInfoG;
            numSubY=numOpt;
		elseif(numOpt==1&&numCurInfoG>1)
			xType='groupby';
			yType='bioM';
			figType='';
            numSubX=numCurInfoG;
            numSubY=numBioM;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='channels';
			yType='bioM';
			figType='';
            numSubX=numOpt;
            numSubY=numBioM;
		else
			xType='bioM';
			yType='';
			figType='';
            numSubX=numBioM;
            numSubY=1;
		end
	end
else %plot with biomarkers embedded
	if(numChartTimes>1)
		if(numOpt>=1&&numCurInfoG>1)
			xType='groupby';
			yType='time';
			figType='channels';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='time';
			yType='channels';
			figType='';
            numSubX=numChartTimes;
            numSubY=numOpt;
		else
			xType='time';
			yType='';
			figType='';
            numSubX=numChartTimes;
            numSubY=1;
		end
	else
		if(numOpt>=1&&numCurInfoG>1)
			xType='groupby';
			yType='channels';
			figType='';
            numSubX=numCurInfoG;
            numSubY=numOpt;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='channels';
			yType='';
			figType='';
            numSubX=numOpt;
            numSubY=1;
		else
			xType='';
			yType='';
			figType='';
            numSubX=1;
            numSubY=1;
		end
	end
end

switch(figType)
    case 'channels'
        for i=1:numOpt
            sH{i,1}.h=figure(1200+i);
            clf(sH{i,1}.h);
            dcm_obj = datacursormode(sH{i,1}.h);
            set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
            for s=1:(numSubX*numSubY)
                xInd=rem(s,numSubX);
                if(xInd==0)
                    xInd=numSubX;
                end
                h=subplot(numSubY,numSubX,s);
                sH{i,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                legend(h, 'off');
            end
        end
    case 'bioM'
        for i=1:numBioM
            sH{i,1}.h=figure(1200+i);
            clf(sH{i,1}.h);
            dcm_obj = datacursormode(sH{i,1}.h);
            set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
            for s=1:(numSubX*numSubY)
                xInd=rem(s,numSubX);
                if(xInd==0)
                    xInd=numSubX;
                end
                h=subplot(numSubY,numSubX,s);
                sH{i,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                legend(h, 'off');
            end
        end
    case 'bio,channels'
        for i=1:numOpt
            for b=1:numBioM
                sH{i,b}.h=figure(1200+i+50*b);
                clf(sH{i,b}.h);
                dcm_obj = datacursormode(sH{i,b}.h);
                set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
                for s=1:(numSubX*numSubY)
                    xInd=rem(s,numSubX);
                    if(xInd==0)
                        xInd=numSubX;
                    end
                    h=subplot(numSubY,numSubX,s);
                    sH{i,b}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                    legend(h, 'off');
                end
            end

        end
    otherwise
        sH{1,1}.h=figure(1200);
        clf(sH{1,1}.h);
        dcm_obj = datacursormode(sH{1,1}.h);
        set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
        for s=1:(numSubX*numSubY)
            xInd=rem(s,numSubX);
            if(xInd==0)
                xInd=numSubX;
            end
            h=subplot(numSubY,numSubX,s);
            sH{1,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
            legend(h, 'off');
        end
end

curSx=1;
curSy=1;
curFigIdx=[1,1];


curInfoStr=ExFNIRS.settings.curInfoStr;

if(ExFNIRS.settings.within_sub_avg_mode==3)
    dataH=ExFNIRS.dataHierarchy;
elseif(ExFNIRS.settings.within_sub_avg_mode==2)
    dataH='SubjectID';
else
    dataH=[];
end

for chIdx=1:numOpt
    
    if(strcmp(figType,'channels'))
        figure(sH{chIdx}.h);
        curFigIdx=[chIdx,1];
    elseif(strcmp(xType,'channels'))
        curSx=chIdx;
    elseif(strcmp(yType,'channels'))
        curSy=chIdx;
    end
    
    ch=selOpt(chIdx);
    legendGFXhandles{1}=[];
    legendGFXstrs{1}=cell(0);
    
    if(plotGroupByBioM)
        num2Plot=numBioM;
    elseif(numUgroups>1)
        num2Plot=numUgroups;
    end
    
    %barChartTimes=times;
    
    pointStrs=cell(num2Plot,1);
    gAStrs=cell(num2Plot,1);
    gAerrStrs=cell(num2Plot,1);
    
    for b=1:numBioM
        bioM=selectedBioM(b);
        if(iscell(bioM))
            bioM=bioM{1};
        end
        
        if(strcmp(figType,'bio,channels'))
            figure(sH{chIdx,b}.h);
            datacursormode(sH{chIdx,b}.h)
            curFigIdx=[chIdx,b];
        elseif(strcmp(figType,'bioM'))
            figure(sH{b,1}.h);
            datacursormode(sH{b,1}.h)
            curFigIdx=[b,1];
        elseif(strcmp(xType,'bioM'))
            curSx=b;
        elseif(strcmp(yType,'bioM'))
            curSy=b;
        end
        
        
        if(numUgroups>1)
            curChart=b;
        else
            curChart=1;
        end
        
        
        for g=1:numGroups
            curGrand=ExFNIRS.gby(g).gbyGrandBar;
            curTable=ExFNIRS.gby(g).gbyTables;
            curData=curTable(:,curInfoStr);
            
            curData=table2array(curData);
    
            if(isstring(curData))
               warning('Strings return count');
               [~,~,curData]=unique(curData);
               plotFeature='Count';
               % return;
            end
            curData(curData==-9999)=nan;
            
            if(useCurInfoGroup)
                curGroupInfoIdx=uCurIdx(g);
                curGroupIdxOffset=(curGroupInfoIdx-1)*numChartTimes;
                curUgroupIdx=uCurGIdxCount(g);
            else
                curGroupInfoIdx=1;
                curGroupIdxOffset=0;
                curUgroupIdx=g;
            end
            
            if(useCurInfoGroup)
                if(strcmp(xType,'groupby'))
                    curSx=curGroupInfoIdx;
                elseif(strcmp(yType,'groupby'))
                    curSy=curGroupInfoIdx;
                end
            end
            
            if(strcmp(plotFeature,'Count'))
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nnz);
            elseif(strcmp(plotFeature,'Mean'))
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean);
            elseif(strcmp(plotFeature,'Median'))
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmedian);
            else
                error('Unknown parameter');
                %curHAvg=nanmedian(hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
            end
            
            if(numChartTimes==0)
                error('No data in selected time range!');
            end
            
            for t=1:numChartTimes
                if(strcmp(xType,'time'))
                    curSx=t;
                elseif(strcmp(yType,'time'))
                    curSy=t;
                end
                
                curPlotHandle=sH{curFigIdx(1),curFigIdx(2)}.subH{curSy,curSx};
                lastSubPlot=(curSy==numSubY&&curSx==numSubX);
                hold(curPlotHandle,'on')
                
                
                [timeIdx,timeIdxRev]=ismember(round(curGrand.time),barChartTimes(t));
                timeIdxRev=timeIdxRev(timeIdxRev>0);
                
                
                
              switch(ExFNIRS.settings.ChannelMode)
                  case 'fNIR'
                      data2plot=curGrand.(bioM);
                  case 'ROI'
                      if(~pf2_base.isnestedfield(curGrand,'ROI.HbO.data'))
                          error('ROI data must be calculated using a build ROI step');
                      end
                          
                      data2plot=curGrand.ROI.(bioM);
                  case 'Aux'

              end 
                curFeatureY=permute(data2plot.data(timeIdx,ch,:),[3,1,2]);
                
                if(strcmp(plotFeature,'Count'))
                    [curFeatureY]=pf2_base.hierarchicalAverage(curFeatureY,curGrand.info.Hierarchy,@nnz);
                elseif(strcmp(plotFeature,'Mean'))
                    [curFeatureY]=pf2_base.hierarchicalAverage(curFeatureY,curGrand.info.Hierarchy,@nanmean);
                elseif(strcmp(plotFeature,'Median'))
                    [curFeatureY]=pf2_base.hierarchicalAverage(curFeatureY,curGrand.info.Hierarchy,@nanmedian);
                else
                    error('Unknown parameter');
                    %curHAvg=nanmedian(hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
                end
                
                if(length(curFeatureY)~=length(curHAvg))
                    if(length(curFeatureY)>length(curHAvg))
                        curFeatureY=curFeatureY(ismember(curGrand.info.Observation,outH));
                    else
                        temp=nan(size(curFeatureY));
                        temp(ismember(outH,curGrand.info.Observation))=curFeatureY;
                        curFeatureY=temp;
                    end
                end
                
                if(~plotGroupByBioM||numBioM==1)
                     %gAStrs{curUgroupIdx,curChart}=sprintf('%s',gbyStrs{curUgroupIdx}); 
                     sColor=cIndex(curUgroupIdx,:);
                elseif(numBioM>1)
                     %gAStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
                     sColor=cIndex(b,:);
                end
               
                
                if(ExFNIRS.settings.plot_scatter_nonparametric)
                    
                    validIdx=sum([isnan(curHAvg),isnan(curFeatureY)],2)==0;
                    validIdx=validIdx&(~isempty(curHAvg)&&~isempty(curFeatureY));
                    xVals=curHAvg(validIdx);
                    yVals=curFeatureY(validIdx);
                    
                    [~,p] = sort(xVals,'descend');
                    r = 1:length(xVals);
                    r(p) = r;
                    xVals=r';
                    
                    [~,p] = sort(yVals,'descend');
                    r = 1:length(yVals);
                    r(p) = r;
                    yVals=r';
                    
                    validIdx=sum([isnan(xVals),isnan(yVals)],2)==0;
                    validIdx=validIdx&(~isempty(curHAvg)&&~isempty(curFeatureY));
                    
                    xVals=xVals(validIdx);
                    yVals=yVals(validIdx);
                    N=length(xVals);
                else
                    validIdx=sum([isnan(curHAvg),isnan(curFeatureY)],2)==0;
                    validIdx=validIdx&(~isempty(curHAvg)&&~isempty(curFeatureY));
                    xVals=curHAvg(validIdx);
                    yVals=curFeatureY(validIdx);
                    N=length(xVals);
                end
                
                if(ExFNIRS.settings.plot_scatter_flipxy)
                    temp=xVals;
                    xVals=yVals;
                    yVals=temp;
                end
                
                
                sHdots=scatter(curPlotHandle,xVals,yVals,25,sColor,'filled');
                if(~plotGroupByBioM)
                   pointStrs{curUgroupIdx}= gbyStrs{g};
                   curPointStr=pointStrs{curUgroupIdx};
                   %if(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&lastSubPlot))
                       sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{curUgroupIdx}=sHdots;
                   %end
                else
                   pointStrs{b}=bioM;
                   curPointStr=bioM;
                  %if(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&lastSubPlot))
                       sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{b}=sHdots;
                   %end
                end 
                
                tagStr=sprintf('%s',curPointStr); 
                set(sHdots,'tag',tagStr);
                
                
                if(plotGroupByBioM&&numBioM>1)
                    curFeatureString=sprintf('\\Delta[X]');
                else
                    curFeatureString=sprintf('\\Delta[%s]',bioM);
                end
                
                if(ExFNIRS.settings.plot_scatter_nonparametric)
                    curFeatureString=sprintf('Rank %s',curFeatureString);
                end
                
                switch(xType)
                    case 'time'
                        title(curPlotHandle,sprintf('t=%i',round(barChartTimes(t))));
                    case 'groupby'
                        title(curPlotHandle,curInfoGby{g});
                    case 'channels'
                        title(curPlotHandle,sprintf('Opt. %i',ch));
                    case 'bioM'
                        title(curPlotHandle,bioM);
                end

                
                if(ExFNIRS.settings.plot_scatter_flipxy)

                    switch(yType)
                        case 'time'
                            ylabel(curPlotHandle,{sprintf('t=%i',round(barChartTimes(t)));curInfoStr});
                        case 'groupby'
                            ylabel(curPlotHandle,{curInfoGby{g};curInfoStr});
                        case 'channels'
                            ylabel(curPlotHandle,{sprintf('Opt. %i',ch);curInfoStr});
                        case 'bioM'
                            ylabel(curPlotHandle,{bioM,curInfoStr});
                        otherwise
                            ylabel(curPlotHandle,curInfoStr);
                    end
                    xlabel(curPlotHandle,curFeatureString);
                else


                    switch(yType)
                        case 'time'
                            ylabel(curPlotHandle,{sprintf('t=%i',round(barChartTimes(t)));curFeatureString});
                        case 'groupby'
                            ylabel(curPlotHandle,{curInfoGby{curUgroupIdx};curFeatureString});
                        case 'channels'
                            ylabel(curPlotHandle,{sprintf('Opt. %i',ch);curFeatureString});
                        case 'bioM'
                            if(numBioM>1)
                                ylabel(curPlotHandle,{bioM,curFeatureString});
                            else
                                ylabel(curPlotHandle,curFeatureString);
                            end
                        otherwise
                            ylabel(curPlotHandle,curFeatureString);
                    end
                    if(ExFNIRS.settings.plot_scatter_nonparametric)
                        xlabel(curPlotHandle,sprintf('Rank %s',curInfoStr));
                    else
                        xlabel(curPlotHandle,curInfoStr);
                    end
                end
                
                
                
                if(ExFNIRS.settings.plot_scatter_line||ExFNIRS.settings.plot_scatter_err)
                    if(N>2)
                        [coefficients,PolyS] = polyfit(xVals, yVals, 1);
                        CI = pf2_base.external.polyparci(coefficients,PolyS);
                        xFit = linspace(min(xVals), max(xVals), 1000);
                        [yFit,deltaY] = polyval(coefficients, xFit,PolyS);
                        
                        if(ExFNIRS.settings.plot_scatter_extend)
                            curXlim=xlim(curPlotHandle);
                            xFitExtend = linspace(min(curXlim), max(curXlim), 1000);
                            yFitExtend = polyval(coefficients, xFitExtend);
                        end

                        errMulitply=ExFNIRS.settings.plot_bar_err_mult;
                        %CI=[0,0;0,0];
                        
                        yEst=polyval(coefficients, xVals,PolyS);
                        yDiff=yVals-yEst;
                        SD=std(yDiff);

                        %SD=sqrt(N)*(CI(:,2)-CI(:,1))'/3.92;
                        SEM=SD/sqrt(N);

                        switch(ExFNIRS.settings.plot_scatter_err_feature)
                            case 'SEM'
                                %yCI_Upper = polyval(coefficients+SEM*errMulitply, xFit);
                                %yCI_Lower = polyval(coefficients-SEM*errMulitply, xFit);
                                yCI_Upper = yFit+SEM*errMulitply;
                                yCI_Lower = yFit-SEM*errMulitply;
                            case 'SD'
                                %yCI_Upper = polyval(coefficients+SD*errMulitply, xFit);
                                %yCI_Lower = polyval(coefficients-SD*errMulitply, xFit);
                                yCI_Upper = yFit+SD*errMulitply;
                                yCI_Lower = yFit-SD*errMulitply;
                            case '95%CI'
                                yCI_Upper = polyval(CI(1,:), xFit);
                                yCI_Lower = polyval(CI(2,:), xFit);
                            case '50%PI'
                                yCI_Upper = yFit+deltaY*(tinv(0.50,(N-1)));
                                yCI_Lower = yFit-deltaY*(tinv(0.50,(N-1)));
                            case '67%PI'
                                yCI_Upper = yFit+deltaY*(tinv(0.67,(N-1)));
                                yCI_Lower = yFit-deltaY*(tinv(0.67,(N-1)));
                            case '90%PI'
                                yCI_Upper = yFit+deltaY*(tinv(0.90,(N-1)));
                                yCI_Lower = yFit-deltaY*(tinv(0.90,(N-1)));
                            case '95%PI'
                                yCI_Upper = yFit+deltaY*(tinv(0.95,(N-1)));
                                yCI_Lower = yFit-deltaY*(tinv(0.95,(N-1)));
                        end
                    end
                end
                
                

                if(ExFNIRS.settings.plot_scatter_err&&N>2)
                    errStyle=ExFNIRS.settings.plot_scatter_error_style;
                    
                    plotShaded=false;
                    
                    switch(errStyle)
                        case 'Dashed'
                            errStyle='--';
                            lineWidth=2;
                        case 'Fine'
                            errStyle='-';
                            lineWidth=0.5;
                        case 'Shaded'
                            errStyle='-';
                            lineWidth=0.5;
                            plotShaded=true;
                        otherwise
                            error('Unspecified error style');
                    end
                    
                    errColor=sColor+(1-sColor)*0.55;
                    if(plotShaded)
                          errAlpha=0.15;
                          yPatch=[yCI_Lower,fliplr(yCI_Upper)];
                          xPatch=[xFit,fliplr(xFit)];
                          %xPatch(isnan(yPatch))=[];
                          %yPatch(isnan(yPatch))=[];

                          h=patch(curPlotHandle,xPatch,yPatch,-1,'facecolor',errColor,'edgecolor','none','facealpha',errAlpha);
                          set(h,'HandleVisibility','off');
                          set(h,'HitTest','off');
                          set(h.Annotation.LegendInformation,'IconDisplayStyle','off');
                    end
                    
                    h=plot(curPlotHandle,xFit,yCI_Upper,'LineStyle',errStyle,'Color',errColor,'LineWidth',lineWidth);
                    set(h.Annotation.LegendInformation,'IconDisplayStyle','off');
                    h=plot(curPlotHandle,xFit,yCI_Lower,'LineStyle',errStyle,'Color',errColor,'LineWidth',lineWidth);
                    set(h.Annotation.LegendInformation,'IconDisplayStyle','off');
                else
                      if(numUgroups>1||numBioM==1)
                           gAErrStrs{curGroupInfoIdx}=''; 
                      elseif(numBioM>1)
                           gAErrStrs{b}='';
                      end 
                end
                
                if(ExFNIRS.settings.plot_scatter_line&&N>2)
                    hold(curPlotHandle,'on')
                    if(ExFNIRS.settings.plot_scatter_extend)
                        gaH=plot(curPlotHandle,xFitExtend, yFitExtend, 'r-', 'LineWidth', 2,'Color',sColor);
                    else
                        gaH=plot(curPlotHandle,xFit, yFit, 'r-', 'LineWidth', 2,'Color',sColor);
                    end
                    
                    set(gaH.Annotation.LegendInformation,'IconDisplayStyle','off');
                    
                    [rho,pval] = corr(xVals,yVals,'Type','Spearman');


                    [r,p]=corr(xVals,yVals,'Type','Pearson');

                    if(~plotGroupByBioM)
                       fitStr=gbyStrs{g};
                       gAStrs{curUgroupIdx}= fitStr;
                       %if(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&lastSubPlot))
                           sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{curUgroupIdx}=gaH;
                       %end
                    else
                       gAStrs{b}=bioM;
                       fitStr=bioM;
                       %if(ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&lastSubPlot))
                           sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{b}=gaH;
                       %end
                    end

                    tagStr=sprintf('%s (N %i)\nRho=%.3f, p=%.4f\nr=%.3f p=%.4f',fitStr,N,rho,pval,r,p); 
                    set(gaH,'tag',tagStr);
                elseif(~ExFNIRS.settings.plot_scatter_line)
                    %sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h=cell(0);
                    %gAStrs=cell(0);
                end
                
                
                curLgdHandles=sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h(:);
                numCurLgd=length(curLgdHandles);
                numFilled=0;
                for i=1:numCurLgd
                	numFilled=numFilled+~isempty(curLgdHandles{i});
                end
                
                if(ExFNIRS.settings.ylim_fixed)
                    ylim(curPlotHandle,'auto');
                    cylim=ylim(curPlotHandle);
                    ExFNIRS.settings.ylim_fixed_min=min(ExFNIRS.settings.ylim_fixed_min,cylim(1));
                    ExFNIRS.settings.ylim_fixed_max=max(ExFNIRS.settings.ylim_fixed_max,cylim(2));
                    
                    xlim(curPlotHandle,'auto');
                    cxlim=xlim(curPlotHandle);
                    xlim_fixed_min=min(xlim_fixed_min,cxlim(1));
                    xlim_fixed_max=max(xlim_fixed_max,cxlim(2));
                elseif(ExFNIRS.settings.ylim_manual)
                    if(ExFNIRS.settings.plot_scatter_flipxy)
                        if(~plotCount)
                            xlim(curPlotHandle,[ExFNIRS.settings.ylim_manual_min,ExFNIRS.settings.ylim_manual_max]);
                        else
                            xlim(curPlotHandle,[0,ExFNIRS.settings.ylim_manual_max]);
                        end
                    else
                        if(~plotCount)
                            ylim(curPlotHandle,[ExFNIRS.settings.ylim_manual_min,ExFNIRS.settings.ylim_manual_max]);
                        else
                            ylim(curPlotHandle,[0,ExFNIRS.settings.ylim_manual_max]);
                        end
                    end
                elseif(plotCount)
                    if(ExFNIRS.settings.plot_scatter_flipxy)
                        cxlim=xlim(curPlotHandle);
                        xlim(curPlotHandle,[0,cxlim(2)]);
                    else
                        cylim=ylim(curPlotHandle);
                        ylim(curPlotHandle,[0,cylim(2)]);
                    end

                else
                    ylim(curPlotHandle,'auto');
                end
                
            end
                
        end
    end
end

if(plotCount)
    if(ExFNIRS.settings.plot_scatter_flipxy)
        xlim_fixed_min=0;
    else
        ExFNIRS.settings.ylim_fixed_min=0; 
    end
end


for i=1:size(sH,1)
    for b=1:size(sH,2)
        for x=1:numSubX
            for y=1:numSubY
                if(ExFNIRS.settings.ylim_fixed)
                    ylim(sH{i,b}.subH{y,x},[ExFNIRS.settings.ylim_fixed_min,ExFNIRS.settings.ylim_fixed_max]);
                    xlim(sH{i,b}.subH{y,x},[xlim_fixed_min,xlim_fixed_max]);
                end
                
                if((ExFNIRS.settings.plot_legend_mode==3||(ExFNIRS.settings.plot_legend_mode==2&&(x==numSubX)&&y==numSubY)))
                    lgStrs=[];
                    for k=1:length(pointStrs)
                       if(isnumeric(pointStrs{k}))
                           pointStrs{k}='';
                       end
                       lgStrs=[lgStrs;pointStrs(k)];
                    end

                    legend(sH{i,b}.subH{y,x},pointStrs(:));
                end

                hold(sH{i,b}.subH{y,x},'off')
            end
        end

        addDebugAnnotation(sH{i,b}.h);
        switch(figType)
            case 'bioM'
                pf2_base.external.suptitle(sH{i,b}.h,selectedBioM{i});
            case 'channels'
                pf2_base.external.suptitle(sH{i,b}.h,selectedOpt{i});
            case 'bio,channels'
                pf2_base.external.suptitle(sH{i,b}.h,sprintf('Optode %i [%s]',selectedOpt(i),selectedBioM{b}));
            otherwise

        end
    end
end

    


% --- Executes on selection change in popupmenu_errorbar_style.
function popupmenu_errorbar_style_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_errorbar_style (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_errorbar_style contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_errorbar_style

global ExFNIRS

idx=get(handles.popupmenu_errorbar_style,'Value');
strs=get(handles.popupmenu_errorbar_style,'String');
ExFNIRS.settings.plot_error_style=strs{idx};

% --- Executes during object creation, after setting all properties.
function popupmenu_errorbar_style_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_errorbar_style (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_scatter_error.
function checkbox_plot_scatter_error_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_scatter_error (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_scatter_error

global ExFNIRS
ExFNIRS.settings.plot_scatter_err=get(handles.checkbox_plot_scatter_error,'Value');

% --- Executes on selection change in popupmenu_scatter_error_feature.
function popupmenu_scatter_error_feature_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_scatter_error_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_scatter_error_feature contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_scatter_error_feature

global ExFNIRS
idx=get(handles.popupmenu_scatter_error_feature,'Value');
strs=get(handles.popupmenu_scatter_error_feature,'String');
ExFNIRS.settings.plot_scatter_err_feature=strs{idx};


% --- Executes during object creation, after setting all properties.
function popupmenu_scatter_error_feature_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_scatter_error_feature (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_scatter_error_multiplier_Callback(hObject, eventdata, handles)
% hObject    handle to edit_scatter_error_multiplier (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_scatter_error_multiplier as text
%        str2double(get(hObject,'String')) returns contents of edit_scatter_error_multiplier as a double

global ExFNIRS
ExFNIRS.settings.plot_scatter_err_mult=str2double(get(handles.edit_scatter_error_multiplier,'String'));
set(handles.edit_scatter_error_multiplier,'String',sprintf('%.1f',ExFNIRS.settings.plot_scatter_err_mult));

% --- Executes during object creation, after setting all properties.
function edit_scatter_error_multiplier_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_scatter_error_multiplier (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_scatter_nonparametric.
function checkbox_plot_scatter_nonparametric_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_scatter_nonparametric (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_scatter_nonparametric

global ExFNIRS
ExFNIRS.settings.plot_scatter_nonparametric=get(handles.checkbox_plot_scatter_nonparametric,'Value');


% --- Executes on button press in checkbox_plot_scatter_line.
function checkbox_plot_scatter_line_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_scatter_line (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_scatter_line

global ExFNIRS
ExFNIRS.settings.plot_scatter_line=get(handles.checkbox_plot_scatter_line,'Value');


% --- Executes on selection change in popupmenu_scatter_error_style.
function popupmenu_scatter_error_style_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_scatter_error_style (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_scatter_error_style contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_scatter_error_style

global ExFNIRS

idx=get(handles.popupmenu_scatter_error_style,'Value');
strs=get(handles.popupmenu_scatter_error_style,'String');
ExFNIRS.settings.plot_scatter_error_style=strs{idx};


% --- Executes during object creation, after setting all properties.
function popupmenu_scatter_error_style_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_scatter_error_style (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_plot_scatter_extend.
function checkbox_plot_scatter_extend_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_scatter_extend (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_scatter_extend
global ExFNIRS
ExFNIRS.settings.plot_scatter_extend=get(handles.checkbox_plot_scatter_extend,'Value');


% --- Executes on selection change in popupmenu_groupby_info_field.
function popupmenu_groupby_info_field_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_groupby_info_field (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_groupby_info_field contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_groupby_info_field

global ExFNIRS

strs=get(handles.popupmenu_groupby_info_field,'String');
val=get(handles.popupmenu_groupby_info_field,'Value');

selStr=strs{val};

ExFNIRS.settings.use_info=true;


ExFNIRS.settings.curInfoGroupBy=selStr;
infoVars=ExFNIRS.dataTable.Properties.VariableNames;

set(handles.popupmenu_groupby_info_field,'String',infoVars);
[a,b]=ismember(ExFNIRS.settings.curInfoGroupBy,infoVars);

if(a==1)
    set(handles.popupmenu_groupby_info_field,'Value',b);
else
    set(handles.popupmenu_groupby_info_field,'Value',1);
end

idx=get(handles.popupmenu_groupby_info_field,'Value');
ExFNIRS.settings.curInfoGroupBy=infoVars{idx};

if(~isempty(ExFNIRS.settings.curInfoGroupBy))
    uVars=unique(ExFNIRS.dataTable(:,ExFNIRS.settings.curInfoGroupBy));
    
    if(isnumeric(uVars{1,1}))
       uVars=table2array(uVars);
       uVars(isnan(uVars))=-9999;
       uVars=unique(uVars);
       %uVars(uVars==-9999)=nan;
       uVars=num2str(uVars,'%.2f');
    elseif(isstring(uVars{1,1}))
       uVars=table2cell(uVars); 
    end
    if(~iscell(uVars))
        uVars=cellstr(uVars);
    end
    nanIndex=strcmp('-9999.00',uVars);
    
    uVars(nanIndex)={'NaN'};
    set(handles.listbox_info_groupby,'String',uVars);
    set(handles.listbox_info_groupby,'Value',1:length(uVars));
    
    
    
    segInfoVars={'Group','Subgroup','Session','Trial','Block','Condition',ExFNIRS.settings.curInfoGroupBy};
    randFxStr{1}='1|SubjectID';
    for i=2:2:length(segInfoVars)*2
       randFxStr{i}=sprintf('%s|SubjectID',segInfoVars{(i)/2}); 
       randFxStr{i+1}=sprintf('1+%s|SubjectID',segInfoVars{(i)/2}); 
    end

    set(handles.popupmenu_lmer_randomeffects,'String',randFxStr);
    ExFNIRS.settings.LME_randomFxStrs=randFxStr;

else
    set(handles.listbox_info_groupby,'String','');
end

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end

% --- Executes during object creation, after setting all properties.
function popupmenu_groupby_info_field_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_groupby_info_field (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_info_groupby.
function listbox_info_groupby_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_info_groupby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_info_groupby contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_info_groupby

global ExFNIRS


if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes during object creation, after setting all properties.
function listbox_info_groupby_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_info_groupby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_info_groupby_select_all.
function pushbutton_info_groupby_select_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_info_groupby_select_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

strs=get(handles.listbox_info_groupby,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_info_groupby,'Value',[1:size(strs,1)]);
end

global ExFNIRS

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in pushbutton_info_groupby_select_none.
function pushbutton_info_groupby_select_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_info_groupby_select_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

strs=get(handles.listbox_info_groupby,'String');
if(iscell(strs)||ismatrix(strs))
    set(handles.listbox_info_groupby,'Value',[]);
end

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end




% --- Executes on button press in checkbox_info_groupby_plotby.
function checkbox_info_groupby_plotby_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_info_groupby_plotby (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_info_groupby_plotby
global ExFNIRS
ExFNIRS.settings.plotby.InfoGroupBy=get(handles.checkbox_info_groupby_plotby,'Value');
if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(true,handles);
end


% --- Executes on button press in checkbox_plot_scatter_flipxy.
function checkbox_plot_scatter_flipxy_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_scatter_flipxy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_scatter_flipxy
global ExFNIRS
ExFNIRS.settings.plot_scatter_flipxy=get(handles.checkbox_plot_scatter_flipxy,'Value');


% --- Executes on selection change in listbox_color_order.
function listbox_color_order_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_color_order (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_color_order contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_color_order


% --- Executes during object creation, after setting all properties.
function listbox_color_order_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_color_order (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_gui_color_move_up.
function pushbutton_gui_color_move_up_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_move_up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

colorStr=get(handles.listbox_color_order,'String');
colorVal=get(handles.listbox_color_order,'Value');

if(isempty(colorVal))
    set(handles.listbox_color_order,'Value',1);
    colorVal=1;
end

numClrStr=length(colorStr);
if(colorVal==1)
    return;
else
    newInd=[1:colorVal-2,colorVal,colorVal-1,(colorVal+1):numClrStr];
    newInd(newInd>numClrStr)=[];
    ExFNIRS.settings.guiColor=ExFNIRS.settings.guiColor(newInd,:);
    set(handles.listbox_color_order,'String',colorStr(newInd));
    set(handles.listbox_color_order,'Value',colorVal-1);
end

updateButtonListColors(handles);


function updateButtonListColors(handles)

global ExFNIRS

set(handles.pushbutton_gui_color_1,'ForegroundColor',ExFNIRS.settings.guiColor(1,:));
set(handles.pushbutton_gui_color_2,'ForegroundColor',ExFNIRS.settings.guiColor(2,:));
set(handles.pushbutton_gui_color_3,'ForegroundColor',ExFNIRS.settings.guiColor(3,:));
set(handles.pushbutton_gui_color_4,'ForegroundColor',ExFNIRS.settings.guiColor(4,:));
set(handles.pushbutton_gui_color_5,'ForegroundColor',ExFNIRS.settings.guiColor(5,:));
set(handles.pushbutton_gui_color_6,'ForegroundColor',ExFNIRS.settings.guiColor(6,:));
set(handles.pushbutton_gui_color_7,'ForegroundColor',ExFNIRS.settings.guiColor(7,:));
set(handles.pushbutton_gui_color_8,'ForegroundColor',ExFNIRS.settings.guiColor(8,:));
set(handles.pushbutton_gui_color_9,'ForegroundColor',ExFNIRS.settings.guiColor(9,:));
set(handles.pushbutton_gui_color_10,'ForegroundColor',ExFNIRS.settings.guiColor(10,:));

colorStr=get(handles.listbox_color_order,'String');

% --- Executes on button press in pushbutton_gui_color_move_down.
function pushbutton_gui_color_move_down_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_gui_color_move_down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

colorStr=get(handles.listbox_color_order,'String');
colorVal=get(handles.listbox_color_order,'Value');

if(isempty(colorVal))
    set(handles.listbox_color_order,'Value',1);
    colorVal=1;
end

numClrStr=length(colorStr);
if(colorVal==length(colorStr))
    return;
else
    newInd=[(1:colorVal-1),(colorVal+1),colorVal,(colorVal+2):numClrStr];
    newInd(newInd>numClrStr)=[];
    ExFNIRS.settings.guiColor=ExFNIRS.settings.guiColor(newInd,:);
    set(handles.listbox_color_order,'String',colorStr(newInd));
    set(handles.listbox_color_order,'Value',colorVal+1);
end

updateButtonListColors(handles);


% --- Executes on button press in checkbox_LME_enable.
function checkbox_LME_enable_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_LME_enable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_LME_enable

global ExFNIRS
ExFNIRS.settings.LME_enable=get(handles.checkbox_LME_enable,'Value');



% --- Executes on button press in checkbox_LME_all_interactions.
function checkbox_LME_all_interactions_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_LME_all_interactions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_LME_all_interactions

global ExFNIRS
ExFNIRS.settings.LME_all_interactions=get(handles.checkbox_LME_all_interactions,'Value');


% --- Executes on button press in checkbox_LME_info_covariate.
function checkbox_LME_info_covariate_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_LME_info_covariate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_LME_info_covariate

global ExFNIRS
ExFNIRS.settings.LME_info_covariate=get(handles.checkbox_LME_info_covariate,'Value');


% --- Executes on button press in pushbutton_lme_plot_topo.
function pushbutton_lme_plot_topo_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_lme_plot_topo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global ExFNIRS
switch(ExFNIRS.settings.ChannelMode)
    case 'fNIR'
        strs=get(handles.listbox_optode,'String');
        if(iscell(strs)||ismatrix(strs))
            set(handles.listbox_optode,'Value',[1:size(strs,1)]);
        end
    case 'ROI'
        
    case 'Aux'
        
end

plot_barchart(handles, false,true)


% --- Executes on button press in checkbox_export_9999.
function checkbox_export_9999_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_export_9999 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_export_9999

global ExFNIRS
ExFNIRS.settings.export_replace_missing_9999=get(handles.checkbox_export_9999,'Value');


% --- Executes on selection change in popupmenu_ChannelMode.
function popupmenu_ChannelMode_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_ChannelMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_ChannelMode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_ChannelMode
global ExFNIRS

idx=get(handles.popupmenu_ChannelMode,'Value');
setExChannelMode(ExFNIRS.settings.ChannelModes{idx,2},handles);

function setExChannelMode(modeStr,handles,initROI)
% sets the channel mode and changes GUI to match

if(nargin<3)
    initROI=false;
end

global ExFNIRS
ExFNIRS.settings.ChannelMode=modeStr;

switch (ExFNIRS.settings.ChannelMode)
    case 'fNIR'
        uOpt=[];
        for i=1:length(ExFNIRS.data)
            if(isfield(ExFNIRS.data{i},'channels'))
                uOpt=[uOpt,ExFNIRS.data{i}.channels];
            end
        end
        uOpt=sort(unique(uOpt));

        set(handles.text_optode_label,'String','Optode');
        set(handles.text_biomarker_label,'String','BioMarker');
        set(handles.listbox_biomarker,'Enable','on');
        set(handles.pushbutton_biomarker_select_all,'Enable','on');
        set(handles.pushbutton_biomarker_select_none,'Enable','on');
        
        set(handles.listbox_optode,'String',uOpt);
        set(handles.listbox_optode,'Value',1);
        set(handles.listbox_biomarker,'String',{'HbO','HbR','HbDiff','HbTotal','CBSI'});
        
        set(handles.pushbutton_lme_plot_topo,'Enable','on');
    case 'ROI'
        uROI={};
        roiNames={};
        for i=1:length(ExFNIRS.data)
            if(pf2_base.isnestedfield(ExFNIRS.data{i},'ROI.info'))
                curRowNames=ExFNIRS.data{i}.ROI.info.Properties.RowNames;
                if(any(~ismember(curRowNames,roiNames)))
                    for roinum=1:size(ExFNIRS.data{i}.ROI.info,1)
                        if(~ismember(curRowNames{roinum},roiNames))
                            if(isempty(ExFNIRS.data{i}.ROI.info.Properties.RowNames{roinum}))
                                newRoiName=sprintf('ROI%i',roinum+length(rowNames));
                                roiNames=[roiNames,{newRoiName}];
                                ExFNIRS.data{i}.ROI.info.Properties.RowNames{roinum}=newRoiName;
                            else
                                roiNames=[roiNames,ExFNIRS.data{i}.ROI.info.Properties.RowNames(roinum)];
                            end
                            ExFNIRS.data{i}.ROI.info.DeviceCfg(:)={ExFNIRS.data{i}.info.probename};
                            uROI=[uROI;ExFNIRS.data{i}.ROI.info(roinum,:)];
                        end
                    end
                end
                
                
                
            end
        end
        if(isempty(uROI))
            warning('No ROIs present in data');
            set(handles.popupmenu_ChannelMode,'Value',1);
        else
            %uROI=unique(uROI{:},'rows');

            [uROInames,b,c]=unique(roiNames);
            uROInames=roiNames(b);
            uROI=uROI(b,:);



            if(initROI) % standaradize all ROIs on first load
                fprintf(2,'************\nStandardizing all ROI fields..\n********\n');
                for i=1:length(ExFNIRS.data)
                    if(pf2_base.isnestedfield(ExFNIRS.data{i},'raw')&&~isempty(ExFNIRS.data{i}))
                       ExFNIRS.data{i}.ROI.info=uROI;
                    end
                end
            end

            ExFNIRS.currentROI=uROI;


            set(handles.text_optode_label,'String','ROI');
            set(handles.text_biomarker_label,'String','BioMarker');
            set(handles.listbox_biomarker,'Enable','on');
            set(handles.pushbutton_biomarker_select_all,'Enable','on');
            set(handles.pushbutton_biomarker_select_none,'Enable','on');

            set(handles.listbox_optode,'String',uROInames);
            set(handles.listbox_optode,'Value',1);
            set(handles.listbox_biomarker,'String',{'HbO','HbR','HbDiff','HbTotal','CBSI'});
            set(handles.pushbutton_lme_plot_topo,'Enable','on');
        end
    case 'Aux'
        set(handles.text_optode_label,'String','Aux');
        set(handles.text_biomarker_label,'String','Aux Signal');
        set(handles.listbox_biomarker,'Enable','off');
        set(handles.pushbutton_biomarker_select_all,'Enable','off');
        set(handles.pushbutton_biomarker_select_none,'Enable','off');
        set(handles.listbox_biomarker,'String',{''});
        set(handles.listbox_optode,'Value',[]);
        set(handles.pushbutton_lme_plot_topo,'Enable','off');
end


% --- Executes during object creation, after setting all properties.
function popupmenu_ChannelMode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_ChannelMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_LME_use_intercept.
function checkbox_LME_use_intercept_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_LME_use_intercept (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_LME_use_intercept

global ExFNIRS

ExFNIRS.settings.LME_use_intercept=get(handles.checkbox_LME_use_intercept,'Value');

% --- Executes on button press in checkbox_process_raw.
function checkbox_process_raw_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_process_raw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_process_raw

global ExFNIRS

ExFNIRS.settings.processRaw=get(handles.checkbox_process_raw,'Value');

if(ExFNIRS.settings.processRaw)
    set(handles.listbox_raw_methods,'Enable','on');
else
    set(handles.listbox_raw_methods,'Enable','off');
    set(handles.listbox_raw_methods,'Value',1);
end

if(ExFNIRS.settings.updateOnChange)
    updateSelectedTable(handles);
else
    flagForUpdate(3,handles);
end


% --- Executes on button press in checkbox_discreteTime.
function checkbox_discreteTime_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_discreteTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_discreteTime
global ExFNIRS
ExFNIRS.settings.LME_use_discreteTime=get(handles.checkbox_discreteTime,'Value');


% --- Executes on selection change in popupmenu_lmer_randomeffects.
function popupmenu_lmer_randomeffects_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_lmer_randomeffects (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_lmer_randomeffects contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_lmer_randomeffects
global ExFNIRS

ExFNIRS.settings.LME_randomFxStr=ExFNIRS.settings.LME_randomFxStrs{get(handles.popupmenu_lmer_randomeffects,'Value')};


% --- Executes during object creation, after setting all properties.
function popupmenu_lmer_randomeffects_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_lmer_randomeffects (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over popupmenu_lmer_randomeffects.
function popupmenu_lmer_randomeffects_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_lmer_randomeffects (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in checkbox_lme_usecustom.
function checkbox_lme_usecustom_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_lme_usecustom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_lme_usecustom

global ExFNIRS

ExFNIRS.settings.LME_use_customStr=get(handles.checkbox_lme_usecustom,'Value');

if(ExFNIRS.settings.LME_use_customStr&&isempty(ExFNIRS.settings.LME_customStr))
    pushbutton_custom_lme_Callback([], [], handles);
else
    
end


% --- Executes on button press in pushbutton_custom_lme.
function pushbutton_custom_lme_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_custom_lme (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

prompt = {'Please enter custom LME string'};
dlgtitle = 'Define custom LME model terms';
dims = [1 100];
answer = inputdlg(prompt,dlgtitle,dims,{ExFNIRS.settings.LME_customStr});

if(~isempty(answer))
    ExFNIRS.settings.LME_customStr=answer{1};
    set(handles.checkbox_lme_usecustom,'Value',1);
    ExFNIRS.settings.LME_use_customStr=true;
else
    ExFNIRS.settings.LME_use_customStr=false;
    set(handles.checkbox_lme_usecustom,'Value',0);
end

set(handles.pushbutton_custom_lme,'TooltipString',answer{1});



% --- Executes on selection change in popupmenu_topoSig.
function popupmenu_topoSig_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_topoSig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_topoSig contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_lmer_randomeffects
global ExFNIRS

switch(get(handles.popupmenu_topoSig,'Value'))
    case 1 % p=0.1
       ExFNIRS.settings.topoSigThrehold={'p',0.1};
    case 2 % p=0.05
       ExFNIRS.settings.topoSigThrehold={'p',0.05};
    case 3
       ExFNIRS.settings.topoSigThrehold={'p',0.01};
   case 4
       ExFNIRS.settings.topoSigThrehold={'q',0.05};
   case 5
       ExFNIRS.settings.topoSigThrehold={'q',0.1};
   case 6
       ExFNIRS.settings.topoSigThrehold={'qReverse',0.05};
end


% --- Executes during object creation, after setting all properties.
function popupmenu_topoSig_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_topoSig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_yaxis.
function checkbox_yaxis_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_yaxis (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_yaxis

global ExFNIRS

ExFNIRS.settings.plot_temporal_y0=get(handles.checkbox_yaxis,'Value');




% --- Executes on button press in pushbutton_exLoad.
function pushbutton_exLoad_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_exLoad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

exploreFNIRS.LoadEx();

% --- Executes on button press in pushbutton_exSave.
function pushbutton_exSave_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_exSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

exploreFNIRS.SaveEx();
