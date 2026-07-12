function spec = buildContrasts(mdl, type)
% BUILDCONTRASTS Generate standard contrast matrices from a fitted LME model
%
% Builds contrast specification structs for common comparison types,
% suitable for use with exploreFNIRS.stats.runContrasts('Contrasts', spec).
%
% Syntax:
%   spec = exploreFNIRS.stats.buildContrasts(mdl, type)
%
% Inputs:
%   mdl  - Fitted LinearMixedModel object
%   type - Contrast type:
%            'pairwise'   - All pairwise level comparisons (replicates autoContrast)
%            'polynomial' - Linear + quadratic trends (for ordered factors)
%            'linear'     - Linear trend only
%            'quadratic'  - Quadratic trend only
%            'helmert'    - Compare each level to mean of subsequent levels
%            'deviation'  - Compare each level to grand mean
%
% Outputs:
%   spec - Struct with fields:
%     .matrix - [nContrasts x nCoefficients] contrast matrix
%     .labels - Cell array of contrast names
%
% Example:
%   mdl = fitlme(T, 'HbO ~ Condition + (1|SubjectID)');
%
%   % Polynomial (linear + quadratic) for 3-level factor
%   spec = exploreFNIRS.stats.buildContrasts(mdl, 'polynomial');
%   cr = exploreFNIRS.stats.runContrasts(results, 'Contrasts', spec);
%
%   % All pairwise comparisons
%   spec = exploreFNIRS.stats.buildContrasts(mdl, 'pairwise');
%
% See also: exploreFNIRS.stats.runContrasts, coefTest

    if nargin < 2
        type = 'pairwise';
    end

    coefNames = mdl.CoefficientNames';
    nCoefs = length(coefNames);
    hasIntercept = any(strcmp(coefNames, '(Intercept)'));

    % Parse coefficient structure to find factor levels
    [factors, levelMap] = parseCoefficients(coefNames, hasIntercept);

    switch lower(type)
        case 'pairwise'
            spec = buildPairwise(coefNames, nCoefs, factors, levelMap, hasIntercept);

        case 'polynomial'
            spec = buildPolynomial(coefNames, nCoefs, factors, levelMap, hasIntercept, 'both');

        case 'linear'
            spec = buildPolynomial(coefNames, nCoefs, factors, levelMap, hasIntercept, 'linear');

        case 'quadratic'
            spec = buildPolynomial(coefNames, nCoefs, factors, levelMap, hasIntercept, 'quadratic');

        case 'helmert'
            spec = buildHelmert(coefNames, nCoefs, factors, levelMap, hasIntercept);

        case 'deviation'
            spec = buildDeviation(coefNames, nCoefs, factors, levelMap, hasIntercept);

        otherwise
            error('exploreFNIRS:stats:buildContrasts:unknownType', ...
                'Unknown contrast type: ''%s''. Use ''pairwise'', ''polynomial'', ''linear'', ''quadratic'', ''helmert'', or ''deviation''.', type);
    end
end


function [factors, levelMap] = parseCoefficients(coefNames, hasIntercept)
% PARSECOEFFICIENTS Extract factor names and their levels from coefficient names
%
% Returns:
%   factors  - cell array of factor names (excluding Intercept)
%   levelMap - containers.Map from factor name to cell array of level suffixes

    factors = {};
    levelMap = containers.Map();

    startIdx = 1 + hasIntercept;  % skip intercept

    for i = startIdx:length(coefNames)
        name = coefNames{i};
        if contains(name, ':'), continue; end  % skip interactions

        % Pattern: FactorName_LevelValue
        parts = regexp(name, '^(.+?)_(.+)$', 'tokens', 'once');
        if isempty(parts), continue; end

        factorName = parts{1};
        levelVal = parts{2};

        if ~levelMap.isKey(factorName)
            factors{end+1} = factorName; %#ok<AGROW>
            levelMap(factorName) = {levelVal};
        else
            existing = levelMap(factorName);
            existing{end+1} = levelVal;
            levelMap(factorName) = existing;
        end
    end
end


function spec = buildPairwise(coefNames, nCoefs, factors, levelMap, hasIntercept)
% BUILDPAIRWISE All pairwise comparisons between factor levels

    rows = [];
    labels = {};

    for fi = 1:length(factors)
        f = factors{fi};
        levels = levelMap(f);
        nLevels = length(levels);

        % Find coefficient indices for each level
        coefIdx = zeros(1, nLevels);
        for li = 1:nLevels
            fullName = sprintf('%s_%s', f, levels{li});
            coefIdx(li) = find(strcmp(coefNames, fullName));
        end

        % All pairwise: level i vs level j
        for i = 1:nLevels
            for j = (i+1):nLevels
                cRow = zeros(1, nCoefs);
                cRow(coefIdx(i)) = 1;
                cRow(coefIdx(j)) = -1;
                rows = [rows; cRow]; %#ok<AGROW>
                labels{end+1} = sprintf('%s_%s vs %s_%s', f, levels{i}, f, levels{j}); %#ok<AGROW>
            end
        end

        % If intercept model, also compare each level vs reference
        if hasIntercept
            for li = 1:nLevels
                cRow = zeros(1, nCoefs);
                cRow(coefIdx(li)) = 1;
                rows = [rows; cRow]; %#ok<AGROW>
                labels{end+1} = sprintf('%s_%s vs Reference', f, levels{li}); %#ok<AGROW>
            end
        end
    end

    if isempty(rows)
        rows = zeros(0, nCoefs);
    end
    spec.matrix = rows;
    spec.labels = labels(:);
end


function spec = buildPolynomial(coefNames, nCoefs, factors, levelMap, hasIntercept, mode)
% BUILDPOLYNOMIAL Linear and/or quadratic trend contrasts

    rows = [];
    labels = {};

    for fi = 1:length(factors)
        f = factors{fi};
        levels = levelMap(f);
        nLevels = length(levels);

        % Find coefficient indices
        coefIdx = zeros(1, nLevels);
        for li = 1:nLevels
            fullName = sprintf('%s_%s', f, levels{li});
            coefIdx(li) = find(strcmp(coefNames, fullName));
        end

        % For intercept models, the reference level is implicit
        % Total levels = nLevels + 1 (reference)
        totalLevels = nLevels + hasIntercept;

        if totalLevels < 2, continue; end

        % Build polynomial contrast coefficients for all levels
        % Using centered integer codes
        x = (1:totalLevels)' - mean(1:totalLevels);

        if strcmp(mode, 'linear') || strcmp(mode, 'both')
            linCoefs = x / norm(x);

            cRow = zeros(1, nCoefs);
            if hasIntercept
                % Reference level is first, intercept absorbs it
                cRow(1) = linCoefs(1);  % intercept gets reference level weight
                for li = 1:nLevels
                    cRow(coefIdx(li)) = linCoefs(li + 1);
                end
            else
                for li = 1:nLevels
                    cRow(coefIdx(li)) = linCoefs(li);
                end
            end
            rows = [rows; cRow]; %#ok<AGROW>
            labels{end+1} = sprintf('%s Linear', f); %#ok<AGROW>
        end

        if (strcmp(mode, 'quadratic') || strcmp(mode, 'both')) && totalLevels >= 3
            quadCoefs = x.^2 - mean(x.^2);
            quadCoefs = quadCoefs / norm(quadCoefs);

            cRow = zeros(1, nCoefs);
            if hasIntercept
                cRow(1) = quadCoefs(1);
                for li = 1:nLevels
                    cRow(coefIdx(li)) = quadCoefs(li + 1);
                end
            else
                for li = 1:nLevels
                    cRow(coefIdx(li)) = quadCoefs(li);
                end
            end
            rows = [rows; cRow]; %#ok<AGROW>
            labels{end+1} = sprintf('%s Quadratic', f); %#ok<AGROW>
        end
    end

    if isempty(rows)
        rows = zeros(0, nCoefs);
    end
    spec.matrix = rows;
    spec.labels = labels(:);
end


function spec = buildHelmert(coefNames, nCoefs, factors, levelMap, hasIntercept)
% BUILDHELMERT Each level vs mean of subsequent levels

    rows = [];
    labels = {};

    for fi = 1:length(factors)
        f = factors{fi};
        levels = levelMap(f);
        nLevels = length(levels);
        totalLevels = nLevels + hasIntercept;

        if totalLevels < 2, continue; end

        % Find coefficient indices
        coefIdx = zeros(1, nLevels);
        for li = 1:nLevels
            fullName = sprintf('%s_%s', f, levels{li});
            coefIdx(li) = find(strcmp(coefNames, fullName));
        end

        % Helmert: level k vs mean of levels k+1..K
        % For K total levels, gives K-1 contrasts
        allLabels = {};
        if hasIntercept
            allLabels = [{'Reference'}, levels(:)'];
        else
            allLabels = levels(:)';
        end

        for k = 1:(totalLevels - 1)
            nRemaining = totalLevels - k;
            cRow = zeros(1, nCoefs);

            if hasIntercept
                if k == 1
                    % Reference level vs mean of all coded levels
                    % In reference coding, reference = intercept + 0 effects
                    % Other levels = intercept + effect_i
                    % So (ref) - mean(others) = -mean(effects)
                    % Contrast on coefficients: intercept=0, effects=-1/nRemaining
                    for li = 1:nLevels
                        cRow(coefIdx(li)) = -1 / nRemaining;
                    end
                else
                    % Coded level vs mean of subsequent coded levels
                    curLevelIdx = k - 1;
                    cRow(coefIdx(curLevelIdx)) = 1;
                    for li = curLevelIdx+1:nLevels
                        cRow(coefIdx(li)) = -1 / nRemaining;
                    end
                end
            else
                cRow(coefIdx(k)) = 1;
                for li = k+1:nLevels
                    cRow(coefIdx(li)) = -1 / nRemaining;
                end
            end

            rows = [rows; cRow]; %#ok<AGROW>
            labels{end+1} = sprintf('%s %s vs Later', f, allLabels{k}); %#ok<AGROW>
        end
    end

    if isempty(rows)
        rows = zeros(0, nCoefs);
    end
    spec.matrix = rows;
    spec.labels = labels(:);
end


function spec = buildDeviation(coefNames, nCoefs, factors, levelMap, hasIntercept)
% BUILDDEVIATION Each level vs grand mean

    rows = [];
    labels = {};

    for fi = 1:length(factors)
        f = factors{fi};
        levels = levelMap(f);
        nLevels = length(levels);
        totalLevels = nLevels + hasIntercept;

        if totalLevels < 2, continue; end

        % Find coefficient indices
        coefIdx = zeros(1, nLevels);
        for li = 1:nLevels
            fullName = sprintf('%s_%s', f, levels{li});
            coefIdx(li) = find(strcmp(coefNames, fullName));
        end

        % Deviation: each level minus grand mean
        % Grand mean of intercept model = intercept + mean(all effects)
        % So deviation for coded level i = effect_i - mean(all effects)

        for li = 1:nLevels
            cRow = zeros(1, nCoefs);
            cRow(coefIdx(li)) = 1;

            % Subtract mean of all effects
            for lj = 1:nLevels
                cRow(coefIdx(lj)) = cRow(coefIdx(lj)) - 1/totalLevels;
            end

            if hasIntercept
                % Reference level contributes 0 effect, mean includes it
                % Already handled by totalLevels denominator
                cRow(1) = -1/totalLevels;  % subtract reference share
            end

            rows = [rows; cRow]; %#ok<AGROW>
            labels{end+1} = sprintf('%s_%s vs Mean', f, levels{li}); %#ok<AGROW>
        end
    end

    if isempty(rows)
        rows = zeros(0, nCoefs);
    end
    spec.matrix = rows;
    spec.labels = labels(:);
end
