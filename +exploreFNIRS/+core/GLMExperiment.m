classdef GLMExperiment < exploreFNIRS.core.Experiment
% GLMEXPERIMENT Scriptable GLM wrapper extending Experiment
%
% Encapsulates the full first-level GLM workflow: processing continuous
% recordings, building design matrices, fitting per-subject GLMs, and
% packaging betas into pseudo-segments for group analysis. All Experiment
% methods (plot, stats, export, connectivity) operate on beta data after
% fit() is called.
%
% Syntax:
%   gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs)
%   gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs, 'Hierarchy', {...})
%   gx = exploreFNIRS.core.GLMExperiment(subjects)  % uses subjects{i}.blocks
%
% Inputs:
%   subjects  - {1 x S} cell array of continuous fNIRS structs
%   blockDefs - (Optional) {1 x S} cell array of block struct arrays from
%               defineBlocks. If omitted, extracted from subjects{i}.blocks.
%
% Example:
%   [subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
%   gx = exploreFNIRS.core.GLMExperiment(subjects, blockDefs);
%   gx.glm.conditions = {'Easy', 'Hard'};
%   gx.fit();
%
%   gx.groupby({'Condition'});
%   gx.aggregate();
%   fig = gx.plotBar('Biomarker', 'HbO', 'ShowIndividual', true);
%
% See also: exploreFNIRS.core.Experiment, pf2.data.blocksToEvents,
%           pf2_base.fnirs.buildDesignMatrix, pf2_base.fnirs.fitGLM,
%           pf2.data.betasToSegments

    properties
        % Source data (immutable after construction)
        subjects        % {S x 1} continuous fNIRS structs
        blockDefs       % {S x 1} block struct arrays from defineBlocks

        % GLM model settings (modify before calling fit())
        glm             % struct with GLM configuration

        % Per-subject first-level results (populated by fit())
        subjectResults  % {1 x S} struct array
    end

    properties (SetAccess = private)
        isFitted        % bool — true after successful fit()
        fitHash         % char — hash of settings at last fit() for invalidation
    end

    methods

        function obj = GLMExperiment(subjects, blockDefs, varargin)
        % GLMEXPERIMENT Create a GLMExperiment from continuous recordings
        %
        %   gx = GLMExperiment(subjects, blockDefs)
        %   gx = GLMExperiment(subjects, blockDefs, 'Hierarchy', {...})
        %   gx = GLMExperiment(subjects)  % uses subjects{i}.blocks

            % Validate subjects
            if ~iscell(subjects)
                error('exploreFNIRS:core:GLMExperiment', ...
                    'subjects must be a cell array');
            end

            % Handle optional blockDefs: if missing or if second arg is a
            % name-value string, extract .blocks from each subject
            if nargin < 2 || ischar(blockDefs) || isstring(blockDefs)
                if nargin >= 2
                    varargin = [{blockDefs}, varargin];
                end
                blockDefs = cell(size(subjects));
                for si = 1:numel(subjects)
                    if ~isfield(subjects{si}, 'blocks') || isempty(subjects{si}.blocks)
                        error('exploreFNIRS:core:GLMExperiment', ...
                            'Subject %d has no .blocks field. Call defineBlocks with ''Embed'', true first.', si);
                    end
                    blockDefs{si} = subjects{si}.blocks;
                end
            end

            if ~iscell(blockDefs)
                error('exploreFNIRS:core:GLMExperiment', ...
                    'blockDefs must be a cell array');
            end
            if length(subjects) ~= length(blockDefs)
                error('exploreFNIRS:core:GLMExperiment', ...
                    'subjects and blockDefs must have the same length');
            end

            % Pass subjects to Experiment superclass (valid fNIRS structs)
            obj@exploreFNIRS.core.Experiment(subjects, varargin{:});

            % Store source data
            obj.subjects = subjects(:);
            obj.blockDefs = blockDefs(:);

            % Default GLM settings
            obj.glm = struct( ...
                'driftOrder',        3, ...
                'driftType',         'legendre', ...
                'driftCutoff',       128, ...
                'includeDerivative', false, ...
                'includeDispersion', false, ...
                'hrf',               [], ...
                'fitMethod',         'OLS', ...
                'biomarkers',        {{'HbO', 'HbR'}}, ...
                'auxFields',         {{}}, ...
                'conditions',        {{}}, ...
                'conditionMap',      {{}}, ...
                'groupBy',           'Condition', ...
                'units',             '\beta' ...
            );

            % Beta-appropriate Experiment defaults
            obj.settings.useBaseline = false;
            obj.settings.resampleRate = 0;
            obj.settings.barBinSize = 0;

            % State
            obj.isFitted = false;
            obj.fitHash = '';
        end


        function obj = fit(obj)
        % FIT Run first-level GLM pipeline on all subjects
        %
        %   gx.fit()
        %
        % Pipeline per subject:
        %   1. Reprocess if rawMethod/oxyMethod specified
        %   2. Convert blocks to GLM events
        %   3. Build design matrix (HRF convolution, drift, derivatives)
        %   4. Fit GLM per biomarker (and optionally per aux field)
        %   5. Package betas into Experiment-compatible pseudo-segments
        %   6. Aggregate block-level behavioral data onto segments
        %
        % After fit(), obj.data contains beta pseudo-segments and all
        % inherited Experiment methods operate on beta data.

            nSubjects = length(obj.subjects);
            fprintf('=== GLMExperiment.fit(): %d subjects ===\n', nSubjects);

            % --- 1. Reprocess if methods are specified ---
            processedSubjects = obj.subjects;
            hasMethodSet = ~isempty(obj.settings.rawMethod) || ...
                           ~isempty(obj.settings.oxyMethod);
            if hasMethodSet
                % processFNIRS2 takes positional args: data, rawMethod, oxyMethod
                % Method names must come before name-value pairs
                positionalArgs = {};
                if ~isempty(obj.settings.rawMethod)
                    positionalArgs{end+1} = obj.settings.rawMethod;
                end
                if ~isempty(obj.settings.oxyMethod)
                    positionalArgs{end+1} = obj.settings.oxyMethod;
                end
                for s = 1:nSubjects
                    processedSubjects{s} = processFNIRS2( ...
                        obj.subjects{s}, positionalArgs{:});
                    fprintf('  Reprocessed %s\n', ...
                        processedSubjects{s}.info.SubjectID);
                end
            end

            % --- 2-5. Per-subject GLM fitting ---
            allSegments = {};
            results = cell(1, nSubjects);

            for s = 1:nSubjects
                d = processedSubjects{s};

                % Convert blocks -> events
                events = pf2.data.blocksToEvents(obj.blockDefs{s}, ...
                    'GroupBy', obj.glm.groupBy);

                % Build design matrix
                dmArgs = {d.time, d.fs, events, ...
                    'DriftOrder', obj.glm.driftOrder, ...
                    'DriftType', obj.glm.driftType, ...
                    'DriftCutoff', obj.glm.driftCutoff, ...
                    'IncludeDerivative', obj.glm.includeDerivative, ...
                    'IncludeDispersion', obj.glm.includeDispersion, ...
                    'IncludeConstant', true};
                if ~isempty(obj.glm.hrf)
                    dmArgs = [dmArgs, {'HRF', obj.glm.hrf}]; %#ok<AGROW>
                end
                [X, names] = pf2_base.fnirs.buildDesignMatrix(dmArgs{:});

                % Fit each biomarker
                bioResults = struct();
                for b = 1:length(obj.glm.biomarkers)
                    bio = obj.glm.biomarkers{b};
                    if isfield(d, bio)
                        bioResults.(bio) = pf2_base.fnirs.fitGLM( ...
                            d.(bio), X, names, ...
                            'Method', obj.glm.fitMethod);
                    end
                end

                % Fit auxiliary fields if requested
                for a = 1:length(obj.glm.auxFields)
                    auxName = obj.glm.auxFields{a};
                    if ~isfield(d, 'Aux') || ~isfield(d.Aux, auxName)
                        continue;
                    end
                    auxStruct = d.Aux.(auxName);
                    auxFs = 1 / median(diff(auxStruct.time));

                    % Build design matrix at Aux sampling rate
                    auxDmArgs = {auxStruct.time, auxFs, events, ...
                        'DriftOrder', obj.glm.driftOrder, ...
                        'DriftType', obj.glm.driftType, ...
                        'DriftCutoff', obj.glm.driftCutoff, ...
                        'IncludeDerivative', obj.glm.includeDerivative, ...
                        'IncludeDispersion', obj.glm.includeDispersion, ...
                        'IncludeConstant', true};
                    if ~isempty(obj.glm.hrf)
                        auxDmArgs = [auxDmArgs, {'HRF', obj.glm.hrf}]; %#ok<AGROW>
                    end
                    [Xaux, auxNames] = pf2_base.fnirs.buildDesignMatrix(auxDmArgs{:});

                    bioResults.(['Aux_' auxName]) = pf2_base.fnirs.fitGLM( ...
                        auxStruct.data, Xaux, auxNames, ...
                        'Method', obj.glm.fitMethod);
                end

                % Store per-subject results
                results{s} = struct( ...
                    'results',        bioResults, ...
                    'designMatrix',   X, ...
                    'regressorNames', {names}, ...
                    'events',         events, ...
                    'subjectID',      d.info.SubjectID);

                % Package betas -> pseudo-segments
                primaryBio = obj.glm.biomarkers{1};
                segs = pf2.data.betasToSegments( ...
                    bioResults.(primaryBio), d, ...
                    'BiomarkerResults', bioResults, ...
                    'Conditions', obj.glm.conditions, ...
                    'ConditionMap', obj.glm.conditionMap, ...
                    'Units', obj.glm.units);

                % Build ROI betas if ROI definitions present
                for k = 1:length(segs)
                    if isfield(segs{k}, 'ROI') && isfield(segs{k}.ROI, 'info')
                        segs{k} = pf2_build_nanmean_ROI(segs{k});
                    end
                end

                % Attach Aux betas to pseudo-segments
                for a = 1:length(obj.glm.auxFields)
                    auxName = obj.glm.auxFields{a};
                    auxKey = ['Aux_' auxName];
                    if ~isfield(bioResults, auxKey), continue; end
                    if ~isfield(d.Aux, auxName), continue; end

                    auxResult = bioResults.(auxKey);
                    auxStruct = d.Aux.(auxName);

                    for k = 1:length(segs)
                        condName = segs{k}.info.Condition;
                        regIdx = find(strcmp(auxResult.regressorNames, condName), 1);
                        if isempty(regIdx), continue; end

                        betaRow = auxResult.beta(regIdx, :);
                        if ~isfield(segs{k}, 'Aux')
                            segs{k}.Aux = struct();
                        end

                        % Build table format that grandAvgFNIRS expects
                        % (table with 'time' column + data columns)
                        auxTable = table([0; 1], 'VariableNames', {'time'});
                        if isfield(auxStruct, 'varNames') && ...
                                ~isempty(auxStruct.varNames)
                            vNames = auxStruct.varNames;
                        else
                            nAuxCh = length(betaRow);
                            vNames = arrayfun(@(i) sprintf('Ch%d', i), ...
                                1:nAuxCh, 'UniformOutput', false);
                        end
                        for vc = 1:length(betaRow)
                            auxTable.(vNames{vc}) = [betaRow(vc); betaRow(vc)];
                        end
                        segs{k}.Aux.(auxName) = auxTable;
                    end
                end

                % --- Aggregate block-level behavioral data ---
                for k = 1:length(segs)
                    segs{k} = aggregateBlockInfo(segs{k}, ...
                        obj.blockDefs{s}, obj.glm.groupBy);
                end

                allSegments = [allSegments, segs]; %#ok<AGROW>

                % Report fit quality
                r2 = bioResults.(primaryBio).R2;
                fprintf('  %s: mean R2=%.3f (%s), %d regressors\n', ...
                    d.info.SubjectID, mean(r2), primaryBio, length(names));
            end

            % --- 6. Replace Experiment data with beta segments ---
            obj.subjectResults = results;
            obj.data = allSegments(:);
            obj.dataTable = exploreFNIRS.dataset.buildSegmentInfoTable(obj.data);
            obj.dataTable.missingFNIRS = zeros(height(obj.dataTable), 1);

            % Reset selection/grouping state via public reset()
            obj.reset();

            % Mark as fitted
            obj.isFitted = true;
            obj.fitHash = buildFitHash(obj);

            fprintf('Fit complete: %d segments (%d subjects x %d conditions)\n', ...
                length(obj.data), nSubjects, ...
                length(obj.data) / max(nSubjects, 1));
        end


        function obj = aggregate(obj, mode)
        % AGGREGATE Auto-fit if needed, then delegate to parent
        %
        %   gx.aggregate()
        %   gx.aggregate('hierarchy')
        %
        % If GLM has not been fitted, or if settings have changed since
        % the last fit, automatically calls fit() before aggregating.
        % Reprocessing methods are temporarily cleared so the parent
        % aggregate() does not try to reprocess the beta pseudo-segments.

            needsRefit = ~obj.isFitted || ...
                ~strcmp(obj.fitHash, buildFitHash(obj));
            if needsRefit
                % Save groupby state — fit() calls reset() which clears it
                savedGroupByVars = obj.getGroupByVars();
                obj.fit();
                % Re-apply groupby if it was set before
                if ~isempty(savedGroupByVars)
                    obj.groupby(savedGroupByVars);
                end
            end

            % Save and clear methods — fit() already reprocessed the raw data;
            % parent aggregate() must not try to reprocess beta segments.
            savedRaw = obj.settings.rawMethod;
            savedOxy = obj.settings.oxyMethod;
            savedBaseline = obj.settings.baseline;
            savedTaskStart = obj.settings.taskStart;
            savedTaskEnd = obj.settings.taskEnd;
            savedUseBaseline = obj.settings.useBaseline;
            savedResampleRate = obj.settings.resampleRate;

            obj.settings.rawMethod = '';
            obj.settings.oxyMethod = '';
            % Beta pseudo-segments have time=[0,1]. Force single time bin
            % so aggregate() doesn't create multiple meaningless time bins.
            obj.settings.baseline = [-1, 0];
            obj.settings.taskStart = 0;
            obj.settings.taskEnd = 0.5;
            obj.settings.useBaseline = false;
            obj.settings.resampleRate = 0;

            try
                if nargin < 2
                    aggregate@exploreFNIRS.core.Experiment(obj);
                else
                    aggregate@exploreFNIRS.core.Experiment(obj, mode);
                end
            catch ME
                % Restore before rethrowing
                obj.settings.rawMethod = savedRaw;
                obj.settings.oxyMethod = savedOxy;
                obj.settings.baseline = savedBaseline;
                obj.settings.taskStart = savedTaskStart;
                obj.settings.taskEnd = savedTaskEnd;
                obj.settings.useBaseline = savedUseBaseline;
                obj.settings.resampleRate = savedResampleRate;
                rethrow(ME);
            end

            obj.settings.rawMethod = savedRaw;
            obj.settings.oxyMethod = savedOxy;
            obj.settings.baseline = savedBaseline;
            obj.settings.taskStart = savedTaskStart;
            obj.settings.taskEnd = savedTaskEnd;
            obj.settings.useBaseline = savedUseBaseline;
            obj.settings.resampleRate = savedResampleRate;
        end


        function results = statsFitLME(obj, varargin)
        % STATSFITLME Override to skip auto Time factor for GLM betas
            results = statsFitLME@exploreFNIRS.core.Experiment(obj, ...
                'SkipTimeFactor', true, varargin{:});
        end

        function [fig, results] = plotLME(obj, varargin)
        % PLOTLME Override to skip auto Time factor for GLM betas
            if ~obj.isAggregated
                error('exploreFNIRS:core:GLMExperiment:plotLME', ...
                    'Call aggregate() before plotLME()');
            end
            varargin = obj.injectColorScheme(varargin);
            [fig, results] = exploreFNIRS.core.plotLME(obj.groups, ...
                obj.groupByVars, 'SkipTimeFactor', true, varargin{:});
        end

        function [fig, results] = plotTopoLME(obj, varargin)
        % PLOTTOPOLME Override to skip auto Time factor for GLM betas
            if ~obj.isAggregated
                error('exploreFNIRS:core:GLMExperiment:plotTopoLME', ...
                    'Call aggregate() before plotTopoLME()');
            end
            [fig, results] = exploreFNIRS.core.plotTopoLME(obj.groups, ...
                obj.groupByVars, 'SkipTimeFactor', true, varargin{:});
        end


        function r = getSubjectResult(obj, idx)
        % GETSUBJECTRESULT Return per-subject GLM result struct
        %
        %   r = gx.getSubjectResult(1)
        %
        % Returns struct with fields: results, designMatrix,
        % regressorNames, events, subjectID

            if ~obj.isFitted
                error('exploreFNIRS:core:GLMExperiment:getSubjectResult', ...
                    'Call fit() before accessing subject results');
            end
            r = obj.subjectResults{idx};
        end


        function fig = plotDesignMatrix(obj, subjectIdx, varargin)
        % PLOTDESIGNMATRIX Visualize a subject's GLM design matrix
        %
        %   fig = gx.plotDesignMatrix(1)
        %   fig = gx.plotDesignMatrix(1, 'Visible', 'off')
        %   fig = gx.plotDesignMatrix(1, 'SavePath', 'dm.png')

            if ~obj.isFitted
                error('exploreFNIRS:core:GLMExperiment:plotDesignMatrix', ...
                    'Call fit() before plotting design matrix');
            end

            p = inputParser;
            addRequired(p, 'subjectIdx', @(x) isnumeric(x) && isscalar(x));
            addParameter(p, 'Visible', 'on', @ischar);
            addParameter(p, 'SavePath', '', @ischar);
            addParameter(p, 'SaveWidth', 800, @isnumeric);
            addParameter(p, 'SaveHeight', 500, @isnumeric);
            addParameter(p, 'SaveDPI', 150, @isnumeric);
            addParameter(p, 'TightLayout', false, @islogical);
            parse(p, subjectIdx, varargin{:});
            opts = p.Results;

            if ~isempty(opts.SavePath)
                opts.Visible = 'off';
            end

            r = obj.subjectResults{subjectIdx};

            fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
                'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
                'SavePath', opts.SavePath);
            ax = axes('Parent', fig);

            imagesc(ax, r.designMatrix);
            colormap(ax, parula);
            colorbar(ax);
            set(ax, 'XTick', 1:length(r.regressorNames), ...
                'XTickLabel', r.regressorNames, 'XTickLabelRotation', 45, ...
                'TickLabelInterpreter', 'none');
            xlabel(ax, 'Regressors');
            ylabel(ax, 'Time (samples)');
            title(ax, sprintf('Design Matrix: %s', pf2_base.plot.escapeTeX(r.subjectID)));

            sty = pf2_base.plot.PlotStyle.getDefault();
            sty.applyToFigure(fig);
            pf2_base.plot.handleSave(fig, opts);
        end


        function T = betaTable(obj, varargin)
        % BETATABLE Export beta weights as a flat table
        %
        %   T = gx.betaTable()
        %   T = gx.betaTable('Channels', 1:4)
        %   T = gx.betaTable('IncludeStats', true)
        %
        % Builds a table with one row per subject x condition x channel,
        % containing beta weights and optionally t-stats/p-values.
        %
        % Name-Value Parameters:
        %   Channels     - Channel indices (default: all)
        %   IncludeStats - Include tstat/pval columns (default: false)

            if ~obj.isFitted
                error('exploreFNIRS:core:GLMExperiment:betaTable', ...
                    'Call fit() before exporting beta table');
            end

            ip = inputParser;
            addParameter(ip, 'Channels', [], @isnumeric);
            addParameter(ip, 'IncludeStats', false, @islogical);
            parse(ip, varargin{:});
            channels = ip.Results.Channels;
            includeStats = ip.Results.IncludeStats;

            % Determine conditions
            conds = obj.glm.conditions;
            if isempty(conds) && ~isempty(obj.subjectResults)
                % Auto-detect from first subject's regressor names
                r1 = obj.subjectResults{1};
                bio1 = obj.glm.biomarkers{1};
                allNames = r1.results.(bio1).regressorNames;
                conds = detectStimulusRegressors(allNames);
            end

            rows = {};
            for s = 1:length(obj.subjectResults)
                sr = obj.subjectResults{s};
                d = obj.subjects{s};
                bio1 = obj.glm.biomarkers{1};
                nCh = size(sr.results.(bio1).beta, 2);

                if isempty(channels)
                    chList = 1:nCh;
                else
                    chList = channels;
                end

                for c = 1:length(conds)
                    condName = conds{c};
                    regIdx = find(strcmp(sr.regressorNames, condName), 1);
                    if isempty(regIdx), continue; end

                    for ch = chList
                        row = struct();
                        row.SubjectID = string(sr.subjectID);

                        % Copy info fields
                        if isfield(d, 'info')
                            infoFields = fieldnames(d.info);
                            for f = 1:length(infoFields)
                                fn = infoFields{f};
                                if strcmp(fn, 'SubjectID'), continue; end
                                val = d.info.(fn);
                                if isnumeric(val) && isscalar(val)
                                    row.(fn) = val;
                                elseif ischar(val) || isstring(val)
                                    row.(fn) = string(val);
                                end
                            end
                        end

                        row.Condition = string(condName);
                        row.Channel = ch;

                        % Beta per biomarker
                        for b = 1:length(obj.glm.biomarkers)
                            bio = obj.glm.biomarkers{b};
                            if isfield(sr.results, bio)
                                row.(['beta_' bio]) = ...
                                    sr.results.(bio).beta(regIdx, ch);
                                if includeStats
                                    row.(['tstat_' bio]) = ...
                                        sr.results.(bio).tstat(regIdx, ch);
                                    row.(['pval_' bio]) = ...
                                        sr.results.(bio).pval(regIdx, ch);
                                end
                            end
                        end

                        rows{end+1} = row; %#ok<AGROW>
                    end
                end
            end

            T = struct2table([rows{:}]);
        end


        function result = betaSeriesConnectivity(obj, varargin)
        % BETASERIESCONNECTIVITY Trial-by-trial beta-series correlation
        %
        %   result = gx.betaSeriesConnectivity()
        %   result = gx.betaSeriesConnectivity('Method', 'LSS')
        %   result = gx.betaSeriesConnectivity('Condition', {'Easy','Hard'})
        %   result = gx.betaSeriesConnectivity('Align', 'union')
        %
        % Computes beta-series correlation connectivity for each subject,
        % then aggregates across subjects using Fisher z-transform. Does
        % NOT require fit() — works directly on continuous data and blocks.
        %
        % All name-value parameters from computeBetaSeries are forwarded.
        %
        % Name-Value Parameters:
        %   Align - Channel alignment mode for group aggregation:
        %           'union' (default) - all channels, NaN where missing
        %           'intersection' - only channels in all subjects
        %           numeric 0-1 - channels in >= threshold fraction of subjects
        %
        % Outputs:
        %   result - Struct with fields:
        %     .Mean      - [C x C] mean connectivity (back-transformed from z)
        %     .SD        - [C x C] standard deviation of z-scores
        %     .SEM       - [C x C] standard error of z-scores
        %     .N         - Number of subjects
        %     .nValid    - [C x C] per-cell count of contributing subjects
        %     .matrices  - {N x 1} cell of per-subject matrices
        %     .method    - Method string
        %     .biomarker - Biomarker used
        %     .channels  - Channel indices
        %
        % See also: exploreFNIRS.connectivity.computeBetaSeries,
        %   exploreFNIRS.connectivity.alignMatrices

            % Extract Align before forwarding rest to computeBetaSeries
            [align, fwdArgs] = extractAlignArg(varargin);

            nSubjects = length(obj.subjects);

            % Reprocess subjects if methods are set
            processedSubjects = reprocessIfNeeded(obj);

            % Build ROI averages on continuous subjects if ROI info exists
            % but ROI biomarker data hasn't been computed yet
            for s = 1:nSubjects
                d = processedSubjects{s};
                if isfield(d, 'ROI') && isfield(d.ROI, 'info') && ...
                        ~isfield(d.ROI, 'HbO')
                    processedSubjects{s} = pf2_build_nanmean_ROI(d);
                end
            end

            % Compute per-subject beta-series connectivity
            subResults = cell(nSubjects, 1);
            for s = 1:nSubjects
                d = processedSubjects{s};
                subResults{s} = exploreFNIRS.connectivity.computeBetaSeries( ...
                    d, obj.blockDefs{s}, fwdArgs{:});
                fprintf('  %s: %d trials, beta-series computed (%d channels)\n', ...
                    d.info.SubjectID, subResults{s}.nTrials, length(subResults{s}.channels));
            end

            % Align matrices across subjects (handles different channel sets)
            [allValues, masterCh, masterLabels, nValid] = ...
                exploreFNIRS.connectivity.alignMatrices(subResults, align);

            % Fisher z-transform and aggregate across subjects (dim 3)
            clamped = max(min(allValues, 0.9999), -0.9999);
            zStack = atanh(clamped);
            nVals = sum(~isnan(allValues), 3);

            zMean = mean(zStack, 3, 'omitnan');
            zSD = std(zStack, 0, 3, 'omitnan');
            zSEM = zSD ./ sqrt(max(nVals, 1));

            result.Mean = tanh(zMean);
            result.SD = zSD;
            result.SEM = zSEM;
            result.N = nSubjects;
            result.nValid = nValid;
            result.matrices = cellfun(@(r) r.matrix, subResults, 'UniformOutput', false);
            result.method = subResults{1}.method;
            result.biomarker = subResults{1}.biomarker;
            result.useROI = subResults{1}.useROI;

            if iscell(masterCh)
                result.channels = masterCh{1};
            else
                result.channels = masterCh;
            end
            result.labels = masterLabels;

            % Plot-compatible
            result.matrix = result.Mean;
            result.pmatrix = nan(size(result.Mean));
        end


        function result = ppi(obj, seedChannels, varargin)
        % PPI Psychophysiological interaction analysis across subjects
        %
        %   result = gx.ppi([1 2 3])
        %   result = gx.ppi(1, 'Contrast', {'Hard', 'Easy'})
        %   result = gx.ppi(1, 'Align', 'union')
        %
        % Computes PPI for each subject and aggregates betas/p-values
        % across subjects. Does NOT require fit().
        %
        % All name-value parameters from computePPI are forwarded.
        %
        % Name-Value Parameters:
        %   Align - Channel alignment mode for group aggregation:
        %           'union' (default) - all channels, NaN where missing
        %           'intersection' - only channels in all subjects
        %           numeric 0-1 - channels in >= threshold fraction of subjects
        %
        % Outputs:
        %   result - Struct with fields:
        %     .Mean_beta   - [1 x nTargets] mean PPI beta
        %     .SD_beta     - [1 x nTargets] SD of PPI betas
        %     .SEM_beta    - [1 x nTargets] SEM of PPI betas
        %     .Mean_tstat  - [1 x nTargets] mean PPI t-stat
        %     .N           - Number of subjects
        %     .nValid      - [nTargets x 1] per-channel count of contributing subjects
        %     .ppi_betas   - [N x nTargets] per-subject PPI betas
        %     .ppi_pvals   - [N x nTargets] per-subject PPI p-values
        %     .matrix      - [1 x nTargets] mean PPI beta (plot compat)
        %     .pmatrix     - [1 x nTargets] group p-value (t-test)
        %     .channels    - Target channel indices
        %     .seedChannels - Seed channels used
        %     .method      - 'PPI'
        %     .biomarker   - Biomarker used
        %
        % See also: exploreFNIRS.connectivity.computePPI,
        %   exploreFNIRS.connectivity.alignMatrices

            % Extract Align before forwarding rest to computePPI
            [align, fwdArgs] = extractAlignArg(varargin);

            nSubjects = length(obj.subjects);

            % Reprocess subjects if methods are set
            processedSubjects = reprocessIfNeeded(obj);

            % Build ROI averages on continuous subjects if ROI info exists
            % but ROI biomarker data hasn't been computed yet
            for s = 1:nSubjects
                d = processedSubjects{s};
                if isfield(d, 'ROI') && isfield(d.ROI, 'info') && ...
                        ~isfield(d.ROI, 'HbO')
                    processedSubjects{s} = pf2_build_nanmean_ROI(d);
                end
            end

            % Compute per-subject PPI
            perSubjectBetas  = cell(nSubjects, 1);
            perSubjectTstats = cell(nSubjects, 1);
            perSubjectPvals  = cell(nSubjects, 1);
            perSubjectChannels = cell(nSubjects, 1);
            bioStr = '';
            lastResult = [];

            for s = 1:nSubjects
                d = processedSubjects{s};
                r = exploreFNIRS.connectivity.computePPI( ...
                    d, obj.blockDefs{s}, seedChannels, fwdArgs{:});

                perSubjectBetas{s}    = r.ppi_beta;
                perSubjectTstats{s}   = r.ppi_tstat;
                perSubjectPvals{s}    = r.ppi_pval;
                perSubjectChannels{s} = r.channels;
                if s == 1
                    bioStr = r.biomarker;
                end
                lastResult = r;
                fprintf('  %s: PPI computed (%d targets)\n', ...
                    d.info.SubjectID, length(r.channels));
            end

            % Use alignMatrices to determine master channels and align betas
            wrappers = cell(nSubjects, 1);
            for s = 1:nSubjects
                wrappers{s}.values = perSubjectBetas{s}(:);
                wrappers{s}.channelsA = perSubjectChannels{s}(:)';
                wrappers{s}.method = 'PPI';
                wrappers{s}.biomarker = bioStr;
                wrappers{s}.pairing = 'same';
            end

            [alignedBetas3D, masterCh, ~, nValid] = ...
                exploreFNIRS.connectivity.alignMatrices(wrappers, align);

            % alignedBetas3D is [nTargets x 1 x nSubjects]
            if iscell(masterCh)
                masterChVec = masterCh{1};
            else
                masterChVec = masterCh;
            end
            nTargets = length(masterChVec);
            alignedBetas = reshape(alignedBetas3D, nTargets, nSubjects);

            % Align tstat and pval to same master channels
            alignedTstats = nan(nTargets, nSubjects);
            alignedPvals = nan(nTargets, nSubjects);
            for s = 1:nSubjects
                [~, mIdx, sIdx] = intersect(masterChVec, perSubjectChannels{s}(:)');
                alignedTstats(mIdx, s) = perSubjectTstats{s}(sIdx);
                alignedPvals(mIdx, s) = perSubjectPvals{s}(sIdx);
            end

            % Aggregate across subjects
            nVals = sum(~isnan(alignedBetas), 2);

            result.Mean_beta  = mean(alignedBetas, 2, 'omitnan')';
            result.SD_beta    = std(alignedBetas, 0, 2, 'omitnan')';
            result.SEM_beta   = result.SD_beta ./ sqrt(max(nVals', 1));
            result.Mean_tstat = mean(alignedTstats, 2, 'omitnan')';
            result.N          = nSubjects;
            result.nValid     = squeeze(nValid);
            result.ppi_betas  = alignedBetas';   % [N x nTargets]
            result.ppi_pvals  = alignedPvals';   % [N x nTargets]

            % Group-level significance: one-sample t-test on betas
            if nSubjects > 1
                [~, pGroup] = pf2_base.compat.ttest(alignedBetas');
            else
                pGroup = alignedPvals';
            end

            result.matrix      = result.Mean_beta;
            result.pmatrix     = pGroup;
            result.channels    = masterChVec;
            result.seedChannels = seedChannels;
            result.method      = 'PPI';
            result.biomarker   = bioStr;
            result.useROI      = lastResult.useROI;

            % Rebuild labels for master channel set
            if lastResult.useROI && ~isempty(lastResult.labels)
                newLabels = arrayfun(@(c) sprintf('Ch%d', c), masterChVec, ...
                    'UniformOutput', false);
                [~, mIdx, sIdx] = intersect(masterChVec, perSubjectChannels{end}(:)');
                validMask = sIdx <= length(lastResult.labels);
                newLabels(mIdx(validMask)) = lastResult.labels(sIdx(validMask));
                result.labels = newLabels;
            else
                result.labels = arrayfun(@(c) sprintf('Ch%d', c), ...
                    masterChVec, 'UniformOutput', false);
            end
        end

    end
end


%% Local helper functions

function h = buildFitHash(obj)
% BUILDFITHASH Create a string hash of all settings that affect fit results

    key = sprintf( ...
        'raw=%s_oxy=%s_drift=%d_%s_%d_deriv=%d_disp=%d_method=%s_bios=%s_conds=%s_group=%s_aux=%s', ...
        obj.settings.rawMethod, obj.settings.oxyMethod, ...
        obj.glm.driftOrder, obj.glm.driftType, obj.glm.driftCutoff, ...
        obj.glm.includeDerivative, obj.glm.includeDispersion, ...
        obj.glm.fitMethod, ...
        strjoin(obj.glm.biomarkers, '+'), ...
        strjoin(obj.glm.conditions, '+'), ...
        obj.glm.groupBy, ...
        strjoin(obj.glm.auxFields, '+'));

    if ~isempty(obj.glm.hrf)
        key = [key '_hrf=' mat2str(obj.glm.hrf(:)')];
    end
    if ~isempty(obj.glm.conditionMap)
        for k = 1:size(obj.glm.conditionMap, 1)
            key = [key '_cm=' char(obj.glm.conditionMap{k,1}) ...
                   '>' char(obj.glm.conditionMap{k,2})]; %#ok<AGROW>
        end
    end

    h = key;
end


function seg = aggregateBlockInfo(seg, blocks, groupField)
% AGGREGATEBLOCKINFO Average numeric block-level info fields onto segment
%
% For a beta segment (one per condition), finds matching blocks and
% averages their numeric .info fields (reactionTime, accuracy, etc.).

    condLabel = seg.info.Condition;

    % Find blocks matching this condition
    condBlocks = [];
    for b = 1:length(blocks)
        blk = blocks(b);
        if isfield(blk, 'info') && isfield(blk.info, groupField)
            blkCond = blk.info.(groupField);
            if isnumeric(blkCond)
                blkCond = num2str(blkCond);
            else
                blkCond = char(blkCond);
            end
            if strcmp(blkCond, condLabel)
                condBlocks = [condBlocks, blk]; %#ok<AGROW>
            end
        end
    end

    if isempty(condBlocks), return; end

    % Average numeric block-level info fields
    blockFields = fieldnames(condBlocks(1).info);
    for f = 1:length(blockFields)
        fname = blockFields{f};
        % Skip grouping field and metadata
        if strcmp(fname, groupField) || strcmp(fname, 'BlockNumber')
            continue;
        end
        % Already present from source data — skip SubjectID, Group, etc.
        if isfield(seg.info, fname), continue; end

        vals = arrayfun(@(blk) blk.info.(fname), condBlocks, ...
            'UniformOutput', false);
        if all(cellfun(@(v) isnumeric(v) && isscalar(v), vals))
            % Average numeric fields across blocks
            numVals = cell2mat(vals);
            seg.info.(fname) = mean(numVals, 'omitnan');
        elseif all(cellfun(@(v) ischar(v) || isstring(v), vals))
            % For string fields, use the first value if all are identical
            charVals = cellfun(@char, vals, 'UniformOutput', false);
            if numel(unique(charVals)) == 1
                seg.info.(fname) = charVals{1};
            end
        end
    end
end


function stimRegs = detectStimulusRegressors(regressorNames)
% DETECTSTIMULUSREGRESSORS Identify stimulus regressors by excluding nuisance

    nuisancePatterns = {
        '^constant$'
        '^drift_'
        '^dct_'
        '^short_ch'
        '_deriv$'
        '_disp$'
    };

    isNuisance = false(size(regressorNames));
    for k = 1:length(nuisancePatterns)
        isNuisance = isNuisance | ~cellfun(@isempty, ...
            regexp(regressorNames, nuisancePatterns{k}));
    end

    stimRegs = regressorNames(~isNuisance);
end


function processedSubjects = reprocessIfNeeded(obj)
% REPROCESSIFNEEDED Reprocess subjects if rawMethod/oxyMethod are set

    processedSubjects = obj.subjects;
    hasMethodSet = ~isempty(obj.settings.rawMethod) || ...
                   ~isempty(obj.settings.oxyMethod);
    if hasMethodSet
        positionalArgs = {};
        if ~isempty(obj.settings.rawMethod)
            positionalArgs{end+1} = obj.settings.rawMethod;
        end
        if ~isempty(obj.settings.oxyMethod)
            positionalArgs{end+1} = obj.settings.oxyMethod;
        end
        for s = 1:length(obj.subjects)
            processedSubjects{s} = processFNIRS2( ...
                obj.subjects{s}, positionalArgs{:});
        end
    end
end


function [align, fwdArgs] = extractAlignArg(args)
% EXTRACTALIGNARG Extract 'Align' name-value pair from varargin
    align = 'union';
    fwdArgs = args;
    for k = 1:2:length(args)-1
        if ischar(args{k}) && strcmpi(args{k}, 'Align')
            align = args{k+1};
            fwdArgs = [args(1:k-1), args(k+2:end)];
            return;
        end
    end
end
