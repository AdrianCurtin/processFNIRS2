function [xout, info] = pf2_GSR(x, nComp, varThresh)
% PF2_GSR Global-signal removal via PCA (eigenvector) spatial filtering
%
% Removes spatially global, systemic interference from fNIRS data by
% subtracting the leading principal components of the across-channel
% covariance. Physiological nuisance (scalp blood flow, Mayer waves,
% cardiac, blood pressure) is strongly shared across channels and therefore
% concentrates in the first few spatial eigenvectors; focal neural activity
% projects onto later, lower-variance components. Removing the top nComp
% components is a tunable generalization of Common Average Reference: CAR
% subtracts the raw spatial mean (a single, fixed component), whereas this
% filter subtracts the data-driven dominant component(s).
%
% Reference:
%   Zhang, Y., Brooks, D. H., Franceschini, M. A., & Boas, D. A. (2005).
%   Eigenvector-based spatial filtering for reduction of physiological
%   interference in diffuse optical imaging. Journal of Biomedical Optics,
%   10(1), 011014. DOI: 10.1117/1.1852552
%
% Differences from Zhang (2005):
%   The original estimates the interference eigenvectors from a guided
%   baseline / no-stimulus period and applies that fixed filter to the task
%   record. This function is the simplified "global" variant: the SVD is
%   computed over the whole record, so a spatially structured evoked
%   response can leak into the leading component(s) and be partially
%   removed. Estimate components on a rest/baseline window, keep nComp
%   small, or use varThresh to mitigate. The original is framed in
%   OD/measurement space; this operates per chromophore (see Notes).
%
% Syntax:
%   xout = pf2_GSR(x)
%   xout = pf2_GSR(x, nComp)
%   xout = pf2_GSR(x, nComp, varThresh)
%   [xout, info] = pf2_GSR(...)
%
% Inputs:
%   x         - Input signal matrix [T x C] where T=samples, C=channels.
%               Intended for hemoglobin concentration data (HbO, HbR, ...),
%               applied per chromophore. NaN samples are tolerated.
%   nComp     - Number of leading components to remove (default: 1).
%               1 is the closest analogue to CAR. Use 2-3 only with dense,
%               whole-head coverage. Set to 0 for a pass-through.
%   varThresh - Optional fractional-variance cap in (0,1] (default: [],
%               disabled). When set, the number of removed components is the
%               smaller of nComp and the count of leading components whose
%               cumulative variance does not exceed varThresh. Guards against
%               stripping a component that dominates the signal (e.g. a focal
%               task response on a sparse montage).
%
% Outputs:
%   xout - Filtered signal matrix [T x C], same size as input. Per-channel
%          temporal means are preserved (only zero-mean structure is removed).
%   info - Struct with .nRemoved (components removed), .varRemoved (fraction
%          of total variance removed), and .varExplained (per-component
%          variance fraction of the leading components).
%
% Algorithm:
%   1. Demean each channel over time (mu = mean over T, NaN-aware).
%   2. Economy SVD of the centered matrix: Xc = U*S*V'.
%   3. Reconstruct the global subspace G = U(:,1:k)*S(1:k,1:k)*V(:,1:k)'
%      with k = nComp (optionally capped by varThresh).
%   4. xout = (Xc - G) + mu, restoring NaN sample positions.
%
% Notes:
%   - Like CAR, this forces the removed component(s) out of every channel and
%     can induce spurious anti-correlations; on sparse/regional montages it
%     may remove genuine focal signal. Prefer short-channel regression
%     (pf2_SSR / pf2_base.fnirs.shortChannelRegression) when short separation
%     channels are available; use this as a proxy when they are not.
%   - Apply per chromophore on hemoglobin data, not on optical density.
%     Run independently, HbO and HbR receive different data-driven spatial
%     filters (their leading components are correlated but not identical),
%     so the correction is not guaranteed consistent across chromophores.
%     For a single shared filter, estimate components jointly (e.g. on
%     stacked or HbT data) and apply the same basis to both.
%   - Channels that are entirely NaN are passed through unchanged.
%
% Example:
%   data      = pf2.import.sampleData();
%   processed = processFNIRS2(data);
%   processed.HbO = pf2_GSR(processed.HbO, 1);   % remove dominant global PC
%   processed.HbR = pf2_GSR(processed.HbR, 1);
%
% See also: pf2_CAR, pf2_SSR, pf2_base.fnirs.shortChannelRegression

    if nargin < 2 || isempty(nComp)
        nComp = 1;
    end
    if nargin < 3
        varThresh = [];
    end
    nComp = round(nComp);   % component count must be integer-valued

    [T, C] = size(x);
    info = struct('nRemoved', 0, 'varRemoved', 0, 'varExplained', []);
    xout = x;

    if nComp < 1 || C < 2
        return;  % nothing to remove
    end

    % --- Center each channel over time (NaN-aware) ---
    mu = mean(x, 1, 'omitnan');
    mu(isnan(mu)) = 0;                 % all-NaN channels -> 0 offset
    Xc = x - mu;

    nanMask = isnan(Xc);
    Xc(nanMask) = 0;                   % zero-fill for the decomposition

    % --- Economy SVD: columns of U/V ordered by variance ---
    [U, S, V] = svd(Xc, 'econ');
    sv = diag(S);
    totVar = sum(sv.^2);
    if totVar <= 0
        return;
    end
    varExpl = (sv.^2) / totVar;

    % --- Decide how many components to strip ---
    k = min(nComp, numel(sv));
    if ~isempty(varThresh)
        cumVar = cumsum(varExpl);
        kCap = find(cumVar <= varThresh, 1, 'last');
        if isempty(kCap)
            kCap = 0;                  % even the 1st PC exceeds the cap
        end
        k = min(k, kCap);
    end

    if k < 1
        info.varExplained = varExpl(1:min(end, max(nComp, 1)))';
        return;
    end

    % --- Remove the global subspace, restore means and NaNs ---
    G = U(:, 1:k) * S(1:k, 1:k) * V(:, 1:k)';
    Xfilt = Xc - G;
    Xfilt(nanMask) = NaN;
    xout = Xfilt + mu;

    info.nRemoved = k;
    info.varRemoved = sum(varExpl(1:k));
    info.varExplained = varExpl(1:min(numel(varExpl), max(k, nComp)))';

end
