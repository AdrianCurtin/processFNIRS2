function [ figHandle ] = raw(fNIR, varargin)
% RAW Plot raw light intensity data from fNIRS acquisition
%
% Creates time series plots of raw fNIRS intensity data, optionally
% arranged according to probe geometry. Supports wavelength selection,
% marker overlay, and visual indication of rejected channels.
%
% Syntax:
%   pf2.data.plot.raw(fNIR)                      % All channels
%   pf2.data.plot.raw(fNIR, channels)            % Specific channels
%   pf2.data.plot.raw(fNIR, ..., Name, Value)    % With options
%
% Inputs:
%   fNIR      - fNIRS data structure with 'raw' and 'time' fields
%   channels  - (optional) Channels to plot: numeric, logical, or 'all'
%
% Options (Name-Value):
%   'markers'     - true (default), false, or numeric array of codes
%   'wavelengths' - [] (all), or specific wavelength values [730, 850]
%   'ylim'        - [] (auto), or [min max]
%   'arranged'    - [] (auto), true, or false
%   'interactive' - true (default), false to skip prompts (for batch/headless)
%   'savePath'    - '' (default), filename to save figure (.png, .pdf, .fig)
%   'saveWidth'   - [] (default), figure width in pixels
%   'saveHeight'  - [] (default), figure height in pixels
%   'saveDPI'     - 150 (default), resolution for raster formats
%
% Example:
%   pf2.data.plot.raw(data)                      % Simple
%   pf2.data.plot.raw(data, 5)                   % Channel 5
%   pf2.data.plot.raw(data, 1:5)                 % Channels 1-5
%   pf2.data.plot.raw(data, 'wavelengths', 730)  % Single wavelength
%   pf2.data.plot.raw(data, 5, 'markers', false) % No markers
%
% See also: pf2.data.plot.oxy, pf2.data.plot, pf2.settings.selectDevice

% Validate fNIR input
if ~isstruct(fNIR)
    error('pf2:InvalidInput', 'First argument must be a fNIRS data structure');
end

% Parameter names for detection
paramNames = {'markers', 'showmarkers', 'wavelengths', 'ylim', 'ylimit', ...
              'arranged', 'plotarranged', 'lineprops', 'rejectedlineprops', ...
              'interactive', 'savepath', 'savewidth', 'saveheight', 'savedpi'};

% Extract positional 'channels' argument if present
channels = [];
nvStart = 1;

if ~isempty(varargin)
    firstArg = varargin{1};
    if isnumeric(firstArg) || islogical(firstArg) || ...
       (ischar(firstArg) && strcmpi(firstArg, 'all'))
        channels = firstArg;
        nvStart = 2;
    elseif ischar(firstArg) || isstring(firstArg)
        if ~ismember(lower(char(firstArg)), paramNames)
            channels = firstArg;
            nvStart = 2;
        end
    end
end

% Parse name-value pairs
p = inputParser;
p.CaseSensitive = false;
addParameter(p, 'markers', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'showMarkers', [], @(x) islogical(x) || isnumeric(x) || isempty(x));  % Legacy
addParameter(p, 'wavelengths', [], @(x) isnumeric(x) || ischar(x));
addParameter(p, 'ylim', [], @isnumeric);
addParameter(p, 'ylimit', [], @isnumeric);  % Legacy
addParameter(p, 'arranged', [], @(x) islogical(x) || isempty(x));
addParameter(p, 'plotArranged', [], @(x) islogical(x) || isempty(x));  % Legacy
addParameter(p, 'lineProps', {'LineWidth', 1}, @iscell);
addParameter(p, 'rejectedLineProps', {'--', 'LineWidth', 1}, @iscell);
addParameter(p, 'interactive', true, @islogical);
addParameter(p, 'savePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveWidth', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveHeight', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'saveDPI', 150, @isnumeric);

parse(p, varargin{nvStart:end});

% Assign parsed values (with legacy fallbacks)
showMarkers = p.Results.markers;
if ~isempty(p.Results.showMarkers), showMarkers = p.Results.showMarkers; end
wavelengths = p.Results.wavelengths;
ylimit = p.Results.ylim;
if ~isempty(p.Results.ylimit), ylimit = p.Results.ylimit; end
plotArranged = p.Results.arranged;
if ~isempty(p.Results.plotArranged), plotArranged = p.Results.plotArranged; end
lineProps = p.Results.lineProps;
rejectedLineProps = p.Results.rejectedLineProps;
interactive = p.Results.interactive;
savePath = p.Results.savePath;
saveWidth = p.Results.saveWidth;
saveHeight = p.Results.saveHeight;
saveDPI = p.Results.saveDPI;


global PF2
if(~isfield(PF2,'RejectLevel'))
    pf2_base.pf2_initialize();
end
if(isfield(fNIR,'fchMask'))
    rejectLevel=PF2.RejectLevel;
end

% Handle default plotArranged (true when all channels)
if isempty(channels) || (ischar(channels) && strcmpi(channels, 'all'))
    if isempty(plotArranged)
        plotArranged = true;  % Enabled when all channels are plotted
    end
    channels = [];
elseif isempty(plotArranged)
    plotArranged = false;
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

sty = pf2_base.plot.PlotStyle.getDefault();

if(~isempty(channels))
    if(nargout>0)
        figHandle=figure('Color', sty.FigureColor);
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
    minH=plot([tmin,tmax],[RawMin,RawMin],'-','Color',sty.ForegroundColor,'HandleVisibility','off');
    set(minH,'Tag',sprintf('Min Device Intensity'));
    hold on;
    if(~isempty(RawMax))
        maxH=plot([tmin,tmax],[RawMax,RawMax],'--','Color',sty.ForegroundColor,'HandleVisibility','off');
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
        maxH=plot([tmean],ylimit(2),'color',sty.FigureColor,'HandleVisibility','off');
        minH=plot([tmean],ylimit(1),'color',sty.FigureColor,'HandleVisibility','off');
        for i=1:length(showMarkers)

            mrkName=sprintf('Mrk%i',showMarkers(i));
            if(numMarkers(i)<tooManyMarkers||plotTonsOfMarkers)
                yLabelHeight=min((1:length(showMarkers))*0.05+0.15, 0.95);
                if(numMarkers(i)<tooManyLabels)
                	pf2_base.external.vline(curMarkers(showMarkersIdx==i),sty.ForegroundColor,mrkName,yLabelHeight(i));
                else
                    pf2_base.external.vline(curMarkers(showMarkersIdx==i),sty.ForegroundColor,'',yLabelHeight(i),'lineTags',mrkName);
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
 
 if(~isempty(selectedObjectTag)&&contains(selectedObjectTag,'Mrk'))
        txt={sprintf('%s\nt=%.2f',selectedObjectTag,pos(1))};
 elseif(~isempty(selectedObjectTag)&&contains(selectedObjectTag,'Device'))
     txt={selectedObjectTag};
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