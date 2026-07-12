function results = fitGLM(Y, X, regressorNames, varargin)
% FITGLM Fit general linear model to fNIRS channel data
%
% Solves the GLM equation Y = X*beta + epsilon for each channel using OLS
% or autoregressive iteratively reweighted least squares (AR-IRLS). Returns
% beta estimates, t-statistics, p-values, and optional contrast results.
% AR-IRLS accounts for temporal autocorrelation in fNIRS residuals by
% prewhitening with estimated AR coefficients.
%
% References:
%   Barker, J. W., Aarabi, A., & Huppert, T. J. (2013). Autoregressive
%   model based algorithm for correcting motion and serially correlated
%   errors in fNIRS. Biomedical Optics Express, 4(8), 1366-1379.
%
%   Huppert, T. J. (2016). Commentary on the statistical properties of
%   noise and its implication on general linear models in functional
%   near-infrared spectroscopy. Neurophotonics, 3(1), 010401.
%   DOI: 10.1117/1.NPh.3.1.010401
%
% Syntax:
%   results = pf2_base.fnirs.fitGLM(Y, X, regressorNames)
%   results = pf2_base.fnirs.fitGLM(Y, X, regressorNames, 'Name', Value)
%
% Inputs:
%   Y              - Channel data [T x C] (one biomarker, e.g. HbO)
%   X              - Design matrix [T x P] from buildDesignMatrix
%   regressorNames - Cell array {1 x P} of regressor labels
%
% Name-Value Parameters:
%   'Method'        - Estimation method: 'OLS' (default) or 'AR-IRLS'
%   'Contrasts'     - Contrast matrix [K x P] (default: [])
%                     Each row defines a linear combination of betas to test.
%   'ContrastNames' - Cell array {1 x K} of contrast labels (default: {})
%   'AROrder'       - AR model order for AR-IRLS (default: 4)
%   'MaxIter'       - Maximum iterations for AR-IRLS (default: 20)
%   'Tolerance'     - Convergence tolerance for AR-IRLS (default: 1e-4)
%   'Accelerate'    - Acceleration mode: 'auto' (default), 'gpu', 'none'
%                     'auto' uses GPU for OLS when T*C > 50000 elements.
%
% Outputs:
%   results - Struct with fields:
%     .beta       - Regression coefficients [P x C]
%     .tstat      - T-statistics for each beta [P x C]
%     .pval       - Two-tailed p-values [P x C]
%     .se         - Standard errors [P x C]
%     .residuals  - Residual time series [T x C] (original space, unwhitened)
%     .R2         - Coefficient of determination [1 x C]
%     .dof        - Degrees of freedom [scalar]
%     .method     - Estimation method used [char]
%     .contrast   - Struct (if Contrasts provided) with fields:
%                   .beta [K x C], .tstat [K x C], .pval [K x C],
%                   .se [K x C], .names {1 x K}
%
% Algorithm (OLS):
%   1. beta = pinv(X) * Y
%   2. residuals = Y - X * beta
%   3. MSE = sum(residuals.^2) / (T - P)
%   4. se = sqrt(diag(MSE * inv(X'*X)))
%   5. t = beta ./ se, p = 2*tcdf(-abs(t), T-P)
%
% Algorithm (AR-IRLS):
%   1. Initial OLS fit
%   2. Estimate AR(p) coefficients from residuals (Yule-Walker)
%   3. Build prewhitening filter from AR coefficients
%   4. Prewhiten Y and X
%   5. Re-fit OLS on prewhitened data
%   6. Repeat steps 2-5 until convergence or MaxIter
%
% Example:
%   events(1) = struct('name', 'TaskA', 'onsets', [10 40 70], 'duration', 20);
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);
%   results = pf2_base.fnirs.fitGLM(data.HbO, X, names);
%   fprintf('TaskA beta: %.4f, p = %.4f\n', results.beta(1,1), results.pval(1,1));
%
% See also: pf2_base.fnirs.buildDesignMatrix, pf2_base.fnirs.buildHRF

% --- Parse inputs ---
p = inputParser;
p.addRequired('Y', @isnumeric);
p.addRequired('X', @isnumeric);
p.addRequired('regressorNames', @iscell);
p.addParameter('Method', 'OLS', @(x) ismember(upper(x), {'OLS', 'AR-IRLS'}));
p.addParameter('Contrasts', [], @isnumeric);
p.addParameter('ContrastNames', {}, @iscell);
p.addParameter('AROrder', 4, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('MaxIter', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Tolerance', 1e-4, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Accelerate', 'auto', @(x) ischar(x) && ismember(lower(x), {'auto','gpu','none'}));
p.parse(Y, X, regressorNames, varargin{:});

method = upper(p.Results.Method);
C = p.Results.Contrasts;
contrastNames = p.Results.ContrastNames;
arOrder = p.Results.AROrder;
maxIter = p.Results.MaxIter;
tol = p.Results.Tolerance;
accelMode = lower(p.Results.Accelerate);

[T, nCh] = size(Y);
P = size(X, 2);

if size(X, 1) ~= T
    error('pf2:fitGLM:sizeMismatch', ...
        'Y has %d rows but X has %d rows.', T, size(X, 1));
end

if length(regressorNames) ~= P
    error('pf2:fitGLM:namesMismatch', ...
        'regressorNames has %d entries but X has %d columns.', ...
        length(regressorNames), P);
end

% Determine GPU usage
useGPU = false;
switch accelMode
    case 'auto'
        gpuInfo = pf2_base.accel.isGPUAvailable();
        if gpuInfo.available
            if strcmp(method, 'AR-IRLS')
                % AR-IRLS iterates many times, so GPU pays off at lower sizes
                useGPU = (T * nCh > 10000);
            else
                useGPU = (T * nCh > 50000);
            end
        end
    case 'gpu'
        useGPU = true;
    case 'none'
        % serial CPU
end

% --- Fit model ---
% Xw and residuals_w hold prewhitened versions (AR-IRLS) or original (OLS)
switch method
    case 'OLS'
        [beta, residuals, se, dof] = fitOLS(Y, X, useGPU);
        Xw = X;
        residuals_w = residuals;

    case 'AR-IRLS'
        [beta, residuals, se, dof, Xw, residuals_w] = fitARIRLS(Y, X, arOrder, maxIter, tol, useGPU);
end

% --- Compute statistics ---
tstat = beta ./ se;
pval = 2 * pf2_base.compat.tcdf(-abs(tstat), dof);

% R-squared
SSres = sum(residuals.^2, 1);
SStot = sum((Y - mean(Y, 1)).^2, 1);
R2 = 1 - SSres ./ SStot;

% --- Pack results ---
results.beta = beta;
results.tstat = tstat;
results.pval = pval;
results.se = se;
results.residuals = residuals;
results.R2 = R2;
results.dof = dof;
results.method = method;
results.regressorNames = regressorNames;

% --- Contrast testing ---
% Use prewhitened X and residuals so contrast SEs are consistent with
% the main-effect SEs (critical for AR-IRLS where original-space
% residuals would produce anti-conservative p-values).
% Note: results.residuals stores original-space residuals (for
% diagnostics/plotting), while contrasts use prewhitened residuals
% (for valid statistical inference under AR-IRLS).
if ~isempty(C)
    results.contrast = computeContrasts(C, contrastNames, beta, se, Xw, dof, residuals_w);
end

end

%%_Subfunctions_________________________________________________________

function [beta, residuals, se, dof] = fitOLS(Y, X, useGPU)
% FITOLS Ordinary least squares estimation
%
% Inputs:
%   Y      - Data matrix [T x C]
%   X      - Design matrix [T x P]
%   useGPU - Whether to use GPU for matrix operations
%
% Outputs:
%   beta      - Coefficients [P x C]
%   residuals - Residuals [T x C]
%   se        - Standard errors [P x C]
%   dof       - Degrees of freedom [scalar]

[T, ~] = size(Y);
P = size(X, 2);

% Optionally transfer to GPU
if useGPU
    [Yg, onGPU] = pf2_base.accel.toGPU(Y, 'Force', true);
    if onGPU
        Xg = gpuArray(X);
    else
        Xg = X;
        Yg = Y;
    end
else
    Yg = Y;
    Xg = X;
end

% Solve via pseudoinverse
Xpinv = pinv(Xg);
beta = Xpinv * Yg;
residuals = Yg - Xg * beta;

% Gather from GPU
beta = pf2_base.accel.gather(beta);
residuals = pf2_base.accel.gather(residuals);

% Degrees of freedom
dof = T - P;

% Mean squared error per channel
MSE = sum(residuals.^2, 1) / dof;

% Covariance of betas: inv(X'X) * MSE
XtXinv = pinv(X' * X);
varBeta = diag(XtXinv);  % [P x 1]

% Standard errors: sqrt(var(beta_j) * MSE_c) for each channel
se = sqrt(varBeta * MSE);  % [P x C]

end

function [beta, residuals, se, dof, Xw, residuals_w] = fitARIRLS(Y, X, arOrder, maxIter, tol, useGPU)
% FITARIRLS Autoregressive iteratively reweighted least squares
%
% When GPU is enabled, data is transferred once at the start and kept on
% GPU throughout all iterations. Only the small Yule-Walker solve (AR order
% x AR order per channel) runs on CPU. Final results are gathered at the
% end, avoiding per-iteration GPU<->CPU transfers.
%
% Inputs:
%   Y       - Data matrix [T x C]
%   X       - Design matrix [T x P]
%   arOrder - AR model order [scalar]
%   maxIter - Maximum iterations [scalar]
%   tol     - Convergence tolerance [scalar]
%   useGPU  - Whether to use GPU acceleration
%
% Outputs:
%   beta        - Coefficients [P x C]
%   residuals   - Residuals [T x C] (original space)
%   se          - Standard errors [P x C]
%   dof         - Effective degrees of freedom [scalar]
%   Xw          - Prewhitened design matrix [T x P]
%   residuals_w - Prewhitened residuals [T x C]

[T, nCh] = size(Y);
P = size(X, 2);

% Transfer to GPU once at the start (if requested)
if useGPU
    [Yg, onGPU] = pf2_base.accel.toGPU(Y, 'Force', true);
    if onGPU
        Xg = gpuArray(X);
    else
        Yg = Y;
        Xg = X;
        useGPU = false;
    end
else
    Yg = Y;
    Xg = X;
end

% Initial OLS (inline to stay on GPU)
Xpinv = pinv(Xg);
beta = Xpinv * Yg;
residuals = Yg - Xg * beta;
prevBeta = beta;

for iter = 1:maxIter
    % AR estimation needs CPU (small Toeplitz systems)
    arCoeffs = yulewalkMulti(pf2_base.accel.gather(residuals), arOrder);
    meanAR = mean(arCoeffs, 2);

    % Prewhiten (works transparently on gpuArrays)
    Yw = applyARFilter(Yg, meanAR);
    Xw = applyARFilter(Xg, meanAR);

    % Re-fit OLS on prewhitened data (inline)
    beta = pinv(Xw) * Yw;

    % Residuals in original space (stays on GPU)
    residuals = Yg - Xg * beta;

    % Convergence check
    betaChange = max(abs( ...
        pf2_base.accel.gather(beta(:)) - pf2_base.accel.gather(prevBeta(:))));
    if betaChange < tol
        break;
    end
    prevBeta = beta;
end

% Final statistics from prewhitened fit
dof = max(T - P - arOrder, 1);
residuals_w = Yw - Xw * beta;
MSE = sum(residuals_w.^2, 1) / dof;
XwXwinv = pinv(Xw' * Xw);
varBeta = diag(XwXwinv);  % [P x 1]
se = sqrt(varBeta * MSE);  % [P x C]

% Final residuals in original space
residuals = Yg - Xg * beta;

% Gather from GPU
beta = pf2_base.accel.gather(beta);
residuals = pf2_base.accel.gather(residuals);
se = pf2_base.accel.gather(se);
Xw = pf2_base.accel.gather(Xw);
residuals_w = pf2_base.accel.gather(residuals_w);

end

function arCoeffs = yulewalkMulti(residuals, order)
% YULEWALKMULTI Vectorized Yule-Walker AR estimation across channels
%
% Computes autocorrelation for all channels simultaneously, then solves
% per-channel Toeplitz systems (small order x order, not worth vectorizing).
%
% Inputs:
%   residuals - [T x C] residual matrix
%   order     - AR model order [scalar]
%
% Outputs:
%   arCoeffs  - [order x C] AR coefficients

[T, nCh] = size(residuals);
arCoeffs = zeros(order, nCh);

% Vectorized autocorrelation across all channels
R_all = zeros(order + 1, nCh);
for k = 0:order
    R_all(k+1, :) = sum(residuals(1:T-k, :) .* residuals(k+1:T, :), 1) / T;
end

% Per-channel Toeplitz solve (small system: order x order)
for ch = 1:nCh
    R = R_all(:, ch);
    if any(isnan(R))
        continue;
    end
    Rmat = toeplitz(R(1:order));
    rvec = R(2:order+1);
    if rcond(Rmat) > eps
        arCoeffs(:, ch) = Rmat \ rvec;
    end
end

end

function Yw = applyARFilter(Y, arCoeffs)
% APPLYARFILTER Vectorized prewhitening using AR coefficients
%
% Applies the AR filter across all columns simultaneously. The inner
% loop iterates only over the AR order (typically 4), not over time
% samples, making this much faster than the naive triple-nested loop.
%
% Inputs:
%   Y        - Data [T x C]
%   arCoeffs - AR coefficients [order x 1]
%
% Outputs:
%   Yw - Prewhitened data [T x C]

[T, ~] = size(Y);
order = length(arCoeffs);
Yw = Y;

% Vectorized: loop over AR order only (typically 4 iterations)
for k = 1:order
    Yw((order+1):T, :) = Yw((order+1):T, :) - arCoeffs(k) * Y((order+1-k):(T-k), :);
end

% Zero out the first 'order' rows (not reliably filtered)
Yw(1:order, :) = 0;

end

function contrast = computeContrasts(C, contrastNames, beta, se, X, dof, residuals)
% COMPUTECONTRASTS Compute contrast statistics
%
% Inputs:
%   C             - Contrast matrix [K x P]
%   contrastNames - Cell array {1 x K}
%   beta          - Coefficients [P x C]
%   se            - Standard errors [P x C]
%   X             - Design matrix [T x P]
%   dof           - Degrees of freedom [scalar]
%   residuals     - Residuals [T x C]
%
% Outputs:
%   contrast - Struct with .beta, .tstat, .pval, .se, .names

[K, P] = size(C);
nCh = size(beta, 2);
T = size(X, 1);

% Contrast beta: c' * beta
cBeta = C * beta;  % [K x C]

% MSE per channel
MSE = sum(residuals.^2, 1) / dof;

% Variance of contrast: c' * inv(X'X) * c * MSE
XtXinv = pinv(X' * X);
cSe = zeros(K, nCh);
for k = 1:K
    cVar = C(k, :) * XtXinv * C(k, :)';  % scalar
    cSe(k, :) = sqrt(cVar * MSE);
end

cTstat = cBeta ./ cSe;
cPval = 2 * pf2_base.compat.tcdf(-abs(cTstat), dof);

% Default contrast names
if isempty(contrastNames) || length(contrastNames) ~= K
    contrastNames = cell(1, K);
    for k = 1:K
        contrastNames{k} = sprintf('contrast_%d', k);
    end
end

contrast.beta = cBeta;
contrast.tstat = cTstat;
contrast.pval = cPval;
contrast.se = cSe;
contrast.names = contrastNames;

end
