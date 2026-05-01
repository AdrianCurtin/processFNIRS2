classdef PipelineModel < handle
% PIPELINEMODEL Reactive handle wrapper around a value Pipeline.
%
% PipelineModel holds a value-class pf2_base.Pipeline (RawPipeline or
% OxyPipeline) inside a handle so that:
%   - Editor / GUI components can listen for change notifications
%     (the 'PipelineChanged' event fires after every mutation).
%   - Snapshots can be pushed onto an undo stack so the user can revert.
%
% The model is intentionally thin: each mutating method calls the
% corresponding value-class method on the wrapped Pipeline, captures
% the resulting new Pipeline, and notifies listeners.
%
% Syntax:
%   m = pf2_base.PipelineModel(pipeline)
%   m.setParam(stepIdx, paramName, value)
%   m.addStep(funcNameOrPF, varargin)
%   m.removeStep(stepIdx)
%   m.moveStep(fromIdx, toIdx)
%   m.swapStep(stepIdx, funcNameOrPF, varargin)
%   m.resetParam(stepIdx, paramName)   % revert to original cfg default
%   m.undo()
%   m.redo()
%
% Events:
%   PipelineChanged - fired after any mutation. Event data is a
%                     pf2_base.PipelineChangedEventData struct with
%                     fields .kind ('setParam'|'addStep'|'removeStep'|...)
%                     and .args (cell of operation arguments).
%
% Example:
%   p  = pf2_base.RawPipeline('test');
%   p  = p.add('pf2_Intensity2OD');
%   m  = pf2_base.PipelineModel(p);
%   lh = listener(m, 'PipelineChanged', @(s,e) disp('changed!'));
%   m.addStep('pf2_lpf', 'freq_cut', 0.05);
%   m.undo();   % reverts the addStep
%
% See also: pf2_base.Pipeline, pf2_base.RawPipeline, pf2_base.OxyPipeline

    properties (SetAccess = private)
        % Current pipeline. Read-only externally; mutate via the model's methods.
        Pipeline
    end

    properties (Access = private)
        UndoStack     cell = {}
        RedoStack     cell = {}
        MaxStackDepth double = 100
    end

    events
        PipelineChanged
    end

    methods
        function obj = PipelineModel(pipeline)
            if nargin < 1 || ~isa(pipeline, 'pf2_base.Pipeline')
                error('pf2:PipelineModel:badInput', ...
                    'PipelineModel requires a pf2_base.Pipeline (or subclass).');
            end
            obj.Pipeline = pipeline;
        end

        % ------------------------------------------------------------
        %  Mutating operations
        % ------------------------------------------------------------

        function setParam(obj, stepIdx, paramName, value)
            obj.pushUndo();
            obj.Pipeline = obj.Pipeline.setParam(stepIdx, paramName, value);
            obj.emitChange('setParam', {stepIdx, paramName, value});
        end

        function addStep(obj, funcNameOrPF, varargin)
            obj.pushUndo();
            obj.Pipeline = obj.Pipeline.add(funcNameOrPF, varargin{:});
            obj.emitChange('addStep', [{funcNameOrPF}, varargin]);
        end

        function insertStep(obj, atIdx, funcNameOrPF, varargin)
            obj.pushUndo();
            obj.Pipeline = obj.Pipeline.insert(atIdx, funcNameOrPF, varargin{:});
            obj.emitChange('insertStep', [{atIdx, funcNameOrPF}, varargin]);
        end

        function removeStep(obj, idxOrName)
            obj.pushUndo();
            obj.Pipeline = obj.Pipeline.remove(idxOrName);
            obj.emitChange('removeStep', {idxOrName});
        end

        function moveStep(obj, fromIdx, toIdx)
            obj.pushUndo();
            n = obj.Pipeline.numSteps();
            if fromIdx < 1 || fromIdx > n || toIdx < 1 || toIdx > n
                error('pf2:PipelineModel:badIndex', ...
                    'moveStep indices out of range.');
            end
            steps = obj.Pipeline.steps;
            stp = steps{fromIdx};
            steps(fromIdx) = [];
            % Adjust toIdx if removing fromIdx shifted later indices
            if toIdx > fromIdx, toIdx = toIdx - 1; end
            steps = [steps(1:toIdx-1), {stp}, steps(toIdx:end)];
            % Build a new Pipeline preserving subclass type
            newP = feval(class(obj.Pipeline), obj.Pipeline.name, ...
                'Description', obj.Pipeline.description);
            newP = pf2_base.PipelineModel.replaceSteps(newP, steps);
            obj.Pipeline = newP;
            obj.emitChange('moveStep', {fromIdx, toIdx});
        end

        function swapStep(obj, idxOrName, funcNameOrPF, varargin)
            obj.pushUndo();
            obj.Pipeline = obj.Pipeline.swapStep(idxOrName, funcNameOrPF, varargin{:});
            obj.emitChange('swapStep', [{idxOrName, funcNameOrPF}, varargin]);
        end

        function resetParam(obj, stepIdx, paramName)
        % RESETPARAM Revert a parameter to its original cfg default.
        %
        % Looks up the current cfg default for the step's function +
        % paramName, and overwrites the in-pipeline value.

            step = obj.Pipeline.getStep(stepIdx);
            cfg = pf2_base.Pipeline.loadFuncConfig();
            if ~isfield(cfg, step.funcName)
                error('pf2:PipelineModel:noConfig', ...
                    'No cfg entry for ''%s''; cannot determine default.', step.funcName);
            end
            sec = cfg.(step.funcName);
            if ~isfield(sec, paramName)
                error('pf2:PipelineModel:noDefault', ...
                    'No default in cfg for parameter ''%s''.', paramName);
            end
            obj.setParam(stepIdx, paramName, sec.(paramName));
        end

        % ------------------------------------------------------------
        %  Undo / Redo
        % ------------------------------------------------------------

        function tf = canUndo(obj)
            tf = ~isempty(obj.UndoStack);
        end

        function tf = canRedo(obj)
            tf = ~isempty(obj.RedoStack);
        end

        function undo(obj)
            if ~obj.canUndo()
                return
            end
            obj.RedoStack{end+1} = obj.Pipeline;
            obj.Pipeline = obj.UndoStack{end};
            obj.UndoStack(end) = [];
            obj.emitChange('undo', {});
        end

        function redo(obj)
            if ~obj.canRedo()
                return
            end
            obj.UndoStack{end+1} = obj.Pipeline;
            obj.Pipeline = obj.RedoStack{end};
            obj.RedoStack(end) = [];
            obj.emitChange('redo', {});
        end

        function clearHistory(obj)
            obj.UndoStack = {};
            obj.RedoStack = {};
        end
    end

    methods (Access = private)
        function pushUndo(obj)
            obj.UndoStack{end+1} = obj.Pipeline;
            if numel(obj.UndoStack) > obj.MaxStackDepth
                obj.UndoStack(1) = [];
            end
            obj.RedoStack = {};  % any new action invalidates redo history
        end

        function emitChange(obj, kind, args)
            ed = pf2_base.PipelineChangedEventData(kind, args);
            notify(obj, 'PipelineChanged', ed);
        end
    end

    methods (Static, Access = private)
        function p = replaceSteps(p, steps)
        % Helper to set the protected `steps` of a Pipeline subclass instance.
        % Uses Pipeline.fromSteps to keep things in the public API.
            cls = class(p);
            base = pf2_base.Pipeline.fromSteps(p.name, steps);
            % Coerce to the right subclass
            switch cls
                case 'pf2_base.RawPipeline'
                    out = pf2_base.RawPipeline(base.name, 'Description', p.description);
                case 'pf2_base.OxyPipeline'
                    out = pf2_base.OxyPipeline(base.name, 'Description', p.description);
                otherwise
                    out = pf2_base.Pipeline(base.name, 'Description', p.description);
            end
            % Use protected setter via fromSteps trick: build, then assign steps.
            % Since `steps` is SetAccess=protected, we can't write directly here.
            % Workaround: re-add each step (PipelineFunction objects) via add().
            for k = 1:numel(steps)
                out = out.add(steps{k});
            end
            p = out;
        end
    end
end
