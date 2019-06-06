function [Xcorr, maskCV]=SMAR_1100(x,N,tauUp,tauLow,tauDark,mask)

% Implementation of Sliding Motion Artificat Rejection algorithim from Ayaz, 2010
% Specifically for fNIR11000 model

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

if(nargin<5)
    tauDark=0.015;
end

if(size(x,2)==49&&nargin<6)
    mask=[1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1];
elseif(nargin<6)
       if(min(size(x))==1) % single channel mode
           mask=1;
       else
           mask=ones(size(x(:,2))); 
       end
end

sat=4300;

if(N<1)
    error('Invalid Window Length');
end

padLength=floor(N/2);
x_length=size(x,1);
x_padded=nan(x_length+N,size(x,2));

x_padded(1+padLength:x_length+padLength,:)=x;

CV=calcLocalCV(x_padded,N);

maskCV=nan(size(CV));
s=size(CV);

if s(2)==49
    time=x(:,1);
end

Xn=zeros(size(x));
for n=1:length(x)
    Xn(n,:)=nansum(x_padded(padLength+n:n+N,:))/(N+1);
end

for i=1:s(2)
    if(mask(i))
        maskCV(:,i)=max((CV(:,i)>tauUp),((CV(:,i)<tauLow).*(Xn(:,i)>sat)));
    else
        maskCV(:,i)=CV(:,i)>tauDark;
    end
end

Xcorr=x.*~maskCV;
Xcorr(maskCV==1)=NaN;

ch=28;
x2=x;
x2(maskCV==1)=nan;
CV2=CV;
CV2(maskCV==1)=nan;
subplot(1,2,1);
plot(x(:,ch));
hold on
plot(x2(:,ch),'r');
hold off
subplot(1,2,2);
plot(CV(:,ch));
hold on
plot(CV2(:,ch),'r');
hold off

%Xcorr=Xcorr(padLength+1:x_length+padLength,:);


end