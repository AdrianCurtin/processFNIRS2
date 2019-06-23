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

% Last Modified by GUIDE v2.5 20-Jun-2019 14:46:00

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
pf2ChannelCheck=[];



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
    pf2ChannelCheck.nirsData.raw=rand(1000,49)*500+1000;
    pf2ChannelCheck.nirsData.time=0.5:0.5:500;
    %error('No data');
    fprintf(2,'Using simulated Data\n');
    pf2ChannelCheck.filepath=[];
else
    pf2ChannelCheck.nirsData=varargin{1};
    
    if(isempty(pf2ChannelCheck.nirsData)||~isfield(pf2ChannelCheck.nirsData,'raw'))
       error('Empty dataset'); 
    end
    
    if(isfield(pf2ChannelCheck.nirsData,'fchMask'))
        pf2ChannelCheck.fmask=pf2ChannelCheck.nirsData.fchMask;
    end
    
    
    if(length(varargin)>1) % pf2ChannelCheck.filepath
        pf2ChannelCheck.filepath=varargin{2};
    else
        pf2ChannelCheck.filepath=[];
    end
    
    if(length(varargin)>2) % pf2ChannelCheck.filepath
        pf2ChannelCheck.overwriteExisting=varargin{3};
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
        pf2ChannelCheck.fmask=chMaskFile.fmask;
        fprintf('Channel mask loaded from: %s\n',filestr);
        
    else
        pf2ChannelCheck.fmask=[];
    end
    
    if(~pf2ChannelCheck.overwriteExisting&&~isempty(pf2ChannelCheck.fmask))
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

pf2ChannelCheck.nirsData.info.probe=pf2_base.loadDeviceCfg(cfgFilePath,true);
    
pf2ChannelCheck.probeNum=1;

setUpAxes(handles,pf2ChannelCheck.nirsData.info.probe.Probe{pf2ChannelCheck.probeNum});


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
pf2ChannelCheck.numChannels=pf2ChannelCheck.nirsData.info.probe.Probe{pf2ChannelCheck.probeNum}.NumOptodes;

if(isfield(pf2ChannelCheck,'fmask')&&isempty(pf2ChannelCheck.fmask))
    if(isfield(pf2ChannelCheck.nirsdata,'fchMask'))
        pf2ChannelCheck.fmask=pf2ChannelCheck.nirsdata.fchMask;
    else
         pf2ChannelCheck.fmask=ones(1,pf2ChannelCheck.numChannels);
    end
end

if(pf2ChannelCheck.numChannels>0)
    pf2ChannelCheck.curChannel=1;
else
    pf2ChannelCheck.curChannel=0;
end
% This sets up the initial plot - only do when we are invisible
% so window can get raised using probeCheckGUI.
if strcmp(get(hObject,'Visible'),'off')
    
   updateChannels(handles);
    
    
    %yaxis([0,4500]);
end

% UIWAIT makes probeCheckGUI wait for user response (see UIRESUME)
uiwait(handles.figure1);


function setUpAxes(handles,probInfo)
    
      
global pf2ChannelCheck
 
pf2ChannelCheck.chCurAxesHandle=handles.chAxes;

uiP=handles.uipanel_arranged;
  

if(~isfield(probInfo,'OptLayout2D'))
    error('Unable to find 2D Optode Layout: Please build layout first');
end


for c=1:length(probInfo.OptLayout2D)
     pf2ChannelCheck.chAxesHandles{c} = axes(uiP);
     plot([1:20],[1:20]);
     pf2ChannelCheck.chAxesHandles{c}.OuterPosition=probInfo.OptLayout2D{c};
     set(pf2ChannelCheck.chAxesHandles{c},'Tag',sprintf('ChAxes%i',c));
     
     pf2ChannelCheck.chAxesHandles{c}.ButtonDownFcn = @myupdatefcn;
end

function myupdatefcn(hObject, eventdata, handles)
    
curChTag=get(hObject,'Tag');

curChNum=str2double(curChTag(7:end));


markUnmarkChannel(curChNum,eventdata);
    
    

        

function [handle]= plotChannel(ch,plotMarkers,withTitle)

      
global pf2ChannelCheck
if(nargin<3)
    withTitle=false;
end

if(nargin<2)
    plotMarkers=false;
end

if(nargin<1)
    ch=pf2ChannelCheck.curChannel;
end

curCh=find(pf2ChannelCheck.nirsData.info.probe.Probe{pf2ChannelCheck.probeNum}.ChannelNumbers==ch);
curWv=pf2ChannelCheck.nirsData.info.probe.Probe{pf2ChannelCheck.probeNum}.Wavelength(curCh);

if(~isfield(pf2ChannelCheck,'viewTimeStart'))
   pf2ChannelCheck.viewTimeStart=min(pf2ChannelCheck.nirsData.time);
end

if(~isfield(pf2ChannelCheck,'viewTimeEnd'))
   pf2ChannelCheck.viewTimeEnd=max(pf2ChannelCheck.nirsData.time);
end

    
    hold off;

    for i=1:length(curCh)
        x=curCh(i);
        temp=get(gca);
        
        handle=plot(pf2ChannelCheck.nirsData.time,pf2ChannelCheck.nirsData.raw(:,x),'linewidth',2);
        set(gca,'ButtonDownFcn',temp.ButtonDownFcn);
        set(gca,'Tag',temp.Tag);
        hold on;
    end
    
   xlim([pf2ChannelCheck.viewTimeStart,pf2ChannelCheck.viewTimeEnd]);
   xl=xlim; 

    if(isfield(pf2ChannelCheck.nirsData.info.probe.Info,'RawMax'))
        
        plot(xl,ones(size(xl))*pf2ChannelCheck.nirsData.info.probe.Info.RawMax,'--k');
        
        yl=ylim();
        ylim([0,pf2ChannelCheck.nirsData.info.probe.Info.RawMax*1.1]);
    end
    
    if(isfield(pf2ChannelCheck.nirsData.info.probe.Info,'RawMin'))
        
        plot(xl,ones(size(xl))*pf2ChannelCheck.nirsData.info.probe.Info.RawMin,'--k');
    end
    
    yl=ylim();

    if(pf2ChannelCheck.fmask(ch)==0) % big red x to mark rejected
        th=text(mean(xl)/2+15,mean(yl),'X','FontSize',40,'color',[1,0,0]);
        set(th,'ButtonDownFcn',temp.ButtonDownFcn);
        set(th,'Tag',temp.Tag);
        hold on;
    elseif(pf2ChannelCheck.fmask(ch)==0.5)
        th=text(mean(xl)/2+15,mean(yl),'~','FontSize',50,'color',[ 0.9100,0.4100,0.1700]);
        set(th,'ButtonDownFcn',temp.ButtonDownFcn);
        set(th,'Tag',temp.Tag);
        hold on;
    end
    
    
    
    if(plotMarkers&&~isempty(pf2ChannelCheck.markers))
        reducedMarkers=pf2ChannelCheck.markers(ismember(pf2ChannelCheck.markers(:,2),pf2ChannelCheck.curMarkers),:);
        
        numMarkers=length(reducedMarkers(:,1));
        
        maxMarkers=200;
        if(numMarkers>maxMarkers)
               fprintf(2,'Num Markers exceeds 200, only plotting first 200. Please select fewer pf2ChannelCheck.markers\n');
        end
        
        for i=1:min(length(reducedMarkers(:,1)),maxMarkers)
            pf2_base.external.vline(reducedMarkers(i,1),'-k');
        end
       
    end

    hold off;
    if(withTitle)
        xlabel('Time (s)');
        ylabel('Light Intensity');
        title(sprintf('Channel %i of %i',ch,pf2ChannelCheck.numChannels));
        set(pf2ChannelCheck.handle.text_curChannel,'String',sprintf('Ch %i of %i',ch,pf2ChannelCheck.numChannels));
    end
    
        xlim([pf2ChannelCheck.viewTimeStart,pf2ChannelCheck.viewTimeEnd]);
    


% --- Outputs from this function are returned to the command line.
function varargout = probeCheckGUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure

global pf2ChannelCheck
pf2ChannelCheck.nirsData.fchMask=pf2ChannelCheck.fmask;
varargout = {pf2ChannelCheck.nirsData};
pf2ChannelCheck=[];
clear pf2ChannelCheck;


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




function updateChannels(handles)
  
global pf2ChannelCheck
axes(handles.chAxes);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);

for i=1:pf2ChannelCheck.numChannels
    axes(pf2ChannelCheck.chAxesHandles{i});
    plotChannel(i,false);
end
% --- Executes on button press in rejectButton.
function rejectButton_Callback(hObject, eventdata, handles)
% hObject    handle to rejectButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck

pf2ChannelCheck.fmask(pf2ChannelCheck.curChannel)=0;
axes(pf2ChannelCheck.chCurAxesHandle{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false);
axes(handles.chAxes);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);


% --- Executes on button press in noisyButton.
function noisyButton_Callback(hObject, eventdata, handles)
% hObject    handle to noisyButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
pf2ChannelCheck.fmask(pf2ChannelCheck.curChannel)=0.5;
axes(pf2ChannelCheck.chCurAxesHandle{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false);
axes(handles.chAxes);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);


%nextButton_Callback(hObject, eventdata, handles);


% --- Executes on button press in cleanButton.
function cleanButton_Callback(hObject, eventdata, handles)
% hObject    handle to cleanButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
pf2ChannelCheck.fmask(pf2ChannelCheck.curChannel)=1;
axes(pf2ChannelCheck.chCurAxesHandle{pf2ChannelCheck.curChannel});
plotChannel(pf2ChannelCheck.curChannel,false);
axes(handles.chAxes);
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
if(isfield(pf2ChannelCheck,'fmask')&&~isempty(pf2ChannelCheck.fmask)&&~isempty(pf2ChannelCheck.filepath))
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
        
        fmask=pf2ChannelCheck.fmask;
        save(filestr,'fmask');
        fprintf('Channel mask saved to %s\n',filestr);
    end
    
end

if(isnestedfield(hObject,'Parent.Parent'))
    uiresume(hObject.Parent.Parent);
end

if(isfield(handles,'figure1'))
   delete(handles.figure1); 
end


close();

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

    axes(handles.chAxes);
    plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);
else
    pf2ChannelCheck.curMarkers=[];
    set(handles.marker_listbox,'Enable','off');
    plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);
end




function markUnmarkChannel(ch,eventdata)
  
global pf2ChannelCheck
pf2ChannelCheck.curChannel=ch;

b = eventdata.Button;
if b==1
    
else
    switch pf2ChannelCheck.fmask(ch)
        case 0
            pf2ChannelCheck.fmask(ch)=0.5;
        case 0.5
            pf2ChannelCheck.fmask(ch)=1;
        case 1
            pf2ChannelCheck.fmask(ch)=0;
    end
end

axes(pf2ChannelCheck.chAxesHandles{ch});
plotChannel(ch,false);

axes(pf2ChannelCheck.chCurAxesHandle);
plotChannel(ch,pf2ChannelCheck.showMarkers,true);


 function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
 switch eventdata.Key
    case 'return'
        pushbutton15_Callback(handles.movefront, [], handles); 
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
    fmask=pf2ChannelCheck.fmask;
    save(filestr,'fmask');
    
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
pf2ChannelCheck.fmask=[];
exitAndReturn(hObject, eventdata, handles)


% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
global pf2ChannelCheck
pf2ChannelCheck.fmask=[];
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
pf2ChannelCheck.curMarkersInd=get(handles.marker_listbox,'Value');
pf2ChannelCheck.curMarkers=pf2ChannelCheck.curMarkerset(pf2ChannelCheck.curMarkersInd);

axes(handles.chAxes);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);

axes(pf2ChannelCheck.chCurAxesHandle{pf2ChannelCheck.curChannel});
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
if(pf2ChannelCheck.curChannel>1)
    pf2ChannelCheck.curChannel=pf2ChannelCheck.curChannel-1;

else
    pf2ChannelCheck.curChannel=1;
    
end

axes(handles.chAxes);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);


% --- Executes on button press in pushbutton_next.
function pushbutton_next_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

  
global pf2ChannelCheck
if(pf2ChannelCheck.curChannel<pf2ChannelCheck.numChannels)
    pf2ChannelCheck.curChannel=pf2ChannelCheck.curChannel+1;

else
    pf2ChannelCheck.curChannel=pf2ChannelCheck.numChannels;
    
end

axes(handles.chAxes);
plotChannel(pf2ChannelCheck.curChannel,pf2ChannelCheck.showMarkers,true);
