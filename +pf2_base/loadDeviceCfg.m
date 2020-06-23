function probeInfo=loadDeviceCfg(deviceCfgFilename,buildProbeLayout,includeSSchannels)
% Builds a probeInfo struct from the device.cfg file
% use BuildProbeLayout to build a 2D representation for plotting
%   use includeSSchannels disable remove short separation channels from 2D
%   plot layouts and figures

if(nargin<1)
    deviceCfgFilename='';
end

if(nargin<2)
   buildProbeLayout=true; 
end

if(nargin<3)
    includeSSchannels=true;
end

pF2_folder=pf2_base.pf2_defaultRootPath();




if(nargin>0||isempty(deviceCfgFilename)) % If file name is specified, try to load it
    
    global setF
    
    [devCfg_folder,name,ext] = fileparts(deviceCfgFilename);
    
    saveOptLayout2=false;
    if(pf2_base.isnestedfield(setF,'device.Info.CfgName')&&(strcmpi(setF.device.Info.CfgName,name)))
        if(~isfield(setF.device.Probe{1},'OptLayout2D')&&buildProbeLayout)
            saveOptLayout2=true;
        else
            probeInfo=setF.device;
            return;
        end
    end
    
    
    fid = fopen(deviceCfgFilename);
    
    
    
    
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
        p=probeInfo.Probe{probeCount};
        
        tempChannels=unique(p.ChannelNumbers);
        p.ChannelList=tempChannels(tempChannels>0);
        p.NumOptodes=length(p.ChannelList);
        if(isfield(p,'DetPosX')&&isfield(p,'SrcPosX'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.SrcPosX=p.SrcPosX(p.sI);
                p.DetPosX=p.DetPosX(p.dI);
            end
            
            p.OptPosX=nanmean([p.DetPosX(:)';p.SrcPosX(:)'],1)';
        end
        
        if(isfield(p,'DetPosY')&&isfield(p,'SrcPosY'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.SrcPosY=p.SrcPosY(p.sI);
                p.DetPosY=p.DetPosY(p.dI);
            end
            p.OptPosY=nanmean([p.DetPosY(:)';p.SrcPosY(:)'],1)';
        end
        
        if(isfield(p,'DetPosZ')&&isfield(p,'SrcPosZ'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.SrcPosZ=p.SrcPosZ(p.sI);
                p.DetPosZ=p.DetPosZ(p.dI);
            end
            p.OptPosZ=nanmean([p.DetPosZ(:)';p.SrcPosZ(:)'],1)';
        end
        
        if(isfield(p,'OptPosX')&&isfield(p,'OptPosY'))
           if(isfield(p,'OptPosZ')) % Calculate 3D SD
               p.SD=sqrt((p.DetPosX-p.SrcPosX).^2+(p.DetPosY-p.SrcPosY).^2+(p.DetPosZ-p.SrcPosZ).^2);
           else % Calculate 2D SD
               p.SD=sqrt((p.DetPosX-p.SrcPosX).^2+(p.DetPosY-p.SrcPosY).^2);
           end
           
           p.IsShortSeparation=p.SD<2;
           p.NumShortSeparation=sum(p.IsShortSeparation);
        else
            error('Unable to determine source detector separation, please validate detector and source positions');
        end
        
        if(isfield(p,'DetPos3DX')&&isfield(p,'SrcPos3DX'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.SrcPos3DX=p.SrcPos3DX(p.sI);
                p.DetPos3DX=p.DetPos3DX(p.dI);
            end
            
            p.OptPos3DX=nanmean([p.DetPos3DX(:)';p.SrcPos3DX(:)'],1)';
        end
        
        if(isfield(p,'DetPos3DY')&&isfield(p,'SrcPos3DY'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.SrcPos3DY=p.SrcPos3DY(p.sI);
                p.DetPos3DY=p.DetPos3DY(p.dI);
            end
            
            p.OptPos3DY=nanmean([p.DetPos3DY(:)';p.SrcPos3DY(:)'],1)';
        end
        
        if(isfield(p,'DetPos3DZ')&&isfield(p,'SrcPos3DZ'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.SrcPos3DZ=p.SrcPos3DZ(p.sI);
                p.DetPos3DZ=p.DetPos3DZ(p.dI);
            end
            
            p.OptPos3DZ=nanmean([p.DetPos3DZ(:)';p.SrcPos3DZ(:)'],1)';
        end
        
        
        if(buildProbeLayout) % auto generate plot layour
            if(isfield(p,'OptPosX')&&isfield(p,'OptPosY')&&~isfield(p,'OptPosZ'))
                if(includeSSchannels)
                    p.OptLayout2D_ss=pf2_base.fitProbe2D(p.OptPosX,p.OptPosY);
                end
                p.OptLayout2D=pf2_base.fitProbe2D(p.OptPosX(~p.IsShortSeparation),p.OptPosY(~p.IsShortSeparation));
            end
            if(isfield(p,'OptPosX')&&isfield(p,'OptPosY')&&isfield(p,'OptPosZ'))
            if(includeSSchannels)
                p.OptLayout2D_ss=pf2_base.fitProbe2D(p.OptPosX,p.OptPosY,p.OptPosZ);
            end
            p.OptLayout2D=pf2_base.fitProbe2D(p.OptPosX(~p.IsShortSeparation),p.OptPosY(~p.IsShortSeparation),p.OptPosZ(~p.IsShortSeparation));
                
                
            else
                warning('buildProbeLayout option selected, but not enough information to generate Optode locations');
                p.OptLayout2D=setUpFalse2D(p.NumOptodes);  % generate false channels if not requested
            end
        else
            %p.OptLayout2D=setUpFalse2D(p.NumOptodes);  % generate false channels if not requested
        end
        
        if(saveOptLayout2&&isfield(p,'OptLayout2D'))
            setF.device.Probe{probeCount}=p;
        end
        probeInfo.Probe{probeCount}=p;
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
    
    opt_2d_coords{i}=[x1,y1,x2,y2];
end
end