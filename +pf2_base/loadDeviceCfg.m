function probeInfo=loadDeviceCfg(deviceCfgFilename,buildProbeLayout)

if(nargin<2)
   buildProbeLayout=false; 
end

pF2_folder=pf2_base.pf2_defaultRootPath();


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

        probeInfo.cfg = pf2_base.external.INI('File',[pathname file]);
    else
        fclose(fid);
        probeInfo.cfg = pf2_base.external.INI('File',deviceCfgFilename);
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

    probeInfo.cfg = pf2_base.external.INI('File',[pathname file]);
end

probeInfo.cfg.read();

probeInfo.Info=probeInfo.cfg.Info;

probeCount=0;
for j=1:length(probeInfo.cfg.Sections)
	if(strfind(probeInfo.cfg.Sections{j},'Probe'))
    	probeCount=probeCount+1;
        probeInfo.Probe{probeCount}=get(probeInfo.cfg,probeInfo.cfg.Sections{j});
        tempChannels=unique(probeInfo.Probe{probeCount}.ChannelNumbers);
        probeInfo.Probe{probeCount}.ChannelList=tempChannels(tempChannels>0);
        probeInfo.Probe{probeCount}.NumOptodes=length(probeInfo.Probe{probeCount}.ChannelList);
        if(isfield(probeInfo.Probe{probeCount},'DetPosX')&&isfield(probeInfo.Probe{probeCount},'SrcPosX'))
            probeInfo.Probe{probeCount}.OptPosX=nanmean([probeInfo.Probe{probeCount}.DetPosX',probeInfo.Probe{probeCount}.SrcPosX'],2)';
        end
        
        if(isfield(probeInfo.Probe{probeCount},'DetPosY')&&isfield(probeInfo.Probe{probeCount},'SrcPosY'))
            probeInfo.Probe{probeCount}.OptPosY=nanmean([probeInfo.Probe{probeCount}.DetPosY',probeInfo.Probe{probeCount}.SrcPosY'],2)';
        end
        
        if(isfield(probeInfo.Probe{probeCount},'DetPosZ')&&isfield(probeInfo.Probe{probeCount},'SrcPosZ'))
            probeInfo.Probe{probeCount}.OptPosZ=nanmean([probeInfo.Probe{probeCount}.DetPosZ',probeInfo.Probe{probeCount}.SrcPosZ'],2)';
        end
        
        if(buildProbeLayout) % auto generate plot layour
            if(isfield(probeInfo.Probe{probeCount},'OptPosX')&&isfield(probeInfo.Probe{probeCount},'OptPosY'))
                probeInfo.Probe{probeCount}.OptLayout2D=setUp2DAxes(probeInfo.Probe{probeCount}.OptPosX,probeInfo.Probe{probeCount}.OptPosY);
            else
                warning('buildProbeLayout option selected, but not enough information to generate Optode locations');
                probeInfo.Probe{probeCount}.OptLayout2D=setUpFalse2D(probeInfo.Probe{probeCount}.NumOptodes);  % generate false channels if not requested
            end
        else
            probeInfo.Probe{probeCount}.OptLayout2D=setUpFalse2D(probeInfo.Probe{probeCount}.NumOptodes);  % generate false channels if not requested
        end
    end
    
end

if(nargout==0) % assigns the global device
    global setF
    setF.device=probeInfo;
end

end

function opt_2d_coords=setUpFalse2D(numCh)

for i=1:numCh
    x1=i-1;
    x2=1;
    y1=0;
    y2=0.9;
    x2=x2/numCh;
    x1=x1/numCh;
    
    opt_2d_coords{i}=[x1,y1,x2-x1,y2-y1];
end
end

function opt_2d_coords=setUp2DAxes(ChxList,ChyList)

plotFigs=false;
fprintf('Autoplacing Channels');
    
global chAxesHandles

numCh=length(ChxList);

chAxesHandles=cell(numCh,1);

ChxList=(ChxList-min(ChxList))./(max(ChxList)-min(ChxList));

ChyList=(ChyList-min(ChyList))./(max(ChyList)-min(ChyList));

% if(plotFigs)
%     figure(999);
%     handles.uipanel_arranged=uipanel('Title','Panel', 'Position',[.1 .1 .8 .8]);
%     uiP=handles.uipanel_arranged;
% end


uCh=unique([ChxList,ChyList],'rows');

if(size(uCh,2)<length(ChxList))
    error('Duplicate Channel Locations Present');
end



uCh=unique([ChxList(:),ChyList(:)],'rows');

if(size(uCh,1)<length(ChxList))
    error('Duplicate Channel Locations Present');
end

startStepSize=50;
stepSize=10;

tic

maskSize=1200;

for pSize=startStepSize:stepSize:maskSize
    bitMask=zeros(maskSize,maskSize);
    for c=1:numCh
        [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),pSize,pSize);
        bitMask(x1:x2,y1:y2)=bitMask(x1:x2,y1:y2)+1;
    end
    if(plotFigs)
        figure(2);
        imagesc(bitMask);
        java.lang.Thread.sleep(100) ;
    end
    
    if(sum(sum(bitMask>1))>0)
        break;
    end
    lastPsize=pSize-stepSize;
end

for wSize=lastPsize:stepSize:maskSize
    bitMask=zeros(maskSize,maskSize);
    for c=1:numCh
        [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),wSize,lastPsize);
        bitMask(x1:x2,y1:y2)=bitMask(x1:x2,y1:y2)+1;
    end
    if(plotFigs)
        figure(2);
        imagesc(bitMask);
        java.lang.Thread.sleep(100) ;
    end
    if(sum(sum(bitMask>1))>0)
        break;
    end
    lastWsize=wSize-stepSize;
end

for hSize=lastPsize:stepSize:maskSize
    bitMask=zeros(maskSize,maskSize);
    for c=1:numCh
        [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),lastWsize,hSize);
        bitMask(x1:x2,y1:y2)=bitMask(x1:x2,y1:y2)+1;
    end
    if(plotFigs)
        figure(2)
        imagesc(bitMask);
        java.lang.Thread.sleep(100) ;
    end
    if(sum(sum(bitMask>1))>0)
        break;
    end
    lastHsize=hSize-stepSize;
end

toc

for c=1:numCh
    
     [x1,y1,x2,y2]=cord2mask(ChxList(c),ChyList(c),lastWsize,lastHsize,true);
     opt_2d_coords{c}=[x1,y1,x2-x1,y2-y1];
end

end


function [x1,y1,x2,y2]=cord2mask(x,y,wPixelSize,hPixelSize,returnRelative)
    
if(nargin<5)
    returnRelative=false;
end

    
bitMaskRes=1200;
adjBitMaskResW=bitMaskRes-wPixelSize;
adjBitMaskResH=bitMaskRes-hPixelSize;

x1=round(x*adjBitMaskResW)+1;
y1=round(y*adjBitMaskResH)+1;
x2=round(x*adjBitMaskResW+wPixelSize)-1;
y2=round(y*adjBitMaskResH+hPixelSize)-1;


if(returnRelative)
    x1=x1/bitMaskRes;
    y1=y1/bitMaskRes;
    x2=x2/bitMaskRes;
    y2=y2/bitMaskRes;
end


end

