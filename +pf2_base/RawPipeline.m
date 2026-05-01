classdef RawPipeline < pf2_base.Pipeline
% RAWPIPELINE Pipeline specialized for Stage 1 (raw intensity to OD)
%
% Extends Pipeline with raw-stage awareness. The toMethod() output is
% compatible with processStageRaw2OD.
%
% Syntax:
%   p = pf2_base.RawPipeline(name)
%   p = pf2_base.RawPipeline(name, 'Description', desc)
%
% Example:
%   raw = pf2_base.RawPipeline('myRaw');
%   raw = raw.add('pf2_Intensity2OD');
%   raw = raw.add('pf2_MotionCorrectTDDR');
%   m = raw.toMethod();
%   % m is ready for processStageRaw2OD
%
% See also: pf2_base.Pipeline, pf2_base.OxyPipeline,
%           pf2_base.fnirs.processStageRaw2OD

    methods
        function obj = RawPipeline(name, varargin)
        % Constructor.

            if nargin == 0
                name = '';
            end
            obj@pf2_base.Pipeline(name, varargin{:});
        end

        function tf = hasIntensity2OD(obj)
        % HASINTENSITY2OD Check if the pipeline includes an Intensity2OD step.

            tf = false;
            for k = 1:numel(obj.steps)
                if obj.steps{k}.isIntensity2OD
                    tf = true;
                    return
                end
            end
        end

        function out = run(obj, data, varargin)
        % RUN Execute the raw pipeline on a data struct via processFNIRS2.
        %
        %   out = p.run(data)
        %   out = p.run(data, 'Context', ctx)        % use a custom context
        %   out = p.run(data, 'IncludeOxy', false)   % default: false (None)
        %
        % Injects this pipeline as the raw method, leaves the oxy stage as
        % 'None'. Stage 1 (intensity→OD) runs your pipeline; Stage 2
        % (Beer-Lambert) runs with current DPF/baseline settings; Stage 3
        % is a no-op. Returns the standard processFNIRS2 output struct.

            ip = inputParser;
            ip.addParameter('Context',    [], @(x) isempty(x) || isa(x, 'pf2_base.ProcessingContext'));
            ip.addParameter('IncludeOxy', false, @islogical);
            ip.parse(varargin{:});

            if isempty(ip.Results.Context)
                pf2_base.RawPipeline.warmupSetFDevice(data);
                ctx = pf2_base.ProcessingContext.fromGlobals();
            else
                ctx = ip.Results.Context;
            end

            method = obj.toMethod();
            if isempty(method.name) || strcmp(method.name, ''), method.name = 'inline_raw'; end
            ctx.rawMethod     = method;
            ctx.rawMethodName = method.name;
            if ~ip.Results.IncludeOxy
                ctx.oxyMethod     = struct('F', {{}}, 'name', 'None');
                ctx.oxyMethodName = 'None';
            end

            out = processFNIRS2(data, 'Context', ctx);
        end
    end

    methods (Static, Hidden)
        function warmupSetFDevice(data)
        % WARMUPSETFDEVICE Ensure global setF.device is populated from data.
        %
        % processFNIRS2 reads setF.device.Probe{1} unconditionally. When
        % run() is called from a fresh session (e.g. headless tests), setF
        % may be empty. We populate it from data.device.probeInfo (the
        % canonical legacy probe struct stored on the pf2.Device wrapper)
        % or from data.probeinfo if a legacy import set it.

            global setF %#ok<GVMIS>
            % Always sync setF.device to the device implied by `data` so the
            % running pipeline matches the input geometry. Skip only if data
            % carries no device hint at all.
            if isfield(data,'device') && isa(data.device, 'pf2.Device') ...
                    && ~isempty(data.device.probeInfo)
                setF.device = data.device.probeInfo;
            elseif isfield(data,'probeinfo') && ~isempty(data.probeinfo)
                setF.device = data.probeinfo;
            end
        end
    end

    methods (Static)
        function p = fromMethod(methodName)
        % FROMMETHOD Build a RawPipeline from an existing named method.
        %
        %   p = pf2_base.RawPipeline.fromMethod('x5_TDDR')

            base = pf2_base.Pipeline.fromMethod(methodName, 'raw');
            p = pf2_base.RawPipeline(base.name);
            p.description = base.description;
            p.steps = base.steps;
        end
    end
end
