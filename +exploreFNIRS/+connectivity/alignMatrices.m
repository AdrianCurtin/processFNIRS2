function [aligned, masterChannels, masterLabels, nValid] = alignMatrices(results, mode)
% ALIGNMATRICES Align connectivity results from subjects with different channels
%
% Maps each subject's/dyad's connectivity result into a common channel-
% indexed grid so that matrix entry (i,j) always represents the same
% channel pair across subjects, regardless of per-subject channel rejection.
%
% Syntax:
%   [aligned, masterCh, masterLabels, nValid] = ...
%       exploreFNIRS.connectivity.alignMatrices(results, 'union')
%   [aligned, masterCh, masterLabels, nValid] = ...
%       exploreFNIRS.connectivity.alignMatrices(results, 'intersection')
%   [aligned, masterCh, masterLabels, nValid] = ...
%       exploreFNIRS.connectivity.alignMatrices(results, 0.75)
%
% Inputs:
%   results - Cell array of result structs. Each must have one of:
%               Connectivity: .matrix [N x N] and .channels [1 x N]
%               Hyperscanning 'same': .values [N x 1] and .channelsA [1 x N]
%               Hyperscanning 'all':  .values [Na x Nb] and .channelsA, .channelsB
%   mode    - Alignment mode:
%               'union'        - All channels present in any subject (default)
%               'intersection' - Only channels present in every subject
%               numeric 0-1    - Channels present in >= mode fraction of subjects
%
% Outputs:
%   aligned       - 3D array with aligned values. NaN where a subject lacks
%                   data for a channel. Shape: [M x M x K] for connectivity,
%                   [M x 1 x K] for hyperscanning 'same', [Ma x Mb x K] for 'all'.
%   masterChannels - Master channel vector (or {masterA, masterB} for 'all' pairing)
%   masterLabels   - Cell array of labels (or {labelsA, labelsB} for 'all' pairing)
%   nValid         - Per-cell count of subjects contributing a non-NaN value
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.hyperscanning.computeGroup

    if nargin < 2
        mode = 'union';
    end

    K = length(results);
    if K == 0
        error('exploreFNIRS:connectivity:alignMatrices', 'Empty results cell array');
    end

    % Detect result shape
    isConnectivity = isfield(results{1}, 'matrix');
    isHyperAll = ~isConnectivity && isfield(results{1}, 'channelsB') && ...
        isfield(results{1}, 'values') && ~isvector(results{1}.values);

    if isHyperAll
        [aligned, masterChannels, masterLabels, nValid] = ...
            alignHyperscanningAll(results, K, mode);
    elseif isConnectivity
        [aligned, masterChannels, masterLabels, nValid] = ...
            alignConnectivity(results, K, mode);
    else
        % Hyperscanning 'same' pairing (vector values)
        [aligned, masterChannels, masterLabels, nValid] = ...
            alignHyperscanningSame(results, K, mode);
    end
end


function [aligned, masterCh, masterLabels, nValid] = alignConnectivity(results, K, mode)
% Align NxN connectivity matrices

    % Collect all channel vectors
    allChannels = cell(K, 1);
    for k = 1:K
        allChannels{k} = results{k}.channels(:)';
    end

    masterCh = computeMasterChannels(allChannels, K, mode);
    M = length(masterCh);

    % Build aligned 3D array
    aligned = nan(M, M, K);
    for k = 1:K
        [~, masterIdx, subIdx] = intersect(masterCh, allChannels{k});
        aligned(masterIdx, masterIdx, k) = results{k}.matrix(subIdx, subIdx);
    end

    nValid = sum(~isnan(aligned), 3);

    % Build labels
    masterLabels = buildLabels(results, masterCh, 'labels', 'channels');
end


function [aligned, masterCh, masterLabels, nValid] = alignHyperscanningSame(results, K, mode)
% Align Nx1 hyperscanning 'same' pairing vectors

    allChannels = cell(K, 1);
    for k = 1:K
        allChannels{k} = results{k}.channelsA(:)';
    end

    masterCh = computeMasterChannels(allChannels, K, mode);
    M = length(masterCh);

    aligned = nan(M, 1, K);
    for k = 1:K
        [~, masterIdx, subIdx] = intersect(masterCh, allChannels{k});
        aligned(masterIdx, 1, k) = results{k}.values(subIdx);
    end

    nValid = sum(~isnan(aligned), 3);

    masterLabels = buildLabels(results, masterCh, 'labelsA', 'channelsA');
end


function [aligned, masterChannels, masterLabels, nValid] = alignHyperscanningAll(results, K, mode)
% Align Na x Nb hyperscanning 'all' pairing matrices

    allChA = cell(K, 1);
    allChB = cell(K, 1);
    for k = 1:K
        allChA{k} = results{k}.channelsA(:)';
        allChB{k} = results{k}.channelsB(:)';
    end

    masterA = computeMasterChannels(allChA, K, mode);
    masterB = computeMasterChannels(allChB, K, mode);
    Ma = length(masterA);
    Mb = length(masterB);

    aligned = nan(Ma, Mb, K);
    for k = 1:K
        [~, mIdxA, sIdxA] = intersect(masterA, allChA{k});
        [~, mIdxB, sIdxB] = intersect(masterB, allChB{k});
        aligned(mIdxA, mIdxB, k) = results{k}.values(sIdxA, sIdxB);
    end

    nValid = sum(~isnan(aligned), 3);

    labelsA = buildLabels(results, masterA, 'labelsA', 'channelsA');
    labelsB = buildLabels(results, masterB, 'labelsB', 'channelsB');

    masterChannels = {masterA, masterB};
    masterLabels = {labelsA, labelsB};
end


function master = computeMasterChannels(allChannels, K, mode)
% Compute the master channel set based on alignment mode

    if ischar(mode) || isstring(mode)
        switch lower(char(mode))
            case 'union'
                master = allChannels{1};
                for k = 2:K
                    master = union(master, allChannels{k});
                end
            case 'intersection'
                master = allChannels{1};
                for k = 2:K
                    master = intersect(master, allChannels{k});
                end
            otherwise
                error('exploreFNIRS:connectivity:alignMatrices', ...
                    'Unknown alignment mode "%s". Use ''union'', ''intersection'', or a numeric threshold.', char(mode));
        end
    elseif isnumeric(mode) && isscalar(mode) && mode > 0 && mode <= 1
        % Threshold mode: channels in >= mode fraction of subjects
        all = [];
        for k = 1:K
            all = union(all, allChannels{k});
        end
        counts = zeros(size(all));
        for k = 1:K
            counts = counts + ismember(all, allChannels{k});
        end
        master = all(counts >= mode * K);
    else
        error('exploreFNIRS:connectivity:alignMatrices', ...
            'mode must be ''union'', ''intersection'', or a numeric threshold in (0, 1].');
    end

    master = sort(master(:)');
end


function labels = buildLabels(results, masterCh, labelField, chField)
% Build labels for master channel set from the first result that has them

    labels = arrayfun(@(c) sprintf('Ch%d', c), masterCh, 'UniformOutput', false);

    for k = 1:length(results)
        if isfield(results{k}, labelField) && ~isempty(results{k}.(labelField))
            subCh = results{k}.(chField)(:)';
            subLabels = results{k}.(labelField);
            if iscell(subLabels)
                [~, mIdx, sIdx] = intersect(masterCh, subCh);
                labels(mIdx) = subLabels(sIdx);
            end
            break;
        end
    end
end
