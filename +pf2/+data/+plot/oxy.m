function [figHandle] = oxy(fNIR, varargin)
% OXY Plot hemoglobin concentration time series
%
% Creates time series plots of processed fNIRS hemoglobin data (HbO, HbR,
% etc.). Can display individual channels or all channels arranged according
% to probe geometry. Supports marker overlay, baseline subtraction, and
% visual distinction of rejected channels.
%
% Syntax:
%   pf2.data.plot.oxy(fNIR)                      % All channels
%   pf2.data.plot.oxy(fNIR, channels)            % Specific channels
%   pf2.data.plot.oxy(fNIR, ..., Name, Value)    % With options
%
% Inputs:
%   fNIR      - Processed fNIRS structure with HbO, HbR fields
%   channels  - (optional) Channels to plot: numeric, logical, or 'all'
%
% Options (Name-Value):
%   'markers'     - true (default), false, or numeric array of codes
%   'biomarkers'  - {'HbO','HbR'} (default), or 'all', or specific list
%   'baseline'    - false (default), or seconds, or [start,end]
%   'ylim'        - [] (auto), or [min max]
%   'interactive' - true (default), false to skip prompts (for batch/headless).
%                   When left unset, auto-detects headless sessions
%                   (pf2_base.isHeadless) and skips prompts automatically.
%   'savePath'    - '' (default), filename to save figure (.png, .pdf, .fig)
%   'saveWidth'   - [] (default), figure width in pixels
%   'saveHeight'  - [] (default), figure height in pixels
%   'saveDPI'     - 150 (default), resolution for raster formats
%
% Example:
%   pf2.data.plot.oxy(data)                      % Simple
%   pf2.data.plot.oxy(data, 5)                   % Channel 5
%   pf2.data.plot.oxy(data, 1:5)                 % Channels 1-5
%   pf2.data.plot.oxy(data, 'baseline', 10)      % With 10s baseline
%   pf2.data.plot.oxy(data, 5, 'ylim', [-2 2])   % Channel 5, fixed y-axis
%
% See also: pf2.data.plot.raw, pf2.data.plot.roi, pf2.probe.plot

% Validate fNIR input
if ~isstruct(fNIR)
    error('pf2:InvalidInput', 'First argument must be a fNIRS data structure');
end

% Parameter names for detection
paramNames = {'markers', 'biomarkers', 'biomlist', 'baseline', 'ylim', ...
              'ylimit', 'arranged', 'plotarranged', 'lineprops', ...
              'rejectedlineprops', 'showmarkers', 'interactive', ...
              'savepath', 'savewidth', 'saveheight', 'savedpi', 'rejectlevel'};

% Extract positional 'channels' argument if present
channels = [];
nvStart = 1;  % Where name-value pairs start in varargin

if ~isempty(varargin)
    firstArg = varargin{1};
    % If first arg is numeric/logical/or 'all', it's channels
    if isnumeric(firstArg) || islogical(firstArg) || ...
       (ischar(firstArg) && strcmpi(firstArg, 'all'))
        channels = firstArg;
        nvStart = 2;
    elseif ischar(firstArg) || isstring(firstArg)
        % Check if it's a parameter name
        if ~ismember(lower(char(firstArg)), paramNames)
            % Not a param name, treat as channels specifier
            channels = firstArg;
            nvStart = 2;
        end
    end
end

% Parse name-value pairs
p = inputParser;
p.CaseSensitive = false;
addParameter(p, 'markers', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'biomarkers', {'HbO', 'HbR'}, @(x) iscell(x) || ischar(x));
addParameter(p, 'bioMlist', {}, @(x) iscell(x) || ischar(x));  % Legacy
addParameter(p, 'baseline', false, @(x) isnumeric(x) || islogical(x) || isstruct(x));
addParameter(p, 'ylim', [], @isnumeric);
addParameter(p, 'ylimit', [], @isnumeric);  % Legacy
addParameter(p, 'arranged', [], @(x) islogical(x) || isempty(x));
addParameter(p, 'plotArranged', [], @(x) islogical(x) || isempty(x));  % Legacy
addParameter(p, 'lineProps', {'LineWidth', 1}, @iscell);
addParameter(p, 'rejectedLineProps', {'--', 'LineWidth', 1}, @iscell);
addParameter(p, 'showMarkers', [], @(x) islogical(x) || isnumeric(x) || isempty(x));
addParameter(p, 'interactive', true, @islogical);
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);
addParameter(p, 'rejectLevel', 0, @isnumeric);

parse(p, varargin{nvStart:end});

% Assign parsed values (with legacy fallbacks)
showMarkers = p.Results.markers;
if ~isempty(p.Results.showMarkers), showMarkers = p.Results.showMarkers; end
bioMlist = p.Results.biomarkers;
if ~isempty(p.Results.bioMlist), bioMlist = p.Results.bioMlist; end
baseline = p.Results.baseline;
ylimit = p.Results.ylim;
if ~isempty(p.Results.ylimit), ylimit = p.Results.ylimit; end
plotArranged = p.Results.arranged;
if ~isempty(p.Results.plotArranged), plotArranged = p.Results.plotArranged; end
lineProps = p.Results.lineProps;
rejectedLineProps = p.Results.rejectedLineProps;
interactive = p.Results.interactive;
% Auto-detect non-interactive sessions when the caller didn't set 'interactive'
% explicitly, so the default never reaches a blocking input() under -batch /
% -nodisplay (a user can still force the prompt with 'interactive', true).
if ismember('interactive', p.UsingDefaults) && pf2_base.isHeadless()
    interactive = false;
end
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;

% Default plotArranged
if isempty(plotArranged)
    plotArranged = false;
end

rejectLevel = p.Results.rejectLevel;

if(~iscell(bioMlist))
    if(any(~ischar(bioMlist)))
       error('pf2:data:plot:oxy:badBiomarkers', 'Must specify biomarkers');
    end
    if(strcmpi(bioMlist,'all'))
        bioMlist={'HbO','HbR','HbDiff','HbTotal','CBSI'};
    else
        bioMlist={bioMlist};
    end
end

if(nargin<2||isempty(channels)||(ischar(channels)&&strcmpi(channels,'all')))
    plotArranged=true; %Enabled when all channels are plot
    channels=[];
end

if(length(channels)>1&&any(logical(channels))&&any(~isnumeric(channels)))
   if(any(~channels))
      plotArranged=true;
   end
   channels=find(channels);
end

% Load probe info using helper
probeInfo = pf2_base.plot.loadProbeInfo(fNIR, plotArranged);


if(isempty(channels))
    channels=1:probeInfo.NumOptodes;
end

for i=1:length(bioMlist)
   if(~isfield(fNIR,bioMlist{i}))
       warning(sprintf('Biomarker %s does not exist',bioMlist{i}));
       return;
   end
end
    
    
if(any(channels>probeInfo.NumOptodes))
    error('pf2:data:plot:oxy:channelOutOfRange', 'Some channels are higher than probe optode count');
elseif(any(channels<0))
    error('pf2:data:plot:oxy:negativeChannel', 'Channels can not be negative');
end


if(isfield(fNIR,'time'))
    t=fNIR.time;
    tmin=nanmin(t);
    tmax=nanmax(t);
    tmean=nanmean(t)-tmin;
else
    error('pf2:data:plot:oxy:noTime', 'Must have valid time field');
end

idx2plot=ismember(probeInfo.TableOpt.OptodeNum,channels);


sty = pf2_base.plot.PlotStyle.getDefault();

if(~isempty(channels))
    if(nargout>0)
        figHandle=figure('Color', sty.FigureColor);
        clf(figHandle);
    else
        figHandle=gcf;
        clf(figHandle);
        set(figHandle, 'Color', sty.FigureColor);
    end
else
    warning('Nothing to Plot');
   return; 
end

% Process markers using helper
numch2plot = length(channels);
tooManyMarkers = 1500 / numch2plot;
[showMarkers, showMarkersIdx, curMarkers, numMarkers] = ...
    pf2_base.plot.processMarkers(fNIR, showMarkers, tooManyMarkers);





% Apply baseline correction using helper
[fNIR, baseline] = pf2_base.plot.processBaseline(fNIR, baseline, bioMlist);



oxyMaxValue=0;
oxyMinValue=0;

colorTable=pf2_base.getBioColors();

for b=1:length(bioMlist)
   bioM=bioMlist{b};
   oxyMaxValue=nanmax([oxyMaxValue,nanmax(nanmax(fNIR.(bioM)(:,idx2plot)))]);
   oxyMinValue=nanmin([oxyMinValue,nanmin(nanmin(fNIR.(bioM)(:,idx2plot)))]);
   oxyMeanValue=oxyMaxValue-oxyMinValue;
end

if(~isnan(oxyMeanValue))
   oxyMinValue=oxyMinValue-oxyMeanValue/20;
   oxyMaxValue=oxyMaxValue+oxyMeanValue/20;
end

if(length(ylimit)==1)
    ylimit=[-1*abs(ylimit),abs(ylimit)];
elseif(length(ylimit)>2||isempty(ylimit))
   ylimit=[oxyMinValue,oxyMaxValue];
end

if(ylimit(1)==ylimit(2))
    ylimit=[0,1]; %% No valid data here
end

h=cell(0);

tooManyLabels = 200 / numch2plot;

% Handle too many markers prompt (numMarkers already computed by helper)
plotTonsOfMarkers = false;
if ~isempty(showMarkers) && any(numMarkers > tooManyMarkers)
    if interactive
        user_entry = input('Enable TonsOfMarkers Mode? (Can be VERY slow) y/n: ', 's');
        plotTonsOfMarkers = ismember(lower(user_entry), {'1', 'y', 'yes'});
    else
        warning('pf2:TooManyMarkers', 'Too many markers to display (>%d). Use ''interactive'', true to enable.', round(tooManyMarkers));
    end
end

printOnce = false;
flagOnce = false;

if isfield(probeInfo, 'OptPos')
    optLayout = probeInfo.OptPos.subplot_layout_ss;
else
    plotArranged = false;
end

for optIdx = 1:length(channels)
    optNum = channels(optIdx);
    if plotArranged
        % Use helper for position calculation
        optPos = pf2_base.plot.getOptodePosition(optLayout, optNum, [0.65, 0.7], [0.03, 0.075]);
        if isempty(optPos)
            continue;
        end
        h{optIdx} = axes('Position', optPos, 'Box', 'on');
    else
        subplot(length(channels), 1, optIdx);
    end
    
    gh=gcf();
    dcm_obj=datacursormode(gh);
    set(dcm_obj,'DisplayStyle','datatip',...
        'SnapToDataVertex','off','Enable','on');
    set(dcm_obj,'UpdateFcn', @myupdatefcn);
    
    idx2plot=probeInfo.TableOpt.OptodeNum==optNum;
    
    num2plot=sum(idx2plot);
    
    if(oxyMaxValue>0&&oxyMinValue<0)
        zeroH=plot([tmin,tmax],[0,0],'--','Color',sty.ZeroLineColor,'HandleVisibility','off');
        hold on;
    end
   
    for b=1:length(bioMlist)
        bioM=bioMlist{b};
        
        bio2plot=fNIR.(bioM)(:,idx2plot);
        if(isfield(fNIR,'fchMask')&&fNIR.fchMask(optNum)<=rejectLevel)
            lh=plot(t,bio2plot,rejectedLineProps{:},'color',colorTable.(bioM),lineProps{:});
            switch(fNIR.fchMask(optNum))
                case 0.5
                    th=text(tmin+tmean*0.6,mean(ylimit),'~','FontSize',20,'color',[ 0.9100,0.4100,0.1700]);
                case 0
                    th=text(tmin+tmean*0.6,mean(ylimit),'X','FontSize',20,'color',[ 1,0.2100,0.1700]);
            end

        elseif(~isempty(lineProps))
            lh=plot(t,bio2plot,'color',colorTable.(bioM),lineProps{:});
        else
            lh=plot(t,bio2plot,'color',colorTable.(bioM));
        end
        set(lh,'Tag',sprintf('Opt%i:%s',optNum,bioM));
    end
    
    if(~isempty(baseline)||isempty(showMarkers))
        maxH=plot([tmean],ylimit(2),'color',sty.FigureColor,'HandleVisibility','off');
        minH=plot([tmean],ylimit(1),'color',sty.FigureColor,'HandleVisibility','off');
    end
    
    if(~isempty(baseline))
        if(~isnan(baseline(1))&&baseline(1)>=0)
            bh=pf2_base.external.vline(baseline(1),'--r','Baseline Start',0.95);
            set(bh,'Tag','Bl-Start');
        end
        if(length(baseline)==2&&~isnan(baseline(2))&&baseline(2)<tmax)
            bh=pf2_base.external.vline(baseline(2),'--r','Baseline End',0.90);
            set(bh,'Tag','Bl-End');
        end
    end
        
    ylim(ylimit);
    if(~isempty(showMarkers))

        for i=1:length(showMarkers)
            mrkName=sprintf('Mrk%i',showMarkers(i));
            if(numMarkers(i)<tooManyMarkers||plotTonsOfMarkers)
                yLabelHeight=min((1:length(showMarkers))*0.05+0.15, 0.95);
                if(numMarkers(i)<tooManyLabels)
                	pf2_base.external.vline(curMarkers(showMarkersIdx==i),{'Color',sty.ForegroundColor,'LineStyle',':'},mrkName,yLabelHeight(i));
                else
                    pf2_base.external.vline(curMarkers(showMarkersIdx==i),{'Color',sty.ForegroundColor,'LineStyle',':'},'',yLabelHeight(i),'lineTags',mrkName);
                    if(~printOnce)
                        fprintf('Marker %i has too many instances to plot labels\n',showMarkers(i));
                        flagOnce=true;
                    end
                    
                end
                
            end
        end
        if(flagOnce)
            printOnce=true;
        end
            
    end
    
    
    hold off;

    xlim([tmin,tmax]);
    
    
    
    xlabel(sprintf('Opt %i',optNum));
    

    if(length(bioMlist)>1)
        ylblstring=sprintf('\\Delta[X]');
    else
        ylblstring=sprintf('\\Delta[%s]',bioMlist{1});
    end
    
    if(isfield(fNIR,'units'))
        ylblstring=sprintf('%s %s',ylblstring,fNIR.units);
    end
    
    ylabel(ylblstring);
    
    
    if(optIdx==length(channels))
        legend(bioMlist);
    end
end

% Add figure title from processingInfo if available
pf2_base.plot.addProcessingInfoTitle(fNIR, gcf());

% Apply theme styling
sty.applyToFigure(gcf());

% Save figure if requested
if ~isempty(savePath)
    fig = gcf();
    pf2_base.plot.saveFigure(fig, savePath, saveWidth, saveHeight, saveDPI);
end

end



function txt = myupdatefcn(pointDataTip, event_obj)

 hAxes=get(pointDataTip,'Parent');
 pos = event_obj.Position;
 selectedObjectTag=event_obj.Target.Tag;
 if(~isempty(selectedObjectTag)&&contains(selectedObjectTag,'Baseline'))
        txt={sprintf('%s\nt=%.2f',selectedObjectTag,pos(1))};
 
 elseif(~isempty(selectedObjectTag)&&contains(selectedObjectTag,'Mrk'))
        txt={sprintf('%s\nt=%.2f',selectedObjectTag,pos(1))};
    elseif(~isempty(selectedObjectTag))
         txt={sprintf('%s\nt=%.2f, y=%.2f',selectedObjectTag,pos(1),pos(2))};
    
 else
    txt={''}; 
 end
 
for i=1:length(txt)
   txtprt=txt{i};
   txtprt(txtprt=='_')=' ';
   txt{i}=txtprt;
end

end