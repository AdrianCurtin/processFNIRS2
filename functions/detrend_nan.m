function y = detrend_nan(x,restoreMean)
% DETREND_NAN Linear detrending with NaN handling
%
% Removes linear trend from data while preserving NaN values and optionally
% restoring the mean. Operates column-wise on multi-dimensional arrays,
% fitting a linear regression only to non-NaN samples. Particularly useful
% for fNIRS data with motion artifact gaps marked as NaN.
%
% Syntax:
%   y = detrend_nan(x)
%   y = detrend_nan(x, restoreMean)
%
% Inputs:
%   x           - Input data matrix [T x C] or multi-dimensional array
%                 NaN values are preserved and excluded from trend estimation.
%                 If input is a row vector, it is automatically transposed.
%   restoreMean - Logical scalar controlling mean restoration (default: true)
%                 true: Add back the original mean after detrending (removes
%                       only slope, preserves DC offset).
%                 false: Return zero-mean detrended signal.
%
% Outputs:
%   y - Detrended data matrix, same size as input [T x C]
%       NaN locations are preserved from input. Non-NaN values have linear
%       trend removed. If restoreMean=true, mean is restored to each column.
%
% Algorithm:
%   For each column:
%   1. Identify non-NaN samples (kp = find(~isnan(x(:,i))))
%   2. Build regressor matrix: [normalized_time, ones] where time spans [0,1]
%   3. Fit linear model via least squares: beta = regressor \ x(kp,i)
%   4. Remove trend: y(kp,i) = x(kp,i) - regressor * beta
%   5. If restoreMean=true, add back mean(x(kp,i))
%   6. NaN positions remain NaN in output
%
% Example:
%   % Detrend fNIRS signal with motion artifacts (NaN gaps)
%   data = pf2.import.sampleData.fNIR2000();
%   signal = data.HbO(:,1);  % Get first channel
%   signal([100:110, 500:520]) = NaN;  % Simulate artifact gaps
%   detrended = detrend_nan(signal);  % Remove drift, keep mean
%
%   % Zero-mean detrending (no mean restoration)
%   detrended_zero = detrend_nan(signal, false);
%
%   % Multi-channel processing
%   allDetrended = detrend_nan(data.HbO);  % Detrend all channels at once
%
% Notes:
%   - Handles multi-dimensional arrays by reshaping to [T x N] internally
%   - Normalizes time range to [0,1] for numerical stability
%   - Preserves input dimensions in output
%   - For row vectors, automatically transposes to column vector
%
% See also: detrend, detrend_3rd_order, pf2_hpf

if(nargin<2)
    restoreMean=true;
end

%  Reshape x if necessary, assuming the dimension to be 
%  detrended is the first

szx = size(x); ndimx = length(szx);
if ndimx > 2;
  x = reshape(x, szx(1), prod(szx(2:ndimx)));
end
 
n = size(x,1);
if n == 1,
  x = x(:);			% If a row, turn into column vector
end
[N, m] = size(x);
y = repmat(NaN, [N m]);

for i = 1:m;
  kp = find(~isnan(x(:,i)));
  if length(kp) < 2
    % Cannot fit a trend with fewer than 2 points; return original values
    y(kp,i) = x(kp,i);
    continue;
  end
  a = [(kp-1)/(max(kp)-min(kp)) ones(length(kp), 1)];  %  Build regressor
  y(kp,i) = x(kp,i) - a*(a\x(kp,i));

  if(restoreMean)
    y(kp,i)=y(kp,i)+nanmean(x(kp,i));
  end
end

if n == 1
  y = y.';
end

%  Reshape output so it is the same dimension as input

if ndimx > 2;
  y = reshape(y, szx);
end
