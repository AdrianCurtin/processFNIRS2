function [dataf] = pf2_bpf_iir(data, fs, lowF, highF, filtOrder, restoreMean, NaN_mode)
% PF2_BPF_IIR Butterworth IIR bandpass filter for fNIRS data
%
% Designs a Butterworth IIR bandpass (or lowpass/highpass) filter and
% applies it with zero-phase filtering (filtfilt). Handles NaN values via
% piecewise or interpolation strategies. Drop-in IIR alternative to
% pf2_bpf_fir.
%
% Butterworth IIR filters have sharper rolloff at equivalent order compared
% to FIR filters, making them popular in fNIRS preprocessing pipelines.
% 22 of 34 FRESH study teams used Butterworth filters specifically.
%
% Reference:
%   Yuecel, M. A. et al. (2025). Best practices for fNIRS publications.
%   Neurophotonics, 8(1), 012101. (FRESH study methodology)
%
% Syntax:
%   dataf = pf2_bpf_iir(data, fs, lowF, highF)
%   dataf = pf2_bpf_iir(data, fs, lowF, highF, filtOrder)
%   dataf = pf2_bpf_iir(data, fs, lowF, highF, filtOrder, restoreMean)
%   dataf = pf2_bpf_iir(data, fs, lowF, highF, filtOrder, restoreMean, NaN_mode)
%   dataf = pf2_bpf_iir(data, fs, 0, highF)    % lowpass only
%   dataf = pf2_bpf_iir(data, fs, lowF, 0)     % highpass only
%
% Inputs:
%   data       - Signal matrix [T x C] where T=samples, C=channels
%   fs         - Sampling frequency in Hz [scalar]
%   lowF       - Highpass cutoff frequency in Hz. Set to 0 for lowpass only.
%   highF      - Lowpass cutoff frequency in Hz. Set to 0 for highpass only.
%   filtOrder  - Butterworth filter order (default: 4). Typical range: 3-5.
%   restoreMean - Restore DC component after filtering (default: false)
%   NaN_mode   - NaN handling: 'Piecewise', 'Interpolate', or 'Leave'
%                (default: 'Piecewise')
%
% Outputs:
%   dataf - Filtered signal [T x C], same size as input
%
% Algorithm:
%   1. Design Butterworth filter using butter() with specified order
%   2. Convert to second-order sections (SOS) for numerical stability
%   3. Apply zero-phase filtering via filtfilt (forward + backward pass)
%   4. NaN handling: 'Piecewise' filters contiguous non-NaN segments,
%      'Interpolate' fills NaN before filtering, 'Leave' passes to filtfilt
%
% Example:
%   % Bandpass 0.01 - 0.5 Hz, order 4
%   dataf = pf2_bpf_iir(data.HbO, data.fs, 0.01, 0.5);
%
%   % Lowpass only at 0.2 Hz, order 3
%   dataf = pf2_bpf_iir(data.HbO, data.fs, 0, 0.2, 3);
%
%   % Highpass only at 0.01 Hz
%   dataf = pf2_bpf_iir(data.HbO, data.fs, 0.01, 0, 4);
%
% See also: bpf, pf2_bpf_fir, lpf, butter, filtfilt

%% Defaults
if nargin < 7, NaN_mode = 'Piecewise'; end
if nargin < 6, restoreMean = false; end
if nargin < 5, filtOrder = 4; end

%% Handle row vectors
[Mini, ~] = size(data);
if Mini == 1
    data = data';
end

[M, ~] = size(data);
half_fs = fs / 2;

%% Design Butterworth filter
if lowF > 0 && highF > 0
    % Bandpass
    Wn = [lowF, highF] / half_fs;
    ftype = 'bandpass';
elseif lowF > 0 && highF <= 0
    % Highpass
    Wn = lowF / half_fs;
    ftype = 'high';
elseif lowF <= 0 && highF > 0
    % Lowpass
    Wn = highF / half_fs;
    ftype = 'low';
else
    error('pf2:bpf_iir:noCutoff', 'At least one of lowF or highF must be > 0.');
end

% Clamp Wn to valid range
Wn = max(Wn, 1e-6);
Wn = min(Wn, 1 - 1e-6);

% Design filter and convert to SOS for numerical stability
if strcmp(ftype, 'bandpass')
    [A, B, C, D] = butter(filtOrder, Wn);
else
    [A, B, C, D] = butter(filtOrder, Wn, ftype);
end
sos = ss2sos(A, B, C, D);

%% Minimum data length for filtering
% filtfilt requires at least 3*nSOS samples
minLen = 3 * size(sos, 1) + 1;

if M < minLen
    dataf = nan(size(data));
    warning('pf2:bpf_iir:tooShort', ...
        'Data length (%d) too short for filter order %d. Returning NaN.', M, filtOrder);
    if Mini == 1, dataf = dataf'; end
    return;
end

%% Store means for restoration
if restoreMean
    dataMeans = mean(data, 1, 'omitnan');
end

%% Apply filter with NaN handling
switch NaN_mode
    case 'Piecewise'
        try
            dataf = pf2_base.filtfilt_piecewise(sos, 1, data, minLen, restoreMean);
        catch
            dataf = pf2_base.external.filtfilt_classic(sos, 1, data);
            if restoreMean
                dataf = dataf + dataMeans;
            end
        end

    case 'Interpolate'
        try
            dataf = pf2_base.filtfilt_interp(sos, 1, data);
        catch
            dataf = pf2_base.external.filtfilt_classic(sos, 1, data);
        end
        if restoreMean
            dataf = dataf + dataMeans;
        end

    case 'Leave'
        try
            dataf = filtfilt(sos, 1, data);
        catch
            dataf = pf2_base.external.filtfilt_classic(sos, 1, data);
        end
        if restoreMean
            dataf = dataf + dataMeans;
        end

    otherwise
        error('pf2:bpf_iir:badNaNMode', ...
            'NaN_mode must be ''Piecewise'', ''Interpolate'', or ''Leave''.');
end

%% Restore shape
if Mini == 1
    dataf = dataf';
end

end
