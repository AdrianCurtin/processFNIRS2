function varargout = probeCheckGUI(varargin)
% PROBECHECKGUI MATLAB code for probeCheckGUI.fig
%      Function is called by ImportNIR as an early data screening tool.
%      Creates a *_CH.mat file containing identified rejected channels.
%      These values are loaded by ImportNIR into the fchmask automatically
%      and can optionally be used to mask the data for poor/lowquality
%      data.
%
%     
%
%      H = PROBECHECKGUI returns the handle to a new PROBECHECKGUI or the handle to
%      the existing singleton*.
%
%      PROBECHECKGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PROBECHECKGUI.M with the given input arguments.
%
%      PROBECHECKGUI('Property','Value',...) creates a new PROBECHECKGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before probeCheckGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to probeCheckGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help probeCheckGUI

%Channel check GUI changelog
%3/29/2019 - Modified marker display to stop after 500 pf2ChannelCheck.markers to speed up
%loading/ display time

% Last Modified by GUIDE v2.5 28-Jun-2019 09:03:37

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @probeCheckGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @probeCheckGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before probeCheckGUI is made visible.
function probeCheckGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to probeCheckGUI (see VARARGIN)

% Choose default command line output for probeCheckGUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

global pf2ChannelCheck

if(isfield(pf2ChannelCheck,'autoscale'))
    set(handles.checkbox_autoscale,'Value',pf2ChannelCheck.autoscale);
end
if(isfield(pf2ChannelCheck,'mark_noisy'))
    set(handles.checkbox_automark_noisy,'Value',pf2ChannelCheck.mark_noisy);
end

if(isfield(pf2ChannelCheck,'multiFigure'))
    set(handles.checkbox_multiFigureMode,'Value',pf2ChannelCheck.multiFigure);
else
    pf2ChannelCheck.multiFigure=get(handles.checkbox_multiFigureMode,'Value');
end

delete pf2ChannelCheck.maskIndicators;
pf2ChannelCheck.maskIndicators = [];
pf2ChannelCheck.plotHandles =[];
pf2ChannelCheck.mainPlotHandle =[];

set(handles.figure1, 'DoubleBuffer', 'on');
set(0, 'DefaultFigureRenderer', 'opengl'); % Use hardware acceleration if available
   


pf2ChannelCheck.autoscale=get(handles.checkbox_autoscale,'Value');
pf2ChannelCheck.mark_noisy=get(handles.checkbox_automark_noisy,'Value');

pf2ChannelCheck.noisyThreshold=0.1;
pf2ChannelCheck.overwriteExisting=false;


if(~isfield(pf2ChannelCheck,'showMarkers'))
    pf2ChannelCheck.showMarkers=true;
    set(handles.marker_listbox,'Enable','on');
else
    set(handles.markerCheck,'Value',pf2ChannelCheck.showMarkers);
    if(pf2ChannelCheck.showMarkers)
        set(handles.marker_listbox,'Enable','on');
    else
        set(handles.marker_listbox,'Enable','off');
    end
end




if (isempty(varargin))
    pf2ChannelCheck.nirsData=[];
    pf2ChannelCheck.nirsData.raw=[];
    pf2ChannelCheck.nirsData.time=0.5:0.5:500;
    %error('No data');
    fprintf(2,'Using simulated Data\n');
    pf2ChannelCheck.filepath=[];
elseif(isstruct(varargin{1}))
    pf2ChannelCheck.nirsData=varargin{1};
    
    if(isempty(pf2ChannelCheck.nirsData)||~isfield(pf2ChannelCheck.nirsData,'raw'))
       error('Empty dataset'); 
    end
    
    if(isfield(pf2ChannelCheck.nirsData,'fchMask'))
        pf2ChannelCheck.fchMask=pf2ChannelCheck.nirsData.fchMask;
    end
    
    
    if(length(varargin)>1) % pf2ChannelCheck.filepath
        pf2ChannelCheck.filepath=varargin{2};
    else
        pf2ChannelCheck.filepath=[];
    end
    
    if(length(varargin)>2) % pf2ChannelCheck.filepath
        pf2ChannelCheck.overwriteExisting=varargin{3};
    end
elseif((isstring(varargin{1})||ischar(varargin{1}))&&length(varargin)>1)
    pf2ChannelCheck.nirsData=pf2.Import.ImportNIR(varargin{2},true,false);
    
     if(isempty(pf2ChannelCheck.nirsData)||~isfield(pf2ChannelCheck.nirsData,'raw'))
       error('Empty dataset'); 
    end
    
    if(isfield(pf2ChannelCheck.nirsData,'fchMask'))
        pf2ChannelCheck.fchMask=pf2ChannelCheck.nirsData.fchMask;
    end
    
    pf2ChannelCheck.filepath=varargin{2};
    
    if(pf2_base.isnestedfield(pf2ChannelCheck,'nirsData.info.filename'))
        pf2ChannelCheck.filepath=pf2ChannelCheck.nirsData.info.filename;
    end
    
    
    
    
    
    if(length(varargin)>2) % pf2ChannelCheck.filepath
        pf2ChannelCheck.overwriteExisting=varargin{3};
    else
        pf2ChannelCheck.overwriteExisting=true;
    end
end




if(isfield(pf2ChannelCheck,'filepath')&&~isempty(pf2ChannelCheck.filepath))
    [pathstr, name, ext] = fileparts(pf2ChannelCheck.filepath);
    if(length(pathstr)>0)
        filestr=[pathstr,'/',name,'_CH.mat'];
    else
        filestr=[name,'_CH.mat'];
    end
    

    if exist(filestr, 'file') == 2
        chMaskFile=load(filestr,'fmask');
        
        pf2ChannelCheck.fchMask=chMaskFile.fmask;
        fprintf('Channel mask loaded from: %s\n',filestr);
        
    else
        pf2ChannelCheck.fchMask=[];
    end
    
    if(~pf2ChannelCheck.overwriteExisting&&~isempty(pf2ChannelCheck.fchMask))
        exitAndReturn(hObject, eventdata, handles,true)
        return;
    end
    
else
   name='Demo Mode'; 
end


if(isfield(pf2ChannelCheck.nirsData,'info')&&isfield(pf2ChannelCheck.nirsData.info,'probename')&&~contains(pf2ChannelCheck.nirsData.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',pf2ChannelCheck.nirsData.info.probename);
else
    cfgFilePath='';
end

if(~isfield(pf2ChannelCheck.nirsData,'probeinfo'))
    pf2ChannelCheck.nirsData.probeinfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
end


pf2ChannelCheck.probeNum=1;

if(isempty(pf2ChannelCheck.nirsData.raw))
   pf2ChannelCheck.nirsData.raw=rand(1000,length(pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum}.ChannelNumbers))*500+1000; 
end

    

setUpAxes(handles,pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum});




if(~isfield(pf2ChannelCheck.nirsData,'markers')||isempty(pf2ChannelCheck.nirsData.markers))
     pf2ChannelCheck.markers=[];
    set(handles.marker_listbox,'String',{''});
    set(handles.marker_listbox,'Value',[]);
    set(handles.marker_listbox,'Enable','off');
else
    pf2ChannelCheck.markers=pf2ChannelCheck.nirsData.markers;
    uMrk=sort(unique(pf2ChannelCheck.markers(:,2)));
    pf2ChannelCheck.curMarkerset=uMrk;
    mrkStr=cell(length(uMrk),1);
    for i=1:length(uMrk)
       mrkStr{i}=sprintf('%i (#%i)',uMrk(i),sum(pf2ChannelCheck.markers(:,2)==uMrk(i)));
       
    end
    
    set(handles.marker_listbox,'String',mrkStr);
    if(pf2ChannelCheck.showMarkers)
        set(handles.marker_listbox,'Value',1:length(uMrk));
        pf2ChannelCheck.curMarkers=pf2ChannelCheck.curMarkerset;
    else
        set(handles.marker_listbox,'Value',[]);
        pf2ChannelCheck.curMarkers=[];
    end
end

pf2ChannelCheck.handle.text_curChannel=handles.text_curChannel;
    
set(handles.currentfiletext,'String',name);
    

%pf2ChannelCheck.nirsData.raw(pf2ChannelCheck.nirsData.raw(:,1)==0,:)=[];

%Count num Channels
pf2ChannelCheck.numChannels=pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum}.NumOptodes;

if(pf2ChannelCheck.numChannels>0)
    pf2ChannelCheck.curChannel=1;
else
    pf2ChannelCheck.curChannel=0;
end




if(isfield(pf2ChannelCheck,'fchMask')&&~isempty(pf2ChannelCheck.fchMask))
    if(isfield(pf2ChannelCheck.nirsData,'fchMask')&&~isempty(pf2ChannelCheck.nirsData.fchMask))
        pf2ChannelCheck.fchMask=pf2ChannelCheck.nirsData.fchMask;
    else
         pf2ChannelCheck.fchMask=ones(1,pf2ChannelCheck.numChannels);
    end
else
   pf2ChannelCheck.fchMask=ones(1,pf2ChannelCheck.numChannels);
end

pf2ChannelCheck.Wavelengths= pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum}.TableCh.Wavelength;
pf2ChannelCheck.ChannelNumbers= pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum}.TableCh.OptodeNumber;

globalData=pf2ChannelCheck.nirsData.raw(:,...
     pf2ChannelCheck.Wavelengths>0);

globalData850=pf2ChannelCheck.nirsData.raw(:,...
     pf2ChannelCheck.Wavelengths>805&pf2ChannelCheck.Wavelengths<950);

globalData730=pf2ChannelCheck.nirsData.raw(:,...
    pf2ChannelCheck.Wavelengths>600&pf2ChannelCheck.Wavelengths<805);

pf2ChannelCheck.globalstats.max=nanmax(nanmax(globalData));
pf2ChannelCheck.globalstats.std=nanstd(globalData(:));
pf2ChannelCheck.globalstats.mean=nanmean(globalData(:));
pf2ChannelCheck.globalstats.cov=nanstd(globalData(:))/nanmean(globalData(:));
pf2ChannelCheck.globalstatsWV1.cov=nanstd(globalData730(:))/nanmean(globalData730(:));
pf2ChannelCheck.globalstatsWV2.cov=nanstd(globalData850(:))/nanmean(globalData850(:));
pf2ChannelCheck.globalstatsWV1.std=nanstd(globalData730(:));
pf2ChannelCheck.globalstatsWV1.mean=nanmean(globalData730(:));
pf2ChannelCheck.globalstatsWV2.std=nanstd(globalData850(:));
pf2ChannelCheck.globalstatsWV2.mean=nanmean(globalData850(:));



pf2ChannelCheck.stats=[];
pf2ChannelCheck.stats.cov=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.statsWV1.cov=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.statsWV2.cov=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.stats.mean=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.statsWV1.mean=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.statsWV2.mean=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.stats.std=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.statsWV1.std=nan(1,pf2ChannelCheck.numChannels);
pf2ChannelCheck.statsWV2.std=nan(1,pf2ChannelCheck.numChannels);

for i=1:pf2ChannelCheck.numChannels
    chIdx=(pf2ChannelCheck.Wavelengths>600&pf2ChannelCheck.ChannelNumbers==i);
    chIdx830=chIdx&pf2ChannelCheck.Wavelengths>805;
    chIdx730=chIdx&pf2ChannelCheck.Wavelengths<805;
    
    data=pf2ChannelCheck.nirsData.raw(:,chIdx);
    data830=pf2ChannelCheck.nirsData.raw(:,chIdx830);
    data730=pf2ChannelCheck.nirsData.raw(:,chIdx730);
    
    if(~isempty(data))

        pf2ChannelCheck.stats.cov(i)=nanstd(data(:))./nanmean(data(:));
        pf2ChannelCheck.stats.mean(i)=nanmean(data(:));
        pf2ChannelCheck.stats.std(i)=nanmean(data(:));

        pf2ChannelCheck.statsWV1.cov(i)=nanstd(data730(:))./nanmean(data730(:));
        pf2ChannelCheck.statsWV1.mean(i)=nanmean(data730(:));
        pf2ChannelCheck.statsWV1.std(i)=nanmean(data730(:));

        pf2ChannelCheck.statsWV2.cov(i)=nanstd(data830(:))./nanmean(data830(:));
        pf2ChannelCheck.statsWV2.mean(i)=nanmean(data830(:));
        pf2ChannelCheck.statsWV2.std(i)=nanmean(data830(:));
    end
    
end

if(pf2ChannelCheck.multiFigure)
    checkbox_multiFigureMode_Callback([], [], handles);
end

pf2ChannelCheck.orig_fmask=pf2ChannelCheck.fchMask;


% This sets up the initial plot - only do when we are invisible
% so window can get raised using probeCheckGUI.
if strcmp(get(hObject,'Visible'),'off')
    
   updateChannels(handles, true);
    
    
    %yaxis([0,4500]);
end

% UIWAIT makes probeCheckGUI wait for user response (see UIRESUME)
uiwait(handles.figure1);





function setUpAxes(handles,probInfo)
    
      
global pf2ChannelCheck
global pf2ChannelCheckHandles
 
pf2ChannelCheckHandles.mainCurAxesHandle=handles.chAxes;

uiP=handles.uipanel_arranged;
  

if(~isfield(probInfo,'OptLayout2D_ss')&&~isfield(probInfo,'OptPos'))
   
    
    warning('Unable to find 2D Optode Layout: Please build layout first');
end

pf2ChannelCheck.smallMode=false;

if(isfield(probInfo,'OptPos'))
    for c=1:size(probInfo.OptPos,1)
        curSubplot=probInfo.OptPos.subplot_layout_ss{c};
        if(c==1 && curSubplot(3)<0.15)
            pf2ChannelCheck.smallMode=true;
        end
        if(~isempty(probInfo.OptPos.subplot_layout_ss{c}))
         pf2ChannelCheckHandles.chAxesHandles{c} = axes(uiP);
         h=plot([1:20],[1:20],'HitTest','on');
         h.ButtonDownFcn = @markUnmarkChannelFcn;

         pf2ChannelCheckHandles.chAxesHandles{c}.OuterPosition=probInfo.OptPos.subplot_layout_ss{c};
         set(pf2ChannelCheckHandles.chAxesHandles{c},'Tag',sprintf('ChAxes%i',c));

         if(pf2ChannelCheck.smallMode)
            set(pf2ChannelCheckHandles.chAxesHandles{c},'XTick',[], 'YTick', [],'xticklabels',[],'yticklabels',[]);
         end

         pf2ChannelCheckHandles.chAxesHandles{c}.ButtonDownFcn = @markUnmarkChannelFcn;
        end
    end
else
    for c=1:size(probInfo.OptPos,1)
        if(~isempty(probInfo.OptPos.subplot_layout_ss{c}))
             pf2ChannelCheckHandles.chAxesHandles{c} = axes(uiP);
             h=plot([1:20],[1:20],'HitTest','on');
             h.ButtonDownFcn = @markUnmarkChannelFcn;
         
             pf2ChannelCheckHandles.chAxesHandles{c}.OuterPosition=probInfo.OptPos.subplot_layout{c};
             set(pf2ChannelCheckHandles.chAxesHandles{c},'Tag',sprintf('ChAxes%i',c));

             pf2ChannelCheckHandles.chAxesHandles{c}.ButtonDownFcn = @markUnmarkChannelFcn;
        end
    end
end



pf2ChannelCheckHandles.text_channelStats=handles.text_channelStats;

function markUnmarkChannelFcn(hObject, eventdata, handles)
    
curChTag=get(hObject,'Tag');

curChNum=str2double(curChTag(7:end));


markUnmarkChannel(curChNum,eventdata);
    

        
function [handle]= plotChannel(ch, plotMarkers, withTitle, mainPlot)
    global pf2ChannelCheck
    global pf2ChannelCheckHandles

    autoscale=pf2ChannelCheck.autoscale;
    mark_noisy=pf2ChannelCheck.mark_noisy;

    if(nargin<4)
        mainPlot = false;
    end

    if(nargin<3)
        withTitle=false;
    end
    
    if(nargin<2)
        plotMarkers=false;
    end
    
    if(nargin<1)
        ch=pf2ChannelCheck.curChannel;
    end

    channelsFilter = pf2ChannelCheck.ChannelNumbers > 0;
    
    
    curCh=find(pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum}.TableCh(channelsFilter,:).OptodeNumber==ch);
    curWv=pf2ChannelCheck.nirsData.probeinfo.Probe{pf2ChannelCheck.probeNum}.TableCh(channelsFilter,:).Wavelength(curCh);
    
    if(~isfield(pf2ChannelCheck,'viewTimeStart'))
       pf2ChannelCheck.viewTimeStart=min(pf2ChannelCheck.nirsData.time);
    end
    
    if(~isfield(pf2ChannelCheck,'viewTimeEnd'))
       pf2ChannelCheck.viewTimeEnd=max(pf2ChannelCheck.nirsData.time);
    end
    
    hold off;
    
    % OPTIMIZATION 1: Smart downsampling based on display needs
    sigLen = length(pf2ChannelCheck.nirsData.time);
    visibleTimeWindow = pf2ChannelCheck.viewTimeEnd - pf2ChannelCheck.viewTimeStart;
    
    % Determine reasonable number of points to display
    maxVisiblePoints = 1000; % This can be adjusted based on performance needs
    
    % Apply time range filter first to reduce data
    timeFilter = (pf2ChannelCheck.nirsData.time >= pf2ChannelCheck.viewTimeStart) & ...
                 (pf2ChannelCheck.nirsData.time <= pf2ChannelCheck.viewTimeEnd);

    
    
    if sum(timeFilter) > 0
        visibleTimeX = pf2ChannelCheck.nirsData.time(timeFilter);
        visibleDataY = pf2ChannelCheck.nirsData.raw(timeFilter,channelsFilter);
        
        % Apply downsampling
        [visibleTimeX, visibleDataY] = smartDownsample(visibleTimeX, visibleDataY, maxVisiblePoints);
        timeX = visibleTimeX;
        dataY = visibleDataY;
    else
        % Fallback if no data in range
        timeX = pf2ChannelCheck.nirsData.time;
        dataY = pf2ChannelCheck.nirsData.raw;
        [timeX, dataY] = smartDownsample(timeX, dataY, maxVisiblePoints);
    end

     maxVal = nanmax(nanmax(dataY(:,curCh)));
     maxVal = max(0.01,maxVal);
        
    
    % Get axes handle
    temp = get(gca);
    channelTag = sprintf('ChAxes%i',ch);
    set(gca, 'Tag', channelTag);
    set(gca, 'ButtonDownFcn', @markUnmarkChannelFcn);
    
    % OPTIMIZATION 2: Use object handles for persistent plotting
    % Check if we already have plot handles for this channel
    if ~isfield(pf2ChannelCheck, 'plotHandles') || length(pf2ChannelCheck.plotHandles) < ch || isempty(pf2ChannelCheck.plotHandles{ch})
        % First time setup
        if ~isfield(pf2ChannelCheck, 'plotHandles')
            pf2ChannelCheck.plotHandles = cell(1, pf2ChannelCheck.numChannels);
        end

        if ~isfield(pf2ChannelCheck, 'mainPlotHandle');
            pf2ChannelCheck.mainPlotHandle = [];
        end

        
        
        % Create new plot
        pf2ChannelCheck.plotHandles{ch} = gobjects(length(curCh), 1);
        for i=1:length(curCh)
            x = curCh(i);
            pf2ChannelCheck.plotHandles{ch}(i) = plot(timeX, dataY(:,x), 'linewidth', 2,'HitTest','on');
            set(pf2ChannelCheck.plotHandles{ch}(i), 'Tag', channelTag);
            set(pf2ChannelCheck.plotHandles{ch}(i), 'ButtonDownFcn', @markUnmarkChannelFcn);
            hold on;
        end


        
        
    else

        if ~isfield(pf2ChannelCheck,'mainPlotHandle') && mainPlot
            pf2ChannelCheck.mainPlotHandle = [];

            pf2ChannelCheck.mainPlotHandle = gobjects(length(curCh), 1);
            for i=1:length(curCh)
                x = curCh(i);
                pf2ChannelCheck.mainPlotHandle(i) = plot(timeX, dataY(:,x), 'linewidth', 2, 'HitTest','on');
                set(pf2ChannelCheck.mainPlotHandle(i), 'Tag', channelTag);
                set(pf2ChannelCheck.mainPlotHandle(i), 'ButtonDownFcn', @markUnmarkChannelFcn);
                hold on;
            end
        end

        maxVal = max(max(dataY(:,curCh)));
        maxVal = max(0.01,maxVal);
        
        % Update existing plot
        for i=1:length(curCh)
            x = curCh(i);

            if(~mainPlot)
                if ishandle(pf2ChannelCheck.plotHandles{ch}(i))
                    set(pf2ChannelCheck.plotHandles{ch}(i), 'XData', timeX);
                    set(pf2ChannelCheck.plotHandles{ch}(i), 'YData', dataY(:,x));
                    hold on;
                else
                    % Handle was deleted, recreate it
                    pf2ChannelCheck.plotHandles{ch}(i) = plot(timeX, dataY(:,x), 'linewidth', 2, 'HitTest','on');
                    set(pf2ChannelCheck.plotHandles{ch}(i), 'Tag', channelTag);
                    set(pf2ChannelCheck.plotHandles{ch}(i), 'ButtonDownFcn', @markUnmarkChannelFcn);
                    hold on;
                end
            else
                if ~isempty(pf2ChannelCheck.mainPlotHandle)&& i <= length(pf2ChannelCheck.mainPlotHandle)&&ishandle(pf2ChannelCheck.mainPlotHandle(i))
                    set(pf2ChannelCheck.mainPlotHandle(i), 'XData', timeX);
                    set(pf2ChannelCheck.mainPlotHandle(i), 'YData', dataY(:,x));
                    hold on;
                else
                    % Handle was deleted, recreate it
                    pf2ChannelCheck.mainPlotHandle(i) = plot(timeX, dataY(:,x), 'linewidth', 2, 'HitTest','on');
                    set(pf2ChannelCheck.mainPlotHandle(i), 'Tag', channelTag);
                    set(pf2ChannelCheck.mainPlotHandle(i), 'ButtonDownFcn', @markUnmarkChannelFcn);
                    hold on;
                end
            end
        end
    end

    
    
    % Set axis limits
    xlim([pf2ChannelCheck.viewTimeStart, pf2ChannelCheck.viewTimeEnd]);
    xl = xlim;
    
    if(isfield(pf2ChannelCheck.nirsData.probeinfo.Info,'RawMax')&&~pf2ChannelCheck.autoscale)
        
        if(~pf2ChannelCheck.smallMode&&~withTitle)
            plot(xl,ones(size(xl))*pf2ChannelCheck.nirsData.probeinfo.Info.RawMax,'--k');

        end

        
        ylim([0,pf2ChannelCheck.globalstats.max*1.1]);%pf2ChannelCheck.nirsData.probeinfo.Info.RawMax*1.1]);
    elseif(~pf2ChannelCheck.autoscale)
        ylim([0,pf2ChannelCheck.globalstats.max*1.1]);
        
    else
        if(~exist("maxVal"))
            maxVal=0.01;
        end
        ylim([0, maxVal*1.2]);
    end
    
    if(isfield(pf2ChannelCheck.nirsData.probeinfo.Info,'RawMin'))
        
        plot(xl,ones(size(xl))*pf2ChannelCheck.nirsData.probeinfo.Info.RawMin,'--k');
    end
   
    
    yl = ylim();
   
    % OPTIMIZATION 3: Optimize channel mask visualization
    % Initialize or update mask indicators
    if ~isfield(pf2ChannelCheck, 'maskIndicators') || length(pf2ChannelCheck.maskIndicators) < ch || isempty(pf2ChannelCheck.maskIndicators{ch})
        if ~isfield(pf2ChannelCheck, 'maskIndicators')
            pf2ChannelCheck.maskIndicators = cell(1, pf2ChannelCheck.numChannels);
        end
        
        
        
        pf2ChannelCheck.maskIndicators{ch} = text(mean(xl), mean(yl), 'X', 'HorizontalAlignment', 'center', 'FontSize', 40, 'Color', [1,0,0], 'Visible', 'off');
        set(pf2ChannelCheck.maskIndicators{ch}, 'ButtonDownFcn', @markUnmarkChannelFcn);
        set(pf2ChannelCheck.maskIndicators{ch}, 'Tag', channelTag);
    end

    % Update mask indicator visibility
    if pf2ChannelCheck.fchMask(ch) == 0
        set(pf2ChannelCheck.maskIndicators{ch}, 'Visible', 'on', 'String', 'X', 'Color', [1,0,0]);
    elseif pf2ChannelCheck.fchMask(ch) == 0.5
        set(pf2ChannelCheck.maskIndicators{ch}, 'Visible', 'on', 'String', '~', 'Color', [0.91,0.41,0.17]);
    else
        if(ishandle(pf2ChannelCheck.maskIndicators{ch}))
            set(pf2ChannelCheck.maskIndicators{ch}, 'Visible', 'off');
        end
    end

    noiseOffset = (max(xl)-min(xl) *0.4) + min(xl);

    if ~isfield(pf2ChannelCheck, 'noiseIndicators') || length(pf2ChannelCheck.noiseIndicators) < ch || isempty(pf2ChannelCheck.noiseIndicators{ch})
        if ~isfield(pf2ChannelCheck, 'noiseIndicators')
            pf2ChannelCheck.noiseIndicators = cell(1, pf2ChannelCheck.numChannels);
        end
        
        
        
        pf2ChannelCheck.noiseIndicators{ch} = text(noiseOffset,max(yl)-mean(yl)/4,'*','FontSize',20,'color',[ 0.2100,0.4100,0.2700],'HitTest','off','Visible','off');
    end

    if(pf2ChannelCheck.mark_noisy&&(pf2ChannelCheck.statsWV1.cov(ch)>pf2ChannelCheck.noisyThreshold||pf2ChannelCheck.statsWV2.cov(ch)>pf2ChannelCheck.noisyThreshold))
        if(isfield(pf2ChannelCheck, 'noiseIndicators')&&~isempty(pf2ChannelCheck.noiseIndicators{ch})&&ishandle(pf2ChannelCheck.noiseIndicators{ch}))
            pf2ChannelCheck.noiseIndicators{ch}.Visible= "on";
        else
            hold on
            pf2ChannelCheck.noiseIndicators{ch} = text(noiseOffset,max(yl)-mean(yl)/4,'*','FontSize',20,'color',[ 0.2100,0.4100,0.2700],'HitTest','off','Visible','on');
            hold on
        end
    end

    if (~mainPlot)
        if pf2ChannelCheck.curChannel == ch
            if(isfield(pf2ChannelCheck,'selectionIndicator') && ishandle(pf2ChannelCheck.selectionIndicator))
                pf2ChannelCheck.selectionIndicator.Visible = "off";
            end
            if exist('pf2ChannelCheck.selectionIndicator')
                delete pf2ChannelCheck.selectionIndicator
            end
            pf2ChannelCheck.selectionIndicator = text(mean(xl), mean(yl), 'O', 'HorizontalAlignment', 'center', 'FontSize', 60, 'Color', [0.2,0.2,0.2],'HitTest','off');
        end
    end
    % OPTIMIZATION 4: Optimize marker plotting
    if(withTitle && plotMarkers && ~isempty(pf2ChannelCheck.markers))
        % Filter markers to only those in the visible time range
        reducedMarkers = pf2ChannelCheck.markers(ismember(pf2ChannelCheck.markers(:,2), pf2ChannelCheck.curMarkers) & ...
                                                pf2ChannelCheck.markers(:,1) >= pf2ChannelCheck.viewTimeStart & ...
                                                pf2ChannelCheck.markers(:,1) <= pf2ChannelCheck.viewTimeEnd, :);
        
        maxMarkers = 200;
        yl = ylim();
        
        if ~isempty(reducedMarkers)
            numMarkers = min(size(reducedMarkers,1), maxMarkers);
            % Batch process markers for efficiency
            markerTimes = reducedMarkers(1:numMarkers,1);
            
            % Plot markers using a more efficient approach
            for i = 1:length(markerTimes)
                line([markerTimes(i) markerTimes(i)], yl, 'Color', 'k', 'LineStyle', '-');
            end
            
            if size(reducedMarkers,1) > maxMarkers
                fprintf(2,'Num Markers exceeds 200, only plotting first 200. Please select fewer markers\n');
            end
        end
    end
    
    % Rest of function remains unchanged
    hold off;
    if(withTitle)
        xlabel('Time (s)');
        ylabel('Light Intensity');
        title(sprintf('Channel %i of %i',ch,pf2ChannelCheck.numChannels));
        set(pf2ChannelCheck.handle.text_curChannel,'String',sprintf('Ch %i of %i',ch,pf2ChannelCheck.numChannels));
        set(pf2ChannelCheckHandles.text_channelStats,'String',getChannelStatStr(ch));
    elseif(pf2ChannelCheck.smallMode)
        xticklabels([]);
        yticklabels([]);
    end
    
    xlim([pf2ChannelCheck.viewTimeStart,pf2ChannelCheck.viewTimeEnd]);
    
    % Force redraw only when strictly necessary
    drawnow limitrate;
    
function statStr=getChannelStatStr(ch)

global pf2ChannelCheck

statStr='Stat Wv1 Wv2 All';

testStr=sprintf('%.5f',pf2ChannelCheck.globalstats.cov);
testStr=strsplit(testStr,'.');

testStrMean=sprintf('%.5f',pf2ChannelCheck.globalstats.mean);
testStrMean=strsplit(testStrMean,'.');
testStrStd=sprintf('%.5f',pf2ChannelCheck.globalstats.std);
testStrStd=strsplit(testStrStd,'.');

maxSigDig=5;

sigdigcov=max(0,maxSigDig-length(testStr{1}));
sigdigmean=max(0,maxSigDig-length(testStrMean{1}));
sigdigstd=max(0,maxSigDig-length(testStrStd{1}));

switch(sigdigmean)
    case 6
        statStr=sprintf('%s\nm: %.6f %.6f %.6f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
    case 5
        statStr=sprintf('%s\nm: %.5f %.5f %.5f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
    case 4
        statStr=sprintf('%s\nm: %.4f %.4f %.4f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
    case 3
        statStr=sprintf('%s\nm: %.3f %.3f %.3f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
    case 2
        statStr=sprintf('%s\nm: %.2f %.2f %.2f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
    case 1
        statStr=sprintf('%s\nm: %.1f %.1f %.1f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
    case 0
        statStr=sprintf('%s\nm: %.0f %.0f %.0f',statStr,pf2ChannelCheck.statsWV1.mean(ch),pf2ChannelCheck.statsWV2.mean(ch),pf2ChannelCheck.stats.mean(ch));
end

switch(sigdigstd)
    case 6
        statStr=sprintf('%s\ns: %.6f %.6f %.6f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
    case 5
        statStr=sprintf('%s\ns: %.5f %.5f %.5f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
    case 4
        statStr=sprintf('%s\ns: %.4f %.4f %.4f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
    case 3
        statStr=sprintf('%s\ns: %.3f %.3f %.3f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
    case 2
        statStr=sprintf('%s\ns: %.2f %.2f %.2f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
    case 1
        statStr=sprintf('%s\ns: %.1f %.1f %.1f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
    case 0
        statStr=sprintf('%s\ns: %.0f %.0f %.0f',statStr,pf2ChannelCheck.statsWV1.std(ch),pf2ChannelCheck.statsWV2.std(ch),pf2ChannelCheck.stats.std(ch));
end

switch(sigdigcov)
    case 6
        statStr=sprintf('%s\nCv %.6f %.6f %.6f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
    case 5
        statStr=sprintf('%s\nCv %.5f %.5f %.5f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
    case 4
        statStr=sprintf('%s\nCv %.4f %.4f %.4f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
    case 3
        statStr=sprintf('%s\nCv %.3f %.3f %.3f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
    case 2
        statStr=sprintf('%s\nCv %.2f %.2f %.2f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
    case 1
        statStr=sprintf('%s\nCv %.1f %.1f %.1f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
    case 0
        statStr=sprintf('%s\nCv %.0f %.0f %.0f',statStr,pf2ChannelCheck.statsWV1.cov(ch),pf2ChannelCheck.statsWV2.cov(ch),pf2ChannelCheck.stats.cov(ch));
end



% --- Outputs from this function are returned to the command line.
function varargout = probeCheckGUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure

global pf2ChannelCheck
global pf2ChannelCheckHandles
pf2ChannelCheck.nirsData.fchMask=pf2ChannelCheck.fchMask;
varargout = {pf2ChannelCheck.nirsData};

autoscale=pf2ChannelCheck.autoscale;
mark_noisy=pf2ChannelCheck.mark_noisy;
if(isfield(pf2ChannelCheck,'multiFigure'))
    twoFig= pf2ChannelCheck.multiFigure;
else
    twoFig=false;
end

pf2ChannelCheck=[];
pf2ChannelCheckHandles=[];
pf2ChannelCheck.autoscale=autoscale;
pf2ChannelCheck.mark_noisy=mark_noisy;
pf2ChannelCheck.multiFigure=twoFig;


% --------------------------------------------------------------------
function FileMenu_Callback(hObject, eventdata, handles)
% hObject    handle to FileMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OpenMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file = uigetfile('*.fig');
if ~isequal(file, 0)
    open(file);
end



% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

function updateChannels(handles, forceUpdate)
    global pf2ChannelCheck
    global pf2ChannelCheckHandles

    if(nargin<2)
        forceUpdate = false;
    end
    
    % OPTIMIZATION: Only update current channel in full detail
    axes(pf2ChannelCheckHandles.mainCurAxesHandle);
    plotChannel(pf2ChannelCheck.curChannel, pf2ChannelCheck.showMarkers, true, true);
    
    % For other channels, only update if necessary
    for i=1:pf2ChannelCheck.numChannels
        if i ~= pf2ChannelCheck.curChannel
            % Check if axis needs update (e.g., channel status changed)
            needsUpdate = forceUpdate; % Set criteria for when update is needed
            
            if needsUpdate
                axes(pf2ChannelCheckHandles.chAxesHandles{i});
                plotChannel(i, false);
            end
        else
            axes(pf2ChannelCheckHandles.chAxesHandles{i});
            plotChannel(i, false);
        end
    end
    
    % Reduce redraw frequency
    drawnow limitrate;
    

% --- Executes on button press in rejectButton.
function rejectButton_Callback(hObject, eventdata, handles)
% hObject    handle to rejectButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
global pf2ChannelCheckHandles

pf2ChannelCheck.fchMask(pf2ChannelCheck.curChannel)=0;
axes(pf2ChannelCheckHandles.chAxesHandles{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false);
axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);


% --- Executes on button press in noisyButton.
function noisyButton_Callback(hObject, eventdata, handles)
% hObject    handle to noisyButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
global pf2ChannelCheckHandles
pf2ChannelCheck.fchMask(pf2ChannelCheck.curChannel)=0.5;
axes(pf2ChannelCheckHandles.chAxesHandles{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false);
axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);


%nextButton_Callback(hObject, eventdata, handles);


% --- Executes on button press in cleanButton.
function cleanButton_Callback(hObject, eventdata, handles)
% hObject    handle to cleanButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
global pf2ChannelCheckHandles
pf2ChannelCheck.fchMask(pf2ChannelCheck.curChannel)=1;
axes(pf2ChannelCheckHandles.chAxesHandles{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false);
axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);



% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if isequal(get(hObject, 'waitstatus'), 'waiting')
% The GUI is still in UIWAIT, us UIRESUME
uiresume(hObject);
end

delete(hObject);


function []=exitAndReturn(hObject, eventdata, handles,skipSave)
    
if(nargin<4)
    skipSave=false;
end  
global pf2ChannelCheck

if(isfield(pf2ChannelCheck,'saved')&&~pf2ChannelCheck.saved)
   skipSave=true; 
end

%If not already loaded write output
if(isfield(pf2ChannelCheck,'fchMask')&&~isempty(pf2ChannelCheck.fchMask)&&~isempty(pf2ChannelCheck.filepath))
   % doc fileparts:
    [pathstr, name, ext] = fileparts(pf2ChannelCheck.filepath);
    pathstr=sprintf('%s/',pathstr);
    filestr=sprintf('%s_CH.mat',name);
    if(length(pathstr)>1)
        filestr=[pathstr,filestr];
    end
    %filestr=[pathstr,'/',name,'_CH.mat'];
    if(~skipSave)
        pf2ChannelCheck.saved=true;
        
        fmask=pf2ChannelCheck.fchMask;
        save(filestr,'fmask');
        fprintf('Channel mask saved to %s\n',filestr);
    end
    
end

close();

if(isfield(handles,'figure1'))
   delete(handles.figure1); 
end


if(pf2_base.isnestedfield(hObject,'Parent.Parent'))
    uiresume(hObject.Parent.Parent);
end





% --- Executes on button press in markerCheck.
function markerCheck_Callback(hObject, eventdata, handles)
% hObject    handle to markerCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of markerCheck
  
global pf2ChannelCheck
pf2ChannelCheck.showMarkers=get(handles.markerCheck,'Value');

if(pf2ChannelCheck.showMarkers)
    set(handles.marker_listbox,'Enable','on');
    
    pf2ChannelCheck.curMarkersInd=get(handles.marker_listbox,'Value');

    if(~isfield(pf2ChannelCheck,'pf2ChannelCheck.curMarkerset')||isempty(pf2ChannelCheck.curMarkerset))
        return;
    end

    pf2ChannelCheck.curMarkers=pf2ChannelCheck.curMarkerset(pf2ChannelCheck.curMarkersInd);

    axes(pf2ChannelCheckHandles.mainCurAxesHandle);
    plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true,true);
else
    pf2ChannelCheck.curMarkers=[];
    set(handles.marker_listbox,'Enable','off');
    plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);
end



function markUnmarkChannel(ch, eventdata)
    global pf2ChannelCheck
    global pf2ChannelCheckHandles
    
    % Save previous channel to update it
    oldChannel = pf2ChannelCheck.curChannel;
    pf2ChannelCheck.curChannel = ch;
    
    b = eventdata.Button;
    if b==1
        % Left click - just select
    else
        % Right click - cycle status
        switch pf2ChannelCheck.fchMask(ch)
            case 0
                pf2ChannelCheck.fchMask(ch) = 0.5;
            case 0.5
                pf2ChannelCheck.fchMask(ch) = 1;
            case 1
                pf2ChannelCheck.fchMask(ch) = 0;
        end
    end
    
    % Update only the channels that changed
    axes(pf2ChannelCheckHandles.chAxesHandles{ch});
    plotChannel(ch, false);
    
    % Only update the main display if the current channel changed
    if oldChannel ~= ch
        axes(pf2ChannelCheckHandles.mainCurAxesHandle);
        plotChannel(ch, pf2ChannelCheck.showMarkers, true, true);
    end
    
    % Instead of full redraw, just update indicators
    updateMaskIndicator(ch);
    
    % Force limited redraw
    drawnow limitrate;
    
function updateMaskIndicator(ch)
    global pf2ChannelCheck
    
    if isfield(pf2ChannelCheck, 'maskIndicators') && length(pf2ChannelCheck.maskIndicators) >= ch && ~isempty(pf2ChannelCheck.maskIndicators{ch})
        if pf2ChannelCheck.fchMask(ch) == 0
            set(pf2ChannelCheck.maskIndicators{ch}, 'Visible', 'on', 'String', 'X', 'Color', [1,0,0]);
        elseif pf2ChannelCheck.fchMask(ch) == 0.5
            set(pf2ChannelCheck.maskIndicators{ch}, 'Visible', 'on', 'String', '~', 'Color', [0.91,0.41,0.17]);
        else
            set(pf2ChannelCheck.maskIndicators{ch}, 'Visible', 'off');
        end
    end


% --- Executes on button press in savebutton.
function savebutton_Callback(hObject, eventdata, handles)
% hObject    handle to savebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
if(isfield(pf2ChannelCheck,'filepath')&&~isempty(pf2ChannelCheck.filepath))
    [pathstr, name, ext] = fileparts(pf2ChannelCheck.filepath);
    pathstr=sprintf('%s/',pathstr);
    filestr=sprintf('%s_CH.mat',name);
    if(length(pathstr)>1)
        filestr=[pathstr,filestr];
    end
    %filestr=[pathstr,'/',name,'_CH.mat'];
    fchMask=pf2ChannelCheck.fchMask;
    save(filestr,'fchMask');
    
    fprintf('Channel mask saved to %s\n',filestr);
end
exitAndReturn(hObject, eventdata, true);


% --- Executes on mouse press over axes background.
function chAxes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chAxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
markUnmarkChannel(pf2ChannelCheck.curChannel,eventdata);


% --- Executes on button press in newfigurebutton.
function newfigurebutton_Callback(hObject, eventdata, handles)
% hObject    handle to newfigurebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
figure(1);  
global pf2ChannelCheck
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);


% --------------------------------------------------------------------
function filemenu_Callback(hObject, eventdata, handles)
% hObject    handle to filemenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function menu_channel_Callback(hObject, eventdata, handles)
% hObject    handle to menu_channel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function menu_next_Callback(hObject, eventdata, handles)
% hObject    handle to menu_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
nextButton_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function menu_clean_Callback(hObject, eventdata, handles)
% hObject    handle to menu_clean (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
cleanButton_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function menu_reject_Callback(hObject, eventdata, handles)
% hObject    handle to menu_reject (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
rejectButton_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function menu_previous_Callback(hObject, eventdata, handles)
% hObject    handle to menu_previous (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
prevButton_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function menu_showhide_Callback(hObject, eventdata, handles)
% hObject    handle to menu_showhide (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
markerCheck_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function menu_save_Callback(hObject, eventdata, handles)
% hObject    handle to menu_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
savebutton_Callback(hObject, [], handles); 

% --------------------------------------------------------------------
function menu_close_Callback(hObject, eventdata, handles)
% hObject    handle to menu_close (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
pf2ChannelCheck.fchMask=[];
exitAndReturn(hObject, eventdata, handles)


% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
pf2ChannelCheck.fchMask=pf2ChannelCheck.orig_fmask;
exitAndReturn(hObject, eventdata, handles,true)


% --- Executes during object creation, after setting all properties.
function cancelbutton_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% --- Executes during object creation, after setting all properties.
function currentfiletext_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on selection change in marker_listbox.
function marker_listbox_Callback(hObject, eventdata, handles)
% hObject    handle to marker_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns marker_listbox contents as cell array
%        contents{get(hObject,'Value')} returns selected item from marker_listbox
  
global pf2ChannelCheck
global pf2ChannelCheckHandles
pf2ChannelCheck.curMarkersInd=get(handles.marker_listbox,'Value');
pf2ChannelCheck.curMarkers=pf2ChannelCheck.curMarkerset(pf2ChannelCheck.curMarkersInd);

axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);

axes(pf2ChannelCheckHandles.chAxesHandles{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false,false);

% --- Executes during object creation, after setting all properties.
function marker_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to marker_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_multiFigureMode.
function checkbox_multiFigureMode_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_multiFigureMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_multiFigureMode

global pf2ChannelCheck
global pf2ChannelCheckHandles
pf2ChannelCheck.multiFigure=get(handles.checkbox_multiFigureMode,'Value');

if(pf2ChannelCheck.multiFigure)
    set(handles.uipanel_curCh,'OuterPosition',[-0.001,0.001,0.918,0.001]);
    set(handles.uipanel_arranged,'OuterPosition',[-0.001,0.001,0.918,0.913]);
    newFig=figure(2020);
    
    pf2ChannelCheckHandles.mainCurAxesHandle=axes(newFig);
    pf2ChannelCheck.mainPlotHandle = [];
    set(pf2ChannelCheckHandles.mainCurAxesHandle,'Tag',sprintf('ChAxes%i',pf2ChannelCheck.curChannel));
    plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true,true);
    set(newFig,'ButtonDownFcn',@markUnmarkChannelFcn);
    set(pf2ChannelCheckHandles.mainCurAxesHandle,'ButtonDownFcn',@markUnmarkChannelFcn);
else
    
    try
        axes(pf2ChannelCheckHandles.mainCurAxesHandle)
        close(gcf());
    catch
        
    end
    
    
    pf2ChannelCheckHandles.mainCurAxesHandle=handles.chAxes;
    
    set(handles.uipanel_curCh,'OuterPosition',[-0.001,0.471,0.918,0.447]);
    set(handles.uipanel_arranged,'OuterPosition',[-0.001,0.001,0.918,0.466]);
    axes(pf2ChannelCheckHandles.mainCurAxesHandle);
    plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);
end


% --- Executes on button press in pushbutton_mrk_all.
function pushbutton_mrk_all_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_mrk_all (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global pf2ChannelCheck
if(isfield(pf2ChannelCheck,'pf2ChannelCheck.curMarkerset')&&~isempty(pf2ChannelCheck.curMarkerset))

set(handles.marker_listbox,'Value',1:length(pf2ChannelCheck.curMarkerset));

end


% --- Executes on button press in pushbutton_mrk_none.
function pushbutton_mrk_none_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_mrk_none (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


set(handles.marker_listbox,'Value',[]);


% --- Executes on button press in pushbutton_prev.
function pushbutton_prev_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_prev (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
global pf2ChannelCheckHandles

prevChannel = pf2ChannelCheck.curChannel;
if(pf2ChannelCheck.curChannel>1)
    pf2ChannelCheck.curChannel=pf2ChannelCheck.curChannel-1;

else
    pf2ChannelCheck.curChannel=pf2ChannelCheck.numChannels;
    
end

axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);

axes(pf2ChannelCheckHandles.chAxesHandles{prevChannel});
plotChannel(prevChannel,pf2ChannelCheck.showMarkers,false, false);

axes(pf2ChannelCheckHandles.chAxesHandles{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,false, false);

% --- Executes on button press in pushbutton_next.
function pushbutton_next_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

  
global pf2ChannelCheck
global pf2ChannelCheckHandles

prevChannel = pf2ChannelCheck.curChannel;
if(pf2ChannelCheck.curChannel<pf2ChannelCheck.numChannels)
    pf2ChannelCheck.curChannel=pf2ChannelCheck.curChannel+1;

else
    pf2ChannelCheck.curChannel=1;
    
end

axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);

axes(pf2ChannelCheckHandles.mainCurAxesHandle);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true, true);

axes(pf2ChannelCheckHandles.chAxesHandles{prevChannel});
plotChannel(prevChannel,pf2ChannelCheck.showMarkers,false, false);

axes(pf2ChannelCheckHandles.chAxesHandles{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,false, false);



% --- Executes on button press in checkbox_autoscale.
function checkbox_autoscale_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_autoscale (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_autoscale
global pf2ChannelCheck
pf2ChannelCheck.autoscale=get(handles.checkbox_autoscale,'Value');

updateChannels(handles, true);



% --- Executes on button press in checkbox_automark_noisy.
function checkbox_automark_noisy_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_automark_noisy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_automark_noisy
% Hint: get(hObject,'Value') returns toggle state of checkbox_autoscale
global pf2ChannelCheck
pf2ChannelCheck.mark_noisy=get(handles.checkbox_automark_noisy,'Value');

updateChannels(handles, true);


function [downsampledTime, downsampledData] = smartDownsample(time, data, maxPoints)
    len = size(data, 1);
    if len > maxPoints
        % Calculate step size based on visible points
        step = max(1, floor(len/maxPoints));
        
        % Basic downsampling for large datasets
        downsampledData = data(1:step:end, :);
        downsampledTime = time(1:step:end);
    else
        downsampledData = data;
        downsampledTime = time;
    end