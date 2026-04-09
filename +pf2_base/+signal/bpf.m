function dataf = bpf(data, filtOrder, fs, lowF, highF)
% BPF Band-pass Butterworth filter (numerically stable variant)
%
% Designs and applies a zero-phase Butterworth band-pass filter using
% zero-pole-gain form converted to second-order sections for numerical
% stability at low normalized frequencies.
%
% Syntax:
%   dataf = pf2_base.signal.bpf(data, filtOrder, fs, lowF, highF)
%
% Inputs:
%   data      - Input signal matrix [T x C]
%   filtOrder - Butterworth filter order (typical: 2-6)
%   fs        - Sampling frequency in Hz
%   lowF      - High-pass cutoff frequency in Hz (lower bound)
%   highF     - Low-pass cutoff frequency in Hz (upper bound)
%
% Outputs:
%   dataf - Filtered signal [T x C], NaN where data is insufficient
%
% See also: pf2_bpf_butter, pf2_bpf_fir, pf2_base.signal.lpf, pf2_base.signal.hpf, filtfilt

[Mini, ~] = size(data);
if Mini == 1
    data = data';
end

% Band-pass filter design
half_fs = fs / 2;

% Use zero-pole-gain form for numerical stability at low normalized
% frequencies (e.g., 0.01 Hz at 5 Hz sampling). ZPK -> SOS avoids
% ill-conditioned intermediate matrices.
[z, p, k] = butter(filtOrder, [lowF highF] / half_fs);
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
