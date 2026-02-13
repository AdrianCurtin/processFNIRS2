function [ dataf ] = pf2_lpf( data,ft,fs,freq_cut,Nf, NaN_mode)
% PF2_LPF Low-pass filter for fNIRS signals
%
% Applies a zero-phase low-pass filter to remove high-frequency noise from
% fNIRS data, including cardiac (~1 Hz) and respiratory (~0.25 Hz) artifacts.
% Supports multiple filter designs and NaN handling strategies.
%
% Syntax:
%   dataf = pf2_lpf(data, ft, fs, freq_cut, Nf)
%   dataf = pf2_lpf(data, ft, fs, freq_cut, Nf, NaN_mode)
%
% Inputs:
%   data     - Input signal matrix [T x C] where T=samples, C=channels
%              Can be column vector or matrix. Row vectors are transposed.
%   ft       - Filter type selection:
%              1 = FIR filter using fir1() with linear phase (recommended)
%              2 = Equiripple FIR using remez() (Parks-McClellan)
%              3 = IIR Butterworth filter using butter()
%   fs       - Sampling frequency in Hz (typical fNIRS: 2-50 Hz)
%   freq_cut - Cutoff frequency in Hz
%              For hemodynamic response: 0.1-0.2 Hz typical
%              For removing cardiac: 0.5 Hz
%   Nf       - Filter order (for ft=3) or filter length (for ft=1,2)
%              For FIR (ft=1,2): typical range 20-100
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
%   - For IIR filters (ft=3), Nf is filter order (effective order = 2*Nf)
%   - Falls back to MATLAB R2018a filtfilt if current version fails
%
% Example:
%   % Remove cardiac artifact with FIR filter
%   filtered = pf2_lpf(hbData, 1, 10, 0.5, 50);
%
%   % Butterworth filter for hemodynamic isolation
%   filtered = pf2_lpf(hbData, 3, 10, 0.1, 4);
%
% See also: pf2_hpf, pf2_bpf_butter, filtfilt

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

if(nargin<6)
	NaN_mode='Piecewise';
end

[M,N]=size(data);

%-----------------------------------------------------------------
% Low-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

if ft==1
    [b,a] = fir1(Nf,freq_cut/half_fs);  % use FIR1 to obtain linear phase filter; b=impulse response

elseif ft==2
    dp=0.01; %pass-band ripple
    ds=0.01; %stop-band ripple
    dev=[dp ds];
    F=[freq_cut freq_cut+0.1*(freq_cut)];   %these are the cutoff frequencies %this frequency depends on noise frequency
    MR=[1 0];
    [N1, F0, M0, W]=remezord(F, MR, dev, fs);
    [b,delta]=remez(N1, F0, M0, W);
    a=1;
elseif ft==3
    [b,a] = butter(Nf,freq_cut/half_fs);
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
    warning('LPF: Datasize must be larger than 3*filter length (%i samples)',Nf);
end

if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end

end
