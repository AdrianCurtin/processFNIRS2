function [fNIR] = ImportNIRX(folderDIR,channelCheck)
%ImportNIRX imports data from NIRX device recordings

if(nargin<2)
   channelCheck=true; 
   forceChannelCheck=false;
else
   forceChannelCheck=true; 
end

includeSSchannels=true;

buildProbeLayout=true;

if nargin < 1
   [folderDIR,pathname] = uigetfile({'*.hdr;*.nirs';'*.*'},'Open NIRX Config file');
  %error('Function requires at least one input argument');
elseif ~ischar(folderDIR)
  error('Input must be a string representing a filename');
else
   pathname=''; 
end

if(isempty(pathname))
    if(contains(folderDIR,'\\'))
        folderDIR(folderDIR=='\\')='/';
    end

    folderDIRparts=strsplit(folderDIR,'/');

    filename=folderDIRparts{end};


    pathname=folderDIR(1:end-length(filename));
end

curdir=cd;
if(~isempty(pathname))
    cd(pathname);
end
d=dir;

if(length(d)>2)
    files=cell(length(d)-2,2);
else
    error('No files found');
end

x=0;
for i=1:length(d)
    if(~d(i).isdir)
        x=x+1;
        files(x,1)={d(i).name};
        if ~isempty(strfind(files{x,1},'.wl'))
            files(x,2)={'wavelength'};
        end
        if ~isempty(strfind(files{x,1},'.inf'))
            files(x,2)={'demographics'};
        end
        if ~isempty(strfind(files{x,1},'.hdr'))
            files(x,2)={'info'};
        end
        if ~isempty(strfind(files{x,1},'_description.json'))
            files(x,2)={'j_description'};
        end
        if ~isempty(strfind(files{x,1},'_config.json'))
            files(x,2)={'j_info'};
        end
        if ~isempty(strfind(files{x,1},'_lsl.tri'))
            files(x,2)={'markers'};
        end
        
        if ~isempty(strfind(files{x,1},'.nirs'))
            files(x,2)={'nirs_file'};
        end
    end
end
clear x dir;

fNIR=[];
fNIR.raw=[];
wvCell=cell(0);

device=[];

for i=1:size(files,1)
    filename=files{i,1};
    if(strcmp(files{i,2},'wavelength'))
        
        strs=strsplit(filename,'.');
        wvNum=str2double(strs{end}(3));
        [wvCell{wvNum}] = dlmread(filename,' ');
    end
    
    if(strcmp(files{i,2},'nirs_file'))
        filenameParts=strsplit(filename,'.');
        fileroot=filenameParts{1};
        probeInfo=load(filename,'-mat');
        
        device=[];
        if(isfield(probeInfo,'t'))
            fNIR.time=probeInfo.t';
            
            fNIR.fs=1/nanmedian(diff(fNIR.time));
            device.Info.TimeIsSampleCount=0;
        end
        if(isfield(probeInfo,'d'))
            fNIR.raw=[probeInfo.t,probeInfo.d];
        end
        if(isfield(probeInfo,'s'))
            mrk=[];
            for mrkID=1:size(probeInfo.s,2)
                curMrkTime(:,1)=fNIR.time(probeInfo.s(:,mrkID)==1);
                curMrkTime(:,2)=mrkID;
                mrk=[mrk;curMrkTime];
            end
            [~,sortIdx]=sort(mrk(:,1));
            fNIR.markers=mrk(sortIdx,:);
            fNIR.Aux.NIRx=probeInfo.aux;
        end
        
        if(strcmp(probeInfo.SD.SpatialUnit,'mm'))
            probeInfo.SD.SrcPos=probeInfo.SD.SrcPos/10;
            probeInfo.SD.DetPos=probeInfo.SD.DetPos/10;
        end
        
        probeNums=unique(probeInfo.SD.MeasList(:,3)); % I THINK
        
        probeIdx=probeInfo.SD.MeasList(:,3);
        
        
        %device=pf2_base.external.INI();
        
        %%device.cfg=[];
        %device.cfg.Info=[];
        
        
        device.cfg=pf2_base.external.INI();
        device.Info.CfgName='generated NIRX file';
        
        device.Info.Name='Sport';
        device.Info.Manufacturer='NIRX';
        device.Info.DefaultSamplingRate=7.8125;
        device.Info.MaxSamplingRate=7.8125;
        device.Info.NumberProbes=length(probeNums);
        device.Info.RawMax=1;
        device.Info.RawMin=0;
        device.Info.NumberChannels=0;
        
        
        for p=1:length(probeNums)
            
            curProbeIdx=probeIdx==p;
        
            device.Probe{p}=[];
            
            device.Probe{p}.SrcPosX=probeInfo.SD.SrcPos(:,1);
            device.Probe{p}.SrcPosY=probeInfo.SD.SrcPos(:,2);
            device.Probe{p}.SrcPosZ=probeInfo.SD.SrcPos(:,3);
            device.Probe{p}.DetPosX=probeInfo.SD.DetPos(:,1);
            device.Probe{p}.DetPosY=probeInfo.SD.DetPos(:,2);
            device.Probe{p}.DetPosZ=probeInfo.SD.DetPos(:,3);
            
            
            device.Probe{p}.SrcPos3D=probeInfo.SD.SrcPos;
            device.Probe{p}.DetPos3D=probeInfo.SD.DetPos;
            

           
            device.Probe{p}.dI=probeInfo.SD.MeasList(curProbeIdx,2);
            device.Probe{p}.sI=probeInfo.SD.MeasList(curProbeIdx,1);
            
            SDpairs=[device.Probe{p}.sI,device.Probe{p}.dI];
            [uPairs,uPairUnsorted,uPairIdx]=unique(SDpairs,'rows');
            uPairs=SDpairs(uPairUnsorted,:);
            
            for opt=1:size(uPairs,1)
                sIdx=uPairs(opt,1);
                dIdx=uPairs(opt,2);
                srcPosX(opt)=device.Probe{p}.SrcPosX(sIdx);
                srcPosY(opt)=device.Probe{p}.SrcPosY(sIdx);
                srcPosZ(opt)=device.Probe{p}.SrcPosZ(sIdx);
                detPosX(opt)=device.Probe{p}.DetPosX(dIdx);
                detPosY(opt)=device.Probe{p}.DetPosY(dIdx);
                detPosZ(opt)=device.Probe{p}.DetPosZ(dIdx);
                srcPos3D(opt,:)=device.Probe{p}.SrcPos3D(sIdx,:);
                detPos3D(opt,:)=device.Probe{p}.DetPos3D(dIdx,:);
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
            
            device.Probe{p}.DetPos3D=detPos3D;
            device.Probe{p}.SrcPos3D=srcPos3D;
            
            device.Probe{p}.OptPos3D=(srcPos3D+detPos3D)/2;
            
            device.Probe{p}.SD=sqrt((device.Probe{p}.SrcPosX-device.Probe{p}.DetPosX).^2+...
                (device.Probe{p}.SrcPosY-device.Probe{p}.DetPosY).^2+(device.Probe{p}.SrcPosZ-device.Probe{p}.DetPosZ).^2)';
            device.Probe{p}.IsShortSeparation=device.Probe{p}.SD<2;
            
            numCh=size(uPairs,1);
            
            device.Probe{p}.probeNum=probeInfo.SD.MeasList(curProbeIdx,3);
            device.Probe{p}.wvI=probeInfo.SD.MeasList(curProbeIdx,4);
            device.Probe{p}.ChannelNumbers=uPairIdx';
            device.Probe{p}.ChannelList= 1:numCh;
            device.Probe{p}.Wavelength=probeInfo.SD.Lambda(device.Probe{p}.wvI);
            device.Info.NumberChannels=device.Info.NumberChannels+numCh;
            %numCh=length(unique(device.Probe{p}.ChannelNumbers));

            if(buildProbeLayout) % auto generate plot layour
                if(isfield(device.Probe{p},'OptPosX')&&isfield(device.Probe{p},'OptPosY'))
                    if(includeSSchannels)
                        device.Probe{p}.OptLayout2D=pf2_base.fitProbe2D(device.Probe{p}.OptPosX,device.Probe{p}.OptPosY,device.Probe{p}.OptPosZ);
                    else
                        device.Probe{p}.OptLayout2D=pf2_base.fitProbe2D(device.Probe{p}.OptPosX(~device.Probe{p}.IsShortSeparation)...
                            ,device.Probe{p}.OptPosY(~device.Probe{p}.IsShortSeparation),...
                            device.Probe{p}.OptPosZ(~device.Probe{p}.IsShortSeparation));
                    end
                else
                    warning('buildProbeLayout option selected, but not enough information to generate Optode locations');
                    device.Probe{p}.OptLayout2D=setUpFalse2D(device.Probe{p}.NumOptodes);  % generate false channels if not requested
                end
            else
                device.Probe{p}.OptLayout2D=setUpFalse2D(device.Probe{p}.NumOptodes);  % generate false channels if not requested
            end
        
        end
        
        
        
    end
    
    if(strcmp(files{i,2},'info'))
        filenameParts=strsplit(filename,'.');
        fileroot=filenameParts{1};
        fNIR.info.probeInfo=pf2_base.external.INI('File',filename);
        fNIR.info.probeInfo.read();
        pInfo=fNIR.info.probeInfo;
        
        if(ismember('Markers',fields(pInfo))&&isfield(pInfo.Markers,'Events'))
            NIRX_mrk=strsplit(pInfo.Markers.Events,'\n');
            numL=0;
            for l=1:length(NIRX_mrk)
                splitLine=strsplit(NIRX_mrk{l},'\t');
                if(length(splitLine)>1)
                    numL=numL+1;
                    fNIR.markers(numL,:)=str2double(splitLine);
                end
            end
        end
        
        if(ismember('ImagingParameters',fields(pInfo))&&isfield(pInfo.ImagingParameters,'SamplingRate'))
            fNIR.fs=pInfo.ImagingParameters.SamplingRate;
            fNIR.info.SamplingRate=fNIR.fs;
        end
        
        if(ismember('ImagingParameters',fields(pInfo))&&isfield(pInfo.ImagingParameters,'Wavelengths'))
            s=pInfo.ImagingParameters.Wavelengths;
            s(s==''''|s=='"')=[];
            s=strsplit(s,'\t');
            fNIR.info.curWv=str2double(s);
        end
        
        if(ismember('DataStructure',fields(pInfo))&&isfield(pInfo.DataStructure,'S_D_Key'))
            s=pInfo.DataStructure.S_D_Key;
            s(s==''''|s=='"')=[];
            sdkeyLines=strsplit(s,',');
            for l=1:length(sdkeyLines) % Source, Detector, Channel
                fNIR.info.sd_key(l,:)=str2double(strsplit(sdkeyLines{l},{'"','-',':'}));
            end
        end
        
        if(ismember('DataStructure',fields(pInfo))&&isfield(pInfo.DataStructure,'S_D_Mask'))
            s=pInfo.DataStructure.S_D_Mask;
            s(s==''''|s=='"')=[];
            sdmaskLines=strsplit(s,'\n');
            numL=0;
            for l=1:length(sdmaskLines)
                splitLine=strsplit(sdmaskLines{l},'\t');
                if(length(splitLine)>1)
                    numL=numL+1;
                    fNIR.info.sd_mask(numL,:)=str2double(splitLine);
                end
            end
        end
        
        if(ismember('ChannelsDistance',fields(pInfo))&&isfield(pInfo.ChannelsDistance,'ChanDis'))
            s=pInfo.ChannelsDistance.ChanDis;
            s(s==''''|s=='"')=[];
            splitLine=strsplit(s,'\t');
            fNIR.info.ChanDis=str2double(splitLine)/10; %convert to cm
        end
        
        if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'Subject'))
            fNIR.info.SubjectID=pInfo.GeneralInfo.Subject;
        end
        
        if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'FileName'))
            fNIR.info.Filename=pInfo.GeneralInfo.FileName;
        end
        
        if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'Date'))
            fNIR.info.Date=pInfo.GeneralInfo.Date;
        end
        
        if(ismember('GeneralInfo',fields(pInfo))&&isfield(pInfo.GeneralInfo,'Time'))
            fNIR.info.Time=pInfo.GeneralInfo.Time;
        end
    end
    
    if(strcmp(files{i,2},'j_info'))

        pInfo = jsondecode(fileread(filename));
        
        if(isfield(pInfo,'montage_path'))
            fNIR.info.montage_path=pInfo.montage_path;
        end
    end
    
    if(strcmp(files{i,2},'j_description'))

        pInfo = jsondecode(fileread(filename));
        
        if(isfield(pInfo,'subject'))
            fNIR.info.SubjectID=pInfo.subject;
        end
        
        
        if(isfield(pInfo,'age')&&~isempty(pInfo.age))
            fNIR.info.Age=pInfo.age;
        else
            fNIR.info.Age=[];
        end
        
        if(isfield(pInfo,'gender'))
            fNIR.info.Sex='';
        end
        
        if(isfield(pInfo,'contact_info'))
            fNIR.info.contact_info='';
        end
        
        if(isfield(pInfo,'experiment'))
            fNIR.info.Session='';
        end
        
        if(isfield(pInfo,'remarks'))
            fNIR.info.remarks='';
        end
    end
end


if(isempty(fNIR.raw))
    numWv=length(wvCell);

    if(numWv>0)
       sampleNum=size(wvCell{1},1);
       numCh=size(wvCell{1},2);
    else
       error('Unable to find any .wv* files'); 
    end

    fNIR.raw=nan(sampleNum,numCh*numWv+1);


    for w=1:numWv
        wvRaw=wvCell{w};
        fNIR.raw(:,(1:numCh)*numWv-numWv+w+1)=wvRaw;

    end

    if(isfield(fNIR,'fs'))
        fNIR.raw(:,1)=[1:sampleNum]'./fNIR.fs;
    else
       error('Sampling Frequency is missing'); 
    end
    
    
    if(isfield(fNIR.info,'sd_key')&&isfield(fNIR.info,'sd_mask'))
        for x=1:size(fNIR.info.sd_mask,1)
           for y=1:size(fNIR.info.sd_mask,2)
               if(fNIR.info.sd_mask(x,y)==1)
                   sdkey_chIdx=fNIR.info.sd_key(:,1)==x&fNIR.info.sd_key(:,2)==y;
                   fNIR.fchMask(fNIR.info.sd_key(sdkey_chIdx,3))=1;
               end
           end
        end
    end
    
    numRawChannels=size(data,1)-1;

    switch(numRawChannels)
        case 49
            fNIR.info.probename='NIRX_Sport_8x8_Frontal';
        otherwise
            warning('Unidentified Probe\n');
            fNIR.info.probename='Unidentified .nirx file';
    end
else
    fNIR.info.probename='generated NIRX file';
end

fNIR.fchMask=ones(1,numCh);


fNIR.probeinfo=device;

if(~channelCheck)
    ch_mask_file=sprintf('%s_CH.mat',fileroot);

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
    fNIR=probeCheckGUI(fNIR,sprintf('%s.nirs',fileroot),forceChannelCheck);
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

cd(curdir);
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



