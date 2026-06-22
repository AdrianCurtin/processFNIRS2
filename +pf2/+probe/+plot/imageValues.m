function [ imgOut ] = imageValues(varargin)
% IMAGEVALUES Display per-channel values as a 2D image heatmap
%
% Creates a 2D image visualization where each fNIRS channel position is filled
% with a color corresponding to its data value. Channel positions are mapped
% to a grid image based on probe layout, creating a rectangular heatmap
% representation of the channel data. This is useful for creating publication-
% ready topographic plots of channel-level metrics.
%
% Reference:
%   Internal pf2 implementation for probe-based visualization.
%
% Syntax:
%   ImageValues(data2plot)
%   ImageValues(data2plot, fNIR)
%   ImageValues(data2plot, fNIR, minVal, maxVal)
%   ImageValues(data2plot, fNIR, minVal, maxVal, titleString, clrBarTitle)
%   imgOut = ImageValues(...)
%   ImageValues(..., 'includeSS', false)
%
% Inputs:
%   data2plot   - Values to display for each channel [1 x C double]
%                 Must have one value per optode/channel in the probe.
%   fNIR        - fNIRS data structure containing probe info (default: {})
%                 If empty, attempts to load from global setF or prompts user.
%   minVal      - Minimum value for color scale (default: min(data2plot))
%   maxVal      - Maximum value for color scale (default: max(data2plot))
%   titleString - Title displayed above the plot (default: '')
%   clrBarTitle - Title for the colorbar (default: '')
%   'includeSS' - Include short separation channels (default: true)
%                 Set to false to exclude short separation channels.
%   'Layout'    - 2D layout to draw (default: 'auto'):
%                 'schematic' (or 'flat') - clean declared/auto grid montage
%                     (e.g. a 2x8), tidy for explanatory plots.
%                 'anatomical' (or 'projected') - affine 3D->2D projection.
%                 'auto' - schematic when the device DECLARES a montage
%                     (LayoutRows/Cols or Layout2D_x/y), else anatomical.
%
% Outputs:
%   imgOut - Handle to the image object (optional)
%
% Example:
%   % Display mean HbO values as heatmap
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   meanHbO = mean(processed.HbO, 1);
%   pf2.probe.plot.imageValues(meanHbO, processed, [], [], 'Mean HbO', 'uM');
%
%   % Display p-values with custom range
%   pvals = rand(1, 18) * 0.1;
%   pf2.probe.plot.imageValues(pvals, processed, 0, 0.05, 'P-values');
%
% See also: pf2.probe.plot.arrangedValues, pf2.probe.plot.interpolateValues,
%           pf2.probe.plot.imageROIvalues, pf2.data.plot.oxy

p = inputParser;

isStructOrEmpty=@(x) isstruct(x)||isempty(x);
isStringOrChar=@(x)isstring(x)||ischar(x);

addRequired(p, 'data2plot');
addOptional(p, 'fNIR', {}, isStructOrEmpty);
addOptional(p, 'minVal', [], @isnumeric);
addOptional(p, 'maxVal', [], @isnumeric);
addOptional(p, 'titleString', '', isStringOrChar);
addOptional(p, 'clrBarTitle', '', isStringOrChar);

addParameter(p, 'includeSS', true, @islogical);
addParameter(p, 'Layout', 'auto', @(x) (ischar(x) || isstring(x)) && ...
    any(strcmpi(char(x), {'auto','schematic','flat','anatomical','projected'})));
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);

parse(p, varargin{:});

clrBarTitle = p.Results.clrBarTitle;
titleString = p.Results.titleString;
minVal = p.Results.minVal;
maxVal = p.Results.maxVal;
fNIR = p.Results.fNIR;
data2plot = p.Results.data2plot;

include_ss=p.Results.includeSS;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;


if(isempty(maxVal))
    maxVal=nanmax(data2plot);
end

if(isempty(minVal))
   minVal=nanmin(data2plot);
end

% Load probe info using helper
probeInfo = pf2_base.plot.loadProbeInfo(fNIR, true);

if(include_ss&&size(probeInfo.OptPos,1)>length(data2plot)&&sum(~probeInfo.TableOpt.IsShortSeparation)==length(data2plot))
   include_ss=false;
   warning('Not enough data for all channels, ignoring short separation channels');
end

% Resolve which 2D layout to draw: the clean declared/auto "schematic" grid
% or the affine 3D->2D "anatomical" projection.
layoutMode = lower(char(p.Results.Layout));
if any(strcmp(layoutMode, {'flat'})),       layoutMode = 'schematic';  end
if any(strcmp(layoutMode, {'projected'})),  layoutMode = 'anatomical'; end
hasSchem = ismember('subplot_layout_schematic', probeInfo.OptPos.Properties.VariableNames);
declared = isfield(probeInfo, 'LayoutDeclared') && logical(probeInfo.LayoutDeclared);
switch layoutMode
    case 'auto'
        useSchematic = hasSchem && declared;   % only auto-prefer a real montage
    case 'schematic'
        useSchematic = hasSchem;
        if ~hasSchem
            warning('pf2:imageValues:noSchematic', ...
                'No schematic layout for this device; using anatomical projection.');
        end
    otherwise % 'anatomical'
        useSchematic = false;
end

% rowIdx maps each data value to its OptPos/TableOpt ROW (the layout cells are
% row-indexed). Indexing by OptodeNum value breaks for devices with
% non-contiguous channel numbers (e.g. merged probes where OptodeNum spans
% 5..42 across 34 rows).
if(include_ss)
    numOptodes=size(probeInfo.TableOpt,1);
    rowIdx=(1:numOptodes)';
    if useSchematic
        optLayout=probeInfo.OptPos.subplot_layout_schematic_ss;
    else
        optLayout=probeInfo.OptPos.subplot_layout_ss;
    end
else
    numOptodes=sum(~probeInfo.TableOpt.IsShortSeparation);
    rowIdx=find(~probeInfo.TableOpt.IsShortSeparation);
    if useSchematic
        optLayout=probeInfo.OptPos.subplot_layout_schematic;
    else
        optLayout=probeInfo.OptPos.subplot_layout;
    end
end

if(length(data2plot)~=numOptodes)
    error('pf2:probe:imageValues:optodeCountMismatch', 'Must have a value for all optodes');
end
% 
% clf(gcf);
% 
% h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

g=gcf;
clf(gcf);


imgSize=1000;
imgData=nan(imgSize,imgSize);




for(optIdx=1:length(data2plot))
    optPos=optLayout{rowIdx(optIdx)};

    if(isempty(optPos)), continue; end   % short-sep / unplaced channel

    optPos([2])=1-optPos([2])-optPos([4]); %flips y vertical axis
    
    x1=round(optPos(1)*imgSize);
    y1=round(optPos(2)*imgSize);
    x2=round(optPos(3)*imgSize+x1);
    y2=round(optPos(4)*imgSize+y1);
    
    if(~isnan(data2plot(optIdx)))
    	imgData(y1:y2,x1:x2)=data2plot(optIdx);
    end
end
imgData=imgData(end:-1:1,:);

imgFinal=imagesc(imgData,[minVal,maxVal]);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
imgFinal.AlphaData=~isnan(imgData);
imgFinal.AlphaDataMapping='scaled';

ch=colorbar();

if(~isempty(clrBarTitle))
set(get(ch,'title'),'string',clrBarTitle);
end


axis off


if(nargout>0)
    imgOut=imgFinal;
end

if(~isempty(titleString))
    title(titleString);
end

% Save figure if requested
if ~isempty(savePath)
    fig = gcf();
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, saveDPI);
end

end
