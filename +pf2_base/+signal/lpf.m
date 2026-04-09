function dataf = lpf(data, ft, fs, freq_cut, Nf)
% LPF Low-pass filter (numerically stable variant)
%
% Designs and applies a zero-phase low-pass filter. For IIR Butterworth
% (ft=3), uses zero-pole-gain form converted to second-order sections for
% numerical stability at low normalized frequencies.
%
% Syntax:
%   dataf = pf2_base.signal.lpf(data, ft, fs, freq_cut, Nf)
%
% Inputs:
%   data     - Input signal matrix [T x C]
%   ft       - Filter type: 1=FIR (fir1), 2=Equiripple (remez), 3=Butterworth
%   fs       - Sampling frequency in Hz
%   freq_cut - Cutoff frequency in Hz
%   Nf       - Filter length (ft=1,2) or order (ft=3)
%
% Outputs:
%   dataf - Filtered signal [T x C], NaN where data is insufficient
%
% See also: pf2_lpf, hpf, bpf, filtfilt

[Mini, ~] = size(data);
if Mini == 1
    data = data';
end

[M, N] = size(data);

% Low-pass filter design
half_fs = fs / 2;
useSOS = false;

if ft == 1
    [b, a] = fir1(Nf, freq_cut / half_fs);
elseif ft == 2
    dp = 0.01;
    ds = 0.01;
    dev = [dp ds];
    F = [freq_cut, freq_cut + 0.1 * freq_cut];
    MR = [1 0];
    [N1, F0, M0, W] = remezord(F, MR, dev, fs);
    [b, ~] = remez(N1, F0, M0, W);
    a = 1;
elseif ft == 3
    % Use zero-pole-gain form for numerical stability.
    % The transfer function form [b,a]=butter can produce unstable filters
    % at low normalized frequencies. ZPK -> SOS avoids this.
    [z, p, k] = butter(Nf, freq_cut / half_fs, 'low');
    sos = zp2sos(z, p, k);
    useSOS = true;
end

% Filter each column, handling NaN-padded regions per channel
minLen = 3 * Nf + 1;
dataf = NaN(size(data));
for col = 1:N
    finIdx = isfinite(data(:, col));
    if ~any(finIdx), continue; end
    first = find(finIdx, 1, 'first');
    last  = find(finIdx, 1, 'last');
    seg = data(first:last, col);
    if all(isfinite(seg)) && numel(seg) > minLen
        if useSOS
            dataf(first:last, col) = pf2_base.external.filtfilt_classic(sos, 1, seg);
        else
            dataf(first:last, col) = filtfilt(b, a, seg);
        end
    end
end

if Mini == 1
    dataf = dataf';
end

end
