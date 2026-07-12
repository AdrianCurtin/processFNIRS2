function [coeff, score, latent, tsquared, explained, mu] = pca(x, varargin)
%PCA Principal component analysis via SVD (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function PCA, implementing the default mean-centered SVD
%   algorithm. Lets PCA-based ROI building run without a Statistics
%   Toolbox license.
%
%   Inputs:
%     x        - N-by-P data matrix (rows = observations, cols = variables).
%   Name/value options:
%     'Algorithm' - Accepted and ignored; SVD is always used. 'Centered'
%                   (default true) is honored if supplied.
%
%   Outputs:
%     coeff     - P-by-K principal component coefficients (loadings).
%     score     - N-by-K component scores (observations in PC space).
%     latent    - K-by-1 eigenvalues (component variances).
%     tsquared  - N-by-1 Hotelling's T-squared per observation.
%     explained - K-by-1 percent of total variance per component.
%     mu        - 1-by-P estimated mean of each variable.
%   where K = min(N-1, P) when centered, matching PCA's component count.
%
%   Notes:
%     Component sign is arbitrary (an SVD property) and may differ from the
%     toolbox; downstream ROI use is sign-agnostic. Rows containing NaN are
%     dropped from the fit ('Rows','complete' behavior); SCORE rows for
%     dropped observations are returned as NaN so SCORE aligns with X.
%
%   See also: SVD, pf2_base.hasStatsToolbox

centered = true;
k = 1;
while k <= numel(varargin) - 1
    if strcmpi(varargin{k}, 'Centered')
        centered = logical(varargin{k+1});
    end
    k = k + 2;
end

[n, pdim] = size(x);
rowOK = all(~isnan(x), 2);
xf    = x(rowOK, :);
nf    = size(xf, 1);

if centered
    mu = mean(xf, 1);
    xc = xf - mu;
else
    mu = zeros(1, pdim);
    xc = xf;
end

[U, S, V] = svd(xc, 'econ');
sv = diag(S);

% Component count: drop the null component lost to centering
if centered
    maxK = min(nf - 1, pdim);
else
    maxK = min(nf, pdim);
end
maxK = max(maxK, 0);

% Variance normalization: N-1 when centered (default), N when not, to
% match the toolbox's eigenvalue scaling in both modes.
if centered
    vnorm = max(nf - 1, 1);
else
    vnorm = max(nf, 1);
end

coeff    = V(:, 1:maxK);
scoreFit = U(:, 1:maxK) * S(1:maxK, 1:maxK);
latent   = (sv(1:maxK).^2) / vnorm;

totalVar  = sum((sv.^2) / vnorm);
if totalVar > 0
    explained = 100 * latent / totalVar;
else
    explained = zeros(maxK, 1);
end

% T-squared on retained components
if maxK > 0
    nz = latent > 0;
    tsq = zeros(nf, 1);
    tsq(:) = sum((scoreFit(:, nz).^2) ./ (latent(nz).'), 2);
else
    tsq = zeros(nf, 1);
end

% Re-expand SCORE / T-squared to original row count (NaN for dropped rows)
score = nan(n, maxK);
score(rowOK, :) = scoreFit;
tsquared = nan(n, 1);
tsquared(rowOK) = tsq;

end
