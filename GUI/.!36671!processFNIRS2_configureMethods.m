function varargout = processFNIRS2_configureMethods(varargin)
% PROCESSFNIRS2_CONFIGUREMETHODS MATLAB code for processFNIRS2_configureMethods.fig
%      PROCESSFNIRS2_CONFIGUREMETHODS, by itself, creates a new PROCESSFNIRS2_CONFIGUREMETHODS or raises the existing
%      singleton*.
%
%      H = PROCESSFNIRS2_CONFIGUREMETHODS returns the handle to a new PROCESSFNIRS2_CONFIGUREMETHODS or the handle to
%      the existing singleton*.
%
%      PROCESSFNIRS2_CONFIGUREMETHODS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PROCESSFNIRS2_CONFIGUREMETHODS.M with the given input arguments.
%
%      PROCESSFNIRS2_CONFIGUREMETHODS('Property','Value',...) creates a new PROCESSFNIRS2_CONFIGUREMETHODS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before processFNIRS2_configureMethods_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to processFNIRS2_configureMethods_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help processFNIRS2_configureMethods

% Last Modified by GUIDE v2.5 28-Jun-2019 13:05:30

% Begin Initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @processFNIRS2_configureMethods_OpeningFcn, ...
                   'gui_OutputFcn',  @processFNIRS2_configureMethods_OutputFcn, ...
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
% End Initialization code - DO NOT EDIT


% --- Executes just before processFNIRS2_configureMethods is made visible.
function processFNIRS2_configureMethods_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to processFNIRS2_configureMethods (see VARARGIN)

% Choose default command line output for processFNIRS2_configureMethods
handles.output = hObject;

global configureMode
if(~isempty(varargin))
    if(strcmp(varargin{1},'raw')||strcmp(varargin{1},'oxy'))
        configureMode.type=varargin{1};
    elseif(isstring(varargin{1}))
        error('Invalid Method type %s\nPlease enter ''raw'' or ''oxy''',varargin{1});
    else
       error('Invalid type\nPlease enter ''raw'' or ''oxy'''); 
    end
else
    configureMode.type='raw';
    disp('No mode selected, entering Raw Method configuration mode');
end

set(handles.text_title,'String',sprintf('Configure Methods: %s mode',configureMode.type));

if(length(varargin)>1)
    handles.main_GUI_handles=varargin{2}.main_GUI_handles;
    handles.main_GUI_hObject=varargin{2}.main_GUI_hObject;
end

configureMode.isRaw=strcmp(configureMode.type,'raw');

% Update handles structure
guidata(hObject, handles);


global PF2
global setF

PF2.defaultOxyMethodsPath=sprintf('%s/pf2_oxy_methods_stored_pf2.cfg',prefdir);
PF2.defaultRawMethodsPath=sprintf('%s/pf2_raw_methods_stored_pf2.cfg',prefdir);

if(~isfield(PF2,'myRawMethods'))
   PF2.myRawMethods=loadMethods(PF2.defaultRawMethodsPath,true);
end
if(~isfield(PF2,'myOxyMethods'))  
   PF2.myOxyMethods=loadMethods(PF2.defaultOxyMethodsPath,true);
   %processFNIRS2_configureMethods() 
end

if(configureMode.isRaw)
    PF2.myMethods=PF2.myRawMethods;
else
    PF2.myMethods=PF2.myOxyMethods;
end

updateCurrentMethods(handles);

PF2.availableFunctionsPath=sprintf('%s/pf2_functions_stored_pf2.cfg',prefdir);
if(~isfield(PF2,'myFunctions'))
   PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true);
   
   defaultFunctionsPath=sprintf('%s/prefs/%s',pf2_base.pf2_defaultRootPath,'pf2_functions_default.cfg');
   if(pf2_base.isnestedfield(PF2.myFunctions,'cfg.Sections'))
       if(isempty(PF2.myFunctions.cfg.Sections))
           answer = questdlg('No saved functions found! Would you like to import the default function library?','Load Default Functions','Yes','No','Yes');
           
           switch(answer)
               case 'Yes'
                   if(~importFunctions(defaultFunctionsPath))
                       warning('Unable to find functions at %s! Please load another file',defaultFunctionsPath);
                       importFunctions();
                   end
               case 'No'
                    
           end
       end
   else
      error('Unable to import or create stored function file'); 
   end
   %processFNIRS2_configureMethods() 
end


updateCurrentFunctions(handles);
refreshCurrentFunctions(handles);
listbox_myMethods_Callback(hObject, eventdata, handles);



% UIWAIT makes processFNIRS2_configureMethods wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = processFNIRS2_configureMethods_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton_addFunction.
function pushbutton_addFunction_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_addFunction (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
curSelected=get(handles.listbox_availableFunctions,'Value'); 
availFnames=get(handles.listbox_availableFunctions,'String'); 

f2add=availFnames(curSelected);

curFnames=get(handles.listbox_currentFunctions,'String');
curFnames=[curFnames;f2add];
set(handles.listbox_currentFunctions,'String',curFnames);


add2method(f2add);

set(handles.listbox_currentFunctions,'Value',length(curFnames));
listbox_currentFunctions_Callback(hObject, eventdata, handles);

function automatic_add_OD_function(handles)
% hObject    handle to pushbutton_addFunction (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%curSelected=get(handles.listbox_availableFunctions,'Value'); 
%availFnames=get(handles.listbox_availableFunctions,'String'); 
%
%f2add=availFnames(curSelected);
updateCurrentMethods(handles);
f2add='pf2_Intensity2OD';
curFnames=get(handles.listbox_currentFunctions,'String');
isListEmpty=isempty(curFnames);
curFnames=[curFnames;f2add];
set(handles.listbox_currentFunctions,'String',curFnames);


add2method(f2add);

if(isListEmpty)
    set(handles.listbox_currentFunctions,'Value',1);
else
    set(handles.listbox_currentFunctions,'Value',length(curFnames));
end
%listbox_currentFunctions_Callback([], [], handles);


% --- Executes on selection change in listbox_currentFunctions.
function listbox_currentFunctions_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_currentFunctions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_currentFunctions contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_currentFunctions
curSelected=get(handles.listbox_currentFunctions,'Value'); 
curFunctionNames=get(handles.listbox_currentFunctions,'String'); 
if(~isempty(curFunctionNames)&&~isempty(curSelected))
    curFnames=get(handles.listbox_currentFunctions,'String');
    if(iscell(curFnames))
       curFname= curFnames{curSelected(1)};
    else
        curFname=curFnames;
    end
        

    global PF2
    
    set(handles.text_functionName,'String',PF2.myFunctions.cfg.(curFname).Name);
    newDescrip=PF2.myFunctions.cfg.(curFname).Description;
    %newlines=strfind(newDescrip,"\\n");
    newDescrip=text2multiline(newDescrip);
    set(handles.edit_functionDescription,'String',newDescrip);
    newArguments=PF2.myFunctions.cfg.(curFname).Arguments;
    set(handles.listbox_inputSelect,'String',newArguments);
    if(length(newArguments)>0)
        set(handles.listbox_inputSelect,'Value',1);
        set(handles.listbox_inputSelect,'Enable','on');
        listbox_inputSelect_Callback(hObject, eventdata, handles);
    end
else
    set(handles.listbox_inputSelect,'String',"");
    listbox_inputSelect_Callback(hObject, eventdata, handles);
    
    set(handles.text_functionName,'String',"No Function Selected");
    set(handles.edit_functionDescription,'String',"Please add a function");
    
end
% --- Executes during object creation, after setting all properties.
function listbox_currentFunctions_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_currentFunctions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_moveUp.
function pushbutton_moveUp_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_moveUp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
curSelected=get(handles.listbox_currentFunctions,'Value'); 
curFnames=get(handles.listbox_currentFunctions,'String');

if(min(curSelected>1))
    oldInd=1:length(curFnames);
    oldInd(curSelected)=[];
    newPos=curSelected-1;
    newInd=zeros(size(curFnames));
    newInd(newPos)=curSelected;
    i2=1;
    for i=1:length(newInd)
        if(newInd(i)==0)
            newInd(i)=oldInd(i2);
            i2=i2+1;
        end
    end
   

    set(handles.listbox_currentFunctions,'String',curFnames(newInd));
    set(handles.listbox_currentFunctions,'Value',newPos);
    
    setMethodFunctionIndexes(newInd);
end

% --- Executes on button press in pushbutton_moveDown.
function pushbutton_moveDown_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_moveDown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
curSelected=get(handles.listbox_currentFunctions,'Value'); 
curFnames=get(handles.listbox_currentFunctions,'String');

if(max(curSelected<length(curFnames)))
    oldInd=1:length(curFnames);
    oldInd(curSelected)=[];
    newPos=curSelected+1;
    newInd=zeros(size(curFnames));
    newInd(newPos)=curSelected;
    i2=1;
    for i=1:length(newInd)
        if(newInd(i)==0)
            newInd(i)=oldInd(i2);
            i2=i2+1;
        end
    end
   

    set(handles.listbox_currentFunctions,'String',curFnames(newInd));
    set(handles.listbox_currentFunctions,'Value',newPos);
    
    setMethodFunctionIndexes(newInd);
end

% --- Executes on button press in pushbutton_remove.
function pushbutton_remove_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_remove (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
curSelected=get(handles.listbox_currentFunctions,'Value'); 
if(~isempty(curSelected))
    removeFunction(curSelected);
    curFnames=get(handles.listbox_currentFunctions,'String');

    if(~isempty(curFnames))
        curFnames(curSelected)=[];
    end

    set(handles.listbox_currentFunctions,'String',curFnames);
    set(handles.listbox_currentFunctions,'Value',1); 
    listbox_currentFunctions_Callback(hObject, eventdata, handles);
end

% --- Executes on selection change in listbox_availableFunctions.
function listbox_availableFunctions_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_availableFunctions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_availableFunctions contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_availableFunctions
curSelected=get(handles.listbox_availableFunctions,'Value'); 
curFunctionNames=get(handles.listbox_availableFunctions,'String'); 
if(~isempty(curFunctionNames)&&~isempty(curSelected))
    curFnames=get(handles.listbox_availableFunctions,'String');

    global PF2
    
    set(handles.text_functionName,'String',PF2.myFunctions.cfg.(curFnames{curSelected(1)}).Name);
    newDescrip=PF2.myFunctions.cfg.(curFnames{curSelected(1)}).Description;
    %newlines=strfind(newDescrip,"\\n");
    newDescrip=text2multiline(newDescrip);
    set(handles.edit_functionDescription,'String',newDescrip);
    newArguments=PF2.myFunctions.cfg.(curFnames{curSelected(1)}).Arguments;
    set(handles.listbox_inputSelect,'String',newArguments);
    if(length(newArguments)>0)
        set(handles.listbox_inputSelect,'Value',1);
        listbox_inputSelect_Callback(hObject, eventdata, handles);
    end
    set(handles.listbox_inputSelect,'Enable','off');
else
    set(handles.listbox_inputSelect,'String',"");
    listbox_inputSelect_Callback(hObject, eventdata, handles);
    
    set(handles.text_functionName,'String',"No Function Selected");
    set(handles.edit_functionDescription,'String',"Please add a function");
    
end

% --- Executes during object creation, after setting all properties.
function listbox_availableFunctions_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_availableFunctions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_methodName_Callback(hObject, eventdata, handles)
% hObject    handle to edit_methodName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_methodName as text
%        str2double(get(hObject,'String')) returns contents of edit_methodName as a double
%global PF2
%str=get(handles.edit_methodName,'String');
%str(str==' ')='_';
%PF2.currentMethod.name=str;
%set(handles.edit_methodName,'String',str);
% --- Executes during object creation, after setting all properties.
function edit_methodName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_methodName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function saveMethods(myMethods,isRaw)
global PF2

%saves methods and assigns to global structure for usage outside of
%configurefnirs


myMethods=packMethods(myMethods);

if(isRaw)
    PF2.myRawMethods=myMethods;
    PF2.myRawMethods.cfg.write();
    PF2.myRawMethods=unpackMethods(PF2.myRawMethods);
else
    PF2.myOxyMethods=myMethods;
    PF2.myOxyMethods.cfg.write();
    PF2.myOxyMethods=unpackMethods(PF2.myOxyMethods);
end


% --- Executes on button press in pushbutton_rename.
function pushbutton_rename_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_rename (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

newName=get(handles.edit_methodName,'String');

newName=cleanNameForINI(newName);


global PF2
global configureMode
oldName=PF2.currentMethod.name;
set(handles.edit_methodName,'String',newName);

if(~strcmp(newName,oldName))
    
    if(strcmp(newName,'None'))
        disp('Reserved method name');
        return;
    end
    
    
    if(ismember(newName,PF2.myMethods.cfg.Sections))
        answer = questdlg('Method already exits, replace?','Duplicate Method','Replace','Cancel','Replace');
        if(strcmp(answer,'Replace'))
            PF2.myMethods.cfg.remove(oldName);
            PF2.myMethods.cfg.remove(newName);
            PF2.myMethods.cfg.add(newName,PF2.currentMethod.F);
            saveMethods(PF2.myMethods,configureMode.isRaw);
        end
    else
        PF2.myMethods.cfg.remove(oldName);
        PF2.myMethods.cfg.add(newName,PF2.currentMethod.F);
        saveMethods(PF2.myMethods,configureMode.isRaw);
    end
    updateCurrentMethods(handles);
    refreshCurrentFunctions(handles);
    setCurrentMethodByName(handles,newName);
end

function newName=cleanNameForINI(Name)

    if(iscell(Name))
        Name=Name{1};
    end
	persistent Numbers LowerCases UpperCases

	if isempty(Numbers)
		Numbers = arrayfun(@(n) {sprintf('%u',n)},0:9);
		LowerCases = arrayfun(@(n) {char(n+96)},1:26);
		UpperCases = arrayfun(@(n) {char(n+64)},1:26);
	end

	newName = '';
	for n = 1:length(Name)
		Character = Name(n);
		switch(Character)
			case Numbers
			case LowerCases
			case UpperCases
