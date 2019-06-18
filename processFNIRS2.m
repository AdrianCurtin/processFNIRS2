function varargout = processFNIRS2(varargin)
% PROCESSFNIR2 MATLAB code for faster non-GUI pipeline
%      2nd generation preprocessing pipleline for fNIRS datasets
%      Uses device configuration files to allow for more repeatable and 
%      more flexible situations
%
%      Always takes a simple array containing the light intensity data and 
%      will optionally load a specific parameters using the varargin option
%      Specifiying an output will hide the GUI unless 'ShowGUI',true is
%      passed as an argument


% To Do: Add 'add function' to configureMethods   
%        Add support for short separation detectors
%       Test with Hitachi data
%       Add support for multiprobe
%       Add suppport for channel rejection
%       Add support for mean addition (but more flexibly)

% Change Log
% 3/8/2019 - Bug fix for viewing window in PF2GUI
% 2/4/2019 - Renamed .Total to .TotalHb
% 1/23/2019 - Process: Added support for DPFmode 'None', similar to Hitachi systems. 
%						Note: units for this field are in mM*mm instead of uM and the quantity is not multiplied by the SD separation distance or a DPF factor
% 1/22/2019 - Process: Changed default behavior for DPF to use Scholtz 2013 age/wavelength dependent calculations instead of 5.93
%						Added 'DPFmode' parameter to change this behavior.
%						Removed support for manufacturer chromophore absorbance, now uses interpolated values from published absorbance
%				GUI:  Added ability to switch between DPF techniques (fixed, and calculated)
% 1/12/2019 - GUI: Added field to show subject/trial information beflow device info (info struct in fNIRS)
% 1/11/2019 - Process: Added support for dark channel/Sourcedetector distance,time, auxillary, dark inputs as optional parameters in method functions
%			  GUI: Added support for information tags to show plot info 
%				ConfigureMethods: Added support for adding and editing functions to available function lists
% 1/10/2019 - GUI: Added support for PF2_Analyze() a custom function that receives the FNIRS struct for processing (resting state or other custom functionality)
% 1/9/2019 - ConfigureMethods: Added function to clean names for storage automatically
% 1/8/2019 - GUI: Added Pre-Post processed options for topographic plots
% 1/7/2019 - Process: Added support for import methods via argument callback
%					GUI:support for channel masking/rejection visualization
% 1/6/2019 - Process: Split GUI from non-gui processFNIRS2 for performance reasons (takes GUI 1 second to load per call)
% 1/5/2019 - Process: Split raw processing and added OD conversion as non-optional part of Raw stage
%					Process: added multiple commandline argument inputs (varargin) to set and change configurations
%					GUI: Added marker visualization support, added option to plot OD
% 1/4/2019 - Process: Changed implementation so channel processing is parralellized
%					Implemented Oxy Processing functionality
%					GUI:Added linked topographic plots (arrangment stored in device cfg files)
%					GUI:Added Relative2View Baselining (baselines at start of viewing window for visualization)
%			ConfigureMethods: Added function descriptions
% 1/3/2019 - ConfigureMethods: Modified method storage (pack/unpack methods)
% 6/28/2019 - Initial Version: Support for select functions, raw processing visualization at multiple stages, selection of viewing window, biomarkers and channels


global PF2
global setF
%global outputData

%
%Load default parameters here
hObject=1;
handles=1;



if(~isfield(PF2,'defaultRootPath'))
    [pF2_folder,~,~] = fileparts(mfilename('fullpath'));
    PF2.defaultRootPath=pF2_folder;
    curdir=cd;
    cd(PF2.defaultRootPath);
    addpath('base_functions','functions','GUI');
    cd(curdir);
end


PF2.defaultOxyMethodsPath=sprintf('%s/pf2_oxy_methods_stored_processFNIRS2.cfg',prefdir);
PF2.defaultRawMethodsPath=sprintf('%s/pf2_raw_methods_stored_processFNIRS2.cfg',prefdir);
if(~isfield(PF2,'myRawMethods')||~isfield(PF2,'baseline'))
   disp('Initializing processfNIRS2');
   PF2.myRawMethods=processFNIRS2_configureMethods('loadMethodsCallback',hObject,handles,[],PF2.defaultRawMethodsPath,true);
   for i=1:length(PF2.myRawMethods.cfg.Sections)
      fprintf('Loaded Raw method: %s\n',PF2.myRawMethods.cfg.Sections{i}); 
   end
   PF2.myOxyMethods=processFNIRS2_configureMethods('loadMethodsCallback',hObject,handles,[],PF2.defaultOxyMethodsPath,true);
   for i=1:length(PF2.myOxyMethods.cfg.Sections)
      fprintf('Loaded Oxy method: %s\n',PF2.myOxyMethods.cfg.Sections{i}); 
   end
   PF2.curDPF_fixed=5.93;   %Default differential pathlength for adult human head (van der Zee 1992)
   PF2.dpf_mode='Calc';   %Default age to calculate differential pathlength factor from.
   PF2.curDPF_age=25;   %Default age to calculate differential pathlength factor from.
   fprintf('Initializing default age for DPF calculation to %.0f\n',PF2.curDPF_age);
   PF2.baseline=[];
   PF2.baseline.startTime=0; %or minimum time
   
   PF2.baseline.useAbsoluteTime=false; %enable to force baseline from absolute time instead of relative time (non-GUI only)
   PF2.baseline.windowStartTime=0; % time from start of viewing window (GUI only)
   PF2.baseline.blLength=10; % time in seconds from start time
   fprintf('Defaulting to %.1f second baseline from t=%.1f\n',PF2.baseline.blLength,PF2.baseline.startTime);
   %processFNIRS2_configureMethods() 
end
%
% Parse inputs here

if(pf2_base.isnestedfield(PF2,'stageRawMethod.name')&&sum(strcmp(PF2.myRawMethods.cfg.Sections,PF2.stageRawMethod.name))==1)
    defaultRawMethod=PF2.stageRawMethod.name;
else
    defaultRawMethod='None';
end
if(pf2_base.isnestedfield(PF2,'stageOxyMethod.name')&&sum(strcmp(PF2.myOxyMethods.cfg.Sections,PF2.stageOxyMethod.name))==1)
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
validDPFmode = @(x) ischar(validatestring(x,{'None','Fixed','Calc'})); % None uses no DPF factor (units mm*mMol), fixed uses one DPF for all wavelenghts,Calc attempts tocalculate wavelength*age dependent changes

addOptional(p,'data',[],validDataInput);
addOptional(p,'Raw_Method',defaultRawMethod,validRawMethod); %Attempt to load specified RawMethod
addOptional(p,'Oxy_Method',defaultOxyMethod,validOxyMethod); %Attempt to load specified OxyMethod
addOptional(p,'blLength',PF2.baseline.blLength,validScalarPosNum); %specify realtive baseline relative to blStartTime (in seconds)
addOptional(p,'blStartTime',PF2.baseline.startTime,validScalarNum); %Specify relative baseline start time (in seconds)
addParameter(p,'defaultSubjectAge',PF2.curDPF_age,validScalarPosNum); %Use custom default age for DPF calculations rather than whatever was in the GUI
addParameter(p,'UseDeviceCFG','',@ischar); %Input for file containing device configuration info
addParameter(p,'markers',[],@ismatrix); %specify where markers go
addParameter(p,'OutputLegacyMarkers',false,@islogical); % turn on to output marker array into .markers.data instead of just .markers

addParameter(p,'SkipOxy',false,@islogical); %specifies whether to stop processing of data at Oxy
addParameter(p,'SkipOD',false,@islogical); %specifies whether to stop processinf of data before OD conversion
addParameter(p,'SkipRaw',false,@islogical); %specifies whether to skip the raw data and only process oxy data
addParameter(p,'ProcessRejectedChannels',false,@islogical); %specifies whether to attempt to process rejected channels, if false channels are returned as NA

addParameter(p,'ChannelMask',[],@ismatrix); %logical matrix the size of channel array which determines if channel has been rejected, later stored in fChMask
addParameter(p,'ShowGUI',false,@islogical); % turn true to launch GUI
addParameter(p,'DirtyBaseline',false,@islogical); % turn to use the entire mean as the baseline period
addParameter(p,'FixedDPF',PF2.curDPF_fixed,validScalarPosNum); %set default uniwavelength DPF
addParameter(p,'DPFmode',PF2.dpf_mode,validDPFmode); %set role of DPF in mBLL calculations


addParameter(p,'ImportOxyMethods','NA',@ischar);  %Path for Oxy methods cfg file to import
addParameter(p,'ImportRawMethods','NA',@ischar);  %Path for Raw methods cfg file to import

parse(p,varargin{:});

outputData.ProcessOxy=~p.Results.SkipOxy;
outputData.ProcessRaw=~p.Results.SkipRaw;
outputData.OutputRaw=p.Results.SkipOD;
outputData.ProcessRejected=p.Results.ProcessRejectedChannels;
PF2.OutputLegacyMarkers=p.Results.OutputLegacyMarkers;


data=p.Results.data;

if(~isempty(p.Results.UseDeviceCFG)) % if command argument given
    cfgFilePath=p.Results.UseDeviceCFG; % command argument to load cfg file
elseif(pf2_base.isnestedfield(data,'info.probename')&&~contains(data.info.probename,'Unkown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',data.info.probename);
else
    cfgFilePath='';
end

ShowGUI=p.Results.ShowGUI||isempty(varargin)||(nargout==0&&~isempty(data));

if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))&&(~ShowGUI&&~isempty(data)) %if nothing, invalid, or no data
    
    warning('Missing or invalid configuration file path\n')
    
    disp('No device specified. Please load device configuration');
    loadDeviceCfg();
    if(~isfield(setF,'device'))
        error('No valid devices selected');
    end
    
elseif(~isempty(cfgFilePath)) 
    
    if(pf2_base.isnestedfield(setF,'device.cfg.Info.CfgName')) % look to see if they match,...
            
        curProbeName=sprintf('%s.cfg',setF.device.cfg.Info.CfgName);
        
        if(~strcmp(curProbeName,cfgFilePath)) %if they do don't bother loading
            loadDeviceCfg(cfgFilePath);
        end
    else
        loadDeviceCfg(cfgFilePath);
    end
end


if(ShowGUI)
    if(any(strcmp(p.UsingDefaults,'ShowGUI')))
       l=length(varargin);
       if(l==0)
           processFNIRS2.GUI();
           return;
       elseif(~isempty(data))
           varargin(l+1)={'ShowGUI'};
           varargin(l+2)={true};
       end
    end
    varargout{1}=processFNIRS2_GUI(varargin{:});
    return
end

PF2.baseline.startTime=p.Results.blStartTime;
PF2.baseline.blLength=p.Results.blLength;

outputData.DirtyBaseline=p.Results.DirtyBaseline||PF2.baseline.blLength==0;


PF2.curDPF_fixed=p.Results.FixedDPF;
PF2.curDPF_age=p.Results.defaultSubjectAge;
PF2.dpf_mode=p.Results.DPFmode;

rawMethodStr=p.Results.Raw_Method;
oxyMethodStr=p.Results.Oxy_Method;

if(pf2_base.isnestedfield(PF2,sprintf('myRawMethods.cfg.%s',rawMethodStr)))
    if(pf2_base.isnestedfield(PF2,'stageRawMethod.name')&&~strcmpi(PF2.stageRawMethod.name,rawMethodStr))
       fprintf('Setting Raw Method to: %s\n',rawMethodStr); 
    end
    
    PF2.stageRawMethod=pf2_base.pf2_unpackMethod(PF2.myRawMethods.cfg.(rawMethodStr));
    PF2.stageRawMethod.name=rawMethodStr;
else
    error('Unable to find method named: %s',oxyMethodStr);
end


if(pf2_base.isnestedfield(PF2,sprintf('myOxyMethods.cfg.%s',oxyMethodStr)))
    if(pf2_base.isnestedfield(PF2,'stageOxyMethod.name')&&~strcmpi(PF2.stageOxyMethod.name,oxyMethodStr))
       fprintf('Setting Oxy Method to: %s\n',oxyMethodStr); 
    end
    
    PF2.stageOxyMethod=pf2_base.pf2_unpackMethod(PF2.myOxyMethods.cfg.(oxyMethodStr));
    PF2.stageOxyMethod.name=oxyMethodStr;
else
    error('Unable to find method named: %s',oxyMethodStr);
end


cfgRawImportPath=p.Results.ImportRawMethods;
cfgOxyImportPath=p.Results.ImportOxyMethods;

if(~strcmp(cfgRawImportPath,'NA'))
    processFNIRS2_configureMethods('importMethodsCallback',hObject,[],handles,cfgRawImportPath,true);
end

if(~strcmp(cfgOxyImportPath,'NA'))
    processFNIRS2_configureMethods('importMethodsCallback',hObject,[],handles,cfgOxyImportPath,false);
end

if(isempty(data)||(isstruct(data)&&isfield(data,'info')&&~isfield(data,'raw')&&~isfield(data,'HbO')))
    disp('No data loaded, initializing settings only');
    if(~isempty(data))
       varargout{1}=data; 
    end
    return;
end

for i=1:5
   fData.stage{i}=[];
end

tempOxyStage=[];

if(ismatrix(data)&&~isstruct(data))
   x=data;
   data=[];
   data.raw=x;
end
   
if(isstruct(data)) %treat as fNIR struct
    if(isfield(data,'raw'))
        fData.stage{1}=data.raw;
    end
    if(isfield(data,'MES'))
        fData.stage{1}=data.raw;
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
        tempOxyStage.HbTotal=data.total;
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
        fData.fchMask=data.fchMask;
    end
    
    if(isfield(data,'time'))
        fData.time=data.time;
    end
    
    if(isfield(data,'markers'))
        if(isnumeric(data.markers))
            fData.markers=data.markers;
        elseif(isfield(data.markers,'data'))
            fData.markers=data.markers.data;
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
    else
       fData.markers=[]; 
    end
    
    if(isfield(data,'info'))
        fData.info=data.info;
    else
        fData.info=[]; 
    end
    
    if(~isfield(fData.info,'SubjectID'))
        fData.info.SubjectID='';
    end
    if(~isfield(fData.info,'Group'))
        fData.info.Group='';
    end
    if(~isfield(fData.info,'Subgroup'))
        fData.info.Subgroup='';
    end
    if(~isfield(fData.info,'Session'))
        fData.info.Session='';
    end
    if(~isfield(fData.info,'Trial'))
        fData.info.Trial='';
    end
    if(~isfield(fData.info,'Block'))
        fData.info.Block='';
    end
    if(~isfield(fData.info,'Condition'))
        fData.info.Condition='';
    end
    if(~isfield(fData.info,'Age'))
        fData.info.Age=[];
    end
    if(~isfield(fData.info,'Sex'))
        fData.info.Sex='';
    end
    
    if(pf2_base.isnestedfield(data,'ROI.info'))
        fData.ROI=data.ROI;
    end
    
    if(isfield(data,'channels'))
        fData.channels=data.channels;
    end
    
    if(isfield(data,'Aux'))
        fData.Aux=data.Aux;
    else
        fData.Aux=[];
    end
    
    if(isfield(data,'takizawa'))
        fData.takizawa=data.takizawa;
    end
end

if(isempty(fData.info.Age))
    warning('fData.info.Age is empty\nDPF calculations will be performed using an age of %i years old\nPlease assign subject age for accurate chromophore calculations',PF2.curDPF_age);
end

if(~isempty(p.Results.markers))
    fData.markers=p.Results.markers; %Overwrite markers if specified
end

if(isstruct(tempOxyStage))
    fData.stage{4}=tempOxyStage; %Assign stage3 if exists
end




fData=updateCurrentDevice(fData);

[numDataRows,numDataCols]=size(fData.stage{1});
numDevCols=length(setF.device.Probe{1}.ChannelNumbers);
while(numDataCols~=numDevCols)
    if(numDataCols==numDataRows)
       fData.stage{1}=fData.stage{1}';
       break;
    else
       fprintf('Data size %i x %i: Expected %i columns in loaded device',numDevCols);
       warning('Channel/Device mismatch, please load new configuration file');
       loadDeviceCfg();
    end
    [numDataRows,numDataCols]=size(fData.stage{1});
    numDevCols=length(setF.device.Probe{1}.ChannelNumbers);  

end



varargout={};

if(~isempty(data))
    if(~isfield(fData,'fchMask')||(isfield(fData,'fchMask')&&isempty(fData.fchMask)))
        fData.fchMask=true(1,length(setF.device.Probe{1}.ChannelList));
    end
    numChannels=length(setF.device.Probe{1}.ChannelList);
    rawMask=ismember(setF.device.Probe{1}.ChannelNumbers,setF.device.Probe{1}.ChannelList(reshape(fData.fchMask|outputData.ProcessRejected,1,numChannels)));

   %varargout=processFNIRdata(); 
   
   
    fAux=fData.Aux;
    fMarkers=fData.markers;
   
   if(outputData.ProcessRaw)
        
        [fData.stage{3},fData.stage{2}]=processStageRaw2OD(fData.stage{1},fData.fs,fData.time,rawMask,fMarkers,fAux); % Raw data processing
        if(outputData.ProcessOxy)
            fData.stage{4}=processStageOD2Hb(fData.stage{3},fData.time,fData.info.Age,outputData.DirtyBaseline); % Beer-Lambert conversion
        end
        if(pf2_base.isnestedfield(fData,'ROI.info'))
            fData.stage{4}.ROI.info=fData.ROI.info; %Regenerate from info
        end
    else
        %fData.stage{2}=fData.stage{1};
        if(~isempty(fData.stage{4})&&~isfield(fData.stage{4},'channels'))
           fData.stage{4}.channels=setF.device.Probe{1}.ChannelList;
           warning('No channel information given, assuming all columns indexs correspond with channel numbers');
        end
        if(pf2_base.isnestedfield(fData,'ROI.info'))
            fData.stage{4}.ROI=fData.ROI; % Use All ROI information provided
        end
    end
    if(outputData.ProcessOxy)
        fData.stage{4}.fchMask=fData.fchMask;
        fData.stage{4}.Aux=fData.Aux;
        fData.stage{4}.markers=fData.markers;
        fData.stage{4}.time=fData.time;
        
        fData.stage{5}=processStageFilterHb(fData.stage{4},fData.fs,outputData.ProcessRejected); % Oxy data processing
    else
        %fData.stage{5}=fData.stage{4};
    end

end

if(nargout>0)
   if(isfield(fData,'stage')&&(size(fData.stage,2)==5))
       if(outputData.ProcessOxy&&~isempty(fData.stage{5}))
          outfNIR=fData.stage{5};
          if(~isempty(fData.stage{1}))
            outfNIR.raw=fData.stage{1};
          end
       elseif(outputData.ProcessRaw&&~outputData.OutputRaw)
          if(~isempty(fData.stage{3}))
              outfNIR.OD=fData.stage{3}; %start with OD
          end
          if(~isempty(fData.stage{1}))
            outfNIR.raw=fData.stage{1};
          end
       elseif(outputData.ProcessRaw)
           if(~isempty(fData.stage{2}))
            outfNIR.rawProcessed=fData.stage{2}; 
           end
          if(~isempty(fData.stage{1}))
            outfNIR.raw=fData.stage{1};
          end
       end
       
       if(isfield(fData,'time'))
           outfNIR.time=fData.time;
       end
       
      if(isfield(fData,'markers')&&~isempty(fData.markers))
           if(PF2.OutputLegacyMarkers)
               outfNIR.markers=[];
               outfNIR.markers.data=fData.markers;
           else
               outfNIR.markers=fData.markers;
           end
       end
       
       if(isfield(fData,'info'))
           outfNIR.info=fData.info;
       end
       
       if(exist('outfNIR')&&isfield(fData,'channels'))
            outfNIR.channels=fData.channels;
        end
       
       if(exist('outfNIR')&&isfield(fData,'fchMask'))
           outfNIR.fchMask=fData.fchMask;
       end
       
       if(isfield(fData,'Aux')&&~isempty(fData.Aux))
           outfNIR.Aux=fData.Aux;
       end
       
       if(isfield(fData,'takizawa'))
           outfNIR.takizawa=fData.takizawa;
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

clearVarsOnClose();

end


function [outDataOD,outDataRaw]=processStageRaw2OD(data,fs,time,rawMask,fMarkers,fAux)
 % Raw data processing

global PF2

outData=data;
OD_converted=false;

validChannels=(PF2.curWvSet>0)&rawMask;  %Dark Channel should be 0, time should be NA, other information should be negative values

if(~isfield(PF2,'stageRawMethod'))
    disp('No current Filters enabled');
    %outData(:,validChannels)=medfilt1(data(:,validChannels),10);
else
    for i=1:length(PF2.stageRawMethod.F)
        Fidx=PF2.stageRawMethod.F{i};
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
                  passedArgVals{x_ind}=data(:,validChannels);
               elseif strcmp(args{a},'fs')==1
                  fs_ind=a; 
                  passedArgVals{fs_ind}=fs;
               elseif strcmp(args{a},'fTime')==1
                  time_ind=a; 
                  passedArgVals{time_ind}=time;
               elseif strcmp(args{a},'fchMask')==1
                  fmask_ind=a;
                  passedArgVals{fmask_ind}=rawMask;
               elseif strcmp(args{a},'fChannelNumbers')==1
                  fchInfo_ind=a;
                  passedArgVals{fchInfo_ind}=PF2.curChSet(validChannels);
               elseif strcmp(args{a},'fChannelSD')==1
                  fsd_ind=a;
                  passedArgVals{fsd_ind}=PF2.curSDSet(ismember(PF2.curChList,PF2.curChSet(validChannels)));
               elseif strcmp(args{a},'fMarkers')==1
                  fmrk_ind=a; 
                  passedArgVals{fmrk_ind}=fMarkers;
               elseif strcmp(args{a},'fAux')==1
                  fAux_ind=a;
                  passedArgVals{fAux_ind}=fAux;
               end
            end
            
            if(~isempty(x_ind))
                outData=data;
                
                %for ch=1:size(data,2)
                outData(:,validChannels)=func(passedArgVals{:});
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
    validChannels=((PF2.curWvSet>=0)&rawMask); %convert all and Dark channels
    outDataOD(:,validChannels)=pf2_Intensity2OD(outData(:,validChannels));
else
    validDarkChannels=((PF2.curWvSet==0)&rawMask); %convert just dark channels
    outDataOD=outData; 
    outDataOD(:,validDarkChannels)=pf2_Intensity2OD(outData(:,validDarkChannels));
end

outDataRaw(:,((PF2.curWvSet>=0)&~rawMask))=nan;
outDataOD(:,((PF2.curWvSet>=0)&~rawMask))=nan;


end

function outData=processStageOD2Hb(data,time,subjectAge,DirtyBaseline)
 % Beer-Lambert conversion

global setF
global PF2

if(strcmp(PF2.dpf_mode,'None'))
    NoPathlength=true;
else
    NoPathlength=false;
end

if(strcmp(PF2.dpf_mode,'Fixed'))
    fixedDPF=PF2.curDPF_fixed;
else
    fixedDPF=0;
end

if(isempty(subjectAge))
    subjectAge=PF2.curDPF_age;
end

if(DirtyBaseline) %use nanmean of entire segment asa baseline
    baselineSamples=1:length(time);
else
    startTime=min(time)+PF2.baseline.startTime;
    endTime=startTime+PF2.baseline.blLength;

    startSample=find(time>=startTime,1);
    endSample=find(time>=endTime,1);
    baselineSamples=startSample:endSample;
end


[outData.HbO, outData.HbR, outData.HbTotal, outData.HbDiff,outData.CBSI,outData.channels,~,outData.units,outData.DPF_factor]=...
    pf2_base.fnirs.bvoxy(data,setF.device.Probe{1}.ChannelNumbers,setF.device.Probe{1}.Wavelength,setF.device.Probe{1}.SD,baselineSamples,subjectAge,[],true,'NoPathlength',NoPathlength,'DiffPathlengthFactor',fixedDPF);

                                                          %BASELINE
                                                          %START/END
%[fNIR.oxy,fNIR.bv_805,fNIR.bv,fNIR.hbo,fNIR.hbr] = bvoxy (1,min(se,60),ss,se,fNIR.fin.raw_730,fNIR.fin.raw_805,fNIR.fin.raw_850);

%outData=data;
end


function outData=processStageFilterHb(data,fs,ProcessRejected)
% Oxy data processing

bioM_list={'HbO','HbR','HbTotal','HbDiff','CBSI'};
validChannels=false(size(data.channels));
numChannels=length(data.channels(data.channels>0));
validChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(data.fchMask|ProcessRejected,[1,numChannels]));

curfMask=data.fchMask|ProcessRejected;

if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(data.ROI))
    validChannels_roi=true(1,size(data.ROI.('HbO'),2));
end

global PF2
if(~isfield(PF2,'stageOxyMethod'))
    disp('No stage2 processing method left');
    outData=data;
    %outData.HbO(:,validChannels)=medfilt1(outData.HbO(:,validChannels),25);
    %outData.HbR(:,validChannels)=medfilt1(outData.HbR(:,validChannels),25);
else
    outData=data;
    for i=1:length(PF2.stageOxyMethod.F)
        Fidx=PF2.stageOxyMethod.F{i};
        if(isfield(Fidx,'f'))
            func=str2func(Fidx(1).f);
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
               for output_idx=1:length(outputList)
                   if strcmpi(outputList{output_idx},'x')==1 && isempty(x_out_ind)
                        x_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'fchMask')==1 && isempty(fmask_out_ind)
                       fmask_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'ROI')==1 && isempty(roi_out_ind)
                       roi_out_ind=output_idx;
                   end
               end
            else %legacy code missing output
                x_out_ind=1;
                roi_out_ind=[];
                fmask_out_ind=[];
            end
            
            for a=1:length(args)
               if strcmp(args{a},'x')==1
                  x_ind=a;
               elseif strcmp(args{a},'fs')==1
                  fs_ind=a; 
                  passedArgVals{fs_ind}=fs;
               elseif strcmp(args{a},'fTime')==1
                  time_ind=a; 
                  passedArgVals{time_ind}=data.time;
               elseif strcmp(args{a},'fchMask')==1
                  fmask_ind=a;
                  passedArgVals{fmask_ind}=data.fchMask;
               elseif strcmp(args{a},'fChannelNumbers')==1
                  fchInfo_ind=a;
                  passedArgVals{fchInfo_ind}=data.channels(validChannels);
               elseif strcmp(args{a},'fMarkers')==1
                  fmrk_ind=a; 
                  passedArgVals{fmrk_ind}=data.markers;
               elseif strcmp(args{a},'fAux')==1
                  fAux_ind=a;
                  passedArgVals{fAux_ind}=data.Aux;
               elseif strcmp(args{a},'fChannelSD')==1
                  fsd_ind=a;
                  passedArgVals{fsd_ind}=PF2.curSDSet(validChannels);
               elseif strcmp(args{a},'fNIRstruct')==1  % Try not to use, can be inefficient
                   fStruct_ind=a;
                   passedArgVals{fStruct_ind}=data;
               end
               
            end
            
            
            if(~isempty(x_ind)||~isempty(fStruct_ind))
                outData=data;
                %TODO move channel mask that doesn't process data outside
                %of loop 
                if(~isempty(fStruct_ind))
                    runOnce=true;
                else
                    runOnce=false;
                end
                for bioM=1:length(bioM_list) % go through each biomarker and process data
                    
                    if(~isempty(x_ind))
                        passedArgVals{x_ind}=data.(bioM_list{bioM})(:,validChannels);
                    end
                    
                    if(~isempty(fStruct_ind))
                        passedArgVals{fStruct_ind}=data;
                    end
                    
                    funcOutput{:}=func(passedArgVals{:});
                    
                    if(pf2_base.isnestedfield(data,'ROI.HbO')&&~isempty(x_ind))
                        % Note ROI functions may not be able to handle
                        % functions using channel numbers of SD separation
                        passedArgVals_roi=passedArgVals;
                        passedArgVals_roi{x_ind}=data.ROI.(bioM_list{bioM})(:,validChannels_roi);
                        funcOutput_roi{:}=func(passedArgVals_roi{:}); 
                    end
                    
                    if(~isempty(x_out_ind)) % Assign values to fNIRS Biomarkers and ROIs when available
                        outData.(bioM_list{bioM})(:,validChannels)=funcOutput{x_out_ind};
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            outData.ROI.(bioM_list{bioM})(:,validChannels_roi)=funcOutput_roi{x_out_ind};
                        end
                    end
                    
                    if(~isempty(fmask_out_ind)) % Or with current fmask
                        curfMask=curfMask&funcOutput{fmask_out_ind};
                        validChannels=validChannels&curfMask;
                        
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            validChannels_roi=validChannels_roi&funcOutput_roi{fmask_out_ind};
                        end
                    end
                    
                    if(~isempty(roi_out_ind)) % Build ROIs
                        outData=funcOutput{roi_out_ind};
                        if(isfield(outData,'ROI')&&~isempty(outData.ROI'))
                            validChannels_roi=true(1,size(outData.ROI.(bioM_list{bioM}),2));
                        end
                    end
                    
                    if(runOnce)
                        break;
                    end
                end
                
                data=outData;
            else
                %outData=data;
                warning('Unable to identify NIRS input argument\n');
            end
        end
    end
end


invalidChannels=false(size(data.channels));
invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask,[1,numChannels]));

for bioM=1:length(bioM_list) % go through each biomarker and set invalid cahnnels to nan
    outData.(bioM_list{bioM})(:,invalidChannels)=nan;
    
    if(pf2_base.isnestedfield(outData,'ROI.HbO'))
        outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
    end
end

end



% UIWAIT makes processFNIRS2 wait for user response (see UIRESUME)
% uiwait(handles.figure1);
function fData=updateCurrentDevice(fData)

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
    if(isempty(PF2.timeIndex))
        warning('Time column could not be found, assuming each row is a sample');
        PF2.timeIndex=0;
    end
else
    error('Not yet implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end

[~,i]=unique(PF2.curChSet);
PF2.curChList=PF2.curChSet(i);


if(PF2.mergedProbe) %All channel numbers are unique for merged probes  
    
    data=fData.stage{1};
    
    if(~isempty(data))
        if(isfield(fData,'time')&&~isempty(fData.time))
            fData.fs=1./median(diff(fData.time));
            fData.sampleTime=1:length(data(:,1));
        elseif(PF2.timeIndex==0)
            fData.sampleTime=1:length(data(:,1));
            fData.time=(fData.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            fData.fs=setF.device.Info.DefaultSamplingRate;
        elseif(setF.device.Info.TimeIsSampleCount==1)
            fData.sampleTime=data(:,PF2.timeIndex);
            fData.time=(fData.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            fData.fs=setF.device.Info.DefaultSamplingRate;
        else
            fData.sampleTime=1:length(data(:,1));
            fData.time=data(:,PF2.timeIndex);
            fData.fs=1./median(diff(fData.time));
        end
    elseif(isfield(data,'time')&&~isempty(fData.time))  %If time exists
        fData.sampleTime=1:length(fData.time);
        fData.fs=1./median(diff(fData.time));
    elseif(~isempty(fData.stage{4})) %try to calculate from oxy data
        data=fData.stage{4};
        if(isfield(fData,'time')&&~isempty(fData.time))
            fData.fs=1./median(diff(fData.time));
            fData.sampleTime=1:length(data(:,1));
        elseif(PF2.timeIndex==0)
            fData.sampleTime=1:length(data.HbO(:,1));
            fData.time=(fData.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            fData.fs=setF.device.Info.DefaultSamplingRate;
        elseif(setF.device.Info.TimeIsSampleCount==1)
            fData.sampleTime=data.HbO(:,PF2.timeIndex);
            fData.time=(fData.sampleTime-1)./setF.device.Info.DefaultSamplingRate;
            fData.fs=setF.device.Info.DefaultSamplingRate;
        else
            fData.sampleTime=1:length(data.HbO(:,1));
            fData.time=data.HbO(:,PF2.timeIndex);
            fData.fs=1./median(diff(fData.time));
        end
    end

else
   error('Not Yet Implemented for seperate probe data,\nAssumes concatenated datasets with unique channels in the config file'); 
end
end


function clearVarsOnClose()

global outputData
global PF2
global setF
fieldsToRemove={'data','curMarkersPlot','curMarkers','curNavMarkers','curNavMarkers','view'};

for i=1:length(fieldsToRemove)
   if(isfield(PF2,fieldsToRemove{i}))
       PF2=rmfield(PF2,fieldsToRemove{i});
   end
end

end




function loadDeviceCfg(deviceCfgFilename)
global setF

    [pF2_folder,name,ext] = fileparts(mfilename('fullpath'));


if(nargin>0) % If file name is specified, try to load it
    
    fid = fopen(deviceCfgFilename);
    
    [devCfg_folder,name,ext] = fileparts(deviceCfgFilename);
    
    if fid==-1 && isempty(devCfg_folder) % if the file wasn't immediately accessible...
                        %try loading from root/devices
        fid = fopen(sprintf('%s/devices/%s',pF2_folder,deviceCfgFilename));
        if(fid~=-1)
            deviceCfgFilename=sprintf('%s/devices/%s',pF2_folder,deviceCfgFilename);
        end
    end

    if fid==-1
        warning('Local Config File not found');
    
        if(isempty(devCfg_folder))
        
            [file, pathname] = uigetfile({'*.cfg';'*.*'},'Please Select Device Configuration file',sprintf('%s/devices/',pF2_folder));
        
        else
            [file, pathname] = uigetfile({'*.cfg';'*.*'},'Please Select Device Configuration file',devCfg_folder);
        end
        
        if(isempty(file)||(isnumeric(file)&&file==0))
            return;
        end
        
        fid = fopen([pathname file]);

        if fid==-1
            error('Data file not found or permission denied');
        end
    
        fclose(fid);

        setF.device.cfg = pf2_base.external.INI('File',[pathname file]);
    else
        fclose(fid);
        setF.device.cfg = pf2_base.external.INI('File',deviceCfgFilename);
    end
else %otherwise try to load the default
    [file, pathname] = uigetfile({'*.cfg';'*.*'},'Please Select Device Configuration file',sprintf('%s/devices',sprintf('%s/devices/',pF2_folder)));
    
    if(isempty(file)||(isnumeric(file)&&file==0))
        return;
    end
    fid = fopen([pathname file]);
    


    if fid==-1
      error('Data file not found or permission denied');
    end

    fclose(fid);

    setF.device.cfg = pf2_base.external.INI('File',[pathname file]);
end

setF.device.cfg.read();

setF.device.Info=setF.device.cfg.Info;

probeCount=0;
for j=1:length(setF.device.cfg.Sections)
	if(strfind(setF.device.cfg.Sections{j},'Probe'))
    	probeCount=probeCount+1;
        setF.device.Probe{probeCount}=get(setF.device.cfg,setF.device.cfg.Sections{j});
        tempChannels=unique(setF.device.Probe{probeCount}.ChannelNumbers);
        setF.device.Probe{probeCount}.ChannelList=tempChannels(tempChannels>0);
    end
end

end
