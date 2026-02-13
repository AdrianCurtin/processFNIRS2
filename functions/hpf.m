function [ dataf ] = hpf( data,filtOrder,fs,freq_cut )

% inputs ------------------------
% data: data to be filtered
% filtOrder: filter order
% fs: sampling freq.
% freq_cut: highpass cut-off frequency
% outputs -----------------------
% dataf: filtered data
%--------------------------------
% hpf function designs a highpass Butterworth filter with the specified
% cut-off frequency and order. Uses zero-pole-gain form converted to
% second-order sections (SOS) for numerical stability at low normalized
% frequencies. It filters the data columnwise as its output.
%--------------------------------

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% High-pass Filter design
%-----------------------------------------------------------------
half_fs = fs/2;    %half of sampling freq. equal to pi

% Use zero-pole-gain form for numerical stability.
% The transfer function form [b,a]=butter can produce unstable filters
% at low normalized frequencies. ZPK -> SOS avoids this.
[z, p, k] = butter(filtOrder, freq_cut/half_fs, 'high');
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
