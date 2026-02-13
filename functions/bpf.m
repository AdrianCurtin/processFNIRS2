function [ dataf ] = bpf( data,filtOrder,fs,lowF,highF)

% inputs ------------------------
% data: data to be filtered
% filtOrder: filter order
% fs: sampling freq.
% lowF: highpass cut-off frequency
% highF: lowpass cutoff frequency
% outputs -----------------------
% dataf: filtered data
%--------------------------------
% bpf function designs bandpass butterworth filter with the specified cut-off frequencies and order.
% It filters the data columnwise as its output
%--------------------------------

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% Band-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

% Use zero-pole-gain form for numerical stability at low normalized
% frequencies (e.g., 0.01 Hz at 5 Hz sampling). The state-space form
% [A,B,C,D]=butter + ss2sos can produce unstable filters due to
% ill-conditioned intermediate matrices. ZPK -> SOS avoids this.
[z, p, k] = butter(filtOrder, [lowF highF]/half_fs);
sos = zp2sos(z, p, k);

% Filter each column, handling NaN-padded regions per channel
dataf = NaN(size(data));
for col = 1:size(data, 2)
    finIdx = isfinite(data(:, col));
    if ~any(finIdx), continue; end
    % Find contiguous finite span (first to last finite sample)
    first = find(finIdx, 1, 'first');
    last  = find(finIdx, 1, 'last');
    seg = data(first:last, col);
    if all(isfinite(seg)) && numel(seg) > 3*filtOrder
        dataf(first:last, col) = pf2_base.external.filtfilt_classic(sos, 1, seg);
    end
end

if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end
