function y = detrend_3rd_order(x,fs)
% DETREND_3RD_ORDER Remove 3rd-order polynomial trend from fNIRS signals
%
% Fits and removes a third-order polynomial trend from each channel of
% fNIRS data. Useful for removing slow instrumental drift and baseline
% wandering that is not adequately addressed by high-pass filtering.
%
% The algorithm uses robust normalization of polynomial basis functions
% to improve numerical stability of the least-squares fit.
%
% Syntax:
%   y = detrend_3rd_order(x, fs)
%
% Inputs:
%   x   - Input signal matrix [T x C] where T=samples, C=channels
%         Each column is detrended independently
%   fs  - Sampling frequency in Hz
%         Used to create a proper time axis for polynomial fitting
%         (converts sample indices to time in seconds)
%
% Outputs:
%   y   - Detrended signal matrix [T x C], same size as input
%         The polynomial trend has been subtracted from each channel
%
% Algorithm:
%   1. Create time axis: X = (1:T)' / fs (time in seconds)
%   2. Build design matrix with normalized polynomial terms:
%      XM = [1, (X-mean(X))/std(X), (X^2-mean)/std, (X^3-mean)/std]
%   3. Fit polynomial via pseudo-inverse: coeffs = pinv(XM) * signal
%   4. Subtract fitted trend: y = signal - XM * coeffs
%
% Notes:
%   - The normalization step centers and scales polynomial terms to
%     avoid numerical issues with high powers of large time values
%   - For very long recordings, consider piecewise detrending
%   - NaN values are not explicitly handled; use detrend_nan if needed
%   - Warnings are suppressed during pinv calculation
%
% Example:
%   % Detrend a 1000-sample recording at 10 Hz
%   detrended = detrend_3rd_order(hbData, 10);
%
%   % Compare original and detrended
%   figure;
%   subplot(2,1,1); plot(hbData(:,1)); title('Original');
%   subplot(2,1,2); plot(detrended(:,1)); title('Detrended');
%
% See also: detrend, detrend_nan, pf2_hpf

order = 3;
for i = 1:size(x,2)
    signal = x(:,i);
    X=(1:length(signal))'/fs;
    XM=ones(length(X),order+1);
    for pn=1:order
        CX=X.^pn;
        XM(:,pn+1)=(CX-mean(CX))/std(CX);
    end
    w=warning('off','all');
    rem_trend = XM*(pinv(XM)*signal);
    signal=signal-rem_trend;
    warning(w);
    y(:,i) = signal;%+x(1,i);
end