function y = detrend_3rd_order(x,fs)

order = 3;
for i = 1:size(x,2)
    signal = x(:,i);
    X=(1:length(signal))'/fs;
    XM=ones(length(X),order+1);
    for pn=1:order
        CX=X.^pn;
        XM(:,pn+1)=(CX-mean(CX))/std(CX);
    end
    w=warning('off','all');
    rem_trend = XM*(pinv(XM)*signal);
    signal=signal-rem_trend;
    warning(w);
    y(:,i) = signal;%+x(1,i);
end