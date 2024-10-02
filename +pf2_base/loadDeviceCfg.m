function probeInfo=loadDeviceCfg(deviceCfgFilename,includeSSchannels,loadFromGlobal)
% Builds a probeInfo struct from the device.cfg file 
%   (located in process fnirs 2 / devices folder)
% 
% use BuildProbeLayout to build a 2D representation for plotting
%   use includeSSchannels to disable removal of short separation channels from 2D
%   plot layouts and figures

% Set default values for input arguments
if nargin < 1
    deviceCfgFilename = '';
end
if nargin < 2
    includeSSchannels = true;
end

if(nargin<3)
    loadFromGlobal=true;
end

% Get the default root path
pF2_folder = pf2_base.pf2_defaultRootPath();

% Try to load the device configuration file
[probeInfo, name] = loadDeviceConfig(deviceCfgFilename, pF2_folder);

% Check if the probe is already in the global deviceTable
global deviceTable
global setF

if ~isempty(deviceTable) && any(strcmp(name, deviceTable.Probe)) && loadFromGlobal
    setF = deviceTable.ProbeInfo(strcmp(name, deviceTable.Probe));
    probeInfo = setF.device;
    return;
end

% Read the configuration file
probeInfo.cfg.read();
probeInfo.Info = probeInfo.cfg.Info;

probeCount=0;
for j=1:length(probeInfo.cfg.Sections)
	if(strfind(probeInfo.cfg.Sections{j},'Probe'))
        
    	probeCount=probeCount+1;
        probeInfo.Probe{probeCount}=get(probeInfo.cfg,probeInfo.cfg.Sections{j});
        p=probeInfo.Probe{probeCount};
        
        tempChannels=unique(p.ChannelNumbers);
        p.ChannelList=tempChannels(tempChannels>0);
        p.NumOptodes=length(p.ChannelList);
        
        p.TableOpt=table();
        p.TableOpt.OptodeNum=p.ChannelList(:);
        
        if(isfield(p,'ChannelLabels'))
            p.TableOpt.Label=p.ChannelLabels(:);
        end
        
        p.TableSD=table();
        p.TableCh=table(); % Map for raw probe data
        
        p.TableCh.ColNumber=[1:length(p.ChannelNumbers)]';
        p.TableCh.OptodeNumber=p.ChannelNumbers(:);
        p.TableCh.isTime=p.TableCh.OptodeNumber==0;
        p.TableCh.isMarker=p.TableCh.OptodeNumber<0|isnan(p.TableCh.OptodeNumber);
        p.TableCh.OptodeNumber(p.TableCh.OptodeNumber<1)=nan;
        
        validCols=~isnan(p.TableCh.OptodeNumber);
        
        p.TableCh.Wavelength=p.Wavelength(:);
        p.TableCh.SourceIndex(:)=nan;
        p.TableCh.DetectorIndex(:)=nan;
        p.TableCh.SourceIndex(validCols)=p.sI(p.TableCh.OptodeNumber(validCols));
        p.TableCh.DetectorIndex(validCols)=p.dI(p.TableCh.OptodeNumber(validCols));
        
        p.TableCh.isDark=(isnan(p.TableCh.Wavelength)|p.TableCh.Wavelength==0) &validCols;
        p.TableCh.isCh=validCols(:);
        
        p.TableCh.Label(:)="";
        
        for ch=1:length(p.ChannelNumbers)
            if(p.TableCh.isTime(ch))
               p.TableCh.Label(ch)="Time"; 
            elseif(p.TableCh.isMarker(ch))
                p.TableCh.Label(ch)="Mrk";
            elseif(p.TableCh.isDark(ch))
                opt=p.TableCh.OptodeNumber(ch);
                p.TableCh.Label(ch)=sprintf('Opt%i_dark',opt);
            else
                wv=p.TableCh.Wavelength(ch);
                opt=p.TableCh.OptodeNumber(ch);
                p.TableCh.Label(ch)=sprintf('Opt%i_wv%.1f',opt,wv);
            end
        end
        
        
        if(isfield(p,'SDLabels'))
            p.TableSD.Label=p.SDLabels(:);
        end
        
        if(~isfield(p,'DetPosX')&&~isfield(p,'SrcPosX')&&isfield(p,'DetPos3DX')&&isfield(p,'SrcPos3DX'))
           warning('No 2D position info available, plotting in 2D may not work');
           p.SrcPosX=p.SrcPos3DX/10;
           p.SrcPosY=p.SrcPos3DY/10;
           p.SrcPosZ=p.SrcPos3DZ/10;
           p.DetPosX=p.DetPos3DX/10;
           p.DetPosY=p.DetPos3DY/10;
           p.DetPosZ=p.DetPos3DZ/10;
        end
        
        if(isfield(p,'DetPosX')&&isfield(p,'SrcPosX'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                
                Type_temp=[ones(size(p.SrcPosX(:)));ones(size(p.DetPosX(:)))*2];
                
                typeStr_temp={'Src','Det'};
                
                catType_temp=categorical(typeStr_temp(Type_temp(:)),typeStr_temp);
                p.TableSD.Type=catType_temp(:);
                
                
                
                p.TableSD.Index=[(1:length(p.SrcPosX(:)))';(1:length(p.DetPosX(:)))'];
                
                
                if(~ismember('Label',p.TableSD.Properties.VariableNames))
                    for sd=1:length(p.TableSD.Index)
                        typeLabel=sprintf('%s',p.TableSD.Type(sd));
                        p.TableSD.Label{sd}=sprintf('%s%i',typeLabel(1),p.TableSD.Index(sd));
                    end
                end
                
                p.TableSD.Pos2D_x=[p.SrcPosX(:);p.DetPosX(:)];
                
                p.SrcPosX=p.SrcPosX(p.sI);
                p.DetPosX=p.DetPosX(p.dI);
                
                p.TableOpt.SrcIdx=p.sI(:);
                p.TableOpt.DetIdx=p.dI(:);
            end
            
            p.OptPosX=nanmean([p.DetPosX(:)';p.SrcPosX(:)'],1)';
            
            p.TableOpt.Pos2D_x=p.OptPosX;
        end
        
        if(isfield(p,'DetPosY')&&isfield(p,'SrcPosY'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                 p.TableSD.Pos2D_y=[p.SrcPosY(:);p.DetPosY(:)];
                
                p.SrcPosY=p.SrcPosY(p.sI);
                p.DetPosY=p.DetPosY(p.dI);
            end
            p.OptPosY=nanmean([p.DetPosY(:)';p.SrcPosY(:)'],1)';
            p.TableOpt.Pos2D_y=p.OptPosY;
        end
        
        if(isfield(p,'DetPosZ')&&isfield(p,'SrcPosZ'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.TableSD.Pos2D_z=[p.SrcPosZ(:);p.DetPosZ(:)];
                p.SrcPosZ=p.SrcPosZ(p.sI);
                p.DetPosZ=p.DetPosZ(p.dI);
            end
            p.OptPosZ=nanmean([p.DetPosZ(:)';p.SrcPosZ(:)'],1)';
            p.TableOpt.Pos2D_z=p.OptPosZ;
        end
        
        
        
        if(isfield(p,'OptPosX')&&isfield(p,'OptPosY'))
           if(isfield(p,'OptPosZ')) % Calculate 3D SD
               p.SD=sqrt((p.DetPosX-p.SrcPosX).^2+(p.DetPosY-p.SrcPosY).^2+(p.DetPosZ-p.SrcPosZ).^2);
               p.TableOpt.SD=p.SD(:);
           else % Calculate 2D SD
               p.SD=sqrt((p.DetPosX-p.SrcPosX).^2+(p.DetPosY-p.SrcPosY).^2);
               p.TableOpt.SD=p.SD(:);
           end
           
           p.IsShortSeparation=p.SD<2;
           p.TableOpt.IsShortSeparation=p.IsShortSeparation(:);
           p.NumShortSeparation=sum(p.IsShortSeparation);
        else
            error('Unable to determine source detector separation, please validate detector and source positions');
        end
        
%          p.SrcPos3DX=p.SrcPos3DX*1.3;
%          p.SrcPos3DY=p.SrcPos3DY*1.2;
%          p.SrcPos3DZ=p.SrcPos3DZ*1.2;
%          p.DetPos3DX=p.DetPos3DX*1.3;
%          p.DetPos3DY=p.DetPos3DY*1.2;
%          p.DetPos3DZ=p.DetPos3DZ*1.2;
%         
        
        if(isfield(p,'DetPos3DX')&&isfield(p,'SrcPos3DX'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.TableSD.Pos3D_x=[p.SrcPos3DX(:);p.DetPos3DX(:)];
                p.SrcPos3DX=p.SrcPos3DX(p.sI);
                p.DetPos3DX=p.DetPos3DX(p.dI);
            end
            
            if(~isfield(p,'OptPos3DX'))
                p.OptPos3DX=nanmean([p.DetPos3DX(:)';p.SrcPos3DX(:)'],1)';
            end
            p.TableOpt.Pos3D_x=p.OptPos3DX(:);
        elseif(isfield(p,'OptPos3DX'))
            
            p.TableOpt.Pos3D_x=p.OptPos3DX(:);
        end
        
        if(isfield(p,'DetPos3DY')&&isfield(p,'SrcPos3DY'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.TableSD.Pos3D_y=[p.SrcPos3DY(:);p.DetPos3DY(:)];
                p.SrcPos3DY=p.SrcPos3DY(p.sI);
                p.DetPos3DY=p.DetPos3DY(p.dI);
            end
            
            if(~isfield(p,'OptPos3DY'))
                p.OptPos3DY=nanmean([p.DetPos3DY(:)';p.SrcPos3DY(:)'],1)';
            end
            p.TableOpt.Pos3D_y=p.OptPos3DY(:);
        elseif(isfield(p,'OptPos3DY'))
            p.TableOpt.Pos3D_y=p.OptPos3DY(:);
        end
        
        if(isfield(p,'DetPos3DZ')&&isfield(p,'SrcPos3DZ'))
            if(isfield(p,'dI')&&isfield(p,'sI'))
                p.TableSD.Pos3D_z=[p.SrcPos3DZ(:);p.DetPos3DZ(:)];
                p.SrcPos3DZ=p.SrcPos3DZ(p.sI);
                p.DetPos3DZ=p.DetPos3DZ(p.dI);
            end
            
            if(~isfield(p,'OptPos3DZ'))
                p.OptPos3DZ=nanmean([p.DetPos3DZ(:)';p.SrcPos3DZ(:)'],1)';
            end
            p.TableOpt.Pos3D_z=p.OptPos3DZ(:);
        elseif(isfield(p,'OptPos3DZ'))
            p.TableOpt.Pos3D_z=p.OptPos3DZ(:);
        end
        
        
        if(true)%buildProbeLayout) % auto generate plot layour
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
        
        hasLabel=ismember('Label',p.TableOpt.Properties.VariableNames);
        
        xyzPresent=ismember({'Pos3D_x','Pos3D_y','Pos3D_z'},p.TableOpt.Properties.VariableNames);
        xyzPresentSD=ismember({'Pos3D_x','Pos3D_y','Pos3D_z'},p.TableSD.Properties.VariableNames);
        xyzSD=[];
        
        if(all(xyzPresent))
            xyz=[p.TableOpt.Pos3D_x,p.TableOpt.Pos3D_y,p.TableOpt.Pos3D_z];
            
            if(all(xyzPresentSD))
                xyzSD=[p.TableSD.Pos3D_x,p.TableSD.Pos3D_y,p.TableSD.Pos3D_z];
            end
        elseif(sum(xyzPresent)==2)
            xyzStrs={'Pos3D_x','Pos3D_y','Pos3D_z'};
            xyzPresent=find(xyzPresent);
            xyz=[p.TableOpt.(xyzStrs{xyzPresent(1)}),p.TableOpt.(xyzStrs{xyzPresent(2)}),zeros(length(p.ChannelList),1)];
            xyzSD=[p.TableSD.(xyzStrs{xyzPresent(1)}),p.TableSD.(xyzStrs{xyzPresent(2)}),zeros(length(p.ChannelList),1)];
            if(any(xyzPresentSD))
                xyzSD=[p.TableSD.Pos3D_x,p.TableSD.Pos3D_y,p.TableSD.Pos3D_z];
            end
        elseif(sum(xyzPresent)==1)
            xyzStrs={'Pos3D_x','Pos3D_y','Pos3D_z'};
            xyzPresent=find(xyzPresent);
            xyz=[p.TableOpt.(xyzStrs{xyzPresent(1)}),zeros(length(p.ChannelList),2)];
            xyzSD=[p.TableSD.(xyzStrs{xyzPresent(1)}),zeros(length(p.ChannelList),2)];
            if(any(xyzPresentSD))
                xyzSD=[p.TableSD.Pos3D_x,p.TableSD.Pos3D_y,p.TableSD.Pos3D_z];
            end
        else
            xyz=[(1:length(p.ChannelList))',zeros(length(p.ChannelList),2)];
            xyz=xyz*30; %Default spacing 30mm
            xyzSD=[]; %Don't know what to do for this
        end
            
        l1=size(xyz,1);
        l2=size(xyzSD,1);
        plane2D=affine_fit([xyz;xyzSD]);
        
        plane2D_opt=plane2D(1:l1,:);
        plane2D_sd=plane2D(end-l2+1:1:end,:);
        
        zeroCoordIndex=sum(round(abs(plane2D)),1)==0;
        
         p.TableOpt.proj2D=plane2D_opt(:,zeroCoordIndex);
         
         if(~isempty(plane2D_sd))
            p.TableSD.proj2D=plane2D_sd(:,zeroCoordIndex);
         end
         
        for c=1:length(p.ChannelList)
            chIdxMatch=(find(p.ChannelNumbers==p.ChannelList(c)));
            p.TableOpt.Ch(c,1:length(chIdxMatch))=chIdxMatch;
            p.TableOpt.wv(c,1:length(chIdxMatch))=p.Wavelength(chIdxMatch);
            if(~hasLabel)
               p.TableOpt.Label{c}=sprintf('Opt%i', p.ChannelList(c));
            end
        end
        
        p.OptPos3D_mean=nanmean(xyz,1);
            
        p.SrcPos=table();
        p.SrcPos.x_2d=p.SrcPosX(:);
        p.SrcPos.y_2d=p.SrcPosY(:);
        p.SrcPos.z_2d=p.SrcPosZ(:);
        p.SrcPos.x=p.SrcPos3DX(:);
        p.SrcPos.y=p.SrcPos3DY(:);
        p.SrcPos.z=p.SrcPos3DZ(:);
        
        
        p.DetPos=table();
        p.DetPos.x_2d=p.DetPosX(:);
        p.DetPos.y_2d=p.DetPosY(:);
        p.DetPos.z_2d=p.DetPosZ(:);
        p.DetPos.x=p.DetPos3DX(:);
        p.DetPos.y=p.DetPos3DY(:);
        p.DetPos.z=p.DetPos3DZ(:);
        
        p.OptPos=table();
        p.OptPos.x_2d=p.OptPosX(:);
        p.OptPos.y_2d=p.OptPosY(:);
        p.OptPos.z_2d=p.OptPosZ(:);
        p.OptPos.x=p.OptPos3DX(:);
        p.OptPos.y=p.OptPos3DY(:);
        p.OptPos.z=p.OptPos3DZ(:);
        
        p.OptPos.subplot_layout(:)=cell(size(p.OptPos.z));
        p.OptPos.subplot_layout(~p.IsShortSeparation)=p.OptLayout2D(:);
        if(includeSSchannels)
            p.OptPos.subplot_layout_ss=p.OptLayout2D_ss(:);
        else
           p.OptPos.subplot_layout_ss= p.OptPos.subplot_layout;
        end
        
        
        fieldsToRemove={'SrcPosX','SrcPosY','SrcPosZ','SrcPos3DX','SrcPos3DY','SrcPos3DZ' ...
            'DetPosX','DetPosY','DetPosZ','DetPos3DX','DetPos3DY','DetPos3DZ'...
            'OptPosX','OptPosY','OptPosZ','OptPos3DX','OptPos3DY','OptPos3DZ'...
            'sI','dI','ChannelList','SD','IsShortSeparation','OptLayout2D','Wavelength','ChannelNumbers','OptPos3D_mean'};
        
        p=rmfield(p,fieldsToRemove);
        
        if(includeSSchannels)
            p=rmfield(p,'OptLayout2D_ss');
        end
        
     
        
        %if(saveOptLayout2&&isfield(p,'OptLayout2D'))
            setF.device.Probe{probeCount}=p;
        %end
        probeInfo.Probe{probeCount}=p;
    end
    
end

if(nargout==0) % assigns the global device
    global setF
    global deviceTable
    if(isempty(deviceTable))
        deviceTable = cell2table(cell(0, 2), 'VariableNames', {'Probe', 'ProbeInfo'});
    end
    container = {};
    container.device = probeInfo;
    deviceTable = [deviceTable; {name, container}];
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

function [proj2d,n,V,p] = affine_fit(XYZ)
    %Computes the plane that fits best (lest square of the normal distance
    %to the plane) a set of sample points.
    %INPUTS:
    %
    %X: a N by 3 matrix where each line is a sample point
    %
    %OUTPUTS:
    %
    %n : a unit (column) vector normal to the plane
    %V : a 3 by 2 matrix. The columns of V form an orthonormal basis of the
    %plane
    %p : a point belonging to the plane
    %
    %NB: this code actually works in any dimension (2,3,4,...)
    %Author: Adrien Leygue
    %Date: August 30 2013
    
    %the mean of the samples belongs to the plane
    p = mean(XYZ,1);
    
    %The samples are reduced:
    R = bsxfun(@minus,XYZ,p);
    %Computation of the principal directions if the samples cloud
    [V,D] = eig(R'*R);
    %Extract the output from the eigenvectors
    n = V(:,1);
    V = V(:,2:end);
    
    proj2d=project(XYZ,n,V,p);
end

function proj2d=project(XYZ,n,V,p)

    XYZ_p=XYZ-p; %move points onto plane
    
    A=[1 0 0 -n(1); 0 1 0 -n(2); 0 0 1 -n(3); n' 0];
    
    B=(A\[XYZ_p';zeros(size(XYZ(:,1)'))])';
    
    r=pf2_base.external.vrrotvec([0,0,1],n);
    RM=pf2_base.external.vrrotvec2mat(r);
    
    proj2d=B(:,1:3)*RM;
   

end



function [probeInfo, name] = loadDeviceConfig(deviceCfgFilename, pF2_folder)
    if isempty(deviceCfgFilename)
        [file, pathname] = uigetfile({'*.cfg;*.ini', 'Configuration Files (*.cfg, *.ini)'; ...
                                      '*.*', 'All Files (*.*)'}, ...
                                     'Select Device Configuration File', ...
                                     fullfile(pF2_folder, 'devices'));
        if isequal(file, 0)
            error('User cancelled file selection');
        end
        deviceCfgFilename = fullfile(pathname, file);
    end

    [~, name, ~] = fileparts(deviceCfgFilename);

    % Try to open the file
    if ~exist(deviceCfgFilename, 'file')
        % If not found, try in the devices folder
        altPath = fullfile(pF2_folder, 'devices', deviceCfgFilename);
        if exist(altPath, 'file')
            deviceCfgFilename = altPath;
        else
            error('Configuration file not found: %s', deviceCfgFilename);
        end
    end

    % Load the configuration file
    try
        probeInfo.cfg = pf2_base.external.INI('File', deviceCfgFilename);
    catch ME
        error('Error loading configuration file: %s', ME.message);
    end
end

