function dataf = hpf(data, filtOrder, fs, freq_cut)
% HPF High-pass Butterworth filter (numerically stable variant)
%
% Designs and applies a zero-phase high-pass Butterworth filter using
% zero-pole-gain form converted to second-order sections for numerical
% stability at low normalized frequencies.
%
% Syntax:
%   dataf = pf2_base.signal.hpf(data, filtOrder, fs, freq_cut)
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
% See also: pf2_hpf, pf2_base.signal.lpf, pf2_base.signal.bpf, filtfilt

[Mini, ~] = size(data);
if Mini == 1
    data = data';
end

% High-pass filter design
half_fs = fs / 2;

% Use zero-pole-gain form for numerical stability.
[z, p, k] = butter(filtOrder, freq_cut / half_fs, 'high');
sos = zp2sos(z, p, k);

% Filter each column, handling NaN-padded regions per channel
dataf = NaN(size(data));
for col = 1:size(data, 2)
    finIdx = isfinite(data(:, col));
    if ~any(finIdx), continue; end
    first = find(finIdx, 1, 'first');
    last  = find(finIdx, 1, 'last');
    seg = data(first:last, col);
    if all(isfinite(seg)) && numel(seg) > 3 * filtOrder
        dataf(first:last, col) = pf2_base.external.filtfilt_classic(sos, 1, seg);
    end
end

if Mini == 1
    dataf = dataf';
end

end
