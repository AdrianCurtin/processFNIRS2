classdef PipelineFunction
% PIPELINEFUNCTION Precomputed processing function for the fNIRS pipeline
%
% Encapsulates a single processing function with precomputed argument
% mappings, output indices, and a cached function handle. Supports both
% positional and name-value calling conventions.
%
% All string comparisons and index lookups happen at construction time.
% The execute() method uses only precomputed integer indices and a
% switch on uint8 enum values, so it adds zero overhead to the hot loop.
%
% Syntax:
%   pf = pf2_base.PipelineFunction(funcName, args, defaults, outputs)
%   pf = pf2_base.PipelineFunction(..., 'Name', Value)
%   pf = pf2_base.PipelineFunction.fromStruct(s)
%
% Inputs:
%   funcName - Function name string (e.g. 'pf2_lpf')
%   args     - Cell array of argument names {'x','filtType','fs','freq_cut','Nf'}
%   defaults - Cell array of default values {[], 1, [], 0.1, 50}
%   outputs  - Cell array of output names {'x'} or {'x','fchMask'}
%
% Name-Value Parameters:
%   'Style'       - 'positional' (default) or 'namevalue'
%   'Name'        - Display name (e.g. 'Low Pass Filter')
%   'Description' - Long description
%   'ValidStages' - Numeric vector of valid stages (e.g. [1,2])
%   'RequiresOD'  - Logical, true if function needs OD input
%
% Example:
%   pf = pf2_base.PipelineFunction('pf2_lpf', ...
%       {'x','filtType','fs','freq_cut','Nf'}, ...
%       {[], 1, [], 0.1, 50}, {'x'});
%   ctx.x = data; ctx.fs = 10;
%   out = pf.execute(ctx);
%
% See also: pf2_base.pf2_unpackMethod, pf2_base.fnirs.processStageRaw2OD

    properties (SetAccess = immutable)
        funcName          char
        funcHandle        function_handle
        name              char
        description       char
        validStages       double
        requiresOD        logical
        style             char

        % Precomputed argument mapping
        argNames          cell
        argDefaults       cell
        specialMask       logical
        specialTypes      uint8
        customIndices     double
        customNames       cell

        % Precomputed output mapping
        outputNames       cell
        xOutIdx           double
        maskOutIdx        double
        timeMaskOutIdx    double
        structOutIdx      double
        roiOutIdx         double
        nOutputs          double

        % Convenience flags
        isIntensity2OD    logical
    end

    % Special argument type enum constants
    properties (Constant, Hidden)
        SPECIAL_X               = uint8(1)
        SPECIAL_FS              = uint8(2)
        SPECIAL_FTIME           = uint8(3)
        SPECIAL_FCHMASK         = uint8(4)
        SPECIAL_FTIMECHMASK     = uint8(5)
        SPECIAL_FCHANNELNUMBERS = uint8(6)
        SPECIAL_FCHANNELSD      = uint8(7)
        SPECIAL_FPROBEINFO      = uint8(8)
        SPECIAL_FMARKERS        = uint8(9)
        SPECIAL_FNIRSTRUCT      = uint8(10)
        SPECIAL_FAUX            = uint8(11)
        SPECIAL_FAMBIENT        = uint8(12)
    end

    methods
        function obj = PipelineFunction(funcName, args, defaults, outputs, varargin)
        % Constructor — precomputes all argument and output mappings.

            if nargin == 0
                % Allow empty construction for array preallocation
                obj.funcName = '';
                obj.funcHandle = @(varargin) [];
                obj.name = '';
                obj.description = '';
                obj.validStages = [];
                obj.requiresOD = false;
                obj.style = 'positional';
                obj.argNames = {};
                obj.argDefaults = {};
                obj.specialMask = logical([]);
                obj.specialTypes = uint8([]);
                obj.customIndices = [];
                obj.customNames = {};
                obj.outputNames = {};
                obj.xOutIdx = 0;
                obj.maskOutIdx = 0;
                obj.timeMaskOutIdx = 0;
                obj.structOutIdx = 0;
                obj.roiOutIdx = 0;
                obj.nOutputs = 0;
                obj.isIntensity2OD = false;
                return
            end

            % Parse optional name-value pairs
            p = inputParser;
            p.addParameter('Style', 'positional', @(x) ismember(x, {'positional','namevalue'}));
            p.addParameter('Name', '', @ischar);
            p.addParameter('Description', '', @ischar);
            p.addParameter('ValidStages', [], @isnumeric);
            p.addParameter('RequiresOD', false, @islogical);
            p.parse(varargin{:});

            obj.funcName = char(funcName);
            obj.funcHandle = str2func(obj.funcName);
            obj.name = p.Results.Name;
            obj.description = p.Results.Description;
            obj.validStages = p.Results.ValidStages;
            obj.requiresOD = p.Results.RequiresOD;
            obj.style = p.Results.Style;
            obj.isIntensity2OD = contains(obj.funcName, 'Intensity2OD');

            % Ensure cell arrays
            if ~iscell(args), args = {args}; end
            if ~iscell(defaults), defaults = {defaults}; end
            if ~iscell(outputs), outputs = {outputs}; end

            obj.argNames = args;

            % Pad defaults to match args length
            if numel(defaults) < numel(args)
                defaults(end+1:numel(args)) = {[]};
            end
            obj.argDefaults = defaults;

            % Build the special argument map (persistent, shared across all instances)
            specialMap = pf2_base.PipelineFunction.specialArgMap();

            nArgs = numel(args);
            sMask = false(1, nArgs);
            sTypes = zeros(1, nArgs, 'uint8');
            custIdx = [];
            custNames = {};

            for k = 1:nArgs
                argName = args{k};
                if specialMap.isKey(argName)
                    sMask(k) = true;
                    sTypes(k) = specialMap(argName);
                else
                    custIdx(end+1) = k; %#ok<AGROW>
                    custNames{end+1} = argName; %#ok<AGROW>
                end
            end

            obj.specialMask = sMask;
            obj.specialTypes = sTypes;
            obj.customIndices = custIdx;
            obj.customNames = custNames;

            % Precompute output indices
            obj.outputNames = outputs;
            obj.nOutputs = numel(outputs);
            obj.xOutIdx = 0;
            obj.maskOutIdx = 0;
            obj.timeMaskOutIdx = 0;
            obj.structOutIdx = 0;
            obj.roiOutIdx = 0;

            for k = 1:numel(outputs)
                switch lower(outputs{k})
                    case 'x'
                        if obj.xOutIdx == 0
                            obj.xOutIdx = k;
                        end
                    case 'fchmask'
                        if obj.maskOutIdx == 0
                            obj.maskOutIdx = k;
                        end
                    case 'ftimechmask'
                        if obj.timeMaskOutIdx == 0
                            obj.timeMaskOutIdx = k;
                        end
                    case 'fnirstruct'
                        if obj.structOutIdx == 0
                            obj.structOutIdx = k;
                        end
                    case 'roi'
                        if obj.roiOutIdx == 0
                            obj.roiOutIdx = k;
                        end
                end
            end
        end

        function out = execute(obj, ctx)
        % EXECUTE Run the function with precomputed argument mapping.
        %
        %   out = pf.execute(ctx)
        %
        %   ctx is a struct with fields matching the special arg names:
        %     .x, .fs, .fTime, .fchMask, .ftimeChMask, .fChannelNumbers,
        %     .fChannelSD, .fProbeInfo, .fMarkers, .fNIRstruct, .fAux, .fAmbient
        %
        %   Returns a cell array of outputs.

            args = obj.argDefaults;

            % Fill special args by precomputed index
            specIdx = find(obj.specialMask);
            for ii = 1:numel(specIdx)
                k = specIdx(ii);
                switch obj.specialTypes(k)
                    case 1;  args{k} = ctx.x;
                    case 2;  args{k} = ctx.fs;
                    case 3;  args{k} = ctx.fTime;
                    case 4;  args{k} = ctx.fchMask;
                    case 5;  args{k} = ctx.ftimeChMask;
                    case 6;  args{k} = ctx.fChannelNumbers;
                    case 7;  args{k} = ctx.fChannelSD;
                    case 8;  args{k} = ctx.fProbeInfo;
                    case 9;  args{k} = ctx.fMarkers;
                    case 10; args{k} = ctx.fNIRstruct;
                    case 11; args{k} = ctx.fAux;
                    case 12; args{k} = ctx.fAmbient;
                end
            end

            % Call function
            if strcmp(obj.style, 'positional')
                [out{1:obj.nOutputs}] = obj.funcHandle(args{:});
            else
                % Name-value: special (positional) args first, then NV pairs
                posArgs = args(obj.specialMask);
                nCustom = numel(obj.customIndices);
                nvArgs = cell(1, 2*nCustom);
                for ii = 1:nCustom
                    idx = obj.customIndices(ii);
                    nvArgs{2*ii-1} = obj.customNames{ii};
                    nvArgs{2*ii}   = args{idx};
                end
                [out{1:obj.nOutputs}] = obj.funcHandle(posArgs{:}, nvArgs{:});
            end
        end

        function newObj = setParam(obj, paramName, value)
        % SETPARAM Return a new PipelineFunction with an updated default value.
        %
        %   newPf = pf.setParam('freq_cut', 0.2)

            idx = find(strcmp(obj.customNames, paramName), 1);
            if isempty(idx)
                error('pf2:PipelineFunction:unknownParam', ...
                    'Parameter ''%s'' not found. Available: %s', ...
                    paramName, strjoin(obj.customNames, ', '));
            end
            argIdx = obj.customIndices(idx);
            newDefaults = obj.argDefaults;
            newDefaults{argIdx} = value;
            newObj = pf2_base.PipelineFunction(obj.funcName, obj.argNames, ...
                newDefaults, obj.outputNames, ...
                'Style', obj.style, 'Name', obj.name, ...
                'Description', obj.description, ...
                'ValidStages', obj.validStages, ...
                'RequiresOD', obj.requiresOD);
        end

        function newObj = addArg(obj, argName, defaultValue)
        % ADDARG Return a new PipelineFunction with an additional argument.
        %
        %   newPf = pf.addArg('threshold', 0.5)
        %   newPf = pf.addArg('x')              % special arg, default []
        %
        % If the argument already exists, updates its default value instead.

            if nargin < 3, defaultValue = []; end
            argName = char(argName);

            % If arg already exists, delegate to setParam for custom args
            % or silently return for special args (already mapped)
            existing = find(strcmp(obj.argNames, argName), 1);
            if ~isempty(existing)
                specialMap = pf2_base.PipelineFunction.specialArgMap();
                if specialMap.isKey(argName)
                    newObj = obj;  % already present as special arg
                else
                    newObj = obj.setParam(argName, defaultValue);
                end
                return
            end

            newArgs = [obj.argNames, {argName}];
            newDefaults = [obj.argDefaults, {defaultValue}];
            newObj = pf2_base.PipelineFunction(obj.funcName, newArgs, ...
                newDefaults, obj.outputNames, ...
                'Style', obj.style, 'Name', obj.name, ...
                'Description', obj.description, ...
                'ValidStages', obj.validStages, ...
                'RequiresOD', obj.requiresOD);
        end

        function newObj = removeArg(obj, argName)
        % REMOVEARG Return a new PipelineFunction without the named argument.
        %
        %   newPf = pf.removeArg('Nf')
        %
        % Errors if the argument does not exist.

            argName = char(argName);
            idx = find(strcmp(obj.argNames, argName), 1);
            if isempty(idx)
                error('pf2:PipelineFunction:unknownArg', ...
                    'Argument ''%s'' not found. Available: %s', ...
                    argName, strjoin(obj.argNames, ', '));
            end

            newArgs = obj.argNames;
            newArgs(idx) = [];
            newDefaults = obj.argDefaults;
            newDefaults(idx) = [];
            newObj = pf2_base.PipelineFunction(obj.funcName, newArgs, ...
                newDefaults, obj.outputNames, ...
                'Style', obj.style, 'Name', obj.name, ...
                'Description', obj.description, ...
                'ValidStages', obj.validStages, ...
                'RequiresOD', obj.requiresOD);
        end

        function newObj = addOutput(obj, outputName)
        % ADDOUTPUT Return a new PipelineFunction with an additional output.
        %
        %   newPf = pf.addOutput('fchMask')
        %
        % If the output already exists, returns unchanged.

            outputName = char(outputName);
            if any(strcmpi(obj.outputNames, outputName))
                newObj = obj;
                return
            end

            newOutputs = [obj.outputNames, {outputName}];
            newObj = pf2_base.PipelineFunction(obj.funcName, obj.argNames, ...
                obj.argDefaults, newOutputs, ...
                'Style', obj.style, 'Name', obj.name, ...
                'Description', obj.description, ...
                'ValidStages', obj.validStages, ...
                'RequiresOD', obj.requiresOD);
        end

        function val = getParam(obj, paramName)
        % GETPARAM Get the current default value for a custom parameter.

            idx = find(strcmp(obj.customNames, paramName), 1);
            if isempty(idx)
                error('pf2:PipelineFunction:unknownParam', ...
                    'Parameter ''%s'' not found. Available: %s', ...
                    paramName, strjoin(obj.customNames, ', '));
            end
            val = obj.argDefaults{obj.customIndices(idx)};
        end

        function s = params(obj)
        % PARAMS Return a struct of all custom parameters with current defaults.

            s = struct();
            for k = 1:numel(obj.customIndices)
                s.(obj.customNames{k}) = obj.argDefaults{obj.customIndices(k)};
            end
        end

        function newObj = setParams(obj, varargin)
        % SETPARAMS Bulk-set multiple parameters at once.
        %
        %   newPf = pf.setParams('freq_cut', 0.2, 'Nf', 100)
        %   newPf = pf.setParams(struct('freq_cut', 0.2, 'Nf', 100))
        %
        % Unknown keys are added via addArg. Context (special) arg keys
        % produce a warning and are skipped.

            if isempty(varargin)
                newObj = obj;
                return
            end

            % Expand struct to NV pairs
            if isstruct(varargin{1})
                s = varargin{1};
                fnames = fieldnames(s);
                nvPairs = cell(1, 2*numel(fnames));
                for k = 1:numel(fnames)
                    nvPairs{2*k-1} = fnames{k};
                    nvPairs{2*k}   = s.(fnames{k});
                end
                varargin = nvPairs;
            end

            if mod(numel(varargin), 2) ~= 0
                error('pf2:PipelineFunction:badNVPairs', ...
                    'Arguments must be name-value pairs or a struct.');
            end

            specialNames = pf2_base.PipelineFunction.specialArgNames();
            newObj = obj;
            for k = 1:2:numel(varargin)
                paramName = char(varargin{k});
                value = varargin{k+1};

                if ismember(paramName, specialNames)
                    warning('pf2:PipelineFunction:contextArg', ...
                        'Skipping context arg ''%s'' — not a tunable parameter.', paramName);
                    continue
                end

                if ismember(paramName, newObj.customNames)
                    newObj = newObj.setParam(paramName, value);
                else
                    newObj = newObj.addArg(paramName, value);
                end
            end
        end

        function tbl = args(obj)
        % ARGS Return a table of all arguments with Kind column.
        %
        %   tbl = pf.args()
        %
        %   Returns a table with columns: Position, Name, Kind, Default.
        %   Kind is 'context' for special args, 'parameter' for custom args.

            nArgs = numel(obj.argNames);
            Position = (1:nArgs)';
            Name = obj.argNames(:);
            Kind = repmat({'parameter'}, nArgs, 1);
            Default = obj.argDefaults(:);

            for k = 1:nArgs
                if obj.specialMask(k)
                    Kind{k} = 'context';
                end
            end

            tbl = table(Position, Name, Kind, Default);
        end

        function s = toStruct(obj)
        % TOSTRUCT Convert to legacy .F{i} struct format.
        %
        %   s = pf.toStruct()
        %
        %   Returns a struct with fields: .f, .args, .argvals,
        %   .default_argvals, .output, and metadata fields when non-default.

            s.f = obj.funcName;
            s.args = obj.argNames;
            s.argvals = obj.argDefaults;
            s.default_argvals = obj.argDefaults;
            s.output = obj.outputNames;

            % Preserve metadata for lossless round-trip via INI.
            % Use 'displayName' not 'name' — the GUI uses
            % isfield(F{i},'name') to detect method headers vs functions.
            % fromStruct() reads .displayName back; pf2_unpackMethod calls
            % fromStruct() on INI load, so the round-trip is preserved.
            if ~strcmp(obj.style, 'positional')
                s.style = obj.style;
            end
            if ~isempty(obj.name)
                s.displayName = obj.name;
            end
            if ~isempty(obj.description)
                s.description = obj.description;
            end
            if ~isempty(obj.validStages)
                s.validStages = obj.validStages;
            end
            if obj.requiresOD
                s.requiresOD = true;
            end
        end

        function hasX = hasSpecialArg(obj, argType)
        % HASSPECIALARG Check if function uses a specific special argument type.
        %
        %   tf = pf.hasSpecialArg('x')    % true if function takes 'x' input

            specialMap = pf2_base.PipelineFunction.specialArgMap();
            if specialMap.isKey(argType)
                hasX = any(obj.specialTypes == specialMap(argType));
            else
                hasX = false;
            end
        end

        function disp(obj)
        % DISP Compact display for PipelineFunction.

            if numel(obj) ~= 1
                fprintf('  %dx%d PipelineFunction array\n', size(obj,1), size(obj,2));
                return
            end

            if isempty(obj.funcName)
                fprintf('  PipelineFunction (empty)\n');
                return
            end

            displayName = obj.funcName;
            if ~isempty(obj.name)
                displayName = sprintf('%s (%s)', obj.name, obj.funcName);
            end

            fprintf('  PipelineFunction: %s\n', displayName);
            fprintf('    Style: %s | Outputs: %s\n', obj.style, strjoin(obj.outputNames, ', '));

            if ~isempty(obj.customNames)
                fprintf('    Parameters:\n');
                for k = 1:numel(obj.customNames)
                    val = obj.argDefaults{obj.customIndices(k)};
                    if isnumeric(val)
                        fprintf('      %s = %s\n', obj.customNames{k}, mat2str(val));
                    elseif ischar(val) || isstring(val)
                        fprintf('      %s = ''%s''\n', obj.customNames{k}, char(val));
                    else
                        fprintf('      %s = [%s]\n', obj.customNames{k}, class(val));
                    end
                end
            end
        end
    end

    methods (Static)
        function pf = fromStruct(s)
        % FROMSTRUCT Create PipelineFunction from a legacy .F{i} struct.
        %
        %   pf = pf2_base.PipelineFunction.fromStruct(s)
        %
        %   s must have fields: .f, .args, .argvals
        %   Optional: .output, .default_argvals

            if ~isfield(s, 'f') || isempty(s.f)
                error('pf2:PipelineFunction:noFunc', 'Struct must have .f field');
            end

            funcName = s.f;

            % Handle struct arrays (legacy format)
            if length(s) > 1
                args = cell(1, length(s));
                defaults = cell(1, length(s));
                for j = 1:length(s)
                    args{j} = s(j).args;
                    if isfield(s, 'default_argvals')
                        defaults{j} = s(j).default_argvals;
                    else
                        defaults{j} = s(j).argvals;
                    end
                end
            else
                args = s.args;
                defaults = s.argvals;
                if isfield(s, 'default_argvals') && ~isempty(s.default_argvals)
                    defaults = s.default_argvals;
                end
            end

            % Ensure cell arrays
            if ~iscell(args), args = {args}; end
            if ~iscell(defaults), defaults = {defaults}; end

            % Extract outputs
            if isfield(s, 'output') && ~isempty(s.output)
                outputs = s.output;
                if iscell(outputs) && ~isempty(outputs) && iscell(outputs{1})
                    outputs = outputs{1};
                end
                if ~iscell(outputs)
                    outputs = {outputs};
                end
            else
                outputs = {'x'};
            end

            % Restore metadata from struct fields first, fall back to config
            [cfgName, cfgDesc, cfgStages, cfgReqOD] = pf2_base.PipelineFunction.lookupFunctionMeta(funcName);

            if isfield(s, 'displayName') && ~isempty(s.displayName)
                displayName = s.displayName;
            else
                displayName = cfgName;
            end
            if isfield(s, 'description') && ~isempty(s.description)
                desc = s.description;
            else
                desc = cfgDesc;
            end
            if isfield(s, 'validStages') && ~isempty(s.validStages)
                stages = s.validStages;
            else
                stages = cfgStages;
            end
            if isfield(s, 'requiresOD')
                reqOD = s.requiresOD;
            else
                reqOD = cfgReqOD;
            end

            styleVal = 'positional';
            if isfield(s, 'style') && ~isempty(s.style)
                styleVal = s.style;
            end

            pf = pf2_base.PipelineFunction(funcName, args, defaults, outputs, ...
                'Style', styleVal, 'Name', displayName, 'Description', desc, ...
                'ValidStages', stages, 'RequiresOD', reqOD);
        end

        function names = specialArgNames()
        % SPECIALARGNAMES Return the canonical list of special argument names.

            names = {'x', 'fs', 'fTime', 'fchMask', 'ftimeChMask', ...
                     'fChannelNumbers', 'fChannelSD', 'fProbeInfo', ...
                     'fMarkers', 'fNIRstruct', 'fAux', 'fAmbient'};
        end

        function pf = detect(funcName)
        % DETECT Auto-discover a function's signature and build a PipelineFunction.
        %
        %   pf = pf2_base.PipelineFunction.detect('pf2_lpf')
        %   pf = pf2_base.PipelineFunction.detect('detrend_3rd_order')
        %
        % Looks up the function in the config first. If not found, parses
        % the source file's function line to extract argument and output
        % names. Special/context args are classified automatically.
        %
        % Errors if the function cannot be found on the path.

            funcName = char(funcName);

            % 1. Try config first
            cfg = pf2_base.Pipeline.loadFuncConfig();
            if isfield(cfg, funcName)
                pf = pf2_base.Pipeline.buildFromConfig(funcName, cfg.(funcName));
                return
            end

            % 2. Find source file
            srcPath = which(funcName);
            if isempty(srcPath)
                error('pf2:PipelineFunction:notFound', ...
                    'Function ''%s'' not found on the MATLAB path.', funcName);
            end
            [~, ~, ext] = fileparts(srcPath);
            if ~strcmp(ext, '.m')
                error('pf2:PipelineFunction:notSource', ...
                    'Function ''%s'' is not a .m file (found: %s).', funcName, srcPath);
            end

            % 3. Parse function line
            [argNames, outputNames] = pf2_base.PipelineFunction.parseFunctionLine(srcPath);

            % 4. Strip varargin
            vaIdx = strcmp(argNames, 'varargin');
            if any(vaIdx)
                warning('pf2:PipelineFunction:varargin', ...
                    'Function ''%s'' uses varargin — dropped from signature.', funcName);
                argNames(vaIdx) = [];
            end

            % 5. Map single unrecognized output to 'x'
            specialNames = pf2_base.PipelineFunction.specialArgNames();
            knownOutputs = [{'x'}, specialNames, {'ROI'}];
            for k = 1:numel(outputNames)
                if ~any(strcmpi(outputNames{k}, knownOutputs))
                    outputNames{k} = 'x';
                end
            end

            % 6. Defaults all []
            defaults = cell(1, numel(argNames));
            for k = 1:numel(defaults)
                defaults{k} = [];
            end

            % 7. Look up metadata
            [displayName, desc, stages, reqOD] = ...
                pf2_base.PipelineFunction.lookupFunctionMeta(funcName);

            % 8. Construct
            pf = pf2_base.PipelineFunction(funcName, argNames, defaults, ...
                outputNames, 'Name', displayName, 'Description', desc, ...
                'ValidStages', stages, 'RequiresOD', reqOD);
        end

        function pf = fromString(callStr)
        % FROMSTRING Parse a MATLAB call-syntax string into a PipelineFunction.
        %
        %   pf = pf2_base.PipelineFunction.fromString('[x]=pf2_lpf(x,1,fs,0.2,50)')
        %   pf = pf2_base.PipelineFunction.fromString('pf2_Intensity2OD(x)')
        %   pf = pf2_base.PipelineFunction.fromString('[x,fchMask]=pf2_SMAR(x,10,0.025,-1)')
        %
        % Parses the call string to extract function name, outputs, and
        % argument values. Uses detect() to get the canonical arg names,
        % then fills in parameter values from the call string. Context
        % (special) args keep [] defaults regardless of call-string values.

            callStr = strtrim(char(callStr));

            % Split on '=' to get output part and call part
            eqIdx = find(callStr == '=', 1);
            if ~isempty(eqIdx)
                outPart = strtrim(callStr(1:eqIdx-1));
                callPart = strtrim(callStr(eqIdx+1:end));

                % Parse output names (strip brackets)
                outPart = strrep(outPart, '[', '');
                outPart = strrep(outPart, ']', '');
                callOutputs = strsplit(strtrim(outPart), ',');
                callOutputs = cellfun(@strtrim, callOutputs, 'UniformOutput', false);
                callOutputs = callOutputs(~cellfun(@isempty, callOutputs));
            else
                callPart = callStr;
                callOutputs = {};
            end

            % Extract funcName and arg string from call part
            parenIdx = find(callPart == '(', 1);
            if isempty(parenIdx)
                funcName = callPart;
                argStr = '';
            else
                funcName = strtrim(callPart(1:parenIdx-1));
                % Find matching close paren
                closeIdx = find(callPart == ')', 1, 'last');
                if isempty(closeIdx)
                    argStr = callPart(parenIdx+1:end);
                else
                    argStr = callPart(parenIdx+1:closeIdx-1);
                end
            end

            % Tokenize arg string
            if isempty(strtrim(argStr))
                tokens = {};
            else
                tokens = pf2_base.PipelineFunction.tokenizeArgs(argStr);
            end

            % Detect canonical signature
            basePf = pf2_base.PipelineFunction.detect(funcName);

            % Build defaults: for each position, if arg is special → [],
            % otherwise parse the call-string token value
            specialNames = pf2_base.PipelineFunction.specialArgNames();
            newDefaults = basePf.argDefaults;
            nArgs = numel(basePf.argNames);

            for k = 1:min(numel(tokens), nArgs)
                if ismember(basePf.argNames{k}, specialNames)
                    % Context arg: keep [] regardless of call-string value
                    newDefaults{k} = [];
                else
                    newDefaults{k} = pf2_base.PipelineFunction.parseToken(tokens{k});
                end
            end

            % Use call outputs if provided, otherwise detect's outputs
            if ~isempty(callOutputs)
                outputs = callOutputs;
            else
                outputs = basePf.outputNames;
            end

            % Construct with canonical arg names but call-string values
            pf = pf2_base.PipelineFunction(funcName, basePf.argNames, ...
                newDefaults, outputs, ...
                'Name', basePf.name, 'Description', basePf.description, ...
                'ValidStages', basePf.validStages, 'RequiresOD', basePf.requiresOD);
        end

        function register(pf)
        % REGISTER Save a PipelineFunction definition to the function library.
        %
        %   pf2_base.PipelineFunction.register(pf)
        %
        % Writes the function's full signature (arguments, defaults, outputs,
        % metadata) into pf2_functions_default.cfg so that it can be looked
        % up by Pipeline.add() and the GUI. Existing entries are overwritten.
        %
        % Example:
        %   pf = pf2_base.PipelineFunction('myFilter', ...
        %       {'x','fs','cutoff'}, {[],[],0.1}, {'x'}, ...
        %       'Name', 'My Filter', 'ValidStages', [1,2]);
        %   pf2_base.PipelineFunction.register(pf);

            rootPath = pf2_base.pf2_defaultRootPath();
            cfgPath = fullfile(rootPath, 'prefs', 'pf2_functions_default.cfg');

            ini = pf2_base.external.INI('File', cfgPath);
            ini.read();

            secName = pf.funcName;

            % Remove existing section if present
            if ismember(secName, ini.Sections)
                ini.remove(secName);
            end

            % Build section struct
            sec = struct();
            if ~isempty(pf.name)
                sec.Name = sprintf('''%s''', pf.name);
            end
            if ~isempty(pf.description)
                sec.Description = sprintf('''%s''', pf.description);
            end

            % Arguments and Output as cell array expressions
            sec.Arguments = pf.argNames;
            sec.Output = pf.outputNames;

            if ~isempty(pf.validStages)
                sec.validStages = pf.validStages;
            end
            if pf.requiresOD
                sec.requiresOD = 1;
            end

            % Write custom parameter defaults
            for k = 1:numel(pf.customIndices)
                argName = pf.customNames{k};
                val = pf.argDefaults{pf.customIndices(k)};
                sec.(argName) = val;
            end

            ini.add(secName, sec);
            ini.write();

            % Clear cached configs so next lookup sees the new entry
            pf2_base.PipelineFunction.clearFunctionConfigCache();
            pf2_base.Pipeline.loadFuncConfig(true);

            fprintf('Registered function: %s\n', secName);
        end
    end

    methods (Static, Hidden)
        function clearFunctionConfigCache()
        % CLEARFUNCTIONCONFIGCACHE Reset cached function config.
        %
        % Forces the next lookupFunctionMeta call to re-read from disk.
        % Called after register() modifies the config file.

            pf2_base.PipelineFunction.lookupFunctionMeta('__clear_cache__');
        end

        function m = specialArgMap()
        % SPECIALARGMAP Persistent map from arg name to uint8 type enum.

            persistent argMap
            if isempty(argMap)
                argMap = containers.Map(...
                    {'x', 'fs', 'fTime', 'fchMask', 'ftimeChMask', ...
                     'fChannelNumbers', 'fChannelSD', 'fProbeInfo', ...
                     'fMarkers', 'fNIRstruct', 'fAux', 'fAmbient'}, ...
                    {uint8(1), uint8(2), uint8(3), uint8(4), uint8(5), ...
                     uint8(6), uint8(7), uint8(8), uint8(9), uint8(10), ...
                     uint8(11), uint8(12)});
            end
            m = argMap;
        end

        function [displayName, desc, stages, reqOD] = lookupFunctionMeta(funcName)
        % LOOKUPFUNCTIONMETA Look up function metadata from the config.

            displayName = '';
            desc = '';
            stages = [];
            reqOD = false;

            try
                persistent funcCfg
                if strcmp(funcName, '__clear_cache__')
                    funcCfg = [];
                    return
                end
                if isempty(funcCfg)
                    funcCfg = pf2_base.PipelineFunction.loadFunctionConfig();
                end
                if isfield(funcCfg, funcName)
                    sec = funcCfg.(funcName);
                    if isfield(sec, 'Name')
                        displayName = sec.Name;
                        if iscell(displayName), displayName = displayName{1}; end
                        displayName = strrep(displayName, '''', '');
                    end
                    if isfield(sec, 'Description')
                        desc = sec.Description;
                        if iscell(desc), desc = desc{1}; end
                        desc = strrep(desc, '''', '');
                    end
                    if isfield(sec, 'validStages')
                        stages = sec.validStages;
                        if ischar(stages) || isstring(stages)
                            stages = str2num(stages); %#ok<ST2NM>
                        end
                    end
                    if isfield(sec, 'requiresOD')
                        val = sec.requiresOD;
                        reqOD = isnumeric(val) && val == 1;
                    end
                end
            catch
                % Config not available — return defaults
            end
        end

        function cfg = loadFunctionConfig()
        % LOADFUNCTIONCONFIG Load function definitions from config or global.

            cfg = struct();
            global PF2
            if ~isempty(PF2) && isfield(PF2, 'myFunctions') && isfield(PF2.myFunctions, 'cfg')
                for i = 1:length(PF2.myFunctions.cfg.Sections)
                    secName = PF2.myFunctions.cfg.Sections{i};
                    cfg.(secName) = PF2.myFunctions.cfg.(secName);
                end
                return
            end
            try
                rootPath = pf2_base.pf2_defaultRootPath();
                cfgPath = fullfile(rootPath, 'prefs', 'pf2_functions_default.cfg');
                ini = pf2_base.external.INI('File', cfgPath);
                ini.read();
                for i = 1:length(ini.Sections)
                    secName = ini.Sections{i};
                    cfg.(secName) = ini.(secName);
                end
            catch
            end
        end

        function [argNames, outputNames] = parseFunctionLine(srcPath)
        % PARSEFUNCTIONLINE Parse the function signature from a .m source file.
        %
        %   [argNames, outputNames] = pf2_base.PipelineFunction.parseFunctionLine(path)
        %
        % Reads the file line by line, skipping comments and blanks,
        % to find the first 'function' declaration. Handles '...'
        % continuation lines.

            fid = fopen(srcPath, 'r');
            if fid == -1
                error('pf2:PipelineFunction:cantRead', ...
                    'Cannot open file: %s', srcPath);
            end
            cleanupObj = onCleanup(@() fclose(fid));

            funcLine = '';
            while ~feof(fid)
                line = fgetl(fid);
                if ~ischar(line), continue; end
                stripped = strtrim(line);
                if isempty(stripped), continue; end
                if stripped(1) == '%', continue; end

                % Check for 'function' keyword
                if startsWith(stripped, 'function') && ...
                        (length(stripped) == 8 || ~isletter(stripped(9)))
                    funcLine = stripped;
                    % Handle continuation lines
                    while endsWith(strtrim(funcLine), '...')
                        funcLine = funcLine(1:end-3);
                        nextLine = fgetl(fid);
                        if ischar(nextLine)
                            funcLine = [funcLine, strtrim(nextLine)]; %#ok<AGROW>
                        end
                    end
                    break
                end
            end

            if isempty(funcLine)
                error('pf2:PipelineFunction:noFuncLine', ...
                    'No function declaration found in: %s', srcPath);
            end

            % Strip 'function' keyword
            funcLine = strtrim(funcLine(9:end));

            % Split on '=' for outputs
            eqIdx = find(funcLine == '=', 1);
            if isempty(eqIdx)
                outStr = '';
                rest = funcLine;
            else
                outStr = strtrim(funcLine(1:eqIdx-1));
                rest = strtrim(funcLine(eqIdx+1:end));
            end

            % Parse outputs
            if isempty(outStr)
                outputNames = {'x'};
            else
                outStr = strrep(outStr, '[', '');
                outStr = strrep(outStr, ']', '');
                parts = strsplit(strtrim(outStr), {',',' '});
                outputNames = cellfun(@strtrim, parts, 'UniformOutput', false);
                outputNames = outputNames(~cellfun(@isempty, outputNames));
            end

            % Parse arguments from parenthesized list
            parenOpen = find(rest == '(', 1);
            parenClose = find(rest == ')', 1, 'last');
            if isempty(parenOpen)
                argNames = {};
            else
                if isempty(parenClose)
                    argStr = rest(parenOpen+1:end);
                else
                    argStr = rest(parenOpen+1:parenClose-1);
                end
                argStr = strtrim(argStr);
                if isempty(argStr)
                    argNames = {};
                else
                    parts = strsplit(argStr, {',',' '});
                    argNames = cellfun(@strtrim, parts, 'UniformOutput', false);
                    argNames = argNames(~cellfun(@isempty, argNames));
                end
            end
        end

        function tokens = tokenizeArgs(argStr)
        % TOKENIZEARGS Bracket-and-quote-aware comma splitter.
        %
        %   tokens = pf2_base.PipelineFunction.tokenizeArgs('x,1,[2,3],''hi''')
        %
        % Splits on commas only at depth 0 and outside string literals.

            argStr = strtrim(char(argStr));
            tokens = {};
            depth = 0;
            inStr = false;
            start = 1;

            for i = 1:length(argStr)
                ch = argStr(i);

                if inStr
                    if ch == ''''
                        % Check for escaped quote ''
                        if i < length(argStr) && argStr(i+1) == ''''
                            % Skip next char (escaped quote)
                            continue
                        else
                            inStr = false;
                        end
                    end
                    continue
                end

                switch ch
                    case ''''
                        inStr = true;
                    case {'(', '[', '{'}
                        depth = depth + 1;
                    case {')', ']', '}'}
                        depth = max(0, depth - 1);
                    case ','
                        if depth == 0
                            tokens{end+1} = strtrim(argStr(start:i-1)); %#ok<AGROW>
                            start = i + 1;
                        end
                end
            end

            % Last token
            lastToken = strtrim(argStr(start:end));
            if ~isempty(lastToken)
                tokens{end+1} = lastToken;
            end
        end

        function val = parseToken(token)
        % PARSETOKEN Convert a call-string token to a MATLAB value.
        %
        %   val = pf2_base.PipelineFunction.parseToken('0.1')   % → 0.1
        %   val = pf2_base.PipelineFunction.parseToken('true')  % → true
        %   val = pf2_base.PipelineFunction.parseToken('''hi''') % → 'hi'
        %   val = pf2_base.PipelineFunction.parseToken('[]')    % → []

            token = strtrim(char(token));

            % Empty array
            if strcmp(token, '[]')
                val = [];
                return
            end

            % Boolean
            if strcmp(token, 'true')
                val = true;
                return
            end
            if strcmp(token, 'false')
                val = false;
                return
            end

            % String literal
            if length(token) >= 2 && token(1) == '''' && token(end) == ''''
                inner = token(2:end-1);
                val = strrep(inner, '''''', '''');
                return
            end

            % Numeric scalar
            num = str2double(token);
            if ~isnan(num)
                val = num;
                return
            end

            % Array literal [1,2,3]
            if token(1) == '['
                try
                    val = eval(token);
                    return
                catch
                end
            end

            % Fallback: keep as char (variable name reference)
            val = token;
        end
    end
end
