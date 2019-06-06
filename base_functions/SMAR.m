function [Xcorr, maskCV]=SMAR(x,N,tauUp,tauLow)
% Implementation of Sliding Motion Artificat Rejection algorithim from Ayaz, 2010


if nargin<1
    error('Not enough Input arguments');
elseif nargin==1
     N=10;  %Default Window Length
end

if(nargin<3)
     tauUp=0.025;
end

if(nargin<4)
    tauLow=0.003;
end

if(N<1)
    error('Invalid Window Length');
end

CV=calcLocalCV(x,N);

maskCV=zeros(size(CV));
s=size(CV);

 Xn=zeros(size(CV));
for n=1:length(CV)
    Xn(n,:)=sum(x(n:n+N,:))/(N+1);
end

for i=1:s(2)
    maskCV(:,i)=max((CV(:,i)>tauUp),((CV(:,i)<tauLow)));
end

maskCVout=ones(size(x));
maskCVout(round(N/2):round(length(x)-N/2-1),:)=maskCV;

Xcorr=x;
%Xcorr=Xcorr.*~maskCV;
Xcorr(maskCVout==1)=NaN;

end