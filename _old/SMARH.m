function Xcorr=SMARH(x,N,tauUp,tauLow)
% SMAR for Hitachi
if nargin<1
    error('Not enough Input arguments');
elseif nargin==1
     N=50;  %Default Window Length
end

if(nargin<3)
    tauUp=0.10;
    tauLow=0.003;
end

sat=5;

if(N<1)
    error('Invalid Window Length');
end

if(size(x,2)>49) %rotate signal if wrong direction
   x=x'; 
end

if(x(1,1)==0&&x(2,1)==0)
   headers=x([1 2],:);
   x([1,2],:)=[];
else
    headers=0;
end

if(x(1:4,1)==[1;2;3;4])
   time=x(:,1); 
else
    time=0;
end

CV=calcLocalCV(x,N);

maskCV=zeros(size(CV));
s=size(CV);

 Xn=zeros(size(CV));
for n=1:length(CV)
    Xn(n,:)=sum(x(n:n+N,:))/(N+1);
end

for i=1:s(2)
    maskCV(:,i)=max((CV(:,i)>tauUp),((CV(:,i)<tauLow).*(Xn(:,i)>sat)));
end

Xcorr=x(N/2:length(x)-N/2-1,:);
Xcorr=Xcorr.*~maskCV;
Xcorr(Xcorr==0)=NaN;

if time~=0
    Xcorr(:,1)=time(N/2:s(1)+N/2-1);
end

if(headers~=0)
   Xcorr=[headers;Xcorr]; 
end
