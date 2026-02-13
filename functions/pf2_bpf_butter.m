function [ dataf ] = pf2_bpf_butter( data,filtOrder,fs,lowF,highF,restoreMean,NaN_mode)
% PF2_BPF_BUTTER Butterworth band-pass filter for fNIRS signals
%
% Applies a zero-phase Butterworth band-pass filter to isolate the
% hemodynamic response frequency band in fNIRS data. Removes both
% slow drifts (below lowF) and high-frequency noise (above highF).
%
% Syntax:
%   dataf = pf2_bpf_butter(data, filtOrder, fs, lowF, highF)
%   dataf = pf2_bpf_butter(data, filtOrder, fs, lowF, highF, restoreMean)
%   dataf = pf2_bpf_butter(data, filtOrder, fs, lowF, highF, restoreMean, NaN_mode)
%
% Inputs:
%   data       - Input signal matrix [T x C] where T=samples, C=channels
%                Can be column vector or matrix. Row vectors are transposed.
%   filtOrder  - Butterworth filter order (typical: 2-6)
%                Higher order = sharper cutoff but more ringing
%                Effective order doubles due to filtfilt
%   fs         - Sampling frequency in Hz (typical fNIRS: 2-50 Hz)
%   lowF       - High-pass cutoff frequency in Hz (lower bound)
%                For hemodynamic: 0.005-0.01 Hz typical
%   highF      - Low-pass cutoff frequency in Hz (upper bound)
%                For hemodynamic: 0.1-0.5 Hz typical
%   restoreMean - Logical flag to add mean back after filtering (default: false)
%                Band-pass removes DC; set true to preserve baseline level
%   NaN_mode   - Strategy for handling NaN values (default: 'Piecewise')
%                'Interpolate' - Interpolate over NaN, filter, restore NaN
%                'Piecewise'   - Filter valid segments, restore mean per segment
%                'Leave'       - Pass data to filtfilt as-is (may fail)
%
% Outputs:
%   dataf      - Filtered signal matrix, same size as input
%                NaN values are preserved in output based on NaN_mode
%
% Notes:
%   - Uses second-order sections (SOS) for numerical stability
%   - Data length must be at least 6*filtOrder samples
%   - Common bands: 0.008-0.1 Hz (hemodynamic), 0.008-0.5 Hz (with cardiac)
%   - Falls back to MATLAB R2018a filtfilt if current version fails
%
% Example:
%   % Standard hemodynamic band-pass (0.008-0.1 Hz)
%   filtered = pf2_bpf_butter(hbData, 4, 10, 0.008, 0.1);
%
%   % Include cardiac, restore baseline
%   filtered = pf2_bpf_butter(hbData, 3, 10, 0.01, 0.5, true);
%
% See also: pf2_lpf, pf2_hpf, pf2_bpf_fir, butter, filtfilt

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
% Band-pass Filter design (ZPK -> SOS for numerical stability)
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

[z,p,k] = butter(filtOrder,[lowF highF]/half_fs);
minLen=filtOrder*6;

if size(data,1)<=minLen
    warning('Data length (%i) must be at least 3 * filter order',size(data,1));
    dataf=nan(size(data));
else
    sos = zp2sos(z,p,k);

	switch(NaN_mode)
		case 'Interpolate'
			try
				dataf=pf2_base.filtfilt_interp(sos,1,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(sos,1,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end
			if(restoreMean)
			   dataf=dataf+nanmean(data,1);
			end
		case 'Piecewise'
			try
				dataf=pf2_base.filtfilt_piecewise(sos,1,data,minLen,restoreMean);
			catch
				dataf=pf2_base.external.filtfilt_classic(sos,1,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end
		case 'Leave'
			try
				dataf=filtfilt(sos,1,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(sos,1,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end

			if(restoreMean)
			   dataf=dataf+nanmean(data,1);
			end
	end

    if Mini==1 %if the data is a row vector converts it to column vector
        dataf=dataf';
    end
end

end
