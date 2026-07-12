function y = filtfilt_interp(b,a,x)
% FILTFILT_INTERP Zero-phase filtering with NaN interpolation
%
% Applies zero-phase digital filtering (filtfilt) to signals containing NaN
% values by first interpolating over the NaN gaps, filtering the complete
% signal, and then restoring NaN values at their original locations. This
% approach preserves the continuity needed for filtering while maintaining
% the artifact markers.
%
% Reference:
%   Internal pf2 implementation based on standard MATLAB filtfilt.
%   See also: Gustafsson, F. (1996). Determining the initial states in
%   forward-backward filtering. IEEE Trans Signal Process 44(4):988-992.
%
% Syntax:
%   y = filtfilt_interp(b, a, x)
%
% Inputs:
%   b - Filter numerator coefficients [1 x N double]
%       Obtained from filter design functions (e.g., butter, fir1).
%   a - Filter denominator coefficients [1 x M double]
%       For FIR filters, a = 1. For IIR filters (e.g., Butterworth),
%       obtained from filter design functions.
%   x - Input signal matrix [T x C double] where T=samples, C=channels
%       May contain NaN values marking artifacts or missing data.
%
% Outputs:
%   y - Filtered signal matrix [T x C double], same size as input
%       NaN values are restored at their original positions after filtering.
%       Channels with fewer than 5 valid samples are returned unchanged.
%
% Algorithm:
%   1. Identify NaN locations in each channel
%   2. Interpolate (linear) over NaN gaps using valid samples
%   3. Apply zero-phase filtering via filtfilt
%   4. Restore NaN values at original locations
%
% Example:
%   % Design a low-pass Butterworth filter
%   [b, a] = butter(4, 0.1/(10/2), 'low');
%
%   % Filter data with NaN artifacts
%   data = randn(1000, 5);
%   data(100:110, 2) = NaN;  % Simulate artifact
%   filtered = pf2_base.filtfilt_interp(b, a, data);
%
% Notes:
%   - Channels with fewer than 5 valid samples are skipped
%   - Uses linear interpolation (interp1) for gap filling
%   - Edge NaN values cannot be interpolated and remain NaN
%
% See also: filtfilt_piecewise, filtfilt, butter, interp1

isNanArr=(isnan(x));

minFilt=5;

for i=1:size(x,2)
	if(sum(~isnan(x(:,i)))<minFilt)
		continue;
	end

	xIdx=1:size(isNanArr,1);
	nanIdx=xIdx(isNanArr(:,i));
	xGoodIdx=xIdx(~isNanArr(:,i));
		
	x(nanIdx,i) = interp1(xGoodIdx,x(~isNanArr(:,i),i),nanIdx);
end

y=pf2_base.external.filtfilt_classic(b,a,x);

y(isNanArr)=nan;

