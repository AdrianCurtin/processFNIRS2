function [ h, imgOut ] = interpolateValues3D(varargin)
% INTERPOLATEVALUES3D Create 3D brain surface visualization with interpolated fNIRS data
%
% Generates a 3D brain surface visualization with fNIRS channel data projected
% onto the cortical surface. Values are interpolated across the brain mesh
% using nearest-neighbor or weighted distance methods. Supports MNI and
% Talairach coordinate systems, multiple probe configurations, EEG 10-20
% electrode positions, Brodmann area overlays, and various visualization options.
%
% Reference:
%   Brain mesh coordinates based on MNI/ICBM templates.
%   10-20 EEG positions from: Koessler, L. et al. (2009). Automated cortical
%   projection of EEG sensors. NeuroImage, 46(1), 64-72.
%
% Syntax:
%   InterpolateValues3D(data2plot)
%   InterpolateValues3D(data2plot, fNIR)
%   InterpolateValues3D(data2plot, fNIR, minVal, maxVal)
%   InterpolateValues3D(data2plot, fNIR, minVal, maxVal, titleString, colorbarStr)
%   [h, imgOut] = InterpolateValues3D(...)
%   InterpolateValues3D(ax, ...)  % Plot to specific axes
%
% Inputs:
%   data2plot     - Values to display for each channel [1 x C double] or
%                   cell array for multi-probe {[1xC1], [1xC2], ...}
%                   Pass [] to show probe geometry without data coloring.
%   fNIR          - fNIRS data structure or probe name string (default: {})
%                   For multi-probe, pass cell array of structs/names.
%   minVal        - Minimum value(s) for color scale (default: min(data2plot))
%                   For two-sided, pass [negMin, posMin].
%   maxVal        - Maximum value(s) for color scale (default: max(data2plot))
%   titleString   - Title displayed above the plot (default: '')
%   colorbarStr   - Title for the colorbar (default: '')
%
% Name-Value Parameters:
%   'ax'                - Target axes handle (default: gca)
%   'ChannelLabels'     - Show channel number labels (default: true)
%   'SDLabels'          - Show source/detector labels (default: varies)
%   'I1020_labels'      - Show 10-20 EEG labels (default: false)
%                         Can be true/false or cell array of electrode names.
%   'useHighRes'        - Use high-resolution brain mesh (default: true)
%   'cmap'              - Colormap for positive values (default: 'hotCropped')
%   'cmap_lower'        - Colormap for negative values (default: 'winter')
%   'labelfontsize'     - Font size for labels (default: 10)
%   'labelfontcolor'    - Font color for labels (default: 'k')
%   'labelspherecolors' - Colors for source/detector spheres (default: ["r","y","w"])
%   'brainColor'        - Base brain surface color (default: [0.92, 0.68, 0.68])
%   'brainAlpha'        - Brain surface transparency (default: 1)
%   'showColorbar'      - Display colorbar (default: true)
%   'initCamPosition'   - Initial camera position (default: 'auto')
%                         Options: 'auto', 'front', 'back', 'top', 'bottom',
%                         'left', 'right', 'face', 'top-left', 'top-right',
%                         'top-front', 'top-back', 'front-left', 'front-right',
%                         'back-left', 'back-right', or numeric [x, y, z].
%   'logScale'          - Use logarithmic color scale (default: false)
%   'interpolateType'   - Interpolation method (default: 'nearest')
%                         Options: 'nearest', 'linear', 'quadratic', 'cubic'
%   'bufferDistance'    - Buffer around optodes in mm (default: auto)
%   'includeSS'         - Include short separation channels (default: varies)
%   'useTalairach'      - Use Talairach coordinates (default: false, uses MNI)
%   'transformToMNI'    - Transform non-MNI coordinates to MNI space (default: 'auto')
%                         'auto': Transform if coordinate system is not MNI and
%                                 landmarks (10-20 electrode positions) are available
%                         true: Always transform (error if no landmarks)
%                         false: Never transform, use original coordinates
%   'BrodmannAreas'     - Highlight Brodmann areas (default: false)
%                         Set true for all areas, or [9,10,46] for specific areas.
%   'showScattering'    - Show light scattering paths (default: false)
%   'optodeLines'       - Show optode direction lines (default: false)
%   'animated'          - Optimize for animation (default: false)
%   'voxelLighting'     - Lighting style for voxel brain (default: 'none')
%                         Options: 'none', 'realistic', 'dramatic', 'clinical'
%
% Outputs:
%   h      - Handle to the axes containing the visualization
%   imgOut - RGB image capture of the rendered figure [H x W x 3 uint8]
%
% Example:
%   % Basic 3D visualization of HbO data
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   hboVals = processed.HbO(100, :);  % Single timepoint
%   pf2.probe.plot.interpolateValues3D(hboVals, processed, -1, 1, 'HbO');
%
%   % Show probe geometry without data
%   pf2.probe.plot.interpolateValues3D([], processed, 'initCamPosition', 'front');
%
%   % Multi-probe visualization
%   pf2.probe.plot.interpolateValues3D({hbo1, hbo2}, {fnir1, fnir2});
%
%   % Show with Brodmann areas
%   pf2.probe.plot.interpolateValues3D([], processed, 'BrodmannAreas', [9,10,46]);
%
% Notes:
%   - Requires cerebro_mdl.mat brain mesh data file
%   - Short separation channels are excluded by default when data is provided
%   - Uses 'animated' mode for video generation to avoid redrawing static elements
%
% See also: pf2.probe.plot.showProbe3D, pf2.probe.plot.interpolateValues,
%           pf2.probe.plot.imageValues, exploreFNIRS
isStructOrEmpty=@(x) isstruct(x)||isempty(x);
isStringOrChar=@(x)isstring(x)||ischar(x);

validAxesHandle= @(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x);
validScalarPosNumOr0 = @(x) isnumeric(x) && x>=0;
validScalarPosNum = @(x) isnumeric(x) && x>0;
validScalarPosNumOrNan = @(x) isnumeric(x) && (x>0||isnan(x));
validI1020Label = @(x) islogical(x) || isStringOrChar(x) || iscell(x);
validBrodmann = @(x) islogical(x) || isnumeric(x)&&all(x<=55)&&all(x>0);
validColor = @(x) (ischar(x) && length(x) == 1) || (isnumeric(x) && length(x) == 3) || isempty(x);
validFnirs = @(x) isStructOrEmpty(x) || iscell(x);
%validColorList = @(x) validColor(x) || all(arrayfun(validColor, x));

defaultInterpolateType = 'nearest';
validInterpolateTypes = {'nearest', 'linear', 'quadratic', 'cubic'};
validInterpolateType = @(x) any(validatestring(x, validInterpolateTypes));

defaultCamPosition = 'auto';
validCamPositions = {'auto','front', 'back', 'top', 'bottom', 'left', 'right', 'face', ...
    'top-left', 'top-right', 'top-front', 'top-back', ...
    'front-left', 'front-right', 'back-left', 'back-right'};
validCamPosition = @(x) ((isstring(x)||ischar(x))&&any(validatestring(x, validCamPositions))) || (isnumeric(x) && length(x) == 3);

defaultColormap = 'hotCropped';
defaultColormapLow = 'winter';

cropFn = @(var,n) var(end-n+1:end,:);
hotCropped = @(n) cropFn(hot(ceil(n*1.25)),n);

validColormapLabels = exploreFNIRS.helper.listColormaps('all');
validColormap = @(x) (isnumeric(x)&&(size(x,2)==3))||isa(x,'function_handle') || any(ishandle(x)) || any(validatestring(x, validColormapLabels));

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




p_pre=inputParser;
p=inputParser;

addOptional(p_pre,'data2plot', []);

parse(p_pre,varargin{1});
data2plot = p_pre.Results.data2plot;
shouldHideByDefault = isempty(data2plot);

addOptional(p,'data2plot', []);
addOptional(p,'fNIR', {}, validFnirs);
addOptional(p,'minval', [], @isnumeric);
addOptional(p,'maxval', [], @isnumeric);
addOptional(p,'titleString', '', isStringOrChar);
addOptional(p,'colorbarStr', '', isStringOrChar);


addParameter(p,'ax',ax,validAxesHandle,'PartialMatchPriority',1);
addParameter(p,'ChannelLabels',true,@islogical);
addParameter(p,'SDLabels',shouldHideByDefault,@islogical);
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
addParameter(p, 'includeSS', shouldHideByDefault, @islogical);
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
addParameter(p, 'voxelLighting', 'none', @(x) ischar(x) || isstring(x));
centerCamPos=[0,-20,0];
addParameter(p, 'camTarget', centerCamPos, validCamPosition); % Target Camera location
addParameter(p, 'camUp', [0,0,1] , validCamPosition); % Target Camera location
addParameter(p, 'animated', false, @islogical); % Optimizes for animation (By not redrawing certain things when possible)
addParameter(p, 'transformToMNI', 'auto', @(x) islogical(x) || (ischar(x) && strcmpi(x, 'auto'))); % Transform non-MNI coords to MNI
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);


parse(p,varargin{:});



data2plot = p.Results.data2plot;
titleString = p.Results.titleString;
clrBarTitle = p.Results.colorbarStr;
projectmode = p.Results.interpolateType;
bufferDistance=p.Results.bufferDistance;
include_ss=p.Results.includeSS;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;


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
    data2plot_concat = concat_data(:);
else
    data2plot_concat=data2plot{1}(:);
end

fNIR = p.Results.fNIR;

% Unwrap single-element cell of config name string for single-probe mode
if iscell(fNIR) && numel(fNIR) == 1 && (isstring(fNIR{1}) || ischar(fNIR{1}))
    fNIR = fNIR{1};
end

% Store config name for downstream loading (don't load yet)
fNIR_cfgOverride = '';
if (isstring(fNIR) || ischar(fNIR)) && ~isempty(fNIR)
    fNIR_cfgOverride = char(fNIR);
    if ~endsWith(fNIR_cfgOverride, '.cfg')
        fNIR_cfgOverride = [fNIR_cfgOverride '.cfg'];
    end
    fNIR = {};  % clear so downstream treats as empty struct
end

if isempty(fNIR) && ~p.Results.useEEG
    if multiprobe
        error("Must specify FNIRS devices when using Multi-probe plotting")
    end
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
        if(nanmax(data2plot_concat)<max(minVal))
            hasUpperData=false;
        else
            hasUpperData=true;
        end
        dataMinVal=min(min(minVal)-1e-3,nanmin(data2plot_concat));
        cbarLower_minmax=[dataMinVal min(minVal)];
        if(nanmin(data2plot_concat)>min(minVal))
            hasLowerData=false;
        else        
            hasLowerData=true;
        end
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

% Default hasUpperData/hasLowerData when maxVal was explicitly provided
if twosided && ~exist('hasUpperData', 'var')
    hasUpperData = true;
end
if twosided && ~exist('hasLowerData', 'var')
    hasLowerData = true;
end

if(p.Results.logScale)
    if(any(data2plot_concat<=0))
        error("Cannot use logscale when data contains negative values")
    end
    data2plot_concat = log(data2plot_concat);
    cbarLower_minmax=log(cbarUpper_minmax);
    cbarUpper_minmax=log(cbarUpper_minmax);
end



cmap_high = p.Results.cmap;
if(~isa(cmap_high,'function_handle'))
    if(strcmp(cmap_high,'hotCropped'))
        cmap_high=hotCropped;
    else
        cmap_high = str2func(cmap_high);
    end
end

cmap_low_t = p.Results.cmap_lower;
if(~isa(cmap_low_t,'function_handle'))
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
    item = findobj(ax, "Tag", itemsToDelete{i});
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
        
        nData=length(data2plot{i});
        nOpt=probeInfos{i}.NumOptodes;
        nSS=probeInfos{i}.NumShortSeparation;
        if(~dataEmpty(i) && (include_ss&&nData~=nOpt...
                || (~include_ss&&nData~=(nOpt-nSS))))
            error('Must have a value for all optodes');
        end
        clear nData nOpt nSS
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
    elseif ~isempty(fNIR_cfgOverride)
        cfgFilePath = fNIR_cfgOverride;
    elseif(isfield(fNIR,'probeinfo'))
        probeInfo=fNIR.probeinfo;
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
    c1020=pf2_base.getAsset('cerebro_1020'); %estimation of 10-20 coordinates
    
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

% Apply MNI transformation if needed
transformOpt = p.Results.transformToMNI;
if isfield(probeInfo, 'TableOpt') && ~p.Results.useEEG
    doTransform = false;
    fNIR_orig = p.Results.fNIR;
    if iscell(fNIR_orig) && ~isempty(fNIR_orig)
        fNIR_orig = fNIR_orig{1};
    end

    if ischar(transformOpt) && strcmpi(transformOpt, 'auto')
        % Auto: transform if coordinate system is not MNI and landmarks exist
        if isstruct(fNIR_orig) && isfield(fNIR_orig, 'device')
            dev = fNIR_orig.device;
            if isa(dev, 'pf2.Device')
                coordSys = dev.CoordinateSystem;
                hasLandmarks = ~isempty(dev.Landmarks);
            elseif isstruct(dev)
                coordSys = '';
                if isfield(dev, 'CoordinateSystem')
                    coordSys = dev.CoordinateSystem;
                end
                hasLandmarks = isfield(dev, 'Landmarks') && ~isempty(dev.Landmarks);
            else
                coordSys = '';
                hasLandmarks = false;
            end
            % Transform if not already in MNI and landmarks available
            if hasLandmarks && ~strcmpi(coordSys, 'MNI') && ~isempty(coordSys) && ~strcmpi(coordSys, 'Unknown')
                doTransform = true;
            end
        end
    elseif islogical(transformOpt) && transformOpt
        % Explicit true: always transform
        doTransform = true;
    end

    if doTransform
        % Get all coordinates to transform
        optCoords = [probeInfo.TableOpt.Pos3D_x, probeInfo.TableOpt.Pos3D_y, probeInfo.TableOpt.Pos3D_z];
        srcCoords = [probeInfo.TableSD.Pos3D_x(probeInfo.TableSD.Type == 'Src'), ...
                     probeInfo.TableSD.Pos3D_y(probeInfo.TableSD.Type == 'Src'), ...
                     probeInfo.TableSD.Pos3D_z(probeInfo.TableSD.Type == 'Src')];
        detCoords = [probeInfo.TableSD.Pos3D_x(probeInfo.TableSD.Type ~= 'Src'), ...
                     probeInfo.TableSD.Pos3D_y(probeInfo.TableSD.Type ~= 'Src'), ...
                     probeInfo.TableSD.Pos3D_z(probeInfo.TableSD.Type ~= 'Src')];

        try
            % Transform all coordinate sets using the same transformation
            [optMNI, T] = pf2.probe.transformToMNI(optCoords, fNIR_orig);
            srcMNI = T.s * (srcCoords * T.R) + T.t;
            detMNI = T.s * (detCoords * T.R) + T.t;

            % Update probeInfo with transformed coordinates
            probeInfo.TableOpt.Pos3D_x = optMNI(:, 1);
            probeInfo.TableOpt.Pos3D_y = optMNI(:, 2);
            probeInfo.TableOpt.Pos3D_z = optMNI(:, 3);
            probeInfo.OptPos.x = optMNI(:, 1);
            probeInfo.OptPos.y = optMNI(:, 2);
            probeInfo.OptPos.z = optMNI(:, 3);

            srcIdx = probeInfo.TableSD.Type == 'Src';
            probeInfo.TableSD.Pos3D_x(srcIdx) = srcMNI(:, 1);
            probeInfo.TableSD.Pos3D_y(srcIdx) = srcMNI(:, 2);
            probeInfo.TableSD.Pos3D_z(srcIdx) = srcMNI(:, 3);
            probeInfo.TableSD.Pos3D_x(~srcIdx) = detMNI(:, 1);
            probeInfo.TableSD.Pos3D_y(~srcIdx) = detMNI(:, 2);
            probeInfo.TableSD.Pos3D_z(~srcIdx) = detMNI(:, 3);

            % Update mean position
            probeInfo.OptPos3D_mean = mean(optMNI, 1, 'omitnan');

        catch ME
            if islogical(transformOpt) && transformOpt
                % Explicit request to transform but failed
                error('pf2:probe:plot:interpolateValues3D:transformFailed', ...
                    'Failed to transform coordinates to MNI: %s', ME.message);
            end
            % Auto mode: silently fall back to original coordinates
        end
    end
end

if(isfield(probeInfo, 'TableOpt'))
    if(~isfield(probeInfo,'NumShortSeparation'))
        probeInfo.NumShortSeparation =0;
    end
    if(include_ss&&probeInfo.NumOptodes>length(data2plot_concat)&&probeInfo.NumOptodes-probeInfo.NumShortSeparation==length(data2plot_concat))
        include_ss=false;
        warning('Not enough data for all channels, ignoring short separation channels');
    end
    
    includeChannels=probeInfo.TableOpt.HasData&(include_ss|~probeInfo.TableOpt.IsShortSeparation);
    
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

if(~include_ss && isfield(probeInfo, 'TableOpt'))
    includeChannels=includeChannels&~probeInfo.TableOpt.IsShortSeparation;

    if(length(data2plot_concat)>sum(includeChannels))
        data2plot_concat=data2plot_concat(includeChannels);
    end
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
h=gca;
if(useHighRes)
    cerebro_mdl=pf2_base.getAsset('cerebro_mdl', 'cache', h);    %high res model
else
    cerebro_mdl=pf2_base.getAsset('cerebro_mdl_05', 'cache', h); %low res model
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

% Voxel brain lighting presets
switch lower(p.Results.voxelLighting)
    case 'realistic'
        voxKa = 0.7;   voxKd = 0.5;  voxKs = 0.25;  voxSE = 12;
    case 'dramatic'
        voxKa = 0.5;   voxKd = 0.65; voxKs = 0.4;   voxSE = 25;
    case 'clinical'
        voxKa = 0.65;  voxKd = 0.55; voxKs = 0.1;   voxSE = 8;
    otherwise % 'none'
        voxKa = ka;    voxKd = kd;   voxKs = ks;     voxSE = 10;
end
useVoxelLighting = ~strcmpi(p.Results.voxelLighting, 'none');

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



if(p.Results.showVoxelBrain&&(isempty(itemsToSkipPlot)||~contains(itemsToSkipPlot,'BrainVoxel')))
    h=ax;
    mni_t1=pf2_base.getAsset('mni_t1', 'cache', h);

    center=[91,127,73];

    voxelRes=1;

    % Check for cached isosurface mesh
    cacheKey = 'voxelISOmesh';
    cached = getappdata(ax, cacheKey);

    if ~isempty(cached)
        % Reuse cached mesh
        if isfield(cached, 'brodmann') && ~isempty(cached.brodmann)
            for ci = 1:length(cached.brodmann)
                cb = cached.brodmann(ci);
                h = patch('Faces', cb.faces, 'Vertices', cb.verts, ...
                    'FaceVertexCData', cb.colors, 'FaceColor', 'interp', ...
                    'EdgeColor', 'none');
                h.DisplayName = cb.displayName;
                h.Tag = 'BA_area_mrk';
                hold on
            end
            legend();
        end
        if isfield(cached, 'background') && ~isempty(cached.background)
            bg = cached.background;
            h = patch('Faces', bg.faces, 'Vertices', bg.verts, ...
                'FaceVertexCData', bg.colors, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', ...
                'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                'FaceAlpha', 1);
            h.Tag = 'BrainVoxel';
            h.HandleVisibility = 'off';
            hold on
        end
        if isfield(cached, 'brain') && ~isempty(cached.brain)
            br = cached.brain;
            h = patch('Faces', br.faces, 'Vertices', br.verts, ...
                'FaceVertexCData', br.colors, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'VertexNormals', br.normals, ...
                'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                'FaceAlpha', 1);
            h.Tag = 'BrainVoxel';
            h.HandleVisibility = 'off';
            hold on
        end
        if useVoxelLighting
            lighting('gouraud');
        else
            lighting('none');
        end
    else
        % Compute isosurface meshes from scratch
        isoCache = struct('brodmann', [], 'background', [], 'brain', []);

        if useVoxelLighting
            lighting('gouraud');
        else
            lighting('none');
        end

        if(p.Results.useVoxelBrodmannAreas)
            brdm=pf2_base.getAsset('brodmann', 'cache', ax);
            brdm=brdm(1:voxelRes:end,1:voxelRes:end,1:voxelRes:end);

            origMni = mni_t1; % preserve intensity before zeroing BA voxels

            if(showBrodmann)
                brainColmap=p.Results.BA_cmp(length(BA_areas));
                brodmannCache = [];

                for i=1:length(BA_areas)
                    mask = (brdm == BA_areas(i));
                    if ~any(mask(:)), continue; end

                    % Zero out these voxels from T1 so background doesn't overlap
                    mni_t1(mask) = 0;

                    % Pad to avoid edge artifacts, smooth for clean surface
                    maskPad = padarray(double(mask), [1 1 1], 0);
                    maskSmooth = smooth3(maskPad, 'gaussian', [3 3 3]);
                    [f, v] = isosurface(maskSmooth, 0.3);

                    if isempty(f), continue; end

                    v = v - 1; % undo padarray offset

                    % MNI transform: isosurface returns (col, row, slice)
                    v_mni = [v(:,2) - center(1), v(:,1) - center(2), v(:,3) - center(3)];

                    % Intensity-modulated color from original T1
                    vInt = interp3(double(origMni), v(:,1), v(:,2), v(:,3), 'linear', 0);
                    vColors = brainColmap(i,:) .* (vInt/255/3 + 0.66);

                    h = patch('Faces', f, 'Vertices', v_mni, ...
                        'FaceVertexCData', vColors, 'FaceColor', 'interp', ...
                        'EdgeColor', 'none');
                    h.DisplayName = sprintf('BA%i', BA_areas(i));
                    h.Tag = 'BA_area_mrk';
                    hold on

                    % Store for cache
                    entry = struct('faces', f, 'verts', v_mni, 'colors', vColors, ...
                        'displayName', sprintf('BA%i', BA_areas(i)));
                    if isempty(brodmannCache)
                        brodmannCache = entry;
                    else
                        brodmannCache(end+1) = entry; %#ok<AGROW>
                    end
                end
                legend();
                isoCache.brodmann = brodmannCache;
            end

            % Remaining Brodmann voxels (background)
            if useVoxelLighting
                lighting('gouraud');
            else
                lighting('none');
            end
            remainMask = brdm > 0 & ~ismember(brdm, BA_areas);
            mni_bg = double(mni_t1) .* double(remainMask);

            if any(mni_bg(:) > 0)
                mni_t1(remainMask) = 0;

                bgPad = padarray(mni_bg, [1 1 1], 0);
                bgSmooth = smooth3(bgPad, 'gaussian', [3 3 3]);
                [bgF, bgV] = isosurface(bgSmooth, 10);

                if ~isempty(bgF)
                    bgV = bgV - 1; % undo padarray offset
                    bgV_mni = [bgV(:,2) - center(1), bgV(:,1) - center(2), bgV(:,3) - center(3)];

                    % Sample at multiple depths inward, take max to avoid dark sulci
                    bgN = isonormals(bgSmooth, bgV + 1); % +1 to match padded coords
                    bgN_mag = max(sqrt(sum(bgN.^2, 2)), eps);
                    bgN_unit = bgN ./ bgN_mag;
                    origMni_dbl = double(origMni);
                    bgInt = zeros(size(bgV, 1), 1);
                    for sd = [3, 6, 10, 15]
                        bgSPts = bgV - sd * bgN_unit;
                        bgSPts = max(bgSPts, 1);
                        bgSPts(:,1) = min(bgSPts(:,1), size(origMni,2));
                        bgSPts(:,2) = min(bgSPts(:,2), size(origMni,1));
                        bgSPts(:,3) = min(bgSPts(:,3), size(origMni,3));
                        bgInt = max(bgInt, interp3(origMni_dbl, bgSPts(:,1), bgSPts(:,2), bgSPts(:,3), 'linear', 0));
                    end
                    bgInt = max(bgInt, 100); % brightness floor
                    bgColors = p.Results.voxelColor .* (bgInt / 255);

                    h = patch('Faces', bgF, 'Vertices', bgV_mni, ...
                        'FaceVertexCData', bgColors, 'FaceColor', 'interp', ...
                        'EdgeColor', 'none', ...
                        'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                        'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                        'FaceAlpha', 1);
                    h.Tag = 'BrainVoxel';
                    h.HandleVisibility = 'off';
                    hold on

                    isoCache.background = struct('faces', bgF, 'verts', bgV_mni, 'colors', bgColors);
                end
            end
            legend();

        else
            % Non-Brodmann voxel brain path
            vol = smooth3(double(mni_t1), 'gaussian', [3 3 3]);
            isoVal = 20;
            [isoF, isoV] = isosurface(vol, isoVal);
            isoN = isonormals(vol, isoV);

            % MNI transform: isosurface returns (col, row, slice)
            isoV_mni = [isoV(:,2) - center(1), isoV(:,1) - center(2), isoV(:,3) - center(3)];

            % Per-vertex intensity coloring — sample at multiple depths inward
            % and take the max to avoid dark patches from sulci/ventricles.
            % isonormals returns outward-pointing normals (toward smaller values).
            isoN_mag = max(sqrt(sum(isoN.^2, 2)), eps);
            isoN_unit = isoN ./ isoN_mag;
            mni_dbl = double(mni_t1);
            sampleDepths = [3, 6, 10, 15]; % multiple depths in voxels
            vInt = zeros(size(isoV, 1), 1);
            for sd = sampleDepths
                sPts = isoV - sd * isoN_unit;
                sPts = max(sPts, 1);
                sPts(:,1) = min(sPts(:,1), size(mni_t1,2));
                sPts(:,2) = min(sPts(:,2), size(mni_t1,1));
                sPts(:,3) = min(sPts(:,3), size(mni_t1,3));
                vInt = max(vInt, interp3(mni_dbl, sPts(:,1), sPts(:,2), sPts(:,3), 'linear', 0));
            end
            vInt = max(vInt, 100); % brightness floor for any remaining dark vertices
            vColors = p.Results.voxelColor .* (vInt / 255);

            h = patch('Faces', isoF, 'Vertices', isoV_mni, ...
                'FaceVertexCData', vColors, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'VertexNormals', -isoN, ...
                'AmbientStrength', voxKa, 'DiffuseStrength', voxKd, ...
                'SpecularStrength', voxKs, 'SpecularExponent', voxSE, ...
                'FaceAlpha', 1);
            h.Tag = 'BrainVoxel';
            h.HandleVisibility = 'off';
            if useVoxelLighting
                lighting('gouraud');
            else
                lighting('none');
            end
            hold on

            isoCache.brain = struct('faces', isoF, 'verts', isoV_mni, ...
                'colors', vColors, 'normals', -isoN);
        end

        % Store computed mesh in cache
        setappdata(ax, cacheKey, isoCache);
    end

    % Add camera lights when voxel lighting is active
    if useVoxelLighting
        lht = findobj(ax, 'Type', 'Light', 'Tag', 'Front');
        if isempty(lht)
            lht = camlight('right');
            lht.Tag = 'Front';
            lht.Color = camColor;
            lht.Position = [0, 100, 0];
        end
        lht2 = findobj(ax, 'Type', 'Light', 'Tag', 'Rear');
        if isempty(lht2)
            lht2 = camlight('left');
            lht2.Tag = 'Rear';
            lht2.Position = [0, -100, 90];
            lht2.Color = camColor;
        end
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
    
    if animationOptimized
        cache = getappdata(ax, 'iv3d_distCache');
        if ~isempty(cache) && size(cache.dist_array, 2) == num_control
            dist_array = cache.dist_array;
            ind = cache.ind;
        else
            dist_array = sum(mdl.v.^2, 2) + sum(controlPoints.^2, 2)' - 2 * (mdl.v * controlPoints');
            [d, ind] = min(dist_array, [], 2);
            ind(d > max_distance_2) = 0;
            setappdata(ax, 'iv3d_distCache', struct('dist_array', dist_array, 'ind', ind));
        end
    else
        dist_array = sum(mdl.v.^2, 2) + sum(controlPoints.^2, 2)' - 2 * (mdl.v * controlPoints');
        [d, ind] = min(dist_array, [], 2);
        ind(d > max_distance_2) = 0;
    end

    % Exclude NaN channels from interpolation (e.g. masked-out channels)
    nanChannels = isnan(C);
    if any(nanChannels)
        dist_array(:, nanChannels) = Inf;
        [d, ind] = min(dist_array, [], 2);
        ind(d > max_distance_2) = 0;
        ind(isinf(d)) = 0;
        C(nanChannels) = 0;
    end

    c_min = nanmin(C, [], 'all');
    c_max = nanmax(C, [], 'all');
    
    if(isnumeric(cmap_high))
        nColorsMaxBar=size(cmap_high,1);
    else
        nColorsMaxBar=1024;
    end
    cbarUpperRange=max(cbarUpper_minmax)-min(cbarUpper_minmax);

    mapWithAlpha = @(cmap, isUpper) [cmap, [linspace( 1* ~isUpper, 1*isUpper, size(cmap(1:floor(end/3),:), 1)).^(0.5)'; ones(size(cmap(floor(end*1/3)+1:end,1)))]];
   
    
    if twosided
        cbarLowerRange = max(cbarLower_minmax) - min(cbarLower_minmax);
        cbarRangeFull = max(cbarUpper_minmax) - min(cbarLower_minmax);
        cbarOverlappingRange = max(cbarLower_minmax) - min(cbarUpper_minmax);
        cbarIsOverlapping = cbarOverlappingRange > 0;
        
        fracUpper = cbarUpperRange / cbarRangeFull;
        fracLower = cbarLowerRange / cbarRangeFull;
        fracOverlap = cbarOverlappingRange / cbarRangeFull;
        
        nColorLower = floor(fracLower * nColorsMaxBar) + 1;
        nColorUpper = floor(fracUpper * nColorsMaxBar) + 1;
        nOverlap = floor(fracOverlap * nColorsMaxBar) + 1;
   
        if cbarIsOverlapping
            cmap = [mapWithAlpha(cmap_low(nColorLower),false); repmat([brainColor,1], nOverlap, 1); mapWithAlpha(cmap_high(nColorUpper),true)];
        else
            cmap = [mapWithAlpha(cmap_low(nColorLower),false); mapWithAlpha(cmap_high(nColorUpper),true)];
        end
        
        % Normalize C to the range [0, 1] based on the full range
        c_ind = (C(:) - min(cbarLower_minmax)) / cbarRangeFull;
        
        % Create a mask for values that should not be colorized
        mask = (C(:) > max(cbarLower_minmax)) & (C(:) < min(cbarUpper_minmax));
    else
        if ~negColorbar
            if(isnumeric(cmap_high))
                cmap = cmap_high;
            else
                cmap = cmap_high(nColorsMaxBar);
            end
            
        else
            if(isnumeric(cmap_low))
                cmap = flip(cmap_low);
            else
                cmap = flip(cmap_low(nColorsMaxBar));
            end
           
        end

        cmap = mapWithAlpha(cmap,~negColorbar);
        
        c_ind = (C(:) - min(cbarUpper_minmax)) / (max(cbarUpper_minmax) - min(cbarUpper_minmax));
        mask = false(size(C));
    end

    % blend cmap with brainColor according to alpha
    cmap = cmap .* cmap(:, 4) + repmat([brainColor(1:3),1], size(cmap, 1), 1) .* (1 - cmap(:, 4));

    switch projectmode
        case 'nearest'
            C_temp = [brainColor; reshape(ind2rgb(round(c_ind * (size(cmap, 1) - 1)) + 1, cmap),[],3)];
            C_temp([-1; c_ind] < 0, :) = repmat(brainColor, sum(c_ind < 0) + 1, 1);
            C_temp(mask, :) = repmat(brainColor, sum(mask), 1);
            
            Cs = C_temp(ind + 1, :);
            
        case {'linear', 'quadratic', 'cubic'}
            switch projectmode
                case 'linear'
                    beta = 0.5;
                case 'quadratic'
                    beta = 1;
                case 'cubic'
                    beta = 1.5;
            end
            
            dist_array(dist_array >= max_distance_2) = Inf;
            my_interp_fx = @(dist, val, pow, dim) sum(val .* (1./(dist.^pow + 1e-8)) ./ sum(1./(dist.^pow + 1e-8), dim), dim);
            
            C_temp = repmat(c_ind', num_vertices, 1);
            v_ind = my_interp_fx(dist_array, C_temp, beta, 2);

            Cs = reshape(ind2rgb(round(v_ind * (size(cmap, 1) - 1)) + 1, cmap), [], 3);

            % Build per-vertex mask: vertices near only masked channels
            if any(mask)
                mask_weights = double(mask(:))';
                v_mask = my_interp_fx(dist_array, repmat(mask_weights, num_vertices, 1), beta, 2) > 0.5;
            else
                v_mask = false(size(v_ind));
            end
            Cs(v_ind < 0 | v_mask, :) = repmat(brainColor, sum(v_ind < 0 | v_mask), 1);
            Cs(ind == 0, :) = repmat(brainColor, sum(ind == 0), 1);
    end

    % Distance-based edge fading: smooth transition to brain color at buffer boundary
    validVerts = ind > 0;
    if any(validVerts)
        vIdx = find(validVerts);
        d_nearest = dist_array(sub2ind(size(dist_array), vIdx, ind(validVerts)));
        d_ratio = sqrt(d_nearest / max_distance_2);  % 0 at channel, 1 at boundary
        fadeAlpha = max(0, min(1, (1 - d_ratio) / 0.4));  % fade over outer 40%
        Cs(vIdx,:) = Cs(vIdx,:) .* fadeAlpha + brainColor .* (1 - fadeAlpha);
    end

else % No data to plot, everything is brain and anatomy
    Cs = repmat(brainColor, size(mdl.v, 1), 1);
    
    if(showBrodmann&&~p.Results.showVoxelBrain)
        
        
        brainColmap=[brainColor;p.Results.BA_cmp(length(BA_areas));];
        
        
        
        if(p.Results.useVoxelBrodmannAreas)

            h=ax;
            brdm=pf2_base.getAsset('brodmann', 'cache', h);

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
    brainHndl=findobj(ax,'Type','Patch','Tag','Brain');
    
    if(isempty(brainHndl))
        brainHndl=ax;
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

% Project channel data onto voxel brain isosurface when both are active
if p.Results.showVoxelBrain && ~all(dataEmpty)
    voxelPatches = findall(ax, 'Type', 'Patch', 'Tag', 'BrainVoxel');
    for vi = 1:length(voxelPatches)
        vp = voxelPatches(vi);
        vpVerts = get(vp, 'Vertices');
        vpBaseColors = get(vp, 'FaceVertexCData');
        nv = size(vpVerts, 1);

        % Distance from each isosurface vertex to each channel control point
        vp_dist = sum(vpVerts.^2, 2) + sum(controlPoints.^2, 2)' - 2 * (vpVerts * controlPoints');
        [vp_d, vp_ind] = min(vp_dist, [], 2);
        vp_ind(vp_d > max_distance_2) = 0;

        % Handle NaN channels
        if exist('nanChannels', 'var') && any(nanChannels)
            vp_dist(:, nanChannels) = Inf;
            [vp_d, vp_ind] = min(vp_dist, [], 2);
            vp_ind(vp_d > max_distance_2) = 0;
            vp_ind(isinf(vp_d)) = 0;
        end

        vpCs = vpBaseColors;
        hasData = vp_ind > 0;

        if any(hasData)
            switch projectmode
                case 'nearest'
                    C_temp = [brainColor; reshape(ind2rgb(round(c_ind * (size(cmap, 1) - 1)) + 1, cmap), [], 3)];
                    C_temp([-1; c_ind] < 0, :) = repmat(brainColor, sum(c_ind < 0) + 1, 1);
                    if exist('mask', 'var') && any(mask)
                        C_temp(mask, :) = repmat(brainColor, sum(mask), 1);
                    end
                    projColors = C_temp(vp_ind(hasData) + 1, :);

                case {'linear', 'quadratic', 'cubic'}
                    switch projectmode
                        case 'linear',    beta_vp = 0.5;
                        case 'quadratic', beta_vp = 1;
                        case 'cubic',     beta_vp = 1.5;
                    end
                    vp_dist(vp_dist >= max_distance_2) = Inf;
                    vp_C_temp = repmat(c_ind', nv, 1);
                    vp_interp = @(dist, val, pow, dim) sum(val .* (1./(dist.^pow + 1e-8)) ./ sum(1./(dist.^pow + 1e-8), dim), dim);
                    vp_v_ind = vp_interp(vp_dist, vp_C_temp, beta_vp, 2);
                    projColors = reshape(ind2rgb(round(vp_v_ind(hasData) * (size(cmap, 1) - 1)) + 1, cmap), [], 3);

                    if exist('mask', 'var') && any(mask)
                        mask_weights = double(mask(:))';
                        vp_v_mask = vp_interp(vp_dist, repmat(mask_weights, nv, 1), beta_vp, 2) > 0.5;
                        projColors(vp_v_mask(hasData) | vp_v_ind(hasData) < 0, :) = ...
                            repmat(brainColor, sum(vp_v_mask(hasData) | vp_v_ind(hasData) < 0), 1);
                    else
                        projColors(vp_v_ind(hasData) < 0, :) = ...
                            repmat(brainColor, sum(vp_v_ind(hasData) < 0), 1);
                    end
            end

            % Edge fading
            d_nearest = vp_dist(sub2ind(size(vp_dist), find(hasData), vp_ind(hasData)));
            d_ratio = sqrt(d_nearest / max_distance_2);
            fadeAlpha = max(0, min(1, (1 - d_ratio) / 0.4));

            % Blend projected color with base voxel color
            vpCs(hasData, :) = projColors .* fadeAlpha + vpBaseColors(hasData, :) .* (1 - fadeAlpha);
        end

        set(vp, 'FaceVertexCData', vpCs);
    end
end

if(multiprobe)
    probe_colors=lines(num_devices);
end

mrkScaleFactor=22;

% Nudge scatter markers slightly inward so text always wins depth test.
% 0.5mm is imperceptible but resolves z-fighting between co-located objects.
markerInsetMM = 0.001;
insetPos = @(pos) pos - markerInsetMM * pos ./ max(vecnorm(pos, 2, 2), 1e-6);

if(showChannels&&isfield(probeInfo, 'TableOpt')&&~contains('ProbeOpt',itemsToSkipPlot))
    optPos = [probeInfo.TableOpt.Pos3D_x probeInfo.TableOpt.Pos3D_y probeInfo.TableOpt.Pos3D_z];

    if(~include_ss)
        optPos=optPos(~probeInfo.TableOpt.IsShortSeparation,:);
    end

    if(p.Results.useTalairach)
        optPos=pf2_base.external.icbm_fsl2tal(optPos);
    end

    optPosInset = insetPos(optPos);

    if(~isempty(optColor) && (isnumeric(optColor) && ~any(isnan(optColor(:))) || (isstring(optColor) && ~any(ismissing(optColor)))))
        if(multiprobe)
            uDevices=unique(probeInfo.TableOpt.ProbeNum);

            probe_string=cell(0);
            for i=1:num_devices

                selOpt=probeInfo.TableOpt.ProbeNum(:,1)==uDevices(i);
                if(~include_ss)
                    selOpt(probeInfo.TableOpt.IsShortSeparation)=[];
                end
                h(i) = scatter3(optPosInset(selOpt,1), optPosInset(selOpt,2), optPosInset(selOpt,3),20*p.Results.labelfontsize,'filled',optColor,'MarkerEdgeColor' ,probe_colors(i,:),'LineWidth',1.5);

                probe_string{i}=sprintf('Probe %i',uDevices(i));

                h(i).Tag='ProbeOpt';
                h(i).DisplayName=probe_string{i};
            end
            legend(h,probe_string);
        else
            h = scatter3(optPosInset(:,1), optPosInset(:,2), optPosInset(:,3),20*p.Results.labelfontsize,'filled',optColor,'MarkerEdgeColor' ,'k');
            h.Tag='ProbeOpt';
            h.DisplayName='Optode';
        end
    end

    if(include_ss)
        h=text(optPos(:,1), optPos(:,2), optPos(:,3), string(probeInfo.TableOpt.OptodeNum), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    else
        h=text(optPos(:,1), optPos(:,2), optPos(:,3), string(probeInfo.TableOpt.OptodeNum(~probeInfo.TableOpt.IsShortSeparation)), 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    end
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
    
    srcPosInset = insetPos(srcPos);
    if(~isempty(srcColor) && (isnumeric(srcColor) && ~any(isnan(srcColor)) || ~ismissing(srcColor)))
        h = scatter3(srcPosInset(:,1),srcPosInset(:,2),srcPosInset(:,3),mrkScaleFactor*p.Results.labelfontsize,'filled',srcColor);
        h.Tag=sprintf('ProbeSrc');
        h.DisplayName='Source';
    end
    h=text(srcPos(:,1), srcPos(:,2), srcPos(:,3), srcLabels, 'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
    for i=1:length(h)
        h(i).Tag='ProbeSrcLabel';
    end
    hold on

    detPosInset = insetPos(detPos);
    if(~isempty(detColor) && (isnumeric(detColor) && ~any(isnan(detColor)) || ~ismissing(detColor)))
        h = scatter3(detPosInset(:,1), detPosInset(:,2), detPosInset(:,3), mrkScaleFactor*p.Results.labelfontsize, 'filled', detColor);
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
            ePos = [c1020.x(i), c1020.y(i), c1020.z(i)];
            ePosInset = insetPos(ePos);
            if(numColors == 4 || numColors == 1)
                h = scatter3(ePosInset(1),ePosInset(2),ePosInset(3),mrkScaleFactor*1.5*p.Results.labelfontsize, 'filled', color1020);

            else
                h = scatter3(ePosInset(1),ePosInset(2),ePosInset(3),mrkScaleFactor*1.5*p.Results.labelfontsize, 'filled');
            end
            h.Tag=sprintf('Scatter1020');
            hold on

            h=text(ePos(1),ePos(2),ePos(3),c1020.Electrode(i),'HorizontalAlignment', 'center','VerticalAlignment', 'middle', "FontSize", p.Results.labelfontsize, 'color', p.Results.labelfontcolor);
            for k=1:length(h)
                h(k).Tag='Label1020';
            end
            %text(x2tx(c1020.x(i)),y2ty(c1020.y(i)),z2tz(c1020.z(i)),c1020.Electrode(i),'HorizontalAlignment','center')
            
        end
    end
end

if(isempty(itemsToSkipPlot))
    
    xlabel('x (R/L)');
    ylabel('y (R/C)');
    zlabel('z (U/D)');
    
    
    camPosUp=p.Results.camUp;
    camup(camPosUp);
    
    camPosTarget=p.Results.camTarget;
    camtarget(camPosTarget);
    
    
    if(isnumeric(p.Results.initCamPosition))
        campos(p.Results.initCamPosition);
    else
        switch(p.Results.initCamPosition)
            case 'auto'
                autoPos = nanmean(optPos,1);
                if any(isnan(autoPos)) || norm(autoPos) == 0
                    campos([0,1200,0]);  % Fall back to front view
                else
                    campos(autoPos/norm(autoPos)*1500);
                end
            case 'front'
                campos([0,1200,0]);
            case 'back'
                campos([0,-1200,0]);
            case 'top'
                campos([0,0,1500]);
            case 'bottom'
                campos([0,0,-1500]);
            case 'left'
                campos([-1200,0,0]);
            case 'right'
                campos([1200,0,0]);
            case 'face'
                campos([0,1200,-300]);
            case 'top-left'
                campos([-900,0,1100]);
            case 'top-right'
                campos([900,0,1100]);
            case 'top-front'
                campos([0,900,1100]);
            case 'top-back'
                campos([0,-900,1100]);
            case 'front-left'
                campos([-850,850,0]);
            case 'front-right'
                campos([850,850,0]);
            case 'back-left'
                campos([-850,-850,0]);
            case 'back-right'
                campos([850,-850,0]);
            otherwise
                warning('Invalid camera position');
                campos(OptPos3D_mean/norm(OptPos3D_mean)*1500);  %Front facing
        end
    end
    
    
    
    
    
    
    
    lht2=findobj(ax,'Type','Light','Tag','Rear');
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


% Determine text color from figure background (handles dark mode)
figBg = get(ancestor(ax, 'figure'), 'Color');
if isnumeric(figBg) && mean(figBg) > 0.5
    textClr = [0 0 0];
else
    textClr = [1 1 1];
end

title(ax, titleString, 'Color', textClr);
if p.Results.showColorbar && ~all(dataEmpty) && isempty(itemsToSkipPlot)
    % Remove existing colorbars
    delete(findobj(ax, 'Type', 'ColorBar'));

    ax1 = ax;
    curAxPosition = ax1.Position;
    
    if twosided
        % Two-sided colorbar
        if hasUpperData || hasLowerData
            cbWidth = 0.01;
            cbGap = curAxPosition(4) * 0.03;  % Small gap between bars
            cbX = curAxPosition(1) + curAxPosition(3);

            if hasUpperData && hasLowerData
                cbHeight = (curAxPosition(4) - cbGap) / 2;
            else
                cbHeight = curAxPosition(4);
            end

            % Create upper colorbar
            if hasUpperData
                chPos = colorbar(ax1, 'Location', 'eastoutside');
                chPos.Tag = 'Main';
                chPos.Color = textClr;
                title(chPos, clrBarTitle, 'Color', textClr);

                % Set colormap for upper colorbar
                colormap(ax1, cmap_high(nColorsMaxBar));
                caxis(ax1, cbarUpper_minmax);

                % Position upper colorbar in top half (or full height if no lower)
                if hasLowerData
                    chPos.Position = [cbX, curAxPosition(2) + cbHeight + cbGap, cbWidth, cbHeight];
                else
                    chPos.Position = [cbX, curAxPosition(2), cbWidth, cbHeight];
                end
            end

            % Create lower colorbar if needed
            if hasLowerData
                ax2 = axes('Position', ax1.Position, 'Visible', 'off');
                chNeg = colorbar(ax2, 'Location', 'eastoutside');
                chNeg.Tag = 'Lower';
                chNeg.Color = textClr;

                if(~hasUpperData)
                    title(chNeg, clrBarTitle, 'Color', textClr);
                end

                % Set colormap for lower colorbar
                colormap(ax2, cmap_low(nColorsMaxBar));
                caxis(ax2, cbarLower_minmax);

                % Position lower colorbar in bottom half (or full height if no upper)
                chNeg.Position = [cbX, curAxPosition(2), cbWidth, cbHeight];

                % Link properties of both axes
                linkprop([ax1, ax2], {'CameraUpVector', 'CameraPosition', 'CameraTarget', 'XLim', 'YLim', 'ZLim'});
            end
        end
    else
        % Single-sided colorbar
        chPos = colorbar(ax1, 'Location', 'eastoutside');
        chPos.Color = textClr;
        title(chPos, clrBarTitle, 'Color', textClr);

        % Set colormap for single colorbar
        if isnumeric(cmap_high)
            colormap(ax1, cmap_high);
        else
            colormap(ax1, cmap_high(nColorsMaxBar));
        end

        if p.Results.logScale
            set(ax1, 'ColorScale', 'log');
            caxis(ax1, exp(cbarUpper_minmax));
        else
            caxis(ax1, cbarUpper_minmax);
        end

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
    %% Reference brain images
    imgData = pf2_base.getAsset('sideprofile');
    img = imgData.img; map = imgData.map; alpha = imgData.alpha;
    
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
    imgData = pf2_base.getAsset('rcSlice');
    img = imgData.img; map = imgData.map; alpha = imgData.alpha;

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

    imgData = pf2_base.getAsset('topprofile');
    img = imgData.img; map = imgData.map; alpha = imgData.alpha;

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

h=ax;

if (nargout > 0)
    h=ax;

    frame=getframe(ax);
    imgOut = frame.cdata;
end

% Save figure if requested
if ~isempty(savePath)
    fig = gcf();
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, saveDPI);
end