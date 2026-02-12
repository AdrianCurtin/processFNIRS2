function [figHandle] = roi(fNIR, varargin)
% ROI Plot hemoglobin time series for regions of interest
%
% Creates time series plots of hemoglobin concentration changes for
% pre-defined regions of interest (ROIs). ROIs must be built prior to
% plotting using ROI construction functions. Supports multiple biomarkers,
% baseline subtraction, and event marker overlay.
%
% Syntax:
%   pf2.data.plot.roi(fNIR)                      % All ROIs
%   pf2.data.plot.roi(fNIR, rois)                % Specific ROIs
%   pf2.data.plot.roi(fNIR, ..., Name, Value)    % With options
%
% Inputs:
%   fNIR      - fNIRS data structure with ROI field [struct]
%               Must contain 'ROI' field with 'info' table and
%               biomarker subfields (HbO, HbR, etc.).
%   rois      - (optional) ROIs to plot: numeric, logical, cell, or 'all'
%
% Options (Name-Value):
%   'markers'     - true (default), false, or numeric array of codes
%   'biomarkers'  - {'HbO','HbR'} (default), or 'all', or specific list
%   'baseline'    - false (default), or seconds, or [start,end]
%   'ylim'        - [] (auto), or [min max]
%   'interactive' - true (default), false to skip prompts (for batch/headless)
%   'savePath'    - '' (default), filename to save figure (.png, .pdf, .fig)
%   'saveWidth'   - [] (default), figure width in pixels
%   'saveHeight'  - [] (default), figure height in pixels
%   'saveDPI'     - 150 (default), resolution for raster formats
%
% Example:
%   pf2.data.plot.roi(data)                      % Simple
%   pf2.data.plot.roi(data, 'FrontalL')          % ROI by name
%   pf2.data.plot.roi(data, 1:2)                 % ROIs 1-2
%   pf2.data.plot.roi(data, 'baseline', 10)      % With 10s baseline
%   pf2.data.plot.roi(data, 1, 'ylim', [-2 2])   % ROI 1, fixed y-axis
%
% See also: pf2.data.plot.oxy, pf2.probe.roi.Build, pf2.data.plot.auxData

% Validate fNIR input
if ~isstruct(fNIR)
    error('pf2:InvalidInput', 'First argument must be a fNIRS data structure');
end

% Parameter names for detection
% Note: Avoid naming ROIs with these reserved names
paramNames = {'markers', 'showmarkers', 'biomarkers', 'biomlist', 'baseline', ...
              'ylim', 'ylimit', 'lineprops', 'rejectedlineprops', 'interactive', ...
              'savepath', 'savewidth', 'saveheight', 'savedpi'};

% Extract positional 'rois' argument if present
rois2plot = [];
nvStart = 1;

if ~isempty(varargin)
    firstArg = varargin{1};
    if isnumeric(firstArg) || islogical(firstArg) || ...
       (ischar(firstArg) && strcmpi(firstArg, 'all'))
        rois2plot = firstArg;
        nvStart = 2;
    elseif iscell(firstArg)
        % Cell array of ROI names
        rois2plot = firstArg;
        nvStart = 2;
    elseif ischar(firstArg) || isstring(firstArg)
        if ~ismember(lower(char(firstArg)), paramNames)
            % Not a param name, treat as ROI name
            rois2plot = firstArg;
            nvStart = 2;
        end
    end
end

% Parse name-value pairs
p = inputParser;
p.CaseSensitive = false;
addParameter(p, 'markers', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'showMarkers', [], @(x) islogical(x) || isnumeric(x) || isempty(x));  % Legacy
addParameter(p, 'biomarkers', {'HbO', 'HbR'}, @(x) iscell(x) || ischar(x));
addParameter(p, 'bioMlist', {}, @(x) iscell(x) || ischar(x));  % Legacy
addParameter(p, 'baseline', false, @(x) isnumeric(x) || islogical(x) || isstruct(x));
addParameter(p, 'ylim', [], @isnumeric);
addParameter(p, 'ylimit', [], @isnumeric);  % Legacy
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
bioMlist = p.Results.biomarkers;
if ~isempty(p.Results.bioMlist), bioMlist = p.Results.bioMlist; end
baseline = p.Results.baseline;
ylimit = p.Results.ylim;
if ~isempty(p.Results.ylimit), ylimit = p.Results.ylimit; end
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

if(~isfield(fNIR,'ROI')||~isfield(fNIR.ROI,'info'))
   error('No ROI information present');
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


ROInames=fNIR.ROI.info.Properties.RowNames;


if(isempty(rois2plot)||(ischar(rois2plot)&&strcmpi(rois2plot,'all')))
    rois2plot=[];
end

if(iscell(rois2plot)||any(ischar(rois2plot)))
    if(~iscell(rois2plot))
        rois2plot={rois2plot};
    end
    rois2plot=find(ismember(ROInames,rois2plot));
end

if(any(logical(rois2plot))&&~any(isnumeric(rois2plot))&&~any(ischar(rois2plot)))
   rois2plot=find(rois2plot);
end







% Load probe info using helper
probeInfo = pf2_base.plot.loadProbeInfo(fNIR, false);


if(isempty(rois2plot))
    rois2plot=1:size(fNIR.ROI.info,1);
end

for i=1:length(bioMlist)
   if(~isfield(fNIR,bioMlist{i}))
       error('Biomarker %s does not exist',bioMlist{i});
   end
   
   if(isempty(fNIR.(bioMlist{i})))
       error('Biomarker %s is empty, please build ROI first',bioMlist{i});
   end
end
    
    
if(any(rois2plot>size(fNIR.ROI.info,1)))
    error('Some indexes are higher than number of ROIs');
elseif(any(rois2plot<0))
    error('ROI index can not be negative');
end




if(isfield(fNIR,'time'))
    t=fNIR.time;
    tmin=nanmin(t);
    tmax=nanmax(t);
    tmean=nanmean(t)-tmin;
else
    error('Must have valid time field');
end

idx2plot=ismember(probeInfo.ChannelList,rois2plot);


sty = pf2_base.plot.PlotStyle.getDefault();

if(~isempty(rois2plot))
    if(nargout>0)
        figHandle=figure('Color', sty.FigureColor);
    else
        figure('Color', sty.FigureColor);
    end
else
    warning('Nothing to Plot');
   return; 
end

% Process markers using helper
tooManyMarkers = 100;
tooManyLabels = 10;
[showMarkers, showMarkersIdx, curMarkers, numMarkers] = ...
    pf2_base.plot.processMarkers(fNIR, showMarkers, tooManyMarkers);

% Handle too many markers prompt
plotTonsOfMarkers = false;
if ~isempty(showMarkers) && any(numMarkers > tooManyMarkers)
    if interactive
        user_entry = input('Enable TonsOfMarkers Mode? (Can be VERY slow) y/n: ', 's');
        plotTonsOfMarkers = ismember(lower(user_entry), {'1', 'y', 'yes'});
    else
        warning('pf2:TooManyMarkers', 'Too many markers to display (>%d). Use ''interactive'', true to enable.', tooManyMarkers);
    end
end


% Apply baseline correction using helper
[fNIR, baseline] = pf2_base.plot.processBaseline(fNIR, baseline, bioMlist);


 t=fNIR.time;
    tmin=nanmin(t);
    tmax=nanmax(t);
    tmean=nanmean(t)-tmin;



oxyMaxValue=0;
oxyMinValue=0;

colorTable=pf2_base.getBioColors();

for b=1:length(bioMlist)
   bioM=bioMlist{b};
   oxyMaxValue=nanmax([oxyMaxValue,nanmax(nanmax(fNIR.ROI.(bioM)(:,idx2plot)))]);
   oxyMinValue=nanmin([oxyMinValue,nanmin(nanmin(fNIR.ROI.(bioM)(:,idx2plot)))]);
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

h=cell(0);
for(roiIdx=1:length(rois2plot))
    roiNum=rois2plot(roiIdx);
%     if(plotArranged)
%         optPos=probeInfo.OptLayout2D{roiNum};
%         optPos([3,4])=optPos([3,4]).*[0.65,0.9];
%         optPos([1,2])=optPos([1,2])+0.03;
%         h{roiIdx}= axes('Position',optPos,'Box','on');
%         
%     else
        subplot(length(rois2plot),1,roiIdx);
%     end
    
    gh=gcf();
    dcm_obj=datacursormode(gh);
    set(dcm_obj,'DisplayStyle','datatip',...
        'SnapToDataVertex','off','Enable','on');
    set(dcm_obj,'UpdateFcn', @myupdatefcn);
    
    
    

    
    if(oxyMaxValue>0&&oxyMinValue<0)
        zeroH=plot([tmin,tmax],[0,0],'--','Color',sty.ZeroLineColor,'HandleVisibility','off');
        hold on;
    end
   
    for b=1:length(bioMlist)
        bioM=bioMlist{b};
        
        bio2plot=fNIR.ROI.(bioM)(:,roiIdx);
        if(isfield(fNIR.ROI,'fchMask')&&fNIR.ROI.fchMask(roiNum)<=rejectLevel)
            lh=plot(t,bio2plot,rejectedLineProps{:},'color',colorTable.(bioM),lineProps{:});
            switch(fNIR.ROI.fchMask(roiNum))
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
        set(lh,'Tag',sprintf('Opt%i:%s',roiNum,bioM));
    end
    
    if(~isempty(baseline)||isempty(showMarkers))
        maxH=plot([tmean],ylimit(2),'color',sty.FigureColor,'HandleVisibility','off');
        minH=plot([tmean],ylimit(1),'color',sty.FigureColor,'HandleVisibility','off'); 
    end
    
    if(~isempty(baseline))
        if(~isnan(baseline(1))&&baseline(1)>0)
            bh=pf2_base.external.vline(tmin+baseline(1),'--r','Baseline Start',0.95);
            set(bh,'Tag','Baseline Start');
        end
        if(length(baseline)==2&&~isnan(baseline(2))&&baseline(2)<tmax)
            bh=pf2_base.external.vline(tmin+baseline(2),'--r','Baseline End',0.90);
            set(bh,'Tag','Baseline End');
        end
    end
        
    
    if(~isempty(showMarkers))
        for i=1:length(showMarkers)
            mrkName=sprintf('Mrk%i',showMarkers(i));
            if(numMarkers(i)<tooManyMarkers||plotTonsOfMarkers)
                yLabelHeight=min((1:length(showMarkers))*0.05+0.15, 0.95);
                if(numMarkers(i)<tooManyLabels)
                	pf2_base.external.vline(curMarkers(showMarkersIdx==i),sty.ForegroundColor,mrkName,yLabelHeight(i));
                else
                    pf2_base.external.vline(curMarkers(showMarkersIdx==i),'lineTags',mrkName);
                    fprintf('Marker %i has too many instances to plot labels',showMarkers(i));
                end
                
            end
        end
    end
    
    
    hold off;

    xlim([tmin,tmax]);
    
    ylim(ylimit);
    
    
    xlabel(sprintf('ROI%i: %s',roiNum,pf2_base.plot.escapeTeX(ROInames{roiNum})));
    

    if(length(bioMlist)>1)
        ylblstring=sprintf('\\Delta[X]');
    else
        ylblstring=sprintf('\\Delta[%s]',bioMlist{1});
    end
    
    if(isfield(fNIR,'units'))
        ylblstring=sprintf('%s %s',ylblstring,fNIR.units);
    end
    
    ylabel(ylblstring);
    
    
    if(roiIdx==length(rois2plot))
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
