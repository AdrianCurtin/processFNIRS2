function [CVx] = calcLocalCV(x,N)
%Calculates absolute-valued coefficient of variation for use in SMAR technique

if nargin<1
    error('Not enough Input arguments');
elseif nargin==1
     N=500;  %Default Window Length
end

if(N<1)
    error('Invalid Window Length');
end

l=size(x);
wid=l(2);%width
len=l(1);%length

xi=zeros(len-N,wid);
xj=zeros(len-N,wid);

CVx=zeros(len-N,wid);

if(len>N)
    for n=1:length(x)-N
        xi(n,:)=sum(x(n:n+N,:))./(N+1);
        for j=0:N
            xj(n,:)=xj(n,:)+(x(n+j,:)-xi(n,:)).^2;
        end
        xj(n)=xj(n)/N;

        CVx(n,:)=sqrt(xj(n,:))./abs(xi(n,:));
    end

else
    CVx(:,:)=nan;
end