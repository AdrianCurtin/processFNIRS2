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
% See also: pf2_describeMethod, processStageRaw2OD, processStageFilterHb
    x=method;
    
    if(isempty(method))
        x.F=cell(0);
        return
    elseif(iscell(x)&&isfield(x{1},'F'))
       x=x{1}; 
    end
    
    if(isfield(x,'F'))
        %return;
    else
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
            x.F=cell(0);
            x_fields=fields(x);

            numMethods=1;
            for j=1:length(x_fields)
               if(strcmp(sprintf('S%i',j),x_fields))
                   x.F{numMethods}=x.(sprintf('S%i',j));
                   x=rmfield(x,sprintf('S%i',j));
                   numMethods=numMethods+1;
               end
            end
        end
    end
    
    for idx=1:length(x.F)
        Fidx=x.F{idx};
        if(length(Fidx)>1) %This is a struct array for some reason?
           %Change it back!
           F_noarray.f=Fidx(1).f;
           F_noarray.args=cell(0,0);
           F_noarray.argvals=cell(0,0);
           F_noarray.default_argvals=cell(0,0);
		   F_noarray.output=cell(0);
           for j=1:length(Fidx)
                F_noarray.args{j}=Fidx(j).args;
                F_noarray.argvals{j}=Fidx(j).argvals;
                F_noarray.default_argvals{j}=Fidx(j).default_argvals;
				if(isfield(Fidx(j),'output'))
                    F_noarray.output{j}=Fidx(j).output;
                else
                    F_noarray.output{j}=Fidx(j).output;
                end
           end
           x.F{idx}=F_noarray;
        end
    end
    

end