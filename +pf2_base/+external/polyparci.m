function CI = polyparci(PolyPrms, PolyS, alpha)
% POLYPARCI Confidence intervals for polynomial fit coefficients.
%
% Summary:
%   Computes two-sided confidence intervals for the coefficients returned by
%   POLYFIT, using the error-estimate struct that POLYFIT provides. The
%   intervals follow standard ordinary-least-squares theory: the coefficient
%   covariance is recovered from the QR factor R and the residual norm, the
%   per-coefficient standard errors are the square roots of its diagonal, and
%   each interval is the estimate plus/minus a Student-t critical value times
%   the standard error.
%
%   The coefficient covariance is
%       COV = (R' * R)^-1 * normr^2 / df
%   where R, normr and df are taken from the POLYFIT struct. The standard
%   error of coefficient j is SE(j) = sqrt(COV(j,j)). The critical value is
%   the inverse Student-t at probability ALPHA with df degrees of freedom,
%   computed from the regularized incomplete beta function so the Statistics
%   Toolbox is not required.
%
% Inputs:
%   PolyPrms - [1xN] (or [Nx1]) vector of coefficient estimates from POLYFIT.
%   PolyS    - struct returned by POLYFIT, with fields R, df and normr.
%   alpha    - (optional) probability for the inverse-t critical value.
%              Default 0.95. Clamped to (0, 1) for numerical safety.
%
% Outputs:
%   CI - [2xN] matrix of confidence intervals. Row 1 is the lower bound and
%        row 2 the upper bound; column j matches coefficient PolyPrms(j),
%        in the same coefficient order POLYFIT uses (highest power first).
%
% Examples:
%   x = (0:0.1:5)';
%   y = 2*x + 1 + 0.1*randn(size(x));
%   [p, S] = polyfit(x, y, 1);
%   CI = pf2_base.external.polyparci(p, S);   % CI(:,2) brackets the intercept
%
% References:
%   Standard ordinary-least-squares coefficient inference; see e.g.
%   Draper, N. R. & Smith, H. (1998). Applied Regression Analysis (3rd ed.),
%   Wiley. The QR-based covariance follows the documented contents of the
%   POLYFIT error-estimate struct (R, df, normr).
%
% See also: polyfit, polyval

    if nargin < 3 || isempty(alpha)
        alpha = 0.95;
    end

    % Clamp alpha away from the open-interval endpoints to keep the inverse-t
    % solve well-conditioned.
    eps0 = 1e-10;
    alpha = min(max(alpha, eps0), 1 - eps0);

    % Coefficient covariance from the QR factor and residual norm.
    R    = PolyS.R;
    df   = PolyS.df;
    nrm2 = PolyS.normr.^2;

    covB = (R' * R) \ eye(size(R, 2));   % inv(R'*R)
    covB = covB * (nrm2 / df);

    SE = sqrt(diag(covB));               % [Nx1] standard errors

    % Work with coefficients as a column vector to align with SE.
    coeff = PolyPrms(:);

    % Inverse Student-t critical value at probability alpha with df dof.
    T  = abs(invStudentT(alpha, df));
    ts = [-T, T];                        % two-sided multipliers

    % [Nx2] = lower/upper per coefficient, then transpose to [2xN] so each
    % column matches the corresponding POLYFIT coefficient.
    CI = (coeff + SE * ts)';
end

function t = invStudentT(p, v)
% INVSTUDENTT Inverse Student-t CDF via the regularized incomplete beta
% function, avoiding a Statistics Toolbox dependency. Returns t such that
% the cumulative Student-t probability at t with v degrees of freedom is p.

    % studentTcdf(t, v) is monotonically increasing in t; solve for the
    % root of studentTcdf(t) - p with a bracketing bisection. fzero would
    % also work, but bisection has no toolbox/initial-guess concerns.
    target = @(tt) studentTcdf(tt, v) - p;

    % Establish a bracket that straddles the root.
    lo = -1; hi = 1;
    while target(lo) > 0
        lo = lo * 2;
        if lo < -1e12, break; end
    end
    while target(hi) < 0
        hi = hi * 2;
        if hi > 1e12, break; end
    end

    for k = 1:200
        mid = 0.5 * (lo + hi);
        fm  = target(mid);
        if fm > 0
            hi = mid;
        else
            lo = mid;
        end
        if (hi - lo) < 1e-12
            break;
        end
    end
    t = 0.5 * (lo + hi);
end

function p = studentTcdf(t, v)
% STUDENTTCDF Cumulative Student-t distribution at t with v degrees of
% freedom, expressed through the regularized incomplete beta function.

    x = v ./ (t.^2 + v);                 % argument for the incomplete beta
    ib = betainc(x, v / 2, 0.5);         % regularized incomplete beta
    % For t >= 0 the CDF is 1 - 0.5*ib; for t < 0 it is 0.5*ib. The single
    % expression below is exact at t = 0 (ib = 1 -> p = 0.5) and matches the
    % standard symmetric form on both sides.
    p = 0.5 * (1 + sign(t) .* (1 - ib));
end
