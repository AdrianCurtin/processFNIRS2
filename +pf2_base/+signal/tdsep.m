function [W, S, A] = tdsep(X, varargin)
% TDSEP Temporal Decorrelation Source Separation
%
% Performs blind source separation using joint approximate diagonalization
% of time-lagged covariance matrices (TDSEP algorithm). Identifies
% independent sources by exploiting temporal structure in the data.
%
% Syntax:
%   [W, S, A] = pf2_base.signal.tdsep(X)
%   [W, S, A] = pf2_base.signal.tdsep(X, 'Lags', 1:50)
%   [W, S, A] = pf2_base.signal.tdsep(X, 'NumComponents', 5)
%   [W, S, A] = pf2_base.signal.tdsep(X, 'VarianceRetained', 0.95)
%
% Inputs:
%   X - [T x C] data matrix (T time samples, C channels)
%
% Name-Value Parameters:
%   Lags             - Time lag vector in samples (default: 1:min(100, floor(T/2)))
%   NumComponents    - Number of components to extract (default: auto from PCA)
%   VarianceRetained - PCA variance threshold 0-1 (default: 0.99)
%   MaxIterations    - Maximum Jacobi sweep iterations (default: 100)
%   Tolerance        - Convergence tolerance for off-diagonal energy (default: 1e-8)
%
% Outputs:
%   W - [K x C] unmixing matrix (K = number of components)
%   S - [T x K] estimated source signals
%   A - [C x K] mixing matrix (pseudoinverse of W)
%
% Algorithm:
%   1. Center and PCA-whiten the data
%   2. Compute symmetrized time-lagged covariance matrices C(tau)
%   3. Joint approximate diagonalization via Jacobi rotations
%   4. Construct unmixing/mixing matrices
%
% References:
%   Ziehe, A. & Muller, K.-R. (1998). TDSEP - an efficient algorithm for
%   blind separation using time structure. Proc. ICANN'98, 675-680.
%
% See also: pf2_base.signal, exploreFNIRS.hyperscanning.hbica

    p = inputParser;
    addRequired(p, 'X', @(v) isnumeric(v) && ismatrix(v));
    addParameter(p, 'Lags', [], @(v) isnumeric(v) && isvector(v));
    addParameter(p, 'NumComponents', 0, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'VarianceRetained', 0.99, @(v) isnumeric(v) && isscalar(v) && v > 0 && v <= 1);
    addParameter(p, 'MaxIterations', 100, @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'Tolerance', 1e-8, @(v) isnumeric(v) && isscalar(v) && v > 0);
    parse(p, X, varargin{:});
    opts = p.Results;

    [T, C] = size(X);

    if T < 3
        error('pf2_base:signal:tdsep', 'Need at least 3 time samples');
    end
    if C < 1
        error('pf2_base:signal:tdsep', 'Need at least 1 channel');
    end

    % Default lags
    lags = opts.Lags;
    if isempty(lags)
        lags = 1:min(100, floor(T/2));
    end
    lags = lags(:)';
    lags = lags(lags > 0 & lags < T);
    if isempty(lags)
        error('pf2_base:signal:tdsep', 'No valid lags after filtering');
    end

    % Step 1: Center
    mu = mean(X, 1);
    Xc = X - mu;

    % Step 2: PCA whitening
    covX = (Xc' * Xc) / (T - 1);
    [V, D] = eig(covX);
    eigvals = diag(D);

    % Sort descending
    [eigvals, sortIdx] = sort(eigvals, 'descend');
    V = V(:, sortIdx);

    % Remove near-zero eigenvalues
    eigvals = max(eigvals, 0);
    validIdx = eigvals > eps * max(eigvals) * C;

    % Determine number of components
    if opts.NumComponents > 0
        K = min(opts.NumComponents, sum(validIdx));
    else
        % Use variance retained threshold
        totalVar = sum(eigvals(validIdx));
        cumVar = cumsum(eigvals(validIdx)) / totalVar;
        K = find(cumVar >= opts.VarianceRetained, 1, 'first');
        if isempty(K)
            K = sum(validIdx);
        end
    end

    K = max(K, 1);
    K = min(K, min(T-1, C));

    % Whitening matrix
    Vk = V(:, 1:K);
    Dk = eigvals(1:K);
    whiteM = diag(1 ./ sqrt(Dk)) * Vk';  % [K x C]

    % Whitened data
    Z = Xc * whiteM';  % [T x K]

    % Step 3: Compute time-lagged covariance matrices
    nLags = length(lags);
    Ctau = zeros(K, K, nLags);

    for iLag = 1:nLags
        tau = lags(iLag);
        Z1 = Z(1:T-tau, :);
        Z2 = Z(tau+1:T, :);
        Craw = (Z1' * Z2) / (T - tau);
        % Symmetrize
        Ctau(:,:,iLag) = (Craw + Craw') / 2;
    end

    % Step 4: Joint approximate diagonalization (Jacobi rotations)
    R = eye(K);

    for iter = 1:opts.MaxIterations
        offDiagSum = 0;

        for pp = 1:K-1
            for qq = pp+1:K
                % Compute optimal Givens rotation angle for (pp,qq) pair
                % across all lag matrices
                h11 = 0; h12 = 0; h22 = 0;

                for iLag = 1:nLags
                    Cij = Ctau(pp,qq,iLag);
                    Dii = Ctau(pp,pp,iLag);
                    Djj = Ctau(qq,qq,iLag);

                    offDiagSum = offDiagSum + Cij^2;

                    % Accumulate for Givens angle
                    d = Dii - Djj;
                    h11 = h11 + d^2;
                    h12 = h12 + d * Cij;
                    h22 = h22 + Cij^2;
                end

                % Compute angle from 2x2 eigenvalue problem
                % Maximize diag energy: solve for theta from
                % [h11 h12; h12 h22] eigenvalue
                if h11 == h22
                    theta = pi/4 * sign(h12);
                else
                    theta = 0.5 * atan2(2 * h12, h11 - h22);
                end

                c = cos(theta);
                s = sin(theta);

                if abs(s) < eps
                    continue;
                end

                % Apply Givens rotation to all Ctau matrices
                for iLag = 1:nLags
                    rowP = Ctau(pp,:,iLag);
                    rowQ = Ctau(qq,:,iLag);
                    Ctau(pp,:,iLag) =  c * rowP + s * rowQ;
                    Ctau(qq,:,iLag) = -s * rowP + c * rowQ;

                    colP = Ctau(:,pp,iLag);
                    colQ = Ctau(:,qq,iLag);
                    Ctau(:,pp,iLag) =  c * colP + s * colQ;
                    Ctau(:,qq,iLag) = -s * colP + c * colQ;
                end

                % Accumulate rotation
                colP = R(:,pp);
                colQ = R(:,qq);
                R(:,pp) =  c * colP + s * colQ;
                R(:,qq) = -s * colP + c * colQ;
            end
        end

        % Check convergence (relative off-diagonal energy)
        totalEnergy = 0;
        for iLag = 1:nLags
            totalEnergy = totalEnergy + sum(Ctau(:,:,iLag).^2, 'all');
        end
        if totalEnergy < eps
            break;
        end
        relOff = offDiagSum / totalEnergy;

        if relOff < opts.Tolerance
            break;
        end
    end

    % Step 5: Construct output matrices
    % W maps from original channels to sources: S = X_centered * W'
    W = R' * whiteM;       % [K x C]
    S = Xc * W';           % [T x K]
    A = pinv(W);            % [C x K]
end
