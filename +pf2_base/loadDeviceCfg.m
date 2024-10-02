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

forceLoad = isempty(deviceCfgFilename)>0;

if ~forceLoad&&~isempty(deviceTable) && any(strcmp(name, deviceTable.Probe)) && loadFromGlobal
    global setF
    setF = deviceTable.ProbeInfo(strcmp(name, deviceTable.Probe));
    probeInfo = setF.device;
    return;
end

% Read the configuration file
probeInfo.cfg.read();
probeInfo.Info = probeInfo.cfg.Info;

probeInfo = processProbeInfo(probeInfo, includeSSchannels);
    


if(nargout==0) % assigns the global device
    global setF
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
    elseif(~contains(lower(deviceCfgFilename),'.cfg'))
        deviceCfgFilename=strcat(deviceCfgFilename,'.cfg');
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

function probeInfo = processProbeInfo(probeInfo, includeSSchannels)
    probeCount = 0;
    for j = 1:length(probeInfo.cfg.Sections)
        sectionName = probeInfo.cfg.Sections{j};
        if contains(sectionName, 'Probe')
            probeCount = probeCount + 1;
            p = get(probeInfo.cfg, sectionName);
            p = initializeProbeStructure(p);
            p = processChannelInfo(p);
            p = processPositionInfo(p);
            p = calculateSourceDetectorSeparation(p);
            p = generateProbeLayout(p, includeSSchannels);

            p = sortOptodes(p); % and drop any in DropOptodes
 
            fieldsToRemove={'SrcPosX','SrcPosY','SrcPosZ','SrcPos3DX','SrcPos3DY','SrcPos3DZ' ...
                'DetPosX','DetPosY','DetPosZ','DetPos3DX','DetPos3DY','DetPos3DZ'...
                'OptPosX','OptPosY','OptPosZ','OptPos3DX','OptPos3DY','OptPos3DZ'...
                'sI','dI','ChannelList','SD','IsShortSeparation','OptLayout2D','Wavelength','ChannelNumbers','OptPos3D_mean'};
    
            p=rmfield(p,fieldsToRemove);
    
            if(includeSSchannels)
                p=rmfield(p,'OptLayout2D_ss');
            end
    
            probeInfo.Probe{probeCount} = p;
        end
    end
end

function p = initializeProbeStructure(p)
    tempChannels = unique(p.ChannelNumbers);
      if(~isfield(p,'ChannelList'))
            p.ChannelList=tempChannels(tempChannels>0);
        elseif(length(tempChannels(tempChannels>0))~=length(p.ChannelList))
            error('Manually defined channel list different number of channels than found in Channel Numbers list');
      end
    p.NumOptodes = length(p.ChannelList);
    p.TableOpt = table('Size', [p.NumOptodes, 1], 'VariableTypes', {'double'}, 'VariableNames', {'OptodeNum'});
    p.TableOpt.OptodeNum = p.ChannelList(:);
    if isfield(p, 'ChannelLabels')
        p.TableOpt.Label = p.ChannelLabels;
    end
    p.TableSD = table();
    p.TableCh = table();
end

function p = processChannelInfo(p)
    p.TableCh.ColNumber = (1:length(p.ChannelNumbers))';
    p.TableCh.OptodeNumber = p.ChannelNumbers(:);
    p.TableCh.isTime = p.TableCh.OptodeNumber == 0;
    if(nansum(p.TableCh.isTime)>1)
       warning('More than one time column specified, please set only one channel to be # 0. Using first ch 0 column');
       firstIdx=find(p.TableCh.isTime);
       p.TableCh.isTime(firstIdx+1:end)=false;
    end
    p.TableCh.isMarker = p.TableCh.OptodeNumber < 0 | isnan(p.TableCh.OptodeNumber);
    p.TableCh.OptodeNumber(p.TableCh.OptodeNumber < 1) = nan;
    
    validCols = ~isnan(p.TableCh.OptodeNumber);
    
    channelIdx = p.TableCh.OptodeNumber(validCols);
    
    if(min(channelIdx)>1 || max(channelIdx)>length(p.ChannelList))
        if(~isequal(unique(channelIdx),unique(p.ChannelList)))
             warning('Assuming source and detector indicies are sorted accoring to their ordinal appearance');
             channelMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
                for i = 1:length(p.ChannelList)
                    channelMap(p.ChannelList(i)) = i;
                end
                
                % Map each value in channelIdx to its index in channelList
                mappedIndices = zeros(size(channelIdx));
                for i = 1:length(channelIdx)
                    if isKey(channelMap, channelIdx(i))
                        mappedIndices(i) = channelMap(channelIdx(i));
                    else
                        error('Channel %d not found in channelList', channelIdx(i));
                    end
                end

                channelIdx=mappedIndices;
        end
    end
    
    p.TableCh.Wavelength = p.Wavelength(:);
    p.TableCh.SourceIndex = nan(size(p.TableCh.OptodeNumber));
    p.TableCh.DetectorIndex = nan(size(p.TableCh.OptodeNumber));
    p.TableCh.SourceIndex(validCols) = p.sI(channelIdx);
    p.TableCh.DetectorIndex(validCols) = p.dI(channelIdx);
    
    p.TableCh.isDark = (isnan(p.TableCh.Wavelength) | p.TableCh.Wavelength == 0) & validCols;
    p.TableCh.isCh = validCols(:);
    
    p.TableCh.Label = repmat("", size(p.TableCh.OptodeNumber));
    
    p = assignChannelLabels(p);
end

function p = assignChannelLabels(p)
    for ch = 1:length(p.ChannelNumbers)
        if p.TableCh.isTime(ch)
            p.TableCh.Label(ch) = "Time";
        elseif p.TableCh.isMarker(ch)
            p.TableCh.Label(ch) = "Mrk";
        elseif p.TableCh.isDark(ch)
            opt = p.TableCh.OptodeNumber(ch);
            p.TableCh.Label(ch) = sprintf('Opt%i_dark', opt);
        else
            wv = p.TableCh.Wavelength(ch);
            opt = p.TableCh.OptodeNumber(ch);
            p.TableCh.Label(ch) = sprintf('Opt%i_wv%.1f', opt, wv);
        end
    end
end

function p = processPositionInfo(p)
    % If no 2D info, use 3D
    if ~isfield(p, 'DetPosX') && ~isfield(p, 'SrcPosX') && isfield(p, 'DetPos3DX') && isfield(p, 'SrcPos3DX')
        warning('No 2D position info available, plotting in 2D may not work');
        p.SrcPosX = p.SrcPos3DX / 10;
        p.SrcPosY = p.SrcPos3DY / 10;
        p.SrcPosZ = p.SrcPos3DZ / 10;
        p.DetPosX = p.DetPos3DX / 10;
        p.DetPosY = p.DetPos3DY / 10;
        p.DetPosZ = p.DetPos3DZ / 10;
    end

    hasX= isfield(p, 'DetPosX') && isfield(p, 'SrcPosX');
    hasY = isfield(p, 'DetPosY') && isfield(p, 'SrcPosY');
    hasZ = isfield(p, 'DetPosZ') && isfield(p, 'SrcPosZ');
    xyz=(hasX+hasY+hasZ);

    if(xyz<1)
       error('No position information provided for device');
    end

    if(xyz==1)
        warning('Only one dimension provided, other dimensons will be zeromapped');
    end
    
    if(hasX)
        nDet= length(p.DetPosX);
        nSrc = length(p.SrcPosX);
    elseif(hasY)
        nDet= length(p.DetPosY);
        nSrc = length(p.SrcPosY);
    else
        nDet= length(p.DetPosZ);
        nSrc = length(p.SrcPosZ);
    end

    if(~hasX)
        p.DetPosX=zeros([1,nDet]);
        p.SrcPosX=zeros([1,nSrc]);
    end

    if(~hasY)
        p.DetPosY=zeros([1,nDet]);
        p.SrcPosY=zeros([1,nSrc]);
    end

    if(~hasZ)
        p.DetPosZ=zeros([1,nDet]);
        p.SrcPosZ=zeros([1,nSrc]);
    end


    if isfield(p, 'DetPosX') && isfield(p, 'SrcPosX')
        return;
    else
        error('No position info is available');
    end
end

function p=calculateSourceDetectorSeparation(p)

    useIdx = isfield(p,'dI')&&isfield(p,'sI');    
    has3D = isfield(p,'DetPos3DX')&&isfield(p,'SrcPos3DX') ...
        &&isfield(p,'DetPos3DY')&&isfield(p,'SrcPos3DY')...
        &&isfield(p,'DetPos3DZ')&&isfield(p,'SrcPos3DZ');
        
    if(isfield(p,'SDLabels'))
        p.TableSD.Label=p.SDLabels(:);
    end
    
        
    if(useIdx)
        % Assign src/det types
        Type_temp=[ones(size(p.SrcPosX(:)));ones(size(p.DetPosX(:)))*2];
                
        typeStr_temp={'Src','Det'};
        
        catType_temp=categorical(typeStr_temp(Type_temp(:)),typeStr_temp);
        p.TableSD.Type=catType_temp(:);
        
        
        
        p.TableSD.Index=[(1:length(p.SrcPosX(:)))';(1:length(p.DetPosX(:)))'];
        
        %Assign labels
        if(~ismember('Label',p.TableSD.Properties.VariableNames))
            for sd=1:length(p.TableSD.Index)
                typeLabel=sprintf('%s',p.TableSD.Type(sd));
                p.TableSD.Label{sd}=sprintf('%s%i',typeLabel(1),p.TableSD.Index(sd));
            end
        end

        %Assign source/detector idx
        p.TableOpt.SrcIdx=p.sI(:);
        p.TableOpt.DetIdx=p.dI(:);

        % Fill in 2D X positions
        p.TableSD.Pos2D_x=[p.SrcPosX(:);p.DetPosX(:)];
        
        p.SrcPosX=p.SrcPosX(p.sI);
        p.DetPosX=p.DetPosX(p.dI);
        
        % Fill in 2D Y positions
        p.TableSD.Pos2D_y=[p.SrcPosY(:);p.DetPosY(:)];
                
        p.SrcPosY=p.SrcPosY(p.sI);
        p.DetPosY=p.DetPosY(p.dI);

        % Fill in 2D Z positions
        p.TableSD.Pos2D_z=[p.SrcPosZ(:);p.DetPosZ(:)];
        p.SrcPosZ=p.SrcPosZ(p.sI);
        p.DetPosZ=p.DetPosZ(p.dI);

        if(has3D)
            p.TableSD.Pos3D_x=[p.SrcPos3DX(:);p.DetPos3DX(:)];
            p.SrcPos3DX=p.SrcPos3DX(p.sI);
            p.DetPos3DX=p.DetPos3DX(p.dI);
            
            p.TableSD.Pos3D_y=[p.SrcPos3DY(:);p.DetPos3DY(:)];
            p.SrcPos3DY=p.SrcPos3DY(p.sI);
            p.DetPos3DY=p.DetPos3DY(p.dI);
            
            p.TableSD.Pos3D_z=[p.SrcPos3DZ(:);p.DetPos3DZ(:)];
            p.SrcPos3DZ=p.SrcPos3DZ(p.sI);
            p.DetPos3DZ=p.DetPos3DZ(p.dI);
        end

    end

    % Should have 2d position info
    p.OptPosX=nanmean([p.DetPosX(:)';p.SrcPosX(:)'],1)';
    p.TableOpt.Pos2D_x=p.OptPosX;

    p.OptPosY=nanmean([p.DetPosY(:)';p.SrcPosY(:)'],1)';
    p.TableOpt.Pos2D_y=p.OptPosY;

    p.OptPosZ=nanmean([p.DetPosZ(:)';p.SrcPosZ(:)'],1)';
    p.TableOpt.Pos2D_z=p.OptPosZ;

    if(has3D) % prefer over 2D for position + SD calculation
        % Allow these to be manually defined if they already exist
        if(~(isfield(p,'OptPos3DX')&&isfield(p,'OptPos3DY')&&isfield(p,'OptPos3DZ')))
            p.OptPos3DX=nanmean([p.DetPos3DX(:)';p.SrcPos3DX(:)'],1)';
            p.OptPos3DY=nanmean([p.DetPos3DY(:)';p.SrcPos3DY(:)'],1)';
            p.OptPos3DZ=nanmean([p.DetPos3DZ(:)';p.SrcPos3DZ(:)'],1)';
        end
        p.TableOpt.Pos3D_x=p.OptPos3DX(:);
        p.TableOpt.Pos3D_y=p.OptPos3DY(:);
        p.TableOpt.Pos3D_z=p.OptPos3DZ(:);
    end
        
    % Use 2D values here for simplicity and consistency (may want to update
    % if using 3D digitized values per participant)
   p.SD=sqrt((p.DetPosX-p.SrcPosX).^2+(p.DetPosY-p.SrcPosY).^2+(p.DetPosZ-p.SrcPosZ).^2);
   p.TableOpt.SD=p.SD(:);
          
           
   p.IsShortSeparation=p.SD<2;
   p.TableOpt.IsShortSeparation=p.IsShortSeparation(:);
   p.NumShortSeparation=sum(p.IsShortSeparation);
end

function  p=generateProbeLayout(p,includeSSchannels)
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
    
   
end

function p = sortOptodes(p)

    [uOpt,b,c]= unique(p.ChannelList);

    numCh=length(uOpt);

    if(isfield(p,'DropOptodes'))
        opt2Drop=ismember(uOpt,p.DropOptodes);
        uOpt=uOpt(~opt2Drop);
        b=b(~opt2Drop);

    end

    if(isequal(uOpt,p.ChannelList))
        return
    end

    

    fieldsToSort = {'DetPosX','DetPosY','DetPosZ','SrcPosX','SrcPosY','SrcPosZ'...
            'DetPos3DX','DetPos3DY','DetPos3DZ','SrcPos3DX','SrcPos3DY','SrcPos3DZ', 'sI','dI'...
            'ChannelList','OptPosX','OptPosY','OptPosZ','OptPos3DX','OptPos3DY','OptPos3DZ','SD','IsShortSeparation'...
            'OptLayout2D_ss','OptLayout2D','SrcPos','DetPos','OptPos','TableOpt'};

    for f=1:length(fieldsToSort)
        if(isfield(p,fieldsToSort{f}))
            if(istable(p.(fieldsToSort{f})))
                p.(fieldsToSort{f})=p.(fieldsToSort{f})(b,:);
            else
    
                nD=find(size(p.(fieldsToSort{f}))==numCh);
                if(nD==1)
                    p.(fieldsToSort{f})=p.(fieldsToSort{f})(b);
                elseif(nD==2)
                    p.(fieldsToSort{f})=p.(fieldsToSort{f})(:,b);
                end
            end
        end
    end

    p.TableOpt = sortrows(p.TableOpt,'OptodeNum');

    p.NumOptodes = height(p.TableOpt);

end




