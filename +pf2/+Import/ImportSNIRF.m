function [fNIR] = ImportSNIRF(filepath,channelCheck,varargin)
%ImportSNIRF imports data from SNIRF device recordings

if(nargin<2)
   channelCheck=true; 
   forceChannelCheck=false;
else
   forceChannelCheck=true; 
end

includeSSchannels=true;

buildProbeLayout=true;

if nargin < 1
   [filepath,pathname] = uigetfile({'*.snirf;*.jsnirf','snirf files (*.snirf,*.jsnirf)';'*.*','All files (*.*)'},'Open SNIRF file');
   filepath=strcat(pathname,'/',filepath);
  %error('Function requires at least one input argument');
elseif ~ischar(filepath)
  error('Input must be a string representing a filename');
end


data=pf2_base.external.jsnirfy.loadsnirf(filepath,varargin);

if(~isfield(data,'nirs'))
    error('No nirs struct contained in file')
end

% probe information
probeInfo=data.nirs.probe;

% Data type of 1 is CW amplitude
% Data type of 99999 is processed

fNIR=[];

metaDataTags=stripStruct(data.nirs.metaDataTags);

if(isfield(data.nirs,'stim'))
    markerArray=[];
    stimArray=data.nirs.stim;
    for m = 1:length(stimArray)
        curStim=stimArray(m);
        markerArray=[markerArray;curStim.data(:,[1,3,2])];
    end
    if(length(stimArray)>1)
        [~,bi]=sort(markerArray(:,1));
        fNIR.markers=markerArray(bi,:);
    else
        fNIR.markers=[];
    end
else
    
end

data=data.nirs.data;

measurementList=struct2table(data.measurementList);




fNIR.raw=data.dataTimeSeries;


device=[];

fNIR.time=data.time';
            
fNIR.fs=1/nanmedian(diff(fNIR.time));





fNIR.info=metaDataTags;

device.Info.TimeIsSampleCount=0;

      
%        Marker handling + aux
% Use STIM field/structs
%         if(isfield(probeInfo,'s'))
%             mrk=[];
%             for mrkID=1:size(probeInfo.s,2)
%                 curMrkTime(:,1)=fNIR.time(probeInfo.s(:,mrkID)==1);
%                 curMrkTime(:,2)=mrkID;
%                 mrk=[mrk;curMrkTime];
%             end
%             [~,sortIdx]=sort(mrk(:,1));
%             fNIR.markers=mrk(sortIdx,:);
%             fNIR.Aux.NIRx=probeInfo.aux;
%         end
%         

if(strcmp(metaDataTags.LengthUnit,'cm'))
    % convert to cm

    probeInfo.detectorPos3D=probeInfo.detectorPos3D*10;
    probeInfo.sourcePos3D=probeInfo.sourcePos3D*10;
    if(isfield(probeInfo,'landmarkPos3D'))
        probeInfo.landmarkPos3D=probeInfo.landmarkPos3D*10;
    end
end

if(isfield(metaDataTags,'MeasurementTime')&&isfield(metaDataTags,'MeasurementDate'))
    dateTimeStr = [metaDataTags.MeasurementDate 'T' metaDataTags.MeasurementTime];
    fNIR.t0 = datetime(dateTimeStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSz','TimeZone','local');

elseif(isfield(metadataTags,'UnixTime'))
    unixTime = str2double(metadataTags.UnixTime);

    % Convert Unix time to datetime
    fNIR.t0 = datetime(unixTime, 'ConvertFrom', 'posixtime');

end
        
        %probeNums=unique(probeInfo.SD.MeasList(:,3)); % I THINK
        
        %probeIdx=probeInfo.SD.MeasList(:,3);
        
        
        %device=pf2_base.external.INI();
        
        %%device.cfg=[];
        %device.cfg.Info=[];
        
        
device.cfg=pf2_base.external.INI();
device.Info.CfgName='generated SNIRF file';
        
device.Info.Name=metaDataTags.Model;
device.Info.Manufacturer=metaDataTags.ManufacturerName;
device.Info.DefaultSamplingRate=fNIR.fs;
device.Info.MaxSamplingRate=fNIR.fs;
device.Info.NumberProbes=1;%length(probeNums);
device.Info.RawMax=nanmax(nanmax(fNIR.raw));
device.Info.RawMin=nanmin(nanmin(fNIR.raw));
device.Info.NumberChannels=0;
        
        
for p=1:1%length(probeNums)
    
    curProbeIdx=1;%1;probeIdx==p;

    device.Probe{p}=[];

    
    
    
    device.Probe{p}.SrcPosX=probeInfo.sourcePos3D(:,1);
    device.Probe{p}.SrcPosY=probeInfo.sourcePos3D(:,2);
    device.Probe{p}.SrcPosZ=probeInfo.sourcePos3D(:,3);
    device.Probe{p}.DetPosX=probeInfo.detectorPos3D(:,1);
    device.Probe{p}.DetPosY=probeInfo.detectorPos3D(:,2);
    device.Probe{p}.DetPosZ=probeInfo.detectorPos3D(:,3);
    
    
    device.Probe{p}.SrcPos3D=probeInfo.sourcePos3D;
    device.Probe{p}.DetPos3D=probeInfo.detectorPos3D;

    device.Probe{p}.TableSD=table();
    device.Probe{p}.TableCh=table(); % Map for raw probe data
    
    device.Probe{p}.TableCh.ColNumber=[1:height(measurementList)]';

    [~,firstOpt,uOpt]=unique(measurementList(:,{'detectorIndex','sourceIndex'}),'rows');
    device.Probe{p}.TableCh.OptodeNumber=uOpt;
    device.Probe{p}.TableCh.isTime=device.Probe{p}.TableCh.OptodeNumber==0;
    device.Probe{p}.TableCh.isMarker=device.Probe{p}.TableCh.OptodeNumber<0|isnan(device.Probe{p}.TableCh.OptodeNumber);
    
    device.Probe{p}.TableCh.OptodeNumber(device.Probe{p}.TableCh.OptodeNumber<1)=nan;
    
    validWVindex=~isnan(measurementList.('wavelengthIndex'));
    device.Probe{p}.TableCh.Wavelength(:)=nan;
    device.Probe{p}.TableCh.Wavelength(validWVindex)=probeInfo.wavelengths(measurementList{validWVindex,'wavelengthIndex'})';
    device.Probe{p}.TableCh.isDark=(isnan(device.Probe{p}.TableCh.Wavelength)|device.Probe{p}.TableCh.Wavelength==0);
    device.Probe{p}.TableCh.SourceIndex(:)=measurementList.('sourceIndex');
    device.Probe{p}.TableCh.DetectorIndex(:)=measurementList.('detectorIndex');

    device.Probe{p}.TableCh.Label(:)="";
        
    for ch=1:length(uOpt)
        if(device.Probe{p}.TableCh.isTime(ch))
           device.Probe{p}.TableCh.Label(ch)="Time"; 
        elseif(device.Probe{p}.TableCh.isMarker(ch))
            device.Probe{p}.TableCh.Label(ch)="Mrk";
        elseif(device.Probe{p}.TableCh.isDark(ch))
            opt=device.Probe{p}.TableCh.OptodeNumber(ch);
            device.Probe{p}.TableCh.Label(ch)=sprintf('Opt%i_dark',opt);
        else
            wv=device.Probe{p}.TableCh.Wavelength(ch);
            opt=device.Probe{p}.TableCh.OptodeNumber(ch);
            device.Probe{p}.TableCh.Label(ch)=sprintf('Opt%i_wv%.1f',opt,wv);
        end
    end

    device.Probe{p}.SrcPos=table();
    device.Probe{p}.SrcPos.x_2d=probeInfo.sourcePos2D(:,1);
    device.Probe{p}.SrcPos.y_2d=probeInfo.sourcePos2D(:,2);
    device.Probe{p}.SrcPos.z_2d=probeInfo.sourcePos2D(:,1)*0;
    device.Probe{p}.SrcPos.x=device.Probe{p}.SrcPosX(:);
    device.Probe{p}.SrcPos.y=device.Probe{p}.SrcPosY(:);
    device.Probe{p}.SrcPos.z=device.Probe{p}.SrcPosZ(:);
    
    
    device.Probe{p}.DetPos=table();
    device.Probe{p}.DetPos.x_2d=probeInfo.detectorPos2D(:,1);
    device.Probe{p}.DetPos.y_2d=probeInfo.detectorPos2D(:,2);
    device.Probe{p}.DetPos.z_2d=probeInfo.detectorPos2D(:,1)*0;
    device.Probe{p}.DetPos.x=device.Probe{p}.DetPosX(:);
    device.Probe{p}.DetPos.y=device.Probe{p}.DetPosY(:);
    device.Probe{p}.DetPos.z=device.Probe{p}.DetPosZ(:);
    
  
    device.Probe{p}.TableOpt=table();
    device.Probe{p}.TableOpt.OptodeNum(:)=[1:length(firstOpt)]';

    % auto generated later, could be pulled from data maybe
    %device.Probe{p}.TableOpt.Label=p.ChannelLabels(:);

    

    
   
    device.Probe{p}.dI=measurementList.('detectorIndex');
    device.Probe{p}.sI=measurementList.('sourceIndex');

    device.Probe{p}.TableOpt.SrcIdx=measurementList{firstOpt,'sourceIndex'};
    device.Probe{p}.TableOpt.DetIdx=measurementList{firstOpt,'detectorIndex'};
    
    SDpairs=[device.Probe{p}.sI,device.Probe{p}.dI];
    [uPairs,uPairUnsorted,uPairIdx]=unique(SDpairs,'rows');
    uPairs=SDpairs(uPairUnsorted,:);

   %uPairs=uPairs(~any(isnan(uPairs),2),:);
    
    for opt=1:size(uPairs,1)
        sIdx=uPairs(opt,1);
        dIdx=uPairs(opt,2);
        if(isnan(sIdx)||isnan(dIdx))
            srcPosX(opt)=nan;
            srcPosY(opt)=nan;
            srcPosZ(opt)=nan;
            detPosX(opt)=nan;
            detPosY(opt)=nan;
            detPosZ(opt)=nan;
            srcPos3D(opt,:)=nan;
            detPos3D(opt,:)=nan;
        else
            srcPosX(opt)=device.Probe{p}.SrcPosX(sIdx);
            srcPosY(opt)=device.Probe{p}.SrcPosY(sIdx);
            srcPosZ(opt)=device.Probe{p}.SrcPosZ(sIdx);
            detPosX(opt)=device.Probe{p}.DetPosX(dIdx);
            detPosY(opt)=device.Probe{p}.DetPosY(dIdx);
            detPosZ(opt)=device.Probe{p}.DetPosZ(dIdx);
            srcPos3D(opt,:)=device.Probe{p}.SrcPos3D(sIdx,:);
            detPos3D(opt,:)=device.Probe{p}.DetPos3D(dIdx,:);
        end
    end
    
    device.Probe{p}.SrcPosX=srcPosX';
    device.Probe{p}.SrcPosY=srcPosY';
    device.Probe{p}.SrcPosZ=srcPosZ';
    device.Probe{p}.DetPosX=detPosX';
    device.Probe{p}.DetPosY=detPosY';
    device.Probe{p}.DetPosZ=detPosZ';
    
    device.Probe{p}.OptPosX=mean([device.Probe{p}.SrcPosX(:,1),device.Probe{p}.DetPosX(:,1)],2);
    device.Probe{p}.OptPosY=mean([device.Probe{p}.SrcPosY(:,1),device.Probe{p}.DetPosY(:,1)],2);
    device.Probe{p}.OptPosZ=mean([device.Probe{p}.SrcPosZ(:,1),device.Probe{p}.DetPosZ(:,1)],2);
    device.Probe{p}.NumOptodes=length(device.Probe{p}.OptPosX);

    device.Probe{p}.OptPos=table();
    device.Probe{p}.OptPos.x_2d=device.Probe{p}.OptPosX(:);
    device.Probe{p}.OptPos.y_2d=device.Probe{p}.OptPosY(:);
    device.Probe{p}.OptPos.z_2d=device.Probe{p}.OptPosZ(:);
    device.Probe{p}.OptPos.x=device.Probe{p}.OptPosX(:);
    device.Probe{p}.OptPos.y=device.Probe{p}.OptPosY(:);
    device.Probe{p}.OptPos.z=device.Probe{p}.OptPosZ(:);
    

    device.Probe{p}.TableOpt.Pos2D_x=device.Probe{p}.OptPos.x_2d;
    device.Probe{p}.TableOpt.Pos2D_y=device.Probe{p}.OptPos.y_2d;
    device.Probe{p}.TableOpt.Pos2D_z=device.Probe{p}.OptPos.z_2d;
    
    device.Probe{p}.TableOpt.Pos3D_x=device.Probe{p}.OptPos.x;
    device.Probe{p}.TableOpt.Pos3D_y=device.Probe{p}.OptPos.y;
    device.Probe{p}.TableOpt.Pos3D_z=device.Probe{p}.OptPos.z;

    device.Probe{p}.DetPos3D=detPos3D;
    device.Probe{p}.SrcPos3D=srcPos3D;

    device.Probe{p}.TableSD=table();

    Type_temp=[ones([height(device.Probe{p}.SrcPos),1]);ones([height(device.Probe{p}.DetPos),1])*2];
                
    typeStr_temp={'Src','Det'};
    
    catType_temp=categorical(typeStr_temp(Type_temp(:)),typeStr_temp);
    device.Probe{p}.TableSD.Type=catType_temp(:);
    
    device.Probe{p}.TableSD.Index=[(1:height(device.Probe{p}.SrcPos))';(1:height(device.Probe{p}.DetPos))'];

    for sd=1:height(device.Probe{p}.TableSD)
        typeLabel=sprintf('%s',device.Probe{p}.TableSD.Type(sd));
        device.Probe{p}.TableSD.Label{sd}=sprintf('%s%i',typeLabel(1),device.Probe{p}.TableSD.Index(sd));

    end

    device.Probe{p}.TableSD.Pos2D_x=[device.Probe{p}.SrcPos.x_2d(:);device.Probe{p}.DetPos.x_2d(:)];
    device.Probe{p}.TableSD.Pos2D_y=[device.Probe{p}.SrcPos.y_2d(:);device.Probe{p}.DetPos.y_2d(:)];
    device.Probe{p}.TableSD.Pos2D_z=[device.Probe{p}.SrcPos.z_2d(:);device.Probe{p}.DetPos.z_2d(:)];


    device.Probe{p}.TableSD.Pos3D_x=[device.Probe{p}.SrcPos.x(:);device.Probe{p}.DetPos.x(:)];
    device.Probe{p}.TableSD.Pos3D_y=[device.Probe{p}.SrcPos.y(:);device.Probe{p}.DetPos.y(:)];
    device.Probe{p}.TableSD.Pos3D_z=[device.Probe{p}.SrcPos.z(:);device.Probe{p}.DetPos.z(:)];
    
    device.Probe{p}.OptPos3D=(srcPos3D+detPos3D)/2;
    
    device.Probe{p}.SD=sqrt((device.Probe{p}.SrcPosX-device.Probe{p}.DetPosX).^2+...
        (device.Probe{p}.SrcPosY-device.Probe{p}.DetPosY).^2+(device.Probe{p}.SrcPosZ-device.Probe{p}.DetPosZ).^2)';
    device.Probe{p}.IsShortSeparation=device.Probe{p}.SD<20;

    device.Probe{p}.NumShortSeparation=sum(device.Probe{p}.IsShortSeparation);

    device.Probe{p}.TableOpt.SD=device.Probe{p}.SD(:);
    device.Probe{p}.TableOpt.IsShortSeparation=device.Probe{p}.IsShortSeparation(:);
    
    numCh=size(uPairs,1);
    
    device.Probe{p}.probeNum=1;%probeInfo.SD.MeasList(curProbeIdx,3);
    device.Probe{p}.wvI=reshape(measurementList.('wavelengthIndex'),[1,height(measurementList)]);
    device.Probe{p}.ChannelNumbers=uPairIdx';
    device.Probe{p}.ChannelList= 1:numCh;
    device.Probe{p}.Wavelength=probeInfo.wavelengths;
    device.Info.NumberChannels=device.Info.NumberChannels+numCh;


    for c=50:length(firstOpt)
        device.Probe{p}.TableOpt.Ch(c,:)=(find(device.Probe{p}.ChannelNumbers==device.Probe{p}.ChannelList(c)));
        wvIdxToMatch=device.Probe{p}.wvI(device.Probe{p}.TableOpt.Ch(c,:));
        if(~any(isnan(wvIdxToMatch)))
            device.Probe{p}.TableOpt.wv(c,:)=device.Probe{p}.Wavelength(wvIdxToMatch);
        end
        if(true)%~hasLabel)
           device.Probe{p}.TableOpt.Label{c}=sprintf('Opt%i', device.Probe{p}.ChannelList(c));
        end
    end
    




    %numCh=length(unique(device.Probe{p}.ChannelNumbers));

    if(buildProbeLayout) % auto generate plot layour
        if(isfield(device.Probe{p},'OptPosX')&&isfield(device.Probe{p},'OptPosY'))
            if(includeSSchannels)
                device.Probe{p}.OptLayout2D_ss=pf2_base.fitProbe2D(device.Probe{p}.OptPosX,device.Probe{p}.OptPosY,device.Probe{p}.OptPosZ);
            end
                device.Probe{p}.OptLayout2D=pf2_base.fitProbe2D(device.Probe{p}.OptPosX(~device.Probe{p}.IsShortSeparation)...
                    ,device.Probe{p}.OptPosY(~device.Probe{p}.IsShortSeparation),...
                    device.Probe{p}.OptPosZ(~device.Probe{p}.IsShortSeparation));
            
        else
            warning('buildProbeLayout option selected, but not enough information to generate Optode locations');
            device.Probe{p}.OptLayout2D=setUpFalse2D(device.Probe{p}.NumOptodes);  % generate false channels if not requested
        end
    else
        device.Probe{p}.OptLayout2D=setUpFalse2D(device.Probe{p}.NumOptodes);  % generate false channels if not requested
    end

    device.Probe{p}.OptPos.subplot_layout(:)=cell(size(device.Probe{p}.OptPos.z));
    device.Probe{p}.OptPos.subplot_layout(~device.Probe{p}.IsShortSeparation)=device.Probe{p}.OptLayout2D(:);
    if(includeSSchannels)
        device.Probe{p}.OptPos.subplot_layout_ss=device.Probe{p}.OptLayout2D_ss(:);
    else
       device.Probe{p}.OptPos.subplot_layout_ss= device.Probe{p}.OptPos.subplot_layout;
    end

end
    
    
    

%     pInfo=fNIR.info.probeInfo;
%     
%     if(ismember('Markers',fields(pInfo))&&isfield(pInfo.Markers,'Events'))
%         NIRX_mrk=strsplit(pInfo.Markers.Events,'\n');
%         numL=0;
%         for l=1:length(NIRX_mrk)
%             splitLine=strsplit(NIRX_mrk{l},'\t');
%             if(length(splitLine)>1)
%                 numL=numL+1;
%                 fNIR.markers(numL,:)=str2double(splitLine);
%             end
%         end
%     end
%     
%     if(ismember('ImagingParameters',fields(pInfo))&&isfield(pInfo.ImagingParameters,'SamplingRate'))
%         fNIR.fs=pInfo.ImagingParameters.SamplingRate;
%         fNIR.info.SamplingRate=fNIR.fs;
%     end
%     
%     if(ismember('ImagingParameters',fields(pInfo))&&isfield(pInfo.ImagingParameters,'Wavelengths'))
%         s=pInfo.ImagingParameters.Wavelengths;
%         s(s==''''|s=='"')=[];
%         s=strsplit(s,'\t');
%         fNIR.info.curWv=str2double(s);
%     end
%     
%     if(ismember('DataStructure',fields(pInfo))&&isfield(pInfo.DataStructure,'S_D_Key'))
%         s=pInfo.DataStructure.S_D_Key;
%         s(s==''''|s=='"')=[];
%         sdkeyLines=strsplit(s,',');
%         for l=1:length(sdkeyLines) % Source, Detector, Channel
%             fNIR.info.sd_key(l,:)=str2double(strsplit(sdkeyLines{l},{'"','-',':'}));
%         end
%     end
%     
%     if(ismember('DataStructure',fields(pInfo))&&isfield(pInfo.DataStructure,'S_D_Mask'))
%         s=pInfo.DataStructure.S_D_Mask;
%         s(s==''''|s=='"')=[];
%         sdmaskLines=strsplit(s,'\n');
%         numL=0;
%         for l=1:length(sdmaskLines)
%             splitLine=strsplit(sdmaskLines{l},'\t');
%             if(length(splitLine)>1)
%                 numL=numL+1;
%                 fNIR.info.sd_mask(numL,:)=str2double(splitLine);
%             end
%         end
%     end
%     
%     if(ismember('ChannelsDistance',fields(pInfo))&&isfield(pInfo.ChannelsDistance,'ChanDis'))
%         s=pInfo.ChannelsDistance.ChanDis;
%         s(s==''''|s=='"')=[];
%         splitLine=strsplit(s,'\t');
%         fNIR.info.ChanDis=str2double(splitLine)/10; %convert to cm
%     end
%     
%     if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'Subject'))
%         fNIR.info.SubjectID=pInfo.GeneralInfo.Subject;
%     end
%     
%     if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'FileName'))
%         fNIR.info.Filename=pInfo.GeneralInfo.FileName;
%     end
%     
%     if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'Date'))
%         fNIR.info.Date=pInfo.GeneralInfo.Date;
%         fNIR.info.StartDateTime=datetime(pInfo.GeneralInfo.Date);
%     end
%     
%     if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'Time'))
%         fNIR.info.Time=pInfo.GeneralInfo.Time;
%         %fNIR.info.StartDateTime=pInfo.GeneralInfo.Time;
%     end
% end
% 
% if(strcmp(files{i,2},'j_info'))
% 
%     pInfo = jsondecode(fileread(filename));
%     
%     if(isfield(pInfo,'montage_path'))
%         fNIR.info.montage_path=pInfo.montage_path;
%     end
% end
% 
% if(strcmp(files{i,2},'j_description'))
% 
%     pInfo = jsondecode(fileread(filename));
%     
%     if(isfield(pInfo,'subject'))
%         fNIR.info.SubjectID=pInfo.subject;
%     end
%     
%     
%     if(isfield(pInfo,'age')&&~isempty(pInfo.age))
%         fNIR.info.Age=pInfo.age;
%     else
%         fNIR.info.Age=[];
%     end
%     
%     if(isfield(pInfo,'gender'))
%         fNIR.info.Sex='';
%     end
%     
%     if(isfield(pInfo,'contact_info'))
%         fNIR.info.contact_info='';
%     end
%     
%     if(isfield(pInfo,'experiment'))
%         fNIR.info.Session='';
%     end
%     
%     if(isfield(pInfo,'remarks'))
%         fNIR.info.remarks='';
%     end
% 
% end


if(isempty(fNIR.raw))
%     numWv=length(wvCell);
% 
%     if(numWv>0)
%        sampleNum=size(wvCell{1},1);
%        numCh=size(wvCell{1},2);
%     else
%        error('Unable to find any .wv* files'); 
%     end
% 
%     fNIR.raw=nan(sampleNum,numCh*numWv+1);
% 
% 
%     for w=1:numWv
%         wvRaw=wvCell{w};
%         fNIR.raw(:,(1:numCh)*numWv-numWv+w+1)=wvRaw;
% 
%     end
% 
%     if(isfield(fNIR,'fs'))
%         fNIR.raw(:,1)=[1:sampleNum]'./fNIR.fs;
%     else
%        error('Sampling Frequency is missing'); 
%     end
%     
%     
%     if(isfield(fNIR.info,'sd_key')&&isfield(fNIR.info,'sd_mask'))
%         for x=1:size(fNIR.info.sd_mask,1)
%            for y=1:size(fNIR.info.sd_mask,2)
%                if(fNIR.info.sd_mask(x,y)==1)
%                    sdkey_chIdx=fNIR.info.sd_key(:,1)==x&fNIR.info.sd_key(:,2)==y;
%                    fNIR.fchMask(fNIR.info.sd_key(sdkey_chIdx,3))=1;
%                end
%            end
%         end
%     end
%     
% %    numRawChannels=size(data,1)-1;
% 
%     %switch(numRawChannels)
%      %   otherwise
%       %      warning('Unidentified Probe\n');
%       %      fNIR.info.probename='Unidentified .snirf file';
%     %end
else
    fNIR.info.probename='generated SNIRF file';
end

fNIR.fchMask=ones(1,numCh);


fNIR.probeinfo=device;

if(~channelCheck)
    ch_mask_file=sprintf('%s_CH.mat',filepath);

    try
        fmask=load(ch_mask_file,'fmask');
        fmask=fmask.fmask;
        fprintf('%i Channels marked bad\n',sum(fmask<1));
    catch
        fprintf('No channel rejection present\n');
        fmask=[];
    end
else
   fmask=[]; 
end

if(channelCheck)
    fNIR=probeCheckGUI(fNIR,filepath,forceChannelCheck);
else
   if(~isempty(fmask))
       fNIR.fchMask=fmask; 
   end
end



if(isfield(fNIR,'probeinfo'))
   global setF
   device.cfg.add('Info',device.Info);
   for i=1:length(device.Probe)
       device.cfg.add(sprintf('Probe%i',i),device.Probe{i});
   end

   setF.device=device;
   
end

%cd(curdir);
end



function opt_2d_coords=setUpFalse2D(numCh)

for i=1:numCh
    x1=i-1;
    x2=1;
    y1=0;
    y2=0.9;
    x2=x2/numCh;
    x1=x1/numCh;
    
    opt_2d_coords{i}=[x1,y1,x2,y2];
end
end


function outTable=struct2table(structObj)
    
    fieldsInStruct=fields(structObj(1));

   
    outTable=table();
    for n=1:length(structObj)
         newTable=table();
        for f=1:length(fieldsInStruct)
            newTable.(fieldsInStruct{f})=structObj(n).(fieldsInStruct{f});
            if(ischar(newTable.(fieldsInStruct{f}))||isstring(newTable.(fieldsInStruct{f})))
                newTable.(fieldsInStruct{f})=cellstr(newTable.(fieldsInStruct{f}));
            end
        end
        outTable=[outTable;newTable];
    end

end

function outStruct = stripStruct(structObj)
    fieldsInStruct=fields(structObj);

   
    outStruct=structObj;
    
    for f=1:length(fieldsInStruct)
        temp=structObj.(fieldsInStruct{f});
        outStruct.(fieldsInStruct{f})=strtrim(strrep(reshape(temp,[1,length(temp)]),char(0),''));
    end
end
