function [ figHandle ] = raw(varargin)
% RAW Plot raw light intensity data from fNIRS acquisition
%
% Creates time series plots of raw fNIRS intensity data, optionally
% arranged according to probe geometry. Supports wavelength selection,
% marker overlay, and visual indication of rejected channels. Useful for
% quality assessment of raw data before processing.
%
% Syntax:
%   pf2.data.plot.raw(fNIR)
%   pf2.data.plot.raw(fNIR, channels)
%   pf2.data.plot.raw(fNIR, channels, showMarkers, wavelengths)
%   pf2.data.plot.raw(fNIR, channels, showMarkers, wavelengths, ylimit, plotArranged)
%   figHandle = pf2.data.plot.raw(..., lineProps, rejectedLineProps)
%
% Inputs:
%   fNIR              - fNIRS data structure [struct]
%                       Must contain 'raw' [T x C] and 'time' [T x 1] fields.
%   channels          - Channels to plot [numeric array | logical | 'all']
%                       (default: all channels, enables arranged plot)
%                       Can be channel numbers or logical index.
%   showMarkers       - Display event markers on plots [logical | numeric | 'all']
%                       (default: true) If numeric, specifies marker codes to show.
%   wavelengths       - Wavelengths to include [numeric array | 'all']
%                       (default: all available wavelengths from probe config)
%                       Common values: 730, 850 nm.
%   ylimit            - Y-axis limits for all subplots [1x2 numeric]
%                       (default: [RawMin, max(data)] from device config)
%   plotArranged      - Use probe geometry layout for subplots [logical]
%                       (default: true when all channels plotted)
%   lineProps         - Line properties for good channels [cell array]
%                       (default: {'LineWidth', 1})
%   rejectedLineProps - Line properties for rejected channels [cell array]
%                       (default: {'--', 'LineWidth', 1})
%
% Outputs:
%   figHandle - Handle to the created figure [figure handle]
%               Only returned when output argument is requested.
%
% Example:
%   % Basic raw data plot
%   data = pf2.import.sampleData.fNIR2000();
%   pf2.data.plot.raw(data);
%
%   % Plot specific channels and wavelengths
%   pf2.data.plot.raw(data, 1:5, true, 730);
%
%   % Custom line styling with markers disabled
%   pf2.data.plot.raw(data, 'all', false, 'all', [], true, ...
%       {'LineWidth', 2, 'Color', 'b'});
%
% Notes:
%   - Requires valid device configuration for probe geometry
%   - Rejected channels (fchMask=0) shown with 'X', marginal (0.5) with '~'
%   - Data cursor mode enabled for interactive inspection
%   - Large numbers of markers may prompt for confirmation (slow rendering)
%
% See also: pf2.data.plot.oxy, pf2.data.plot, pf2.settings.selectDevice

validFnirs = @(x) (iscell(x) || isstruct(x));
validChannels = @(x) (isnumeric(x) || ischar(x));
validWavelength = @(x) (isnumeric(x) || ischar(x));

p=inputParser;
addRequired(p, 'fNIR', validFnirs);
addOptional(p, 'channels', [], validChannels);
addOptional(p, 'showMarkers', true, @islogical);
addOptional(p, 'wavelengths', [], validWavelength);
addOptional(p, 'ylimit', [], @isnumeric);
addOptional(p, 'plotArranged', false, @islogical);
addOptional(p, 'lineProps', {'LineWidth', 1}, @iscell);
addOptional(p, 'rejectedLineProps', {'--', 'LineWidth', 1}, @iscell);

parse(p, varargin{:});
fNIR = p.Results.fNIR;
channels = p.Results.channels;
showMarkers = p.Results.showMarkers;
wavelengths = p.Results.wavelengths;
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

if(nargin<8||isempty(rejectedLineProps))
    rejectedLineProps={'--','LineWidth',1};
end

if(nargin<7||isempty(lineProps))
    lineProps={'LineWidth',1};
end



if(nargin<6)
    plotArranged=false;  % plot when channels is all or empty
end

if(nargin<5)
   ylimit=[]; % will use max device info to plot
end


if(nargin<3)
   showMarkers=true;  %will plot all markers 
end

if(nargin<2||isempty(channels)||(ischar(channels)&&strcmpi(channels,'all')))
    plotArranged=true; %Enabled when all channels are plot
    channels=[];
end

if(any(logical(channels))&&any(~isnumeric(channels)))
   if(any(~channels))
      plotArranged=true; 
   end
   channels=find(channels); 
end



% Load probe info using helper
[probeInfo, deviceInfo] = pf2_base.plot.loadProbeInfo(fNIR, plotArranged);



if(isempty(channels))
    channels=1:probeInfo.NumOptodes;
end

if(nargin<4||isempty(wavelengths)||(ischar(wavelengths)&&strcmpi(wavelengths,'all')))
    [wavelengths,wvb]=unique(probeInfo.TableCh.Wavelength);
    wavelengths=probeInfo.TableCh.Wavelength(wvb); %unsort here
else
    wvs=wavelengths(ismember(wavelengths,probeInfo.TableCh.Wavelength));
    [wavelengths,wvb]=unique(wvs);
    wavelengths=wvs(wvb); %unsort here
end



wavelengths=wavelengths(~isnan(wavelengths));

if(isempty(wavelengths))
    wavelengths=unique(probeInfo.Wavelength);
    wavelengths=wavelengths(~isnan(wavelengths));
    fprintf(2,'Valid Wavelengths are: ')
    for i=1:length(wavelengths)
       fprintf(2,'%i ',wavelengths(i)); 
    end
    fprintf('\n');
    error('No Wavelengths to plot');
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

idx2plot=ismember(probeInfo.TableCh.OptodeNumber,channels);
wv2plot=ismember(probeInfo.TableCh.Wavelength,wavelengths);
idx2plot=idx2plot&wv2plot;

maxRawValue=nanmax(nanmax(fNIR.raw(:,idx2plot)));

if(isfield(deviceInfo,'RawMax'))
    RawMax=deviceInfo.RawMax;
    
    if(maxRawValue<RawMax)
       maxRawValue=RawMax*1.01; 
    end
else
    RawMax=[];
end


if(isfield(deviceInfo,'RawMin'))
    RawMin=deviceInfo.RawMin;
else
    RawMin=0;
end

if(~isempty(channels))
    if(nargout>0)
        figHandle=figure(); 
    else
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



if(length(ylimit)==1)
    ylimit=[0,maxRawValue];
elseif(length(ylimit)>2||isempty(ylimit))
   ylimit=[RawMin,maxRawValue];
end


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

h = cell(0);
for optIdx = 1:length(channels)
    optNum = channels(optIdx);
    if plotArranged
        % Use helper for position calculation
        optPos = pf2_base.plot.getOptodePosition(optLayout, optNum, [0.65, 0.9], [0.03, 0]);
        if isempty(optPos)
            continue;
        end
        h{optIdx} = axes('Position', optPos, 'Box', 'on');
    else
        h{optIdx} = subplot(length(channels), 1, optIdx);
    end
    
    gh=gcf();
    dcm_obj=datacursormode(gh);
    set(dcm_obj,'DisplayStyle','datatip',...
        'SnapToDataVertex','off','Enable','on');
    set(dcm_obj,'UpdateFcn', @myupdatefcn);
    
    idx2plot=probeInfo.TableCh.OptodeNumber==optNum;
    wv2plot=ismember(probeInfo.TableCh.Wavelength,wavelengths);
    curWv=probeInfo.TableCh.Wavelength(wv2plot);
    
    idx2plot=idx2plot&wv2plot;
    num2plot=sum(idx2plot);
    

    rawToPlot=fNIR.raw(:,idx2plot);
    minH=plot([tmin,tmax],[RawMin,RawMin],'k','HandleVisibility','off');
    set(minH,'Tag',sprintf('Min Device Intensity'));
    hold on;
    if(~isempty(RawMax))
        maxH=plot([tmin,tmax],[RawMax,RawMax],'--k','HandleVisibility','off');
        set(maxH,'Tag',sprintf('Max Device Intensity'));
    end
    
    for i=1:size(rawToPlot,2)
        if(isfield(fNIR,'fchMask')&&fNIR.fchMask(optNum)<=rejectLevel)
            lh=plot(t,rawToPlot(:,i),rejectedLineProps{:},lineProps{:});
            switch(fNIR.fchMask(optNum))
                case 0.5
                    th=text(tmin+tmean*0.6,mean(ylimit),'~','FontSize',20,'color',[ 0.9100,0.4100,0.1700]);
                case 0
                    th=text(tmin+tmean*0.6,mean(ylimit),'X','FontSize',20,'color',[ 1,0.2100,0.1700]);
            end
                
        elseif(~isempty(lineProps))
            lh=plot(t,rawToPlot(:,i),lineProps{:});
        else
            lh=plot(t,rawToPlot(:,i));
        end
        
        if(curWv(i)==0)
            set(lh,'Tag',sprintf('Opt%i:Ambient',optNum));
        else
            set(lh,'Tag',sprintf('Opt%i:%inm',optNum,curWv(i)));
        end
    end
    
    ylim(ylimit);
    if(~isempty(showMarkers))
        maxH=plot([tmean],ylimit(2),'color',[1,1,1],'HandleVisibility','off');
        minH=plot([tmean],ylimit(1),'color',[1,1,1],'HandleVisibility','off');
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
    
    if(optIdx==length(channels))
        legStr=cell(1,length(wavelengths));
        for s=1:length(wavelengths)
            if(wavelengths(s)==0)
                legStr{s}='Ambient';
            else
                legStr{s}=sprintf('%.0fnm',wavelengths(s)); 
            end
        end
        legend(legStr{:});
    end
    
    
    hold off;

    xlim([tmin,tmax]);
    
    
    
    
    
    
    xlabel(sprintf('Opt %i',optNum));
    ylabel('Intensity');
    

end

end

 
function txt = myupdatefcn(pointDataTip, event_obj)

 hAxes=get(pointDataTip,'Parent');
 pos = event_obj.Position;
 selectedObjectTag=event_obj.Target.Tag;
 
 if(~isempty(selectedObjectTag)&&contains(selectedObjectTag,'Mrk'))
        txt={sprintf('%s\nt=%.2f',selectedObjectTag,pos(1))};
 elseif(~isempty(selectedObjectTag)&&contains(selectedObjectTag,'Device'))
     txt={selectedObjectTag};
    elseif(~isempty(selectedObjectTag))
         txt={sprintf('%s\nt=%.2f, y=%.2f',selectedObjectTag,pos(1),pos(2))};

 end
 
for i=1:length(txt)
   txtprt=txt{i};
   txtprt(txtprt=='_')=' ';
   txt{i}=txtprt;
end

end