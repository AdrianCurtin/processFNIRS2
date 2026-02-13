function [ dataf ] = lpf( data,ft,fs,freq_cut,Nf )

% inputs ------------------------
% data: data to be filtered
% ft: filter type
% fs: sampling freq.
% freq_cut: cut-off frequency
% Nf: filter length / filter order
% outputs -----------------------
% dataf: filtered data
%--------------------------------
% lpf function designs lowpass filter with the specified cut-off frequency
% and order/length. It filters the data columnwise as its output.
%
% Filter types:
%   ft=1: FIR (fir1), Nf = filter length
%   ft=2: FIR (Parks-McClellan / remez), Nf = filter length
%   ft=3: IIR Butterworth (zero-pole-gain -> SOS for stability), Nf = filter order
%--------------------------------

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% Low-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi
useSOS = false;

if ft==1
    [b,a] = fir1(Nf,freq_cut/half_fs);  % FIR1 linear phase filter
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
    % Use zero-pole-gain form for numerical stability.
    % The transfer function form [b,a]=butter can produce unstable filters
    % at low normalized frequencies. ZPK -> SOS avoids this.
    [z, p, k] = butter(Nf, freq_cut/half_fs, 'low');
    sos = zp2sos(z, p, k);
    useSOS = true;
end
%-----------------------------------------------------------------
% Filter the data
%-----------------------------------------------------------------
% Filter each column, handling NaN-padded regions per channel
minLen = 3 * Nf + 1;
dataf = NaN(size(data));
for col = 1:N
    finIdx = isfinite(data(:, col));
    if ~any(finIdx), continue; end
    % Find contiguous finite span (first to last finite sample)
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

if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end
