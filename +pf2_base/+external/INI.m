%% Manager for initialization file
%  Version : v1.02
%  Author  : E. Ogier
%  Release : 31th aug. 2017
%
%  VERSIONS :
%  - v1.0  (04 mar. 2016) : initial version
%  - v1.01 (13 apr. 2016) : correction of a bug occurring when a string including "=" symbol is read
%  - v1.02 (31 aug. 2017) : correction of a bug in "read" method when dynamic properties were previously created
%
%  OBJECT PROPERTIES <Default> :
%  - File        <'INI.ini'> : Default file name
%  - CommentChar <'%'>       : Comment character when reading
%  - NewLineChar <'\r\n'>    : New line characters when writing
%  - Sections    <{}>        : Sections names
%
%  OBJECT METHODS :
%  - I = INI(PROPERTY1,VALUE1,PROPERTY2,VALUE2,...) : Create an INI object and set the specified properties
%  - I.set(PROPERTY1,VALUE1,PROPERTY2,VALUE2,...)   : Set the specified properties
%  - I.get(PROPERTY)                                : Get the specified property
%  - I.read()                                       : Read the file corresponding to the previously defined file name
%  - I.read(FILE)                                   : Read the specified file
%  - I.write()                                      : Write the file corresponding to the previously defined file name
%  - I.write(FILE)                                  : Write the specified file
%  - I.add(NAME1,STRUCTURE1,NAME2,STRUCTURE2)       : Add the sections NAME1 and NAME2 and store STRUCTURE1 and STRUCTURE2 structures respectively
%  - I.remove()                                     : Remove all the sections stored internally
%  - I.remove(SECTION1,SECTION2)                    : Remove the sections called SECTION1 and SECTION2
%
%  EXAMPLE 1 :
%
%  %% INI file writing
% 
%  %  Initialisation
%  I = INI();
%  File = 'Configuration.ini';
%  
%  %% Section "Timer"
% 
%  % Creation of a timer
%  Timer = timer();
%  
%  % Add section
%  I.add('Timer',Timer);
%  
%  %% Section "Serial"
%  
%  % Creation of a serial port
%  COM = serial('COM1');
%  
%  % Add section
%  I.add('Serial',COM);
%  
%  %% Section "UserData"
%  
%  % Data specified by user
%  Structure.Field1 = 'Data1';
%  Structure.Field2 = {'Data21','Data22'};
%  Structure.Field3 = 'Data3';
%  UserData = struct('Vector',0:9,'Matrix',ones(3,3),'Structure',Structure);
%  
%  % Add section
%  I.add('UserData',UserData);
%  
%  
%  %% Writing
%  
%  % Write file
%  I.write(File);
%  
%  % Open "Configuration.ini"
%  winopen(File); 
%
%  EXAMPLE 2 :
% 
%  %% INI file reading
%  % Creation of an example file called "Configuration.ini" : execute EXAMPLE 1
%  
%  % Initialization
%  File = 'Configuration.ini';
%  I = INI('File',File);
%  
%  % INI file reading
%  I.read();
%  
%  % Sections from INI file
%  Sections = I.get('Sections');
%  
%  % Sections names
%  fprintf(1,'Sections of "%s" file :\n',File);
%  
%  % Sections data
%  for s = 1:numel(Sections)
%      fprintf(1,'- Section "%s"\n',Sections{s});
%      disp(I.get(Sections{s}));
%  end

classdef INI < hgsetget & dynamicprops
   
    properties
       File        = 'INI.ini'; % Default file
       CommentChar = '%';       % Comment character when reading
       NewLineChar = '\n';      % New line characters when writing
       Sections    = {};        % Sections names
    end
    
    methods
        
        % Constructor
        function Object = INI(varargin)
            
            for v = 1:2:length(varargin)                
                Property = varargin{v};
                Value = varargin{v+1};
                set(Object,Property,Value);                
            end
            
        end
        
        % Function 'set'
        function Object = set(Object,varargin)
            
            Properties = varargin(1:2:end);
            Values = varargin(2:2:end);
            
            for n = 1:length(Properties)
                [is, Property] = isproperty(Object,Properties{n});                
                if is
                    Object.(Property) = Values{n};
                else
                    error('Property "%s" not supported !',Properties{n});
                end                
            end
            
        end
        
        % Function 'get'
        function Value = get(varargin)
            
            switch nargin
                case 1
                    Value = varargin{1};
                otherwise
                    Object = varargin{1};
                    [is, Property] = isproperty(Object,varargin{2});                    
                    if is                        
                        Value = Object.(Property);
                    else
                        [is, Property] = isproperty(Object,rename(varargin{2}));
                        if is
                            Value = Object.(Property);
                        else
                            error('Property "%s" not supported !',varargin{2});
                        end
                    end
            end
            
        end
        
        % Function 'ispropery'
        function [is, Property] = isproperty(Object,Property)
            
            Properties = properties(Object); 
            [is, b] = ismember(lower(Property),lower(Properties));
            if is
                Property = Properties{b};
            else
                Property = [];
            end
            
        end
                  
        % Function 'read' INI file
        function Object = read(Object,varargin)
            
            if nargin == 2
                set(Object,'File',varargin{1});
            end
            
            Object.Sections = {};
            DynamicProperties = setdiff(properties(Object),{'File','CommentChar','NewLineChar','Sections'});
            for Property = DynamicProperties'
                delete(findprop(Object,cell2mat(Property)));
            end
            
            SplitChars = ['[=' Object.CommentChar '\[\]]'];
            
            ID = fopen(get(Object,'File'));
            
            while ~feof(ID)
                
                Line = fgetl(ID);
                                
                if ~isempty(Line)&&sum(Line)~=-1
                    
                    [String,~,~,~,SplitChar] = regexp(Line,SplitChars,'split');
                    
                    if ~isempty(SplitChar)
                        
                       switch SplitChar{1}
                           
                           % Comment
                           case Object.CommentChar
                               
                           % Section
                           case '['
                               
                               if numel(SplitChar)>=2
                                   if strcmp(SplitChar{2},']')
                                       Section0 = strTrimStrip(String{2});
                                       Section = rename(Section0);                                       
                                       if ~ismember(Section,properties(Object))
                                            addprop(Object,Section);
                                            Object.Sections{end+1} = Section0;
                                       end
                                   end
                               end
                               
                           % Field
                           case '='
                               fieldEndLine=ftell(ID);
                               % Split on the FIRST '=' only — everything after
                               % belongs to the value (which may contain '=' inside
                               % strings or struct(...) expressions).
                               eqIdx = strfind(Line,'=');
                               firstEq = eqIdx(1);
                               Field = rename(strTrimStrip(Line(1:firstEq-1)));
                               Value = Line(firstEq+1:end);
                               Struct_section = get(Object,Section);

                               Value2 = strTrimStrip(Value);
                               isString = ~isempty(Value2) && (Value2(1) == '''' || Value2(1) == '"');

                  
                               
                               Line = fgetl(ID);
                               
                               while(~isempty(Line)&&sum(Line)~=-1)
                                    [String,~,~,~,SplitChar] = regexp(Line,SplitChars,'split');
                                    
                                    if(isempty(SplitChar))
                                        splitChar='';
                                    else
                                        splitChar=SplitChar{1};
                                    end
                                        
                                    switch (splitChar)
                                        % Comment
                                       case Object.CommentChar
                                            Line='';
                                           break;
                                       % Section
                                       case '['  
                                           Line='';
                                           break;
                                       %Value
                                       case '='
                                           Line='';
                                           break;
                                        otherwise
                                           if(isString)
                                                Value=sprintf('%s\n%s',Value,Line);
                                           else
                                               Value=sprintf('%s...%s',Value,Line);
                                           end
                                           fieldEndLine=ftell(ID);
                                           Line = fgetl(ID);
                                    end
                                     
                               end
                               
                               fseek(ID,fieldEndLine,'bof'); %rewind
                               
                               if(isString)
                                    Struct_section.(Field) = strTrimStrip(stripStringComment(Value));
                               else
                                   try  %Try to convert to number or cell
                                       Struct_section.(Field) = eval(strTrimStrip(Value));
                                   catch %#ok<CTCH>  Fall back to string
                                       Struct_section.(Field) = strTrimStrip(Value);
                                   end
                               end
                               set(Object,Section,Struct_section);
                               
                       end
                       
                    end
                    
                end
                
            end
            
            fclose(ID);
            
          	Object.Sections = sort(Object.Sections);
            
        end
        
        % Function 'write' INI file
        function Object = write(Object,varargin)
            
            if nargin == 2
                set(Object,'File',varargin{1});
            end
            
          	Object.Sections = sort(Object.Sections);
            
            ID = fopen(get(Object,'File'),'w');
            
            for s = 1:numel(Object.Sections)
                
                % Section
                Section = Object.Sections{s};
                fprintf(ID,['[%s]' Object.NewLineChar],Section);   
                Section = rename(Section);
                Fields = fieldnames(Object.(Section)); 
                
                % Maximum name length
                M = 1;
                for f = 1:numel(Fields)
                    M = max(M,length(Fields{f}));
                end
                
                % Fields
                for f = 1:numel(Fields) 
                    
                    % Field name
                    Field = Fields{f};
                    Value = Object.(Section).(Field);                                        
                    fprintf(ID,'%s%s= ',Field,blanks(max(1,M+1-length(Field)))); 
                   
                    % Field value
                    Write_value(ID,Value);
                    
                    % Field end
                    fprintf(ID, Object.NewLineChar); 
                    
                end                    
                
                % Section end
                fprintf(ID, Object.NewLineChar); 
                
            end
                        
            fclose(ID);
                             
            % Function 'Write value' (struct, cell, char or numeric)
            function Write_value(ID,Value)
                
                if isstring(Value)
                    Value = char(Value);
                elseif isa(Value, 'function_handle')
                    Value = func2str(Value);
                end

                % Convert MATLAB objects with a toStruct method (e.g.
                % pf2_base.PipelineFunction) to their canonical legacy
                % struct form before serializing — otherwise we'd write
                % implementation-internal property names that no reader
                % knows how to interpret.
                if isobject(Value) && ~isstring(Value) ...
                        && ~isa(Value, 'function_handle') ...
                        && ismethod(Value, 'toStruct')
                    Value = Value.toStruct();
                end

                % Treat any remaining objects (without toStruct) as structs
                % so they round-trip through eval as structs.
                isObj = isobject(Value) && ~isstring(Value) && ...
                        ~isa(Value, 'function_handle');
                if isObj
                    Symbols = {'struct(',')'};
                else
                switch class(Value)
                    case 'struct'
                        Symbols = {'struct(',')'};
                    case 'cell'
                        Symbols = {'{','}'};
                    case 'char'
                        if isempty(Value)
                            Symbols = {'''',''''};
                        elseif(Value(1)==''''&&Value(end)=='''')||(Value(1)=='"'&&Value(end)=='"')
                            Symbols = {'',''};
                        else
                            Symbols = {'''',''''};
                        end
                    otherwise
                        if isscalar(Value)
                            Symbols = {'',''};
                        else
                            Symbols = {'[',']'};
                        end
                end
                end  % end isObj else

                fprintf(ID,Symbols{1});
                
                if isobject(Value)
                    Class = 'struct';
                else
                    Class = class(Value);
                end
                
                switch Class
                    case 'struct'                        
                        Fields_struct = fieldnames(Value);                        
                        for n = 1:numel(Fields_struct)
                            Field_struct  = Fields_struct{n};
                            fprintf(ID,'''%s'',',Field_struct);
                            Write_value(ID,Value.(Field_struct));
                            if n < numel(Fields_struct)
                                fprintf(ID,',');
                            end
                        end                        
                    case 'char'
                        fprintf(ID,'%s',Value);
                    otherwise
                        for n = 1:size(Value,1)
                            for m = 1:size(Value,2)
                                switch class(Value)
                                    case 'cell'
                                        Write_value(ID,Value{n,m});
                                        if m < size(Value,2)
                                            fprintf(ID,',');
                                        end
                                    case 'logical'
                                        fprintf(ID,'%d',double(Value(n,m)));
                                        if m < size(Value,2)
                                            fprintf(ID,',');
                                        end
                                    otherwise
                                        fprintf(ID,getFormatStr(Value(n,m)),Value(n,m));
                                        if m < size(Value,2)
                                            fprintf(ID,',');
                                        end
                                end
                            end
                            if n < size(Value,1)
                                fprintf(ID,';');
                            end
                        end
                end

                fprintf(ID,Symbols{2});

                function fmt = getFormatStr(Data)

                    switch class(Data)
                        case {'uint8','uint16','uint32','uint64'}
                            fmt = '%u';
                        case {'int8','int16','int32','int64'}
                            fmt = '%d';
                        case {'single','double'}
                            fmt = '%G';
                        case 'char'
                            fmt = '''%s''';
                        case 'logical'
                            fmt = '%d';
                        otherwise
                            error('Type "%s" not supported.',class(Data));
                    end

                end
                
            end
            
        end
        
        % Function 'add' sections
        function Object = add(Object,varargin)
                  
            Properties = varargin(1:2:end);
            Structures = varargin(2:2:end);
            
            for n = 1:length(Properties)   
                
                Section = Properties{n};
                Section2 = rename(Section);
                Structure = Structures{n};  
              
                addprop(Object,Section2);
                set(Object,Section2,Structure);                
                Object.Sections{end+1} = Section;
                    
            end
            
            Object.Sections = sort(Object.Sections);
        
        end
          
        % Function 'remove' [all]/[sections]
        function Object = remove(Object,varargin)
            
            switch nargin
                
                case 0
                    
                    Object.Sections = {};
                    DynamicProperties = setdiff(properties(Object),{'File','CommentChar','NewLineChar','Sections'});
                    for Property = DynamicProperties'
                        delete(Property{1});
                    end
                    
                otherwise
                    
                    Sections_clear = varargin;                    
                    for n = 1:numel(Sections_clear)      
                        
                        Section_clear = Sections_clear{n};
                        
                        for s = 1:numel(Object.Sections)                            
                            if strcmpi(rename(Object.Sections{s}),rename(Section_clear))
                                Object.Sections = setdiff(Object.Sections,Object.Sections{s});
                                break
                            end                            
                        end
                                                
                        [is, Property] = isproperty(Object,rename(Section_clear));
                        if is
                            delete(Object.findprop(Property));                        
                        else
                            error('Property "%s" not supported !',Property);
                        end
                        
                    end    
                    
            end
            
        end
        
    end
    
end

% Function 'rename' expression to generate variable name
function Name2 = rename(Name)

persistent Numbers LowerCases UpperCases

if isempty(Numbers)
    Numbers = arrayfun(@(n) {sprintf('%u',n)},0:9);
    LowerCases = arrayfun(@(n) {char(n+96)},1:26);
    UpperCases = arrayfun(@(n) {char(n+64)},1:26);
end

Name2 = '';
for n = 1:length(Name)
    Character = Name(n);
    switch Character
        case Numbers
        case LowerCases
        case UpperCases
        case {'�','�','�','�','�','�'},     Character = 'A';
        case '�',                           Character = 'AE';
        case '�',                           Character = 'C';
        case {'�','�','�','�'},             Character = 'E';
        case {'�','�','�','�'},             Character = 'I';
        case '�',                           Character = 'N';
        case {'�','�','�','�','�'},         Character = 'O';
        case {'�','�','�','�'},             Character = 'U';
        case '�',                           Character = 'Y';
        case '�',                           Character = '2';
        case '�',                           Character = '3';
        case '�',                           Character = '1_4';
        case '�',                           Character = '1_2';
        case '�',                           Character = '3_4';
        case {'�','�','�','�','�','�'},     Character = 'a';
        case '�',                           Character = 'ae';
        case '�',                           Character = 'c';
        case {'�','�','�','�'},             Character = 'e';
        case {'�','�','�','�'},             Character = 'i';
        case '�',                           Character = 'n';
        case {'�','�','�','�','�'},         Character = 'o';
        case {'�','�','�','�','�'},         Character = 'u';
        case {'�','�'},                     Character = 'y';
        case {' ','''', '-', '_',...
                '(','[','/','\'},         	Character = '_';
        case {'�'},                         Character = 'deg';
        otherwise,                          Character = '' ;
    end
    Name2 = [Name2, Character]; %#ok<AGROW>
end

Name2 = strrep(Name2,'__','_');
if length(Name2) > 1
    if strcmp(Name2(end),'_')
        Name2 = Name2(1:end-1);
    end
end
Name2 = matlab.lang.makeValidName(Name2);

end

function str_trimmed=strTrimStrip(str)

    str_trimmed=strtrim(str);

    if(~isempty(str_trimmed)&&length(str_trimmed)>2)
        if(str_trimmed(1)==''''&&str_trimmed(end)=='''')||(str_trimmed(end)=='"'&&str_trimmed(1)=='"')
            str_trimmed=str_trimmed(2:end-1);
        end
    end

end

function out=stripStringComment(value)
% STRIPSTRINGCOMMENT Drop a trailing inline comment from a quoted value.
%
% For a value that begins with a quote (e.g. "'name' % comment"), returns the
% quoted literal only, discarding anything after the closing quote. A '%' that
% falls INSIDE the quotes is preserved, and a doubled quote ('') is treated as
% an escaped quote (not the terminator), so values like 'O''Brien' survive
% intact. Non-quoted or unterminated values are returned unchanged.

    out = value;
    v = strtrim(value);
    if isempty(v)
        return;
    end
    q = v(1);
    if q ~= '''' && q ~= '"'
        return;  % not a quoted string; leave for the eval/number path
    end
    i = 2;
    n = numel(v);
    while i <= n
        if v(i) == q
            if i < n && v(i + 1) == q
                i = i + 2;          % doubled quote = escaped, skip both
            else
                out = v(1:i);        % real closing quote; drop trailing comment
                return;
            end
        else
            i = i + 1;
        end
    end
    % no closing quote found (e.g. multi-line); leave unchanged
end
