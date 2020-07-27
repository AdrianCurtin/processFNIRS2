function [ h, imgOut ] = InterpolateValues3D(varargin)

%processFNIRS2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
% fNIR is a data structure that contains the fNIRS structure info, 
% data2plot houses the numbers themselves
%
% Short separation channels are not presented here and are skipped
%
tic
validAxesHandle= @(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x);
validScalarPosNum = @(x) isnumeric(x) && x>0;
validScalarPosNumOrNan = @(x) isnumeric(x) && (x>0||isnan(x));
validI1020Label = @(x) islogical(x) || iscellstr(x);
validColor = @(x) (ischar(x) && length(x) == 1) || isnumeric(x) && length(x) == 3 || isempty(x);
validFnirs = @(x) (iscell(x) || isstruct(x));
%validColorList = @(x) validColor(x) || all(arrayfun(validColor, x));

defaultInterpolateType = 'nearest';
validInterpolateTypes = {'nearest', 'linear', 'quadratic', 'cubic'};
validInterpolateType = @(x) any(validatestring(x, validInterpolateTypes));

defaultCamPosition = 'auto';
validCamPositions = {'auto','front', 'back', 'top' 'left', 'right'};
validCamPosition = @(x) any(validatestring(x, validCamPositions)) || isnumeric(x) && length(x) == 3;

defaultColormap = 'hot';
defaultColormapLow = 'cool';
validColormapLabels = {'hot', 'autumn', 'jet', 'gray', 'copper', 'bone', 'cool', 'winter', 'pink'};
validColormap = @(x) any(validatestring(x, validColormapLabels)) || ishandle(x);

if(numel(varargin) > 0 && isa(varargin{1},'matlab.graphics.axis.Axes')) %If first argument is axes then move to front
   ax=varargin{1};
   varargin=varargin(2:end);
else
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
addParameter(p, 'brainAlpha', 1, validScalarPosNum);
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

parse(p,varargin{:});

data2plot = p.Results.data2plot;
dataEmpty = isempty(p.Results.data2plot);
multiprobe = iscell(data2plot);
if(multiprobe && ~dataEmpty)
    data2plot_cell = data2plot;
    concat_data = [];
    for i=1:numel(data2plot)
        concat_data = [concat_data, data2plot{i}];
    end
    data2plot = concat_data;
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

if(p.Results.logScale)
   if(any(data2plot<=0))
        error("Cannot use logscale when data contains negative values")    
   end
   data2plot = log(data2plot);
   minVal = log(minVal);
   maxVal = log(maxVal);
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
showSD = p.Results.SDLabels && ~p.Results.useEEG;
showChannels = p.Results.ChannelLabels;

%cla
hold off

probeInfo=[];

if(show1020)
    c1020=load('cerebro_1020_table.mat'); %estimation of 10-20 coordinates
    c1020=c1020.cerebro_1020_table;
    c1020 = c1020(~isnan(c1020.tx), :);
    if ~islogical(p.Results.I1020_labels)
        labels = "'" + p.Results.I1020_labels + "'";
        c1020 = c1020(ismember(c1020.Electrode, labels), :);
    end   
    
    if(p.Results.useEEG)
       probeInfo = {};
       if(islogical(p.Results.I1020_labels))
           idx = 1:height(c1020);
       else
           [a,idx] = ismember(labels, c1020.Electrode);
           if(any(~a))
                warning("%s are invalid labels", evalc("disp(labels(~a))"));
           end
       end
       data2plot = data2plot(idx(idx > 0));
       probeInfo.OptPos3DX = c1020.tx;
       probeInfo.OptPos3DY = c1020.ty;
       probeInfo.OptPos3DZ = c1020.tz;
       probeInfo.NumOptodes = height(c1020);
       probeInfo.IsShortSeparation = zeros(1, probeInfo.NumOptodes);
       probeInfo.OptPos3D_mean = nanmean([c1020.tx c1020.ty c1020.tz]);
       if(isnan(p.Results.bufferDistance))
          bufferDistance = 40/sqrt(2); 
       end
    end
end

if(multiprobe)
    num_devices = length(fNIR);
    probeInfos = {};
    for i=1:num_devices
        if(pf2_base.isnestedfield(fNIR{i}, 'info.probename')&&isfield(fNIR{i}.info, 'probename')&&~contains(fNIR{i}.info.probename,'Unknown')) 
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
        else
            error('Unable to identify probe'); 
        end
        
        if(~dataEmpty && length(data2plot_cell{i})~=probeInfos{i}.NumOptodes)
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
    
    probeInfo.OptPos3D_mean = [nanmean(probeInfo.OptPos3DX) nanmean(probeInfo.OptPos3DY) nanmean(probeInfo.OptPos3DZ)];
    probeInfo.NumShortSeparation = sum(probeInfo.IsShortSeparation);
    probeInfo.NumOptodes = length(probeInfo.OptPosX);
else
if(p.Results.useEEG)
   %pass
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

if(~isempty(probeInfo) || p.Results.useEEG)

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
elseif(~p.Results.useEEG)
   error('Unable to identify probe'); 
end
end

if(~dataEmpty && length(data2plot)~=probeInfo.NumOptodes)
    error('Must have a value for all optodes');
end

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');


OptPosX=probeInfo.OptPos3DX(~probeInfo.IsShortSeparation | ~p.Results.includeSS);
OptPosY=probeInfo.OptPos3DY(~probeInfo.IsShortSeparation | ~p.Results.includeSS);
OptPosZ=probeInfo.OptPos3DZ(~probeInfo.IsShortSeparation | ~p.Results.includeSS);

OptPos3D_mean=probeInfo.OptPos3D_mean;

if(isnan(bufferDistance))
   bufferDistance=median(probeInfo.SD(~probeInfo.IsShortSeparation)*10)/sqrt(2);
end



% TAL EEG locations from Automated cortical projection of EEG sensors: Anatomical correlation via the international 10–10 system
if(useHighRes)
    cerebro_mdl=load('cerebro_mdl.mat');    %high res model
    cerebro_mdl=cerebro_mdl.cerebro_mdl;
else
    cerebro_mdl=load('cerebro_mdl_05.mat');  %Low-res model
    cerebro_mdl=cerebro_mdl.cerebro_mdl_05;
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



tx2x=@(x) x;%/49*1.73;  %L/R scaling
ty2y=@(y) y;%/143*4.76+0.5; %rostral/caudal scaling
tz2z=@(z) z;%/79*2.5+2.3;  %up down scaling

brainResizeFactor=1.2;

x2tx=@(x) x*49/1.73/brainResizeFactor;  %L/R scaling
y2ty=@(y) (y-0.57)*143.5/4.35/brainResizeFactor; %rostral/caudal scaling
z2tz=@(z) (z-2.32)*79/2.4/brainResizeFactor;  %up down scaling


reorderIdx=[3,1,2];
mdl.v=cMdl.v(:,reorderIdx);
mdl.v=[x2tx(mdl.v(:,1)),y2ty(mdl.v(:,2)),z2tz(mdl.v(:,3))];
mdl.f=cMdl.f.v(:,reorderIdx);
%mdl.f=[x2tx(mdl.f(:,1)),y2ty(mdl.f(:,2)),z2tz(mdl.f(:,3))];

%set(h,'linestyle','None');
shading interp
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
   
    %camlight(lht,0, 180);
else
   %camlight(lht,0,180); 
end

%camlight(lht,'headlight');
% 
% lht=findobj(gca,'Type','Light','Tag','Left');
% if(isempty(lht))
%     lht=camlight('right');
%     lht.Tag='Left';
%     lht.Color=camColor;
%     lht.Position=[-100,10,60];
%    
%     %camlight(lht,0, 180);
% else
%    %camlight(lht,0,180); 
% end
% 
% lht=findobj(gca,'Type','Light','Tag','Right');
% if(isempty(lht))
%     lht=camlight('right');
%     lht.Tag='Right';
%     lht.Color=camColor;
%     lht.Position=[100,-10,60];
%    
%     %camlight(lht,0, 180);
% else
%    %camlight(lht,0,180); 
% end


C=data2plot;

num_vertices = size(mdl.v, 1);
max_distance_2 = bufferDistance^2;
Cs = zeros(num_vertices, 3);
controlPoints = [OptPosX(:), OptPosY(:), OptPosZ(:)];
num_control = size(controlPoints, 1);


dist_array = zeros(num_vertices, num_control);
for i=1:num_control
    q = repmat(controlPoints(i,:), num_vertices, 1);
    dist_array(:,i) = sum((mdl.v - q).^2, 2);
end

[d, ind] = min(dist_array, [], 2);
ind(d > max_distance_2) = 0;

if(~dataEmpty)
c_min = nanmin(C, [], 'all');
c_max = nanmax(C, [], 'all');
if twosided
   if minVal(1) - maxVal(1) > maxVal(2) - minVal(2)
       range = minVal(1) - maxVal(1);
       cmap = colormap([cmap_low(256);
               repmat(brainColor, round(256*(minVal(2) - minVal(1))/range), 1);
               cmap_high(round(256*(maxVal(2) - minVal(2))/range))]);
   else
       range = maxVal(2) - minVal(2);
       cmap = colormap([cmap_low(round(256*(minVal(1) - maxVal(1))/range));
               repmat(brainColor, round(256*(minVal(2) - minVal(1))/range), 1);
               cmap_high(256)]);
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
        if(p.Results.logScale)
            cmap = [cmap_high(256)];
        else
            cmap = [cmap_high(256)];
        end
    else
        if(p.Results.logScale)
            cmap = [flip(cmap_low(256))];
        else
            cmap = [flip(cmap_low(256))];
        end
    end
    
    c_ind = round(length(cmap)*(C(:) - minVal)/(maxVal - minVal));
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
else
    Cs = repmat(brainColor, size(mdl.v, 1), 1);
end


brainHndl=findobj(gca,'Type','Patch','Tag','Brain');

if(isempty(brainHndl))
   brainHndl=gca; 
   cameratoolbar

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


if(multiprobe)
   probe_colors=lines(num_devices); 
end

mrkScaleFactor=22;

if(showChannels&&isfield(probeInfo, 'TableOpt'))
    optPos = [probeInfo.TableOpt.Pos3D_x probeInfo.TableOpt.Pos3D_y probeInfo.TableOpt.Pos3D_z];
    
    if(~isempty(optColor) && (isnumeric(optColor) && ~any(isnan(optColor)) || ~ismissing(optColor)))
        if(multiprobe)
            uDevices=unique(probeInfo.TableOpt.ProbeNum);
            
            probe_string=cell(0);
            for i=1:num_devices
                selOpt=probeInfo.TableOpt.ProbeNum(:,1)==uDevices(i);
                h(i) = scatter3(optPos(selOpt,1), optPos(selOpt,2), optPos(selOpt,3),20*p.Results.labelfontsize,'filled',optColor,'MarkerEdgeColor' ,probe_colors(i,:),'LineWidth',1.5);
                probe_string{i}=sprintf('Probe %i',uDevices(i));
            end
            legend(h,probe_string);
        else
            h = scatter3(optPos(:,1), optPos(:,2), optPos(:,3),20*p.Results.labelfontsize,'filled',optColor,'MarkerEdgeColor' ,'k');
        end
    end
    text(optPos(:,1), optPos(:,2), optPos(:,3), string(probeInfo.TableOpt.OptodeNum), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
end

if(plotFNIRS_SD&&isfield(probeInfo,'SrcPos3DX'))
    srcIdx=probeInfo.TableSD.Type=='Src';
    detIdx=~srcIdx;
    
    srcPos = [probeInfo.TableSD.Pos3D_x(srcIdx), probeInfo.TableSD.Pos3D_y(srcIdx), probeInfo.TableSD.Pos3D_z(srcIdx)];
    
    if(~isempty(srcColor) && (isnumeric(srcColor) && ~any(isnan(srcColor)) || ~ismissing(srcColor)))
        h = scatter3(srcPos(:,1),srcPos(:,2),srcPos(:,3),mrkScaleFactor*p.Results.labelfontsize,'filled',srcColor);
    end
    text(srcPos(:,1), srcPos(:,2), srcPos(:,3), probeInfo.TableSD.Label(srcIdx), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    hold on
    
    detPos = [probeInfo.TableSD.Pos3D_x(detIdx), probeInfo.TableSD.Pos3D_y(detIdx), probeInfo.TableSD.Pos3D_z(detIdx)];
   
    if(~isempty(detColor) && (isnumeric(detColor) && ~any(isnan(detColor)) || ~ismissing(detColor)))
        h = scatter3(detPos(:,1), detPos(:,2), detPos(:,3), mrkScaleFactor*p.Results.labelfontsize, 'filled', detColor);
    end
    text(detPos(:,1), detPos(:,2), detPos(:,3), probeInfo.TableSD.Label(detIdx), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
end

if(plot1020)

for i=1:size(c1020,1)
    %text(cerebro1020(i,1),cerebro1020(i,2),cerebro1020(i,3),cerebro1020_labels{i})
    if(~isnan(c1020.BA(i)))
        if(numColors == 4 || numColors == 1)
            h = scatter3(c1020.tx(i),c1020.ty(i),c1020.tz(i),mrkScaleFactor*1.5*p.Results.labelfontsize, 'filled', color1020);
        else
            h = scatter3(c1020.tx(i),c1020.ty(i),c1020.tz(i),mrkScaleFactor*1.5*p.Results.labelfontsize, 'filled');
        end
        hold on
        
        text(c1020.tx(i),c1020.ty(i),c1020.tz(i),c1020.Electrode(i),'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor)
        %text(x2tx(c1020.x(i)),y2ty(c1020.y(i)),z2tz(c1020.z(i)),c1020.Electrode(i),'HorizontalAlignment','center')
        
    end
end
end

xlabel('x (L/R)');
ylabel('y (R/C)');
zlabel('z (U/D)');


switch(p.Results.initCamPosition)
    case 'auto'
        campos(OptPos3D_mean/norm(OptPos3D_mean)*1500);   %Front facing
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
        campos(OptPos3D_mean/norm(OptPos3D_mean)*1500);  %Front facing
end
%campos(OptPos3D_mean*25);  %Front facing
camtarget([0,-20,0]);

lht2=findobj(gca,'Type','Light','Tag','Rear');
if(isempty(lht2))
    lht2=camlight('left');
    lht2.Tag='Rear';
    lht2.Position=[0,-100,90];
    lht2.Color=camColor;
else
    
end


title(ax, titleString);
if(p.Results.showColorbar && ~dataEmpty)
    cbars = findobj(gcf, "Type", "ColorBar");
    delete(cbars);
    ax1=ax;
    curAxPosition=ax1.Position;
    
    if(~twosided)
        
        if(maxVal>minVal)
            colormap(ax1,cmap_high(256));
            negColorbar=false;
        else
            colormap(ax1,cmap_low(256));
            temp=minVal;
            minVal=maxVal;
            maxVal=temp;
            negColorbar=true;
        end
        
        chPos=colorbar(ax1);
        
        if(p.Results.logScale)
            set(ax1, 'ColorScale', 'log');
            caxis(ax1, [exp(minVal), exp(maxVal)]);
        else
            caxis(ax1, [minVal, maxVal]);
        end
        
        set(get(chPos, 'title'), 'string', clrBarTitle);
    else
        curAxPosition=ax1.OuterPosition;

        colormap(ax1,cmap_high(256));
        caxis(ax1, [minVal(2), maxVal(2)]);

        ax2=axes('OuterPosition',curAxPosition);
        ax2.Position=ax1.Position;

        set(gca,'xtick',[]);
        set(gca,'ytick',[]);

        %set( chNeg, 'YDir', 'reverse' );
        colormap(ax2,cmap_low(256));
        caxis(ax2, [maxVal(1), minVal(1)]);
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

if(p.Results.showScattering)
    srcIdx=probeInfo.TableSD.Type=='Src';
    detIdx=~srcIdx;
    
    srcPos = [probeInfo.TableSD.Pos3D_x(srcIdx), probeInfo.TableSD.Pos3D_y(srcIdx), probeInfo.TableSD.Pos3D_z(srcIdx)];   
    detPos = [probeInfo.TableSD.Pos3D_x(detIdx), probeInfo.TableSD.Pos3D_y(detIdx), probeInfo.TableSD.Pos3D_z(detIdx)];
    
    optPos = [probeInfo.TableOpt.Pos3D_x, probeInfo.TableOpt.Pos3D_y, probeInfo.TableOpt.Pos3D_z];
    optSrcPos = srcPos(probeInfo.TableOpt.SrcIdx, :);
    optDetPos = detPos(probeInfo.TableOpt.DetIdx, :);
    scatteringFactor = p.Results.scatteringFactor;
    for i=1:length(optSrcPos)
       s = optSrcPos(i,:);
       d = optDetPos(i,:);
       o = optPos(i,:);
       t = linspace(0, pi, 16);
       
       influencePoints = mdl.v(ind == i, :);
       target = mean(influencePoints);
       
       if(isnan(target))
           continue;
       end
       
       % formula for ellipse: C + a cos(theta) U + b sin(theta) V
       b = norm(s - d)/2;
       a = 2 * scatteringFactor * b;
       U = s - d;
       U = U / norm(U);
       V = target-o;
       V = V / norm(V);
       
       line = @(t, r) o + b*cos(t)' .* U + r*a*sin(t)' .* V;
       points1 = line(t, 1);
       points2 = line(t, 1.25);
       points3 = line(t, 0.75);
       plot3(points1(:,1), points1(:,2), points1(:,3), 'k', 'LineWidth', 1);
       plot3(points2(:,1), points2(:,2), points2(:,3), '--k', 'LineWidth', 1);
       plot3(points3(:,1), points3(:,2), points3(:,3), '--k', 'LineWidth', 1);
    end
end

if(p.Results.showReference)
    %% Test code for calibration
    path4debug=mfilename('fullpath');
    
    [path4debug]=fileparts(path4debug);
    
    path4debug=sprintf('%s/../../../',path4debug);
    
    [img,map,alpha] = imread(sprintf('%s%s',path4debug,'sideprofile_mid.png'));     % Load a sample image
    
    %https://www.openanatomy.org/atlases/nac/brain-2017-01/viewer/#!/view/33316a96-32f2-47f4-b5e0-a6225be09803/state/9dc9a3eb-7805-4b2b-943f-0b6e63ba488f

    imgXY=size(img);
    imgRes=1/5.25;
    
    rotx = @(t) [1 0 0; 0 cos(t) -sin(t) ; 0 sin(t) cos(t)] ;
    roty = @(t) [cos(t) 0 sin(t) ; 0 1 0 ; -sin(t) 0  cos(t)] ;
    rotz = @(t) [cos(t) -sin(t) 0 ; sin(t) cos(t) 0 ; 0 0 1] ;
    

    xMid=0;
    yMid=-10;
    zMid=5;
    
    rotX=rotx(10*pi/180);

    
    imgCoord1=[0,imgXY(1)*imgRes,imgXY(2)*imgRes]*rotX;
    imgCoord2=[0,-imgXY(1)*imgRes,imgXY(2)*imgRes]*rotX;
    imgCoord3=[0,imgXY(1)*imgRes,-imgXY(2)*imgRes]*rotX;
    imgCoord4=[0,-imgXY(1)*imgRes,-imgXY(2)*imgRes]*rotX;

    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid];       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid];            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid];   % The z data for the image corners
    
    
    
    
    hold on
    surf(xImage,yImage,zImage,...    % Plot the surface
         'CData',img,...
        'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off

    [img,map,alpha] = imread(sprintf('%s%s',path4debug,'rcSlice.png'));     % Load a sample image


    imgXY=size(img);

    xMid=0;
    yMid=-7;
    zMid=2;


    rotX=rotx(10*pi/180);

    
    imgCoord1=[imgXY(1)*imgRes,0,imgXY(2)*imgRes]*rotX;
    imgCoord2=[-imgXY(1)*imgRes,0,imgXY(2)*imgRes]*rotX;
    imgCoord3=[imgXY(1)*imgRes,0,-imgXY(2)*imgRes]*rotX;
    imgCoord4=[-imgXY(1)*imgRes,0,-imgXY(2)*imgRes]*rotX;

    xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid];       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid];            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid];   % The z data for the image corners

  
    hold on
    surf(xImage,yImage,zImage,...    % Plot the surface
         'CData',img,...
         'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off



    [img,map,alpha]  = imread(sprintf('%s%s',path4debug,'topprofile.png'));     % Load a sample image


    imgXY=size(img);

    xMid=1;
    yMid=-14;
    zMid=-18;
    
    imgCoord1=[imgXY(1)*imgRes,imgXY(2)*imgRes,0]*rotX;
    imgCoord2=[-imgXY(1)*imgRes,imgXY(2)*imgRes,0]*rotX;
    imgCoord3=[imgXY(1)*imgRes,-imgXY(2)*imgRes,0]*rotX;
    imgCoord4=[-imgXY(1)*imgRes,-imgXY(2)*imgRes,0]*rotX;
    
   xImage = [imgCoord1(1)+xMid imgCoord2(1)+xMid; imgCoord3(1)+xMid imgCoord4(1)+xMid];       % The x data for the image corners
    yImage = [imgCoord1(2)+yMid imgCoord2(2)+yMid; imgCoord3(2)+yMid imgCoord4(2)+yMid];            % The y data for the image corners
    zImage = [imgCoord1(3)+zMid imgCoord2(3)+zMid; imgCoord3(3)+zMid imgCoord4(3)+zMid];   % The z data for the image corners

  
    hold on
    surf(xImage,yImage,zImage,...    % Plot the surface
         'CData',img,...
         'FaceColor','texturemap','FaceLighting','none','AlphaData',alpha,'FaceAlpha','texture');
    hold off
end

if (nargout > 0)
    h=gca;
    
    imgOut = getframe(ax).cdata;
end

toc