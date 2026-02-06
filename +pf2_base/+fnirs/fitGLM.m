function results = fitGLM(Y, X, regressorNames, varargin)
% FITGLM Fit general linear model to fNIRS channel data
%
% Solves the GLM equation Y = X*beta + epsilon for each channel using OLS
% or autoregressive iteratively reweighted least squares (AR-IRLS). Returns
% beta estimates, t-statistics, p-values, and optional contrast results.
% AR-IRLS accounts for temporal autocorrelation in fNIRS residuals by
% prewhitening with estimated AR coefficients.
%
% Reference:
%   Barker, J. W., Aarabi, A., & Huppert, T. J. (2013). Autoregressive
%   model based algorithm for correcting motion and serially correlated
%   errors in fNIRS. Biomedical Optics Express, 4(8), 1366-1379.
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
%
% Outputs:
%   results - Struct with fields:
%     .beta       - Regression coefficients [P x C]
%     .tstat      - T-statistics for each beta [P x C]
%     .pval       - Two-tailed p-values [P x C]
%     .se         - Standard errors [P x C]
%     .residuals  - Residual time series [T x C]
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
p.parse(Y, X, regressorNames, varargin{:});

method = upper(p.Results.Method);
C = p.Results.Contrasts;
contrastNames = p.Results.ContrastNames;
arOrder = p.Results.AROrder;
maxIter = p.Results.MaxIter;
tol = p.Results.Tolerance;

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

% --- Fit model ---
switch method
    case 'OLS'
        [beta, residuals, se, dof] = fitOLS(Y, X);

    case 'AR-IRLS'
        [beta, residuals, se, dof] = fitARIRLS(Y, X, arOrder, maxIter, tol);
end

% --- Compute statistics ---
tstat = beta ./ se;
pval = 2 * tcdf(-abs(tstat), dof);

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
if ~isempty(C)
    results.contrast = computeContrasts(C, contrastNames, beta, se, X, dof, residuals);
end

end

%%_Subfunctions_________________________________________________________

function [beta, residuals, se, dof] = fitOLS(Y, X)
% FITOLS Ordinary least squares estimation
%
% Inputs:
%   Y - Data matrix [T x C]
%   X - Design matrix [T x P]
%
% Outputs:
%   beta      - Coefficients [P x C]
%   residuals - Residuals [T x C]
%   se        - Standard errors [P x C]
%   dof       - Degrees of freedom [scalar]

[T, ~] = size(Y);
P = size(X, 2);

% Solve via pseudoinverse
Xpinv = pinv(X);
beta = Xpinv * Y;
residuals = Y - X * beta;

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

function [beta, residuals, se, dof] = fitARIRLS(Y, X, arOrder, maxIter, tol)
% FITARIRLS Autoregressive iteratively reweighted least squares
%
% Inputs:
%   Y       - Data matrix [T x C]
%   X       - Design matrix [T x P]
%   arOrder - AR model order [scalar]
%   maxIter - Maximum iterations [scalar]
%   tol     - Convergence tolerance [scalar]
%
% Outputs:
%   beta      - Coefficients [P x C]
%   residuals - Residuals [T x C]
%   se        - Standard errors [P x C]
%   dof       - Effective degrees of freedom [scalar]

[T, nCh] = size(Y);
P = size(X, 2);

% Initial OLS
[beta, residuals, ~, ~] = fitOLS(Y, X);

prevBeta = beta;

for iter = 1:maxIter
    % Estimate AR coefficients from residuals (per channel, then average)
    arCoeffs = zeros(arOrder, nCh);
    for ch = 1:nCh
        r = residuals(:, ch);
        r = r(~isnan(r));
        if length(r) > arOrder + 1
            arCoeffs(:, ch) = yulewalk(r, arOrder);
        end
    end
    % Use mean AR coefficients across channels for consistent prewhitening
    meanAR = mean(arCoeffs, 2);

    % Build prewhitening filter matrix
    Yw = applyARFilter(Y, meanAR);
    Xw = applyARFilter(X, meanAR);

    % Re-fit OLS on prewhitened data
    [beta, residuals_w, se, dof] = fitOLS(Yw, Xw);

    % Compute residuals in original space
    residuals = Y - X * beta;

    % Check convergence
    betaChange = max(abs(beta(:) - prevBeta(:)));
    if betaChange < tol
        break;
    end
    prevBeta = beta;
end

% Adjust DOF for AR parameters
dof = max(T - P - arOrder, 1);

end

function a = yulewalk(r, order)
% YULEWALK Estimate AR coefficients via Yule-Walker equations
%
% Inputs:
%   r     - Residual signal [T x 1]
%   order - AR model order [scalar]
%
% Outputs:
%   a - AR coefficients [order x 1]

r = r(:);
N = length(r);

% Compute autocorrelation
R = zeros(order + 1, 1);
for k = 0:order
    R(k+1) = sum(r(1:N-k) .* r(k+1:N)) / N;
end

% Build Toeplitz system
Rmat = toeplitz(R(1:order));
rvec = R(2:order+1);

% Solve Yule-Walker equations
if rcond(Rmat) > eps
    a = Rmat \ rvec;
else
    a = zeros(order, 1);
end

end

function Yw = applyARFilter(Y, arCoeffs)
% APPLYARFILTER Prewhiten data using AR coefficients
%
% Inputs:
%   Y        - Data [T x C]
%   arCoeffs - AR coefficients [order x 1]
%
% Outputs:
%   Yw - Prewhitened data [T x C]

[T, C] = size(Y);
order = length(arCoeffs);
Yw = Y;

for t = (order+1):T
    for k = 1:order
        Yw(t, :) = Yw(t, :) - arCoeffs(k) * Y(t-k, :);
    end
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
cPval = 2 * tcdf(-abs(cTstat), dof);

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
