function varargout = processFNIRS2_configureMethods_functionAddEdit(varargin)
% PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT MATLAB code for processFNIRS2_configureMethods_functionAddEdit.fig
%      PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT, by itself, creates a new PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT or raises the existing
%      singleton*.
%
%      H = PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT returns the handle to a new PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT or the handle to
%      the existing singleton*.
%
%      PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT.M with the given input arguments.
%
%      PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT('Property','Value',...) creates a new PROCESSFNIRS2_CONFIGUREMETHODS_FUNCTIONADDEDIT or raises
%      the existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before processFNIRS2_configureMethods_functionAddEdit_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to processFNIRS2_configureMethods_functionAddEdit_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help processFNIRS2_configureMethods_functionAddEdit

% Last Modified by GUIDE v2.5 18-Jun-2019 23:36:05

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @processFNIRS2_configureMethods_functionAddEdit_OpeningFcn, ...
                   'gui_OutputFcn',  @processFNIRS2_configureMethods_functionAddEdit_OutputFcn, ...
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

% --- Executes just before processFNIRS2_configureMethods_functionAddEdit is made visible.
function processFNIRS2_configureMethods_functionAddEdit_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to processFNIRS2_configureMethods_functionAddEdit (see VARARGIN)

% Choose default command line output for processFNIRS2_configureMethods_functionAddEdit

handles.output = hObject;

global compareMode
global curFunction
global outFunc

outFunc=[];

if(~isempty(varargin))
    if(strcmp(varargin{1},'Add')||strcmp(varargin{1},'Edit'))
        compareMode.type=varargin{1};
    elseif(isstring(varargin{1}))
        error('Invalid Method type %s\nPlease enter ''Add'' or ''Edit''',varargin{1});
    else
       error('Invalid type\nPlease enter ''Add'' or ''Edit'''); 
    end
else
    compareMode.type='Add';
    disp('No mode selected, entering Add Function mode');
end

compareMode.isEdit=strcmp(compareMode.type,'Edit');


set(handles.figure1,'Name',sprintf('%s Function',compareMode.type));

outputType=cell(3,1);
outputType{1}='x';
outputType{2}='fchMask';
outputType{3}='ftimeChMask';
outputType{4}='ROI';
set(handles.popupmenu_output_types,'String',outputType);

argumentTypes=cell(9,1);
argumentTypes{1}='Num/Logical';
argumentTypes{2}='String';
argumentTypes{3}='Input';
argumentTypes{4}='Fs';
argumentTypes{5}='Time';
argumentTypes{6}='ChannelMask';
argumentTypes{7}='TimeChannelMask';
argumentTypes{8}='ChannelNumbers';
argumentTypes{9}='SD Dist';
argumentTypes{10}='Markers';
argumentTypes{11}='Aux';
argumentTypes{12}='AmbientChannels';
argumentTypes{13}='Full fNIR struct';


set(handles.popupmenu_argument_types,'String',argumentTypes);




if(~compareMode.isEdit)
    initializeDefaultFunction(handles);
    populateExistingFunctionFields(handles);
    %Set default values for new function here
    
else
    curFunction=varargin{2}.func2edit;
    populateExistingFunctionFields(handles);
end

if(~isfield(curFunction,'Output')||isempty(curFunction.Output))
    set(handles.popupmenu_output_types,'Value',1);
else
    set(handles.popupmenu_output_types,'Value',find(contains(outputType,curFunction.Output{1})));
end

curFunction.ReservedArgumentNames=cell(9,1);
curFunction.ReservedArgumentNames{1}='Not Reserved';
curFunction.ReservedArgumentNames{2}='Not Reserved';
curFunction.ReservedArgumentNames{3}='x';
curFunction.ReservedArgumentNames{4}='fs';
curFunction.ReservedArgumentNames{5}='fTime';
curFunction.ReservedArgumentNames{6}='fchMask';
curFunction.ReservedArgumentNames{7}='ftimeChMask';
curFunction.ReservedArgumentNames{8}='fChannelNumbers';
curFunction.ReservedArgumentNames{9}='fChannelSD';
curFunction.ReservedArgumentNames{10}='fMarkers';
curFunction.ReservedArgumentNames{11}='fAux';
curFunction.ReservedArgumentNames{12}='fAmbient';
curFunction.ReservedArgumentNames{13}='fNIRstruct';

if(~isempty(curFunction.Arguments))
    set(handles.listbox_function_arguments,'Value',1);
end
listbox_function_arguments_Callback(hObject, eventdata, handles);


% Update handles structure
guidata(hObject, handles);


% UIWAIT makes processFNIRS2_configureMethods_functionAddEdit wait for user response (see UIRESUME)
 uiwait(handles.figure1);

function initializeDefaultFunction(handles)
global curFunction

curFunction.Command='MyNewFunc';

pushbutton_rename_command_Callback([], [], handles);

curFunction.Name='NewFunction';
curFunction.Description='Enter description here';
curFunction.validStages=1;
curFunction.Arguments={'x'};

function str=stripQuotes(str)

str=strrep(str,'''','');
str=strrep(str,'''','');

function populateExistingFunctionFields(handles)
global curFunction

set(handles.edit_function_matlab_command,'String',stripQuotes(curFunction.Command));
set(handles.edit_function_name,'String',stripQuotes(curFunction.Name));
set(handles.edit_function_description,'String',stripQuotes(sprintf('%s',curFunction.Description)));
set(handles.checkbox_valid_raw,'Value',any(curFunction.validStages==1));
set(handles.checkbox_valid_oxy,'Value',any(curFunction.validStages==2));

argStr=cell(0);

reservedArgs={'Name','Description','validStages','Arguments','DefaultValues','ArgumentTypes','Output'};
for i=length(curFunction.Arguments):-1:1
    if(contains(reservedArgs,curFunction.Arguments{i}))
        warning('Warning: Argument %s is a reserved argument name in processFNIRS2',curFunction.Arguments{i});
        curFunction.Arguments{i}=[];
    end
end

for i=1:length(curFunction.Arguments)
    argStr{i}=curFunction.Arguments{i};
    if(isfield(curFunction,argStr{i}))
        curFunction.DefaultValues{i}=curFunction.(argStr{i});
        curFunction.ArgumentTypes(i)=ischar(curFunction.(argStr{i}))+1; %1 for numeric, 2 for strings
        curFunction=rmfield(curFunction,argStr{i});
    elseif(strcmp(argStr{i},'x'))
        curFunction.DefaultValues{i}='Input';
        curFunction.ArgumentTypes(i)=3;
    elseif(strcmp(argStr{i},'fs'))
        curFunction.DefaultValues{i}='Sampling Frequency';
        curFunction.ArgumentTypes(i)=4;
    elseif(strcmp(argStr{i},'fTime'))
        curFunction.DefaultValues{i}='Time';
        curFunction.ArgumentTypes(i)=5;
    elseif(strcmp(argStr{i},'fchMask'))
        curFunction.DefaultValues{i}='Channel Mask';
        curFunction.ArgumentTypes(i)=6;
    elseif(strcmp(argStr{i},'ftimeChMask'))
        curFunction.DefaultValues{i}='Time X Channel Mask';
        curFunction.ArgumentTypes(i)=7;
    elseif(strcmp(argStr{i},'fChannelNumbers'))
        curFunction.DefaultValues{i}='ChannelNumbers';
        curFunction.ArgumentTypes(i)=8;
    elseif(strcmp(argStr{i},'fChannelSD'))
        curFunction.DefaultValues{i}='SD Dist';
        curFunction.ArgumentTypes(i)=9;    
    elseif(strcmp(argStr{i},'fMarkers'))
        curFunction.DefaultValues{i}='Markers';
        curFunction.ArgumentTypes(i)=10;
    elseif(strcmp(argStr{i},'fAux'))
        curFunction.DefaultValues{i}='Auxillary';
        curFunction.ArgumentTypes(i)=11;        
    elseif(strcmp(argStr{i},'fAmbient'))
        curFunction.DefaultValues{i}='AmbientChannels';
        curFunction.ArgumentTypes(i)=12;    
    elseif(strcmp(argStr{i},'fNIRstruct'))
        curFunction.DefaultValues{i}='Full fNIR struct';
        curFunction.ArgumentTypes(i)=13;    
    else
        curFunction.DefaultValues{i}='Unknown';
        curFunction.ArgumentTypes(i)=3; %assume its input?
    end
end
set(handles.listbox_function_arguments,'String',argStr);

function args=reservedArgs()

args={'Name','Description','validStages','Arguments','x','fs','fTime','fchMask','ftimeChMask','fChannelNumbers','fMarkers','fAux','fAmbient','fChannelSD','fNIRstruct'};

function myOutFunction=saveExistingFields(handles)
global curFunction

myOutFunction.Command=cleanNameForINI(get(handles.edit_function_matlab_command,'String'));

res=exist(myOutFunction.Command);
if(res~=2&&res~=5)
   waitfor(errordlg('Error: Command %s does not exist in current namespace'));
    return;
end

myOutFunction.Name=get(handles.edit_function_name,'String');
myOutFunction.Description=get(handles.edit_function_description,'String');
outputtypes=get(handles.popupmenu_output_types,'String');
myOutFunction.Output={outputtypes{get(handles.popupmenu_output_types,'Value')}};

myOutFunction.validStages=[];
if(get(handles.checkbox_valid_raw,'Value'))
    myOutFunction.validStages=[myOutFunction.validStages,1];
end
if(get(handles.checkbox_valid_oxy,'Value'))
    myOutFunction.validStages=[myOutFunction.validStages,2];
end

if(isempty(myOutFunction.validStages))
   waitfor(errordlg(sprintf('No valid stages selected\nPlease select either Raw or Oxy stage')));
    return;
end

myOutFunction.Arguments=get(handles.listbox_function_arguments,'String');



for i=1:length(myOutFunction.Arguments)
    if(~contains(reservedArgs(),myOutFunction.Arguments{i}))
        defaultValue=curFunction.DefaultValues{i};
        if(curFunction.ArgumentTypes(i)==1) %numeric
            if(ischar(defaultValue))
                defaultValue=str2double(defaultValue);
            end
            myOutFunction.(myOutFunction.Arguments{i})=defaultValue;
        elseif(curFunction.ArgumentTypes(i)==2) %String
            myOutFunction.(myOutFunction.Arguments{i})=stripQuotes(defaultValue);
        end
    end
end
%warning('Warning: Argument %s is a reserved argument name in processFNIRS2',curFunction.Arguments{i}); 
   



% --- Outputs from this function are returned to the command line.
function varargout = processFNIRS2_configureMethods_functionAddEdit_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure

global outFunc
varargout{1} = outFunc;
clearGlobals();


% --- Executes on button press in pushbutton_save.
function pushbutton_save_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global outFunc
global curFunction
res=exist(curFunction.Command);
if(res~=2&&res~=5)
   waitfor(errordlg('Error: Command %s does not exist in current namespace'));
    return;
end
outFunc=saveExistingFields(handles);
close();

function clearGlobals()
global outFunc
global curFunction

outFunc=[];
curFunction=[];

% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_cancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

clearGlobals();
close();




function edit_function_matlab_command_Callback(hObject, eventdata, handles)
% hObject    handle to edit_function_matlab_command (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_function_matlab_command as text
%        str2double(get(hObject,'String')) returns contents of edit_function_matlab_command as a double

curName=cleanNameForINI(get(hObject,'String'));
set(hObject,'String',curName);


% --- Executes during object creation, after setting all properties.
function edit_function_matlab_command_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_function_matlab_command (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_function_name_Callback(hObject, eventdata, handles)
% hObject    handle to edit_function_name (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_function_name as text
%        str2double(get(hObject,'String')) returns contents of edit_function_name as a double


% --- Executes during object creation, after setting all properties.
function edit_function_name_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_function_name (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_function_description_Callback(hObject, eventdata, handles)
% hObject    handle to edit_function_description (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_function_description as text
%        str2double(get(hObject,'String')) returns contents of edit_function_description as a double


% --- Executes during object creation, after setting all properties.
function edit_function_description_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_function_description (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_function_arguments.
function listbox_function_arguments_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_function_arguments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_function_arguments contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_function_arguments

global curFunction
curfFidx=get(handles.listbox_function_arguments,'Value');

defaultArg=curFunction.DefaultValues{curfFidx};
argType=curFunction.ArgumentTypes(curfFidx);

if(isnumeric(defaultArg))
    defaultArg=num2str(defaultArg);
end

set(handles.edit_arg_default_value,'String',defaultArg);
set(handles.popupmenu_argument_types,'Value',argType);
popupmenu_argument_types_Callback(hObject, eventdata, handles);


% --- Executes during object creation, after setting all properties.
function listbox_function_arguments_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_function_arguments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_add_argument.
function pushbutton_add_argument_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_add_argument (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

prompt = {'Enter argument name';'Enter Default Value'};
title = 'New Argument';
dims = [1 35];
definput = {'NewArgumentName','0'};
answer = inputdlg(prompt,title,dims,definput);

curArgs=get(handles.listbox_function_arguments,'String');


if(~isempty(answer)||~isempty(answer(1)))
    if(ismember(answer{1},curArgs))
       errordlg('Argument already exists');
       return;
    end
    
    
    global curFunction

    curNumArguments=length(curFunction.Arguments);
    newArgIndex=curNumArguments+1;
    curFunction.Arguments{newArgIndex}=answer{1};
    curFunction.DefaultValues{newArgIndex}=answer{2};
    curFunction.ArgumentTypes(newArgIndex)=1;
    
    if(ismember(curFunction.Arguments{newArgIndex},curFunction.ReservedArgumentNames))
        curFunction.ArgumentTypes(newArgIndex)=find(strcmp(curFunction.Arguments{newArgIndex},curFunction.ReservedArgumentNames));
    end
    
    set(handles.listbox_function_arguments,'String',curFunction.Arguments);
    set(handles.listbox_function_arguments,'Value',newArgIndex);
    listbox_function_arguments_Callback(hObject,eventdata,handles);
end


% --- Executes on button press in pushbutton_remove_argument.
function pushbutton_remove_argument_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_remove_argument (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global curFunction
curfFidx=get(handles.listbox_function_arguments,'Value');
numArguments=length(get(handles.listbox_function_arguments,'String'));
if(numArguments==0)
    return;
end
curFunction.Arguments(curfFidx)=[];
curFunction.ArgumentTypes(curfFidx)=[];
curFunction.DefaultValues(curfFidx)=[];
set(handles.listbox_function_arguments,'String',curFunction.Arguments);
set(handles.listbox_function_arguments,'Value',1);
listbox_function_arguments_Callback(hObject,eventdata,handles);


% --- Executes on button press in pushbutton_move_arg_up.
function pushbutton_move_arg_up_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_move_arg_up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global curFunction
curfFidx=get(handles.listbox_function_arguments,'Value');
numArguments=length(get(handles.listbox_function_arguments,'String'));
if(curfFidx==1||numArguments==1)
    return;
else
    newOrder=[1:curfFidx-2,curfFidx,curfFidx-1,curfFidx+1:numArguments];
    curFunction.Arguments=curFunction.Arguments(newOrder);
    curFunction.ArgumentTypes=curFunction.ArgumentTypes(newOrder);
    curFunction.DefaultValues=curFunction.DefaultValues(newOrder);
    set(handles.listbox_function_arguments,'String',curFunction.Arguments);
    set(handles.listbox_function_arguments,'Value',curfFidx-1);
    listbox_function_arguments_Callback(hObject,eventdata,handles);
end

% --- Executes on button press in pushbutton_move_arg_down.
function pushbutton_move_arg_down_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_move_arg_down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global curFunction
curfFidx=get(handles.listbox_function_arguments,'Value');
numArguments=length(get(handles.listbox_function_arguments,'String'));
if(curfFidx==numArguments)
    return;
else
    newOrder=[1:curfFidx-1,curfFidx+1,curfFidx,curfFidx+2:numArguments];
    curFunction.Arguments=curFunction.Arguments(newOrder);
    curFunction.ArgumentTypes=curFunction.ArgumentTypes(newOrder);
    curFunction.DefaultValues=curFunction.DefaultValues(newOrder);
    set(handles.listbox_function_arguments,'String',curFunction.Arguments);
    set(handles.listbox_function_arguments,'Value',curfFidx+1);
    listbox_function_arguments_Callback(hObject,eventdata,handles);
end



function edit_arg_default_value_Callback(hObject, eventdata, handles)
% hObject    handle to edit_arg_default_value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_arg_default_value as text
%        str2double(get(hObject,'String')) returns contents of edit_arg_default_value as a double
global curFunction
curfFidx=get(handles.listbox_function_arguments,'Value');
curArgType=get(handles.popupmenu_argument_types,'Value');

if(curArgType==1||curArgType==2)
     % first case, was a string, now a number
   if(curArgType==2) % now its a string
       curFunction.DefaultValues{curfFidx}=stripQuotes(get(handles.edit_arg_default_value,'String'));
   else
       curFunction.DefaultValues{curfFidx}=str2num(get(handles.edit_arg_default_value,'String'));
   end
end


% --- Executes during object creation, after setting all properties.
function edit_arg_default_value_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_arg_default_value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in popupmenu_argument_types.
function popupmenu_argument_types_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_argument_types (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_argument_types contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_argument_types
global curFunction
curfFidx=get(handles.listbox_function_arguments,'Value');
curArgType=get(handles.popupmenu_argument_types,'Value'); %curFunction.ArgumentTypes(curfFidx);
getTypesStr=get(handles.popupmenu_argument_types,'String');

if(curArgType<=2)
    set(handles.popupmenu_argument_types,'Enable','on'); 
    set(handles.edit_arg_default_value,'Enable','on');
    if(ischar(curFunction.DefaultValues{curfFidx}))
       set(handles.edit_arg_default_value,'String',stripQuotes(curFunction.DefaultValues{curfFidx})); 
   else
        set(handles.edit_arg_default_value,'String',num2str(curFunction.DefaultValues{curfFidx})); 
    end
   curFunction.ArgumentTypes(curfFidx)=curArgType;

else
    set(handles.popupmenu_argument_types,'Enable','off'); 
    set(handles.edit_arg_default_value,'Enable','off'); 
    set(handles.edit_arg_default_value,'String',getTypesStr{curArgType}); 
end
if((curFunction.ArgumentTypes(curfFidx)==1||curFunction.ArgumentTypes(curfFidx)==2)&&(curArgType==1||curArgType==2))
  
elseif((curFunction.ArgumentTypes(curfFidx)==1||curFunction.ArgumentTypes(curfFidx)==2))
    opts.Interpreter = 'tex';
    opts.Default='No';
    answer = questdlg(sprintf('Switch Argument ''%s'' to revserved input %s?',curFunction.Arguments{curfFidx},curFunction.ReservedArgumentNames{curArgType}),'Switch to reserved input','Yes','No',opts);
    % Handle response
    switch answer
        case 'Yes'
           set(handles.edit_arg_default_value,'Enable','off'); 
           set(handles.edit_arg_default_value,'String',getTypesStr{curArgType});
           curFunction.Arguments{curfFidx}=curFunction.ReservedArgumentNames{curArgType};
           curFunction.DefaultValues{curfFidx}=getTypesStr{curArgType};
           curFunction.ArgumentTypes(curfFidx)=curArgType;
           set(handles.listbox_function_arguments,'String',curFunction.Arguments);
           listbox_function_arguments_Callback(hObject, eventdata, handles);
        case 'No'
            set(handles.popupmenu_argument_types,'Value',curFunction.ArgumentTypes(curfFidx));
            popupmenu_argument_types_Callback(hObject, eventdata, handles);
            return;
    end
end


% --- Executes during object creation, after setting all properties.
function popupmenu_argument_types_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_argument_types (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox_valid_oxy.
function checkbox_valid_oxy_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_valid_oxy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_valid_oxy


% --- Executes on button press in checkbox_valid_raw.
function checkbox_valid_raw_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_valid_raw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox_valid_raw

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


% --- Executes on button press in pushbutton_rename_command.
function pushbutton_rename_command_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_rename_command (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


prompt = {'Enter new Matlab Command'};
title = 'Edit Matlab Command';
dims = [1 35];
definput = {'MyMatlabCommand'};
answer = inputdlg(prompt,title,dims,definput);

global curFunction

if(~isempty(answer)||~isempty(answer(1)))
    curFunction.Command=cleanNameForINI(answer{1});
    set(handles.edit_function_matlab_command,'String',curFunction.Command);
end


% --- Executes on selection change in popupmenu_output_types.
function popupmenu_output_types_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_output_types (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_output_types contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_output_types
outStr=get(handles.popupmenu_output_types,'String');
global curFunction
curFunction.Output={outStr};

% --- Executes during object creation, after setting all properties.
function popupmenu_output_types_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_output_types (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
