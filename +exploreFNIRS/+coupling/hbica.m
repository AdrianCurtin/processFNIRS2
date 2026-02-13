function result = hbica(x, y, fs, varargin)
% HBICA Pairwise coupling adapter for HB-ICA
%
% Thin wrapper providing the standard coupling interface (x, y, fs) for
% HB-ICA. For the 2-channel case, GOF degenerates (z-scoring 2 values
% always gives +/-0.707), so this adapter uses product-of-normalized-weights
% as the coupling metric instead.
%
% The recommended path for full HB-ICA analysis is the standalone function
% exploreFNIRS.hyperscanning.hbica() which operates on complete fNIRS
% structs. This adapter is provided for API consistency with the coupling
% dispatch system.
%
% Syntax:
%   result = exploreFNIRS.coupling.hbica(x, y, fs)
%
% Inputs:
%   x  - [T x 1] time series from subject A
%   y  - [T x 1] time series from subject B
%   fs - Sampling frequency (Hz)
%
% Name-Value Parameters:
%   NumComponents    - ICA components (default: 0, auto)
%   VarianceRetained - PCA threshold (default: 0.99)
%   Lags             - TDSEP lags in samples (default: auto)
%
% Outputs:
%   result - Struct with fields:
%     .value    - Scalar coupling score (0 = one-sided, 0.5 = max inter-brain)
%     .pvalue   - NaN (no parametric p-value for ICA-based metric)
%     .method   - 'hbica'
%     .windowed - false
%
% Notes:
%   The coupling value is: 2 * w1_norm * w2_norm, where w_norm = |w|/sum(|w|).
%   This equals 0.5 when both channels load equally (maximum inter-brain
%   coupling) and approaches 0 when loading is one-sided.
%
% References:
%   Luo, H., Cai, Y., Lin, X. & Duan, L. (2024). Hyper-brain independent
%   component analysis (HB-ICA). Biomedical Optics Express, 16(1).
%   DOI: 10.1364/BOE.542554
%
% See also: exploreFNIRS.hyperscanning.hbica, exploreFNIRS.coupling.pearson

    ip = inputParser;
    addRequired(ip, 'x', @(v) isnumeric(v) && isvector(v));
    addRequired(ip, 'y', @(v) isnumeric(v) && isvector(v));
    addRequired(ip, 'fs', @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(ip, 'NumComponents', 0, @(v) isnumeric(v) && isscalar(v));
    addParameter(ip, 'VarianceRetained', 0.99, @(v) isnumeric(v) && isscalar(v));
    addParameter(ip, 'Lags', [], @(v) isnumeric(v));
    parse(ip, x, y, fs, varargin{:});
    opts = ip.Results;

    x = x(:);
    y = y(:);
    if length(x) ~= length(y)
        error('exploreFNIRS:coupling:hbica', 'x and y must have equal length');
    end

    T = length(x);
    if T < 10
        result.value = NaN;
        result.pvalue = NaN;
        result.method = 'hbica';
        result.windowed = false;
        return;
    end

    % Concatenate as 2-channel matrix
    X = [x, y];

    % Run TDSEP
    tdsepArgs = {'VarianceRetained', opts.VarianceRetained};
    if opts.NumComponents > 0
        tdsepArgs = [tdsepArgs, 'NumComponents', opts.NumComponents];
    end
    if ~isempty(opts.Lags)
        tdsepArgs = [tdsepArgs, 'Lags', opts.Lags];
    end

    [~, ~, A] = pf2_base.signal.tdsep(X, tdsepArgs{:});

    % For 2-channel case, use product-of-normalized-weights
    % Pick the component with most balanced loading across the two channels
    K = size(A, 2);
    couplingValues = zeros(K, 1);
    for k = 1:K
        w = abs(A(:, k));
        wSum = sum(w);
        if wSum < eps
            continue;
        end
        wNorm = w / wSum;
        % 2 * w1_norm * w2_norm: max 0.5 at equal loading, 0 at one-sided
        couplingValues(k) = 2 * wNorm(1) * wNorm(2);
    end

    % Return the maximum coupling across components
    result.value = max(couplingValues);
    result.pvalue = NaN;
    result.method = 'hbica';
    result.windowed = false;
end
