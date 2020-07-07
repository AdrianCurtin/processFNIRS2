function [ imgOut,optPos2Plot ] = InterpolateValues3D(varargin)

%processFNIRS2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
% fNIR is a data structure that contains the fNIRS structure info, 
% data2plot houses the numbers themselves
%
% Short separation channels are not presented here and are skipped
%

validAxesHandle= @(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x);
validScalarPosNum = @(x) isnumeric(x) && x>0;
validScalarPosNumOrNan = @(x) isnumeric(x) && (x>0||isnan(x));
validI1020Label = @(x) islogical(x) || iscellstr(x);
validColor = @(x) (ischar(x) && length(x) == 1) || isnumeric(x) && length(x) == 3 || isempty(x);
%validColorList = @(x) validColor(x) || all(arrayfun(validColor, x));

defaultInterpolateType = 'nearest';
validInterpolateTypes = {'nearest', 'linear', 'quadratic', 'cubic'};
validInterpolateType = @(x) any(validatestring(x, validInterpolateTypes));

defaultCamPosition = 'auto';
validCamPositions = {'auto','front', 'back', 'top' 'left', 'right'};
validCamPosition = @(x) any(validatestring(x, validCamPositions)) || isnumeric(x) && length(x) == 3;

if(isa(varargin{1},'matlab.graphics.axis.Axes')) %If first argument is axes then move to front
   ax=varargin{1};
   varargin=varargin(2:end);
else
   ax=gca;
end

p=inputParser;

addRequired(p,'data2plot');
addOptional(p,'fNIR', {}, @isstruct);
addOptional(p,'minval', [], @isnumeric);
addOptional(p,'maxval', [], @isnumeric);
addOptional(p,'titleString', '', @isstring);
addOptional(p,'colorbarStr', '', @isstring);

addParameter(p,'ax',ax,validAxesHandle,'PartialMatchPriority',1);
addParameter(p,'ChannelLabels',true,@islogical);
addParameter(p,'SDLabels',true,@islogical);
addParameter(p,'I1020_labels',false,validI1020Label);
addParameter(p, 'useHighRes', true, @islogical);
addParameter(p, 'cmap', 'hot', @ischar);
addParameter(p, 'cmap_lower', 'cool', @ischar);
addParameter(p, 'labelfontsize', 10, validScalarPosNum);
addParameter(p, 'labelfontcolor', 'k', validColor);
addParameter(p, 'labelspherecolors', ["r", "y"]);
addParameter(p, 'brainColor', [0.92, 0.68, 0.68], validColor);
addParameter(p, 'brainLineColor', [], validColor);
addParameter(p, 'backgroundColor', [], validColor);
addParameter(p, 'showColorbar', true, @islogical);
addParameter(p, 'initCamPosition', defaultCamPosition, validCamPosition);
addParameter(p, 'logScale', false, @islogical);
addParameter(p, 'interpolateType', defaultInterpolateType, validInterpolateType);
addParameter(p, 'bufferDistance', nan, validScalarPosNumOrNan); %In a grid, this may equal to sqrt(sd distance^2/2)
addParameter(p, 'includeSS', true, @islogical);

parse(p,varargin{:});

data2plot = p.Results.data2plot;
if(isempty(p.Results.fNIR))
    global setF;
    fNIR = {};
else
    fNIR = p.Results.fNIR;
end

minVal = p.Results.minval;
maxVal = p.Results.maxval;
if(isempty(p.Results.minval))
    minVal = nanmin(data2plot);
end
if(length(minVal)==2)
    twosided = true;
else
    twosided = false;
end

if(isempty(maxVal))
    if(~twosided)
        maxVal = nanmax(data2plot);
    else
        maxVal = [nanmin(data2plot) nanmax(data2plot)];
    end
elseif(length(maxVal) == 1 && length(minVal) == 2)
    if min(minVal) < maxVal && maxVal < max(minVal)
        temp = maxVal;
        maxVal = [minVal(1) minVal(2)];
        minVal = [temp temp];
    else
        maxVal = [-abs(maxVal) abs(maxVal)];
    end
elseif(length(maxVal) == 2 && length(minVal) == 1)
    minVal = min(maxVal);
    maxVal = max(maxVal);
elseif(length(maxVal) == 2 && length(minVal) == 2)
    s = sort([minVal, maxVal]);
    maxVal = s([1, 4]);
    minVal = s([2, 3]);
end


titleString = p.Results.titleString;
clrBarTitle = p.Results.colorbarStr;
projectmode = p.Results.interpolateType;

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

cla

probeInfo=[];

if(isempty(fNIR)&&isfield(setF,'device'))
    
    cfgFilePath=setF.device.cfg.File;
    if(~isfield(setF.device.Probe{1},'OptLayout2D'))
        probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
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

if(~isempty(probeInfo))

elseif(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
    
    warning('Missing or invalid configuration file path\n')
    
    disp('No device specified. Please load device configuration');
    probeInfo=pf2_base.loadDeviceCfg('',true);
    if(isempty(probeInfo))
        error('No valid devices selected');
    end
    
elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
    probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
end

if(pf2_base.isnestedfield(probeInfo,'Probe'))
    deviceInfo=probeInfo.Info;
    if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
        probeNum=1;
    end
    probeInfo=probeInfo.Probe{probeNum};
else
   error('Unable to identify probe'); 
end

if(length(data2plot)~=probeInfo.NumOptodes)
    error('Must have a value for all optodes');
end

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');


OptPosX=probeInfo.OptPos3DX(~probeInfo.IsShortSeparation | ~p.Results.includeSS);
OptPosY=probeInfo.OptPos3DY(~probeInfo.IsShortSeparation | ~p.Results.includeSS);
OptPosZ=probeInfo.OptPos3DZ(~probeInfo.IsShortSeparation | ~p.Results.includeSS);

OptPos3D_mean=probeInfo.OptPos3D_mean;

bufferDistance=p.Results.bufferDistance;
if(isnan(bufferDistance))
   bufferDistance=median(probeInfo.SD(~probeInfo.IsShortSeparation)*10)/sqrt(2);
end

useHighRes = p.Results.useHighRes;
show1020 = islogical(p.Results.I1020_labels) && p.Results.I1020_labels || ~islogical(p.Results.I1020_labels) && ~isempty(p.Results.I1020_labels);
showSD = p.Results.SDLabels;
showChannels = p.Results.ChannelLabels;

% TAL EEG locations from Automated cortical projection of EEG sensors: Anatomical correlation via the international 10–10 system
if(useHighRes)
    cerebro_mdl=load('cerebro_mdl.mat');    %high res model
    cerebro_mdl=cerebro_mdl.cerebro_mdl;
else
    cerebro_mdl=load('cerebro_mdl_05.mat');  %Low-res model
    cerebro_mdl=cerebro_mdl.cerebro_mdl_05;
end

if(show1020)
    c1020=load('cerebro_1020_table.mat'); %estimation of 10-20 coordinates
    c1020=c1020.cerebro_1020_table;
    if ~islogical(p.Results.I1020_labels)
        labels = "'" + p.Results.I1020_labels + "'";
        c1020 = c1020(ismember(c1020.Electrode, labels), :);
    end     
end

%lighting('phong')

camproj('perspective');
axis square
%axis off
axis equal
axis tight

plotFNIRS_SD=showSD;
plot1020=show1020;
brainColor=p.Results.brainColor;
cMdl=cerebro_mdl;



tx2x=@(x) x;%/50*1.73;  %L/R scaling
ty2y=@(y) y;%/140*4.76+0.5; %rostral/caudal scaling
tz2z=@(z) z;%/80*2.5+2.3;  %up down scaling

x2tx=@(x) x*49/1.73;  %L/R scaling
y2ty=@(y) (y-0.57)*143.5/4.76; %rostral/caudal scaling
z2tz=@(z) (z-2.32)*79/2.5;  %up down scaling


reorderIdx=[3,1,2];
mdl.v=cMdl.v(:,reorderIdx);
mdl.v=[x2tx(mdl.v(:,1)),y2ty(mdl.v(:,2)),z2tz(mdl.v(:,3))];
mdl.f=cMdl.f.v(:,reorderIdx);
%mdl.f=[x2tx(mdl.f(:,1)),y2ty(mdl.f(:,2)),z2tz(mdl.f(:,3))];

%set(h,'linestyle','None');
shading interp
cameratoolbar
lht=camlight('headlight');
lht.Color=[0.68,0.68,0.68];
camlight(lht,'headlight');

hold on;

C=data2plot;

num_vertices = size(mdl.v, 1);
max_distance_2 = bufferDistance^2;
Cs = zeros(num_vertices, 3);
controlPoints = [OptPosX(:), OptPosY(:), OptPosZ(:)];
num_control = size(controlPoints, 1);


cmap_high = colormap(hot(256));
cmap_low = colormap(cool(256));


tic
dist_array = zeros(num_vertices, num_control);
for i=1:num_control
    q = repmat(controlPoints(i,:), num_vertices, 1);
    dist_array(:,i) = sum((mdl.v - q).^2, 2);
end

[d, ind] = min(dist_array, [], 2);
ind(d > max_distance_2) = 0;

c_min = nanmin(C, [], 'all');
c_max = nanmax(C, [], 'all');
if twosided
   if minVal(1) - maxVal(1) > maxVal(2) - minVal(2)
       range = minVal(1) - maxVal(1);
       cmap = colormap([cool(256);
               repmat(brainColor, round(256*(minVal(2) - minVal(1))/range), 1);
               hot(round(256*(maxVal(2) - minVal(2))/range))]);
   else
       range = maxVal(2) - minVal(2);
       cmap = colormap([cool(round(256*(minVal(1) - maxVal(1))/range));
               repmat(brainColor, round(256*(minVal(2) - minVal(1))/range), 1);
               hot(256)]);
   end
   c_ind = round(length(cmap)*(C(:) - maxVal(1))/(maxVal(2) - maxVal(1)));
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
    if minVal < maxVal
        cmap = hot(256);
    else
        cmap = cool(256);
    end
    c_ind = round(length(cmap)*(C(:) - minVal)/(maxVal - minVal));
end

switch(projectmode)
    case 'nearest'
        C_temp = [brainColor;reshape(ind2rgb(c_ind, cmap), [], 3)];
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
        Cs(ind == 0,:) = repmat(brainColor, sum(ind == 0), 1);
end
toc

if(~isempty(p.Results.brainLineColor)&&all(~isnan(p.Results.brainLineColor)))
    h=patch('vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp','AmbientStrength',0.6, 'EdgeColor', p.Results.brainLineColor);
else
    h=patch('vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp','AmbientStrength',0.6, 'LineStyle', 'None');
end

if(showChannels)
    if(numColors ~= 2)
        if(~isempty(optColor) && (isnumeric(optColor) && ~any(isnan(optColor)) || ~ismissing(optColor)))
            h = scatter3(OptPosX, OptPosY, OptPosZ,20*p.Results.labelfontsize,'filled',optColor);
        end
    end
    text(OptPosX, OptPosY, OptPosZ, string(1:length(probeInfo.OptPos3DZ)), 'HorizontalAlignment', 'center', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
end

if(plotFNIRS_SD&&isfield(probeInfo,'SrcPos3DX'))
    srcPos = [probeInfo.SrcPos3DX', probeInfo.SrcPos3DY', probeInfo.SrcPos3DZ'];
    [srcPos, I] = unique(srcPos, 'rows');
    srcPos = srcPos(probeInfo.sI(I),:);
    if(~isempty(srcColor) && (isnumeric(srcColor) && ~any(isnan(srcColor)) || ~ismissing(srcColor)))
        h = scatter3(srcPos(:,1),srcPos(:,2),srcPos(:,3),20*p.Results.labelfontsize,'filled',srcColor);
    end
    text(srcPos(:,1), srcPos(:,2), srcPos(:,3), 'S'+string(1:length(srcPos)), 'HorizontalAlignment', 'center', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    hold on
    
    detPos = [probeInfo.DetPos3DX', probeInfo.DetPos3DY', probeInfo.DetPos3DZ'];
    [detPos, I] = unique(detPos, 'rows');
    detPos = detPos(probeInfo.dI(I),:);
    if(~isempty(detColor) && (isnumeric(detColor) && ~any(isnan(detColor)) || ~ismissing(detColor)))
        h = scatter3(detPos(:,1), detPos(:,2), detPos(:,3), 20*p.Results.labelfontsize, 'filled', detColor);
    end
    text(detPos(:,1), detPos(:,2), detPos(:,3), 'D'+string(1:length(detPos)), 'HorizontalAlignment', 'center', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
end

if(plot1020)

for i=1:size(c1020,1)
    %text(cerebro1020(i,1),cerebro1020(i,2),cerebro1020(i,3),cerebro1020_labels{i})
    if(~isnan(c1020.BA(i)))
        if(numColors == 4 || numColors == 1)
            h = scatter3(c1020.tx(i),c1020.ty(i),c1020.tz(i),30*p.Results.labelfontsize, 'filled', color1020);
        else
            h = scatter3(c1020.tx(i),c1020.ty(i),c1020.tz(i),30*p.Results.labelfontsize, 'filled');
        end
        hold on
        
        text(c1020.tx(i),c1020.ty(i),c1020.tz(i),c1020.Electrode(i),'HorizontalAlignment','center', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor)
        %text(x2tx(c1020.x(i)),y2ty(c1020.y(i)),z2tz(c1020.z(i)),c1020.Electrode(i),'HorizontalAlignment','center')
        
    end
end
end

xlabel('x (L/R)');
ylabel('y (R/C)');
zlabel('z (U/D)');


switch(p.Results.initCamPosition)
    case 'auto'
        campos(OptPos3D_mean*35);  %Front facing
    case 'front'
        campos([0,1000,0]);
    case 'back'
        campos([0,-1000,0]);
    case 'top'
        campos([0,0,1500]);
    case 'left'
        campos([-1000,0,0]);  
    case 'right'
        campos([1000,0,0]);
    otherwise
        campos(OptPos3D_mean*25);  %Front facing
end
%campos(OptPos3D_mean*25);  %Front facing
camtarget([0,-20,0]);
camlight(lht,'headlight');
camlight(180, 0);

if(p.Results.showColorbar)
% clrBarTitle
ax1=ax;
curAxPosition=ax1.Position;

if(~twosided)
    title(ax, titleString);
    if(maxVal>minVal)
        colormap(ax1,cmap);
        negColorbar=false;
    else
        colormap(ax1,cmap_low);
        temp=minVal;
        minVal=maxVal;
        maxVal=temp;
        negColorbar=true;
    end
    caxis(ax1, [minVal, maxVal]);
    chPos=colorbar(ax1);
else
    curAxPosition=ax1.OuterPosition;
    
    colormap(ax1,cmap_high);
    caxis([minVal(2), maxVal(2)]);
    
    ax2=axes('OuterPosition',curAxPosition);
    ax2.Position=ax1.Position;

    set(gca,'xtick',[]);
    set(gca,'ytick',[]);
    
    %set( chNeg, 'YDir', 'reverse' );
    colormap(ax2,cmap_low);
    caxis([maxVal(1), minVal(1)]);
    %caxis([-1*minVal(1),-1*maxVal(2)])
  
    axis off
    
    curAxInnerPosition=ax1.Position;
    
    linkprop([ax1, ax2],{'CameraUpVector', 'CameraPosition', 'CameraTarget', 'XLim', 'YLim', 'ZLim'});
    %set([ax1,ax2],'Position',[.05 .11 .885 .815]);
    chPos=colorbar(ax1);
    %chPos_position=chPos.OuterPosition;
    cbHeight=curAxInnerPosition(4)/2;
    
    set(chPos,'Position',[curAxInnerPosition(1)+curAxInnerPosition(3),curAxInnerPosition(2)+cbHeight,0.02,cbHeight]);
    
    
    chNeg=colorbar(ax2,'Position',[curAxInnerPosition(1)+curAxInnerPosition(3),curAxInnerPosition(2)-cbHeight/5,0.02,cbHeight]);    
end
end