function contrastResults = runContrasts(lmeResults, varargin)
% RUNCONTRASTS Post-hoc contrasts across channels with FDR correction
%
% Takes output from exploreFNIRS.stats.fitLME and generates post-hoc
% contrast tables per channel, then applies FDR correction across channels
% for each unique contrast name.
%
% Syntax:
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults)
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults, 'FDRThreshold', 0.05)
%   contrastResults = exploreFNIRS.stats.runContrasts(lmeResults, 'FDRMethod', 'twostep')
%
% Inputs:
%   lmeResults - Struct from exploreFNIRS.stats.fitLME containing .models
%
% Name-Value Parameters:
%   PThreshold   - ANOVA p-value threshold for eligible contrasts (default: 0.1)
%   FDRThreshold - FDR significance threshold (default: 0.05)
%   FDRMethod    - 'bh' (Benjamini-Hochberg, default) or 'twostep' (adaptive)
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
%   cr = exploreFNIRS.stats.runContrasts(results);
%   fprintf('Significant contrasts (FDR corrected):\n');
%   disp(cr.contrastNames(any(cr.significantMatrix(:,:), 2)));
%
% See also: exploreFNIRS.stats.fitLME, exploreFNIRS.fx.autoContrast,
%           exploreFNIRS.fx.performFDR

    p = inputParser;
    addRequired(p, 'lmeResults', @isstruct);
    addParameter(p, 'PThreshold', 0.1, @isnumeric);
    addParameter(p, 'FDRThreshold', 0.05, @isnumeric);
    addParameter(p, 'FDRMethod', 'bh', @ischar);
    parse(p, lmeResults, varargin{:});
    opts = p.Results;

    % Validate FDR method early
    validMethods = {'bh', 'twostep'};
    if ~ismember(lower(opts.FDRMethod), validMethods)
        error('exploreFNIRS:stats:runContrasts', ...
            'Unknown FDR method: ''%s''. Use ''bh'' or ''twostep''.', opts.FDRMethod);
    end

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

    % FDR correction across channels for each contrast x biomarker
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
                otherwise
                    error('exploreFNIRS:stats:runContrasts', ...
                        'Unknown FDR method: %s. Use ''bh'' or ''twostep''.', opts.FDRMethod);
            end

            qMatrix(c, bIdx, :) = qVals;
            sigMatrix(c, bIdx, :) = sig;
        end
    end

    contrastResults.qvalueMatrix = qMatrix;
    contrastResults.significantMatrix = sigMatrix;
    contrastResults.fdrThreshold = opts.FDRThreshold;
    contrastResults.fdrMethod = opts.FDRMethod;
end
