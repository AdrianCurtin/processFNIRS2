classdef ProcessingContext < handle
    % PROCESSINGCONTEXT Encapsulates all processing settings for fNIRS analysis
    %
    % ProcessingContext provides an alternative to global variables (PF2, setF)
    % for managing processing configuration. It enables:
    %   - Isolated testing without global state pollution
    %   - Parallel processing with different settings per worker
    %   - Reproducible analyses by saving/loading contexts
    %   - Explicit dependency injection into processing functions
    %
    % For backward compatibility, functions that accept a Context parameter
    % will fall back to reading from globals when no context is provided.
    %
    % Syntax:
    %   ctx = ProcessingContext()           % Create with defaults
    %   ctx = ProcessingContext.fromGlobals() % Create from current global state
    %
    % Properties:
    %   DPF Settings:
    %     dpfMode       - 'None', 'Fixed', or 'Calc' (default: 'Calc')
    %     dpfFixedValue - Fixed DPF value (default: 5.93)
    %     subjectAge    - Age for DPF calculation (default: 25)
    %
    %   Baseline Settings:
    %     baselineStartTime - Baseline start in seconds (default: 0)
    %     baselineLength    - Baseline duration in seconds (default: 10)
    %     useAbsoluteTime   - Use absolute vs relative time (default: false)
    %     dirtyBaseline     - Use entire signal as baseline (default: false)
    %
    %   Method Configuration:
    %     rawMethodName   - Name of raw processing method
    %     rawMethod       - Unpacked raw method struct
    %     oxyMethodName   - Name of oxy processing method
    %     oxyMethod       - Unpacked oxy method struct
    %     rawMethodsLib   - Library of available raw methods
    %     oxyMethodsLib   - Library of available oxy methods
    %
    %   Device Configuration:
    %     device          - Device configuration struct (from setF.device)
    %
    %   Quality Control:
    %     rejectLevel     - Channel rejection threshold (default: 0)
    %     processRejected - Process rejected channels anyway (default: false)
    %
    %   Output Options:
    %     outputLegacyMarkers - Output markers in legacy format (default: false)
    %
    % Example:
    %   % Create context for testing
    %   ctx = ProcessingContext();
    %   ctx.dpfMode = 'Fixed';
    %   ctx.dpfFixedValue = 6.0;
    %   ctx.baselineLength = 5;
    %   result = processFNIRS2(data, 'Context', ctx);
    %
    %   % Parallel processing with different ages
    %   parfor i = 1:numSubjects
    %       ctx = ProcessingContext.fromGlobals();
    %       ctx.subjectAge = ages(i);
    %       results{i} = processFNIRS2(data{i}, 'Context', ctx);
    %   end
    %
    %   % Save context for reproducibility
    %   ctx = ProcessingContext.fromGlobals();
    %   save('analysis_settings.mat', 'ctx');
    %
    % See also: processFNIRS2, pf2_base.pf2_initialize

    properties
        % DPF (Differential Pathlength Factor) settings
        dpfMode (1,:) char {mustBeMember(dpfMode, {'None', 'Fixed', 'Calc'})} = 'Calc'
        dpfFixedValue (1,1) double {mustBePositive} = 5.93
        subjectAge (1,1) double {mustBePositive} = 25

        % Baseline settings
        baselineStartTime (1,1) double = 0
        baselineLength (1,1) double {mustBeNonnegative} = 10
        useAbsoluteTime (1,1) logical = false
        windowStartTime (1,1) double = 0
        dirtyBaseline (1,1) logical = false

        % Method configuration
        rawMethodName (1,:) char = 'None'
        rawMethod struct = struct()
        oxyMethodName (1,:) char = 'None'
        oxyMethod struct = struct()

        % Method libraries (loaded from config files)
        rawMethodsLib struct = struct()
        oxyMethodsLib struct = struct()

        % Device configuration
        device struct = struct()

        % Quality control
        rejectLevel (1,1) double {mustBeInRange(rejectLevel, 0, 1)} = 0
        processRejected (1,1) logical = false

        % Output options
        outputLegacyMarkers (1,1) logical = false

        % Paths
        rootPath (1,:) char = ''
    end

    methods
        function obj = ProcessingContext()
            % PROCESSINGCONTEXT Create a new processing context with defaults
            %
            % The context is initialized with sensible defaults. Use
            % fromGlobals() to create a context matching current global state.

            obj.rootPath = pf2_base.pf2_defaultRootPath();
        end

        function setRawMethod(obj, methodName)
            % SETRAWMETHOD Set the raw processing method by name
            %
            % Syntax:
            %   ctx.setRawMethod('x5_TDDR')
            %
            % The method must exist in rawMethodsLib.

            if isempty(obj.rawMethodsLib) || ~isfield(obj.rawMethodsLib, 'cfg')
                error('ProcessingContext:NoMethodsLoaded', ...
                    'No raw methods library loaded. Use fromGlobals() or loadMethods().');
            end

            if ~ismember(methodName, obj.rawMethodsLib.cfg.Sections)
                error('ProcessingContext:InvalidMethod', ...
                    'Raw method ''%s'' not found. Available: %s', ...
                    methodName, strjoin(obj.rawMethodsLib.cfg.Sections, ', '));
            end

            obj.rawMethodName = methodName;
            obj.rawMethod = pf2_base.pf2_unpackMethod(obj.rawMethodsLib.cfg.(methodName));
            obj.rawMethod.name = methodName;
        end

        function setOxyMethod(obj, methodName)
            % SETOXYMETHOD Set the oxy processing method by name
            %
            % Syntax:
            %   ctx.setOxyMethod('takizawa_easy')
            %
            % The method must exist in oxyMethodsLib.

            if isempty(obj.oxyMethodsLib) || ~isfield(obj.oxyMethodsLib, 'cfg')
                error('ProcessingContext:NoMethodsLoaded', ...
                    'No oxy methods library loaded. Use fromGlobals() or loadMethods().');
            end

            if ~ismember(methodName, obj.oxyMethodsLib.cfg.Sections)
                error('ProcessingContext:InvalidMethod', ...
                    'Oxy method ''%s'' not found. Available: %s', ...
                    methodName, strjoin(obj.oxyMethodsLib.cfg.Sections, ', '));
            end

            obj.oxyMethodName = methodName;
            obj.oxyMethod = pf2_base.pf2_unpackMethod(obj.oxyMethodsLib.cfg.(methodName));
            obj.oxyMethod.name = methodName;
        end

        function applyToGlobals(obj)
            % APPLYTOGLOBALS Write context settings back to global variables
            %
            % This is useful when you've configured a context and want to
            % use it with GUI functions that read from globals.
            %
            % Syntax:
            %   ctx.applyToGlobals()

            global PF2 setF

            % Ensure initialized
            if ~isfield(PF2, 'myRawMethods')
                pf2_base.pf2_initialize();
            end

            % DPF settings
            PF2.dpf_mode = obj.dpfMode;
            PF2.curDPF_fixed = obj.dpfFixedValue;
            PF2.curDPF_age = obj.subjectAge;

            % Baseline settings
            PF2.baseline.startTime = obj.baselineStartTime;
            PF2.baseline.blLength = obj.baselineLength;
            PF2.baseline.useAbsoluteTime = obj.useAbsoluteTime;
            PF2.baseline.windowStartTime = obj.windowStartTime;

            % Quality control
            PF2.RejectLevel = obj.rejectLevel;

            % Output options
            PF2.OutputLegacyMarkers = obj.outputLegacyMarkers;

            % Methods (if set)
            if ~isempty(obj.rawMethod) && isfield(obj.rawMethod, 'name')
                PF2.stageRawMethod = obj.rawMethod;
            end
            if ~isempty(obj.oxyMethod) && isfield(obj.oxyMethod, 'name')
                PF2.stageOxyMethod = obj.oxyMethod;
            end

            % Device
            if ~isempty(fieldnames(obj.device))
                setF.device = obj.device;
            end
        end

        function s = toStruct(obj)
            % TOSTRUCT Convert context to a plain struct for saving
            %
            % Syntax:
            %   s = ctx.toStruct();
            %   save('settings.mat', '-struct', 's');

            s = struct();
            s.contextVersion = '1.0';
            s.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
            s.dpfMode = obj.dpfMode;
            s.dpfFixedValue = obj.dpfFixedValue;
            s.subjectAge = obj.subjectAge;
            s.baselineStartTime = obj.baselineStartTime;
            s.baselineLength = obj.baselineLength;
            s.useAbsoluteTime = obj.useAbsoluteTime;
            s.windowStartTime = obj.windowStartTime;
            s.dirtyBaseline = obj.dirtyBaseline;
            s.rawMethodName = obj.rawMethodName;
            s.oxyMethodName = obj.oxyMethodName;
            s.rejectLevel = obj.rejectLevel;
            s.processRejected = obj.processRejected;
            s.outputLegacyMarkers = obj.outputLegacyMarkers;
            s.rootPath = obj.rootPath;
        end
    end

    methods (Static)
        function obj = fromGlobals()
            % FROMGLOBALS Create a ProcessingContext from current global state
            %
            % Reads PF2 and setF globals and creates a context with matching
            % settings. This is useful for:
            %   - Creating an isolated copy for parallel processing
            %   - Saving current settings for reproducibility
            %   - Starting from current settings and modifying
            %
            % Syntax:
            %   ctx = ProcessingContext.fromGlobals();
            %
            % Example:
            %   % Save current settings
            %   ctx = ProcessingContext.fromGlobals();
            %   save('my_settings.mat', 'ctx');
            %
            %   % Modify for parallel processing
            %   parfor i = 1:N
            %       ctx = ProcessingContext.fromGlobals();
            %       ctx.subjectAge = ages(i);
            %       results{i} = processFNIRS2(data{i}, 'Context', ctx);
            %   end

            global PF2 setF

            % Ensure globals are initialized
            if ~isfield(PF2, 'myRawMethods') || ~isfield(PF2, 'baseline')
                pf2_base.pf2_initialize();
            end

            obj = pf2_base.ProcessingContext();

            % DPF settings
            if isfield(PF2, 'dpf_mode')
                obj.dpfMode = PF2.dpf_mode;
            end
            if isfield(PF2, 'curDPF_fixed')
                obj.dpfFixedValue = PF2.curDPF_fixed;
            end
            if isfield(PF2, 'curDPF_age')
                obj.subjectAge = PF2.curDPF_age;
            end

            % Baseline settings
            if isfield(PF2, 'baseline')
                if isfield(PF2.baseline, 'startTime')
                    obj.baselineStartTime = PF2.baseline.startTime;
                end
                if isfield(PF2.baseline, 'blLength')
                    obj.baselineLength = PF2.baseline.blLength;
                end
                if isfield(PF2.baseline, 'useAbsoluteTime')
                    obj.useAbsoluteTime = PF2.baseline.useAbsoluteTime;
                end
                if isfield(PF2.baseline, 'windowStartTime')
                    obj.windowStartTime = PF2.baseline.windowStartTime;
                end
            end

            % Quality control
            if isfield(PF2, 'RejectLevel')
                obj.rejectLevel = PF2.RejectLevel;
            end

            % Output options
            if isfield(PF2, 'OutputLegacyMarkers')
                obj.outputLegacyMarkers = PF2.OutputLegacyMarkers;
            end

            % Method libraries
            if isfield(PF2, 'myRawMethods')
                obj.rawMethodsLib = PF2.myRawMethods;
            end
            if isfield(PF2, 'myOxyMethods')
                obj.oxyMethodsLib = PF2.myOxyMethods;
            end

            % Current methods
            if isfield(PF2, 'stageRawMethod')
                obj.rawMethod = PF2.stageRawMethod;
                if isfield(PF2.stageRawMethod, 'name')
                    obj.rawMethodName = PF2.stageRawMethod.name;
                end
            end
            if isfield(PF2, 'stageOxyMethod')
                obj.oxyMethod = PF2.stageOxyMethod;
                if isfield(PF2.stageOxyMethod, 'name')
                    obj.oxyMethodName = PF2.stageOxyMethod.name;
                end
            end

            % Paths
            if isfield(PF2, 'defaultRootPath')
                obj.rootPath = PF2.defaultRootPath;
            end

            % Device configuration
            if isstruct(setF) && isfield(setF, 'device')
                obj.device = setF.device;
            end
        end

        function obj = fromStruct(s)
            % FROMSTRUCT Create a ProcessingContext from a saved struct
            %
            % Syntax:
            %   s = load('settings.mat');
            %   ctx = ProcessingContext.fromStruct(s);

            obj = pf2_base.ProcessingContext();

            if isfield(s, 'dpfMode'), obj.dpfMode = s.dpfMode; end
            if isfield(s, 'dpfFixedValue'), obj.dpfFixedValue = s.dpfFixedValue; end
            if isfield(s, 'subjectAge'), obj.subjectAge = s.subjectAge; end
            if isfield(s, 'baselineStartTime'), obj.baselineStartTime = s.baselineStartTime; end
            if isfield(s, 'baselineLength'), obj.baselineLength = s.baselineLength; end
            if isfield(s, 'useAbsoluteTime'), obj.useAbsoluteTime = s.useAbsoluteTime; end
            if isfield(s, 'windowStartTime'), obj.windowStartTime = s.windowStartTime; end
            if isfield(s, 'dirtyBaseline'), obj.dirtyBaseline = s.dirtyBaseline; end
            if isfield(s, 'rawMethodName'), obj.rawMethodName = s.rawMethodName; end
            if isfield(s, 'oxyMethodName'), obj.oxyMethodName = s.oxyMethodName; end
            if isfield(s, 'rejectLevel'), obj.rejectLevel = s.rejectLevel; end
            if isfield(s, 'processRejected'), obj.processRejected = s.processRejected; end
            if isfield(s, 'outputLegacyMarkers'), obj.outputLegacyMarkers = s.outputLegacyMarkers; end
            if isfield(s, 'rootPath'), obj.rootPath = s.rootPath; end
        end
    end
end

function mustBeInRange(value, minVal, maxVal)
    % Custom validator for rejectLevel
    if value < minVal || value > maxVal
        error('MATLAB:validators:mustBeInRange', ...
            'Value must be between %g and %g', minVal, maxVal);
    end
end
