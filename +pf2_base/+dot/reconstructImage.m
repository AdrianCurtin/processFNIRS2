function [X, meta] = reconstructImage(A, Y, varargin)
% RECONSTRUCTIMAGE Depth-weighted Tikhonov minimum-norm DOT inverse
%
% Solves the linear DOT inverse problem y = A*x for the image x given the
% forward sensitivity operator A, using a regularized minimum-norm estimator
% with optional depth compensation. The estimator is evaluated in the dual
% (measurement) space, so cost scales with the number of channels, not the
% number of image voxels — many time points are reconstructed at once.
%
% Syntax:
%   X = pf2_base.dot.reconstructImage(A, Y)
%   [X, meta] = pf2_base.dot.reconstructImage(A, Y, 'DepthWeight', true)
%
% Inputs:
%   A - [m x nV] sensitivity matrix (channels x vertices), may be sparse.
%   Y - [m x T] measurements (one column per time point / condition).
%
% Inputs (name-value):
%   'DepthWeight'   - Compensate low surface-sensitivity at depth via a prior
%                     covariance C = diag(1/(cn^2 + (delta*max cn)^2)), cn =
%                     column norms of A (default true).
%   'DepthFloor'    - delta in the depth-weight denominator, as a fraction of
%                     max column norm (default 0.1; larger = gentler boost).
%   'Whiten'        - Channel whitening (default true): scale each measurement
%                     and its sensitivity row by 1/||A(row)|| so a few
%                     high-sensitivity (short-separation) channels do not
%                     dominate the inverse. Greatly sharpens localization.
%   'Lambda'        - Absolute Tikhonov parameter. Default [] selects it
%                     automatically (see 'RegMethod').
%   'LambdaFraction'- If set, use lambda = frac * max(eig(M)) instead of auto.
%   'RegMethod'     - 'gcv' (default) or 'lcurve' for automatic lambda.
%   'Subset'        - Vertex indices to reconstruct (others set 0). Used with
%                     RegOperator to restrict the image to the coverage support.
%   'RegOperator'   - Sparse regularization operator Gamma over the subset
%                     (e.g. a graph Laplacian for smoothness). When supplied,
%                     a generalized-Tikhonov primal solve is used instead of the
%                     depth-weighted minimum-norm dual path.
%
% Outputs:
%   X    - [nV x T] reconstructed image(s).
%   meta - struct: .lambda, .depthWeight, .whiten, .prior, .subset, .colNorm
%          (sensitivity column norms — computed AFTER whitening when Whiten is
%          on, i.e. norms of the whitened operator), .eig (d), .regCurve.
%
% Algorithm:
%   C = diag(c) (depth-weight prior covariance), M = A*C*A' (m x m).
%   Eigendecompose M = U*diag(d)*U'. Pick lambda (GCV/L-curve on d, U'*y_ref,
%   y_ref = highest-variance column of Y). Then
%     W = (M + lambda*I)^{-1} * Y,   X = C * A' * W = c .* (A' * W).
%
% References:
%   Arridge, S. R. (1999). Optical tomography in medical imaging. Inverse
%     Problems, 15(2), R41-R93. DOI: 10.1088/0266-5611/15/2/022
%   Gibson, A. P., Hebden, J. C. & Arridge, S. R. (2005). Recent advances in
%     diffuse optical imaging. Physics in Medicine and Biology, 50(4), R1-R43.
%     DOI: 10.1088/0031-9155/50/4/R01
%
% Example:
%   A = pf2.probe.forward.sensitivity(proc);
%   y = proc.HbO(120, :)';          % channels x 1 at one time point
%   x = pf2_base.dot.reconstructImage(A, y);
%
% See also: pf2_base.dot.regParam, pf2.probe.dot.reconstruct

p = inputParser;
addParameter(p, 'DepthWeight', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'DepthFloor', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Whiten', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Lambda', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'LambdaFraction', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'RegMethod', 'gcv', @(x) any(strcmpi(x, {'gcv','lcurve'})));
addParameter(p, 'Subset', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'RegOperator', [], @(x) isempty(x) || issparse(x) || isnumeric(x));
parse(p, varargin{:});
opt = p.Results;

[m, nV] = size(A);
if size(Y, 1) ~= m
    error('pf2:dot:reconstructImage:sizeMismatch', ...
        'Y must have %d rows (channels); got %d.', m, size(Y, 1));
end

% Channel whitening: rescale each measurement equation by 1/||A(row)|| so the
% reconstruction is not dominated by a handful of high-sensitivity (short
% separation) channels. The image x is unchanged — only the equations are
% reweighted — so X comes out in the original units.
if opt.Whiten
    rn = sqrt(full(sum(A.^2, 2)));
    rn(rn < eps) = eps;
    A = A ./ rn;
    Y = Y ./ rn;
end

% --- Generalized-Tikhonov primal path (smoothness / parcel priors) ---------
% When a regularization operator Gamma is supplied over a vertex subset, solve
% min ||A_s x - y||^2 + lambda ||Gamma x||^2 on that subset directly:
%   (A_s' A_s + lambda Gamma' Gamma) x = A_s' y.
if ~isempty(opt.RegOperator)
    sub = opt.Subset(:);
    if isempty(sub), sub = (1:nV)'; end
    As = A(:, sub);
    G = opt.RegOperator;
    AtA = As' * As;
    GtG = G' * G;
    nSub = size(AtA, 1);
    ridge = 1e-9 * (trace(AtA) / max(nSub, 1)) * speye(nSub);  % isolated-vertex guard
    yref = Y(:, refColumn(Y));
    bref = As' * yref;

    if ~isempty(opt.Lambda)
        lambda = opt.Lambda;
        regCurve = struct();
    elseif ~isempty(opt.LambdaFraction)
        % Scale by the spectral-norm ratio so LambdaFraction means the same
        % thing here as in the dual path (fraction of the operator norm).
        lambda = opt.LambdaFraction * (normest(AtA) / max(normest(GtG), eps));
        regCurve = struct();
    else
        % L-curve over the generalized Tikhonov problem: balance the data
        % residual ||As x - y|| against the prior seminorm ||G x||. Centre the
        % grid on the operator-norm ratio so it brackets the corner regardless
        % of operator scaling.
        s0 = max(normest(AtA), eps) / max(normest(GtG), eps);
        grid = s0 * logspace(-4, 6, 30)';
        rho = zeros(size(grid)); eta = zeros(size(grid));
        for k = 1:numel(grid)
            xk = (AtA + grid(k) * GtG + ridge) \ bref;
            rho(k) = log(max(norm(As * xk - yref), eps));
            eta(k) = log(max(norm(G * xk), eps));
        end
        lambda = lcurveCorner(grid, rho, eta);
        regCurve = struct('lambda', grid, 'residual', exp(rho), 'solution', exp(eta));
    end

    Xsub = (AtA + lambda * GtG + ridge) \ (As' * Y);
    X = zeros(nV, size(Y, 2));
    X(sub, :) = Xsub;
    meta = struct('lambda', lambda, 'depthWeight', false, 'whiten', opt.Whiten, ...
        'prior', 'operator', 'subset', sub, 'colNorm', [], 'eig', [], ...
        'regCurve', regCurve);
    return;
end

% Depth-weight prior covariance C = diag(c).
cn = sqrt(full(sum(A.^2, 1)))';      % column norms [nV x 1]
if opt.DepthWeight
    delta = opt.DepthFloor * max(cn);
    c = 1 ./ (cn.^2 + delta.^2);
    c = c / max(c);                  % normalize so max prior variance = 1
else
    c = ones(nV, 1);
end

% Measurement-space normal matrix M = A*C*A' (m x m).
Ac = A .* c';                        % column-scaled (sparse-safe)
M = full(Ac * A');
M = (M + M') / 2;                    % symmetrize

[U, Dg] = eig(M);
d = max(real(diag(Dg)), 0);

% Reference column for lambda selection: highest-energy time point.
[~, ref] = max(sum(Y.^2, 1));
yref = Y(:, ref);

regCurve = struct();
if ~isempty(opt.Lambda)
    lambda = opt.Lambda;
elseif ~isempty(opt.LambdaFraction)
    lambda = opt.LambdaFraction * max(d);
else
    [lambda, regCurve] = pf2_base.dot.regParam(d, U' * yref, ...
        'Method', opt.RegMethod);
end

% Solve (M + lambda I) W = Y via the eigenbasis, then back-project.
filt = 1 ./ (d + lambda);
W = U * (filt .* (U' * Y));          % [m x T]
X = c .* (A' * W);                   % [nV x T]

meta = struct('lambda', lambda, 'depthWeight', opt.DepthWeight, ...
    'whiten', opt.Whiten, 'prior', 'minnorm', 'subset', [], ...
    'colNorm', cn, 'eig', d, 'regCurve', regCurve);
end

function r = refColumn(Y)
% Index of the highest-variance column (the frame used to pick lambda).
[~, r] = max(sum(Y.^2, 1));
end

function lambda = lcurveCorner(grid, rho, eta)
% Maximum-curvature corner of the (log-residual, log-solution) L-curve.
drho = gradient(rho); deta = gradient(eta);
d2rho = gradient(drho); d2eta = gradient(deta);
kappa = (drho .* d2eta - deta .* d2rho) ./ ...
    max((drho.^2 + deta.^2).^1.5, eps);
[~, ix] = max(kappa);
lambda = grid(ix);
end
