function [ dataf ] = pf2_bpf_fir( data,fs,lowF,highF,Nf,restoreMean,NaN_mode)

% inputs ------------------------
% data: data to be filtered
% filtOrder: filter order
% fs: sampling freq.
% lowF: highpass cut-off frequency
% highF: lowpass cutoff frequency
% Nf: filter Length
% restoreMean: add back in 0 frequency data
% outputs -----------------------
% dataf: filtered data
%--------------------------------
% Designs a bandpass FIR filter with the specified cut-off frequencies and
% length. Filters the data columnwise.
%
% References:
%   Oppenheim, A. V. & Schafer, R. W. (2010). Discrete-Time Signal
%   Processing, 3rd ed. Prentice Hall. ISBN: 978-0131988422
%--------------------------------

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

[b,a] = fir1(Nf,[lowF highF]/half_fs);

if(size(data,1)>3*Nf)
	switch(NaN_mode)
		case 'Interpolate'
			try
				dataf=pf2_base.filtfilt_interp(b,a,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end
			if(restoreMean)
			   dataf=dataf+nanmean(data,1); 
			end
		case 'Piecewise'
			try
				dataf=pf2_base.filtfilt_piecewise(b,a,data,3*Nf,restoreMean);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Use matlab 2018a filtfilt if current version fails due to nans
            end
		case 'Leave'
			try
				dataf=filtfilt(b,a,data);
			catch
				dataf=pf2_base.external.filtfilt_classic(b,a,data); % Use matlab 2018a filtfilt if current version fails due to nans
			end
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



