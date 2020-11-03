function [ h, imgOut ] = InterpolateValues3D(varargin)

%pf2.Data.Plot.InterpolatValues3D
%
% Uses an imagemap to change the color of each cell based on data2plot
% fNIR is a data structure that contains the fNIRS structure info, 
% data2plot houses the numbers themselves
%
% Short separation channels are not presented here and are skipped
%
tic
validAxesHandle= @(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x);
validScalarPosNumOr0 = @(x) isnumeric(x) && x>=0;
validScalarPosNum = @(x) isnumeric(x) && x>0;
validScalarPosNumOrNan = @(x) isnumeric(x) && (x>0||isnan(x));
validI1020Label = @(x) islogical(x) || iscellstr(x);
validBrodmann = @(x) islogical(x) || isnumeric(x)&&all(x<=55)&&all(x>0);
validColor = @(x) (ischar(x) && length(x) == 1) || isnumeric(x) && length(x) == 3 || isempty(x);
validFnirs = @(x) (iscell(x) || isstruct(x));
%validColorList = @(x) validColor(x) || all(arrayfun(validColor, x));

defaultInterpolateType = 'nearest';
validInterpolateTypes = {'nearest', 'linear', 'quadratic', 'cubic'};
validInterpolateType = @(x) any(validatestring(x, validInterpolateTypes));

defaultCamPosition = 'auto';
validCamPositions = {'auto','front', 'back', 'top' 'left', 'right','face'};
validCamPosition = @(x) any(validatestring(x, validCamPositions)) || isnumeric(x) && length(x) == 3;

defaultColormap = 'hot';
defaultColormapLow = 'cool';
validColormapLabels = {'hot', 'autumn', 'jet', 'gray', 'copper', 'bone', 'cool', 'winter', 'pink'};
validColormap = @(x) isa(x,'function_handle') || any(ishandle(x)) || any(validatestring(x, validColormapLabels));

if(numel(varargin) > 0 && isa(varargin{1},'matlab.graphics.axis.Axes')) %If first argument is axes then move to front
   ax=varargin{1};
   varargin=varargin(2:end);
else
    curFig=gcf;
    if(~curFig.Visible)
       figure(); 
    end
   ax=gca;
end





p=inputParser;

addOptional(p,'data2plot', []);
addOptional(p,'fNIR', {}, validFnirs);
addOptional(p,'minval', [], @isnumeric);
addOptional(p,'maxval', [], @isnumeric);
addOptional(p,'titleString', '', @isstring);
addOptional(p,'colorbarStr', '', @isstring);

addParameter(p,'ax',ax,validAxesHandle,'PartialMatchPriority',1);
addParameter(p,'ChannelLabels',true,@islogical);
addParameter(p,'SDLabels',true,@islogical);
addParameter(p,'I1020_labels',false,validI1020Label);
addParameter(p, 'useHighRes', true, @islogical);
addParameter(p, 'cmap', defaultColormap, validColormap);
addParameter(p, 'cmap_lower', defaultColormapLow, validColormap);
addParameter(p, 'labelfontsize', 10, validScalarPosNum);
addParameter(p, 'labelfontcolor', 'k', validColor);
addParameter(p, 'labelspherecolors', ["r", "y","w"]);
addParameter(p, 'brainColor', [0.92, 0.68, 0.68], validColor);
addParameter(p, 'voxelColor', [1, 1, 1], validColor);
addParameter(p, 'brainAlpha', 1, validScalarPosNumOr0);
addParameter(p, 'brainLineColor', [], validColor);
addParameter(p, 'backgroundColor', [], validColor);
addParameter(p, 'showColorbar', true, @islogical);
addParameter(p, 'initCamPosition', defaultCamPosition, validCamPosition);
addParameter(p, 'logScale', false, @islogical);
addParameter(p, 'interpolateType', defaultInterpolateType, validInterpolateType);
addParameter(p, 'bufferDistance', nan, validScalarPosNumOrNan); %In a grid, this may equal to sqrt(sd distance^2/2)
addParameter(p, 'includeSS', true, @islogical);
addParameter(p, 'showReference', false, @islogical);
addParameter(p, 'showScattering', false, @islogical);
addParameter(p, 'scatteringFactor', 1, validScalarPosNumOrNan);
addParameter(p, 'useEEG', false, @islogical);
addParameter(p, 'optodeLines', false, @islogical);
addParameter(p, 'useProjectedOptodeLocations', false,@islogical);
addParameter(p, 'useTalairach', false, @islogical); % Otherwise will default to MNI
addParameter(p, 'BrodmannAreas', false, validBrodmann); % Colors in Brodmann areas
addParameter(p, 'BA_cmp', @lines, validColormap); % Colors in Brodmann areas
addParameter(p, 'useVoxelBrodmannAreas', false, @islogical); % Colors in Brodmann areas
addParameter(p, 'showVoxelBrain', false, @islogical); % Colors in Brodmann areas
centerCamPos=[0,-20,0];
addParameter(p, 'camTarget', centerCamPos, validCamPosition); % Colors in Brodmann areas
addParameter(p, 'animated', false, @islogical); % Optimizes for animation (By not redrawing certain things when possible)



parse(p,varargin{:});



data2plot = p.Results.data2plot;
multiprobe = iscell(data2plot);


if(~multiprobe&&isnumeric(data2plot))
   data2plot={data2plot};
end

numProbes=length(data2plot);

for i=1:numProbes
   dataEmpty(i)=isempty(data2plot{i}); 
end

if(multiprobe && ~all(dataEmpty))
    data2plot_cell = data2plot;
    concat_data = [];
    for i=1:numel(data2plot)
        concat_data = [concat_data, data2plot{i}];
    end
    data2plot_concat = concat_data;
else
    data2plot_concat=data2plot{1};
end

if(isempty(p.Results.fNIR) && ~p.Results.useEEG)
    global setF;
    fNIR = {};
    if(multiprobe)
        error("Must specify FNIRS devices when using Multi-probe plotting")
    end
else
    fNIR = p.Results.fNIR;
end

if(iscell(fNIR)&&all(dataEmpty))
    if(length(fNIR)>1)
       multiprobe=true;
       dataEmpty=true(size(fNIR));
    end
end

animationOptimized=p.Results.animated;

cbarUpper_minmax=[nan,nan];
cbarLower_minmax=[nan,nan];

minVal = p.Results.minval;
maxVal = p.Results.maxval;

negColorbar=false; % Enabled when only negative color bar is present and min>max


if(isempty(p.Results.minval))
    minVal = nanmin(data2plot_concat);
end

if(length(minVal)==2)
    twosided = true;
    minVal=sort(minVal);
else
    twosided = false;
end

if(length(maxVal)==2)
    twosided=true;
    maxVal=sort(maxVal);
elseif(length(maxVal)==1)
    if(~twosided&&minVal>maxVal)
        negColorbar=true; 
    end
end

if(isempty(maxVal)) % No max value specified
    if(~twosided)
        %[X,X] [Min1, Datamax]
        maxVal=nanmax(data2plot_concat);
        cbarUpper_minmax=[minVal maxVal];
    else
        %[DataMin, Min2] [Min1, Datamax] or DataMin-1e-3, DataMax+1e-3
        dataMaxVal=max(max(minVal)+1e-3,nanmax(data2plot_concat));
        cbarUpper_minmax=[max(minVal) dataMaxVal];
        dataMinVal=min(min(minVal)-1e-3,nanmin(data2plot_concat));
        cbarLower_minmax=[dataMinVal min(minVal)];
    end
elseif(length(maxVal) == 1 && length(minVal) == 2) % One Max value specified
    % If a max value is in the middle, then it is the 0
    if maxVal > min(minVal)  && maxVal < max(minVal)
        % [Min1 Max Min2]
        s = sort([minVal, maxVal]);
        cbarLower_minmax=s(1:2);
        cbarUpper_minmax=s(2:3);
    else
        % [-Max Min1], [Min2 Max]
        maxVal = [-abs(maxVal) abs(maxVal)];
        s = sort([minVal, maxVal]);
        cbarLower_minmax=s(1:2);
        cbarUpper_minmax=s(3:4);
    end
elseif(length(maxVal) == 2 && length(minVal) == 1) % Two Max value specified, one min, two colorbars
    s = sort([minVal, maxVal]);
    cbarLower_minmax=s(1:2);
    cbarUpper_minmax=s(2:3);
elseif(length(maxVal) == 2 && length(minVal) == 2) % Everything specified
    s = sort([minVal, maxVal]);
    cbarLower_minmax=s(1:2);
    cbarUpper_minmax=s(3:4);
elseif(length(maxVal)==1 && length(minVal)==1)
    cbarUpper_minmax=sort([minVal, maxVal]);
end

if(p.Results.logScale)
   if(any(data2plot_concat<=0))
        error("Cannot use logscale when data contains negative values")    
   end
   data2plot_concat = log(data2plot_concat);
   cbarLower_minmax=log(cbarUpper_minmax);
   cbarUpper_minmax=log(cbarUpper_minmax);
end

titleString = p.Results.titleString;
clrBarTitle = p.Results.colorbarStr;
projectmode = p.Results.interpolateType;
bufferDistance=p.Results.bufferDistance;

cmap_high = p.Results.cmap;
if(~ishandle(cmap_high))
   cmap_high = str2func(cmap_high);
end

cmap_low_t = p.Results.cmap_lower;
if(~ishandle(cmap_low_t))
    cmap_low_t = str2func(cmap_low_t);
end
cmap_low = @(n) flip(cmap_low_t(n));

ax = p.Results.ax;
bgc = p.Results.backgroundColor;
if(~any(ismissing(bgc)) && ~isempty(bgc))
    set(ax, 'color', bgc);
end

numericColors = isnumeric(p.Results.labelspherecolors);
ss = size(p.Results.labelspherecolors);
if(numericColors)
    numColors = ss(1);
else
    numColors = length(p.Results.labelspherecolors);
end
if(numericColors)
   switch(numColors)
       case 1
           srcColor = p.Results.labelspherecolors;
           detColor = p.Results.labelspherecolors;
           optColor = p.Results.labelspherecolors;
           color1020 = p.Results.labelspherecolors;
       case 2
           srcColor = p.Results.labelspherecolors(1,:);
           detColor = p.Results.labelspherecolors(2,:);
           optColor=[];
       case 3
           srcColor = p.Results.labelspherecolors(1,:);
           detColor = p.Results.labelspherecolors(2,:);
           optColor = p.Results.labelspherecolors(3,:);
       otherwise
           srcColor = p.Results.labelspherecolors(1,:);
           detColor = p.Results.labelspherecolors(2,:);
           optColor = p.Results.labelspherecolors(3,:);
           color1020 = p.Results.labelspherecolors(4,:);
   end
else
    switch(numColors)
       case 1
           srcColor = p.Results.labelspherecolors;
           detColor = p.Results.labelspherecolors;
           optColor = p.Results.labelspherecolors;
           color1020 = p.Results.labelspherecolors;
       case 2
           srcColor = p.Results.labelspherecolors(1);
           detColor = p.Results.labelspherecolors(2);
           optColor=[];
       case 3
           srcColor = p.Results.labelspherecolors(1);
           detColor = p.Results.labelspherecolors(2);
           optColor = p.Results.labelspherecolors(3);
        otherwise
           srcColor = p.Results.labelspherecolors(1);
           detColor = p.Results.labelspherecolors(2);
           optColor = p.Results.labelspherecolors(3);
           color1020 = p.Results.labelspherecolors(4);
    end
end
useHighRes = p.Results.useHighRes;
show1020 = p.Results.useEEG || islogical(p.Results.I1020_labels) && p.Results.I1020_labels || ~islogical(p.Results.I1020_labels) && ~isempty(p.Results.I1020_labels);
showSD = p.Results.SDLabels;
showChannels = p.Results.ChannelLabels;

%cla
hold off



itemsToDelete={'BrainVoxel','BA_area_mrk','Eye','ProbeOpt','OptLabel','ProbeSrc','ProbeSrcLabel','ProbeDet','ProbeDetLabel','Scatter1020','Label1020','ScatterCurve','OptLines','BrainRef'};

grootHandle=groot;
grootHandle.ShowHiddenHandles=true;
itemsToSkipPlot=cell(0);
j=1;
for i=1:length(itemsToDelete)
    item = findobj(gcf, "Tag", itemsToDelete{i});
    if(~isempty(item)&&~animationOptimized)
        delete(item);
    elseif(~isempty(item)&&animationOptimized)
        itemsToSkipPlot{j}=itemsToDelete{i};
        j=j+1;
    end
end
grootHandle.ShowHiddenHandles=false;

probeInfo=[];

if(multiprobe)
    num_devices = length(fNIR);
    probeInfos = {};
    maxSrcIdx=0;
    maxDetIdx=0;
    for i=1:num_devices
        if(isstring(fNIR{i})||ischar(fNIR{i}))
            cfgFilePath=sprintf('%s.cfg', fNIR{i}); 
            
        elseif(pf2_base.isnestedfield(fNIR{i}, 'info.probename')&&isfield(fNIR{i}.info, 'probename')&&~contains(fNIR{i}.info.probename,'Unknown')) 
            cfgFilePath = sprintf('%s.cfg', fNIR{i}.info.probename); 
        else
            cfgFilePath = '';
        end
        probeInfos{i} = pf2_base.loadDeviceCfg(cfgFilePath);
        
        if(pf2_base.isnestedfield(probeInfos{i},'Probe'))
            deviceInfo=probeInfos{i}.Info;
            if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
                probeNum=1;
            end
            probeInfos{i}=probeInfos{i}.Probe{probeNum};
            probeInfos{i}.TableOpt.ProbeNum(:,1)=i;
            probeInfos{i}.TableSD.ProbeNum(:,1)=i;
            probeInfos{i}.TableOpt.SrcIdx=probeInfos{i}.TableOpt.SrcIdx+maxSrcIdx;
            maxSrcIdx=maxSrcIdx+max(probeInfos{i}.TableOpt.SrcIdx);
            probeInfos{i}.TableOpt.DetIdx=probeInfos{i}.TableOpt.DetIdx+maxDetIdx;
            maxDetIdx=maxDetIdx+max(probeInfos{i}.TableOpt.DetIdx);
            probeInfos{i}.TableOpt.HasData(:,1)=~dataEmpty(i);
        else
            error('Unable to identify probe'); 
        end
        
        if(~dataEmpty(i) && length(data2plot{i})~=probeInfos{i}.NumOptodes)
            error('Must have a value for all optodes');
        end
    end
    probeInfo = {};
    fields = fieldnames(probeInfos{1});
    for i=1:numel(fields)
        value = probeInfos{1}.(fields{i});
        if size(value, 1) == 1 && size(value, 2) == 1
            continue;
        elseif size(value, 1) == 1
            result = [];
            for j=1:num_devices
                result = [result, probeInfos{j}.(fields{i})];
            end
            probeInfo.(fields{i}) = result;
        elseif size(value, 2) == 1
            result = [];
            for j=1:num_devices
                result = [result; probeInfos{j}.(fields{i})];
            end
            probeInfo.(fields{i}) = result;
        elseif istable(value)
            result = probeInfos{1}.(fields{i});
            if strcmp(fields{i}, "TableOpt")
                result = removevars(result, {'Ch', 'wv'});
            end
            for j = 2:num_devices
                temp = probeInfos{j}.(fields{i});
                if strcmp(fields{i}, 'TableOpt')
                    temp = removevars(temp, {'Ch', 'wv'});
                end
                
                result = [result; temp];
            end
            probeInfo.(fields{i}) = result;
        end
    end
    

    
    probeInfo.OptPos3D_mean = [nanmean(probeInfo.OptPos.x) nanmean(probeInfo.OptPos.y) nanmean(probeInfo.OptPos.z)];
    probeInfo.NumShortSeparation = sum(probeInfo.TableOpt.IsShortSeparation);
    probeInfo.NumOptodes = length(probeInfo.OptPos.x);
else
    if(p.Results.useEEG && isempty(fNIR))
       probeDraw = {};
       cfgFilePath = '';
    elseif(isempty(fNIR)&&isfield(setF,'device'))
        cfgFilePath=setF.device.cfg.File;
        if(~isfield(setF.device.Probe{1},'OptLayout2D'))
            probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,false);
            setF.device=probeInfo;
        else
           probeInfo=setF.device; 
        end
    elseif(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown')) 
        %try to load the probename cfg file
        cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
    else
        cfgFilePath='';
    end

    if(~isempty(probeInfo) || isempty(cfgFilePath) && p.Results.useEEG)

    elseif(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))

        warning('Missing or invalid configuration file path\n')

        disp('No device specified. Please load device configuration');
        probeInfo=pf2_base.loadDeviceCfg('',false);
        if(isempty(probeInfo))
            error('No valid devices selected');
        end

    elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
        probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,false);
    end

    if(pf2_base.isnestedfield(probeInfo,'Probe'))
        deviceInfo=probeInfo.Info;
        if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
            probeNum=1;
        end
        probeInfo=probeInfo.Probe{probeNum};
        
        probeInfo.TableOpt.HasData(:,1)=~dataEmpty;
        probeInfo.TableOpt.ProbeNum(:,1)=1;
        
    elseif(~p.Results.useEEG)
       error('Unable to identify probe'); 
    end
end

if(show1020)
    c1020=load('cerebro_1020_table.mat'); %estimation of 10-20 coordinates
    c1020=c1020.c1020;
    
    if(p.Results.useTalairach)
            txyz=pf2_base.external.icbm_fsl2tal([c1020.mx,c1020.my,c1020.mz]);
        
           c1020.x = txyz(:,1);
           c1020.y = txyz(:,2);
           c1020.z = txyz(:,3);
       else
           c1020.x = c1020.mx;
           c1020.y = c1020.my;
           c1020.z = c1020.mz;
    end
    
    c1020 = c1020(~isnan(c1020.x), :);
    if ~islogical(p.Results.I1020_labels)
        labels = p.Results.I1020_labels;
        c1020 = c1020(ismember(c1020.Electrode, labels), :);
    end   
    
    if(p.Results.useEEG)
       probeDraw = probeInfo;
       probeInfo = {};
       idx = arrayfun(@(x) find(strcmp(c1020.Electrode, x)), labels);
       data2plot_concat = data2plot_concat(idx);
       
       probeInfo.OptPos3DX = c1020.x;
       probeInfo.OptPos3DY = c1020.y;
       probeInfo.OptPos3DZ = c1020.z;
       
       probeInfo.OptPos.x=c1020.x;
       probeInfo.OptPos.y=c1020.y;
       probeInfo.OptPos.z=c1020.z;
       
       probeInfo.NumOptodes = height(c1020);
       probeInfo.IsShortSeparation = zeros(1, probeInfo.NumOptodes);
       probeInfo.OptPos3D_mean = nanmean([probeInfo.OptPos3DX probeInfo.OptPos3DY probeInfo.OptPos3DZ]);
       if(isnan(p.Results.bufferDistance))
          bufferDistance = 40/sqrt(2); 
       end
    end
end

if(p.Results.useEEG && ~isempty(probeDraw))
    tempProbe = probeInfo;
    probeInfo =  probeDraw;
end
if(isfield(probeInfo, 'TableOpt'))
    include_ss=p.Results.includeSS;
    if(include_ss&&probeInfo.NumOptodes>length(data2plot_concat)&&probeInfo.NumOptodes-probeInfo.NumShortSeparation==length(data2plot_concat))
        include_ss=false;
        warning('Not enough data for all channels, ignoring short separation channels');
    end
    
    includeChannels=probeInfo.TableOpt.HasData&(include_ss||~probeInfo.IsShortSeparation);
    
    channelList=probeInfo.TableOpt.OptodeNum(includeChannels);
    numOptodes=length(channelList);
    
    srcIdx=probeInfo.TableSD.Type=='Src';
    detIdx=~srcIdx;
    srcPos = [probeInfo.TableSD.Pos3D_x(srcIdx), probeInfo.TableSD.Pos3D_y(srcIdx), probeInfo.TableSD.Pos3D_z(srcIdx)];
    srcLabels = probeInfo.TableSD.Label(srcIdx);
    detLabels = probeInfo.TableSD.Label(detIdx);
    detPos = [probeInfo.TableSD.Pos3D_x(detIdx), probeInfo.TableSD.Pos3D_y(detIdx), probeInfo.TableSD.Pos3D_z(detIdx)];
    optPos = [probeInfo.TableOpt.Pos3D_x, probeInfo.TableOpt.Pos3D_y, probeInfo.TableOpt.Pos3D_z];
    
    if(p.Results.useTalairach)
        optPos=pf2_base.external.icbm_fsl2tal(optPos);
        detPos=pf2_base.external.icbm_fsl2tal(detPos);
        srcPos=pf2_base.external.icbm_fsl2tal(srcPos);
    end
    
    probeInfo.TableOpt.OptPos=optPos;
    probeInfo.TableOpt.SrcPos=srcPos(probeInfo.TableOpt.SrcIdx, :);
    probeInfo.TableOpt.DetPos=detPos(probeInfo.TableOpt.DetIdx, :);
    probeInfo.TableOpt.sd=probeInfo.TableOpt.SrcPos-probeInfo.TableOpt.DetPos;
    probeInfo.TableOpt.sdDist=sqrt(sum(probeInfo.TableOpt.sd.^2,2));

    % formula for ellipse: C + a cos(theta) U + b sin(theta) V
    
    uProbe=unique(probeInfo.TableOpt.ProbeNum);
    
    probeInfo.TableOpt.b(:,1)=probeInfo.TableOpt.sdDist/2;
    probeInfo.TableOpt.a(:,1)=probeInfo.TableOpt.b*p.Results.scatteringFactor;
    probeInfo.TableOpt.U=probeInfo.TableOpt.sd./vecnorm(probeInfo.TableOpt.sd')';
    probeInfo.TableOpt.V=centerCamPos-probeInfo.TableOpt.OptPos;
    probeInfo.TableOpt.V=probeInfo.TableOpt.V./vecnorm(probeInfo.TableOpt.V')';
    probeInfo.TableOpt.VectorDir=probeInfo.TableOpt.OptPos+probeInfo.TableOpt.V.*probeInfo.TableOpt.sdDist/3;
    

end

if(p.Results.useEEG)
    if(~isempty(probeDraw))
        probeInfo = tempProbe;
    end
    numOptodes = probeInfo.NumOptodes;
    includeChannels = ~isnan(probeInfo.OptPos3DX);
end

if(~all(dataEmpty) && length(data2plot_concat)~=numOptodes)
    error('Must have a value for all optodes');
end

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');


optPos=[probeInfo.OptPos.x(includeChannels),probeInfo.OptPos.y(includeChannels),probeInfo.OptPos.z(includeChannels)];

if(p.Results.useTalairach)
     optPos=pf2_base.external.icbm_fsl2tal(optPos);
end
     
OptPos3D_mean=nanmean(optPos,1);


if(isnan(bufferDistance))
   bufferDistance=median(probeInfo.TableOpt.SD(includeChannels))*10/sqrt(2);
end



% TAL EEG locations from Automated cortical projection of EEG sensors: Anatomical correlation via the international 10–10 system
h=gcf;
if(useHighRes)
    if(isfield(h,'UserData')&&isfield(h.UserData,'cMdl_high'))
        cerebro_mdl=h.UserData.cMdl_high;
    else
        cerebro_mdl=load('cerebro_mdl.mat');    %high res model
        cerebro_mdl=cerebro_mdl.cerebro_mdl;
        h.UserData.cMdl_high=cerebro_mdl;
    end
else
    if(isfield(h,'UserData')&&isfield(h.UserData,'cMdl_low'))
        cerebro_mdl=h.UserData.cMdl_low;
    else
        cerebro_mdl=load('cerebro_mdl_05.mat');    %high res model
        cerebro_mdl=cerebro_mdl.cerebro_mdl;
        h.UserData.cMdl_low=cerebro_mdl;
    end
end

%

if(isempty(itemsToSkipPlot))
    camproj('perspective');
    axis('image');
end

plotFNIRS_SD=showSD&&~contains('ProbeSrc',itemsToSkipPlot);
plot1020=show1020;
brainColor=p.Results.brainColor;
cMdl=cerebro_mdl;



TAL_RosCaud=[70,-110];
TAL_RL=[68, -65];
TAL_UD=[76, -50-13.5];

MNI_RosCaud=[75,-108];
MNI_RL=[73, -71];
MNI_UD=[83, -70-13.5];

x2tx=@(x) (x-min(x))/(max(x)-min(x))*(TAL_RL(1)-TAL_RL(2))+TAL_RL(2);%*49/1.73/brainResizeFactor;  %L/R scaling
y2ty=@(y) (y-min(y))/(max(y)-min(y))*(TAL_RosCaud(1)-TAL_RosCaud(2))+TAL_RosCaud(2);%(y-0.57)*143.5/4.35/brainResizeFactor; %rostral/caudal scaling
z2tz=@(z) (z-min(z))/(max(z)-min(z))*(TAL_UD(1)-TAL_UD(2))+TAL_UD(2);%(z-2.32)*79/2.4/brainResizeFactor;  %up down scaling

x2mx=@(x) (x-min(x))/(max(x)-min(x))*(MNI_RL(1)-MNI_RL(2))+MNI_RL(2);  %L/R scaling
y2my=@(y) (y-min(y))/(max(y)-min(y))*(MNI_RosCaud(1)-MNI_RosCaud(2))+MNI_RosCaud(2); %rostral/caudal scaling
z2mz=@(z) (z-min(z))/(max(z)-min(z))*(MNI_UD(1)-MNI_UD(2))+MNI_UD(2);  %up down scaling

rotx = @(t) [1 0 0; 0 cos(t) -sin(t) ; 0 sin(t) cos(t)] ;
roty = @(t) [cos(t) 0 sin(t) ; 0 1 0 ; -sin(t) 0  cos(t)] ;
rotz = @(t) [cos(t) -sin(t) 0 ; sin(t) cos(t) 0 ; 0 0 1] ;

reorderIdx=[3,1,2];
mdl.v=cMdl.v(:,reorderIdx);

if(p.Results.useTalairach)
    mdl.v=mdl.v*rotx(4/180*pi);
    mdl.v=[x2tx(mdl.v(:,1)),y2ty(mdl.v(:,2)),z2tz(mdl.v(:,3))];
else
    mdl.v=mdl.v*rotx(0/180*pi);
    mdl.v=[x2mx(mdl.v(:,1)),y2my(mdl.v(:,2)),z2mz(mdl.v(:,3))];
    
    
    
end

if(p.Results.showReference)
    fprintf('Min X: %.3f Max X %.3f\n',min(mdl.v(:,1)),max(mdl.v(:,1)));
    fprintf('Min Y: %.3f Max Y %.3f\n',min(mdl.v(:,2)),max(mdl.v(:,2)));
    fprintf('Min Z: %.3f Max Z %.3f\n',min(mdl.v(mdl.v(:,2)<-60,3)),max(mdl.v(:,3)));
end

mdl.f=cMdl.f.v(:,reorderIdx);
%mdl.f=[x2tx(mdl.f(:,1)),y2ty(mdl.f(:,2)),z2tz(mdl.f(:,3))];

%set(h,'linestyle','None');
%shading interp
%cameratoolbar

camIntensity=0.8;
camColor=[1,1,1]*camIntensity;

ka=0.825;
kd=0.4;
ks=0.2;

hold on;

lht=findobj(gca,'Type','Light','Tag','Front');
if(isempty(lht))
    lht=camlight('right');
    lht.Tag='Front';
    lht.Color=camColor;
    lht.Position=[0,100,0];
    
    shading('interp');
    
    lighting('phong');
   
    %camlight(lht,0, 180);
else
   %camlight(lht,0,180); 
end

if(islogical(p.Results.BrodmannAreas)&&p.Results.BrodmannAreas||isnumeric(p.Results.BrodmannAreas))
    showBrodmann=true;
    if(islogical(p.Results.BrodmannAreas))
        BA_areas=1:55;
    else
        BA_areas=p.Results.BrodmannAreas;
    end
else
    showBrodmann=false;
    BA_areas=[];
end



if(p.Results.showVoxelBrain&&~contains(itemsToSkipPlot,'BrainVoxel'))
    h=gcf;
    if(isfield(h,'UserData')&&isfield(h.UserData,'mni_t1'))
        mni_t1=h.UserData.mni_t1;
    else
        mni_t1=load('mni_t1.mat');
        mni_t1=mni_t1.mni_t1;
        h.UserData.mni_t1=mni_t1;
    end
    
    center=[91,127,73];
    szM=size(mni_t1);
    
    
    voxelRes=1;
    

    x2mni=@(x) x-center(1);
    y2mni=@(y) y-center(2);
    z2mni=@(z) z-center(3);

    xyz2mni=@(x,y,z) [x2mni(x),y2mni(y),z2mni(z)];

    mni2x=@(mx) mx+center(1);
    mni2y=@(my) my+center(2);
    mni2z=@(mz) mz+center(3);

    mni_t1_x=x2mni(1:voxelRes:szM(1));
    mni_t1_y=y2mni(1:voxelRes:szM(2));
    mni_t1_z=z2mni(1:voxelRes:szM(3));
    %mni_t1=mni_t1(1:voxelRes:end,1:voxelRes:end,end:voxelRes*-1:1);
    
    
    

   lighting('none');
    
    if(p.Results.useVoxelBrodmannAreas)
        h=gcf;
        if(isfield(h,'UserData')&&isfield(h.UserData,'brdm'))
            brdm=h.UserData.brdm;
        else
            brdm=load('brodmann.mat');
            brdm=brdm.brdm;
            h.UserData.brdm=brdm;
        end
       
        
        brdm=brdm(1:voxelRes:end,1:voxelRes:end,1:voxelRes:end);

        %center=[90,126,72];
        szB=size(brdm);

        
        brodmannRes=voxelRes;

        %BA_areas=[9,10,46];

        if(showBrodmann)
            brainColmap=p.Results.BA_cmp(length(BA_areas));

        
            for i=1:length(BA_areas)
                 bdI=find(brdm==BA_areas(i)); %&mni_t1>0); % Might look better with these for whatever reason

                 if(~any(bdI))
                     continue;
                 end

                 [bdx,bdy,bdz] = ind2sub(size(brdm),bdI);

                 bd_mni_intensity=mni_t1(bdI);

                 mni_t1(bdI)=0;


                 bdxyz=xyz2mni(bdx,bdy,bdz);


                 scattercols=brainColmap(i,:).*(double(bd_mni_intensity)/255/3+0.66);
                 h=plotCube(bdxyz(:,1),bdxyz(:,2),bdxyz(:,3),brodmannRes,scattercols);
                 %h=scatter3(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),50*brodmannRes,scattercols,'filled');
                 h.DisplayName=sprintf('BA%i',BA_areas(i));
                 h.Tag='BA_area_mrk';
                hold on
                legend();
            end
        end
        
        lighting('none');
         bdI=brdm>0.&~ismember(brdm,BA_areas);%&mni_t1>0;
         [bdx,bdy,bdz] = ind2sub(size(brdm),find(bdI));

         bd_mni_intensity=mni_t1(bdI);

          mni_t1(bdI)=0;
          bdxyz=xyz2mni(bdx,bdy,bdz);



         scattercols=p.Results.voxelColor.*(double(bd_mni_intensity)/255);
         h=plotCube(bdxyz(:,1),bdxyz(:,2),bdxyz(:,3),brodmannRes,scattercols);
         %h=scatter3(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),50*brodmannRes,scattercols,'filled');
         %h.DisplayName=sprintf('BA%i',BA_areas(i));
         h.Tag='BrainVoxel';
         h.HandleVisibility='off';

        hold on
        legend();
        
        
        %nnzMNIvals=nnzMNIvals(b);

        
    else


        nnzMNI=mni_t1>0;%.&~ismember(brdm,BA_areas);
        nnzMNIvals=(mni_t1(nnzMNI));

        [mnx,mny,mnz] = ind2sub(size(mni_t1),find(nnzMNI));

        mnxyz=xyz2mni(mnx,mny,mnz);

        cubeCols=p.Results.voxelColor.*double(nnzMNIvals)/255;
        
        h=plotCube(mnxyz(:,1),mnxyz(:,2),mnxyz(:,3),voxelRes,cubeCols);
        h.Tag='BrainVoxel';
        h.HandleVisibility='off';
        lighting('none');
        hold on
    end
end



if(~all(dataEmpty))
    C=data2plot_concat;

    num_vertices = size(mdl.v, 1);

    Cs = zeros(num_vertices, 3);

    if(p.Results.useProjectedOptodeLocations)
        controlPoints=probeInfo.TableOpt.VectorDir(includeChannels,:);
        max_distance_2 = bufferDistance^1.2;
    else
        controlPoints = optPos;
        max_distance_2 = bufferDistance^2/sqrt(2);
    end
    
    num_control = size(controlPoints, 1);
    
%     
%     controlPoints=bigbd;
%     
%     num_control = size(controlPoints, 1);
% 
%     d=nan(num_vertices,1);
%     ind=nan(num_vertices,1);
%     for i=1:num_vertices
%         q = repmat(mdl.v(i,:), num_control, 1);
%         dist_array = sum((controlPoints - q).^2, 2);
%         [d(i), ind(i)] = min(dist_array);
%         if(rem(i,1000)==0)
%             toc
%             fprintf('%i\n',i);
%             tic
%         end
%     end
%     cerebro_mdl.b_dist=d;
%     cerebro_mdl.b_area=bigbdidx(ind);
    
    dist_array = zeros(num_vertices, num_control);
    for i=1:num_control
        q = repmat(controlPoints(i,:), num_vertices, 1);
        dist_array(:,i) = sum((mdl.v - q).^2, 2);
    end

    [d, ind] = min(dist_array, [], 2);
    ind(d > max_distance_2) = 0;

    c_min = nanmin(C, [], 'all');
    c_max = nanmax(C, [], 'all');
    
    nColorsMaxBar=1024;
    cbarUpperRange=max(cbarUpper_minmax)-min(cbarUpper_minmax);
    
    if twosided
       cbarLowerRange=max(cbarLower_minmax)-min(cbarLower_minmax);
       cbarRangeFull=max(cbarUpper_minmax)-min(cbarLower_minmax);
       cbarOverlappingRange=min(cbarUpper_minmax)-max(cbarLower_minmax);
       cbarIsOverlapping=cbarOverlappingRange>0;
       
       
       
       fracUpper=cbarUpperRange/cbarRangeFull;
       fracLower=cbarLowerRange/cbarRangeFull;
       fracOverlap=cbarOverlappingRange/cbarRangeFull;
       
       nColorLower=floor(fracLower*nColorsMaxBar)+1;
       nColorUpper=floor(fracUpper*nColorsMaxBar)+1;
       nOverlap=floor(fracOverlap*nColorsMaxBar)+1;
       
       if cbarIsOverlapping %non-overlapping colorbars
           cmap = colormap([cmap_low(nColorLower);
                   repmat(brainColor, nOverlap, 1);
                   cmap_high(nColorUpper)]);
       else
           cmap = colormap([cmap_low(nColorLower);
                   cmap_high(nColorUpper)]);
       end
       c_ind = round(length(cmap)*(C(:) - min(cbarLower_minmax))/(cbarRangeFull)); %Renormalize to min/max of 0 and 1
       %for i=1:num_control  
          %if C(i) <= minVal(1)
          %    c_ind(i) = round(length(cmap)*(C(i) - c_min)/range);
          %    cmap_i(i) = 1;
          %elseif C(i) < minVal(2)
          %    c_ind(i) = 0;
          %    alphas(i) = 1;
          %else
          %    c_ind(i) = round(length(cmap)*(C(i) - minVal(2))/range);
       %end
    else
        if ~negColorbar
            if(p.Results.logScale)
                cmap = [cmap_high(nColorsMaxBar)];
            else
                cmap = [cmap_high(nColorsMaxBar)];
            end
        else 
            if(p.Results.logScale)
                cmap = [flip(cmap_low(nColorsMaxBar))];
            else
                cmap = [flip(cmap_low(nColorsMaxBar))];
            end
        end

        c_ind = round(length(cmap)*(C(:) - min(cbarUpper_minmax))/cbarUpperRange);
    end

    switch(projectmode)
        case 'nearest'
            C_temp = [brainColor;reshape(ind2rgb(c_ind, cmap), [], 3)];
            C_temp([-1; c_ind] < 0, :) = repmat(brainColor, sum(c_ind < 0)+1, 1);
            %C_temp = zeros(num_control+1, 3);
            %C_temp(1,:) = brainColor;
            %C_temp(logical([0;cmap_i == 1]),:) = reshape(ind2rgb(c_ind(cmap_i == 1), cmap_low), [], 3);
            %C_temp(logical([0;cmap_i == 0]),:) = reshape(ind2rgb(c_ind(cmap_i == 0), cmap), [], 3);

            counts = histcounts(ind, 0:num_control+1);
            for i=1:num_control+1
                Cs(ind==i-1,:) = repmat(C_temp(i,:), counts(i), 1);
            end
            n=length(Cs(~any(Cs,2), :));
        case {'linear', 'quadratic', 'cubic'}
            switch(projectmode)
                case 'linear'
                    beta = 0.5;
                case 'quadratic'
                    beta = 1;
                case 'cubic'
                    beta = 1.5;
            end
            dist_array(dist_array >= max_distance_2) = Inf;

            my_interp_fx = @(dist, val, pow, dim) sum(val.*(1./(dist.^pow + 1e-8))./sum(1./(dist.^pow + 1e-8), dim), dim);
            C_temp = repmat(c_ind', num_vertices, 1);
            v_ind = my_interp_fx(dist_array, C_temp, beta, 2);
            %v_ind = round(length(cmap)*(v_ind - minVal)/(maxVal - minVal));

            %alpha_interp(cmap_interp > 0.1 & cmap_interp < 0.9) = 1;
            Cs = reshape(ind2rgb(round(v_ind), cmap), [], 3);
            Cs(v_ind < 0, :) = repmat(brainColor, sum(v_ind < 0), 1);
            Cs(ind == 0,:) = repmat(brainColor, sum(ind == 0), 1);    
    end
else % No data to plot, everything is brain and anatomy
    Cs = repmat(brainColor, size(mdl.v, 1), 1);
    
    if(showBrodmann&&~p.Results.showVoxelBrain)
      
        
        brainColmap=[brainColor;p.Results.BA_cmp(length(BA_areas));];
        
        
        
        if(p.Results.useVoxelBrodmannAreas)

                h=gcf;
                if(isfield(h,'UserData')&&isfield(h.UserData,'brdm'))
                    brdm=h.UserData.brdm;
                else
                    brdm=load('brodmann.mat');
                    brdm=brdm.brdm;
                    h.UserData.brdm=brdm;
                end

                center=[90,126,72];
                szB=size(brdm);

                brodmannRes=1;

                brainColmap=p.Results.BA_cmp(length(BA_areas));

              
                for i=1:length(BA_areas)
                     bdI=find(brdm==BA_areas(i));
                     [bdx,bdz,bdy] = ind2sub(size(brdm),bdI);
                     bdx=(szB(1)-center(1)-bdx);
                     bdz=szB(2)-center(2)-bdz;
                      bdy=bdy-center(3);
                     bdxyz=unique(round([bdx,bdz,bdy]/brodmannRes)*brodmannRes,'rows');
                     hold on
                     %h=scatter3(bdxyz(:,1),bdxyz(:,2),bdxyz(:,3),50*brodmannRes,'square','MarkerFaceColor',brainColmap(i,:),'MarkerEdgeColor','none');
                    % h.DisplayName=sprintf('BA%i',BA_areas(i));
                    % h.Tag='BA_area_mrk';
    
                end

               % legend(legendStr);

            
        else
        
            cerebro_mdl.b_area(~ismember(cerebro_mdl.b_area,BA_areas))=0;
            cerebro_mdl.b_area(cerebro_mdl.b_dist>150)=0;

            brainstembox=[-15,15;-40,15;-80,5];

            inBox=@(xyz,xminmax,yminmax,zminmax) xyz(:,1)>min(xminmax)&xyz(:,1)<max(xminmax)& ...
                xyz(:,2)>min(yminmax)&xyz(:,2)<max(yminmax)& ...
                xyz(:,3)>min(zminmax)&xyz(:,3)<max(zminmax);

            cerebro_mdl.b_area(inBox(mdl.v,brainstembox(1,:),brainstembox(2,:),brainstembox(3,:)))=0;

            cerstembox=[-55,55;-120,-40;-80,-25];

            cerebro_mdl.b_area(inBox(mdl.v,cerstembox(1,:),cerstembox(2,:),cerstembox(3,:)))=0;

           [a,b,c]=unique(cerebro_mdl.b_area);

            cerebro_mdl.Cs=brainColmap(c,:);
            Cs=cerebro_mdl.Cs;


            for i=2:length(a)
                h=scatter3(0,0,0,0.1,'square','MarkerFaceColor',brainColmap(i,:));
                h.Tag='BA_area_mrk';
                h.DisplayName=sprintf('BA%i',a(i));
                hold on
            end

        end
        
        legend();
    end
end

if(~p.Results.showVoxelBrain)
    brainHndl=findobj(gca,'Type','Patch','Tag','Brain');

    if(isempty(brainHndl))
       brainHndl=gca; 
       cameratoolbar
        hold off
        if(~isempty(p.Results.brainLineColor)&&all(~isnan(p.Results.brainLineColor)))
            brainHndl=patch(brainHndl,'vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp',...
                'AmbientStrength',ka, 'DiffuseStrength', kd, 'SpecularStrength',ks, ...
                'EdgeColor', p.Results.brainLineColor,'FaceAlpha', p.Results.brainAlpha,'LineStyle', '-');
        else
            brainHndl=patch(brainHndl,'vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp',...
                'AmbientStrength',ka, 'DiffuseStrength', kd, 'SpecularStrength',ks, ...
                'LineStyle', 'None','FaceAlpha', p.Results.brainAlpha);
        end

            brainHndl.Tag='Brain';
            brainHndl.DisplayName='Brain';
            brainHndl.HandleVisibility='off';
            hold on;


    else

        if(~isempty(p.Results.brainLineColor)&&all(~isnan(p.Results.brainLineColor)))
            set(brainHndl,'vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp',...
                'AmbientStrength',ka, 'DiffuseStrength', kd, 'SpecularStrength',ks, ...
                'EdgeColor', p.Results.brainLineColor,'FaceAlpha', p.Results.brainAlpha,'LineStyle', '-');
        else
           set(brainHndl,'vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp',...
               'AmbientStrength',ka, 'DiffuseStrength', kd, 'SpecularStrength',ks, ...
               'LineStyle', 'None','FaceAlpha', p.Results.brainAlpha);
        end

    end

end


if(multiprobe)
   probe_colors=lines(num_devices); 
end

mrkScaleFactor=22;

if(showChannels&&isfield(probeInfo, 'TableOpt')&&~contains('ProbeOpt',itemsToSkipPlot))
    optPos = [probeInfo.TableOpt.Pos3D_x probeInfo.TableOpt.Pos3D_y probeInfo.TableOpt.Pos3D_z];
    
    if(p.Results.useTalairach)
         optPos=pf2_base.external.icbm_fsl2tal(optPos);
     end
    
    if(~isempty(optColor) && (isnumeric(optColor) && ~any(isnan(optColor)) || ~ismissing(optColor)))
        if(multiprobe)
            uDevices=unique(probeInfo.TableOpt.ProbeNum);
            
            probe_string=cell(0);
            for i=1:num_devices
                selOpt=probeInfo.TableOpt.ProbeNum(:,1)==uDevices(i);
                h(i) = scatter3(optPos(selOpt,1), optPos(selOpt,2), optPos(selOpt,3),20*p.Results.labelfontsize,'filled',optColor,'MarkerEdgeColor' ,probe_colors(i,:),'LineWidth',1.5);
                
                probe_string{i}=sprintf('Probe %i',uDevices(i));
                
                h(i).Tag='ProbeOpt';
                h(i).DisplayName=probe_string{i};
            end
            legend(h,probe_string);
        else
            h = scatter3(optPos(:,1), optPos(:,2), optPos(:,3),20*p.Results.labelfontsize,'filled',optColor,'MarkerEdgeColor' ,'k');
            h.Tag='ProbeOpt';
            h.DisplayName='Optode';
        end
    end
    
    h=text(optPos(:,1), optPos(:,2), optPos(:,3), string(probeInfo.TableOpt.OptodeNum), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    for i=1:length(h)
        h(i).Tag='OptLabel';
    end
end

if(plotFNIRS_SD&&isfield(probeInfo,'TableSD'))
    %srcIdx=probeInfo.TableSD.Type=='Src';
    %detIdx=~srcIdx;
    
    
    %srcPos = [probeInfo.TableSD.Pos3D_x(srcIdx), probeInfo.TableSD.Pos3D_y(srcIdx), probeInfo.TableSD.Pos3D_z(srcIdx)];
    
     %if(p.Results.useTalairach)
     %    srcPos=pf2_base.external.icbm_fsl2tal(srcPos);
     %end
    
    if(~isempty(srcColor) && (isnumeric(srcColor) && ~any(isnan(srcColor)) || ~ismissing(srcColor)))
        h = scatter3(srcPos(:,1),srcPos(:,2),srcPos(:,3),mrkScaleFactor*p.Results.labelfontsize,'filled',srcColor);
        h.Tag=sprintf('ProbeSrc');
        h.DisplayName='Source';
    end
    h=text(srcPos(:,1), srcPos(:,2), srcPos(:,3), srcLabels, 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    for i=1:length(h)
        h(i).Tag='ProbeSrcLabel';
    end
    hold on
    
    %detPos = [probeInfo.TableSD.Pos3D_x(detIdx), probeInfo.TableSD.Pos3D_y(detIdx), probeInfo.TableSD.Pos3D_z(detIdx)];
    
    %if(p.Results.useTalairach)
    %    detPos=pf2_base.external.icbm_fsl2tal(detPos);
    %end
   
    if(~isempty(detColor) && (isnumeric(detColor) && ~any(isnan(detColor)) || ~ismissing(detColor)))
        h = scatter3(detPos(:,1), detPos(:,2), detPos(:,3), mrkScaleFactor*p.Results.labelfontsize, 'filled', detColor);
        h.Tag=sprintf('ProbeDet');
        h.DisplayName='Detector';
    end
    h=text(detPos(:,1), detPos(:,2), detPos(:,3), detLabels, 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    for i=1:length(h)
        h(i).Tag='ProbeDetLabel';
    end
end

if(plot1020&&~contains('Scatter1020',itemsToSkipPlot))

for i=1:size(c1020,1)
    %text(cerebro1020(i,1),cerebro1020(i,2),cerebro1020(i,3),cerebro1020_labels{i})
    if(~isnan(c1020.BA(i)))
        if(numColors == 4 || numColors == 1)
            h = scatter3(c1020.x(i),c1020.y(i),c1020.z(i),mrkScaleFactor*1.5*p.Results.labelfontsize, 'filled', color1020);
            
        else
            h = scatter3(c1020.x(i),c1020.y(i),c1020.z(i),mrkScaleFactor*1.5*p.Results.labelfontsize, 'filled');
        end
        h.Tag=sprintf('Scatter1020');
        hold on
        
        h=text(c1020.x(i),c1020.y(i),c1020.z(i),c1020.Electrode(i),'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
        for i=1:length(h)
            h(i).Tag='Label1020';
         end
        %text(x2tx(c1020.x(i)),y2ty(c1020.y(i)),z2tz(c1020.z(i)),c1020.Electrode(i),'HorizontalAlignment','center')
        
    end
end
end

if(isempty(itemsToSkipPlot))

        xlabel('x (R/L)');
        ylabel('y (R/C)');
        zlabel('z (U/D)');



    if(isnumeric(p.Results.initCamPosition))
        campos(p.Results.initCamPosition);
    else 
        switch(p.Results.initCamPosition)
            case 'auto'
                campos(nanmean(optPos,1)/norm(nanmean(optPos,1))*1500);   %Front facing
            case 'front'
                campos([0,1200,0]);
            case 'back'
                campos([0,-1200,0]);
            case 'top'
                campos([0,0,1500]);
            case 'left'
                campos([-1200,0,0]);  
            case 'right'
                campos([1200,0,0]);
            case 'face'
                campos([0,1200,-300]);
            otherwise
                warning('Invalid camera position');
                campos(OptPos3D_mean/norm(OptPos3D_mean)*1500);  %Front facing
        end
    end




    campPosTarget=p.Results.camTarget;
    camtarget(campPosTarget);

    lht2=findobj(gca,'Type','Light','Tag','Rear');
    if(isempty(lht2))
        lht2=camlight('left');
        lht2.Tag='Rear';
        lht2.Position=[0,-100,90];
        lht2.Color=camColor;
    else

    end

end


if(p.Results.showScattering||p.Results.optodeLines)&&~contains('OptLines',itemsToSkipPlot)&&~contains('ScatterCurve',itemsToSkipPlot)
   t = linspace(0, pi, 16);
    
   s = probeInfo.TableOpt.SrcPos;
   d = probeInfo.TableOpt.DetPos;
   o = probeInfo.TableOpt.OptPos;


   % formula for ellipse: C + a cos(theta) U + b sin(theta) V
   b = probeInfo.TableOpt.b;%norm(s - d)/2;
   a = probeInfo.TableOpt.a;%p.Results.scatteringFactor * b;
   %U = s - d;
   U = probeInfo.TableOpt.U;%U / norm(U);
   %V = camtarget-o;
   V = probeInfo.TableOpt.V;%V / norm(V);
    
    for i=1:length(probeInfo.TableOpt.OptPos)
       
       points = o(i,:) + b(i)*cos(t)' .* U(i,:) + a(i)*sin(t)' .* V(i,:); 
       
       if(p.Results.optodeLines)
           hold on 
           vectorDir=probeInfo.TableOpt.VectorDir(i,:);
            h=plot3([o(i,1),vectorDir(1)], [o(i,2),vectorDir(2)],[o(i,3),vectorDir(3)], '--k', 'LineWidth', 2,'HandleVisibility','off');
            h.Tag='OptLines';
            
       end
       
       if(p.Results.showScattering)
           hold on
           h=plot3(points(:,1), points(:,2), points(:,3), 'k', 'LineWidth', 1,'HandleVisibility','off');
           h.Tag='ScatterCurve';
       end
    end
end


title(ax, titleString);
if(p.Results.showColorbar && ~all(dataEmpty)&&isempty(itemsToSkipPlot))
    cbars = findobj(gcf, "Type", "ColorBar");
    delete(cbars);
    ax1=ax;
    curAxPosition=ax1.Position;
    
    if(~twosided)
        
        if(~negColorbar)
            colormap(ax1,cmap_high(nColorsMaxBar));
        else
            colormap(ax1,cmap_low(nColorsMaxBar));
        end
        
        chPos=colorbar(ax1);
        
        if(p.Results.logScale)
            set(ax1, 'ColorScale', 'log');
            caxis(ax1, [exp(cbarUpper_minmax)]);
        else
            caxis(ax1, [cbarUpper_minmax]);
        end
        
        set(get(chPos, 'title'), 'string', clrBarTitle);
    else
        curAxPosition=ax1.OuterPosition;

        colormap(ax1,cmap_high(nColorsMaxBar));
        caxis(ax1, [cbarUpper_minmax]);

        ax2=axes('OuterPosition',curAxPosition);
        ax2.Position=ax1.Position;

        set(gca,'xtick',[]);
        set(gca,'ytick',[]);

        %set( chNeg, 'YDir', 'reverse' );
        colormap(ax2,cmap_low(nColorsMaxBar));

        caxis(ax2, [cbarLower_minmax]);
        %caxis([-1*minVal(1),-1*maxVal(2)])

        axis off

        curAxInnerPosition=ax1.Position;

        linkprop([ax1, ax2],{'CameraUpVector', 'CameraPosition', 'CameraTarget', 'XLim', 'YLim', 'ZLim'});
        %set([ax1,ax2],'Position',[.05 .11 .885 .815]);
        chPos=colorbar(ax1);
        chPos.Tag = "Main";
        
        set(get(chPos, 'title'), 'string', clrBarTitle);
        %chPos_position=chPos.OuterPosition;
        cbHeight=curAxInnerPosition(4)/2;

        set(chPos,'Position',[curAxInnerPosition(1)+curAxInnerPosition(3),curAxInnerPosition(2)+cbHeight,0.02,cbHeight]);


        chNeg=colorbar(ax2,'Position',[curAxInnerPosition(1)+curAxInnerPosition(3),curAxInnerPosition(2)-cbHeight/5,0.02,cbHeight]); 
        chNeg.Tag = "Lower";
    end
end


% Alt reference code
% for y=-90:30:90
%     y
%     for x=-60:10:60
%         z=0;
%     %for z=-60:30:60
%        mni3d(x,y,z); 
%     %end
%     
%     end
% end 
%    
    



if(p.Results.showReference&&(isempty(itemsToSkipPlot)))
    %% Test code for calibration
    path4debug=mfilename('fullpath');
    
    [path4debug]=fileparts(path4debug);
    
    path4debug=sprintf('%s/../../../',path4debug);
    
    [img,map,alpha] = imread(sprintf('%s%s',path4debug,'sideprofile_mid.png'));     % Load a sample image
    
    %https://www.openanatomy.org/atlases/nac/brain-2017-01/viewer/#!/view/33316a96-32f2-47f4-b5e0-a6225be09803/state/9dc9a3eb-7805-4b2b-943f-0b6e63ba488f

    imgXY=size(img);
    if(p.Results.useTalairach)
         [lEyeX,lEyeY,lEyeZ]=sphere(10);
        lEyeX=lEyeX*14-32;
        lEyeY=lEyeY*14+45;
        lEyeZ=lEyeZ*14-30;

        h=surf(lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';

        h=surf(-1*lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';
    else
        [lEyeX,lEyeY,lEyeZ]=sphere(10);
        lEyeX=lEyeX*14-32;
        lEyeY=lEyeY*14+45;
        lEyeZ=lEyeZ*14-40;

        h=surf(lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';

        h=surf(-1*lEyeX,lEyeY,lEyeZ,'FaceColor','white');
        h.Tag='Eye';

    end
    
    if(p.Results.useTalairach)
         zStretch=1;
        xStretch=1.15;
        yStretch=1;
        
        xOffset=0;
        yOffset=-5;
        zOffset=-1;
        
        
        xMid=0;
        yMid=-10;
        zMid=9;

        rotX=rotx(10*pi/180);
        
        imgRes=1/4.3;
    else
         zStretch=1.1;
        xStretch=1.16;
        yStretch=1;
        
        xOffset=0;
        yOffset=-3;
        zOffset=-10;
        
        xMid=0;
        yMid=-10;
        zMid=17;
        
        imgRes=1/4.25;
        rotX=rotx(15*pi/180);
    end

    
    imgCoord1=[0,imgXY(1)*imgRes,imgXY(2)*imgRes]*rotX;
    imgCoord2=[0,-imgXY(1)*imgRes,imgXY(2)*imgRes]*rotX;
    imgCoord3=[0,imgXY(1)*imgRes,-imgXY(2)*imgRes]*rotX;
    imgCoord4=[0,-imgXY(1)*imgRes,-imgXY(2)*imgRes]*rotX;

    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid]*xStretch+xOffset;       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid]*yStretch+yOffset;            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid]*zStretch+zOffset;   % The z data for the image corners
    
    
    
    
    hold on
    h=surf(xImage,yImage,zImage,...    % Plot the surface
         'CData',img,...
        'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off

    
    h.Tag='BrainRef';
    [img,map,alpha] = imread(sprintf('%s%s',path4debug,'rcSlice.png'));     % Load a sample image


    imgXY=size(img);

    if(p.Results.useTalairach)
        xMid=-1;
        yMid=-7;
        zMid=6;


        %rotX=rotx(10*pi/180);
    else
        xMid=0;
        yMid=-11;
        zMid=17;


        %rotX=rotx(15*pi/180);
    end
    

    imgRes=1/4.45;
    imgCoord1=[imgXY(1)*imgRes,0,imgXY(2)*imgRes]*rotX;
    imgCoord2=[-imgXY(1)*imgRes,0,imgXY(2)*imgRes]*rotX;
    imgCoord3=[imgXY(1)*imgRes,0,-imgXY(2)*imgRes]*rotX;
    imgCoord4=[-imgXY(1)*imgRes,0,-imgXY(2)*imgRes]*rotX;

    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid]*xStretch+xOffset;       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid]*yStretch+yOffset;            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid]*zStretch+zOffset;   % The z data for the image corners

  
    hold on
    h=surf(xImage,yImage,zImage,...    % Plot the surface
         'CData',img,...
         'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off
    h.Tag='BrainRef';


    [img,map,alpha]  = imread(sprintf('%s%s',path4debug,'topprofile.png'));     % Load a sample image


    imgXY=size(img);
    

        if(p.Results.useTalairach)
            xMid=1;
            yMid=-16;
            zMid=-16;

            %rotX=rotx(10*pi/180);
        else
            xMid=1;
            yMid=-20;
            zMid=-4;

            %rotX=rotx(15*pi/180);
        end
   
    
    imgCoord1=[imgXY(1)*imgRes,imgXY(2)*imgRes,0]*rotX;
    imgCoord2=[-imgXY(1)*imgRes,imgXY(2)*imgRes,0]*rotX;
    imgCoord3=[imgXY(1)*imgRes,-imgXY(2)*imgRes,0]*rotX;
    imgCoord4=[-imgXY(1)*imgRes,-imgXY(2)*imgRes,0]*rotX;
    
    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid]*xStretch+xOffset;       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid]*yStretch+yOffset;            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid]*zStretch+zOffset;   % The z data for the image corners

  
    hold on
    h=surf(xImage,yImage,zImage,...    % Plot the surface
         'CData',img,...
         'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off
    
    h.Tag='BrainRef';
    
    text(-85,55,-50,'L');
    text(85,55,-50,'R');
    
end

h=gca;

if (nargout > 0)
    h=gca;
    
    frame=getframe(ax);
    imgOut = frame.cdata;
end

toc