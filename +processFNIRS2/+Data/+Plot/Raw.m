function [ figHandle ] = Raw(fNIR,channels,showMarkers,wavelengths,ylimit,plotArranged,lineProps,rejectedLineProps)
%processFNIRS2.Plot.Raw  
%   plots an individual channels or autoarranged plot of the channelss based on the device

% specify an individual optode to plot that or leave blank or 'all' to plot
% all channels arranged

% showMarkers argument can be an array of markers, strings of marker
% labels, or just true/false to plot all

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
    probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,plotArranged);
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


if(isempty(channels))
    channels=1:probeInfo.NumOptodes;
end

if(nargin<4||isempty(wavelengths)||(ischar(wavelengths)&&strcmpi(wavelengths,'all')))
    wavelengths=unique(probeInfo.Wavelength);
else
    wavelengths=unique(wavelengths(ismember(wavelengths,probeInfo.Wavelength)));
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

idx2plot=ismember(probeInfo.ChannelNumbers,channels);
wv2plot=ismember(probeInfo.Wavelength,wavelengths);
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
tooManyLabels=30;
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


if(length(ylimit)==1)
    ylimit=[0,maxRawValue];
elseif(length(ylimit)>2||isempty(ylimit))
   ylimit=[RawMin,maxRawValue];
end



h=cell(0);
for(optIdx=1:length(channels))
    optNum=channels(optIdx);
    if(plotArranged)
        optPos=probeInfo.OptLayout2D{optNum};
        optPos([3,4])=optPos([3,4]).*[0.65,0.9];
        optPos([1,2])=optPos([1,2])+0.03;
        h{optIdx}= axes('Position',optPos,'Box','on');
        
    else
        h{optIdx}=subplot(length(channels),1,optIdx);
    end
    
    gh=gcf();
    dcm_obj=datacursormode(gh);
    set(dcm_obj,'DisplayStyle','datatip',...
        'SnapToDataVertex','off','Enable','on');
    set(dcm_obj,'UpdateFcn', @myupdatefcn);
    
    idx2plot=probeInfo.ChannelNumbers==optNum;
    wv2plot=ismember(probeInfo.Wavelength,wavelengths);
    curWv=probeInfo.Wavelength(wv2plot);
    
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
            lh=plot(t,rawToPlot,rejectedLineProps{:},lineProps{:});
            switch(fNIR.fchMask(optNum))
                case 0.5
                    th=text(tmin+tmean*0.6,mean(ylimit),'~','FontSize',20,'color',[ 0.9100,0.4100,0.1700]);
                case 0
                    th=text(tmin+tmean*0.6,mean(ylimit),'X','FontSize',20,'color',[ 1,0.2100,0.1700]);
            end
                
        elseif(~isempty(lineProps))
            lh=plot(t,rawToPlot,lineProps{:});
        else
            lh=plot(t,rawToPlot);
        end
        
        if(curWv(i)==0)
            set(lh,'Tag',sprintf('Opt%i:Ambient',optNum));
        else
            set(lh,'Tag',sprintf('Opt%i:%inm',optNum,curWv(i)));
        end
    end
    
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
                    pf2_base.external.vline(curMarkers(showMarkersIdx==i));
                    fprintf('Marker %i has too many instances to plot labels',showMarkers(i));
                end
                
            end
        end
    end
    
    
    hold off;

    xlim([tmin,tmax]);
    
    ylim(ylimit);
    
    
    
    
    xlabel(sprintf('Opt %i',optNum));
    ylabel('Intensity');
    
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
