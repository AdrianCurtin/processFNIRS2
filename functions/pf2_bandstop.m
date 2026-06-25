function [ dataf ] = pf2_bandstop( data,filtOrder,fs,lowF,highF)
% PF2_BANDSTOP Band-stop (notch) Butterworth filter for fNIRS signals
%
% Designs and applies a band-stop (notch) filter to attenuate frequencies
% within a specified band while passing frequencies outside that band. Useful
% for removing specific noise sources such as mains interference (50/60 Hz)
% or other known periodic artifacts from fNIRS data.
%
% Reference:
%   Standard signal processing; see MATLAB designfilt, filtfilt documentation.
%
% Syntax:
%   dataf = pf2_bandstop(data, filtOrder, fs, lowF, highF)
%
% Inputs:
%   data      - Input signal matrix [T x C] where T=samples, C=channels
%               Each column is filtered independently.
%               Row vectors are automatically transposed for filtering.
%   filtOrder - Filter order for the Butterworth design (scalar)
%               Higher order = sharper cutoff but more ringing.
%               Typical range: 2-6 for fNIRS applications.
%   fs        - Sampling frequency in Hz
%   lowF      - Lower edge of the stop band in Hz
%               Frequencies below this pass through unattenuated.
%   highF     - Upper edge of the stop band in Hz
%               Frequencies above this pass through unattenuated.
%
% Outputs:
%   dataf - Filtered signal matrix [T x C], same size as input
%           Frequencies between lowF and highF are attenuated.
%
% Algorithm:
%   1. Design an IIR band-stop Butterworth filter (zero-pole-gain form ->
%      second-order sections) with the toolbox-free pf2_base.external.butter
%   2. Apply zero-phase filtering using filtfilt_classic (forward-backward)
%   3. Preserve input orientation (row vs column vector)
%
% Example:
%   % Remove 60 Hz mains interference (58-62 Hz band)
%   cleanData = pf2_bandstop(rawData, 4, 10, 58, 62);
%
%   % Remove 50 Hz European mains interference
%   cleanData = pf2_bandstop(rawData, 4, fs, 48, 52);
%
% Notes:
%   - Uses zero-phase filtering (filtfilt) to avoid phase distortion
%   - Row vectors are automatically handled but returned in original shape
%   - For notch filters targeting a specific frequency, set lowF and highF
%     to bracket the target frequency (e.g., 59-61 Hz for 60 Hz notch)
%   - NaN handling: filtfilt does not tolerate NaN values. If your data
%     contains NaN-masked channels, filter only finite columns or use a
%     NaN-aware wrapper (see pf2_lpf NaN_mode options for examples).
%
% See also: pf2_bpf_butter, pf2_lpf, pf2_hpf, designfilt, filtfilt

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% Band-stop Filter design
%-----------------------------------------------------------------


% Butterworth band-stop in zero-pole-gain form -> SOS. A band design of order
% n produces a 2n-order filter, so halve the requested total order to match
% the previous designfilt('FilterOrder', filtOrder) convention.
nHalf = max(1, round(filtOrder / 2));
half_fs = fs / 2;
[z, p, k] = pf2_base.external.butter(nHalf, [lowF highF] / half_fs, 'stop');
sos = pf2_base.external.zp2sos(z, p, k);

dataf = pf2_base.external.filtfilt_classic(sos, 1, data);


if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end
