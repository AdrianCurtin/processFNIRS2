function x=pf2_unpackMethod(method)
% PF2_UNPACKMETHOD Parse method configuration into executable function chain
%
% Unpacks processing method definitions stored in configuration files into
% a structured format with function handles, arguments, and output mappings.
% Converts legacy .S field notation to the .F cell array format used by the
% processing pipeline.
%
% Reference:
%   Internal pf2 implementation for method configuration parsing.
%
% Syntax:
%   x = pf2_unpackMethod(method)
%
% Inputs:
%   method - Method configuration in one of several formats:
%            - Empty [] returns struct with empty F cell
%            - Cell array with .F field already defined
%            - Cell array of function structs
%            - Struct with .S1, .S2, etc. legacy fields
%
% Outputs:
%   x - Unpacked method structure containing:
%       .F    - Cell array of function definitions, each with:
%               .f       - Function name or handle
%               .args    - Cell array of argument names
%               .argvals - Cell array of argument values
%               .default_argvals - Cell array of default values
%               .output  - Cell array of output variable names
%       .name - Method display name (default: 'Unknown Method')
%
% Algorithm:
%   1. Handle empty input or already-unpacked methods
%   2. Convert legacy .S# notation to .F cell array
%   3. Flatten any struct arrays within function definitions
%   4. Ensure consistent field structure across all functions
%
% Example:
%   % Unpack a method loaded from configuration
%   method = PF2.rawMethods{1};
%   unpacked = pf2_base.pf2_unpackMethod(method);
%   fprintf('Method has %d processing steps\n', length(unpacked.F));
%
% See also: pf2_base.PipelineFunction, pf2_base.Pipeline,
%           processStageRaw2OD, processStageFilterHb
    x=method;
    
    if(isempty(method))
        x.F=cell(0);
        return
    elseif(iscell(x)&&isfield(x{1},'F'))
       x=x{1}; 
    end
    
    if isfield(x,'F') && iscell(x.F)
        % F is already a proper cell array — use as-is
    elseif isfield(x,'F') && isstruct(x.F)
        % Config loading produced a struct array — convert to cell
        tmp = cell(1, numel(x.F));
        for k = 1:numel(x.F)
            tmp{k} = x.F(k);
        end
        x.F = tmp;
    else
        % F is missing or corrupted (e.g. char from INI serialization)
        % — fall through to S# field extraction
        if isfield(x,'F'), x = rmfield(x,'F'); end
        if(iscell(x)&&~isstruct(x))
            t=x;
            x=cell(0);
            x.F=t;
            for i=length(x.F):-1:1
               if(~isfield(x.F{i},'f'))
                  x.F(i)=[]; 
               end
            end
            x.name=('Unknown Method');
        else
            x.F={};
            x_fields=fieldnames(x);
            for j=1:length(x_fields)
                fieldName=sprintf('S%d',j);
                if isfield(x,fieldName)
                    x.F{end+1}=x.(fieldName);
                    x=rmfield(x,fieldName);
                end
            end
        end
    end
    
    for idx=1:length(x.F)
        Fidx=x.F{idx};

        % Already a PipelineFunction — leave as-is
        if isa(Fidx, 'pf2_base.PipelineFunction')
            continue
        end

        % Recover from cfg files corrupted by an older INI reader that
        % truncated values containing '=' (e.g. inside descriptions). The
        % serialized form starts with `struct(`; try to eval back to a struct.
        if (ischar(Fidx) || isstring(Fidx)) && startsWith(strtrim(char(Fidx)), 'struct(')
            try
                Fidx = eval(char(Fidx));
                x.F{idx} = Fidx;
            catch
                % Leave as-is; downstream check will warn.
            end
        end

        if isstruct(Fidx) && length(Fidx) > 1
           %This is a struct array for some reason — change it back!
           F_noarray.f=Fidx(1).f;
           F_noarray.args=cell(0,0);
           F_noarray.argvals=cell(0,0);
           F_noarray.default_argvals=cell(0,0);
           for j=1:length(Fidx)
                F_noarray.args{j}=Fidx(j).args;
                F_noarray.argvals{j}=Fidx(j).argvals;
                if isfield(Fidx, 'default_argvals')
                    F_noarray.default_argvals{j}=Fidx(j).default_argvals;
                else
                    F_noarray.default_argvals{j}=Fidx(j).argvals;
                end
           end
           % Output is the same across all struct array elements (artifact of
           % MATLAB struct() distributing scalar values). Take from first only.
           if isfield(Fidx, 'output')
               F_noarray.output = Fidx(1).output;
           else
               F_noarray.output = 'x';
           end
           x.F{idx}=F_noarray;
           Fidx=x.F{idx};
        end

        % Convert legacy struct → PipelineFunction at unpack time
        if isstruct(Fidx) && isfield(Fidx, 'f')
            x.F{idx} = pf2_base.PipelineFunction.fromStruct(Fidx);
        end
    end


end