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
