function [ dataf ] = pf2_bpf_fir( data,fs,lowF,highF,Nf,restoreMean,NaN_mode)
% PF2_BPF_FIR FIR band-pass filter for fNIRS signals
%
% Designs and applies a zero-phase FIR band-pass filter using fir1 to
% isolate a frequency band in fNIRS data. Removes both slow drifts (below
% lowF) and high-frequency noise (above highF).
%
% Reference:
%   Oppenheim, A. V. & Schafer, R. W. (2010). Discrete-Time Signal
%   Processing, 3rd ed. Prentice Hall. ISBN: 978-0131988422
%
% Syntax:
%   dataf = pf2_bpf_fir(data, fs, lowF, highF, Nf)
%   dataf = pf2_bpf_fir(data, fs, lowF, highF, Nf, restoreMean, NaN_mode)
%
% Inputs:
%   data        - Input signal matrix [T x C] where T=samples, C=channels
%   fs          - Sampling frequency in Hz
%   lowF        - High-pass cutoff frequency in Hz (lower bound)
%   highF       - Low-pass cutoff frequency in Hz (upper bound)
%   Nf          - FIR filter length (typical: 20-100)
%   restoreMean - Add mean back after filtering (default: false)
%   NaN_mode    - NaN handling: 'Piecewise' (default), 'Interpolate', 'Leave'
%
% Outputs:
%   dataf - Filtered signal matrix [T x C], same size as input
%
% Notes:
%   - Data length must be at least 3*Nf samples; shorter data returns NaN
%   - Uses zero-phase filtering (filtfilt) to avoid phase distortion
%
% See also: pf2_bpf_butter, pf2_lpf, pf2_hpf, fir1, filtfilt

if(nargin<7)
   NaN_mode='Piecewise';
end

if(nargin<6)
   restoreMean=false; 
end

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% Band-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

[b,a] = pf2_base.external.fir1(Nf,[lowF highF]/half_fs);

if(size(data,1)>3*Nf)
	switch(NaN_mode)
		case 'Interpolate'
			try
				dataf=pf2_base.filtfilt_interp(b,a,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Fall back to in-house zero-phase filter if the NaN-aware path errors
			end
			if(restoreMean)
			   dataf=dataf+nanmean(data,1); 
			end
		case 'Piecewise'
			try
				dataf=pf2_base.filtfilt_piecewise(b,a,data,3*Nf,restoreMean);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Fall back to in-house zero-phase filter if the NaN-aware path errors
            end
		case 'Leave'
			dataf=pf2_base.external.filtfilt_classic(b,a,data);
			if(restoreMean)
			   dataf=dataf+nanmean(data,1); 
			end
	end
	
	
else
    dataf=nan(size(data)); 
    warning('BPF: Datasize must be larger than 3*filter length (%i samples)',Nf);
end



if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end

end



