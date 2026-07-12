classdef (ConstructOnLoad) PipelineChangedEventData < event.EventData
% PIPELINECHANGEDEVENTDATA Event data for PipelineModel mutations.
%
% Carries information about the operation that caused the change so that
% UI listeners can respond selectively (e.g. only refresh the affected
% step rather than the whole pipeline view).

    properties
        kind char  % 'setParam' | 'addStep' | 'insertStep' | 'removeStep' |
                   % 'moveStep' | 'swapStep' | 'undo' | 'redo'
        args cell  % operation arguments, matching the model method signature
    end

    methods
        function obj = PipelineChangedEventData(kind, args)
            obj.kind = char(kind);
            if nargin < 2 || isempty(args)
                obj.args = {};
            else
                obj.args = args;
            end
        end
    end
end
