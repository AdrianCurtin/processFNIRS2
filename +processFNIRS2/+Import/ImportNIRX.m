function [ fNIR] = ImportNIRX( file,pathname )
%ImportNIRX imports data from NIRX device recordings

if(nargin<2)
    pathname='';
end

if nargin < 1
   [file,pathname] = uigetfile({'*.hdr';'*.*'},'Open NIRX Config file');
  %error('Function requires at least one input argument');
elseif ~ischar(pathname)
  error('Input must be a string representing a filename');
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
    end
end
clear x dir;

fNIR=[];
wvCell=cell(0);
for i=1:size(files,1)
    filename=files{i,1};
    if(strcmp(files{i,2},'wavelength'))
        
        strs=strsplit(filename,'.');
        wvNum=str2double(strs{end}(3));
        [wvCell{wvNum}] = dlmread(filename,' ');
    end
    
    if(strcmp(files{i,2},'info'))
        fNIR.info.probeInfo=INI('File',filename);
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
end


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

fNIR.fchMask=zeros(1,numCh);

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
        fNIR.info.probename='Unkown .nirx file';
end

cd(curdir);


