function [figHandle] = oxy(varargin)
% OXY Plot hemoglobin concentration time series
%
% Creates time series plots of processed fNIRS hemoglobin data (HbO, HbR,
% etc.). Can display individual channels or all channels arranged according
% to probe geometry. Supports marker overlay, baseline subtraction, and
% visual distinction of rejected channels.
%
% Syntax:
%   pf2.data.plot.oxy(fNIR)                          % Plot all channels
%   pf2.data.plot.oxy(fNIR, channel)                 % Plot specific channel
%   pf2.data.plot.oxy(fNIR, 'all')                   % Explicit all channels
%   pf2.data.plot.oxy(..., 'Name', Value)            % With options
%   figHandle = pf2.data.plot.oxy(...)               % Return figure handle
%
% Inputs:
%   fNIR          - Processed fNIRS structure with HbO, HbR fields
%   channels      - Channel(s) to plot (optional):
%                   - Numeric: Specific channel number(s)
%                   - 'all' or []: All channels in probe arrangement
%   'markers'     - Marker display options:
%                   - true: Show all markers (default)
%                   - false: Hide markers
%                   - Numeric array: Show only specified marker codes
%   'bioMlist'    - Biomarkers to plot (default: {'HbO', 'HbR'})
%                   Options: 'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   'baseline'    - Baseline subtraction:
%                   - Numeric: Seconds from start for baseline period
%                   - Negative: Index from end of recording
%                   - fNIR struct: Use separate data as baseline
%   'ylimit'      - Y-axis limits [min max] for all subplots
%   'plotArranged' - Force probe arrangement layout (default: false)
%   'lineProps'   - Line properties for all plots (cell array)
%                   Default: {'LineWidth', 1}
%   'rejectedLineProps' - Line properties for rejected channels
%                   Default: {'--', 'LineWidth', 1}
%   'showMarkers' - Display event markers (default: true)
%
% Outputs:
%   figHandle     - Handle to the created figure
%
% Notes:
%   - Requires processed data (must contain HbO field)
%   - Probe arrangement uses device configuration subplot layout
%   - Rejected channels (fchMask < RejectLevel) shown with dashed lines
%   - Standard biomarker colors: HbO=red, HbR=blue, HbTotal=green
%
% Example:
%   % Basic plot of all channels
%   pf2.data.plot.oxy(processedData);
%
%   % Plot specific channel with custom biomarkers
%   pf2.data.plot.oxy(data, 5, 'bioMlist', {'HbO', 'HbR', 'HbTotal'});
%
%   % Plot with baseline subtraction
%   pf2.data.plot.oxy(data, 'baseline', 10);  % 10s baseline
%
% See also: pf2.data.plot.raw, pf2.data.plot.roi, pf2.probe.plot.imageValues

validFnirs = @(x) (iscell(x) || isstruct(x));
validChannels = @(x) (isnumeric(x) || ischar(x));
validbioMlist = @(x) (iscell(x) || ischar(x));

p=inputParser;
addRequired(p, 'fNIR', validFnirs);
addOptional(p, 'channels', [], validChannels);
addOptional(p, 'markers', [], @isnumeric);
addOptional(p, 'bioMlist', {'HbO', 'HbR'}, validbioMlist);
addOptional(p, 'baseline', false, @isnumeric);
addOptional(p, 'ylimit', [], @isnumeric);
addOptional(p, 'plotArranged', false, @islogical);
addOptional(p, 'lineProps', {'LineWidth', 1}, @iscell);
addOptional(p, 'rejectedLineProps', {'--', 'LineWidth', 1}, @iscell);
addOptional(p, 'showMarkers', true, @islogical);

parse(p, varargin{:});
fNIR = p.Results.fNIR;
channels = p.Results.channels;
showMarkers = p.Results.showMarkers;
bioMlist = p.Results.bioMlist;
baseline = p.Results.baseline;
ylimit = p.Results.ylimit;
plotArranged = p.Results.plotArranged;
lineProps = p.Results.lineProps;
rejectedLineProps = p.Results.rejectedLineProps;


global PF2
if(~isfield(PF2,'RejectLevel'))
    pf2_base.pf2_initialize();
end
if(isfield(fNIR,'fchMask'))
    rejectLevel=PF2.RejectLevel;
end

if(~iscell(bioMlist))
    if(any(~ischar(bioMlist)))
       error('Must specify biomarkers');
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
    error('Some channels are higher than probe optode count');
elseif(any(channels<0))
    error('Channels can not be negative');
end


if(isfield(fNIR,'time'))
    t=fNIR.time;
    tmin=nanmin(t);
    tmax=nanmax(t);
    tmean=nanmean(t)-tmin;
else
    error('Must have valid time field');
end

idx2plot=ismember(probeInfo.TableOpt.OptodeNum,channels);


if(~isempty(channels))
    if(nargout>0)
        figHandle=figure(); 
        clf(figHandle);
    else
        figHandle=gcf;
        clf(figHandle);
        %figure();
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
    user_entry = input('Enable TonsOfMarkers Mode? (Can be VERY slow) y/n: ', 's');
    plotTonsOfMarkers = ismember(lower(user_entry), {'1', 'y', 'yes'});
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
        zeroH=plot([tmin,tmax],[0,0],'--k','HandleVisibility','off');
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
        maxH=plot([tmean],ylimit(2),'color',[1,1,1],'HandleVisibility','off');
        minH=plot([tmean],ylimit(1),'color',[1,1,1],'HandleVisibility','off'); 
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
                yLabelHeight=(1:length(showMarkers))*0.05+0.15;
                if(numMarkers(i)<tooManyLabels)
                	pf2_base.external.vline(curMarkers(showMarkersIdx==i),'k',mrkName,yLabelHeight(i));
                else
                    pf2_base.external.vline(curMarkers(showMarkersIdx==i),'k','',yLabelHeight(i),'lineTags',mrkName);
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
    

    if(length(bioM)>1)
        ylblstring=sprintf('\\Delta[X]');
    else
        ylblstring=sprintf('\\Delta[%s]',bioM{1});
    end
    
    if(isfield(fNIR,'units'))
        ylblstring=sprintf('%s %s',ylblstring,fNIR.units);
    end
    
    ylabel(ylblstring);
    
    
    if(optIdx==length(channels))
        legend(bioMlist);
    end
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