function results = fitGLM(Y, X, regressorNames, varargin)
% FITGLM Fit general linear model to fNIRS channel data
%
% Solves the GLM equation Y = X*beta + epsilon for each channel using OLS
% or autoregressive iteratively reweighted least squares (AR-IRLS). Returns
% beta estimates, t-statistics, p-values, and optional contrast results.
% AR-IRLS accounts for temporal autocorrelation in fNIRS residuals by
% prewhitening with estimated AR coefficients pooled across channels.
%
% AR order selection: The whitening AR model is fit via Yule-Walker and the
% coefficients are POOLED across channels (mean over channels) before
% prewhitening. When AROrder='auto', a single order is selected by minimising
% the median BIC across channels over the candidate range 1..round(fs/2),
% then the pooled whitening is refit at that order. The selected order is
% stored in results.arOrder for reproducibility. This pooled architecture is
% intentional: a shared prewhitening filter is required for valid contrast
% SE computation in the prewhitened space (Barker et al. 2013).
%
% References:
%   Barker, J. W., Aarabi, A., & Huppert, T. J. (2013). Autoregressive
%   model based algorithm for correcting motion and serially correlated
%   errors in fNIRS. Biomedical Optics Express, 4(8), 1366-1379.
%   DOI: 10.1364/BOE.4.001366
%
%   Huppert, T. J. (2016). Commentary on the statistical properties of
%   noise and its implication on general linear models in functional
%   near-infrared spectroscopy. Neurophotonics, 3(1), 010401.
%   DOI: 10.1117/1.NPh.3.1.010401
%
%   Schwarz, G. (1978). Estimating the Dimension of a Model. The Annals of
%   Statistics, 6(2), 461-464. DOI: 10.1214/aos/1176344136
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
%                     May also be 'auto' (char or scalar string), in which
%                     case BIC is minimised over 1..round(fs/2) to select a
%                     single order applied uniformly to all channels. BIC is
%                     preferred over AIC at the modest run lengths typical in
%                     fNIRS to avoid overfitting (Schwarz 1978). Requires 'fs'
%                     when 'auto'.
%                     NOTE: at very low sampling rates (fs <= 2 Hz, e.g. heavily
%                     downsampled data) round(fs/2) collapses the search to
%                     order 1; pass an explicit integer AROrder in that regime.
%                     AROrder only affects Method='AR-IRLS' (it configures the
%                     prewhitening filter). If Method='OLS' and an AROrder is
%                     explicitly supplied, it has no effect and is ignored
%                     with a pf2:fitGLM:arOrderIgnored warning rather than
%                     being applied or raising an error.
%   'fs'            - Sampling frequency in Hz (default: [])
%                     Required when AROrder='auto' to bound the candidate range.
%                     Ignored when AROrder is a fixed integer.
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
%     .dof        - Degrees of freedom [scalar]. Computed from the design's
%                   EFFECTIVE RANK (not raw column count P) so rank-deficient
%                   designs (e.g. an FIR basis with fewer samples than stick
%                   regressors) cannot drive dof negative; always >= 1. A
%                   pf2:fitGLM:rankDeficient warning is emitted when the
%                   design is rank-deficient. If the unclamped dof (T minus
%                   effective rank, minus AR order for AR-IRLS) is <= 0,
%                   .tstat/.pval (and any .contrast.tstat/.contrast.pval) are
%                   NaN, since they are not statistically identifiable;
%                   .beta is still the pinv minimum-norm solution.
%     .method     - Estimation method used [char]
%     .arOrder    - AR order used (scalar; present only for AR-IRLS)
%     .contrast   - Struct (if Contrasts provided) with fields:
%                   .beta [K x C], .tstat [K x C], .pval [K x C],
%                   .se [K x C], .names {1 x K}
%
% Algorithm (OLS):
%   1. beta = pinv(X) * Y
%   2. residuals = Y - X * beta
%   3. r = rank(X); dof = max(T - r, 1) (warn if r < P, i.e. rank-deficient)
%   4. MSE = sum(residuals.^2) / dof
%   5. se = sqrt(diag(MSE * inv(X'*X)))
%   6. t = beta ./ se, p = 2*tcdf(-abs(t), dof); NaN if T - r <= 0
%
% Algorithm (AR-IRLS):
%   1. Initial OLS fit
%   2. If AROrder='auto': select order by median BIC over channels
%   3. Estimate AR(p) coefficients from residuals (Yule-Walker) and pool
%      across channels (mean over channels) to form a shared filter
%   4. Prewhiten Y and X with the pooled filter
%   5. Re-fit OLS on prewhitened data
%   6. Repeat steps 3-5 until convergence or MaxIter
%   7. r = rank(Xw) (effective rank of the prewhitened design);
%      dof = max(T - r - AROrder, 1) (warn if r < P); NaN t/p if the
%      unclamped T - r - AROrder <= 0
%
% Example:
%   events(1) = struct('name', 'TaskA', 'onsets', [10 40 70], 'duration', 20);
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);
%   results = pf2_base.fnirs.fitGLM(data.HbO, X, names);
%   fprintf('TaskA beta: %.4f, p = %.4f\n', results.beta(1,1), results.pval(1,1));
%
%   % Automatic AR order selection via BIC
%   results = pf2_base.fnirs.fitGLM(data.HbO, X, names, ...
%       'Method', 'AR-IRLS', 'AROrder', 'auto', 'fs', data.fs);
%   fprintf('Selected AR order: %d\n', results.arOrder);
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
p.addParameter('AROrder', 4, @(x) (isnumeric(x) && isscalar(x) && x > 0) || ...
    ((ischar(x) || isstring(x)) && isscalar(string(x)) && strcmpi(x, 'auto')));
p.addParameter('fs', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.addParameter('MaxIter', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Tolerance', 1e-4, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Accelerate', 'auto', @(x) ischar(x) && ismember(lower(x), {'auto','gpu','none'}));
p.parse(Y, X, regressorNames, varargin{:});

method = upper(p.Results.Method);
C = p.Results.Contrasts;
contrastNames = p.Results.ContrastNames;
arOrder = p.Results.AROrder;
fs_val = p.Results.fs;
maxIter = p.Results.MaxIter;
tol = p.Results.Tolerance;
accelMode = lower(p.Results.Accelerate);

% AROrder only affects Method='AR-IRLS' (it configures the prewhitening
% filter); OLS never uses it. If Method='OLS' and the caller explicitly
% supplied AROrder (fixed integer or 'auto'), ignore it with a warning
% instead of resolving 'auto' (which could otherwise error for lack of 'fs'
% or silently waste time selecting an order that is never used).
arOrderSupplied = ~ismember('AROrder', p.UsingDefaults);
autoOrder = (ischar(arOrder) || isstring(arOrder)) && strcmpi(arOrder, 'auto');

if strcmp(method, 'OLS')
    if arOrderSupplied
        warning('pf2:fitGLM:arOrderIgnored', ...
            ['AROrder only applies to Method=''AR-IRLS''; the supplied AROrder ' ...
             'has no effect under Method=''OLS'' and is ignored.']);
    end
    % autoOrder is intentionally not resolved here: OLS never uses arOrder.
elseif autoOrder
    % Resolve 'auto' AR order: requires fs to bound the candidate range
    if isempty(fs_val)
        error('pf2:fitGLM:autoOrderNeedsFs', ...
            'AROrder=''auto'' requires the ''fs'' parameter to bound the candidate range.');
    end
    % Candidate range: 1..round(fs/2). Bounded at T/4 as a stability guard.
    [T_check, ~] = size(Y);
    maxCand = min(round(fs_val / 2), floor(T_check / 4));
    maxCand = max(maxCand, 1);
    arOrder = selectAROrderBIC(Y, X, maxCand);
end

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
        [beta, residuals, se, dof, dofInvalid] = fitOLS(Y, X, useGPU);
        Xw = X;
        residuals_w = residuals;

    case 'AR-IRLS'
        [beta, residuals, se, dof, Xw, residuals_w, dofInvalid] = ...
            fitARIRLS(Y, X, arOrder, maxIter, tol, useGPU);
end

% --- Compute statistics ---
tstat = beta ./ se;
pval = 2 * pf2_base.compat.tcdf(-abs(tstat), dof);
if dofInvalid
    % The unclamped degrees of freedom (T minus the design's effective rank,
    % minus AR order for AR-IRLS) was <= 0 -- e.g. an FIR design with fewer
    % samples than stick regressors. dof was clamped to 1 above purely to
    % keep tcdf() from dividing by a non-positive dof; the resulting t/p
    % values are not statistically identifiable, so report them as NaN.
    % beta remains the pinv minimum-norm solution.
    tstat(:) = NaN;
    pval(:) = NaN;
end

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
if strcmp(method, 'AR-IRLS')
    results.arOrder = arOrder;  % scalar; documents the pooled whitening order
end

% --- Contrast testing ---
% Use prewhitened X and residuals so contrast SEs are consistent with
% the main-effect SEs (critical for AR-IRLS where original-space
% residuals would produce anti-conservative p-values).
% Note: results.residuals stores original-space residuals (for
% diagnostics/plotting), while contrasts use prewhitened residuals
% (for valid statistical inference under AR-IRLS).
if ~isempty(C)
    results.contrast = computeContrasts(C, contrastNames, beta, se, Xw, dof, residuals_w, dofInvalid);
end

end

%%_Subfunctions_________________________________________________________

function [beta, residuals, se, dof, dofInvalid] = fitOLS(Y, X, useGPU)
% FITOLS Ordinary least squares estimation
%
% Inputs:
%   Y      - Data matrix [T x C]
%   X      - Design matrix [T x P]
%   useGPU - Whether to use GPU for matrix operations
%
% Outputs:
%   beta       - Coefficients [P x C]
%   residuals  - Residuals [T x C]
%   se         - Standard errors [P x C]
%   dof        - Degrees of freedom [scalar], clamped to >= 1
%   dofInvalid - True if the unclamped dof (T - effective rank) was <= 0,
%                meaning t/p-values are not statistically identifiable

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

% Degrees of freedom: use the EFFECTIVE RANK of X, not the raw column count
% P. A rank-deficient design (e.g. an FIR basis with T < number of stick
% regressors) would otherwise drive T - P to zero or negative; pinv(X)
% above already returns the minimum-norm beta for such designs, so the
% residual dof must be computed from the rank actually used.
r = rank(X);
if r < P
    warning('pf2:fitGLM:rankDeficient', ...
        ['Design matrix is rank-deficient (effective rank %d of %d columns); ' ...
         'using the effective rank for degrees-of-freedom. Coefficients are ' ...
         'the minimum-norm (pinv) solution and are not uniquely identified.'], ...
        r, P);
end
dofRaw = T - r;
dofInvalid = dofRaw <= 0;
dof = max(dofRaw, 1);

% Mean squared error per channel
MSE = sum(residuals.^2, 1) / dof;

% Covariance of betas: inv(X'X) * MSE
XtXinv = pinv(X' * X);
varBeta = diag(XtXinv);  % [P x 1]

% Standard errors: sqrt(var(beta_j) * MSE_c) for each channel
se = sqrt(varBeta * MSE);  % [P x C]

end

function [beta, residuals, se, dof, Xw, residuals_w, dofInvalid] = fitARIRLS(Y, X, arOrder, maxIter, tol, useGPU)
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
%   dof         - Effective degrees of freedom [scalar], clamped to >= 1
%   Xw          - Prewhitened design matrix [T x P]
%   residuals_w - Prewhitened residuals [T x C]
%   dofInvalid  - True if the unclamped dof (T - effective rank of Xw -
%                 arOrder) was <= 0, meaning t/p-values are not
%                 statistically identifiable

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

% Final statistics from prewhitened fit. Degrees of freedom use the
% EFFECTIVE RANK of the prewhitened design Xw (not the raw column count P),
% for the same reason as the OLS path: a rank-deficient design (e.g. an FIR
% basis with T < number of stick regressors) must not understate, zero, or
% negate the residual dof.
r = rank(pf2_base.accel.gather(Xw));
if r < P
    warning('pf2:fitGLM:rankDeficient', ...
        ['Prewhitened design matrix is rank-deficient (effective rank %d of ' ...
         '%d columns); using the effective rank for degrees-of-freedom. ' ...
         'Coefficients are the minimum-norm (pinv) solution and are not ' ...
         'uniquely identified.'], r, P);
end
dofRaw = T - r - arOrder;
dofInvalid = dofRaw <= 0;
dof = max(dofRaw, 1);
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

function contrast = computeContrasts(C, contrastNames, beta, se, X, dof, residuals, dofInvalid)
% COMPUTECONTRASTS Compute contrast statistics
%
% Inputs:
%   C             - Contrast matrix [K x P]
%   contrastNames - Cell array {1 x K}
%   beta          - Coefficients [P x C]
%   se            - Standard errors [P x C]
%   X             - Design matrix [T x P]
%   dof           - Degrees of freedom [scalar], clamped to >= 1
%   residuals     - Residuals [T x C]
%   dofInvalid    - True if the unclamped dof was <= 0; contrast t/p-values
%                   are set to NaN in that case (mirrors the main-effect
%                   NaN handling in fitGLM)
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
if dofInvalid
    cTstat(:) = NaN;
    cPval(:) = NaN;
end

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

function order = selectAROrderBIC(Y, X, maxOrder)
% SELECTARORDERBIC Select AR model order by minimising median BIC across channels
%
% Evaluates AR models of order 1..maxOrder on the OLS residuals of Y regressed
% on the DESIGN MATRIX X (Y - X*beta), using the Yule-Walker estimate and BIC
% from the prewhitened residual variance. Residualizing the design first is
% important: fNIRS channels have strong task-evoked and drift autocorrelation
% that would otherwise inflate the selected order relative to the actual
% post-fit residual the AR-IRLS whitening loop removes. The candidate with the
% minimum MEDIAN BIC across non-degenerate channels is chosen, yielding a
% single scalar order for the pooled whitening filter.
%
% BIC is used instead of AIC because fNIRS recordings have modest T (a few
% hundred to a few thousand samples), where AIC tends to overfit
% (Schwarz 1978). BIC = T*log(sigma^2) + p*log(T).
%
% Channels whose residual variance is near zero (degenerate/flat) are
% excluded from the BIC aggregation to avoid numerical instability.
%
% Inputs:
%   Y        - Data matrix [T x C]
%   maxOrder - Maximum candidate AR order [scalar]
%
% Outputs:
%   order - Selected AR model order [scalar integer]

[T, nCh] = size(Y);

% Residuals from the actual design (task + drift), not just the channel mean,
% so the AR order reflects the noise the whitening loop removes.
if nargin < 2 || isempty(X)
    Yc = Y - mean(Y, 1);
elseif size(X, 1) == T
    Yc = Y - X * (X \ Y);       % OLS residuals
else
    Yc = Y - mean(Y, 1);        % shape mismatch: fall back to mean removal
end

% Variance floor for degenerate channel detection
varFloor = 1e-12 * max(var(Yc, 0, 1), [], 'omitnan');

bicMat = nan(maxOrder, nCh);

for q = 1:maxOrder
    if T <= q + 1
        break;
    end
    % Yule-Walker AR(q) fit
    arC = yulewalkMulti(Yc, q);      % [q x nCh]
    meanAR = mean(arC, 2);           % pool for BIC residual estimate

    % Prewhitened residuals for BIC
    Yw = applyARFilter(Yc, meanAR);  % [T x nCh]
    Yw = Yw((q+1):end, :);          % drop zeroed-out leading rows
    Teff = size(Yw, 1);
    if Teff < 1
        break;
    end

    sigma2 = sum(Yw .^ 2, 1) / Teff;  % [1 x nCh]

    % Exclude degenerate channels from BIC
    goodCh = sigma2 > varFloor & isfinite(sigma2);
    if any(goodCh)
        bic_q = Teff * log(max(sigma2, eps)) + q * log(Teff);  % [1 x nCh]
        bic_q(~goodCh) = NaN;
        bicMat(q, :) = bic_q;
    end
end

% Aggregate: median BIC per candidate order over good channels
medBIC = median(bicMat, 2, 'omitnan');

if all(isnan(medBIC))
    warning('pf2:fitGLM:autoOrderFallback', ...
        'BIC order selection produced all NaN; falling back to AR(1).');
    order = 1;
    return;
end

[~, order] = min(medBIC);

end
