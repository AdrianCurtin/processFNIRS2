
function varargout = processFNIRS2_GUI(varargin)
% PROCESSFNIR2 MATLAB code for processFNIRS2_GUI.fig
%      2nd generation preprocessing pipleline for fNIRS datasets
%      Uses device configuration files to allow for more repeatable and 
%      more flexible situations
%
%      Always takes a simple array containing the light intensity data and 
%      will optionally load a specific parameters using the varargin option
%      Specifiying an output will hide the GUI unless 'ShowGUI',true is
%      passed as an argument
%
%      PROCESSFNIRS2_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PROCESSFNIR2.M with the given input arguments.
%
%      PROCESSFNIRS2_GUI('Property','Value',...) creates a new PROCESSFNIR2 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before processFNIRS2_GUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to processFNIRS2_GUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help processFNIRS2_GUI

% Last Modified by GUIDE v2.5 23-Jan-2019 09:21:35

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @processFNIRS2_GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @processFNIRS2_GUI_OutputFcn, ...
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

% --- Executes just before processFNIRS2_GUI is made visible.
function processFNIRS2_GUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to processFNIRS2_GUI (see VARARGIN)


global PF2
global setF
global outputData 




warning('OFF','MATLAB:table:RowsAddedExistingVars');

%%
%Load default paramaters here

if(isempty(PF2))
   pf2_base.pf2_initialize(); 
end


PF2.GUIPF2=struct();
PF2.view.processWindowOnly=false; %GUI option to only process the current window of data


%%
% Parse inputs here

if(isfield(PF2,'stageRawMethod')&&isfield(PF2.stageRawMethod,'name')&&sum(strcmp(PF2.myRawMethods.cfg.Sections,PF2.stageRawMethod.name))==1)
    defaultRawMethod=PF2.stageRawMethod.name;
else
    defaultRawMethod='None';
end

if(isfield(PF2,'stageOxyMethod')&&isfield(PF2.stageOxyMethod,'name')&&sum(strcmp(PF2.myOxyMethods.cfg.Sections,PF2.stageOxyMethod.name))==1)
    defaultOxyMethod=PF2.stageOxyMethod.name;
else
    defaultOxyMethod='None';
end

p = inputParser;

validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x >= 0);
validScalarNum = @(x) isnumeric(x) && isscalar(x);
validDataInput = @(x) ((isnumeric(x) && ismatrix(x))||(isstruct(x)&&(isfield(x,'raw')||isfield(x,'hbo')||isfield(x,'HbO')||isfield(x,'info'))));
validRawMethod = @(x) ischar(validatestring(x,PF2.myRawMethods.cfg.Sections));
validOxyMethod = @(x) ischar(validatestring(x,PF2.myOxyMethods.cfg.Sections));
validDPFmode = @(x) ischar(validatestring(x,{'None','Fixed','Calc'}));


addOptional(p,'data',[],validDataInput);
addOptional(p,'Raw_Method',defaultRawMethod,validRawMethod); %Attempt to load specified RawMethod
addOptional(p,'Oxy_Method',defaultOxyMethod,validOxyMethod); %Attempt to load specified OxyMethod
addOptional(p,'blLength',PF2.baseline.blLength,validScalarPosNum); %specify realtive baseline relative to blStartTime (in seconds)
addOptional(p,'blStartTime',PF2.baseline.startTime,validScalarNum); %Specify relative baseline start time (in seconds)
addParameter(p,'defaultSubjectAge',PF2.curDPF_age,validScalarPosNum); %Use custom DPF rather than whatever was in the GUI
addParameter(p,'UseDeviceCFG','',@ischar); %Input for file containing device configuration info
addParameter(p,'markers',[],@ismatrix); %specify where markers go
addParameter(p,'OutputLegacyMarkers',false,@islogical); % turn on to output marker array into .markers.data instead of just .markers


addParameter(p,'SkipOxy',false,@islogical); %specifies whether to stop processing of data at Oxy
addParameter(p,'SkipOD',false,@islogical); %specifies whether to stop processing of data before OD conversion
addParameter(p,'SkipRaw',false,@islogical); %specifies whether to skip the raw data and only process oxy data
addParameter(p,'ProcessRejectedChannels',false,@islogical); %specifies whether to attempt to process rejected channels, if false channels are returned as NA

addParameter(p,'ChannelMask',[],@ismatrix); %logical matrix the size of channel array which determines if channel has been rejected, later stored in fChMask

addParameter(p,'ShowGUI',true,@islogical); %adds bool to show gui even when output is defined
addParameter(p,'DirtyBaseline',false,@islogical); % turn to use the entire mean as the baseline period
addParameter(p,'FixedDPF',PF2.curDPF_fixed,validScalarPosNum); %set default uniwavelength DPF
addParameter(p,'DPFmode',PF2.dpf_mode,validDPFmode); %set role of DPF in mBLL calculations
addParameter(p,'RejectLevel',PF2.RejectLevel,@(x) isnumeric(x)&&isscalar(x)&&x<1&&x>=0); %set the level at which a channel is rejected (fChMask)


addParameter(p,'ImportOxyMethods','NA',@ischar);
addParameter(p,'ImportRawMethods','NA',@ischar);


parse(p,varargin{:});

outputData.ProcessOxy=~p.Results.SkipOxy;
outputData.ProcessRaw=~p.Results.SkipRaw;
outputData.OutputRaw=p.Results.SkipOD;
outputData.ProcessRejected=p.Results.ProcessRejectedChannels;
outputData.DirtyBaseline=p.Results.DirtyBaseline;
PF2.OutputLegacyMarkers=p.Results.OutputLegacyMarkers;

outputData.ShowGUI=p.Results.ShowGUI;

PF2.baseline.startTime=p.Results.blStartTime;
PF2.baseline.blLength=p.Results.blLength;

if(PF2.baseline.blLength==0)
   outputData.DirtyBaseline=true;
end

PF2.curDPF_fixed=p.Results.FixedDPF;
PF2.curDPF_age=p.Results.defaultSubjectAge;
PF2.dpf_mode=p.Results.DPFmode;

data=p.Results.data;

rawMethodStr=p.Results.Raw_Method;
oxyMethodStr=p.Results.Oxy_Method;

PF2.stageRawMethod=pf2_base.pf2_unpackMethod(PF2.myRawMethods.cfg.(rawMethodStr));
PF2.stageRawMethod.name=rawMethodStr;

PF2.stageOxyMethod=pf2_base.pf2_unpackMethod(PF2.myOxyMethods.cfg.(oxyMethodStr));
PF2.stageOxyMethod.name=oxyMethodStr;

PF2.GUIPF2.handles=handles;
PF2.GUIPF2.figHandle=handles.figure1;
PF2.GUIPF2.curDPF_age=PF2.curDPF_age;   %Default age for differential pathlenght factor calculation.
PF2.GUIPF2.curDPF_fixed=PF2.curDPF_fixed;   %Default age for differential pathlenght factor calculation.
PF2.GUIPF2.dpf_mode=PF2.dpf_mode; 

PF2.GUIPF2.baseline=PF2.baseline;
PF2.GUIPF2.baseline.relative2View=false; %GUI option to rebaseline to start of view when moving window, processor intensive
PF2.GUIPF2.baseline.blLength=PF2.baseline.blLength;

PF2.GUIPF2.stageRawMethod=PF2.stageRawMethod;
PF2.GUIPF2.stageOxyMethod=PF2.stageOxyMethod;

cfgFilePath=p.Results.UseDeviceCFG;

cfgRawImportPath=p.Results.ImportRawMethods;
cfgOxyImportPath=p.Results.ImportOxyMethods;

if(~strcmp(cfgRawImportPath,'NA'))
    processFNIRS2_configureMethods('importMethodsCallback',hObject,[],handles,cfgRawImportPath,true);
end

if(~strcmp(cfgOxyImportPath,'NA'))
    processFNIRS2_configureMethods('importMethodsCallback',hObject,[],handles,cfgOxyImportPath,false);
end


if(isempty(data)&&isempty(varargin))
    
    myNIRsample=processFNIRS2.Import.ImportSampleData;
    disp('No input arguments given, program is being loaded in with sample data');
    outputData.ShowGUI=true;
    data=myNIRsample;
    
elseif(isempty(data)||(isstruct(data)&&isfield(data,'info')&&~isfield(data,'raw')&&~isfield(data,'HbO')))
    disp('No data loaded, initializing settings only');
    outputData.ShowGUI=false;
    return;
end

for i=1:5
   PF2.data.stage{i}=[];
end

tempOxyStage=[];

if(ismatrix(data)&&~isstruct(data))
   x=data;
   data=[];
   data.raw=x;
end

if(isstruct(data)) %treat as fNIR struct
    if(isfield(data,'raw'))
        PF2.data.stage{1}=data.raw;
    end
    
    if(isfield(data,'MES'))
        PF2.data.stage{1}=data.raw;
    end
    
    if(isfield(data,'oxy'))
        tempOxyStage.HbDiff=data.oxy;
    end
    
    if(isfield(data,'hbo'))
        tempOxyStage.HbO=data.hbo;
    end
    
    if(isfield(data,'hbr'))
        tempOxyStage.HbR=data.hbr;
    end
    
    if(isfield(data,'total'))
        tempOxyStage.HbTotal=data.total;
    end
    
    if(isfield(data,'Total'))
        tempOxyStage.HbTotal=data.Total;
    end
    
    if(isfield(data,'cbsi'))
        tempOxyStage.CBSI=data.cbsi;
    end
    
    if(isfield(data,'HbO'))
        tempOxyStage.HbO=data.HbO;
    end
    
    if(isfield(data,'HbR'))
        tempOxyStage.HbR=data.HbR;
    end
    
    if(isfield(data,'HbTotal'))
        tempOxyStage.HbTotal=data.HbTotal;
    end
    
    if(isfield(data,'CBSI'))
        tempOxyStage.CBSI=data.CBSI;
    end
    
    if(isfield(data,'diffhb'))
        tempOxyStage.HbDiff=data.diffhb;
    end
    
    if(isfield(data,'HbDiff'))
        tempOxyStage.HbDiff=data.HbDiff;
    end
    
    if(isfield(data,'Oxy'))
        tempOxyStage.HbO=data.Oxy;
    end
    
    if(isfield(data,'Deoxy'))
        tempOxyStage.HbR=data.Deoxy;
    end
    
    if(isfield(data,'channels'))
        tempOxyStage.channels=data.channels;
    end
    
    if(isfield(data,'units'))
        tempOxyStage.units=data.units;
    end
    
    if(isfield(data,'DPF_factor'))
        tempOxyStage.DPF_factor=data.DPF_factor;
    end
    
    
    if(isfield(data,'mrk'))
        if(isnumeric(data.mrk))
            data.markers=data.mrk;
        elseif(isfield(data.mrk,'data'))
            data.markers=data.mrk.data;
            if(~isfield(data,'info'))
                data.info=[];
            end
            if(isfield(data.mrk,'info'))
               data.info.mrkinfo=data.mrk.info;
            end
            if(isfield(data.mrk,'headers'))
                data.info.mrkheaders=data.mrk.headers;
            end
        end
    end
    
    if(isfield(data,'fchMask'))
        PF2.data.fchMask=data.fchMask;
    end
    
    if(isfield(data,'time'))
        PF2.data.time=data.time;
    end
    
    if(isfield(data,'markers'))
        if(isnumeric(data.markers))
            PF2.data.markers=data.markers;
        elseif(isfield(data.markers,'data'))
            PF2.data.markers=data.markers.data;
            if(~isfield(data,'info'))
                data.info=[];
            end
            if(isfield(data.markers,'info'))
               data.info.mrkinfo=data.markers.info;
            end
            if(isfield(data.markers,'headers'))
                data.info.mrkheaders=data.markers.headers;
            end
        end
    end
    
    if(isfield(data,'info'))
        PF2.data.info=data.info;
    else
        PF2.data.info=[]; 
    end
    
    if(~isfield(PF2.data.info,'SubjectID'))
        PF2.data.info.SubjectID='';
    end
    if(~isfield(PF2.data.info,'Group'))
        PF2.data.info.Group='';
    end
    if(~isfield(PF2.data.info,'Subgroup'))
        PF2.data.info.Subgroup='';
    end
    if(~isfield(PF2.data.info,'Session'))
        PF2.data.info.Session='';
    end
    if(~isfield(PF2.data.info,'Trial'))
        PF2.data.info.Trial='';
    end
    if(~isfield(PF2.data.info,'Block'))
        PF2.data.info.Block='';
    end
    if(~isfield(PF2.data.info,'probename'))
        PF2.data.info.probename='';
    end
    if(~isfield(PF2.data.info,'Condition'))
        PF2.data.info.Condition='';
    end
    if(~isfield(PF2.data.info,'Age'))
        PF2.data.info.Age=[];
    end
    if(~isfield(PF2.data.info,'Sex'))
        PF2.data.info.Sex='';
    end
    
    if(isfield(data,'Aux'))
        PF2.data.Aux=data.Aux;
    end
    
    if(isfield(data,'channels'))
        PF2.data.channels=data.channels;
    end
    
    if(pf2_base.isnestedfield(data,'ROI.info'))
        PF2.data.ROI=data.ROI;
    end
    
    if(isfield(data,'takizawa'))
        PF2.data.takizawa=data.takizawa;
    end
end

if(isempty(PF2.data.info.Age))
   warning('fData.info.Age is empty\nDPF calculations will be performed using an age of %i years old\nPlease assign subject age for accurate chromophore calculations',PF2.curDPF_age);

end

if(~isempty(p.Results.markers))
    PF2.data.markers=p.Results.markers; %Overwrite markers if specified
end

if(isstruct(tempOxyStage))
    PF2.data.stage{4}=tempOxyStage; %Assign stage3 if exists
end

if(~isempty(p.Results.UseDeviceCFG)) % if command argument given
    cfgFilePath=p.Results.UseDeviceCFG; % command argument to load cfg file
elseif(isfield(data,'info')&&isfield(data.info,'probename')&&~contains(data.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',data.info.probename);
else
    cfgFilePath='';
end


if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
    
    warning('Missing or invalid configuration file path\n')
    
    disp('No device specified. Please load device configuration');
    pf2_base.loadDeviceCfg([],true);
    if(~isfield(setF,'device'))
        error('No valid devices selected');
    end
    
elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
    
    if(pf2_base.isnestedfield(setF,'device.cfg.info.CfgName')) % look to see if they match,...
            
        curProbeName=sprintf('%s.cfg',setF.device.cfg.info.CfgName);
        
        %if(~strcmp(curProbeName,cfgFilePath)) %if they do don't bother loading
            pf2_base.loadDeviceCfg(cfgFilePath,true); % Always load to build device layout
        %end
    else
        pf2_base.loadDeviceCfg(cfgFilePath,true);
    end
end



updateCurrentDevice();

[numDataRows,numDataCols]=size(PF2.data.stage{1});
numDevCols=length(setF.device.Probe{1}.ChannelNumbers);
while(numDataCols~=numDevCols)
    
    if(numDataCols==numDataRows)
       PF2.data.stage{1}=PF2.data.stage{1}';
       break;
    else
       fprintf('Data size %i x %i: Expected %i columns in loaded device',numDevCols);
       warning('Channel/Device mismatch, please load new configuration file');
       pf2_base.loadDeviceCfg();
    end
    [numDataRows,numDataCols]=size(PF2.data.stage{1});
    numDevCols=length(setF.device.Probe{1}.ChannelNumbers);  
end

if(~isfield(PF2.data,'fchMask')||(isfield(PF2.data,'fchMask')&&isempty(PF2.data.fchMask)))
    PF2.data.fchMask=true(1,length(setF.device.Probe{1}.ChannelList));
end

numChannels=length(setF.device.Probe{1}.ChannelList);
PF2.data.rawMask=ismember(setF.device.Probe{1}.ChannelNumbers,setF.device.Probe{1}.ChannelList(reshape(PF2.data.fchMask>PF2.RejectLevel|outputData.ProcessRejected,[1,numChannels])));


if(~isempty(data))
   processFNIR_GUI(); 
end

if(~outputData.ShowGUI)
    close()
    return;
end

if(isfield(PF2.data,'markers')&&~isempty(PF2.data.markers))
    PF2.curMarkerSet=sort(unique(PF2.data.markers(:,2)));
    mrkStr=cell(length(PF2.curMarkerSet),1);
    for i=1:length(PF2.curMarkerSet)
       mrkStr{i}=sprintf('%i',PF2.curMarkerSet(i));
    end
    set(handles.listbox_markers,'String',mrkStr);
    set(handles.listbox_markers,'Value',[]);
    set(handles.listbox_marker_nav,'String',{});
    PF2.curMarkers=[];
    PF2.curNavMarkers=[];
else
   set(handles.listbox_markers,'String',{});
   set(handles.listbox_marker_nav,'String',{});
end

% Choose default command line output for processFNIRS2_GUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


InitializeViewSettings(handles);




PF2.GUIPF2.optodeTable=[];
%processFNIR_GUI();
UpdateOptodeList(handles);
updatePlots(handles);



% This sets up the initial plot - only do when we are invisible
% so window can get raised using processFNIRS2_GUI.
if strcmp(get(hObject,'Visible'),'off')
    plot(setF.device.Probe{1}.DetPosX);
end


function processFNIR_GUI()
global PF2
%1 is raw, 
%2 is processed raw, 
%3 is processed OD, 
%4 is oxy, 
%5 is processed oxy

global outputData
global setF

if(outputData.ProcessRaw)
    if(PF2.view.processWindowOnly)
        croppedData=PF2.data.stage{1};
        startSample=find(PF2.data.time>=PF2.view.startTime,1);
        endSample=find(PF2.data.time>PF2.view.endTime,1);
        croppedData(1:(startSample-1),:)=nan;
        croppedData(endSample:end,:)=nan;
        [PF2.data.stage{3},PF2.data.stage{2}]=processStageRaw2OD(croppedData); % Raw data processing
    else
        [PF2.data.stage{3},PF2.data.stage{2}]=processStageRaw2OD(PF2.data.stage{1}); % Raw data processing
    end
    
    if(outputData.ProcessOxy)
        PF2.data.stage{4}=processStageOD2Hb(PF2.data.stage{3},PF2.GUIPF2.curDPF_age); % Beer-Lambert conversion
    end
    
    if(pf2_base.isnestedfield(PF2,'data.ROI.info'))
        PF2.data.stage{4}.ROI.info=PF2.data.ROI.info; %Regenerate from info
    end
else
    PF2.data.stage{2}=PF2.data.stage{1};
    if(~isempty(PF2.data.stage{4})&&~isfield(PF2.data.stage{4},'channels'))
       PF2.data.stage{4}.channels=setF.device.Probe{1}.ChannelList;
       warning('No channel information given, assuming all columns indexs correspond with channel numbers');
    end
    if(pf2_base.isnestedfield(PF2,'data.ROI.info'))
        PF2.data.stage{4}.ROI=PF2.data.ROI; %Use all ROI information
    end
end


if(outputData.ProcessOxy)
    PF2.data.stage{5}=processStageFilterHb(PF2.data.stage{4}); % Oxy data processing
else
    PF2.data.stage{5}=PF2.data.stage{4};
end


function [outDataOD,outDataRaw]=processStageRaw2OD(data)
 % Raw data processing

global PF2

outData=data;
OD_converted=false;

validChannels=((PF2.curWvSet>0)&PF2.data.rawMask);  %Dark Channel should be 0, time should be NA, other information should be negative values
validDarkChannels=((PF2.curWvSet==0)&PF2.data.rawMask);

firstValidRow=nan;
for i=1:size(data,1)
   if(any(~isnan(data(i,validChannels))))
       firstValidRow=i;
       break;
   end
end

lastValidRow=nan;
for i=size(data,1):-1:1
   if(any(~isnan(data(i,validChannels))))
       lastValidRow=i;
       break;
   end
end

if(isnan(firstValidRow)||isnan(lastValidRow))
   warning('All Data is invalid'); 
   validRows=1;
else
   validRows=firstValidRow:lastValidRow; 
end

if(~isfield(PF2.GUIPF2,'stageRawMethod'))
    disp('No current Filters enabled');
    %outData(:,validChannels)=medfilt1(data(:,validChannels),10);
else
    for i=1:length(PF2.GUIPF2.stageRawMethod.F)
        Fidx=PF2.GUIPF2.stageRawMethod.F{i};
        if(isfield(Fidx,'f'))
            func=str2func(Fidx(1).f);
            if(contains(Fidx(1).f,'Intensity2OD'))
                outDataRaw=outData;
                OD_converted=true;
            end
            x_ind=[];
            fs_ind=[];
            time_ind=[];
            fmask_ind=[];
            fchInfo_ind=[];
            fmrk_ind=[];
            fAux_ind=[];
            fAmb_ind=[];
            fsd_ind=[];
            
            if(length(Fidx)>1) %This is a struct array for some reason?
               %Change it back!
               args=cell(0,0);
               passedArgVals=cell(0,0);
               for j=1:length(Fidx)
                    args{j}=Fidx(j).args;
                    passedArgVals{j}=Fidx(j).argvals;
               end
            else
                args=Fidx.args;
                passedArgVals=Fidx.argvals;
                if(~iscell(args))
                    args={args};
                end
                if(~iscell(passedArgVals))
                    passedArgVals={passedArgVals};
                end
            end
            

            
            for a=1:length(args)
               if strcmp(args{a},'x')==1
                  x_ind=a;
                  passedArgVals{x_ind}=data(validRows,validChannels);
               elseif strcmp(args{a},'fs')==1
                  fs_ind=a; 
                  passedArgVals{fs_ind}=PF2.data.fs;
               elseif strcmp(args{a},'fTime')==1
                  time_ind=a; 
                  passedArgVals{time_ind}=PF2.data.time(validRows);
               elseif strcmp(args{a},'fchMask')==1
                  fmask_ind=a;
                  passedArgVals{fmask_ind}=PF2.data.rawMask;
               elseif strcmp(args{a},'fChannelNumbers')==1
                  fchInfo_ind=a;
                  passedArgVals{fchInfo_ind}=PF2.curChSet(validChannels);               
               elseif strcmp(args{a},'fChannelSD')==1
                  fsd_ind=a;
                  passedArgVals{fsd_ind}=PF2.curSDSet(ismember(PF2.curChList,PF2.curChSet(validChannels)));
               elseif strcmp(args{a},'fMarkers')==1
                  fmrk_ind=a; 
                  passedArgVals{fmrk_ind}=PF2.data.markers;
               elseif strcmp(args{a},'fAux')==1
                  fAux_ind=a;
                  passedArgVals{fAux_ind}=PF2.data.Aux;
               elseif strcmp(args{a},'fAmbient')==1
                  fAmb_ind=a;
                  passedArgVals{fAmb_ind}=data(validRows,validDarkChannels);
               end
            end
            
            
            if(~isempty(x_ind))
                outData=data;
                %for ch=1:size(data,2)
                    
                    try
                        outData(validRows,validChannels)=func(passedArgVals{:});
                    catch ME
                        global outputData
                        if(outputData.ShowGUI)
                            outData(:,validChannels)=nan;
                            warning('Error occured in method %s when processing %s\n',PF2.GUIPF2.stageRawMethod.name,Fidx(1).f);
                            waitfor(errordlg(sprintf('Error occured in method %s when processing %s\n%s\n',PF2.GUIPF2.stageRawMethod.name,Fidx(1).f,ME.message),'Raw Processing Error'));
                        else
                            fprintf('Error occured in method %s when processing %s\n',PF2.GUIPF2.stageRawMethod.name,Fidx(1).f);
                            outData(:,validChannels)=nan;
                            rethrow(ME);
                        end
                    end
                %end
                data=outData;
            else
                outData=data;
                warning('Unable to identify NIRS input argument\n');
            end
        end
    end
end
if(OD_converted==false)
    outDataRaw=outData;
    outDataOD=outData;
    validChannels=((PF2.curWvSet>=0)&PF2.data.rawMask); %convert all and Dark channels
    outDataOD(:,validChannels)=pf2_Intensity2OD(outData(:,validChannels));
else
    validDarkChannels=((PF2.curWvSet==0)&PF2.data.rawMask); %convert just dark channels
    outDataOD=outData; 
    outDataOD(:,validDarkChannels)=pf2_Intensity2OD(outData(:,validDarkChannels));
end

outDataRaw(:,((PF2.curWvSet>=0)&~PF2.data.rawMask))=nan;
outDataOD(:,((PF2.curWvSet>=0)&~PF2.data.rawMask))=nan;

function outData=processStageOD2Hb(data,subAge)
 % Beer-Lambert conversion

global setF
global PF2
global outputData


if(outputData.DirtyBaseline)
    baselineSamples=1:length(PF2.data.time);
else
    if(PF2.GUIPF2.baseline.relative2View==1||PF2.view.processWindowOnly)
        startTime=PF2.view.startTime+PF2.GUIPF2.baseline.windowStartTime;
        endTime=PF2.view.startTime+PF2.GUIPF2.baseline.windowStartTime+PF2.GUIPF2.baseline.blLength;
    else
        startTime=min(PF2.data.time)+PF2.GUIPF2.baseline.startTime;
        endTime=startTime+PF2.GUIPF2.baseline.blLength;
    end

    startSample=find(PF2.data.time>=startTime,1);
    endSample=find(PF2.data.time>=endTime,1);
    baselineSamples=startSample:endSample;

end


if(strcmp(PF2.GUIPF2.dpf_mode,'None'))
    NoPathlength=true;
else
    NoPathlength=false;
end

if(strcmp(PF2.GUIPF2.dpf_mode,'Fixed'))
    fixedDPF=PF2.GUIPF2.curDPF_fixed;
else
    fixedDPF=0;
end

if(isempty(subAge))
    subAge=PF2.GUIPF2.curDPF_age;
end
    
[outData.HbO, outData.HbR, outData.HbTotal, outData.HbDiff,outData.CBSI,outData.channels,outData.time,outData.units,outData.DPF_factor]=...
    pf2_base.fnirs.bvoxy(data,setF.device.Probe{1}.ChannelNumbers,setF.device.Probe{1}.Wavelength,setF.device.Probe{1}.SD,baselineSamples,subAge,[],true,'NoPathlength',NoPathlength,'DiffPathlengthFactor',fixedDPF);

                                                          %BASELINE
                                                          %START/END
%[fNIR.oxy,fNIR.bv_805,fNIR.bv,fNIR.hbo,fNIR.hbr] = bvoxy (1,min(se,60),ss,se,fNIR.fin.raw_730,fNIR.fin.raw_805,fNIR.fin.raw_850);

%outData=data;



function outData=processStageFilterHb(data)
% Oxy data processing
global outputData
global PF2

bioM_list={'HbO','HbR','HbDiff','HbTotal','CBSI'};

validChannels=false(size(data.channels));
numChannels=length(data.channels(data.channels>0));
validChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(PF2.data.fchMask>PF2.RejectLevel|outputData.ProcessRejected,[1,numChannels]));

curfMask=PF2.data.fchMask>PF2.RejectLevel|outputData.ProcessRejected;

if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(data.ROI))
    validChannels_roi=true(1,size(data.ROI.('HbO'),2));
end

firstValidRow=nan;
for i=1:size(data.HbO,1)
   if(any(~isnan(data.HbO(i,validChannels))))
       firstValidRow=i;
       break;
   end
end

lastValidRow=nan;
for i=size(data.HbO,1):-1:1
   if(any(~isnan(data.HbO(i,validChannels))))
       lastValidRow=i;
       break;
   end
end

if(isnan(firstValidRow)||isnan(lastValidRow))
   warning('All Data is invalid'); 
   validRows=1;
else
   validRows=firstValidRow:lastValidRow; 
end


if(~isfield(PF2.GUIPF2,'stageOxyMethod'))
    disp('No stage2 processing method left');
    outData=data;
    %outData.HbO(:,validChannels)=medfilt1(outData.HbO(:,validChannels),25);
    %outData.HbR(:,validChannels)=medfilt1(outData.HbR(:,validChannels),25);
else
    outData=data;
    for i=1:length(PF2.GUIPF2.stageOxyMethod.F)
        Fidx=PF2.GUIPF2.stageOxyMethod.F{i};
        if(isfield(Fidx,'f'))
            func=str2func(Fidx(1).f);
            errorFlag=false;
            x_ind=[];
            fs_ind=[];
            time_ind=[];
            fmask_ind=[];
            fchInfo_ind=[];
            fmrk_ind=[];
            fAux_ind=[];
            fsd_ind=[];
            fStruct_ind=[];
            
            if(length(Fidx)>1||~iscell(Fidx.args)) %This is a struct array for some reason?
               %Change it back!
               args=cell(0,0);
               passedArgVals=cell(0,0);
               for j=1:length(Fidx)
                    args{j}=Fidx(j).args;
                    passedArgVals{j}=Fidx(j).argvals;
               end
            else
                args=Fidx.args;
                passedArgVals=Fidx.argvals;
            end
            
            if(isfield(Fidx,'output'))
               x_out_ind=[];
               roi_out_ind=[];
               fmask_out_ind=[];
               outputList=Fidx.output;
               for output_idx=1:length(outputList) % find first argument in output list
                   if strcmp(outputList{output_idx},'x')==1 &&isempty(x_out_ind)
                        x_out_ind=output_idx;
                   elseif strcmp(outputList{output_idx},'fchMask')==1  &&isempty(fmask_out_ind)
                       fmask_out_ind=output_idx;
                   elseif strcmp(outputList{output_idx},'ROI')==1&&isempty(roi_out_ind)
                       roi_out_ind=output_idx;
                   end
               end
            else
                x_out_ind=1; % assume that first index is the signal output
                roi_out_ind=[]; % leave empty
                fmask_out_ind=[];
            end
            
            for a=1:length(args)
               if strcmp(args{a},'x')==1
                  x_ind=a;
               elseif strcmp(args{a},'fs')==1
                  fs_ind=a; 
                  passedArgVals{fs_ind}=PF2.data.fs;
               elseif strcmp(args{a},'fTime')==1
                  time_ind=a; 
                  passedArgVals{time_ind}=PF2.data.time(validRows);
               elseif strcmp(args{a},'fchMask')==1
                  fmask_ind=a;
                  passedArgVals{fmask_ind}=PF2.data.rawMask;
               elseif strcmp(args{a},'fChannelNumbers')==1
                  fchInfo_ind=a;
                  passedArgVals{fchInfo_ind}=data.channels(validChannels);
               elseif strcmp(args{a},'fChannelSD')==1
                  fsd_ind=a;
                  passedArgVals{fsd_ind}=PF2.curSDSet(validChannels);
               elseif strcmp(args{a},'fMarkers')==1
                  fmrk_ind=a; 
                  passedArgVals{fmrk_ind}=PF2.data.markers;
               elseif strcmp(args{a},'fAux')==1
                  fAux_ind=a;
                  passedArgVals{fAux_ind}=PF2.data.Aux;
               elseif strcmp(args{a},'fNIRstruct')==1  % Try not to use, can be inefficient
                   fStruct_ind=a;
                   passedArgVals{fStruct_ind}=data;
               end
            end
            
            if(~isempty(x_ind)||~isempty(fStruct_ind))
                outData=data;
                %for ch=1:size(data,2)
                
                if(~isempty(fStruct_ind))
                    runOnce=true;
                else
                    runOnce=false;
                end
                
                for bmrkIdx=1:length(bioM_list)
                    bmrk=bioM_list{bmrkIdx};
                    
                    if(pf2_base.isnestedfield(data,'ROI.HbO'))
                       passedArgVals_roi=passedArgVals; 
                    end
                    
                    if(~isempty(x_ind))
                        passedArgVals{x_ind}=data.(bmrk)(validRows,validChannels);
                        
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                        % Note ROI functions may not be able to handle
                        % functions using channel numbers of SD separation
                            passedArgVals_roi{x_ind}=data.ROI.(bmrk)(validRows,validChannels_roi);
                        end
                    end
                    
                    if(~isempty(fStruct_ind))
                        passedArgVals{fStruct_ind}=data;
                    end
                    
                    
                     
                    
                    try
                        if(~errorFlag)
                            
                            funcOutput{:}=func(passedArgVals{:});
                            if(pf2_base.isnestedfield(outData,'ROI.HbO')&&~isempty(x_ind))
                                funcOutput_roi{:}=func(passedArgVals_roi{:}); 
                            end
                            
                            if(~isempty(x_out_ind)) % Assign values to fNIRS Biomarkers
                                outData.(bmrk)(validRows,validChannels)=funcOutput{x_out_ind};
                                if(pf2_base.isnestedfield(outData,'ROI.HbO'))
                                    outData.ROI.(bmrk)(validRows,validChannels_roi)=funcOutput_roi{x_out_ind};
                                end
                            end
                            
                            if(~isempty(fmask_out_ind)) % Or with current fmask
                                curfMask=curfMask&funcOutput{fmask_out_ind};
                                validChannels=outData.channels&(reshape(curfMask,[1,numChannels]));
                                outData.(bmrk)(:,~validChannels)=nan;

                                if(pf2_base.isnestedfield(outData,'ROI.HbO')&&~isempty(x_ind)) % won't run on full fNIR struct fxs
                                    validChannels_roi=validChannels_roi&funcOutput_roi{fmask_out_ind};
                                    validChannels_roi=sum(~isnan(outData.(bmrk)))>0; % check for invalid ROI
                                    outData.ROI.(bmrk)(:,~validChannels_roi)=nan;
                                end
                            end
                            
                            if(~isempty(roi_out_ind)) % Build ROIs
                                outData=funcOutput{roi_out_ind};
                                if(~isempty(outData.ROI))
                                    validChannels_roi=true(1,size(outData.ROI.(bmrk),2));
                                else
                                    clear outData.ROI; 
                                end
                                    
                            end
                            
                            if(runOnce)
                                break;
                            end
                            
                        else
                            outData.(bmrk)(:,validChannels)=nan;
                        end
                    catch ME
                        %global outputData
                        if(outputData.ShowGUI)
                            outData.(bmrk)(:,validChannels)=nan;
                            errorFlag=true;  % Set all other biomarkers to na
                            fprintf('Error occured in method %s when processing %s\n',PF2.GUIPF2.stageRawMethod.name,Fidx(1).f);
                            waitfor(errordlg(sprintf('Error occured in method %s when processing %s\n%s\n',PF2.GUIPF2.stageRawMethod.name,Fidx(1).f,ME.message),'Raw Processing Error'));
                        else
                            fprintf('Error occured in method %s when processing %s\n',PF2.GUIPF2.stageRawMethod.name,Fidx(1).f);
                            outData.(bmrk)(:,validChannels)=nan;
                            rethrow(ME);
                        end
                    end
                end

                %end
                data=outData;
            else
                %outData=data;
                warning('Unable to identify NIRS input argument\n');
            end
        end
    end
end

invalidChannels=false(size(data.channels));
invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask&~outputData.ProcessRejected,[1,numChannels]));
PF2.data.curChMask=curfMask;



for bioM=1:length(bioM_list) % go through each biomarker and set invalid cahnnels to nan
    outData.(bioM_list{bioM})(:,invalidChannels)=nan;
    
    if(isfield(outData,'ROI')&&isfield(outData.ROI,'HbO'))
        outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
    end
end


if(PF2.view.processWindowOnly)
    outData.validRows=validRows;
end


% UIWAIT makes processFNIRS2_GUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);
function updateCurrentDevice()

global setF
global PF2

PF2.curChSet=[];
PF2.curWvSet=[];
PF2.curSDSet=[];
PF2.curProbeInd=[];

if(length(setF.device.Probe)==1)
    PF2.mergedProbe=true;
else
    PF2.mergedProbe=true;
    warning('Multiple Probes may not be fully supported');
end

if(PF2.mergedProbe) %All channel numbers are unique for merged probes
    for i =1:length(setF.device.Probe)
        PF2.curChSet=[PF2.curChSet,setF.device.Probe{i}.ChannelNumbers];
        PF2.curProbeInd=[PF2.curProbeInd,i*length(setF.device.Probe{i}.ChannelNumbers)];
    
        PF2.curWvSet=[PF2.curWvSet,setF.device.Probe{i}.Wavelength];
        PF2.curSDSet=[PF2.curSDSet,setF.device.Probe{i}.SD];
    end
    PF2.timeIndex=find(PF2.curChSet==0);
    if(isempty(PF2.timeIndex)||setF.device.Info.TimeIsSampleCount)
        if(~setF.device.Info.TimeIsSampleCount)
            warning('Time column could not be found, assuming each row contains samples only');
        end
        
        if(isempty(PF2.timeIndex))
            PF2.timeIndex=0;
        end
    end
else
    error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

[~,i]=unique(PF2.curChSet);
PF2.curChList=PF2.curChSet(i);


if(PF2.mergedProbe) %All channel numbers are unique for merged probes  
    
    data=PF2.data.stage{1};
    if(~isempty(data))
        if(PF2.timeIndex==0) % No time index
            PF2.data.sampleTime=1:length(data(:,1));
            PF2.data.time=(PF2.data.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            PF2.data.fs=setF.device.Info.DefaultSamplingRate;
        elseif(setF.device.Info.TimeIsSampleCount==1)  %time index is sample time
            PF2.data.sampleTime=data(:,PF2.timeIndex);
            PF2.data.time=(PF2.data.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            PF2.data.fs=setF.device.Info.DefaultSamplingRate;
        else
            PF2.data.sampleTime=1:length(data(:,1));
            PF2.data.time=data(:,PF2.timeIndex);
            PF2.data.fs=1./median(diff(PF2.data.time));
        end

        PF2.view.startTime=min(PF2.data.time);
        PF2.view.endTime=max(PF2.data.time);
        PF2.view.timeStepSize=round((max(PF2.data.time)-min(PF2.data.time))/10);
    elseif(isfield(data,'time')&&~isempty(PF2.data.time))  %If time exists
        PF2.data.sampleTime=1:length(PF2.data.time);
        PF2.data.fs=1./median(diff(PF2.data.time));
    elseif(~isempty(PF2.data.stage{4})) %try to calculate from oxy data
        data=PF2.data.stage{4};
        if(PF2.timeIndex==0)
            PF2.data.sampleTime=1:length(data.HbO(:,1));
            PF2.data.time=(PF2.data.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            PF2.data.fs=setF.device.Info.DefaultSamplingRate;
        elseif(setF.device.Info.TimeIsSampleCount==1)
            PF2.data.sampleTime=data.HbO(:,PF2.timeIndex);
            PF2.data.time=(PF2.data.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            PF2.data.fs=setF.device.Info.DefaultSamplingRate;
        else
            PF2.data.sampleTime=1:length(data.HbO(:,1));
            PF2.data.time=data.HbO(:,PF2.timeIndex);
            PF2.data.fs=1./median(diff(PF2.data.time));
        end

        PF2.view.startTime=min(PF2.data.time);
        PF2.view.endTime=max(PF2.data.time);
        PF2.view.timeStepSize=round((max(PF2.data.time)-min(PF2.data.time))/10);
    end

else
   error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

function segInfoStr=BuildSegmentInfoString(info)

segInfoStr='';
if(~isempty(info.Group))
    segStr=info.Group;
    if(isnumeric(segStr))
       segStr= num2str(segStr);
    end
    segInfoStr=sprintf('%sGroup: %s\t',segInfoStr,segStr);
end
if(~isempty(info.SubjectID))
    segStr=info.SubjectID;
    if(isnumeric(segStr))
       segStr= num2str(segStr);
    end
    segInfoStr=sprintf('%sID: %s\t',segInfoStr,segStr);
end
if(~isempty(info.Session))
    segStr=info.Session;
    if(isnumeric(segStr))
       segStr= num2str(segStr);
    end
    segInfoStr=sprintf('%sSession: %s\t',segInfoStr,segStr);
end
if(~isempty(info.Trial))
    segStr=info.Trial;
    if(isnumeric(segStr))
       segStr= num2str(segStr);
    end
    segInfoStr=sprintf('%sTrial: %s\t',segInfoStr,segStr);
end
if(~isempty(info.Block))
    segStr=info.Block;
    if(isnumeric(segStr))
       segStr= num2str(segStr);
    end
    segInfoStr=sprintf('%sBlock: %s\t',segInfoStr,segStr);
end
if(~isempty(info.Condition))
    segStr=info.Condition;
    if(isnumeric(segStr))
       segStr= num2str(segStr);
    end
    segInfoStr=sprintf('%sCondition: %s\t',segInfoStr,segStr);
end

if(isempty(segInfoStr))
   segInfoStr='No information in segment'; 
end


function InitializeViewSettings(handles)

updateCurrentFiltersListbox(handles);
updateCurrentDevice();

global stageAxesHandles
global timelineAxesHandle
global cursorTimelineMode
cursorTimelineMode='start';

timelineAxesHandle=handles.axes_timeline;
stageAxesHandles{1}=handles.axesStage1;
stageAxesHandles{2}=handles.axesStage2;
stageAxesHandles{3}=handles.axesStage3;
stageAxesHandles{4}=handles.axesStage4;

global setF
global PF2
global outputData



handles.text_CurrentDeviceName.String=sprintf('%s %s',setF.device.Info.Manufacturer,setF.device.Info.Name);
handles.text_numChannels.String=sprintf('%i',setF.device.Info.NumberChannels);
handles.text_numProbes.String=sprintf('%i',setF.device.Info.NumberProbes);
handles.text_defaultFs.String=sprintf('%i',setF.device.Info.DefaultSamplingRate);


handles.text_segment_info.String=BuildSegmentInfoString(PF2.data.info);

set(handles.checkbox_baseline_global,'Value',outputData.DirtyBaseline);
handles.edit_baseline_length=sprintf('%.2f',PF2.GUIPF2.baseline.blLength);
handles.edit_baseline_start_time=sprintf('%.2f',PF2.GUIPF2.baseline.startTime);

new_str={'Error'};
probeCount=length(setF.device.Probe);
for i=1:probeCount
    new_str{i}=sprintf('%i',i);
end
set(handles.listbox_probes,'string',new_str);
set(handles.listbox_probes,'Value',1:probeCount);

set(handles.edit_stepSize,'String',sprintf('%.2f',PF2.view.timeStepSize))
set(handles.edit_startTime,'String',sprintf('%.2f',PF2.view.startTime))
set(handles.edit_endTime,'String',sprintf('%.2f',PF2.view.endTime))

PF2.view.plotOD=false;
PF2.view.OxyAuto=1;
PF2.view.LightAuto=1;
set(handles.checkbox_viewLightAuto,'Value',PF2.view.LightAuto);
set(handles.checkbox_viewOxyAuto,'Value',PF2.view.OxyAuto);
PF2.view.LightColorAuto=0;
PF2.view.OxyColorAuto=1;
set(handles.checkbox_viewLightColorAuto,'Value',PF2.view.LightColorAuto);
set(handles.checkbox_viewOxyColorAuto,'Value',PF2.view.OxyColorAuto);
PF2.view.LightMax=setF.device.Info.RawMax;
PF2.view.LightMin=setF.device.Info.RawMin;
set(handles.edit_viewLightMin,'String',sprintf('%.1f',PF2.view.LightMin));
set(handles.edit_viewLightMax,'String',sprintf('%.1f',PF2.view.LightMax));

PF2.view.OxyMax=3;
PF2.view.OxyMin=-3;
set(handles.edit_viewOxyMin,'String',sprintf('%.1f',PF2.view.OxyMin));
set(handles.edit_viewOxyMax,'String',sprintf('%.1f',PF2.view.OxyMax));

if(isempty(PF2.data.info.Age))
    set(handles.edit_DPF_age,'String',num2str(PF2.GUIPF2.curDPF_age));
else
    set(handles.edit_DPF_age,'String',num2str(PF2.data.info.Age));
end

set(handles.edit_DPF_fixed,'String',num2str(PF2.GUIPF2.curDPF_fixed,'%.2f'));

switch(PF2.GUIPF2.dpf_mode)
    case 'None'
        set(handles.popupmenu_dpf_mode,'Value',1);
        set(handles.edit_DPF_fixed,'Enable','off');
         set(handles.edit_DPF_age,'Enable','off');
    case 'Fixed'
        set(handles.popupmenu_dpf_mode,'Value',2);
         set(handles.edit_DPF_fixed,'Enable','on');
          set(handles.edit_DPF_age,'Enable','off');
    case 'Calc'
        set(handles.popupmenu_dpf_mode,'Value',3);
         set(handles.edit_DPF_fixed,'Enable','off');
          set(handles.edit_DPF_age,'Enable','on');
    otherwise
        set(handles.popupmenu_dpf_mode,'Value',3);
         set(handles.edit_DPF_fixed,'Enable','off');
          set(handles.edit_DPF_age,'Enable','on');
end
    

dcm_obj=datacursormode(handles.figure1);
set(dcm_obj,'DisplayStyle','datatip',...
    'SnapToDataVertex','off','Enable','on');
set(dcm_obj,'UpdateFcn', @myupdatefcn);




function updateCurrentFiltersListbox(handles)
% Loads all available functions from processFNIRS2_GUI.cfg
global PF2

curRawStrs=get(handles.listbox_rawMethods,'String');
curRawIdx=get(handles.listbox_rawMethods,'Value');
if(~isempty(curRawStrs))
    curRawM=curRawStrs(curRawIdx);
    if(strcmp(curRawM,'Listbox'))
        curRawM=PF2.GUIPF2.stageRawMethod.name;
    end
else
    curRawM='None';
end

curOxyStrs=get(handles.listbox_oxyMethods,'String');
curOxyIdx=get(handles.listbox_oxyMethods,'Value');
if(~isempty(curOxyStrs))
    curOxyM=curOxyStrs(curOxyIdx);
    if(strcmp(curOxyM,'Listbox'))
        curOxyM=PF2.GUIPF2.stageOxyMethod.name;
    end
else
    curOxyM='None';
end

set(handles.listbox_rawMethods,'String',PF2.myRawMethods.cfg.Sections)
set(handles.listbox_oxyMethods,'String',PF2.myOxyMethods.cfg.Sections)

newRawStrs=get(handles.listbox_rawMethods,'String');
newOxyStrs=get(handles.listbox_oxyMethods,'String');

if(length(PF2.myRawMethods.cfg.Sections)==1)
    set(handles.listbox_rawMethods,'Value',1);
else
    noneIdx=strcmp(newRawStrs,'None');
    newRawIdx=strcmp(newRawStrs,curRawM);
    if(sum(newRawIdx)==1)
        set(handles.listbox_rawMethods,'Value',find(newRawIdx==1));
    elseif(sum(noneIdx)==1)
        set(handles.listbox_rawMethods,'Value',find(noneIdx==1));
    else
        set(handles.listbox_rawMethods,'Value',1);
    end
end

if(length(PF2.myOxyMethods.cfg.Sections)==1)
    set(handles.listbox_oxyMethods,'Value',1);
else
    noneIdx=strcmp(newOxyStrs,'None');
    newOxyIdx=strcmp(newOxyStrs,curOxyM);
    if(sum(newOxyIdx)==1)
        set(handles.listbox_oxyMethods,'Value',find(newOxyIdx==1));
    elseif(sum(noneIdx)==1)
        set(handles.listbox_oxyMethods,'Value',find(noneIdx==1));
    else
        set(handles.listbox_oxyMethods,'Value',1);
    end
end



% --- Outputs from this function are returned to the command line.
function varargout = processFNIRS2_GUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
%varargout{1} = handles.output;
global PF2
global outputData



varargout={};

if(nargout>0)
   if(isfield(PF2,'data')&&isfield(PF2.data,'stage')&&(size(PF2.data.stage,2)==5))
       if(outputData.ProcessOxy&&~isempty(PF2.data.stage{5}))
          outfNIR=PF2.data.stage{5};
          if(~isempty(PF2.data.stage{1}))
            outfNIR.raw=PF2.data.stage{1};
          end
       elseif(outputData.ProcessRaw&&~outputData.OutputRaw)
          if(~isempty(PF2.data.stage{3}))
           outfNIR.OD=PF2.data.stage{3}; %start with OD
          end
          if(~isempty(PF2.data.stage{1}))
            outfNIR.raw=PF2.data.stage{1};
          end
       elseif(outputData.ProcessRaw)
           if(~isempty(PF2.data.stage{2}))
                outfNIR.rawProcessed=PF2.data.stage{2};
           end
          if(~isempty(PF2.data.stage{1}))
            outfNIR.raw=PF2.data.stage{1};
          end
       end
       
       if(isfield(PF2.data,'time'))
           outfNIR.time=PF2.data.time;
       end
       
       if(isfield(PF2.data,'markers'))
           
           if(PF2.OutputLegacyMarkers)
               outfNIR.markers=[];
               outfNIR.markers.data=PF2.data.markers;
           else
               outfNIR.markers=PF2.data.markers;
           end
       end
       
       if(isfield(PF2.data,'info'))
           outfNIR.info=PF2.data.info;
       end
       
       if(exist('outfNIR')&&isfield(PF2.data,'fchMask'))
           outfNIR.fchMask=PF2.data.fchMask;
       end
       
        if(exist('outfNIR')&&isfield(PF2.data,'channels'))
            outfNIR.channels=PF2.data.channels;
        end
        
       
       if(isfield(PF2.data,'takizawa'))
           outfNIR.takizawa=PF2.data.takizawa;
       end
       
       if(isfield(PF2.data,'Aux'))
           outfNIR.Aux=PF2.data.Aux;
       end
       
        if(exist('outfNIR'))
            varargout={outfNIR};
        else
            varargout={[]};
        end
   else
       varargout={[]};
   end
   
end

if(isfield(outputData,'ShowGUI'))
    if(~outputData.ShowGUI)
        clearVarsOnClose();
    end
end


% --------------------------------------------------------------------
function FileMenu_Callback(hObject, eventdata, handles)
% hObject    handle to FileMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OpenMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file = uigetfile('*.fig');
if ~isequal(file, 0)
    open(file);
end

% --------------------------------------------------------------------
function PrintMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to PrintMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
printdlg(handles.figure1)

% --------------------------------------------------------------------
function CloseMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to CloseMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
selection = questdlg(['Close ' get(handles.figure1,'Name') '?'],...
                     ['Close ' get(handles.figure1,'Name') '...'],...
                     'Yes','No','Yes');
if strcmp(selection,'No')
    return;
end

delete(handles.figure1)


function clearVarsOnClose()

global outputData
global PF2
global setF
clear -global outputData;
fieldsToRemove={'data','curMarkersPlot','curMarkers','curNavMarkers','curNavMarkers','view','GUIPF2'};

for i=1:length(fieldsToRemove)
   if(isfield(PF2,fieldsToRemove{i}))
       PF2=rmfield(PF2,fieldsToRemove{i});
   end
end



% --- Executes on button press in pushbutton_loadDeviceCfg.
function pushbutton_loadDeviceCfg_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_loadDeviceCfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
pf2_base.loadDeviceCfg();

updateCurrentDevice();



function updateAutoRejectedChannelLabels(handles)
global PF2
global setF

curCh=[];
curChMask=[];
curSelectedOptode=get(handles.listbox_optodes,'Value');
PF2.curProbes=get(handles.listbox_probes,'Value');
for i=1:length(PF2.curProbes)
    curCh=[curCh,setF.device.Probe{PF2.curProbes(i)}.ChannelNumbers];
    if(isfield(PF2,'data')&&isfield(PF2.data,'fchMask'))
        curChMask=[curChMask,PF2.data.fchMask]; 
    else
        curChMask=[curChMask,true(size(curCh))];
    end
end
curCh=unique(curCh(curCh>0));
[listCh,idx]=sort(curCh);
curChMask=curChMask(idx);

newVal=get(handles.checkbox_rejectCh,'Value')==0;

% --- Executes on button press in checkbox_rejectCh.
function checkbox_rejectCh_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_rejectCh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_rejectCh
global PF2
global setF
global outputData

curCh=[];
curChMask=[];
curSelectedOptode=get(handles.listbox_optodes,'Value');
PF2.curProbes=get(handles.listbox_probes,'Value');
for i=1:length(PF2.curProbes)
    curCh=[curCh,setF.device.Probe{PF2.curProbes(i)}.ChannelNumbers];
    if(isfield(PF2,'data')&&isfield(PF2.data,'fchMask'))
        curChMask=[curChMask,PF2.data.fchMask]; 
    else
        curChMask=[curChMask,true(size(curCh))];
    end
end
curCh=unique(curCh(curCh>0));
[listCh,idx]=sort(curCh);
curChMask=curChMask(idx);

newVal=get(handles.checkbox_rejectCh,'Value')==0;

if(length(PF2.curProbes)==1)
    PF2.data.fchMask(curCh==listCh(curSelectedOptode))=newVal;
    PF2.data.rawMask=ismember(setF.device.Probe{1}.ChannelNumbers,setF.device.Probe{1}.ChannelList(PF2.data.fchMask>PF2.RejectLevel|outputData.ProcessRejected));
end


processFNIR_GUI();
UpdateOptodeList(handles);
updatePlots(handles);

function edit_back(hObject, eventdata, handles)
% hObject    handle to edit_startTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_startTime as text
%        str2double(get(hObject,'String')) returns contents of edit_startTime as a double
global PF2
PF2.view.startTime=str2double(get(handles.edit_startTime,'String'));
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI();
end
updatePlots(handles);


% --- Executes during object creation, after setting all properties.
function edit_startTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_startTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function edit_startTime_Callback(hObject, eventdata, handles)
% hObject    handle to edit_endTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_endTime as text
%        str2double(get(hObject,'String')) returns contents of edit_endTime as a double
global PF2
PF2.view.startTime=min(str2double(get(handles.edit_startTime,'String')),PF2.view.endTime);
set(handles.edit_startTime,'String',sprintf('%.2f',PF2.view.startTime));

if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI()
end
updatePlots(handles)



function edit_endTime_Callback(hObject, eventdata, handles)
% hObject    handle to edit_endTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_endTime as text
%        str2double(get(hObject,'String')) returns contents of edit_endTime as a double
global PF2
PF2.view.endTime=max(str2double(get(handles.edit_endTime,'String')),PF2.view.startTime);
set(handles.edit_endTime,'String',sprintf('%.2f',PF2.view.endTime));
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI()
end
updatePlots(handles)

% --- Executes during object creation, after setting all properties.
function edit_endTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_endTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_stepSize_Callback(hObject, eventdata, handles)
% hObject    handle to edit_stepSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_stepSize as text
%        str2double(get(hObject,'String')) returns contents of edit_stepSize as a double
global PF2
PF2.view.timeStepSize=str2double(get(handles.edit_stepSize,'String'));


% --- Executes during object creation, after setting all properties.
function edit_stepSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_stepSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_viewPrevLargeStep.
function pushbutton_viewPrevLargeStep_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_viewPrevLargeStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
PF2.view.endTime=min(PF2.data.time)+PF2.view.timeStepSize;
PF2.view.startTime=min(PF2.data.time);
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI()
end
updateViewTimeEdits(handles)
updatePlots(handles)


% --- Executes on button press in pushbutton_viewPrevSmallStep.
function pushbutton_viewPrevSmallStep_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_viewPrevSmallStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2

PF2.view.startTime=max(PF2.view.startTime-PF2.view.timeStepSize,min(PF2.data.time));
PF2.view.endTime=max(PF2.view.endTime-PF2.view.timeStepSize,PF2.view.startTime+PF2.view.timeStepSize);
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI()
end
updateViewTimeEdits(handles)
updatePlots(handles)

% --- Executes on button press in pushbutton_viewNextSmallStep.
function pushbutton_viewNextSmallStep_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_viewNextSmallStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global PF2
PF2.view.endTime=min(PF2.view.endTime+PF2.view.timeStepSize,max(PF2.data.time));
PF2.view.startTime=min(PF2.view.startTime+PF2.view.timeStepSize,max(PF2.data.time)-PF2.view.timeStepSize);
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI();
end
updateViewTimeEdits(handles)
updatePlots(handles)

% --- Executes on button press in pushbutton_ViewNextLargeStep.
function pushbutton_ViewNextLargeStep_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_ViewNextLargeStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
PF2.view.endTime=max(PF2.data.time);
PF2.view.startTime=max(min(PF2.data.time),max(PF2.data.time)-PF2.view.timeStepSize);
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI();
end
updateViewTimeEdits(handles);
updatePlots(handles);


% --- Executes on selection change in listbox_optodes.
function listbox_optodes_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_optodes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_optodes contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_optodes
optIdx=get(handles.listbox_optodes,'Value');
optStr=get(handles.listbox_optodes,'String');

if(~isempty(optIdx))
   if(length(optIdx)>1)
       set(handles.checkbox_rejectCh,'Enable','off');
   else
       set(handles.checkbox_rejectCh,'Enable','on');
       set(handles.checkbox_rejectCh,'Value',contains(optStr{optIdx},'(AR)')||contains(optStr{optIdx},'(R)'));
   end
end

updatePlots(handles)

function updatePlots(handles)

global PF2
global setF

figure(handles.figure1);

PF2.curProbe=get(handles.listbox_probes,'Value');
PF2.curCh_listIdx=get(handles.listbox_optodes,'Value');
PF2.curWv=get(handles.listbox_wavelengths,'Value');
PF2.curConc=get(handles.listbox_conc,'Value');
PF2.curChSet=[];
PF2.curWvSet=[];
PF2.curProbeInd=[];

if(PF2.mergedProbe) %All channel numbers are unique for merged probes
    for i =1:length(setF.device.Probe)
        PF2.curProbeInd=[PF2.curProbeInd,i*length(setF.device.Probe{i}.ChannelNumbers)];
        PF2.curChSet=[PF2.curChSet,setF.device.Probe{i}.ChannelNumbers];
        PF2.curWvSet=[PF2.curWvSet,setF.device.Probe{i}.Wavelength];
    end

    tempWvSet=sort(unique(PF2.curWvSet));
    PF2.curWv=tempWvSet(PF2.curWv);
else
   error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

time=PF2.data.time;

startInd=find(PF2.view.startTime<=time);
if(isempty(startInd))
    startInd=1;
else
    startInd=startInd(1);
end
endInd=find(PF2.view.endTime<=time);
if(isempty(endInd))
    endInd=length(time);
else
    endInd=endInd(1);
end
if(endInd<startInd)
    x=endInd;
    endInd=startInd;
    startInd=x;
end

timeInd=startInd:endInd;



%%%%%%% Plot Timeline
global dataTipSelectionHandleTag

global timelineAxesHandle
axes(timelineAxesHandle);
if(~isempty(dataTipSelectionHandleTag))
    for i=1:length(timelineAxesHandle.Children)
        if(~strcmp(timelineAxesHandle.Children(i).Tag,dataTipSelectionHandleTag))
            idx2delete(i)=true; 
        else
            idx2delete(i)=false;
        end
    end
    for i=length(timelineAxesHandle.Children):-1:1
        if(idx2delete(i))
            delete(timelineAxesHandle.Children(i)); 
        end
    end
    
else
    cla(timelineAxesHandle);
end
h=plot(timelineAxesHandle,PF2.data.time,0*PF2.data.time+0.1,'color','White','linewidth',4);
set(h,'Tag','ViewLine');
hold(timelineAxesHandle,'on');
h=plot(timelineAxesHandle,PF2.data.time,0*PF2.data.time-0.1,'color','White','linewidth',4);
set(h,'Tag','ViewLine');
h=plot(timelineAxesHandle,PF2.data.time,0*PF2.data.time,'color','White','linewidth',4);
set(h,'Tag','ViewLine');
h=plot(timelineAxesHandle,PF2.data.time,0*PF2.data.time,'color','White','linewidth',4);
set(h,'Tag','ViewLine');
h=plot(timelineAxesHandle,PF2.data.time,0*PF2.data.time,'--k');
set(h,'Tag','ViewLine');

h=plot(timelineAxesHandle,PF2.data.time(timeInd),0*PF2.data.time(timeInd),'r','linewidth',4);
set(h,'Tag','ViewLine');
h=pf2_base.external.vline(timelineAxesHandle,PF2.view.startTime,{'r','linewidth',4});
set(h,'Tag','StartVLine');
h=pf2_base.external.vline(timelineAxesHandle,PF2.view.endTime,{'r','linewidth',4});
set(h,'Tag','EndVLine');
xlim(timelineAxesHandle,[min(PF2.data.time),max(PF2.data.time)]);
ylim(timelineAxesHandle,[-1,1]);
set(timelineAxesHandle,'xtick',[],'ytick',[])
set(timelineAxesHandle,'Tag','Timeline');


%%%%%% Plot Stage 1
global stageAxesHandles
axes(stageAxesHandles{1});

%if(~fmask(ch))
%    text(max(nirsData(:,1))/2+15,2000,'X','FontSize',40,'Color','red');
%    hold on;
%end
data=PF2.data.stage{1};
optTable=PF2.GUIPF2.optodeTable;

if(~isempty(data))
    plotOptTable=optTable(PF2.curCh_listIdx,:);
    %plotOptTable=plotOptTable(~plotOptTable.ManualRej,:);
    
    if(sum(plotOptTable.IsROI)>0)
        plotROITable=plotOptTable(plotOptTable.IsROI==1,:);
        allROIch=[];
        for idx=1:size(plotROITable)
            allROIch=[allROIch,plotROITable.Optodes_roi{idx}];
        end
        allROIch=unique(allROIch);
        
        single_roi_idx=~optTable.IsROI&ismember(optTable.Optode,allROIch);
        if(sum(single_roi_idx)>0)
            plotSingleROImerge=optTable(single_roi_idx,:);
        else
            plotSingleROImerge=[];
        end
    else
        plotROITable=[];
        plotSingleROImerge=[];
    end
    
    
    
    if(sum(~plotOptTable.IsROI)>0)
        plotSingleTable=plotOptTable(~plotOptTable.IsROI,:);
    else
        if(~isempty(plotSingleROImerge))
            plotSingleTable=plotSingleROImerge;
        else
            plotSingleTable=[];
        end
    end
    
    
    if(~isempty(plotSingleTable))
        plotIdx=(ismember(PF2.curChSet,plotSingleTable.Optode));
    else
       plotIdx=false(size(PF2.curChSet));
    end
    plotIdx2=(ismember(PF2.curWvSet,PF2.curWv));
    plotIdx=find(plotIdx.*plotIdx2);
    num2Plot=length(plotIdx);

    if(PF2.view.LightColorAuto)
        [wvUnique]=sort(unique(round(PF2.curWvSet)));
        wvUnique(isnan(wvUnique))=[];
         cc=lines(length(wvUnique));%linspecer(length(wvUnique),'qualitative');

        rInd=zeros(1,num2Plot);
        for i=1:length(wvUnique)
            rInd=rInd+(PF2.curWvSet(plotIdx)==wvUnique(i)).*i;

        end
        cIndex=cc(rInd,:);
    else
        cc=lines(num2Plot);%linspecer(num2Plot,'qualitative');
        cIndex=cc;
    end


    cla(stageAxesHandles{1});
    for i=1:num2Plot
       h=plot(stageAxesHandles{1},PF2.data.time(timeInd),data(timeInd,plotIdx(i)),'color',cIndex(i,:)); 
       set(h,'Tag',sprintf('Ch%i_%inm',PF2.curChSet(plotIdx(i)),PF2.curWvSet(plotIdx(i))));
       hold(stageAxesHandles{1},'on');
    end

    if(~PF2.view.LightAuto)
       ylim(stageAxesHandles{1},[PF2.view.LightMin,PF2.view.LightMax]); 
    end


    if(~isempty(plotIdx))
       yl=ylim(stageAxesHandles{1});

       if(max(yl)>0.95*setF.device.Info.RawMax)
           plot(stageAxesHandles{1},PF2.data.time(timeInd),PF2.data.time(timeInd)*0+setF.device.Info.RawMax,'--r','linewidth',2);
       end
    end

    xl=[PF2.view.startTime,PF2.view.endTime]; plotMarkers(xl,stageAxesHandles{1});
    hold(stageAxesHandles{1},'off');
    xlim(xl);
    if(setF.device.Info.TimeIsSampleCount)
        xlabel(stageAxesHandles{1},'Time (samples)');
    else
        xlabel(stageAxesHandles{1},'Time (s)');
    end

    %*%xlim([PF2.view.startTime,PF2.view.endTime])

    ylabel(stageAxesHandles{1},'Intensity -  I_i_n');
    set(stageAxesHandles{1},'Tag','Stage1');
end

%%%%%%%%%%%%%%%%% Plot Stage 2
axes(stageAxesHandles{2});

%if(~fmask(ch))
%    text(max(nirsData(:,1))/2+15,2000,'X','FontSize',40,'Color','red');
%    hold on;
%end
if(PF2.view.plotOD)
    data=PF2.data.stage{3};
else
    data=PF2.data.stage{2};
end

cla(stageAxesHandles{2});

plotOptTable=optTable(PF2.curCh_listIdx,:);
plotOptTable=plotOptTable(~plotOptTable.ManualRej,:);
    
if(sum(plotOptTable.IsROI)>0)
    plotROITable=plotOptTable(plotOptTable.IsROI==1,:);
    allROIch=[];
    for idx=1:size(plotROITable)
        allROIch=[allROIch,plotROITable.Optodes_roi{idx}];
    end
    allROIch=unique(allROIch);

    single_roi_idx=~optTable.IsROI&ismember(optTable.Optode,allROIch);
    if(sum(single_roi_idx)>0)
        plotSingleROImerge=optTable(single_roi_idx,:);
    else
        plotSingleROImerge=[];
    end
else
    plotROITable=[];
    plotSingleROImerge=[];
end



if(sum(~plotOptTable.IsROI)>0)
    plotSingleTable=plotOptTable(~plotOptTable.IsROI,:);
else
    if(~isempty(plotSingleROImerge))
        plotSingleTable=plotSingleROImerge;
    else
        plotSingleTable=[];
    end
end

if(~isempty(data)&&~isempty(plotSingleTable))
    plotIdx=(ismember(PF2.curChSet,plotSingleTable.Optode));
    plotIdx2=(ismember(PF2.curWvSet,PF2.curWv));
    plotIdx=find(plotIdx.*plotIdx2);
    num2Plot=length(plotIdx);

    if(PF2.view.LightColorAuto)
        [wvUnique]=sort(unique(round(PF2.curWvSet)));
        wvUnique(isnan(wvUnique))=[];
         cc=lines(length(wvUnique));%linspecer(length(wvUnique),'qualitative');

        rInd=zeros(1,num2Plot);
        for i=1:length(wvUnique)
            rInd=rInd+(PF2.curWvSet(plotIdx)==wvUnique(i)).*i;

        end
        cIndex=cc(rInd,:);
    else
        cc=lines(num2Plot);%linspecer(num2Plot,'qualitative');
        cIndex=cc;
    end


    
    for i=1:num2Plot
       h=plot(stageAxesHandles{2},PF2.data.time(timeInd),data(timeInd,plotIdx(i)),'color',cIndex(i,:)); 
       set(h,'Tag',sprintf('Ch%i_%inm',PF2.curChSet(plotIdx(i)),PF2.curWvSet(plotIdx(i))));
       hold(stageAxesHandles{2},'on');
    end


    if(~PF2.view.LightAuto&&~PF2.view.plotOD)
       ylim([PF2.view.LightMin,PF2.view.LightMax]); 
    else
        %ylim(yl);
    end

    if(~isempty(plotIdx))
       yl=ylim(stageAxesHandles{2});

       if(max(yl)>0.95*setF.device.Info.RawMax)
           plot(stageAxesHandles{2},PF2.data.time(timeInd),PF2.data.time(timeInd)*0+setF.device.Info.RawMax,'--r','linewidth',2);
       end
    end

    xl=[PF2.view.startTime,PF2.view.endTime]; plotMarkers(xl,stageAxesHandles{2});
    hold(stageAxesHandles{2},'off');
    xlim(xl);
    if(setF.device.Info.TimeIsSampleCount)
        xlabel(stageAxesHandles{2},'Time (samples)');
    else
        xlabel(stageAxesHandles{2},'Time (s)');
    end

    %*%xlim([PF2.view.startTime,PF2.view.endTime])
    if(PF2.view.plotOD)
        ylabel(stageAxesHandles{2},'Optical Denisty -  log_1_0(I_i_n)');
    else
        ylabel(stageAxesHandles{2},'Intensity - I_i_n');
    end
    
    set(stageAxesHandles{2},'Tag','Stage2');
end
%%%%%% Plot Stage 3
axes(stageAxesHandles{3});

%if(~fmask(ch))
%    text(max(nirsData(:,1))/2+15,2000,'X','FontSize',40,'Color','red');
%    hold on;
%end
data=PF2.data.stage{4};


if(~isempty(data))
    plotOptTable=optTable(PF2.curCh_listIdx,:);
    plotOptTable=plotOptTable(~plotOptTable.ManualRej,:);
    
    if(sum(plotOptTable.IsROI)>0)
        plotROITable=plotOptTable(plotOptTable.IsROI==1,:);
        allROIch=[];
        for idx=1:size(plotROITable)
            allROIch=[allROIch,plotROITable.Optodes_roi{idx}];
        end
        allROIch=unique(allROIch);
        
        single_roi_idx=~optTable.IsROI&ismember(optTable.Optode,allROIch);
        if(sum(single_roi_idx)>0)
            plotSingleROImerge=optTable(single_roi_idx,:);
        else
            plotSingleROImerge=[];
        end
    else
        plotROITable=[];
        plotSingleROImerge=[];
    end
    
    
    
    if(sum(~plotOptTable.IsROI)>0)
        plotSingleTable=plotOptTable(~plotOptTable.IsROI,:);
    else
        if(~isempty(plotSingleROImerge))
            plotSingleTable=plotSingleROImerge;
        else
            plotSingleTable=[];
        end
    end
    


    %plotIdx2=(ismember(PF2.curConcSet,PF2.curConc));
    

    % if(PF2.view.OxyColorAuto)
    %     [wvUnique]=sort(unique(round(PF2.curWvSet)));
    %     wvUnique(isnan(wvUnique))=[];
    %      cc=lines(length(wvUnique));%linspecer(length(wvUnique),'qualitative');
    %     
    %     rInd=zeros(1,num2Plot);
    %     for i=1:length(wvUnique)
    %         rInd=rInd+(PF2.curWvSet(plotIdx)==wvUnique(i)).*i;
    %         
    %     end
    %     cIndex=cc(rInd,:);
    % else
    %     cc=lines(num2Plot);%linspecer(num2Plot,'qualitative');
    %     cIndex=cc;
    % end
    yl=[PF2.view.OxyMin,PF2.view.OxyMax];

    cla(stageAxesHandles{3})
    
    colorsTable=pf2_base.colorsTable();
    bioM=colorsTable.Properties.VariableNames;
    bioMclr=table2cell(colorsTable);
    numBioM=length(bioM);
    
    for b=1:numBioM
        if(sum(ismember(PF2.curConc,b))>0)
            for i=1:size(plotSingleTable,1)
               h=plot(stageAxesHandles{3},PF2.data.time(timeInd),data.(bioM{b})(timeInd,plotSingleTable.Optode(i)),'color',bioMclr{b}); 
               set(h,'Tag',sprintf('Opt%i_%s',plotSingleTable.Optode(i),bioM{b}));
               hold(stageAxesHandles{3},'on');
            end
        end
    end


    if(~PF2.view.OxyAuto)
       ylim(stageAxesHandles{3},[PF2.view.OxyMin,PF2.view.OxyMax]); 
    end


    if(size(plotOptTable,1)>0)
       yl=ylim(stageAxesHandles{3});

       plot(stageAxesHandles{3},PF2.data.time(timeInd),PF2.data.time(timeInd)*0,'--k','linewidth',1);
    end

    xl=[PF2.view.startTime,PF2.view.endTime]; plotMarkers(xl,stageAxesHandles{3});
    hold(stageAxesHandles{3},'off');
    xlim(xl);
    if(setF.device.Info.TimeIsSampleCount)
        xlabel(stageAxesHandles{3},'Time (samples)');
    else
        xlabel(stageAxesHandles{3},'Time (s)');
    end

    %*%xlim([PF2.view.startTime,PF2.view.endTime])

    if(strcmp(PF2.GUIPF2.dpf_mode,'None'))
        ylabel(stageAxesHandles{3},'\Delta[X] (mM*mm)');
    else
        ylabel(stageAxesHandles{3},'\Delta[X] (\muM)');
    end
    set(stageAxesHandles{3},'Tag','Stage3');
end

axes(stageAxesHandles{4});

%if(~fmask(ch))
%    text(max(nirsData(:,1))/2+15,2000,'X','FontSize',40,'Color','red');
%    hold on;
%end
data=PF2.data.stage{5};

if(~isempty(data))
    plotOptTable=plotOptTable(~plotOptTable.AutoRej,:);
    
    if(sum(~plotOptTable.IsROI)>0)
        plotST_idx=~plotOptTable.IsROI&~plotOptTable.AutoRej&~plotOptTable.ManualRej;
        if(sum(plotST_idx)>0)
            plotSingleTable=plotOptTable(plotST_idx,:);
        else
            plotSingleTable=[];
        end
    else
        plotSingleTable=[];
    end

    cla(stageAxesHandles{4});
    for b=1:numBioM
        if(sum(ismember(PF2.curConc,b))>0)
            for i=1:size(plotSingleTable,1)
               h=plot(stageAxesHandles{4},PF2.data.time(timeInd),data.(bioM{b})(timeInd,plotSingleTable.Optode(i)),'color',bioMclr{b}); 
               set(h,'Tag',sprintf('Opt%i_%s',plotSingleTable.Optode(i),bioM{b}));
               hold(stageAxesHandles{4},'on');
            end
        end
    end
    
    
    for i=1:size(plotROITable,1)
        if(pf2_base.isnestedfield(data,'ROI.HbO'))
            for b=1:numBioM
                if(sum(ismember(PF2.curConc,b))>0)
                   h=plot(stageAxesHandles{4},PF2.data.time(timeInd),data.ROI.(bioM{b})(timeInd,plotROITable.Optode(i)),'color',bioMclr{b}*0.8,'linewidth',1); 
                   set(h,'Tag',sprintf('%s_%s',plotROITable.Label{i},bioM{b}));
                   hold(stageAxesHandles{4},'on');
                end

            end
          else
            fprintf(2,'ROIs have not been built, use a function in Oxy Stage to build ROIs\n');
        end  
    end
    



    if(~PF2.view.OxyAuto)
       ylim(stageAxesHandles{4},[PF2.view.OxyMin,PF2.view.OxyMax]); 
    else

        %ylim(stageAxesHandles{4},yl);
    end


    if(size(plotOptTable,1)>0)
       yl=ylim(stageAxesHandles{4});

       plot(stageAxesHandles{4},PF2.data.time(timeInd),PF2.data.time(timeInd)*0,'--k','linewidth',1);
    end

    xl=[PF2.view.startTime,PF2.view.endTime]; plotMarkers(xl,stageAxesHandles{4});
    xlim(xl);
    hold(stageAxesHandles{4},'off');

    if(setF.device.Info.TimeIsSampleCount)
        xlabel(stageAxesHandles{4},'Time (samples)');
    else
        xlabel(stageAxesHandles{4},'Time (s)');
    end

    %*%xlim([PF2.view.startTime,PF2.view.endTime])

    if(strcmp(PF2.GUIPF2.dpf_mode,'None'))
        ylabel(stageAxesHandles{4},'\Delta[X] (mM*mm)');
    else
        ylabel(stageAxesHandles{4},'\Delta[X] (\muM)');
    end
    set(stageAxesHandles{4},'Tag','Stage4');
end

if(isfield(PF2,'rawTopo'))
    for pt=1:length(PF2.rawTopo)
        curTopoH=PF2.rawTopo{pt};
        isValidH=~isempty(curTopoH)&&isvalid(curTopoH);
        if(isValidH)
            plotRawArranged(handles,false);
        end
    end
end

if(isfield(PF2,'rawTopo_pre'))
    for pt=1:length(PF2.rawTopo_pre)
        curTopoH=PF2.rawTopo_pre{pt};
        isValidH=~isempty(curTopoH)&&isvalid(curTopoH);
        if(isValidH)
            plotRawArranged(handles,true);
        end
    end
end

if(isfield(PF2,'rawTopo_I'))
    for pt=1:length(PF2.rawTopo_I)
        curTopoH=PF2.rawTopo_I{pt};
        isValidH=~isempty(curTopoH)&&isvalid(curTopoH);
        if(isValidH)
            plotRawArranged(handles,false,false);
        end
    end
end

if(isfield(PF2,'oxyTopo'))
    for pt=1:length(PF2.oxyTopo)
        curTopoH=PF2.oxyTopo{pt};
        isValidH=~isempty(curTopoH)&&isvalid(curTopoH);
        if(isValidH)
            plotOxyArranged(handles,false);
        end
    end
end

if(isfield(PF2,'oxyTopo_pre'))
    for pt=1:length(PF2.oxyTopo_pre)
        curTopoH=PF2.oxyTopo_pre{pt};
        isValidH=~isempty(curTopoH)&&isvalid(curTopoH);
        if(isValidH)
            plotOxyArranged(handles,true);
        end
    end
end

if(isfield(PF2,'PF2Analyze'))
    for pt=1:length(PF2.PF2Analyze)
        curTopoH=PF2.PF2Analyze{pt};
        isValidH=~isempty(curTopoH)&&isvalid(curTopoH);
        if(isValidH)
            runPF2Analyze(curTopoH);
        end
    end
end

function runPF2Analyze(curTopoH)

global PF2
data=PF2.data.stage{5};
if(PF2.view.processWindowOnly)
    validRows=data.validRows;
    data.raw=PF2.data.stage{1};
    data.HbO=data.HbO(validRows,:);
    data.HbR=data.HbR(validRows,:);
    data.HbDiff=data.HbDiff(validRows,:);
    data.HbTotal=data.HbTotal(validRows,:);
    data.CBSI=data.CBSI(validRows,:);
    data.time=data.time(validRows,:);
end
if(isfield(PF2.data,'markers'))
    data.markers=PF2.data.markers;
end
pt=1;
PF2.PF2Analyze{pt}=PF2Analyze(data,curTopoH);


function updateTitleText(handles,titlestr)

function chName=getChName(ind,probeNum)
if(nargin<2)
    probeNum=1;
end
global PF2
if(PF2.mergedProbe)
    chNum=PF2.curChSet(ind);
    wv=PF2.curWvSet(ind);
    if(length(PF2.device.Probe)>1)
        probInd=PF2.curProbeInd(ind);
        chName=sprintf('P%i_O%i_%inm',probInd,chNum,wv);
    else
        chName=sprintf('Opt%i_%inm',chNum,wv);
    end
else
    chNum=PF2.device.Probe{probeNum}.ChannelNumbers(ind);
    wv=PF2.device.Probe{probeNum}.Wavelengths(ind);
    chName=sprintf('P%i_O%i_%inm',probeNum,chNum,wv);
end







% --- Executes during object creation, after setting all properties.
function listbox_optodes_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_optodes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_wavelengths.
function listbox_wavelengths_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_wavelengths (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_wavelengths contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_wavelengths
updatePlots(handles)

% --- Executes during object creation, after setting all properties.
function listbox_wavelengths_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_wavelengths (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_optodes_all.
function pushbutton_optodes_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_optodes_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if(iscell(get(handles.listbox_optodes, 'String')))
    sList = numel(get(handles.listbox_optodes, 'String'));
else
    sList=1;
end
set(handles.listbox_optodes,'Value',1:sList);
listbox_optodes_Callback(hObject, eventdata, handles);

% --- Executes on button press in pushbutton_optodes_none.
function pushbutton_optodes_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_optodes_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.listbox_optodes,'Value',[]);
listbox_optodes_Callback(hObject, eventdata, handles);

% --- Executes on button press in pushbutton_optodes_next.
function pushbutton_optodes_next_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_optodes_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(iscell(get(handles.listbox_optodes, 'String')))
    sList = numel(get(handles.listbox_optodes, 'String'));
else
    sList=1;
end
curCh=get(handles.listbox_optodes,'Value');
if(isempty(curCh))
    curCh=1;
elseif(max(curCh)<sList)
    curCh=max(curCh)+1;
else
    curCh=sList;
end
set(handles.listbox_optodes,'Value',curCh);
listbox_optodes_Callback(hObject, eventdata, handles);

% --- Executes on button press in pushbutton_optodes_prev.
function pushbutton_optodes_prev_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_optodes_prev (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(iscell(get(handles.listbox_optodes, 'String')))
    sList = numel(get(handles.listbox_optodes, 'String'));
else
    sList=1;
end
curCh=get(handles.listbox_optodes,'Value');
if(isempty(curCh))
    curCh=1;
    
elseif(min(curCh)>1)
    curCh=min(curCh)-1;
else
    curCh=1;
end
set(handles.listbox_optodes,'Value',curCh);
listbox_optodes_Callback(hObject, eventdata, handles);

% --- Executes on selection change in listbox_conc.
function listbox_conc_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_conc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_conc contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_conc
updatePlots(handles)

% --- Executes during object creation, after setting all properties.
function listbox_conc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_conc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_chromophores_all.
function pushbutton_chromophores_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_chromophores_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(iscell(get(handles.listbox_conc, 'String')))
    sList = numel(get(handles.listbox_conc, 'String'));
else
    sList=1;
end
set(handles.listbox_conc,'Value',1:sList);
updatePlots(handles)


% --- Executes on button press in pushbutton_chromophores_none.
function pushbutton_chromophores_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_chromophores_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.listbox_conc,'Value',[]);
updatePlots(handles)

% --- Executes on selection change in listbox_probes.
function listbox_probes_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_probes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_probes contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_probes
UpdateOptodeList(handles)

function BuildProbeTables()
global PF2
global setF

probeTable=table([],[],[],[],[],'VariableNames',{'ProbeNum','Index','Optode','Wv','Label'});
optodeTable=table([],[],[],[],[],[],{},'VariableNames',{'ProbeNum','Optode','ManualRej','AutoRej','IsROI','Label','Optodes_roi'});
for i=1:length(setF.device.Probe)
    probeNum=i;
    rawChannels=setF.device.Probe{probeNum}.ChannelNumbers;
    numCh=length(rawChannels);
    probeChIdx=1:numCh;
    startIdx_probe=size(probeTable,1)+1;
    endIdx_probe=numCh;
    probeTable.Index(startIdx_probe:endIdx_probe)=probeChIdx;
    probeTable.Optode(startIdx_probe:endIdx_probe)=rawChannels;
    probeTable.ProbeNum(startIdx_probe:endIdx_probe)=probeNum;
    probeTable.Wv(startIdx_probe:endIdx_probe)=setF.device.Probe{probeNum}.Wavelength;
    
    if(i==1)%need to convert to string only the first time
        probeTable.Label=cellstr(num2str(probeTable.Label));
    end
    
    for ch=1:numCh
        idx=startIdx_probe+ch-1;
        probeTable.Label{idx}=sprintf('P%iC%iW%.0f',probeNum,probeTable.Optode(idx),probeTable.Wv(idx));
    end
    
    probeOptodes=unique(rawChannels(rawChannels>0));
    
    numOpt=length(probeOptodes);
    startIdx_opt=size(optodeTable,1)+1;
    endIdx_opt=numOpt;
    
    optodeTable.ProbeNum(startIdx_opt:endIdx_opt)=probeNum;
    optodeTable.Optode(startIdx_opt:endIdx_opt)=probeOptodes;
    optodeTable.IsROI(startIdx_opt:endIdx_opt)=false;
    

    if(i==1)
        optodeTable.Label=cellstr(num2str(optodeTable.Label));
    end
end


PF2.GUIPF2.optodeTable=optodeTable;
PF2.GUIPF2.probeTable=probeTable;

function updateOptodeTablesROI()

global PF2
global setF

PF2.GUIPF2.optodeTable=PF2.GUIPF2.optodeTable(PF2.GUIPF2.optodeTable.IsROI==false,:);

numProbes=length(setF.device.Probe);

if(pf2_base.isnestedfield(PF2,'data.ROI.info'))
   for probeNum=1:numProbes
       if(iscell(PF2.data.ROI.info)) % If its a cell, make it a better format
           rownames=cell(1,length(PF2.data.ROI.info));
           for r=1:length(PF2.data.ROI.info)
               rownames{r}=sprintf('ROI%i',r);
           end
           PF2.data.ROI.info=table(PF2.data.ROI.info,'VariableNames',{'Optodes'},'RowNames',rownames);
       end
       
       if(istable(PF2.data.ROI.info))
           roi_names=PF2.data.ROI.info.Properties.RowNames;
           start_idx=size(PF2.GUIPF2.optodeTable,1);
            for roi=1:size(PF2.data.ROI.info,1)
                
                idx=start_idx+roi;

                PF2.GUIPF2.optodeTable.ProbeNum(idx)=probeNum;
                PF2.GUIPF2.optodeTable.Optode(idx)=roi;
                PF2.GUIPF2.optodeTable.IsROI(idx)=true;
                PF2.GUIPF2.optodeTable.Optodes_roi(idx)=PF2.data.ROI.info.Optodes(roi);
                
                if(numProbes>1)
                    PF2.GUIPF2.optodeTable.Label{idx}=sprintf('P%i-%s',probeNum,roi_names{roi});
                else
                    PF2.GUIPF2.optodeTable.Label(idx)=roi_names(roi);
                end
            end
       end
   end
end
    
    



function UpdateOptodeList(handles)
global PF2
global setF



curOptStrs=get(handles.listbox_optodes,'String');
if(ischar(curOptStrs)&&contains(curOptStrs,'Select')||isempty(PF2.GUIPF2.optodeTable))
    initLists=true;
    BuildProbeTables();
else
    initLists=false;
end


PF2.curProbes=get(handles.listbox_probes,'Value');
numProbes=length(setF.device.Probe);

for probeNum=1:numProbes
    probeOptIdx=(PF2.GUIPF2.optodeTable.ProbeNum==probeNum&~PF2.GUIPF2.optodeTable.IsROI);
    
    if(pf2_base.isnestedfield(PF2,'data.curChMask'))
        PF2.GUIPF2.optodeTable.AutoRej(probeOptIdx)=~PF2.data.curChMask;
    else
        PF2.GUIPF2.optodeTable.AutoRej(probeOptIdx)=false;
    end
    
    if(isfield(PF2,'data')&&isfield(PF2.data,'fchMask'))
        PF2.GUIPF2.optodeTable.ManualRej(probeOptIdx)=~PF2.data.fchMask>PF2.RejectLevel; 
    else
        PF2.GUIPF2.optodeTable.ManualRej(probeOptIdx)=false;
    end
    
    

    probeRow=find(probeOptIdx);
    numOpt=length(probeRow);
    
    if(numProbes>1)
       opt_start_string=sprintf('P%i-',probeNum); 
    else
       opt_start_string='';
    end
    
    for opt=1:numOpt
        idx=probeRow(opt);
        if(PF2.GUIPF2.optodeTable.ManualRej(idx))
            PF2.GUIPF2.optodeTable.Label{idx}=sprintf('%s%i(R)',opt_start_string,PF2.GUIPF2.optodeTable.Optode(idx));
        elseif(PF2.GUIPF2.optodeTable.AutoRej(idx))
            PF2.GUIPF2.optodeTable.Label{idx}=sprintf('%s%i(AR)',opt_start_string,PF2.GUIPF2.optodeTable.Optode(idx));
        else
            PF2.GUIPF2.optodeTable.Label{idx}=sprintf('%s%i',opt_start_string,PF2.GUIPF2.optodeTable.Optode(idx)); 
        end
    end
end

updateOptodeTablesROI();

%if(isfield())
curSelectedOptode=get(handles.listbox_optodes,'Value');
    
%end
totalOpt=size(PF2.GUIPF2.optodeTable.Label,1);

set(handles.listbox_optodes,'string',PF2.GUIPF2.optodeTable.Label);


if(initLists||isempty(curSelectedOptode)||max(curSelectedOptode)>totalOpt)
    curSelectedOptode=1;
end

set(handles.listbox_optodes,'Value',curSelectedOptode);

strWv={};
listWv=sort(unique(PF2.GUIPF2.probeTable.Wv));
numList=0;
for i=1:length(listWv)
   if(listWv(i)>0)
        numList=numList+1;
        strWv{numList}=sprintf('%.1f',listWv(i)); 
   elseif(listWv(i)==0)
       numList=numList+1;
       strWv{numList}='Dark'; %sprintf('%i',listWv(i)); 
   end
end


curSelectedWv=get(handles.listbox_wavelengths,'Value');
set(handles.listbox_wavelengths,'string',strWv);
if(initLists||isempty(curSelectedWv)||max(curSelectedWv)>numList)
   curSelectedWv=1:numList; 
end
set(handles.listbox_wavelengths,'Value',curSelectedWv);

strConc={};
listConc={'HbO','HbR','Delta','Total','CBSI'};
numList=0;
for i=1:length(listConc)
        numList=numList+1;
        strConc{numList}=listConc{i}; 
end


curSelectedConc=get(handles.listbox_conc,'Value');
set(handles.listbox_conc,'string',strConc);
if(initLists||isempty(curSelectedConc)||max(curSelectedConc)>numList)
    curSelectedConc=1:3;
end
set(handles.listbox_conc,'Value',curSelectedConc);





% --- Executes during object creation, after setting all properties.
function listbox_probes_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_probes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_wavelengths_all.
function pushbutton_wavelengths_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_wavelengths_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(iscell(get(handles.listbox_wavelengths, 'String')))
    sList = numel(get(handles.listbox_wavelengths, 'String'));
else
    sList=1;
end
set(handles.listbox_wavelengths,'Value',1:sList);
updatePlots(handles)

% --- Executes on button press in pushbutton_wavelengths_none.
function pushbutton_wavelengths_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_wavelengths_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.listbox_wavelengths,'Value',[]);
updatePlots(handles)


% --- Executes on button press in pushbutton_viewAll.
function pushbutton_viewAll_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_viewAll (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
PF2.view.endTime=max(PF2.data.time);
PF2.view.startTime=min(PF2.data.time);

updateViewTimeEdits(handles)
if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
    processFNIR_GUI();
end
updatePlots(handles)


function updateViewTimeEdits(handles)
global PF2
set(handles.edit_endTime,'String',sprintf('%.2f',PF2.view.endTime));
set(handles.edit_startTime,'String',sprintf('%.2f',PF2.view.startTime));



function edit_viewLightMin_Callback(hObject, eventdata, handles)
% hObject    handle to edit_viewLightMin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_viewLightMin as text
%        str2double(get(hObject,'String')) returns contents of edit_viewLightMin as a double
global PF2

PF2.view.LightMin=str2double(get(hObject,'String'));
updatePlots(handles)


% --- Executes during object creation, after setting all properties.
function edit_viewLightMin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_viewLightMin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_viewOxyMin_Callback(hObject, eventdata, handles)
% hObject    handle to edit_viewOxyMin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_viewOxyMin as text
%        str2double(get(hObject,'String')) returns contents of edit_viewOxyMin as a double
global PF2

PF2.view.OxyMin=str2double(get(hObject,'String'));
updatePlots(handles)


% --- Executes during object creation, after setting all properties.
function edit_viewOxyMin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_viewOxyMin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_viewLightMax_Callback(hObject, eventdata, handles)
% hObject    handle to edit_viewLightMax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_viewLightMax as text
%        str2double(get(hObject,'String')) returns contents of edit_viewLightMax as a double
global PF2

PF2.view.LightMax=str2double(get(hObject,'String'));
updatePlots(handles)


% --- Executes during object creation, after setting all properties.
function edit_viewLightMax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_viewLightMax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_viewOxyMax_Callback(hObject, eventdata, handles)
% hObject    handle to edit_viewOxyMax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_viewOxyMax as text
%        str2double(get(hObject,'String')) returns contents of edit_viewOxyMax as a double
global PF2

PF2.view.OxyMax=str2double(get(hObject,'String'));
updatePlots(handles)

% --- Executes during object creation, after setting all properties.
function edit_viewOxyMax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_viewOxyMax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_viewLightAuto.
function checkbox_viewLightAuto_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_viewLightAuto (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_viewLightAuto
global PF2

PF2.view.LightAuto=get(hObject,'Value');
updatePlots(handles);

% --- Executes on button press in checkbox_viewOxyAuto.
function checkbox_viewOxyAuto_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_viewOxyAuto (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_viewOxyAuto
global PF2

PF2.view.OxyAuto=get(hObject,'Value');
updatePlots(handles);


% --- Executes on button press in checkbox_viewLightColorAuto.
function checkbox_viewLightColorAuto_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_viewLightColorAuto (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_viewLightColorAuto
global PF2

PF2.view.LightColorAuto=get(hObject,'Value');
updatePlots(handles);

% --- Executes on button press in checkbox_viewOxyColorAuto.
function checkbox_viewOxyColorAuto_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_viewOxyColorAuto (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_viewOxyColorAuto
global PF2

PF2.view.OxyColorAuto=get(hObject,'Value');
updatePlots(handles);


% --- Executes on selection change in listbox_oxyMethods.
function listbox_oxyMethods_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_oxyMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_oxyMethods contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_oxyMethods


global PF2
selected=get(handles.listbox_oxyMethods,'Value');
strings=get(handles.listbox_oxyMethods,'String');
selectedMethod=strings{selected};

if(~ismember(PF2.myOxyMethods.cfg.Sections,selectedMethod))
    selectedMethod='None';
    updateCurrentFiltersListbox(handles);
end

PF2.GUIPF2.stageOxyMethod=pf2_base.pf2_unpackMethod(PF2.myOxyMethods.cfg.(selectedMethod));
PF2.GUIPF2.stageOxyMethod.name=selectedMethod;

processFNIR_GUI();
updatePlots(handles);


% --- Executes during object creation, after setting all properties.
function listbox_oxyMethods_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_oxyMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_oxyMethods.
function listbox8_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_oxyMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_oxyMethods contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_oxyMethods


% --- Executes during object creation, after setting all properties.
function listbox8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_oxyMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_oxyConfigure.
function pushbutton_oxyConfigure_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_oxyConfigure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.parameters.stage = ['oxy']; %SecondGUIStuff;
handles.parameters.main_GUI_handles=handles;
handles.parameters.main_GUI_hObject=hObject;
processFNIRS2_configureMethods('oxy',handles.parameters);

% --- Executes on button press in pushbutton_rawConfigure.
function pushbutton_rawConfigure_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_rawConfigure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.parameters.stage = ['raw']; %SecondGUIStuff;
handles.parameters.main_GUI_handles=handles;
handles.parameters.main_GUI_hObject=hObject;
processFNIRS2_configureMethods('raw',handles.parameters);
%handles.paramListener = addlistener( handles.parameters, 'StuffChanged', @( src, evt ) updateTable( handles.figure1 ) );

function updateTable( hGUI )
handles = guidata( hGUI );

function edit_DPF_age_Callback(hObject, eventdata, handles)
% hObject    handle to edit_DPF_age (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_DPF_age as text
%        str2double(get(hObject,'String')) returns contents of edit_DPF_age as a double
global PF2

newDPFage=str2double(get(handles.edit_DPF_age,'String'));
if(newDPFage>100)
    newDPFage=100;
elseif(newDPFage<1)
    newDPFage=1;
end
set(handles.edit_DPF_age,'String',num2str(newDPFage,'%.0f'));

global setF

probe_wv_set=setF.device.Probe{1}.Wavelength;
wv_set=unique(floor(probe_wv_set(probe_wv_set>0)));

wv1=min(wv_set);
wv2=max(wv_set);



%calculations for DpF based on Scholkmann (2013)
% valid for Frontal cortex, but other values may be needed once program is
% extended to other corticies
alpha=223.3;
beta=0.05624;
gamma=0.8493;
delta=-5.723e-7;
eta=0.001245;
sigma=-0.9025;
calcDPF=@(lambda,Age) alpha + beta*Age.^gamma+delta*lambda.^3+eta.*lambda.^2+sigma*lambda;

set(handles.text_wv1_dpf,'String',sprintf('%inm: %.2f',wv1,calcDPF(wv1,newDPFage)));
set(handles.text_wv2_dpf,'String',sprintf('%inm: %.2f',wv2,calcDPF(wv2,newDPFage)));
PF2.GUIPF2.curDPF_age=newDPFage;

processFNIR_GUI();
updatePlots(handles);




% --- Executes during object creation, after setting all properties.
function edit_DPF_age_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_DPF_age (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function axesStage1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axesStage1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axesStage1


% --- Executes during object creation, after setting all properties.
function listbox_rawMethods_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_rawMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_rawMethods.
function listbox_rawMethods_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_rawMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_rawMethods contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_rawMethods

global PF2
selected=get(handles.listbox_rawMethods,'Value');
strings=get(handles.listbox_rawMethods,'String');
selectedMethod=strings{selected};

if(~ismember(PF2.myRawMethods.cfg.Sections,selectedMethod))
    selectedMethod='None';
    updateCurrentFiltersListbox(handles);
end
     
PF2.GUIPF2.stageRawMethod=pf2_base.pf2_unpackMethod(PF2.myRawMethods.cfg.(selectedMethod));
PF2.GUIPF2.stageRawMethod.name=selectedMethod;
processFNIR_GUI();
updatePlots(handles);


% --- Executes on button press in pushbutton_reloadMethods.
function pushbutton_reloadMethods_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_reloadMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateCurrentFiltersListbox(handles);
processFNIR_GUI();
updatePlots(handles);


% --- Executes during object creation, after setting all properties.
function uipanel5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to uipanel5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in pushbutton_arranged_oxy.
function pushbutton_arranged_oxy_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_arranged_oxy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

plotOxyArranged(handles,false);

function plotOxyArranged(handles,preProcessed)


global PF2
global setF
PF2.curProbe=get(handles.listbox_probes,'Value');
PF2.curCh_listIdx=get(handles.listbox_optodes,'Value');
PF2.curWv=get(handles.listbox_wavelengths,'Value');
PF2.curConc=get(handles.listbox_conc,'Value');
PF2.curChSet=[];
PF2.curWvSet=[];
PF2.curProbeInd=[];

if(PF2.mergedProbe) %All channel numbers are unique for merged probes
    for i =1:length(setF.device.Probe)
        PF2.curProbeInd=[PF2.curProbeInd,i*length(setF.device.Probe{i}.ChannelNumbers)];
        PF2.curChSet=[PF2.curChSet,setF.device.Probe{i}.ChannelNumbers];
        PF2.curWvSet=[PF2.curWvSet,setF.device.Probe{i}.Wavelength];
        PF2.topoPlotInfo{i}=setF.device.Probe{i}.OptLayout2D;
    end

    tempWvSet=sort(unique(PF2.curWvSet));
    PF2.curWv=tempWvSet(PF2.curWv);
else
   error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

time=PF2.data.time;

startInd=find(PF2.view.startTime<=time);
if(isempty(startInd))
    startInd=1;
else
    startInd=startInd(1);
end
endInd=find(PF2.view.endTime<=time);
if(isempty(endInd))
    endInd=length(time);
else
    endInd=endInd(1);
end

if(endInd<startInd)
    x=endInd;
    endInd=startInd;
    startInd=x;
end

timeInd=startInd:endInd;
if(preProcessed)
    data=PF2.data.stage{4};
else
    data=PF2.data.stage{5};
end

if(~isempty(data))

    %%%%%% Plot for each probe
    for prb=1:length(PF2.topoPlotInfo)
        curTopoInfo=PF2.topoPlotInfo{prb};
        
        if(preProcessed)
            PF2.oxyTopo_pre{prb}=figure(200+prb+10*preProcessed);
            clf(PF2.oxyTopo_pre{prb});
            annotstr=sprintf('Probe %i: Preprocessed Oxy',prb); 
            th=annotation(PF2.oxyTopo_pre{prb},'textbox',[0,1,0,0],'String',annotstr,'FitBoxToText','on');
        else
            PF2.oxyTopo{prb}=figure(200+prb+10*preProcessed);
            clf(PF2.oxyTopo{prb});
            annotstr=sprintf('Probe %i: Processed Oxy',prb); 
            th=annotation(PF2.oxyTopo{prb},'textbox',[0,1,0,0],'String',annotstr,'FitBoxToText','on');
            
        end

        numOptodes=length(curTopoInfo);
        
        for optIdx=1:numOptodes
            h{optIdx}= axes('Position',[0 0 .001 .001],'Box','on');
            h{optIdx}.OuterPosition=curTopoInfo{optIdx};
        end

        for optIdx=1:numOptodes
            axes(h{optIdx});
            

            plotIdx=(ismember(data.channels,optIdx));
            %plotIdx2=(ismember(PF2.curConcSet,PF2.curConc));
            plotIdx=find(plotIdx);%.*plotIdx2);

            % if(PF2.view.OxyColorAuto)
            %     [wvUnique]=sort(unique(round(PF2.curWvSet)));
            %     wvUnique(isnan(wvUnique))=[];
            %      cc=lines(length(wvUnique));%linspecer(length(wvUnique),'qualitative');
            %     
            %     rInd=zeros(1,num2Plot);
            %     for i=1:length(wvUnique)
            %         rInd=rInd+(PF2.curWvSet(plotIdx)==wvUnique(i)).*i;
            %         
            %     end
            %     cIndex=cc(rInd,:);
            % else
            %     cc=lines(num2Plot);%linspecer(num2Plot,'qualitative');
            %     cIndex=cc;
            % end

            cla
            if(sum(ismember(PF2.curConc,1))>0)
                for i=1:length(plotIdx)
                   plot(data.time(timeInd),data.HbO(timeInd,plotIdx(i)),'r'); 
                   hold on;
                end
            end

            if(sum(ismember(PF2.curConc,2))>0)
                for i=1:length(plotIdx)
                   plot(data.time(timeInd),data.HbR(timeInd,plotIdx(i)),'b'); 
                   hold on;
                end
            end

            if(sum(ismember(PF2.curConc,3))>0)
                for i=1:length(plotIdx)
                   plot(data.time(timeInd),data.HbDiff(timeInd,plotIdx(i)),'k'); 
                   hold on;
                end
            end

            if(sum(ismember(PF2.curConc,4))>0)
                for i=1:length(plotIdx)
                   plot(data.time(timeInd),data.HbTotal(timeInd,plotIdx(i)),'color',[0.6,0,0.6]);
                   hold on;
                end
            end

            if(sum(ismember(PF2.curConc,5))>0)
                for i=1:length(plotIdx)
                   plot(data.time(timeInd),data.CBSI(timeInd,plotIdx(i)),'color',[0,0.7,0.7]); 
                   hold on;
                end
            end

            if(~PF2.view.OxyAuto)
               ylim([PF2.view.OxyMin,PF2.view.OxyMax]); 
            end


            if(~isempty(plotIdx))
               yl=ylim;

               plot(data.time(timeInd),data.time(timeInd)*0,'--k','linewidth',1);
            else
               
               th=text(0.5,0.5,'X','FontSize',40,'color',[1,0,0]); axis off
            end

            xl=[PF2.view.startTime,PF2.view.endTime]; plotMarkers(xl);
            hold off;

            if(setF.device.Info.TimeIsSampleCount)
                xlabel('Time (samples)');
            else
                xlabel('Time (s)');
            end

            %*%xlim([PF2.view.startTime,PF2.view.endTime])
            title(sprintf('P%i: Opt%i',prb,optIdx));
            if(strcmp(PF2.GUIPF2.dpf_mode,'None'))
                ylabel('\Delta[X] (mM*mm)');
            else
                ylabel('\Delta[X] (\muM)');
            end
        end

    end
    
    
end

% --- Executes on button press in pushbutton_arranged_raw.
function pushbutton_arranged_raw_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_arranged_raw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


plotRawArranged(handles,false,false);


function plotRawArranged(handles,preProcessed,plotIntensity)
if(nargin<3)
    plotIntensity=true;
end
global PF2
global setF
PF2.curProbe=get(handles.listbox_probes,'Value');
PF2.curCh_listIdx=get(handles.listbox_optodes,'Value');
PF2.curWv=get(handles.listbox_wavelengths,'Value');
PF2.curConc=get(handles.listbox_conc,'Value');
PF2.curChSet=[];
PF2.curWvSet=[];
PF2.curProbeInd=[];

if(PF2.mergedProbe) %All channel numbers are unique for merged probes
    for i =1:length(setF.device.Probe)
        PF2.curProbeInd=[PF2.curProbeInd,i*length(setF.device.Probe{i}.ChannelNumbers)];
        PF2.curChSet=[PF2.curChSet,setF.device.Probe{i}.ChannelNumbers];
        PF2.curWvSet=[PF2.curWvSet,setF.device.Probe{i}.Wavelength];
        PF2.topoPlotInfo{i}=setF.device.Probe{i}.OptLayout2D;
    end

    tempWvSet=sort(unique(PF2.curWvSet));
    PF2.curWv=tempWvSet(PF2.curWv);
else
   error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

time=PF2.data.time;

startInd=find(PF2.view.startTime<=time);
if(isempty(startInd))
    startInd=1;
else
    startInd=startInd(1);
end
endInd=find(PF2.view.endTime<=time);
if(isempty(endInd))
    endInd=length(time);
else
    endInd=endInd(1);
end
if(endInd<startInd)
    x=endInd;
    endInd=startInd;
    startInd=x;
end
if(endInd<startInd)
    x=endInd;
    endInd=startInd;
    startInd=x;
end

timeInd=startInd:endInd;

if(preProcessed==true)
    data=PF2.data.stage{1};
elseif(plotIntensity)
    data=PF2.data.stage{2};
else % plot OD
    data=PF2.data.stage{3};
end

if(~isempty(data))

    plotIdx2=(ismember(PF2.curWvSet,PF2.curWv));

%%%%%% Plot for each probe
    for prb=1:length(PF2.topoPlotInfo)
        curTopoInfo=PF2.topoPlotInfo{prb};
        if(preProcessed)
             PF2.rawTopo_pre{prb}=figure(100+prb+10*preProcessed);
             clf(PF2.rawTopo_pre{prb});
            annotstr=sprintf('Probe %i: Preprocessed Raw',prb);
            th=annotation(PF2.rawTopo_pre{prb},'textbox',[0,1,0,0],'String',annotstr,'FitBoxToText','on');
        elseif(plotIntensity)
            PF2.rawTopo_I{prb}=figure(100+prb+10*preProcessed+20*plotIntensity);
            clf(PF2.rawTopo_I{prb});
            annotstr=sprintf('Probe %i: Partially Processed Intensity',prb);
            th=annotation(PF2.rawTopo_I{prb},'textbox',[0,1,0,0],'String',annotstr,'FitBoxToText','on');
        else

            PF2.rawTopo{prb}=figure(100+prb+10*preProcessed);
            clf(PF2.rawTopo{prb});
            annotstr=sprintf('Probe %i: Processed Raw',prb);
            th=annotation(PF2.rawTopo{prb},'textbox',[0,1,0,0],'String',annotstr,'FitBoxToText','on');
        end
        numOptodes=length(curTopoInfo);
        
        
        for optIdx=1:numOptodes
            h{optIdx}= axes('Position',[0 0 .001 .001],'Box','on');
            h{optIdx}.OuterPosition=curTopoInfo{optIdx};
        end

        for optIdx=1:numOptodes
            axes(h{optIdx});
            
            plotIdx=(ismember(PF2.curChSet,optIdx));

            plotIdx=find(plotIdx.*plotIdx2==1);
            num2Plot=length(plotIdx);

            if(PF2.view.LightColorAuto)
                [wvUnique]=sort(unique(round(PF2.curWvSet)));
                wvUnique(isnan(wvUnique))=[];
                 cc=lines(length(wvUnique));%linspecer(length(wvUnique),'qualitative');

                rInd=zeros(1,num2Plot);
                for i=1:length(wvUnique)
                    rInd=rInd+(PF2.curWvSet(plotIdx)==wvUnique(i)).*i;

                end
                cIndex=cc(rInd,:);
            else
                cc=lines(num2Plot);%linspecer(num2Plot,'qualitative');
                cIndex=cc;
            end


            cla
            for i=1:num2Plot
               plot(PF2.data.time(timeInd),data(timeInd,plotIdx(i)),'color',cIndex(i,:)); 
               hold on;
            end

            if(~PF2.view.LightAuto&&plotIntensity)
               ylim([PF2.view.LightMin,PF2.view.LightMax]); 
            end


            if(~isempty(plotIdx))
               yl=ylim;

               if(max(yl)>0.95*setF.device.Info.RawMax)
                   plot(PF2.data.time(timeInd),PF2.data.time(timeInd)*0+setF.device.Info.RawMax,'--r','linewidth',2);
               end
            end

            xl=[PF2.view.startTime,PF2.view.endTime]; plotMarkers(xl);
            hold off;

            if(setF.device.Info.TimeIsSampleCount)
                xlabel('Time (samples)');
            else
                xlabel('Time (s)');
            end

            title(sprintf('P%i: Opt%i',prb,optIdx));

            %*%xlim([PF2.view.startTime,PF2.view.endTime])
            if(plotIntensity)
                ylabel('Intensity (I_in)');
            else
                ylabel('\Delta OD');
            end
                
        end
    end 
end

% --- Executes on button press in checkbox_baseline_relative_to_view.
function checkbox_baseline_relative_to_view_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_baseline_relative_to_view (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_baseline_relative_to_view
global PF2
PF2.GUIPF2.baseline.relative2View=get(hObject,'Value');
processFNIR_GUI();
updatePlots(handles);

function edit_baseline_start_time_Callback(hObject, eventdata, handles)
% hObject    handle to edit_baseline_start_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_baseline_start_time as text
%        str2double(get(hObject,'String')) returns contents of edit_baseline_start_time as a double
global PF2

PF2.baseline.startTime=str2double(get(hObject,'String'));

if(isempty(PF2.baseline.startTime)||PF2.baseline.startTime<0||PF2.baseline.startTime>max(PF2.data.time))
    set(hObject,'String','0');
    edit_baseline_start_time_Callback(hObject, eventdata, handles);
else
    set(hObject,'String',sprintf('%.2f',PF2.baseline.startTime));
end

processFNIR_GUI()
updatePlots(handles);

% --- Executes during object creation, after setting all properties.
function edit_baseline_start_time_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_baseline_start_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_baseline_length_Callback(hObject, eventdata, handles)
% hObject    handle to edit_baseline_length (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_baseline_length as text
%        str2double(get(hObject,'String')) returns contents of edit_baseline_length as a double
global PF2
global outputData;

PF2.GUIPF2.baseline.blLength=str2double(get(hObject,'String'));

if(PF2.GUIPF2.baseline.blLength==0)
    outputData.DirtyBaseline=true;
    set(handles.checkbox_baseline_global,'Value',1);
elseif(PF2.GUIPF2.baseline.blLength<0||isempty(PF2.GUIPF2.baseline.blLength)||isnan(PF2.GUIPF2.baseline.blLength))
    set(hObject,'String','10');
    edit_baseline_length_Callback(hObject, eventdata, handles);
    set(handles.checkbox_baseline_global,'Value',0);
    return;
else
    outputData.DirtyBaseline=false;
    set(hObject,'String',sprintf('%2.f',PF2.GUIPF2.baseline.blLength));
    set(handles.checkbox_baseline_global,'Value',0);
end

processFNIR_GUI();
updatePlots(handles);


% --- Executes during object creation, after setting all properties.
function edit_baseline_length_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_baseline_length (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_markers.
function listbox_markers_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_markers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_markers contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_markers

global PF2

if(isfield(PF2,'curMarkerSet')&&~isempty(PF2.curMarkerSet))
    curMarkersInd=get(handles.listbox_markers,'Value');
    PF2.curMarkers=PF2.curMarkerSet(curMarkersInd);
    reducedMarkers=PF2.data.markers(ismember(PF2.data.markers(:,2),PF2.curMarkers),:);
    PF2.curMarkersPlot=reducedMarkers;

    if(~isempty(PF2.curMarkersPlot))
        strArr=cell(size(PF2.curMarkersPlot(:,2)));
        for i=1:length(strArr)
           strArr{i}=sprintf('%i (%.2f)',PF2.curMarkersPlot(i,2),PF2.curMarkersPlot(i,1));
        end
        set(handles.listbox_marker_nav,'String',strArr);
        set(handles.listbox_marker_nav,'Value',1);
    else
        set(handles.listbox_marker_nav,'String',{});
    end

    updatePlots(handles);
else
    set(handles.listbox_marker_nav,'String',{});
    set(handles.listbox_markers,'String',{});
end

function plotMarkers(xl,curAx)
if(nargin<2)
    curAx=gca;
end

global PF2
if(isfield(PF2,'curMarkersPlot')&&~isempty(PF2.curMarkersPlot))
    reducedMarkers=PF2.curMarkersPlot((PF2.curMarkersPlot(:,1)>=xl(1)&PF2.curMarkersPlot(:,1)<=xl(2)),:);
    if(~isempty(reducedMarkers))
        hhh=pf2_base.external.vline(curAx,reducedMarkers(:,1),'-k',{},'lineTags',cellstr(num2str(reducedMarkers(:,2))));
    end
end


% --- Executes during object creation, after setting all properties.
function listbox_markers_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_markers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_select_all_markers.
function pushbutton_select_all_markers_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_select_all_markers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
set(handles.listbox_markers,'Value',1:length(PF2.curMarkerSet));
listbox_markers_Callback(hObject, eventdata, handles);

% --- Executes on button press in pushbutton_clear_markers.
function pushbutton_clear_markers_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_clear_markers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.listbox_markers,'Value',[]);
listbox_markers_Callback(hObject, eventdata, handles);



% --- Executes on button press in checkbox_plot_OD.
function checkbox_plot_OD_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_plot_OD (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_plot_OD
global PF2

PF2.view.plotOD=get(handles.checkbox_plot_OD,'Value');
updatePlots(handles);


% --- Executes on selection change in listbox_marker_nav.
function listbox_marker_nav_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_marker_nav (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_marker_nav contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_marker_nav
global PF2

curNavIndex=get(handles.listbox_marker_nav,'Value');
if(iscell(curNavIndex))
    curNavIndex=curNavIndex{1};
end

if(isfield(PF2,'curMarkersPlot')&&~isempty(PF2.curMarkersPlot))
    mrkStartTime=PF2.curMarkersPlot(curNavIndex,1);
    set(handles.edit_startTime,'String',sprintf('%.2f',mrkStartTime-PF2.GUIPF2.baseline.blLength));
    PF2.view.startTime=str2double(get(handles.edit_startTime,'String'));
    %edit_startTime_Callback(hObject, eventdata, handles);
    set(handles.edit_endTime,'String',sprintf('%.2f',mrkStartTime+PF2.view.timeStepSize));
    edit_endTime_Callback(hObject, eventdata, handles);
end


% --- Executes during object creation, after setting all properties.
function listbox_marker_nav_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_marker_nav (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_marker_prev.
function pushbutton_marker_prev_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_marker_prev (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
if(~isempty(PF2.curMarkersPlot))
    minVal=1;

    curNavIndex=get(handles.listbox_marker_nav,'Value');
    if(iscell(curNavIndex))
        curNavIndex=curNavIndex{1};
    end
    set(handles.listbox_marker_nav,'Value',max(minVal,curNavIndex-1));
    listbox_marker_nav_Callback(hObject, eventdata, handles);
end

% --- Executes on button press in pushbutton_marker_next.
function pushbutton_marker_next_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_marker_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
if(~isempty(PF2.curMarkersPlot))
    maxVal=length(PF2.curMarkersPlot(:,1));

    curNavIndex=get(handles.listbox_marker_nav,'Value');
    if(iscell(curNavIndex))
        curNavIndex=curNavIndex{1};
    end
    set(handles.listbox_marker_nav,'Value',min(maxVal,curNavIndex+1));
    listbox_marker_nav_Callback(hObject, eventdata, handles);
end
% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over pushbutton_marker_next.
function pushbutton_marker_next_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton_marker_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global outputData
if(isfield(outputData,'ShowGUI'))
    if(outputData.ShowGUI)
        clearVarsOnClose();
    end
end


% --- Executes on button press in pushbutton_arranged_raw_pre.
function pushbutton_arranged_raw_pre_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_arranged_raw_pre (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


plotRawArranged(handles,true);

% --- Executes on button press in pushbutton_arranged_oxy_pre.
function pushbutton_arranged_oxy_pre_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_arranged_oxy_pre (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


plotOxyArranged(handles,true);


% --- Executes on button press in pushbutton_arranged_raw_intensity.
function pushbutton_arranged_raw_intensity_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_arranged_raw_intensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
plotRawArranged(handles,false,true);


% --- Executes on button press in checkbox_baseline_global.
function checkbox_baseline_global_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_baseline_global (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_baseline_global
global PF2
global outputData;

bGlobalCheck=get(hObject,'Value');
if(bGlobalCheck)
    PF2.GUIPF2.baseline.blLength=0;
else
    PF2.GUIPF2.baseline.blLength=10; 
end
set(handles.edit_baseline_length,'String',sprintf('%2.f',PF2.GUIPF2.baseline.blLength));
edit_baseline_length_Callback(handles.edit_baseline_length,[],handles);


% --- Executes on button press in pushbutton_customCallback.
function pushbutton_customCallback_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_customCallback (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
data=PF2.data.stage{5};
if(isfield(PF2.data,'markers'))
    data.markers=PF2.data.markers;
end
if(exist('PF2Analyze')==2)
    if(isempty(PF2.PF2Analyze))
        PF2.PF2Analyze{1}=cell(1);
    end
    runPF2Analyze(PF2.PF2Analyze{1});
else
    waitfor(errordlg(sprintf('PF2Analyze(oxyFNIR,handles) does not currently exist\nPlease define your own function which accepts these argument and returns any handles which you wish to be reused when updating\nThis function can be used to post-process your data to assess spatial variation and functional connectivity or correlations with other data')));
end


% --- Executes on button press in checkbox_view_processWindowOnly.
function checkbox_view_processWindowOnly_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_view_processWindowOnly (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
PF2.view.processWindowOnly=get(hObject,'Value');
processFNIR_GUI();
updatePlots(handles);

% Hint: get(hObject,'Value') returns toggle state of checkbox_view_processWindowOnly


% --- Executes on mouse press over axes background.
function axes_timeline_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to axes_timeline (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



  
function txt = myupdatefcn(pointDataTip, event_obj)
 global dataTipSelectionHandleTag
 global cursorTimelineMode

 hAxes=get(pointDataTip,'Parent');
 pos = event_obj.Position;
 selectedObjectTag=event_obj.Target.Tag;
 
 if(strcmp(hAxes.Tag,'Timeline'))
     global PF2
     handles=PF2.GUIPF2.handles;
     
     
     if(strcmp(cursorTimelineMode,'start'))
         if(pos(1)~= PF2.view.startTime)
            dataTipSelectionHandleTag=selectedObjectTag;
            if(pos(1)>PF2.view.endTime||contains(dataTipSelectionHandleTag,'End'))
                cursorTimelineMode='end';
            else
                PF2.view.startTime=pos(1);
                set(handles.edit_startTime,'String',sprintf('%.2f',PF2.view.startTime));
                if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
                    processFNIR_GUI();
                end
                updatePlots(handles);
                dataTipSelectionHandleTag=[];
            end
            
         end
     elseif(strcmp(cursorTimelineMode,'end'))
         if(pos(1)~= PF2.view.endTime)
            dataTipSelectionHandleTag=selectedObjectTag;
            if(pos(1)<PF2.view.startTime||contains(dataTipSelectionHandleTag,'Start'))
                cursorTimelineMode='start';
            else
                PF2.view.endTime=pos(1);
                set(handles.edit_endTime,'String',sprintf('%.2f',PF2.view.endTime));
                if(PF2.GUIPF2.baseline.relative2View||PF2.view.processWindowOnly)
                    processFNIR_GUI();
                end
                updatePlots(handles);
                dataTipSelectionHandleTag=[];
            end
            
          end
     end
     txt={};
 elseif(contains(hAxes.Tag,'Stage'))
     if(~isempty(selectedObjectTag))
         txt={sprintf('%s\nt=%.2f, y=%.2f',selectedObjectTag,pos(1),pos(2))};
     else
         txt = {sprintf('t=%.2f, y=%.2f',pos(1),pos(2))};
     end
    %disp(['You clicked X:',num2str(pos(1)),', Y:',num2str(pos(2))]);
    
 else
     
     txt={''};
 end
 
for i=1:length(txt)
   txtprt=txt{i};
   txtprt(txtprt=='_')=' ';
   txt{i}=txtprt;
end
  
 


% --- Executes on selection change in popupmenu_dpf_mode.
function popupmenu_dpf_mode_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_dpf_mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_dpf_mode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_dpf_mode
global PF2

curSelectedValue=get(handles.popupmenu_dpf_mode,'Value');

switch(curSelectedValue)
    case 1
        PF2.GUIPF2.dpf_mode='None';
        set(handles.edit_DPF_fixed,'Enable','off');
        set(handles.edit_DPF_age,'Enable','off');
    case 2
        PF2.GUIPF2.dpf_mode='Fixed';
        set(handles.edit_DPF_fixed,'Enable','on');
        set(handles.edit_DPF_age,'Enable','off');
    case 3
        PF2.GUIPF2.dpf_mode='Calc';
        set(handles.edit_DPF_fixed,'Enable','off');
        set(handles.edit_DPF_age,'Enable','on');
    otherwise
        PF2.GUIPF2.dpf_mode='None';
end

processFNIR_GUI();
updatePlots(handles);


% --- Executes during object creation, after setting all properties.
function popupmenu_dpf_mode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_dpf_mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_DPF_fixed_Callback(hObject, eventdata, handles)
% hObject    handle to edit_DPF_fixed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_DPF_fixed as text
%        str2double(get(hObject,'String')) returns contents of edit_DPF_fixed as a double
global PF2

newDPFfixed=str2double(get(handles.edit_DPF_fixed,'String'));
if(newDPFfixed>10)
    newDPFfixed=10;
elseif(newDPFfixed<1)
    newDPFfixed=1;
end
set(handles.edit_DPF_fixed,'String',num2str(newDPFfixed,'%.2f'));


PF2.GUIPF2.curDPF_fixed=newDPFfixed;

processFNIR_GUI();
updatePlots(handles);


% --- Executes during object creation, after setting all properties.
function edit_DPF_fixed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_DPF_fixed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
