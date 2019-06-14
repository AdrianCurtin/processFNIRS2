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

% Last Modified by GUIDE v2.5 12-Jan-2019 12:52:23

% Begin pf2_base.external.INItialization code - DO NOT EDIT
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
% End pf2_base.external.INItialization code - DO NOT EDIT


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

PF2.defaultOxyMethodsPath=sprintf('%s/pf2_oxy_methods_stored_processFNIRS2.cfg',prefdir);
PF2.defaultRawMethodsPath=sprintf('%s/pf2_raw_methods_stored_processFNIRS2.cfg',prefdir);

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

PF2.availableFunctionsPath=sprintf('%s/pf2_functions_stored_processFNIRS2.cfg',prefdir);
if(~isfield(PF2,'myFunctions'))
   PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true);
   
   defaultFunctionsPath=sprintf('%s/prefs/%s',PF2.defaultRootPath,'pf2_functions_default.cfg');
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

newName=cleanNameForpf2_base.external.INI(newName);


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
			case {'À','�?','Â','Ã','Ä','Å'},     Character = 'A';
			case 'Æ',                           Character = 'AE';
			case 'Ç',                           Character = 'C';
			case {'È','É','Ê','Ë'},             Character = 'E';
			case {'Ì','�?','Î','�?'},             Character = 'I';
			case 'Ñ',                           Character = 'N';
			case {'Ò','Ó','Ô','Õ','Ö'},         Character = 'O';
			case {'Ù','Ú','Û','Ü'},             Character = 'U';
			case '�?',                           Character = 'Y';
			case '²',                           Character = '2';
			case '³',                           Character = '3';
			case '¼',                           Character = '1_4';
			case '½',                           Character = '1_2';
			case '¾',                           Character = '3_4';
			case {'à','á','â','ã','ä','å'},     Character = 'a';
			case 'æ',                           Character = 'ae';
			case 'ç',                           Character = 'c';
			case {'è','é','ê','ë'},             Character = 'e';
			case {'ì','í','î','ï'},             Character = 'i';
			case 'ñ',                           Character = 'n';
			case {'ò','ó','ô','õ','ö'},         Character = 'o';
			case {'ù','ú','û','ü','µ'},         Character = 'u';
			case {'ý','ÿ'},                     Character = 'y';
			case {' ','''', '-', '_',...
					'(','[','/','\'},         	Character = '_';
			case {'°'},                         Character = 'deg';
			otherwise,                          Character = '' ;
		end
		newName = [newName, Character]; %#ok<AGROW>
	end

	newName = strrep(newName,'__','_');
	if length(newName) > 1
		if strcmp(newName(end),'_')
			newName = newName(1:end-1);
		end
	end
	newName = matlab.lang.makeValidName(newName);
	if(~strcmp(Name,newName))
		warning('Mismatch between validated name (%s) and original name (%s), please avoid irregular characters',newName,Name);
	end


function updateCurrentMethods(handles,forceSwitchMethod)
if(nargin<2)
    forceSwitchMethod=false;
end
global PF2

set(handles.listbox_myMethods,'String',PF2.myMethods.cfg.Sections);
if(length(PF2.myMethods.cfg.Sections)>0)
    set(handles.listbox_myMethods,'Value',1);
end

if (forceSwitchMethod||~isfield(PF2,'currentMethod'))&length(PF2.myMethods.cfg.Sections)>0
   PF2.currentMethod=PF2.myMethods.cfg.(PF2.myMethods.cfg.Sections{1});
   if(isempty(PF2.currentMethod))
      PF2.currentMethod.F=cell(0); 
   end
   PF2.currentMethod.name=PF2.myMethods.cfg.Sections{1};
   
elseif(~isfield(PF2,'currentMethod')||forceSwitchMethod)
    pushbutton_newMethod_Callback([], [], handles);
end

% --- Executes on selection change in listbox_myMethods.
function listbox_myMethods_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_my Methods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_myMethods contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_myMethods
global PF2
selectedMethod=get(handles.listbox_myMethods,'Value');
if(length(selectedMethod)>1)
   selectedMethod=selectedMethod(1); 
end
if(~isempty(selectedMethod))
    selectedMethodName=get(handles.listbox_myMethods,'String');
    selectedMethodName=selectedMethodName{selectedMethod};
    PF2.currentMethod=unpackMethod(PF2.myMethods.cfg.(PF2.myMethods.cfg.Sections{selectedMethod}));

    PF2.currentMethod.name=selectedMethodName;
    set(handles.edit_methodName,'String',PF2.currentMethod.name);
    
    if(strcmp(PF2.currentMethod.name,'None'))
        set(handles.edit_methodName,'Enable','off')
        set(handles.pushbutton_addFunction,'Enable','off')
    else
        set(handles.edit_methodName,'Enable','on')
        set(handles.pushbutton_addFunction,'Enable','on')
    end
    
%    set(handles.checkbox_raw,'Value',sum(contains(PF2.currentMethod.validStages,'raw'))>0);
%    set(handles.checkbox_oxy,'Value',sum(contains(PF2.currentMethod.validStages,'oxy'))>0);

    refreshCurrentFunctions(handles);
else
    pushbutton_newMethod_Callback(hObject, eventdata, handles);
end

function refreshCurrentFunctions(handles)
global PF2

str=[];


if(isfield(PF2.currentMethod,'F')&&iscell(PF2.currentMethod.F))
    remInd=[];
    for i=1:length(PF2.currentMethod.F)
       remInd(i)=(isempty(PF2.currentMethod.F{i})||isfield(PF2.currentMethod.F{i},'name')); 
       
    end

    PF2.currentMethod.F(remInd==1)=[];

    for i=1:length(PF2.currentMethod.F)
        if(~isfield(PF2.currentMethod.F{i},'f'))
            break;
        else
            str{i}=PF2.currentMethod.F{i}.f;
        end
    end

    set(handles.listbox_currentFunctions,'String',str);
    set(handles.listbox_currentFunctions,'Value',1);
    set(handles.listbox_inputSelect,'Value',1);
        
    listbox_currentFunctions_Callback(handles.output, [], handles);
        

else
    set(handles.listbox_currentFunctions,'String',[]);
end
% --- Executes during object creation, after setting all properties.
function listbox_myMethods_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_myMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_newMethod.
function pushbutton_newMethod_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_newMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of pushbutton_newMethod
global PF2
global configureMode

if(ismember('None',PF2.myMethods.cfg.Sections))
    newName = inputdlg('Enter new method name','New Method');
else
    newName='None';
end

if(ismember(newName,PF2.myMethods.cfg.Sections))
    f = waitfor(msgbox('Method Name aleady exists','Duplicate Method'));
    return;
elseif(~isempty(newName)&&~isempty(newName))
    if(iscell(newName))
        newName=newName{1};
    end

    PF2.currentMethod.name=cleanNameForpf2_base.external.INI(newName);
    set(handles.edit_methodName,'String',PF2.currentMethod.name);
    PF2.currentMethod.F=cell(0);
    PF2.myMethods.cfg.add(PF2.currentMethod.name,PF2.currentMethod.F);
    updateCurrentMethods(handles)
    %set(handles.listbox_myMethods,'Value',length(PF2.myMethods.cfg.Sections));
    refreshCurrentFunctions(handles);
    if(configureMode.isRaw)
       automatic_add_OD_function(handles); 
    end
    setCurrentMethodByName(handles,newName);
    saveMethods(PF2.myMethods,configureMode.isRaw);
end

function setCurrentMethodByName(handles,methodName)


curMethods=get(handles.listbox_myMethods,'String');
newMethodIndex=find(strcmp(curMethods,methodName)==1);
if(~isempty(newMethodIndex))
    
    set(handles.listbox_myMethods,'Value',newMethodIndex);
    listbox_myMethods_Callback([],[],handles);
else
    disp('Unable to find Method');
    if(~isempty(curMethods))
        set(handles.listbox_myMethods,'Value',1);
        listbox_myMethods_Callback([],[],handles);
    end
end

    
% --- Executes on button press in pushbutton_copyMethod.
function pushbutton_copyMethod_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_copyMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global PF2
global configureMode
oldName=PF2.currentMethod.name;
newName=sprintf('%s_copy',oldName);
set(handles.edit_methodName,'String',newName);

if(ismember(newName,PF2.myMethods.cfg.Sections))
    answer = questdlg('Method already exits, replace?','Duplicate Method','Replace','Cancel','Replace');
    if(strcmp(answer,'Replace'))
        PF2.myMethods.cfg.remove(newName);
        PF2.myMethods.cfg.add(newName,PF2.currentMethod.F);
        saveMethods(PF2.myMethods,configureMode.isRaw);
    end
else
    PF2.myMethods.cfg.add(newName,PF2.currentMethod.F);
    saveMethods(PF2.myMethods,configureMode.isRaw);
end

updateCurrentMethods(handles);
refreshCurrentFunctions(handles);
setCurrentMethodByName(handles,newName);



% --- Executes on button press in pushbutton_deleteMethod.
function pushbutton_deleteMethod_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_deleteMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
if(~strcmp(PF2.currentMethod.name,'None'))
    PF2.myMethods.cfg.remove(PF2.currentMethod.name);
    updateCurrentMethods(handles,true);
    %set(handles.listbox_myMethods,'Value',length(PF2.myMethods.cfg.Sections));
    refreshCurrentFunctions(handles);
    setCurrentMethodByName(handles,'None');
end

% --- Executes on selection change in listbox_inputSelect.
function listbox_inputSelect_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_inputSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_inputSelect contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_inputSelect
global PF2

reservedArgs={'Name','Description','validStages','Arguments','x','fs','fTime','fchMask','fMarkers','fChannelNumbers','fMarkers','fChannelSD','fAmbient','argvals','default_argvals'};

curFunction=get(handles.listbox_currentFunctions,'Value');
curFunctionNames=get(handles.listbox_currentFunctions,'String');
if(~isempty(curFunctionNames)&&~isempty(curFunction))
    if(isfield(PF2.currentMethod.F{curFunction},'f')&&ismember(PF2.currentMethod.F{curFunction}.f,PF2.myFunctions.cfg.Sections))
        curFunction=curFunction(1);
        selectedInd=get(handles.listbox_inputSelect,'Value');
        curArgument=get(handles.listbox_inputSelect,'String');
        curArgument=curArgument{selectedInd(1)};
        if(~iscell(PF2.currentMethod.F{curFunction}.argvals)&&selectedInd==1)
            PF2.currentMethod.F{curFunction}.argvals={PF2.currentMethod.F{curFunction}.argvals};
        end

        if(~iscell(PF2.currentMethod.F{curFunction}.default_argvals)&&selectedInd==1)
            PF2.currentMethod.F{curFunction}.default_argvals={PF2.currentMethod.F{curFunction}.default_argvals};
        end

        try
            curArgVal=PF2.currentMethod.F{curFunction}.argvals{selectedInd(1)};
            defaultArgVal=PF2.currentMethod.F{curFunction}.default_argvals{selectedInd(1)};

            if(ischar(curArgVal)==1)
                set(handles.edit_input,'String',curArgVal);
            else
                set(handles.edit_input,'String',sprintf('%f',curArgVal));
            end

            if(~ismember(curArgument,reservedArgs))
                set(handles.edit_input,'Enable','on');
                set(handles.pushbutton_setArgument,'Enable','on');
                if(ischar(curArgVal)==1)
                    set(handles.text_inputDescription,'String',sprintf('Default Value: %s',defaultArgVal));
                else
                   set(handles.text_inputDescription,'String',sprintf('Default Value: %f',defaultArgVal)); 
                end
            else
                set(handles.edit_input,'Enable','off');
                set(handles.pushbutton_setArgument,'Enable','off');
                if(strcmp(curArgument,'x'))
                    set(handles.text_inputDescription,'String',sprintf('fNIRS data matrix [s x Ch]')); 
                elseif(strcmp(curArgument,'fs'))
                    set(handles.text_inputDescription,'String',sprintf('Sampling Frequency of data'));
                elseif(strcmp(curArgument,'fTime'))
                    set(handles.text_inputDescription,'String',sprintf('time points of fNIRS data')); 
                elseif(strcmp(curArgument,'fchMask'))
                    set(handles.text_inputDescription,'String',sprintf('Channel Mask')); 
                elseif(strcmp(curArgument,'fChannelNumbers'))
                    set(handles.text_inputDescription,'String',sprintf('Channel numbers corresponding to rows input')); 
                elseif(strcmp(curArgument,'fMarkers'))
                    set(handles.text_inputDescription,'String',sprintf('Marker data matrix')); 
                elseif(strcmp(curArgument,'fAux'))
                    set(handles.text_inputDescription,'String',sprintf('Auxillary data located in .Aux')); 
                elseif(strcmp(curArgument,'fChannelSD'))
                    set(handles.text_inputDescription,'String',sprintf('Channel Source-Detector Distances')); 
                elseif(strcmp(curArgument,'fAmbient'))
                    set(handles.text_inputDescription,'String',sprintf('Ambient/DarkChannel Data')); 
                end
            end

        catch
            fStr=PF2.currentMethod.F{curFunction}.f;
            waitfor(errordlg(sprintf('Unable to assign values to function %s\nAttempting to remove and replace function',fStr),'Function settings error'));
            
            removeFunction(curFunction);
            add2method(fStr);
            refreshCurrentFunctions(handles);
        end
    else
        waitfor(errordlg(sprintf('Function %s not in currently available functions',curFunction),'Function settings error'));
        
    end
else
    set(handles.edit_input,'Enable','off');
    set(handles.pushbutton_setArgument,'Enable','off');
    set(handles.text_inputDescription,'String','');
end


% --- Executes during object creation, after setting all properties.
function listbox_inputSelect_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_inputSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_input_Callback(hObject, eventdata, handles)
% hObject    handle to edit_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_input as text
%        str2double(get(hObject,'String')) returns contents of edit_input as a double
pushbutton_setArgument_Callback(hObject, eventdata, handles);

% --- Executes during object creation, after setting all properties.
function edit_input_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_raw.
function checkbox_raw_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_raw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_raw
global PF2

rawStage=get(handles.checkbox_raw,'Value');
%if(rawStage==1&&sum(contains(PF2.currentMethod.validStages,'raw'))==0)
%    PF2.currentMethod.validStages{length(PF2.currentMethod.validStages)+1}='raw';
%elseif(rawStage==0&&sum(contains(PF2.currentMethod.validStages,'raw'))>0)
%    PF2.currentMethod.validStages(contains(PF2.currentMethod.validStages,'raw'))=[];
%end

% --- Executes on button press in checkbox_oxy.
function checkbox_oxy_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_oxy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_oxy
global PF2
%Stage 0 is raw light intensity
%Stage 1 is OD
%Stage 2 is oxy

oxyStage=get(handles.checkbox_oxy,'Value');
%if(oxyStage==1&&sum(contains(PF2.currentMethod.validStages,'oxy'))==0)
%    PF2.currentMethod.validStages{length(PF2.currentMethod.validStages)+1}='oxy';
%elseif(oxyStage==0&&sum(contains(PF2.currentMethod.validStages,'oxy'))>0)
%    PF2.currentMethod.validStages(contains(PF2.currentMethod.validStages,'oxy'))=[];
%end



% --- Executes on button press in pushbutton_saveClose.
function pushbutton_saveClose_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_saveClose (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2
global configureMode
saveMethods(PF2.myMethods,configureMode.isRaw);
close();
updateMainGUI(handles,eventdata);


function updateMainGUI(handles,eventdata)
if(isfield(handles,'main_GUI_handles'))
    if(isvalid(handles.main_GUI_hObject))

        func=handles.main_GUI_handles.pushbutton_reloadMethods.Callback;
        func(handles.main_GUI_hObject, eventdata);
    else
       warning('GUI handle is invalid'); 
    end
end

function [myMethods]= loadMethods(methodsCfgFilename,createIfMissing)
    
    myMethods=[];
    if(nargin==1||(nargin==2&&~createIfMissing))
        fid = fopen(methodsCfgFilename);

        if fid==-1
            %fclose(fid);
            warning('Local Config File not found');


            [file, pathname] = uigetfile({'pf2_methods_*.cfg';'*.cfg';'*.*'},'Please Select Methods Defpf2_base.external.INItion file');
            
            if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
                return;
            end
            
            fid = fopen([pathname file]);
            
            

            if fid==-1
                error('Data file not found or permission denied');
            end

            fclose(fid);

            myMethods.cfg = pf2_base.external.INI('File',[pathname file]);
        end

        myMethods.cfg = pf2_base.external.INI('File',methodsCfgFilename);
    elseif(nargin==2&&createIfMissing)
        fid = fopen(methodsCfgFilename);

        if fid==-1
            %fclose(fid);
            fprintf('Local Config File not found\nMaking new methods config file');

            myMethods.cfg = pf2_base.external.INI('File',methodsCfgFilename);
            myMethods.cfg.write(); 
            
        else

            myMethods.cfg = pf2_base.external.INI('File',methodsCfgFilename);
        end
    else
        [file, pathname] = uigetfile({'pf2_methods_*.cfg';'*.cfg';'*.*'},'Please Select Methods Defpf2_base.external.INItion file');
        
        if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
            return;
        end
        
        fid = fopen([pathname file]);

        if fid==-1
          error('Data file not found or permission denied');
        end

        fclose(fid);

        myMethods.cfg = pf2_base.external.INI('File',[pathname file]);
    end

    myMethods.cfg.read();
    x=[];
    x.name='None';
    x.F=cell(0);
    if(~ismember('None',myMethods.cfg.Sections))
       %Add None method
        
        myMethods.cfg.add('None',x);
    else
        myMethods.cfg.remove('None');
        myMethods.cfg.add('None',x);
        
    end
    
    myMethods=unpackMethods(myMethods);
    

    
function [myFunctions]= loadFunctions(functionsCfgFilename,createIfMissing)
   
     
    
    myFunctions=[];
    if(nargin==1||(nargin==2&&~createIfMissing))
        fid = fopen(functionsCfgFilename);

        if fid==-1
            %fclose(fid);
            warning('Local Config File not found');


            [file, pathname] = uigetfile({'pf2_functions_*.cfg';'*.cfg';'*.*'},'Please Select Functions Defpf2_base.external.INItion file');
            fid = fopen([pathname file]);
            
            if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
                return
            end

            if fid==-1
                error('Data file not found or permission denied');
            end

            fclose(fid);

            myFunctions.cfg = pf2_base.external.INI('File',[pathname file]);
        end

        myFunctions.cfg = pf2_base.external.INI('File',functionsCfgFilename);
    elseif(nargin==2&&createIfMissing)
        fid = fopen(functionsCfgFilename);

        if fid==-1
            %fclose(fid);
            warning('Local Function Config File not found');

            myFunctions.cfg = pf2_base.external.INI('File',functionsCfgFilename);
            myFunctions.cfg.write(); 
            
        else

            myFunctions.cfg = pf2_base.external.INI('File',functionsCfgFilename);
        end
    else
        [file, pathname] = uigetfile({'pf2_functions_*.cfg';'*.cfg';'*.*'},'Please Select Functions Defpf2_base.external.INItion file');
        if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
            return
        end
        fid = fopen([pathname file]);

        if fid==-1
          error('Data file not found or permission denied');
        end

        fclose(fid);

        myFunctions.cfg = pf2_base.external.INI('File',[pathname file]);
    end

    myFunctions.cfg.read();

function [myMethods]= loadMethodsCallback(hObject, eventdata, handles,methodsCfgFilename,createIfMissing)
    [myMethods]= loadMethods(methodsCfgFilename,createIfMissing);

function [myValidOxyMethods]=currentOxyMethodsCallback(hObject, eventdata, handles)
        
global PF2
if(isfield(PF2,'myOxyMethods'))
    myValidOxyMethods=PF2.myOxyMethods.cfg.Sections;
else
    myValidOxyMethods=cell(0);
end
function [myValidRawMethods]=currentRawMethodsCallback(hObject, eventdata, handles)
global PF2
if(isfield(PF2,'myRawMethods'))
    myValidRawMethods=PF2.myRawMethods.cfg.Sections;
else
    myValidRawMethods=cell(0);
end

% --- Executes on button press in pushbutton_avail_function_import.
function pushbutton_avail_function_import_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_avail_function_import (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

importFunctions();
updateCurrentFunctions(handles)

function importFunctionFromStruct(func)

global PF2

if(~isfield(PF2,'myFunctions'))
    PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true); 
end

if(ismember(func.Command,PF2.myFunctions.cfg.Sections))
    PF2.myFunctions.cfg.remove(func.Command);
    fprintf('Removing and replacing function: %s\n',func.Command);
else
    fprintf('Adding new function: %s\n',func.Command);
end

cmdName=func.Command;
func=rmfield(func,'Command');
PF2.myFunctions.cfg.add(cmdName,func);


PF2.myFunctions.cfg.write();


function succeeded=importFunctions(cfgPath)

if(nargin<1)
    [myFunctions]= loadFunctions();
else
    [myFunctions]= loadFunctions(cfgPath);
end

if(isempty(myFunctions))
    
    succeeded=false;
    return;
end

global PF2

if(isfield(PF2,'myFunctions'))
    PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true); 
end

[C,ia,ib] = intersect(myFunctions.cfg.Sections,unique(PF2.myFunctions.cfg.Sections), 'stable');

if(length(myFunctions.cfg.Sections)>0)
   for i=1:length(myFunctions.cfg.Sections)
       if ismember(i,ia)
            PF2.myFunctions.cfg.remove(myFunctions.cfg.Sections{i});
            PF2.myFunctions.cfg.add(myFunctions.cfg.Sections{i},myFunctions.cfg.(myFunctions.cfg.Sections{i}));
            fprintf('Removing and replacing function: %s\n',myFunctions.cfg.Sections{i});
       else
            PF2.myFunctions.cfg.add(myFunctions.cfg.Sections{i},myFunctions.cfg.(myFunctions.cfg.Sections{i}));
            fprintf('Adding function: %s\n',myFunctions.cfg.Sections{i});
       end
   end
end

PF2.myFunctions.cfg.write()

succeeded=true;
return;



function updateCurrentFunctions(handles)
global PF2
global configureMode


if(isfield(PF2,'myFunctions'))
    PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true); 
end

if(~isempty(PF2.myFunctions.cfg.Sections))
   funcStrArr=cell(0);
   
   idx=1;
   for i=1:length(PF2.myFunctions.cfg.Sections)
       funcName=PF2.myFunctions.cfg.Sections{i};
       validStages=PF2.myFunctions.cfg.(funcName).validStages;
       if(any(validStages==1)&&configureMode.isRaw)
        funcStrArr{idx}=funcName;
        idx=idx+1;
       elseif(any(validStages==2)&&~configureMode.isRaw)
        funcStrArr{idx}=funcName;
        idx=idx+1;
       end
   end
   set(handles.listbox_availableFunctions,'String',funcStrArr);
end



function edit_functionDescription_Callback(hObject, eventdata, handles)
% hObject    handle to edit_functionDescription (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_functionDescription as text
%        str2double(get(hObject,'String')) returns contents of edit_functionDescription as a double


% --- Executes during object creation, after setting all properties.
function edit_functionDescription_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_functionDescription (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function cellStr = text2multiline(text)
doubleLine=strfind(text,'\\n');
if(~isempty(doubleLine))
    text(doubleLine+1)='\n';
    text(doubleLine)='';
end
newLines=strfind(text,'\n');
newLines=[-1,newLines,length(text)+1];
cellStr=cell(1,length(newLines));
for i=1:length(newLines)-1
    cellStr{i}=text((newLines(i)+2):(newLines(i+1)-1)); % This indexing makes no goddamn sense
end



function add2method(f2add)
% This function adds a new preprocessing function to the current Method
global PF2

if(~isfield(PF2,'currentMethod'))
   PF2.currentMethod=[];
   PF2.currentMethod.name='Unnamed';
   PF2.currentMethod.validStages={};
end

    if(strcmp(PF2.currentMethod.name,'None'))
       return
    end

if(~isfield(PF2.currentMethod,'F')||isempty(PF2.currentMethod.F))
   PF2.currentMethod.F=cell(0); 
end

if(isempty(f2add))
	warning('No function specified');
	return;
end

if(~iscell(f2add))
    temp=f2add;
    f2add=cell(1,1);
    f2add{1}=temp;
end

reservedArgs={'Name','Description','validStages','Arguments','x','fs','fTime','fchMask','fChannelSD','fAmbient','fMarkers','fChannelNumbers','argvals','default_argvals'};

if(iscell(f2add))
   for i=1:length(f2add)
		f2add{i}=cleanNameForpf2_base.external.INI(f2add);
       %Add and assign default arguments and values
      PF2.currentMethod.F{length(PF2.currentMethod.F)+1}.f=f2add{i}; 
      PF2.currentMethod.F{length(PF2.currentMethod.F)}.args=PF2.myFunctions.cfg.(f2add{i}).Arguments;
      
      for a=1:length(PF2.currentMethod.F{length(PF2.currentMethod.F)}.args)
          %Setting default values here
          if(~ismember(PF2.myFunctions.cfg.(f2add{i}).Arguments{a},reservedArgs))
              if(isfield(PF2.myFunctions.cfg.(f2add{i}),PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
                  PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}= PF2.myFunctions.cfg.(f2add{i}).(PF2.myFunctions.cfg.(f2add{i}).Arguments{a});
              else
                  PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}=[];
              end
          elseif(strcmp('x',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Input Data';
          elseif(strcmp('fs',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='fs';
          elseif(strcmp('fTime',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Time';
          elseif(strcmp('fchMask',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Channel Mask';
          elseif(strcmp('fChannelNumbers',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Channel Numbers';
          elseif(strcmp('fMarkers',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Marker Data';
          elseif(strcmp('fAux',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Auxillary data';
          elseif(strcmp('fChannelSD',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Source-Detector Dist';
          elseif(strcmp('fAmbient',PF2.myFunctions.cfg.(f2add{i}).Arguments{a}))
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}='Ambient/Dark Channel data';
          else
              PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals{a}=[];
          end
      end
        
       PF2.currentMethod.F{length(PF2.currentMethod.F)}.default_argvals= PF2.currentMethod.F{length(PF2.currentMethod.F)}.argvals;
      
   end
end

if(isempty(PF2.currentMethod.F{1}))
   PF2.currentMethod.F{1}=[]; 
end

saveCurrentMethod()

function saveCurrentMethod()
global PF2

 if(ismember(PF2.currentMethod.name,PF2.myMethods.cfg.Sections))
    PF2.myMethods.cfg.remove(PF2.currentMethod.name);
 end
 PF2.myMethods.cfg.add(PF2.currentMethod.name,PF2.currentMethod.F);
 

function myMethods=packMethods(myMethods)
%Move all functions from methods into packed versions
% Converts 'F' cells to 'S' structs for storage

for i=1:length(myMethods.cfg.Sections)
    x=[];

    x=myMethods.cfg.(myMethods.cfg.Sections{i});
    if(iscell(x)) %If x is a cell with no fields
       F=x;
       x=[];
       x.F=F;
    end
    x.name=myMethods.cfg.Sections{i};
    if(isfield(x,'F'))
        for j=1:length(x.F)
            if(~isempty(x.F{j}))
                x.(sprintf('S%i',j))=x.F{j};
            end
        end
    
        x=rmfield(x,'F');
    end

    myMethods.cfg.remove(x.name);
    myMethods.cfg.add(x.name,x);
end



function myMethods=unpackMethods(myMethods)
%Converts mymethods function from .S to fields in F
for i=1:length(myMethods.cfg.Sections)
    x=myMethods.cfg.(myMethods.cfg.Sections{i});
    x_fields=fields(x);
    x.name=myMethods.cfg.Sections{i};
    x.F=cell(0);
    numMethods=1;
    for j=1:(length(x_fields))
       if(sum(strcmp(x_fields,sprintf('S%i',j))==1))
           x.F{numMethods}=x.(sprintf('S%i',j));
           x=rmfield(x,sprintf('S%i',j));
           numMethods=numMethods+1;
       end
    end
    
    for idx=1:length(x.F)
        Fidx=x.F{idx};
        if(ischar(Fidx)&&contains(Fidx,'struct(''f'))
            warning('Improperly formatted function found. Some settings may be lost');
            x.F(idx)=[];
        elseif(length(Fidx)>1) %This is a struct array for some reason?
           %Change it back!
           F_noarray.f=Fidx(1).f;
           F_noarray.args=cell(0);
           F_noarray.argvals=cell(0);
           F_noarray.default_argvals=cell(0);
           for j=1:length(Fidx)
                F_noarray.args{j}=Fidx(j).args;
                F_noarray.argvals{j}=Fidx(j).argvals;
                F_noarray.default_argvals{j}=Fidx(j).default_argvals;
           end
           x.F{idx}=F_noarray;
        end
    end

    myMethods.cfg.remove(x.name);
    myMethods.cfg.add(x.name,x);
end

function x=unpackMethod(method)
%Converts method fields from .S to fields in F
    x=method;
    if(isempty(method))
        x.F=cell(0);
        return
    elseif(iscell(x))
        F=x;
        x=[];
        x.F=F;
        clear F;
        
    elseif(~isfield(method,'F'))
        x_fields=fields(x);
        x.F=cell(0);
        numMethods=1;
        for j=1:length(x_fields)
           if(sum(strcmp(x_fields,sprintf('S%i',j))))
               x.F{numMethods}=x.(sprintf('S%i',j));
               x=rmfield(x,sprintf('S%i',j));
               numMethods=numMethods+1;
           end
        end
    end
    
    for idx=1:length(x.F)
        Fidx=x.F{idx};
        if(ischar(Fidx)&&contains(Fidx,'struct(''f'))
            warning('Improperly formatted function found. Some settings may be lost');
            x.F(idx)=[];
        elseif(length(Fidx)>1) %This is a struct array for some reason?
           %Change it back!
           F_noarray.f=Fidx(1).f;
           F_noarray.args=cell(0);
           F_noarray.argvals=cell(0);
           F_noarray.default_argvals=cell(0);
           for j=1:length(Fidx)
                F_noarray.args{j}=Fidx(j).args;
                F_noarray.argvals{j}=Fidx(j).argvals;
                F_noarray.default_argvals{j}=Fidx(j).default_argvals;
           end
           x.F{idx}=F_noarray;
        end
    end
    
    
    

function []=removeFunction(idx)
global PF2

if(~isempty(idx)&&~isempty(PF2.currentMethod.F)&&idx<length(PF2.currentMethod.F))
    PF2.currentMethod.F(idx)=[];
end
saveCurrentMethod();


function []=setMethodFunctionIndexes(newIdx)
global PF2

if(~isempty(newIdx))
    PF2.currentMethod.F=PF2.currentMethod.F(newIdx);
end
saveCurrentMethod();



% --- Executes on button press in pushbutton_setArgument.
function pushbutton_setArgument_Callback(hObject, eventdata, handles)
%Assigns arguments in preprocessing function
% hObject    handle to pushbutton_setArgument (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2

curFunction=get(handles.listbox_currentFunctions,'Value');
selectedArgInd=get(handles.listbox_inputSelect,'Value');
curArgument=get(handles.listbox_inputSelect,'String');
curArgument=curArgument{selectedArgInd(1)};
curInput=PF2.currentMethod.F{curFunction(1)}.argvals{selectedArgInd(1)};
newArgVal=get(handles.edit_input,'String');
if(isstring(curInput))
    PF2.currentMethod.F{curFunction(1)}.argvals{selectedArgInd(1)}=newArgVal;
else
    PF2.currentMethod.F{curFunction(1)}.argvals{selectedArgInd(1)}=str2double(newArgVal);
end

saveCurrentMethod();



% --- Executes on mouse press over figure background.
function figure1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over listbox_availableFunctions.
function listbox_availableFunctions_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to listbox_availableFunctions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%addFuncEnabled=get(pushbutton_addFunction,'Enable');
%if(strcmp(addFuncEnabled,'on'))
%    pushbutton_addFunction_Callback(hObject, eventdata, handles);
%end


% --- Executes on button press in pushbutton_exportMethod.
function pushbutton_exportMethod_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_exportMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PF2

[file, pathname] = uiputfile({'pf2_methods_*.cfg';'*.cfg';'*.*'},'Save Methods Defpf2_base.external.INItion file');
if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
    return
end

PF2.myMethods=packMethods(PF2.myMethods);
exportMethods.cfg = pf2_base.external.INI('File',[pathname file]);

if(length(PF2.myMethods.cfg.Sections)>0)
   for i=1:length(PF2.myMethods.cfg.Sections)
       if(~strcmp(PF2.myMethods.cfg.Sections{i},'None'))
            exportMethods.cfg.add(PF2.myMethods.cfg.Sections{i},PF2.myMethods.cfg.(PF2.myMethods.cfg.Sections{i}));
            fprintf('Exporting method: %s\n',PF2.myMethods.cfg.Sections{i});
       end
   end
end
exportMethods.cfg.write(); 
PF2.myMethods=unpackMethods(PF2.myMethods);

fid = fopen([pathname file]);

if fid==-1
    error('Data file not found or permission denied');
end

fclose(fid);

% --- Executes on button press in pushbutton_importMethods.
function pushbutton_importMethods_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_importMethods (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
importMethods();
updateCurrentMethods(handles);

function importMethods(cfgFile,isRaw)
if(nargin<1||isempty(cfgFile))
    [myMethods]= loadMethods();
else
    [myMethods]= loadMethods(cfgFile);
end

if(isempty(myMethods))
    warning('No methods found in file');
    return;
end
global PF2

if(isRaw)
    myStoredMethods=loadMethods(PF2.defaultRawMethodsPath,true); 
else
    myStoredMethods=loadMethods(PF2.defaultOxyMethodsPath,true); 
end

[C,ia,ib] = intersect(myMethods.cfg.Sections,unique(myStoredMethods.cfg.Sections), 'stable');

if(length(myMethods.cfg.Sections)>0)
   for i=1:length(myMethods.cfg.Sections)
       if ismember(i,ia)
            myStoredMethods.cfg.remove(myMethods.cfg.Sections{i});
            myStoredMethods.cfg.add(myMethods.cfg.Sections{i},unpackMethod(myMethods.cfg.(myMethods.cfg.Sections{i})));
            fprintf('Removing and replacing method: %s\n',myMethods.cfg.Sections{i});
       else
            myStoredMethods.cfg.add(myMethods.cfg.Sections{i},unpackMethod(myMethods.cfg.(myMethods.cfg.Sections{i})));
            fprintf('Adding method: %s\n',myMethods.cfg.Sections{i});
       end
   end
end

saveMethods(myStoredMethods,isRaw);

function importMethodsCallback(hObject, eventdata, handles,methodsCfgFilename,isRaw)

importMethods(methodsCfgFilename,isRaw);


% --- Executes on button press in pushbutton_avail_function_import.
function pushbutton14_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_avail_function_import (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton_updateGUI.
function pushbutton_updateGUI_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_updateGUI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateMainGUI(handles,eventdata);
listbox_inputSelect_Callback(hObject, eventdata, handles);

% --- Executes on button press in checkbox_updateOnChange.
function checkbox_updateOnChange_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_updateOnChange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% Hint: get(hObject,'Value') returns toggle state of checkbox_updateOnChange


% --- Executes on button press in pushbutton_avail_function_delete.
function pushbutton_avail_function_delete_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_avail_function_delete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global PF2



if(~isfield(PF2,'myFunctions'))
    PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true); 
end

curFuncIndex=get(handles.listbox_availableFunctions,'Value');
if(isempty(curFuncIndex))
    return;
end
curFuncStrs=get(handles.listbox_availableFunctions,'String');

if(~isempty(curFuncStrs)&&~iscell(curFuncStrs))
    curFuncStrs={curFuncStrs};
end

if(~isempty(curFuncStrs))
    curFuncStrs=curFuncStrs(curFuncIndex);
    for i=1:length(curFuncStrs)
        PF2.myFunctions.cfg.remove(curFuncStrs{i});
    end
    
    PF2.myFunctions.cfg.write()
    updateCurrentFunctions(handles)
    set(handles.listbox_availableFunctions,'Value',1);
end


% --- Executes on button press in pushbutton_avil_function_add.
function pushbutton_avil_function_add_Callback(hObject, eventdata, handles)
global PF2

% hObject    handle to pushbutton_avil_function_add (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.parameters.stage = 'Add'; %SecondGUIStuff;
handles.parameters.main_GUI_handles=handles;
handles.parameters.main_GUI_hObject=hObject;

newFunction=processFNIRS2_configureMethods_functionAddEdit('Add',handles.parameters);

if(isempty(newFunction))
    return;
end

curFuncStrs=get(handles.listbox_availableFunctions,'String');


if(ismember(newFunction.Command,curFuncStrs))
    opts.Interpreter = 'tex';
    opts.Default='No';
    answer = questdlg(sprintf('Warning: Function ''%s'' already exits\nReplace function?',newFunction.Command),'Overwrite Existing Function','Yes','No',opts);
    % Handle response
    switch answer
        case 'Yes'
           %
        case 'No'
            return;
    end
end

importFunctionFromStruct(newFunction);
PF2.myFunctions.cfg.write();
updateCurrentFunctions(handles);
listbox_currentFunctions_Callback(hObject, eventdata, handles);




% --- Executes on button press in pushbutton_avail_function_edit.
function pushbutton_avail_function_edit_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_avail_function_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global PF2

if(~isfield(PF2,'myFunctions'))
    PF2.myFunctions=loadFunctions(PF2.availableFunctionsPath,true); 
end

curFuncIndex=get(handles.listbox_availableFunctions,'Value');
if(isempty(curFuncIndex))
    return;
end
curFuncStrs=get(handles.listbox_availableFunctions,'String');

if(~isempty(curFuncStrs)&&~iscell(curFuncStrs))
    curFuncStrs={curFuncStrs};
end

if(~isempty(curFuncStrs))
    curFuncStrs=curFuncStrs(curFuncIndex);
    
    curFuncStr=curFuncStrs{1};
    
    handles.parameters.stage = 'Edit'; %SecondGUIStuff;
    handles.parameters.func2edit=PF2.myFunctions.cfg.(curFuncStr);
    handles.parameters.func2edit.Command=curFuncStr;
    handles.parameters.main_GUI_handles=handles;
    handles.parameters.main_GUI_hObject=hObject;
    editedFunction=processFNIRS2_configureMethods_functionAddEdit('Edit',handles.parameters);
    
    curFuncStrs=get(handles.listbox_availableFunctions,'String');
    if(isempty(editedFunction))
        return;
    end
    
    if(ismember(editedFunction.Command,curFuncStrs))
        opts.Interpreter = 'tex';
        opts.Default='No';
        answer = questdlg(sprintf('Save changes to Function ''%s''?',editedFunction.Command),'Overwrite Existing Function','Yes','No',opts);
        % Handle response
        switch answer
            case 'Yes'
               %
            case 'No'
                return;
        end
    end

    importFunctionFromStruct(editedFunction);
    PF2.myFunctions.cfg.write();
    updateCurrentFunctions(handles);
    listbox_currentFunctions_Callback(hObject, eventdata, handles);
    
    
    
end


% --- Executes on button press in pushbutton_avail_function_export.
function pushbutton_avail_function_export_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_avail_function_export (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global PF2

[file, pathname] = uiputfile({'pf2_functions_*.cfg';'*.cfg';'*.*'},'Save Function Defpf2_base.external.INItions file');
if(isempty(file)||~ischar(file)||(isnumeric(file)&&file==0))
    return
end

exportFunctions.cfg = pf2_base.external.INI('File',[pathname file]);

curFuncIdx=get(handles.listbox_availableFunctions,'Value');
curFuncStrs=get(handles.listbox_availableFunctions,'String');

if(isempty(curFuncIdx))
    return
elseif(~iscell(curFuncStrs))
    curFuncStrs={curFuncStrs};
end

curFuncStrs=curFuncStrs(curFuncIdx);

for i=1:length(curFuncStrs)
    curFstr=curFuncStrs{i};
   if(ismember(curFstr,PF2.myFunctions.cfg.Sections))
        exportFunctions.cfg.add(curFstr,PF2.myFunctions.cfg.(curFstr));
        fprintf('Exporting function: %s\n',curFstr);
   else
      warning('Function %s not found in Available Methods',curFstr); 
   end
end
exportFunctions.cfg.write(); 

fid = fopen([pathname file]);

if fid==-1
    error('Data file not found or permission denied');
end

fclose(fid);


% --- Executes on button press in pushbutton_reset_to_default.
function pushbutton_reset_to_default_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_reset_to_default (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global PF2

curFunction=get(handles.listbox_currentFunctions,'Value');
selectedArgInd=get(handles.listbox_inputSelect,'Value');
curArgument=get(handles.listbox_inputSelect,'String');
curArgument=curArgument{selectedArgInd(1)};
curInput=PF2.currentMethod.F{curFunction(1)}.argvals{selectedArgInd(1)};
newArgVal=PF2.currentMethod.F{curFunction(1)}.default_argvals{selectedArgInd(1)};

PF2.currentMethod.F{curFunction(1)}.argvals{selectedArgInd(1)}=newArgVal;
if(ischar(newArgVal))
    set(handles.edit_input,'String',newArgVal);
else
    set(handles.edit_input,'String',num2str(newArgVal));
end
edit_input_Callback(hObject, eventdata, handles);
saveCurrentMethod();
