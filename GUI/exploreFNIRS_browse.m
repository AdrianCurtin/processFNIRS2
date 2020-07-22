function varargout = exploreFNIRS_browse(varargin)
% EXPLOREFNIRS_BROWSE MATLAB code for exploreFNIRS_browse.fig
%      EXPLOREFNIRS_BROWSE, by itself, creates a new EXPLOREFNIRS_BROWSE or raises the existing
%      singleton*.
%
%      H = EXPLOREFNIRS_BROWSE returns the handle to a new EXPLOREFNIRS_BROWSE or the handle to
%      the existing singleton*.
%
%      EXPLOREFNIRS_BROWSE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in EXPLOREFNIRS_BROWSE.M with the given input arguments.
%
%      EXPLOREFNIRS_BROWSE('Property','Value',...) creates a new EXPLOREFNIRS_BROWSE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before exploreFNIRS_browse_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to exploreFNIRS_browse_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help exploreFNIRS_browse

% Last Modified by GUIDE v2.5 16-Jul-2019 11:05:53

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @exploreFNIRS_browse_OpeningFcn, ...
                   'gui_OutputFcn',  @exploreFNIRS_browse_OutputFcn, ...
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







% --- Executes just before exploreFNIRS_browse is made visible.
function exploreFNIRS_browse_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to exploreFNIRS_browse (see VARARGIN)

% Choose default command line output for exploreFNIRS_browse
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes exploreFNIRS_browse wait for user response (see UIRESUME)
% uiwait(handles.figure1);
global BrowseFNIRS

if(~isfield(BrowseFNIRS,'mode'))
    val=get(handles.radiobutton_full_table,'Value');
    if(val)
        BrowseFNIRS.mode='Full';
    else
        BrowseFNIRS.mode='Selected';
    end
end

pushbutton_refresh_Callback(0, 0, handles);
listbox_dataTable_Callback(hObject, eventdata, handles);


% --- Outputs from this function are returned to the command line.
function varargout = exploreFNIRS_browse_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



% --- Executes on selection change in listbox_dataTable.
function listbox_dataTable_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_dataTable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_dataTable contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_dataTable
global ExFNIRS
global BrowseFNIRS

BrowseFNIRS.curIndex=get(handles.listbox_dataTable,'Value');

if(isfield(BrowseFNIRS,'curIndex')&&BrowseFNIRS.curIndex>0&&isfield(ExFNIRS,'dataTable')&&BrowseFNIRS.curIndex<=size(ExFNIRS.dataTable,1))
    curTableInfo=ExFNIRS.dataTable(BrowseFNIRS.curIndex,:);
    curVars=curTableInfo.Properties.VariableNames;
    labelTxt=sprintf("Info for Index %i",BrowseFNIRS.curIndex);
    for i=1:size(curTableInfo,2)
        curStr=toNumOrStr(curTableInfo.(curVars{i})(1));
        labelTxt=sprintf('%s\n%s:',labelTxt,curVars{i});
        labelTxt=sprintf('%s%s',labelTxt,curStr);
    end
    set(handles.text_seg,'String',labelTxt);
    
    if(isfield(ExFNIRS,'data')&&~isempty(ExFNIRS.data{BrowseFNIRS.curIndex}))
       h=figure(90001);
       clf(h);
       
       
       if(isfield(ExFNIRS.settings,'baseline_start'))
           bStart=ExFNIRS.settings.baseline_start-nanmin(ExFNIRS.data{BrowseFNIRS.curIndex}.time);
           bEnd=ExFNIRS.settings.baseline_end-nanmin(ExFNIRS.data{BrowseFNIRS.curIndex}.time);
           pf2.Data.Plot.Oxy(ExFNIRS.data{BrowseFNIRS.curIndex},[],[],{'HbO','HbR','CBSI'},[bStart,bEnd]);
       else
           pf2.Data.Plot.Oxy(ExFNIRS.data{BrowseFNIRS.curIndex},[],[],{'HbO','HbR','CBSI'},[]);
       end
    end
end
% 
% switch(BrowseFNIRS.mode)
%     case 'Full'
%         curTable=ExFNIRS.dataTable;
%     case 'Selected'
%         curTable=ExFNIRS.selectedTable;
% end
% uit = uitable('Data',curTable);






% --- Executes during object creation, after setting all properties.
function listbox_dataTable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_dataTable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_refresh.
function pushbutton_refresh_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_refresh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS

global BrowseFNIRS

if(~isempty(ExFNIRS)&&isfield(ExFNIRS,'dataTable'))
    
    switch(BrowseFNIRS.mode)
        case 'Full'
            curTable=ExFNIRS.dataTable;
        case 'Selected'
            curTable=ExFNIRS.selectedTable;
    end
    
    cellStrs=cell(size(curTable,1),1);
    
    for i=1:size(curTable,1)
        
        cellStrs{i}=sprintf('%i',i);
        if(~isempty(curTable.SubjectID(i)))
            curStr=toNumOrStr(curTable.SubjectID(i));
            cellStrs{i}=sprintf('%s,ID:%s',cellStrs{i},curStr);
        end
        if(~isempty(curTable.Group(i)))
            curStr=toNumOrStr(curTable.Group(i));
            cellStrs{i}=sprintf('%s,G:%s',cellStrs{i},curStr);
        end
        if(~isempty(curTable.Session(i)))
            curStr=toNumOrStr(curTable.Session(i));
            cellStrs{i}=sprintf('%s,S:%s',cellStrs{i},curStr);
        end
        if(~isempty(curTable.Condition(i)))
            curStr=toNumOrStr(curTable.Condition(i));
            cellStrs{i}=sprintf('%s,C:%s',cellStrs{i},curStr);
        end
        if(~isempty(curTable.Block(i)))
            curStr=toNumOrStr(curTable.Block(i));
            cellStrs{i}=sprintf('%s,B:%s',cellStrs{i},curStr);
        end
    end
    
    set(handles.listbox_dataTable,'String',cellStrs);
    if(~isempty(cellStrs))
        set(handles.listbox_dataTable,'Value',1);
        BrowseFNIRS.curIndex=1;
    end
else
   set(handles.listbox_dataTable,'String','No Data'); 
end







function outStr=toNumOrStr(possibleStr)
    if(isempty(possibleStr))
        outStr='';
    elseif(isnumeric(possibleStr))
        outStr=sprintf('%.2f',possibleStr);
    elseif(ischar(possibleStr)||isstring(possibleStr))
        if(ismissing(possibleStr))
            possibleStr='missing';
        end
        outStr=sprintf('%s',possibleStr);
    elseif(islogical(possibleStr))
        outStr=sprintf('%i',possibleStr');
    end
    


function mytable = transposeTable(in_table)

myArray = table2cell(in_table(:,2:end) );
myArray = cell2table(myArray'); 
var_names = cellstr( table2cell(in_table(:,1)) );
var_names = matlab.lang.makeValidName(var_names) ;
var_names = var_names';

myArray.Properties.VariableNames = var_names ;

% S = {'my.Name','my_Name','my_Name'};
% validValues = matlab.lang.makeValidName(S)
% validUniqueValues = matlab.lang.makeUniqueStrings(validValues,{},...
%     namelengthmax)
  
row_names = in_table.Properties.VariableNames(2:end); 
row_names = cell2table(row_names');
mytable = [row_names , myArray ] ;
mytable.Properties.VariableNames(1,1) = in_table.Properties.VariableNames(1,1);

clear myArray var_names row_names ii str expression replace newStr 



% --- Executes on button press in pushbutton_rejCh.
function pushbutton_rejCh_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_rejCh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ExFNIRS
global BrowseFNIRS

switch(BrowseFNIRS.mode)
    case 'Full'
        curIdx=BrowseFNIRS.curIndex;
    case 'Selected'
        selInd=find(ExFNIRS.selectedIdx);
        curIdx=selInd(BrowseFNIRS.curIndex);
end



if(isfield(ExFNIRS,'data')&&curIdx<=length(ExFNIRS.data))
   data=ExFNIRS.data{curIdx};
else
   data=''; 
end

if(~isempty(data))
    newData=pf2.Data.EditChannelMaskGUI(ExFNIRS.data{curIdx});
    if(~isempty(newData))
        ExFNIRS.data{curIdx}.fchMask=newData.fchMask;
    end
end



% --- Executes on button press in radiobutton_full_table.
function radiobutton_full_table_Callback(hObject, eventdata, handles)
% hObject    handle to radiobutton_full_table (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton_full_table

val=get(handles.radiobutton_full_table,'Value');

global BrowseFNIRS


if(val)
    BrowseFNIRS.mode='Full';
    set(handles.radiobutton_sel_table,'Value',0);
else
    BrowseFNIRS.mode='Selected';
    set(handles.radiobutton_sel_table,'Value',1);
end
    
pushbutton_refresh_Callback(hObject, eventdata, handles);

% --- Executes on button press in radiobutton_sel_table.
function radiobutton_sel_table_Callback(hObject, eventdata, handles)
% hObject    handle to radiobutton_sel_table (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

val=get(handles.radiobutton_full_table,'Value');
global BrowseFNIRS
if(val)
    BrowseFNIRS.mode='Selected';
    set(handles.radiobutton_full_table,'Value',0);
else
    BrowseFNIRS.mode='Full';
    set(handles.radiobutton_full_table,'Value',1);
end
    
pushbutton_refresh_Callback(hObject, eventdata, handles);

% Hint: get(hObject,'Value') returns toggle state of radiobutton_sel_table


% --- Executes on button press in pushbutton_edit_mask.
function pushbutton_edit_mask_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_edit_mask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global ExFNIRS
global BrowseFNIRS

switch(BrowseFNIRS.mode)
    case 'Full'
        curIdx=BrowseFNIRS.curIndex;
    case 'Selected'
        selInd=find(ExFNIRS.selectedIdx);
        curIdx=selInd(BrowseFNIRS.curIndex);
end



if(isfield(ExFNIRS,'data')&&curIdx<=length(ExFNIRS.data))
   data=ExFNIRS.data{curIdx};
else
   data=''; 
end

if(~isempty(data))
    newData=pf2.Data.EditChannelMaskGUI(ExFNIRS.data{curIdx}.info.filename);
    if(~isempty(newData))
        ExFNIRS.data{curIdx}.fchMask=newData.fchMask;
    end
end


% --- Executes on button press in pushbutton_prev.
function pushbutton_prev_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_prev (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val=get(handles.listbox_dataTable,'Value');
val=max(val-1,1);
set(handles.listbox_dataTable,'Value',val);
listbox_dataTable_Callback(hObject, eventdata, handles);

% --- Executes on button press in pushbutton_next.
function pushbutton_next_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val=get(handles.listbox_dataTable,'Value');
val=min(val+1,length(get(handles.listbox_dataTable,'String')));
set(handles.listbox_dataTable,'Value',val);
listbox_dataTable_Callback(hObject, eventdata, handles);
