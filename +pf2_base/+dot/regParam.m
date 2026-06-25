function [lambda, curve] = regParam(d, b, varargin)
% REGPARAM Choose the Tikhonov regularization parameter (GCV or L-curve)
%
% Selects the regularization weight lambda for a depth-weighted minimum-norm
% DOT inverse, working from the eigenspectrum of the (small) measurement-space
% normal matrix M = A*C*A' rather than the full image-space system. Supports
% generalized cross-validation (GCV, default) and L-curve corner selection.
%
% Syntax:
%   lambda = pf2_base.dot.regParam(d, b)
%   [lambda, curve] = pf2_base.dot.regParam(d, b, 'Method', 'lcurve')
%
% Inputs:
%   d - [n x 1] eigenvalues of M = A*C*A' (n = number of measurements/channels).
%   b - [n x 1] projection U'*y of the measurement onto M's eigenvectors. For
%       many time points, pass a representative column (e.g. the peak-variance
%       or mean response); lambda is shared across time.
%
% Inputs (name-value):
%   'Method'   - 'gcv' (default) or 'lcurve'.
%   'NLambda'  - Grid points (default 200).
%   'Range'    - [lo hi] multipliers on max(d) bounding the lambda grid
%                (default [1e-6, 1e2]).
%
% Outputs:
%   lambda - selected regularization parameter (same scale as d).
%   curve  - struct with .lambda (grid), .gcv or .residual/.solution norms,
%            and .method, for diagnostics/plotting.
%
% Algorithm:
%   With filter factors f_i(lambda) = d_i/(d_i+lambda):
%     residual^2(lambda) = sum_i (lambda/(d_i+lambda))^2 * b_i^2
%     GCV(lambda) = n * residual^2 / (sum_i lambda/(d_i+lambda))^2
%   GCV picks the minimizer. The L-curve option returns the maximum-curvature
%   corner of (log residual-norm, log solution-norm).
%
% References:
%   Arridge, S. R. (1999). Optical tomography in medical imaging. Inverse
%     Problems, 15(2), R41-R93. DOI: 10.1088/0266-5611/15/2/022
%
% Example:
%   M = full(A*spdiags(c,0,nV,nV)*A');
%   [U,Dg] = eig((M+M')/2); d = diag(Dg);
%   lambda = pf2_base.dot.regParam(d, U'*y);
%
% See also: pf2_base.dot.reconstructImage

p = inputParser;
addParameter(p, 'Method', 'gcv', @(x) any(strcmpi(x, {'gcv','lcurve'})));
addParameter(p, 'NLambda', 200, @(x) isnumeric(x) && isscalar(x) && x >= 10);
addParameter(p, 'Range', [1e-6, 1e2], @(x) isnumeric(x) && numel(x) == 2);
parse(p, varargin{:});
method = lower(p.Results.Method);

d = d(:);
b = b(:);
d = max(d, 0);
n = numel(d);
dmax = max(d);
if dmax <= 0
    lambda = eps;
    curve = struct('lambda', lambda, 'method', method);
    return;
end

lamGrid = logspace(log10(p.Results.Range(1) * dmax), ...
    log10(p.Results.Range(2) * dmax), p.Results.NLambda)';

resid2 = zeros(size(lamGrid));
soln2  = zeros(size(lamGrid));
df     = zeros(size(lamGrid));       % tr(I - H), residual degrees of freedom
for k = 1:numel(lamGrid)
    lam = lamGrid(k);
    fil = lam ./ (d + lam);          % residual filter (I - H)
    gain = d ./ (d + lam);           % solution filter H
    resid2(k) = sum((fil .* b).^2);
    % Image-space solution norm for the dual MNE x = A'(AA'+lam I)^-1 y:
    %   ||x||^2 = sum_i d_i/(d_i+lam)^2 * b_i^2 = sum_i gain^2/d_i * b_i^2.
    soln2(k)  = sum((gain.^2 ./ max(d, eps)) .* b.^2);
    df(k)     = sum(fil);
end

switch method
    case 'gcv'
        gcv = n * resid2 ./ max(df.^2, eps);
        [~, ix] = min(gcv);
        lambda = lamGrid(ix);
        curve = struct('lambda', lamGrid, 'gcv', gcv, 'method', 'gcv');
    case 'lcurve'
        rho = 0.5 * log(max(resid2, eps));
        eta = 0.5 * log(max(soln2, eps));
        % Discrete curvature; pick the maximum-curvature corner.
        drho = gradient(rho); deta = gradient(eta);
        d2rho = gradient(drho); d2eta = gradient(deta);
        kappa = (drho .* d2eta - deta .* d2rho) ./ ...
            max((drho.^2 + deta.^2).^1.5, eps);
        [~, ix] = max(kappa);
        lambda = lamGrid(ix);
        curve = struct('lambda', lamGrid, 'residual', sqrt(resid2), ...
            'solution', sqrt(soln2), 'curvature', kappa, 'method', 'lcurve');
end

if ix == 1 || ix == numel(lamGrid)
    warning('pf2:dot:regParam:boundary', ...
        ['Selected lambda is at the search-grid boundary; the optimum may lie ' ...
         'outside the [%g, %g]*max(eig) range. Consider widening ''Range''.'], ...
        p.Results.Range(1), p.Results.Range(2));
end
end
