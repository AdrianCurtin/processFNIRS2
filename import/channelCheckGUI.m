function varargout = channelCheckGUI(varargin)
% CHANNELCHECKGUI MATLAB code for channelCheckGUI.fig
%      Function is called by ImportNIR as an early data screening tool.
%      Creates a *_CH.mat file containing identified rejected channels.
%      These values are loaded by ImportNIR into the fchmask automatically
%      and can optionally be used to mask the data for poor/lowquality
%      data.
%
%      Currently data is only useful for the fNIRS 1100 type sensor, code
%      may need to be modified for future fNIRS devices
%
%      H = CHANNELCHECKGUI returns the handle to a new CHANNELCHECKGUI or the handle to
%      the existing singleton*.
%
%      CHANNELCHECKGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CHANNELCHECKGUI.M with the given input arguments.
%
%      CHANNELCHECKGUI('Property','Value',...) creates a new CHANNELCHECKGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before channelCheckGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to channelCheckGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help channelCheckGUI

%Channel check GUI changelog
%3/29/2019 - Modified marker display to stop after 500 markers to speed up
%loading/ display time

% Last Modified by GUIDE v2.5 05-Jun-2018 16:21:40

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @channelCheckGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @channelCheckGUI_OutputFcn, ...
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

% --- Executes just before channelCheckGUI is made visible.
function channelCheckGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to channelCheckGUI (see VARARGIN)

% Choose default command line output for channelCheckGUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

global nirsData;
global filepath;
global fmask;
global numChannels;
global curChannel;
global markers;
global showMarkers;
global chAxesHandles;

chAxesHandles{1}=handles.chRawAxes1;
chAxesHandles{2}=handles.chRawAxes2;
chAxesHandles{3}=handles.chRawAxes3;
chAxesHandles{4}=handles.chRawAxes4;
chAxesHandles{5}=handles.chRawAxes5;
chAxesHandles{6}=handles.chRawAxes6;
chAxesHandles{7}=handles.chRawAxes7;
chAxesHandles{8}=handles.chRawAxes8;
chAxesHandles{9}=handles.chRawAxes9;
chAxesHandles{10}=handles.chRawAxes10;
chAxesHandles{11}=handles.chRawAxes11;
chAxesHandles{12}=handles.chRawAxes12;
chAxesHandles{13}=handles.chRawAxes13;
chAxesHandles{14}=handles.chRawAxes14;
chAxesHandles{15}=handles.chRawAxes15;
chAxesHandles{16}=handles.chRawAxes16;

if(isempty(showMarkers))
    showMarkers=true;
    set(handles.marker_listbox,'Enable','on');
else
    set(handles.markerCheck,'Value',showMarkers);
    if(showMarkers)
    set(handles.marker_listbox,'Enable','on');
    else
        set(handles.marker_listbox,'Enable','off');
    end
end



if(length(varargin) <2)
    %error('No FilePath');
    filepath='D:/text.nir';
else
    filepath=varargin{2};
end

if (length(varargin) <1)
    nirsData=rand(1000,49)*500+1000;
    nirsData(:,1)=0.5:0.5:500;
    %error('No data');
else
    nirsData=varargin{1};
end

if(size(nirsData,1)<=1)
   error('Empty dataset'); 
end
global curMarkerSet;
global curMarkers;



if(length(varargin)<3)
    markers=[];
    set(handles.marker_listbox,'String',{''});
    curMarkerSet=[];
    curMarkers=[];
else
    markers=varargin{3}.data;
    uMrk=sort(unique(markers(:,2)));
    curMarkerSet=uMrk;
    mrkStr=cell(length(uMrk),1);
    for i=1:length(uMrk)
       mrkStr{i}=sprintf('%i',uMrk(i));
       
    end
    
    set(handles.marker_listbox,'String',mrkStr);
    if(showMarkers)
        set(handles.marker_listbox,'Value',1:length(uMrk));
        curMarkers=curMarkerSet;
    else
        set(handles.marker_listbox,'Value',[]);
        curMarkers=[];
    end
end


    [pathstr, name, ext] = fileparts(filepath)
    if(length(pathstr)>0)
        filestr=[pathstr,'/',name,'_CH.mat'];
    else
        filestr=[name,'_CH.mat'];
    end
    
    
    if exist(filestr, 'file') == 2
        load(filestr);
        exitAndReturn(hObject, eventdata, handles,true)
        return;
    end
    
set(handles.currentfiletext,'String',name);
    

nirsData(nirsData(:,1)==0,:)=[];

%Count num Channels
numChannels=(size(nirsData,2)-1)/3;

fmask=ones(1,numChannels);

if(numChannels>0)
    curChannel=1;
else
    curChannel=0;
end
% This sets up the initial plot - only do when we are invisible
% so window can get raised using channelCheckGUI.
if strcmp(get(hObject,'Visible'),'off')
    
   updateChannels(handles);
    
    
    %yaxis([0,4500]);
end

% UIWAIT makes channelCheckGUI wait for user response (see UIRESUME)
uiwait(handles.figure1);

function [handle]= plotChannel(ch,plotMarkers,withTitle)

global nirsData;
global filepath;
global fmask;
global numChannels;
global markers;
global curChannel;
global curMarkers;


if(nargin<3)
    withTitle=false;
end

if(nargin<2)
    plotMarkers=false;
end

if(nargin<1)
    ch=curChannel;
end



    
    hold off;

    
    x=(ch-1)*3+2;
    temp=get(gca);
    temp=temp.ButtonDownFcn;
    handle=plot(nirsData(:,1),nirsData(:,x),'r');
    set(gca,'ButtonDownFcn',temp);
    hold on;
    if(~fmask(ch))
        text(max(nirsData(:,1))/2+15,2000,'X','FontSize',40,'color',[1,0,0]);
        hold on;
    elseif(fmask(ch)==0.5)
        text(max(nirsData(:,1))/2+15,2000,'~','FontSize',50,'color',[ 0.9100,0.4100,0.1700]);
        hold on;
    end
    plot(nirsData(:,1),nirsData(:,x+1),'k');
    hold on;
    plot(nirsData(:,1),nirsData(:,x+2),'b');
    hold on;
    plot(nirsData(:,1),ones(length(nirsData(:,1)),1)*4000,'--k');
    
    
    
    if(plotMarkers&&~isempty(markers))
        reducedMarkers=markers(ismember(markers(:,2),curMarkers),:);
        
        numMarkers=length(reducedMarkers(:,1));
        if(numMarkers>1000)
               fprintf(2,'Num Markers exceeds 500, only plotting first 500. Please select fewer markers\n');
        end
        
        for i=1:min(length(reducedMarkers(:,1)),500)
            vline(reducedMarkers(i,1),'-k');
        end
       
    end

    hold off;
    if(withTitle)
        xlabel('Time (s)');
        ylabel('Light Intensity mV');
        title(sprintf('Channel %i of %i',ch,numChannels));
    end
    axis([min(nirsData(:,1)) max(nirsData(:,1)) 0 4300])



% --- Outputs from this function are returned to the command line.
function varargout = channelCheckGUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
global fmask;
%varargout{1} = handles.output;
varargout{1} = fmask;

clear fmask;


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


% --- Executes on button press in prevButton.
function prevButton_Callback(hObject, eventdata, handles)
% hObject    handle to prevButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global curChannel;
global showMarkers;

if(curChannel>1)
    curChannel=curChannel-1;

else
    curChannel=1;
    
end

axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);




% --- Executes on button press in nextButton.
function nextButton_Callback(hObject, eventdata, handles)
% hObject    handle to nextButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global curChannel;
global numChannels;
global showMarkers;

if(curChannel<numChannels)
    curChannel=curChannel+1;

else
    curChannel=numChannels;
    
end

axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);

function updateChannels(handles)

global curChannel;
global showMarkers;
global numChannels;
global chAxesHandles;

axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);

for i=1:numChannels
    axes(chAxesHandles{i});
    plotChannel(i,false);
end
% --- Executes on button press in rejectButton.
function rejectButton_Callback(hObject, eventdata, handles)
% hObject    handle to rejectButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global curChannel
global numChannels
global fmask
global chAxesHandles;
global showMarkers;


fmask(curChannel)=0;
axes(chAxesHandles{curChannel});
plotChannel(curChannel,false);
axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);


% --- Executes on button press in noisyButton.
function noisyButton_Callback(hObject, eventdata, handles)
% hObject    handle to noisyButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global curChannel
global numChannels
global fmask
global showMarkers
global chAxesHandles;

fmask(curChannel)=0.5;
axes(chAxesHandles{curChannel});
plotChannel(curChannel,false);
axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);


%nextButton_Callback(hObject, eventdata, handles);


% --- Executes on button press in cleanButton.
function cleanButton_Callback(hObject, eventdata, handles)
% hObject    handle to cleanButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global curChannel
global numChannels
global fmask
global chAxesHandles;
global showMarkers;

fmask(curChannel)=1;
axes(chAxesHandles{curChannel});
plotChannel(curChannel,false);
axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);



% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if isequal(get(hObject, 'waitstatus'), 'waiting')
% The GUI is still in UIWAIT, us UIRESUME
uiresume(hObject);
else
delete(hObject);
end

function []=exitAndReturn(hObject, eventdata, handles,skipSave)
if(nargin<4)
    skipSave=false;
end
global nirsData;
global filepath;
global numChannels;
global curChannel;
global markers;
global showMarkers;




global fmask;
%If not already loaded write output
if(~isempty(fmask)&&sum(fmask<0)==0)
   % doc fileparts:
    [pathstr, name, ext] = fileparts(filepath);
    pathstr=sprintf('%s/',pathstr);
    filestr=sprintf('%s_CH.mat',name);
    if(length(pathstr)>1)
        filestr=[pathstr,filestr];
    end
    %filestr=[pathstr,'/',name,'_CH.mat'];
    if(~skipSave)
        save(filestr,'fmask');
    end
end

clear curChannel numChannels nirsData markers filepath showMarkers;
channelCheckGUI_OutputFcn(hObject, eventdata, handles);
delete(gca);
delete(handles.figure1);


% --- Executes on button press in markerCheck.
function markerCheck_Callback(hObject, eventdata, handles)
% hObject    handle to markerCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of markerCheck

global curChannel;
global showMarkers;

showMarkers=get(handles.markerCheck,'Value');
global curMarkerSet;
global curMarkers;

curMarkersInd=get(handles.marker_listbox,'Value');
curMarkers=curMarkerSet(curMarkersInd);

if(showMarkers)
set(handles.marker_listbox,'Enable','on');
else
    set(handles.marker_listbox,'Enable','off');
end
axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);


% --- Executes on mouse press over axes background.
function chRawAxes1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(1,eventdata,handles);

% --- Executes on mouse press over axes background.
function chRawAxes2_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(2,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes3_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(3,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes4_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(4,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes5_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(5,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes6_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(6,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes7_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(7,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes8_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(8,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes9_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(9,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes10_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(10,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes11_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(11,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes12_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(12,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes13_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(13,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes14_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(14,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes15_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(15,eventdata,handles);
% --- Executes on mouse press over axes background.
function chRawAxes16_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chRawAxes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

markUnmarkChannel(16,eventdata,handles);

function markUnmarkChannel(ch,eventdata,handles)
b = eventdata.Button;
global fmask;
global chAxesHandles;
global curChannel;
global showMarkers

curChannel=ch;

if b==1
    
else
    fmask(ch)=~fmask(ch);
end

axes(chAxesHandles{ch});
plotChannel(ch,false);

axes(handles.chAxes);
plotChannel(ch,showMarkers,true);


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
global filepath
global fmask

    [pathstr, name, ext] = fileparts(filepath);
    pathstr=sprintf('%s/',pathstr);
    filestr=sprintf('%s_CH.mat',name);
    if(length(pathstr)>1)
        filestr=[pathstr,filestr];
    end
    %filestr=[pathstr,'/',name,'_CH.mat'];
    save(filestr,'fmask');
   exitAndReturn(hObject, eventdata, handles);


% --- Executes on mouse press over axes background.
function chAxes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to chAxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global curChannel;

markUnmarkChannel(curChannel,eventdata,handles);


% --- Executes on button press in newfigurebutton.
function newfigurebutton_Callback(hObject, eventdata, handles)
% hObject    handle to newfigurebutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
figure(1);
global curChannel;global markers;
global showMarkers;
plotChannel(curChannel,showMarkers,true);


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
global fmask
fmask=[];
exitAndReturn(hObject, eventdata, handles)


% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global fmask
fmask=[];
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
global chAxesHandles;
global curChannel;
global showMarkers;
global curMarkerSet;
global curMarkers;

curMarkersInd=get(handles.marker_listbox,'Value');
curMarkers=curMarkerSet(curMarkersInd);

axes(handles.chAxes);
plotChannel(curChannel,showMarkers,true);

axes(chAxesHandles{curChannel});
plotChannel(curChannel,false,false);

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
