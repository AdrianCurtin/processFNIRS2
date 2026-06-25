function [ dataf ] = hpf( data,filtOrder,fs,freq_cut )
% HPF High-pass Butterworth filter (numerically stable variant)
%
% Designs and applies a zero-phase high-pass Butterworth filter using
% zero-pole-gain form converted to second-order sections for numerical
% stability at low normalized frequencies.
%
% Unlike pf2_hpf, this version does not support NaN_mode options or
% multiple filter types but uses per-column finite-span filtering.
%
% Syntax:
%   dataf = hpf(data, filtOrder, fs, freq_cut)
%
% Inputs:
%   data      - Input signal matrix [T x C]
%   filtOrder - Butterworth filter order (typical: 2-6)
%   fs        - Sampling frequency in Hz
%   freq_cut  - Cutoff frequency in Hz
%
% Outputs:
%   dataf - Filtered signal [T x C], NaN where data is insufficient
%
% See also: pf2_hpf, lpf, bpf, filtfilt

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% High-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

% Use zero-pole-gain form for numerical stability.
% The transfer function form [b,a]=butter can produce unstable filters
% at low normalized frequencies. ZPK -> SOS avoids this.
[z, p, k] = pf2_base.external.butter(filtOrder, freq_cut/half_fs, 'high');
sos = pf2_base.external.zp2sos(z, p, k);

% Filter each column, handling NaN-padded regions per channel
dataf = NaN(size(data));
for col = 1:size(data, 2)
    finIdx = isfinite(data(:, col));
    if ~any(finIdx), continue; end
    % Find contiguous finite span (first to last finite sample)
    first = find(finIdx, 1, 'first');
    last  = find(finIdx, 1, 'last');
    seg = data(first:last, col);
    if all(isfinite(seg)) && numel(seg) > 3*filtOrder
        dataf(first:last, col) = pf2_base.external.filtfilt_classic(sos, 1, seg);
    end
end

if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end
