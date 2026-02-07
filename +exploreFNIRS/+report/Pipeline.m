classdef Pipeline < handle
% PIPELINE Orchestrator for reproducible fNIRS report generation
%
% Configures and runs a complete analysis pipeline on an Experiment
% object, collecting figures, tables, and statistics for report output.
%
% Syntax:
%   pipe = exploreFNIRS.report.Pipeline(experiment)
%   pipe.addStep('lme', 'Biomarkers', {'HbO'}, 'Channels', 1:16)
%   pipe.addStep('temporal', 'Biomarkers', {'HbO','HbR'})
%   pipe.run()
%   exploreFNIRS.report.generate(pipe, 'output/report')
%
% Inputs:
%   experiment - Experiment object (grouped and aggregated)
%
% Example:
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.groupby({'Group','Condition'});
%   ex.aggregate();
%
%   pipe = exploreFNIRS.report.Pipeline(ex);
%   pipe.addStep('lme', 'Biomarkers', {'HbO'}, 'Channels', 1:16);
%   pipe.addStep('temporal', 'Biomarkers', {'HbO'});
%   pipe.addStep('bar', 'Biomarker', 'HbO');
%   pipe.addStep('demographics', 'Variables', {'Age','Sex'});
%   pipe.run();
%
%   exploreFNIRS.report.generate(pipe, 'output/report');
%
% See also: exploreFNIRS.report.generate, exploreFNIRS.core.Experiment

    properties
        % Experiment object
        experiment

        % Analysis configuration
        config

        % Pipeline steps (cell array of structs)
        steps

        % Results after run
        figures    % Struct of figure handles
        tables     % Struct of MATLAB tables
        stats      % Struct of formatted stat strings
        results    % Struct of raw results (e.g., LME model objects)

        % State
        isRun
    end

    methods

        function obj = Pipeline(experiment, varargin)
        % PIPELINE Create a new report pipeline
        %
        %   pipe = Pipeline(experiment)
        %   pipe = Pipeline(experiment, 'Title', 'My Study')

            if ~isa(experiment, 'exploreFNIRS.core.Experiment')
                error('exploreFNIRS:report:Pipeline', ...
                    'Input must be an Experiment object');
            end

            ip = inputParser;
            addParameter(ip, 'Title', '', @ischar);
            addParameter(ip, 'Author', '', @ischar);
            addParameter(ip, 'Date', datestr(now, 'yyyy-mm-dd'), @ischar);
            parse(ip, varargin{:});

            obj.experiment = experiment;
            obj.config = ip.Results;
            obj.steps = {};
            obj.figures = struct();
            obj.tables = struct();
            obj.stats = struct();
            obj.results = struct();
            obj.isRun = false;
        end


        function obj = addStep(obj, stepType, varargin)
        % ADDSTEP Add an analysis step to the pipeline
        %
        %   pipe.addStep('lme', 'Biomarkers', {'HbO'}, 'Channels', 1:16)
        %   pipe.addStep('temporal', 'Biomarkers', {'HbO','HbR'})
        %   pipe.addStep('bar', 'Biomarker', 'HbO')
        %   pipe.addStep('demographics', 'Variables', {'Age','Sex'})
        %   pipe.addStep('connectivity', 'Method', 'pearson')
        %   pipe.addStep('contrast', 'Channel', 1)
        %
        % Valid step types:
        %   'lme'          - LME analysis (plotLME)
        %   'temporal'     - Temporal plot
        %   'bar'          - Bar chart
        %   'demographics' - Demographics Table 1
        %   'connectivity' - Connectivity analysis
        %   'contrast'     - Contrast table (requires prior 'lme' step)
        %   'anova'        - ANOVA table (requires prior 'lme' step)

            validTypes = {'lme', 'temporal', 'bar', 'demographics', ...
                'connectivity', 'contrast', 'anova'};
            if ~ismember(lower(stepType), validTypes)
                error('exploreFNIRS:report:Pipeline:addStep', ...
                    'Unknown step type: %s. Valid types: %s', ...
                    stepType, strjoin(validTypes, ', '));
            end

            step = struct();
            step.type = lower(stepType);
            step.args = varargin;
            step.name = generateStepName(step.type, length(obj.steps) + 1);

            obj.steps{end+1} = step;
            obj.isRun = false;

            fprintf('Added step [%d] %s: %s\n', length(obj.steps), ...
                step.type, step.name);
        end


        function obj = run(obj)
        % RUN Execute all pipeline steps
        %
        %   pipe.run()

            fprintf('Running pipeline (%d steps)...\n', length(obj.steps));
            t0 = tic;

            for i = 1:length(obj.steps)
                step = obj.steps{i};
                fprintf('\n--- Step %d: %s ---\n', i, step.type);

                try
                    runStep(obj, step);
                catch ME
                    warning('Step %d (%s) failed: %s', i, step.type, ME.message);
                end
            end

            elapsed = toc(t0);
            obj.isRun = true;
            fprintf('\nPipeline complete (%.1f seconds)\n', elapsed);
            fprintf('  Figures: %d\n', length(fieldnames(obj.figures)));
            fprintf('  Tables: %d\n', length(fieldnames(obj.tables)));
            fprintf('  Stats: %d\n', length(fieldnames(obj.stats)));
        end


        function s = summary(obj)
        % SUMMARY Return pipeline summary as struct
        %
        %   s = pipe.summary()

            s.title = obj.config.Title;
            s.author = obj.config.Author;
            s.date = obj.config.Date;
            s.nSteps = length(obj.steps);
            s.stepTypes = cellfun(@(x) x.type, obj.steps, 'UniformOutput', false);
            s.isRun = obj.isRun;
            s.nFigures = length(fieldnames(obj.figures));
            s.nTables = length(fieldnames(obj.tables));
            s.nStats = length(fieldnames(obj.stats));

            if nargout == 0
                fprintf('\nPipeline Summary\n');
                fprintf('  Title: %s\n', s.title);
                fprintf('  Steps: %d\n', s.nSteps);
                fprintf('  Run: %s\n', mat2str(s.isRun));
                if s.isRun
                    fprintf('  Figures: %d, Tables: %d, Stats: %d\n', ...
                        s.nFigures, s.nTables, s.nStats);
                end
                clear s;
            end
        end

    end

    methods (Access = private)

        function runStep(obj, step)
            ex = obj.experiment;

            switch step.type
                case 'lme'
                    args = [step.args, {'Visible', 'off'}];
                    [fig, res] = ex.plotLME(args{:});
                    applyReportStyle(fig);
                    obj.figures.(step.name) = fig;
                    obj.results.(step.name) = res;

                    % Auto-generate formatted stats per term
                    if ~isempty(res.anova_pval) && height(res.anova_pval) > 0
                        terms = res.anova_pval.Properties.VariableNames;
                        for t = 1:length(terms)
                            statKey = sprintf('%s_%s', step.name, terms{t});
                            obj.stats.(statKey) = exploreFNIRS.report.formatStats( ...
                                res, 'Type', 'anova', 'Term', terms{t});
                        end
                    end

                case 'temporal'
                    args = [step.args, {'Visible', 'off'}];
                    fig = ex.plotTemporal(args{:});
                    applyReportStyle(fig);
                    obj.figures.(step.name) = fig;

                case 'bar'
                    args = [step.args, {'Visible', 'off'}];
                    fig = ex.plotBar(args{:});
                    applyReportStyle(fig);
                    obj.figures.(step.name) = fig;

                case 'demographics'
                    T = exploreFNIRS.report.demographicsTable(ex, step.args{:});
                    obj.tables.(step.name) = T;

                case 'connectivity'
                    res = ex.connectivity(step.args{:});
                    obj.results.(step.name) = res;
                    T = exploreFNIRS.report.connectivitySummary(res);
                    obj.tables.(step.name) = T;

                case 'contrast'
                    % Find most recent LME results
                    lmeKey = findLMEResult(obj);
                    if isempty(lmeKey)
                        warning('No LME results found. Add an ''lme'' step before ''contrast''.');
                        return;
                    end
                    res = obj.results.(lmeKey);
                    T = exploreFNIRS.report.contrastTable(res, step.args{:});
                    obj.tables.(step.name) = T;

                case 'anova'
                    lmeKey = findLMEResult(obj);
                    if isempty(lmeKey)
                        warning('No LME results found. Add an ''lme'' step before ''anova''.');
                        return;
                    end
                    res = obj.results.(lmeKey);
                    T = exploreFNIRS.report.anovaTable(res, step.args{:});
                    obj.tables.(step.name) = T;
            end
        end

    end
end


%% Local helpers

function name = generateStepName(stepType, idx)
    name = sprintf('%s_%d', stepType, idx);
end


function key = findLMEResult(obj)
    flds = fieldnames(obj.results);
    key = '';
    for i = length(flds):-1:1
        if startsWith(flds{i}, 'lme_')
            key = flds{i};
            return;
        end
    end
end


function applyReportStyle(fig)
% Force white background and publication styling on a figure
% Ensures report figures look correct regardless of MATLAB dark mode.
    if isempty(fig) || ~isvalid(fig)
        return;
    end

    set(fig, 'Color', 'w');

    % Apply publication style
    sty = pf2_base.plot.PlotStyle.getPublication();
    sty.applyToFigure(fig);

    exploreFNIRS.report.forceWhiteMode(fig);
end
