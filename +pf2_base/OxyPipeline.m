classdef OxyPipeline < pf2_base.Pipeline
% OXYPIPELINE Pipeline specialized for Stage 3 (hemoglobin filtering)
%
% Extends Pipeline with ROI-aware helpers. The swapROI method finds the
% step whose output is 'ROI' and replaces it, making it easy to switch
% between ROI build strategies.
%
% Syntax:
%   p = pf2_base.OxyPipeline(name)
%   p = p.add('pf2_lpf', 'freq_cut', 0.1)
%   p = p.add('pf2_build_nanmean_ROI')
%   p = p.swapROI('pf2_build_pca_ROI', 'ComponentNumber', 2)
%
% Example:
%   oxy = pf2_base.OxyPipeline('myOxy');
%   oxy = oxy.add('pf2_lpf', 'freq_cut', 0.1);
%   oxy = oxy.add('pf2_build_nanmean_ROI');
%   oxy = oxy.swapROI('pf2_build_pca_ROI', 'ComponentNumber', 2);
%   m = oxy.toMethod();
%
% See also: pf2_base.Pipeline, pf2_base.RawPipeline,
%           pf2_base.fnirs.processStageFilterHb

    methods
        function obj = OxyPipeline(name, varargin)
        % Constructor.

            if nargin == 0
                name = '';
            end
            obj@pf2_base.Pipeline(name, varargin{:});
        end

        function tf = hasROI(obj)
        % HASROI Check if the pipeline has an ROI build step.

            tf = obj.findROI() > 0;
        end

        function obj = swapROI(obj, funcNameOrPF, varargin)
        % SWAPROI Replace the ROI build step.
        %
        %   p = p.swapROI('pf2_build_pca_ROI', 'ComponentNumber', 2)
        %   p = p.swapROI(pfObj)
        %
        % If no ROI step exists, appends the new one.

            idx = obj.findROI();
            if idx > 0
                obj = obj.swapStep(idx, funcNameOrPF, varargin{:});
            else
                obj = obj.add(funcNameOrPF, varargin{:});
            end
        end

        function obj = removeROI(obj)
        % REMOVEROI Remove the ROI build step if present.

            idx = obj.findROI();
            if idx > 0
                obj = obj.remove(idx);
            end
        end

        function out = run(obj, data, varargin)
        % RUN Execute the oxy pipeline on a data struct via processFNIRS2.
        %
        %   out = p.run(data)
        %   out = p.run(data, 'Context', ctx)
        %   out = p.run(data, 'RawMethod', 'wl_raw')   % default: 'None'
        %
        % Injects this pipeline as the oxy method. By default the raw stage
        % is set to 'None' — caller is responsible for ensuring the input
        % data either is already raw with a sensible OD interpretation OR
        % already contains processed Hb data (Stage 2 will run regardless).
        % For previews on raw data, set 'RawMethod' to a chain that includes
        % at least pf2_Intensity2OD, or use Pipeline.runFull(rawP, oxyP, data).

            ip = inputParser;
            ip.addParameter('Context',   [], @(x) isempty(x) || isa(x, 'pf2_base.ProcessingContext'));
            ip.addParameter('RawMethod', 'None', @(x) ischar(x) || isstring(x));
            ip.parse(varargin{:});

            if isempty(ip.Results.Context)
                pf2_base.RawPipeline.warmupSetFDevice(data);
                ctx = pf2_base.ProcessingContext.fromGlobals();
            else
                ctx = ip.Results.Context;
            end

            method = obj.toMethod();
            if isempty(method.name) || strcmp(method.name, ''), method.name = 'inline_oxy'; end
            ctx.oxyMethod     = method;
            ctx.oxyMethodName = method.name;

            rawName = char(ip.Results.RawMethod);
            if strcmpi(rawName, 'None')
                ctx.rawMethod     = struct('F', {{}}, 'name', 'None');
                ctx.rawMethodName = 'None';
            else
                % Look up the named raw method from the library.
                if ~isempty(ctx.rawMethodsLib) && isfield(ctx.rawMethodsLib, 'cfg') ...
                        && isfield(ctx.rawMethodsLib.cfg, rawName)
                    ctx.rawMethod = pf2_base.pf2_unpackMethod(ctx.rawMethodsLib.cfg.(rawName));
                    ctx.rawMethod.name = rawName;
                    ctx.rawMethodName  = rawName;
                else
                    error('pf2:OxyPipeline:rawMethodNotFound', ...
                        'Raw method ''%s'' not found in library.', rawName);
                end
            end

            out = processFNIRS2(data, 'Context', ctx);
        end
    end

    methods (Access = private)
        function idx = findROI(obj)
        % FINDROI Find the index of the ROI build step (0 if none).

            idx = 0;
            for k = 1:numel(obj.steps)
                if obj.steps{k}.roiOutIdx > 0
                    idx = k;
                    return
                end
            end
        end
    end

    methods (Static)
        function p = fromMethod(methodName)
        % FROMMETHOD Build an OxyPipeline from an existing named method.
        %
        %   p = pf2_base.OxyPipeline.fromMethod('takizawa_easy_lpf')

            base = pf2_base.Pipeline.fromMethod(methodName, 'oxy');
            p = pf2_base.OxyPipeline(base.name);
            p.description = base.description;
            p.steps = base.steps;
        end
    end
end
