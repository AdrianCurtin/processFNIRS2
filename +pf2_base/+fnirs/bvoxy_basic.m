function [HbO, HbR, Total, HbDiff,CBSI,units]=bvoxy_basic(Iin1,Iin2,wv1,wv2,DPF)

if(nargin<5)
    DPF=[nan,nan];
end

if(nargin<3)
    wv1=700;
    wv2=850;
end



[HbO, HbR, Total, HbDiff,CBSI,~,~,units,~]=pf2_base.fnirs.bvoxy([Iin1,Iin2],1:length(Iin1),[ones(size(wv1))*wv1,ones(size(wv2))*wv2],1:length(Iin1),DPF,'isOD',false);