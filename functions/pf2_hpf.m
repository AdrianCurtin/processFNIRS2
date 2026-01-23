function [ dataf ] = pf2_hpf( data,ft,fs,freq_cut,Nf ,NaN_mode)
% PF2_HPF High-pass filter for fNIRS signals
%
% Applies a zero-phase high-pass filter to remove slow drifts and baseline
% fluctuations from fNIRS data. Useful for removing very low frequency
% noise, slow physiological trends, and instrumental drift.
%
% Syntax:
%   dataf = pf2_hpf(data, ft, fs, freq_cut, Nf)
%   dataf = pf2_hpf(data, ft, fs, freq_cut, Nf, NaN_mode)
%
% Inputs:
%   data     - Input signal matrix [T x C] where T=samples, C=channels
%              Can be column vector or matrix. Row vectors are transposed.
%   ft       - Filter type selection:
%              1 = FIR filter using fir1() with linear phase (recommended)
%              3 = IIR Butterworth filter using butter()
%              Note: ft=2 (remez) not supported for high-pass
%   fs       - Sampling frequency in Hz (typical fNIRS: 2-50 Hz)
%   freq_cut - Cutoff frequency in Hz
%              For drift removal: 0.005-0.02 Hz typical
%              For Mayer wave removal: ~0.1 Hz
%   Nf       - Filter order (for ft=3) or filter length (for ft=1)
%              For FIR (ft=1): typical range 20-100
%              For Butterworth (ft=3): typical range 2-6
%   NaN_mode - Strategy for handling NaN values in data (default: 'Piecewise')
%              'Interpolate' - Interpolate over NaN, filter, restore NaN
%              'Piecewise'   - Filter valid segments separately (recommended)
%              'Leave'       - Pass data to filtfilt as-is (may fail)
%
% Outputs:
%   dataf    - Filtered signal matrix, same size as input
%              NaN values are preserved in output based on NaN_mode
%
% Notes:
%   - Uses zero-phase filtering (filtfilt) to avoid phase distortion
%   - Data length must be at least 3*Nf samples; shorter data returns NaN
%   - High-pass removes DC component; consider restoring mean if needed
%   - For block designs, ensure cutoff is below task frequency
%
% Example:
%   % Remove slow drift below 0.01 Hz
%   filtered = pf2_hpf(hbData, 3, 10, 0.01, 4);
%
%   % FIR high-pass with 0.008 Hz cutoff
%   filtered = pf2_hpf(hbData, 1, 10, 0.008, 60);
%
% See also: pf2_lpf, pf2_bpf_butter, filtfilt, detrend_nan

if(nargin<6)
	NaN_mode='Piecewise';
end

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);

%-----------------------------------------------------------------
% High-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

if ft==1
    [b,a] = fir1(Nf,freq_cut/half_fs,'high');  % use FIR1 to obtain linear phase filter; b=impulse response

elseif ft==3
    [b,a] = butter(Nf,freq_cut/half_fs,'high');
end

%-----------------------------------------------------------------
% Filter the data
%-----------------------------------------------------------------
%H = fft(b',2*(M+Nf));           %frequency domain filter
%H = freqz(b,a,2*(M+Nf),'whole');           %frequency domain filter
%H=H/(H(1));

%Data = fft(data,2*(M+Nf));      %frequency domain data
%Dataf = (H * ones(1,N)) .* Data;  %frequency domain filtered data
%datad = ifft(Dataf);              %time domain filtered data
%dataf = (real(datad(Nf/2:M+Nf/2-1,1:N))); %adjustment for time shifting caused by the filter

if(size(data,1)>3*Nf)
    switch(NaN_mode)
		case 'Interpolate'
			try
				dataf=pf2_base.filtfilt_interp(b,a,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end
		case 'Piecewise'
			try
				dataf=pf2_base.filtfilt_piecewise(b,a,data,3*Nf);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end
		case 'Leave'
			try
				dataf=filtfilt(b,a,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Use matlab 2018a filtfilt if current version fails due to nans
            end
	end
else
    dataf=nan(size(data));
    warning('HPF: Datasize must be larger than 3*filter length (%i samples)',Nf);
end

if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end
