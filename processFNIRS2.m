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


pf2_base.pf2_initialize() % Loads methods, sets DPF factors, default age, baseline values
            %Also sets default root path

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
addParameter(p,'RejectLevel',PF2.RejectLevel,@(x) isnumeric(x)&&isscalar(x)&&x<1&&x>=0); %set the level at which a channel is rejected (fChMask)


addParameter(p,'ImportOxyMethods','NA',@ischar);  %Path for Oxy methods cfg file to import
addParameter(p,'ImportRawMethods','NA',@ischar);  %Path for Raw methods cfg file to import

parse(p,varargin{:});

outputData.ProcessOxy=~p.Results.SkipOxy;
outputData.ProcessRaw=~p.Results.SkipRaw;
outputData.OutputRaw=p.Results.SkipOD;
outputData.ProcessRejected=p.Results.ProcessRejectedChannels;
PF2.OutputLegacyMarkers=p.Results.OutputLegacyMarkers;


data=p.Results.data;

skipCFG=false;
if(~isempty(p.Results.UseDeviceCFG)) % if command argument given
    cfgFilePath=p.Results.UseDeviceCFG; % command argument to load cfg file
elseif(pf2_base.isnestedfield(data,'info.probename')&&~contains(data.info.probename,'Unkown')&&~contains(data.info.probename,'generated')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',data.info.probename);
elseif(pf2_base.isnestedfield(data,'info.probename')&&~contains(data.info.probename,'Unkown')&&contains(data.info.probename,'generated')) 
    cfgFilePath=sprintf('%s.cfg',data.info.probename);
    skipCFG=true;
else
    cfgFilePath='';
end

ShowGUI=p.Results.ShowGUI||isempty(varargin)||(nargout==0&&~isempty(data));

if(isfield(data,'probeinfo')&&~isempty(data.probeinfo))
    setF.device=data.probeinfo;
else

    if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))&&(~ShowGUI&&~isempty(data)) %if nothing, invalid, or no data

        warning('Missing or invalid configuration file path\n')

        disp('No device specified. Please load device configuration');
        pf2_base.loadDeviceCfg();
        if(~isfield(setF,'device'))
            error('No valid devices selected');
        end

    elseif(~isempty(cfgFilePath)) 

        if(pf2_base.isnestedfield(setF,'device.cfg.Info.CfgName')) % look to see if they match,...

            curProbeName=sprintf('%s.cfg',setF.device.cfg.Info.CfgName);

            if(~strcmp(curProbeName,cfgFilePath)&&~skipCFG) %if they do don't bother loading
                pf2_base.loadDeviceCfg(cfgFilePath);
            end
        else
            pf2_base.loadDeviceCfg(cfgFilePath);
        end
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
    processFNIRS2.Methods.Raw.ImportMethods(cfgRawImportPath);
end

if(~strcmp(cfgOxyImportPath,'NA'))
    processFNIRS2.Methods.Oxy.ImportMethods(cfgOxyImportPath);
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

[validBioFields,altSpellings]=pf2_base.pf2_getFNIRSbiomFields();
[validFields]=pf2_base.pf2_getFNIRSfields();
   
if(isstruct(data)) %treat as fNIR struct
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
    
    
    dataFields=fields(data);  % copy bio marker fields
    for i=1:length(dataFields)
        curField=dataFields{i};
       for j=1:length(validBioFields)
           memberIdx=ismember(altSpellings{j},curField);
           if(any(memberIdx))
                if(strcmpi(validBioFields{j},'raw'))
                    fData.stage{1}=data.(curField);
                else
                    tempOxyStage.(validBioFields{j})=data.(curField);
                end
                break;
           end
       end
    end
    
    for i=1:length(dataFields)  % copy other fields
       curField=dataFields{i};
       memberIdx=ismember(validFields,curField);
       if(any(memberIdx))
            if(strcmpi(validFields{memberIdx},'channels')||...
                    strcmpi(validFields{memberIdx},'units')||...
                    strcmpi(validFields{memberIdx},'DPF_factor'))
                tempOxyStage.(validFields{memberIdx})=data.(curField);
            else
                fData.(validFields{memberIdx})=data.(curField);
            end
       end
    end

    
    if(~isfield(fData,'markers'))
       fData.markers=[]; 
    end
    
    if(~isfield(fData,'info'))
        fData.info=[]; 
    end
    
    if(~isfield(fData,'Aux'))
        fData.Aux=[];
    end
    
    [defaultInfoFields,defaultValues]=pf2_base.pf2_getDefaultInfoFields();
    
    for i=1:length(defaultInfoFields)
        if(~isfield(fData.info,defaultInfoFields{i}))
            fData.info.(defaultInfoFields{i})=defaultValues{i};
        end
    end
    
    if(pf2_base.isnestedfield(data,'ROI.info'))
        fData.ROI=data.ROI;
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
       pf2_base.loadDeviceCfg();
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
    channelNumbers=setF.device.Probe{1}.ChannelNumbers;
    wavelengths=setF.device.Probe{1}.Wavelength;
    
    rawMask=ismember(channelNumbers,setF.device.Probe{1}.ChannelList(reshape(fData.fchMask>PF2.RejectLevel|outputData.ProcessRejected,1,numChannels)));

   %varargout=processFNIRdata(); 
   
   
    fAux=fData.Aux;
    fMarkers=fData.markers;
    

   if(outputData.ProcessRaw)
        
        [fData.stage{3},fData.stage{2}]=pf2_base.fnirs.processStageRaw2OD(PF2.stageRawMethod,fData.stage{1},fData.fs,fData.time,rawMask,fMarkers,fAux,channelNumbers,wavelengths); % Raw data processing
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
        fData.stage{4}.fchMask=fData.fchMask>PF2.RejectLevel;
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
       
       if(exist('outfNIR'))
           fdataFields=fields(fData);
           for i=1:length(fdataFields)
               memberIdx=ismember(validFields,fdataFields{i});
               if(any(memberIdx))
                    outfNIR.(validFields{memberIdx})=fData.(fdataFields{i});
               end
           end
           
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
outData.time=time;
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

if(isfield(data,'ftimeChMask'))
    curftimeMask=data.ftimeChMask|ProcessRejected;
else
    curftimeMask=ones(size(data.HbO));
end

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
            ftimeMask_ind=[];
            
            
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
               ftimeMask_out_ind=[];
               fstruct_out_ind=[];
               
               outputList=Fidx.output;
               
               if(iscell(outputList{1}))
                  outputList=outputList{1}; 
               end
               for output_idx=1:length(outputList)
                   if strcmpi(outputList{output_idx},'x')==1 && isempty(x_out_ind)
                        x_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'fchMask')==1 && isempty(fmask_out_ind)
                       fmask_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'ftimeChMask')==1 && isempty(ftimeMask_out_ind)
                       ftimeMask_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'fNIRstruct')==1 && isempty(fstruct_out_ind)
                       fstruct_out_ind=output_idx;
                   elseif strcmpi(outputList{output_idx},'ROI')==1 && isempty(roi_out_ind)
                       roi_out_ind=output_idx;
                   end
               end
            else %legacy code missing output
                x_out_ind=1;
                roi_out_ind=[];
                fmask_out_ind=[];
                ftimeMask_out_ind=[];
                fstruct_out_ind=[];
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
                  passedArgVals{fmask_ind}=curfMask;
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
               elseif strcmp(args{a},'ftimeChMask')==1
                  ftimeMask_ind=a;
                  passedArgVals{ftimeMask_ind}=curftimeMask; % always needs channel info when used in raw
               elseif strcmp(args{a},'fNIRstruct')==1  % Try not to use, can be inefficient
                   fStruct_ind=a;
                   passedArgVals{fStruct_ind}=data;
               end
               
            end
            
            
            if(~isempty(x_ind)||~isempty(fStruct_ind))
                outData=data;
                %TODO move channel mask that doesn't process data outside
                %of loop 
                if(~isempty(fStruct_ind)||~isempty(fstruct_out_ind))
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
                        if(size(funcOutput{fmask_out_ind},2)<size(curfMask,2))
                            curfMask(:,validChannels)=curfMask(:,validChannels)&funcOutput{fmask_out_ind};
                        else
                            curfMask=curfMask&funcOutput{fmask_out_ind};
                        end
                        
                        validChannels=validChannels&curfMask;
                        outData.(bioM_list{bioM})(:,~validChannels)=nan;
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            if(size(funcOutput_roi{fmask_out_ind},2)<size(validChannels_roi,2))
                                validChannels_roi(:,validChannels)=validChannels_roi(:,validChannels)&funcOutput{fmask_out_ind};
                            else
                                validChannels_roi=validChannels_roi&funcOutput_roi{fmask_out_ind};
                            end
                            outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
                        end
                    end
                    
                    if(~isempty(ftimeMask_out_ind)) % Or with current ftimemask
                        if(size(funcOutput{ftimeMask_out_ind},2)<size(validChannels,2))
                            curftimeMask(:,validChannels)=curftimeMask(:,validChannels)&funcOutput{ftimeMask_out_ind};
                        else
                            curftimeMask=curftimeMask&funcOutput{ftimeMask_out_ind};
                        end
                        if(pf2_base.isnestedfield(data,'ROI.HbO'))
                            if(size(funcOutput_roi{ftimeMask_out_ind},2)<size(validChannels_roi,2))
                                curftimeMask_roi(:,validChannels_roi)=curftimeMask_roi(:,validChannels_roi)&funcOutput_roi{ftimeMask_out_ind};
                            else
                                curftimeMask_roi=curftimeMask_roi&funcOutput_roi{ftimeMask_out_ind};
                            end
                        end
                    end
                    
                    if(~isempty(roi_out_ind)) % Build ROIs
                        outData=funcOutput{roi_out_ind};
                        if(isfield(outData,'ROI')&&~isempty(outData.ROI'))
                            validChannels_roi=true(1,size(outData.ROI.(bioM_list{bioM}),2));
                            curftimeMask_roi=true(size(outData.ROI.(bioM_list{bioM})));
                        end
                    end
                    
                    if(~isempty(fstruct_out_ind)) % Build ROIs
                        outData=funcOutput{fstruct_out_ind};
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

if(pf2_base.isnestedfield(outData,'ROI.info')&&~isempty(outData.ROI.info)&&~isfield(outData.ROI,'HbO'))
    fprintf(2,'No ROI information was built\nDefaulting to nanmean of valid channels\n');
    outData=pf2_build_nanmean_ROI(outData);
    if(~isempty(outData.ROI)&&isfield(outData.ROI,'HbO'))
        validChannels_roi=true(1,size(outData.ROI.('HbO'),2));
    else
        clear outData.ROI; 
    end
end


invalidChannels=false(size(data.channels));
invalidChannels(data.channels>0)=data.channels(data.channels>0)&(reshape(~curfMask,[1,numChannels]));

for bioM=1:length(bioM_list) % go through each biomarker and set invalid cahnnels to nan
    outData.(bioM_list{bioM})(:,invalidChannels)=nan;
    
    outData.(bioM_list{bioM})(~curftimeMask)=nan;
    
    if(pf2_base.isnestedfield(outData,'ROI.HbO'))
        outData.ROI.(bioM_list{bioM})(:,~validChannels_roi)=nan;
        outData.ROI.(bioM_list{bioM})(~curftimeMask_roi)=nan;
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




