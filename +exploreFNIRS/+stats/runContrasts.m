function contrastResults = runContrasts(lmeResults, varargin)
% RUNCONTRASTS Post-hoc contrasts across channels with FDR correction
%
% Takes output from exploreFNIRS.stats.fitLME and generates post-hoc
% contrast tables per channel, then applies FDR correction across channels
% for each unique contrast name.
%
% Supports both automatic pairwise contrasts (default) and user-specified
% custom contrast matrices for planned comparisons.
%
% Syntax:
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults)
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults, 'FDRThreshold', 0.05)
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults, 'FDRMethod', 'twostep')
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults, 'Contrasts', spec)
%
% Inputs:
%   lmeResults - Struct from exploreFNIRS.stats.fitLME containing .models
%
% Name-Value Parameters:
%   PThreshold   - ANOVA p-value threshold for eligible contrasts (default: 0.1)
%                  Only used when Contrasts='auto'.
%   FDRThreshold - FDR significance threshold (default: 0.05)
%   FDRMethod    - 'bh' (Benjamini-Hochberg, default) or 'twostep' (adaptive)
%   Contrasts    - 'auto' (default) for automatic pairwise contrasts, or a
%                  struct with fields:
%                    .matrix - [nContrasts x nCoefficients] contrast matrix
%                    .labels - Cell array of contrast names
%                  Each row of .matrix is a contrast vector tested via coefTest.
%
% Outputs:
%   contrastResults - Struct with fields:
%     .contrasts         - Cell array of contrast tables [nBio x nCh]
%     .contrastNames     - Cell array of unique contrast names across channels
%     .pvalueMatrix      - [nContrasts x nBio x nCh] uncorrected p-values
%     .qvalueMatrix      - [nContrasts x nBio x nCh] FDR-corrected q-values
%     .significantMatrix - [nContrasts x nBio x nCh] logical significance
%     .effectSizeMatrix  - [nContrasts x nBio x nCh] delta estimates
%     .fdrThreshold      - Threshold used
%     .fdrMethod         - Method used
%     .biomarkers        - Biomarker names
%     .channels          - Channel indices
%
% Example:
%   results = exploreFNIRS.stats.fitLME(groups, {'Group','Condition'});
%
%   % Auto contrasts (default)
%   cr = exploreFNIRS.stats.runContrasts(results);
%
%   % Custom planned comparisons
%   spec.matrix = [-1 0 1; -1 2 -1];
%   spec.labels = {'Linear', 'Quadratic'};
%   cr = exploreFNIRS.stats.runContrasts(results, 'Contrasts', spec);
%
%   % Generate standard contrast types
%   spec = exploreFNIRS.stats.buildContrasts(results.models{1,1}, 'polynomial');
%   cr = exploreFNIRS.stats.runContrasts(results, 'Contrasts', spec);
%
% References:
%   Benjamini, Y. & Hochberg, Y. (1995). Controlling the false discovery
%   rate: a practical and powerful approach to multiple testing. Journal of
%   the Royal Statistical Society, Series B, 57(1), 289-300.
%
%   Benjamini, Y., Krieger, A. M. & Yekutieli, D. (2006). Adaptive linear
%   step-up procedures that control the false discovery rate. Biometrika,
%   93(3), 491-507. DOI: 10.1093/biomet/93.3.491
%
%   Searle, S. R., Speed, F. M. & Milliken, G. A. (1980). Population
%   marginal means in the linear model: An alternative to least squares
%   means. The American Statistician, 34(4), 216-221.
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.stats.buildContrasts,
%           exploreFNIRS.fx.autoContrast, exploreFNIRS.fx.performFDR

    p = inputParser;
    addRequired(p, 'lmeResults', @isstruct);
    addParameter(p, 'PThreshold', 0.1, @isnumeric);
    addParameter(p, 'FDRThreshold', 0.05, @isnumeric);
    addParameter(p, 'FDRMethod', 'bh', @ischar);
    addParameter(p, 'Contrasts', 'auto', @(x) ischar(x) || isstruct(x));
    parse(p, lmeResults, varargin{:});
    opts = p.Results;

    % Validate FDR method early
    validMethods = {'bh', 'twostep'};
    if ~ismember(lower(opts.FDRMethod), validMethods)
        error('exploreFNIRS:stats:runContrasts', ...
            'Unknown FDR method: ''%s''. Use ''bh'' or ''twostep''.', opts.FDRMethod);
    end

    % Determine contrast mode
    useCustom = isstruct(opts.Contrasts);

    if useCustom
        contrastResults = runCustomContrasts(lmeResults, opts);
    else
        contrastResults = runAutoContrasts(lmeResults, opts);
    end
end


function contrastResults = runAutoContrasts(lmeResults, opts)
% RUNAUTOCONTRASTS Original autoContrast-based pipeline

    [nBioM, nCh] = size(lmeResults.models);

    contrastResults = struct();
    contrastResults.contrasts = cell(nBioM, nCh);
    contrastResults.biomarkers = lmeResults.biomarkers;
    contrastResults.channels = lmeResults.channels;

    % First pass: run autoContrast per model and collect all unique names
    allContrastNames = {};

    for bIdx = 1:nBioM
        for chI = 1:nCh
            mdl = lmeResults.models{bIdx, chI};
            if isempty(mdl), continue; end

            try
                cTable = exploreFNIRS.fx.autoContrast(mdl, opts.PThreshold);
                contrastResults.contrasts{bIdx, chI} = cTable;

                if ~isempty(cTable) && height(cTable) > 0
                    names = cTable.Properties.RowNames;
                    allContrastNames = union(allContrastNames, names, 'stable');
                end
            catch
                contrastResults.contrasts{bIdx, chI} = table();
            end
        end
    end

    contrastResults.contrastNames = allContrastNames;
    nContrasts = length(allContrastNames);

    if nContrasts == 0
        contrastResults.pvalueMatrix = [];
        contrastResults.qvalueMatrix = [];
        contrastResults.significantMatrix = [];
        contrastResults.effectSizeMatrix = [];
        contrastResults.fdrThreshold = opts.FDRThreshold;
        contrastResults.fdrMethod = opts.FDRMethod;
        return;
    end

    % Build p-value and effect size matrices
    pMatrix = nan(nContrasts, nBioM, nCh);
    eMatrix = nan(nContrasts, nBioM, nCh);

    for bIdx = 1:nBioM
        for chI = 1:nCh
            cTable = contrastResults.contrasts{bIdx, chI};
            if isempty(cTable) || height(cTable) == 0, continue; end

            for c = 1:nContrasts
                if ismember(allContrastNames{c}, cTable.Properties.RowNames)
                    pMatrix(c, bIdx, chI) = cTable{allContrastNames{c}, 'pVal'};
                    eMatrix(c, bIdx, chI) = cTable{allContrastNames{c}, 'deltaE'};
                end
            end
        end
    end

    contrastResults.pvalueMatrix = pMatrix;
    contrastResults.effectSizeMatrix = eMatrix;

    % FDR correction
    [contrastResults.qvalueMatrix, contrastResults.significantMatrix] = ...
        applyFDR(pMatrix, nContrasts, nBioM, opts);
    contrastResults.fdrThreshold = opts.FDRThreshold;
    contrastResults.fdrMethod = opts.FDRMethod;
end


function contrastResults = runCustomContrasts(lmeResults, opts)
% RUNCUSTOMCONTRASTS User-specified contrast matrix pipeline

    spec = opts.Contrasts;

    % Validate contrast spec
    if ~isfield(spec, 'matrix') || ~isfield(spec, 'labels')
        error('exploreFNIRS:stats:runContrasts:invalidSpec', ...
            'Contrasts struct must have .matrix and .labels fields.');
    end
    if size(spec.matrix, 1) ~= length(spec.labels)
        error('exploreFNIRS:stats:runContrasts:sizeMismatch', ...
            'Number of rows in .matrix (%d) must match length of .labels (%d).', ...
            size(spec.matrix, 1), length(spec.labels));
    end

    [nBioM, nCh] = size(lmeResults.models);
    nContrasts = size(spec.matrix, 1);

    contrastResults = struct();
    contrastResults.contrasts = cell(nBioM, nCh);
    contrastResults.biomarkers = lmeResults.biomarkers;
    contrastResults.channels = lmeResults.channels;
    contrastResults.contrastNames = spec.labels(:)';

    pMatrix = nan(nContrasts, nBioM, nCh);
    eMatrix = nan(nContrasts, nBioM, nCh);

    for bIdx = 1:nBioM
        for chI = 1:nCh
            mdl = lmeResults.models{bIdx, chI};
            if isempty(mdl), continue; end

            cTable = customContrast(mdl, spec);
            contrastResults.contrasts{bIdx, chI} = cTable;

            if ~isempty(cTable) && height(cTable) > 0
                pMatrix(:, bIdx, chI) = cTable.pVal;
                eMatrix(:, bIdx, chI) = cTable.deltaE;
            end
        end
    end

    contrastResults.pvalueMatrix = pMatrix;
    contrastResults.effectSizeMatrix = eMatrix;

    % FDR correction
    [contrastResults.qvalueMatrix, contrastResults.significantMatrix] = ...
        applyFDR(pMatrix, nContrasts, nBioM, opts);
    contrastResults.fdrThreshold = opts.FDRThreshold;
    contrastResults.fdrMethod = opts.FDRMethod;
end


function cTable = customContrast(mdl, spec)
% CUSTOMCONTRAST Run user-specified contrasts against an LME model
%
% Validates matrix dimensions, runs coefTest per row, computes effect sizes.

    nCoefs = length(mdl.CoefficientNames);
    nContrasts = size(spec.matrix, 1);

    if size(spec.matrix, 2) ~= nCoefs
        error('exploreFNIRS:stats:runContrasts:coefMismatch', ...
            'Contrast matrix has %d columns but model has %d coefficients (%s).', ...
            size(spec.matrix, 2), nCoefs, strjoin(mdl.CoefficientNames, ', '));
    end

    [~, ~, mdlCoef] = fixedEffects(mdl, 'DFMethod', 'satterthwaite');

    deltaE = nan(nContrasts, 1);
    SD = nan(nContrasts, 1);
    F = nan(nContrasts, 1);
    df1 = nan(nContrasts, 1);
    df2 = nan(nContrasts, 1);
    pVal = nan(nContrasts, 1);
    sig = strings(nContrasts, 1);

    for c = 1:nContrasts
        cRow = spec.matrix(c, :);

        [pVal(c), F(c), df1(c), df2(c)] = coefTest(mdl, cRow, 0, ...
            'DFMethod', 'satterthwaite');

        % Effect size: contrast vector dot product with coefficients
        deltaE(c) = cRow * mdlCoef.Estimate;

        % SE of the contrast estimate: sqrt(L * CovBeta * L')
        covBeta = mdl.CoefficientCovariance;
        SD(c) = sqrt(cRow * covBeta * cRow');

        % Significance stars
        if pVal(c) < 0.001
            sig(c) = " *** ";
        elseif pVal(c) < 0.01
            sig(c) = " **  ";
        elseif pVal(c) < 0.05
            sig(c) = " *   ";
        elseif pVal(c) < 0.1
            sig(c) = " +   ";
        else
            sig(c) = "     ";
        end
    end

    % Bonferroni correction within custom contrast set
    pVal_corr = min(pVal * nContrasts, 1);

    cTable = table(deltaE, SD, F, df1, df2, pVal, pVal_corr, sig, ...
        repmat({nan(1, nCoefs)}, nContrasts, 1), ...
        'VariableNames', {'deltaE','SD','F','df1','df2','pVal','pVal_corr','sig','coefContrasts'}, ...
        'RowNames', spec.labels(:));

    % Store actual contrast rows
    for c = 1:nContrasts
        cTable.coefContrasts{c} = spec.matrix(c, :);
    end
end


function [qMatrix, sigMatrix] = applyFDR(pMatrix, nContrasts, nBioM, opts)
% APPLYFDR FDR correction across channels for each contrast x biomarker

    qMatrix = nan(size(pMatrix));
    sigMatrix = false(size(pMatrix));

    for c = 1:nContrasts
        for bIdx = 1:nBioM
            pVals = squeeze(pMatrix(c, bIdx, :))';
            if all(isnan(pVals)), continue; end

            switch lower(opts.FDRMethod)
                case 'bh'
                    [qVals, ~, sig] = exploreFNIRS.fx.performFDR( ...
                        pVals, opts.FDRThreshold);
                case 'twostep'
                    [qVals, ~, sig] = exploreFNIRS.fx.performFDR_twostep( ...
                        pVals, opts.FDRThreshold);
            end

            qMatrix(c, bIdx, :) = qVals;
            sigMatrix(c, bIdx, :) = sig;
        end
    end
end
