function [ figHandle ] = ROI(fNIR,rois2plot,showMarkers,bioMlist,baseline,ylimit,lineProps,rejectedLineProps)
%pf2.Data.Plot.ROI
%   plots an individual or ROIs (provided they have been built and
%   calculated
% specify an individual ROI index to plot that or leave blank or 'all' to plot
%       Can use ROI names to plot ex'ROI1'
%
% showMarkers argument can be an array of markers, strings of marker
% labels, or just true/false to plot all
%
% bioMlist is the list of biomarkers that Plot.Oxy will use, defaults to
% just HbO/HbR
%
% baseline will accept a time (ex 10s) for a baseline at the beginning of the plot
%   can be negative indexed from the end or accepts an FNIRS struct to
%   baseline from
% 
% ylimit will force the ylimit of each plot to a specific value
%
%
% lineprops will be passed along to all polots
%
% rejectedLineProps will just be passed on to rejected Optodes
%   (fchMask<rejectLevel)

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



if(nargin<8||isempty(rejectedLineProps))
    rejectedLineProps={'--','LineWidth',1};
end

if(nargin<7||isempty(lineProps))
    lineProps={'LineWidth',1};
end


if(nargin<6)
   ylimit=[]; % will use max device info to plot
end

if(nargin<5)
    baseline=false;
end


if(nargin<4||isempty(bioMlist))
    bioMlist={'HbO','HbR'};
end

if(nargin<3)
   showMarkers=true;  %will plot all markers 
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


if(nargin<2||isempty(rois2plot)||(ischar(rois2plot)&&strcmpi(rois2plot,'all')))
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







if(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
else
    cfgFilePath='';
end


if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
    
    warning('Missing or invalid configuration file path\n')
    
    disp('No device specified. Please load device configuration');
    probeInfo=pf2_base.loadDeviceCfg([],true);
    if(~isempty(probeInfo))
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
else
   error('Unable to identify probe'); 
end


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


if(~isempty(rois2plot))
    if(nargout>0)
        figHandle=figure(); 
    else
        figure();
    end
else
    warning('Nothing to Plot');
   return; 
end

if(~isfield(fNIR,'markers')||isempty(fNIR.markers))
   showMarkers=false; 
end

if(ischar(showMarkers)&&strcmpi(showMarkers,'all'))
    showMarkers=true;
end

if(islogical(showMarkers))
    if(~showMarkers)
        showMarkers=[];
    else
        [showMarkers,~,showMarkersIdx]=unique(fNIR.markers(:,2));
    end
elseif(isnumeric(showMarkers))
    [uMarkers,~,showMarkersIdxTemp]=unique(fNIR.markers(:,2));
    showMarkersIdx=nan(size(showMarkersIdxTemp));
    showMarkersUidx=find(ismember(uMarkers,showMarkers));
    for i=1:length(showMarkersUidx)
        showMarkersIdx(showMarkersIdxTemp==(showMarkersUidx(i)))=i;
    end
    showMarkers=uMarkers(showMarkersUidx);
end

if(isfield(fNIR,'markers')&&~isempty(showMarkers))
    curMarkers=fNIR.markers;
    if(~isnumeric(curMarkers)&&isfield(curMarkers,'data'))
        curMarkers=curMarkers.data;
    end
end


tooManyMarkers=100;
tooManyLabels=10;
if(~isempty(showMarkers))
    plotTonsOfMarkers=[];
    numMarkers=zeros(1,length(showMarkers));
    for i=1:length(showMarkers)
        numMarkers(i)=sum(showMarkersIdx==i);
        if(numMarkers(i)>tooManyMarkers&&isempty(plotTonsOfMarkers))
            fprintf(2,'Warning: Over %i markers for marker %i\n',tooManyMarkers,i);
            user_entry = input(sprintf('Enable TonsOfMarkers Mode?\n(Can be VERY slow)\ny/n: '), 's');
            user_entry=lower(user_entry);
            switch user_entry
                case '1'
                    plotTonsOfMarkers=true;
                case '0'
                    plotTonsOfMarkers=false;
                case 'y'
                    plotTonsOfMarkers=true;
                case 'n'
                    plotTonsOfMarkers=false;
                case 'yes'
                    plotTonsOfMarkers=true;
                case 'no'
                    plotTonsOfMarkers=false;
            end
        end
    end
    if(isempty(plotTonsOfMarkers))
       plotTonsOfMarkers=false; 
    end
end


if(islogical(baseline)&&baseline&&any(~isnumeric(baseline))) 
    baseline=10;
    fNIR=pf2.Data.Split(fNIR,'blLength',baseline,'relative',true);
    baseline=[nan,baseline];
elseif(~any(~isnumeric(baseline))&&length(baseline)==1&&baseline>0&&baseline<(tmax-tmin))
    fNIR=pf2.Data.Split(fNIR,'blLength',baseline,'relative',true);
    baseline=[nan,baseline];
elseif(~any(~isnumeric(baseline))&&length(baseline)==1&&baseline<0&&baseline>(tmin-tmax)) %from end
    if(baseline(1)<0)
        baseline(1)=tmax-tmin+baseline(1);
        baseline(2)=tmax-tmin;
    end
    fNIR=pf2.Data.Split(fNIR,'blStartTime',baseline(1),'blEndTime',baseline(2),'relative',true);
    baseline=baseline+tmin;
elseif(any(isnumeric(baseline))&&length(baseline)==2) %from end
    if(baseline(1)<0)
        baseline(1)=tmax+baseline(1)-tmin;
    end
    if(baseline(2)<0)
        baseline(2)=tmax+baseline(2)-tmin; 
    end
    fNIR=pf2.Data.Split(fNIR,'blStartTime',baseline(1),'blEndTime',baseline(2),'relative',true);
    baseline=baseline+tmin;
elseif(isstruct(baseline)&&isfield(baseline,'time')&&isfield(baseline,bioMlist{1}))
    fNIR=pf2.Data.Split(fNIR,tmin,tmax,'blfNIR',baseline);
    baseline=[];
else
   baseline=[]; 
end


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
        zeroH=plot([tmin,tmax],[0,0],'--k','HandleVisibility','off');
        hold on;
    end
   
    for b=1:length(bioMlist)
        bioM=bioMlist{b};
        
        bio2plot=fNIR.ROI.(bioM)(:,roiIdx);
        if(isfield(fNIR.ROI,'fchMask')&&fNIR.ROI.fchMask(roiNum)<=rejectLevel)
            lh=plot(t,bio2plot,rejectedLineProps{:},'color',colorTable.(bioM),lineProps{:});
            switch(fNIR.fchMask(roiNum))
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
        maxH=plot([tmean],ylimit(2),'color',[1,1,1],'HandleVisibility','off');
        minH=plot([tmean],ylimit(1),'color',[1,1,1],'HandleVisibility','off'); 
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
                yLabelHeight=(1:length(showMarkers))*0.05+0.15;
                if(numMarkers(i)<tooManyLabels)
                	pf2_base.external.vline(curMarkers(showMarkersIdx==i),'k',mrkName,yLabelHeight(i));
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
    
    
    xlabel(sprintf('ROI%i: %s',roiNum,ROInames{roiNum}));
    

    if(length(bioM)>1)
        ylblstring=sprintf('\\Delta[X]');
    else
        ylblstring=sprintf('\\Delta[%s]',bioM{1});
    end
    
    if(isfield(fNIR,'units'))
        ylblstring=sprintf('%s %s',ylblstring,fNIR.units);
    end
    
    ylabel(ylblstring);
    
    
    if(roiIdx==length(rois2plot))
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
