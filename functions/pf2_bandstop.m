function [ dataf ] = pf2_bandstop( data,filtOrder,fs,lowF,highF)

% inputs ------------------------
% data: data to be filtered
% filtOrder: filter order
% fs: sampling freq.
% lowF: highpass cut-off frequency
% highF: lowpass cutoff frequency
% outputs -----------------------
% dataf: filtered data
%--------------------------------
% pf2_bandstop function designs bandstop butterworth filter with the specified cut-off frequencies and order.
% It filters the data columnwise as its output
%--------------------------------

[Mini,Nini]=size(data);
if Mini==1 %if the data is a row vector converts it to column vector
    data=data';
end

[M,N]=size(data);
%-----------------------------------------------------------------
% Band-stop Filter design
%-----------------------------------------------------------------


d = designfilt('bandstopiir','FilterOrder',filtOrder, ...
           'HalfPowerFrequency1',lowF,'HalfPowerFrequency2',highF, ...
           'DesignMethod','butter','SampleRate',fs);

% [A,B,C,D] = butter(filtOrder,[lowF highF]/half_fs);
% 
% sos = ss2sos(A,B,C,D);
% dataf=filtfilt(sos,1,data);

dataf=(filtfilt(d,data));


if Mini==1 %if the data is a row vector converts it to column vector
    dataf=dataf';
end
