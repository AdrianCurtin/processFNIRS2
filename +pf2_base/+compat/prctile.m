function q = prctile(x, p, dim)
%PRCTILE Percentiles of a sample (toolbox-free).
%
%   Base-MATLAB replacement for the Statistics and Machine Learning
%   Toolbox function PRCTILE. Thin wrapper over pf2_base.compat.quantile
%   with percentages (0-100) instead of probabilities (0-1).
%
%   Inputs:
%     x   - Numeric array. NaNs are ignored.
%     p   - Percentages in [0,100], scalar or vector.
%     dim - (optional) Dimension to operate along. Defaults to the first
%           non-singleton dimension.
%
%   Outputs:
%     q   - Percentiles, shaped as pf2_base.compat.quantile returns.
%
%   See also: pf2_base.compat.quantile

prob = p ./ 100;

% Guard against quantile's integer-N reinterpretation: a scalar probability
% of exactly 1 (the 100th percentile) would be read as "N = 1 quantile" and
% return the median instead of the maximum. Nudge it just below 1 so it
% stays a probability; the interpolation clamps it to the sample maximum.
prob(prob >= 1) = 1 - eps;

if nargin < 3
    q = pf2_base.compat.quantile(x, prob);
else
    q = pf2_base.compat.quantile(x, prob, dim);
end

end
