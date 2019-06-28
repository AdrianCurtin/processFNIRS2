function [maskCV]=pf2_SMAR_mask(x,N,tauUp,tauLow)
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
    tauLow=-1;
end

if(N<1)
    error('Invalid Window Length');
end

CVx=calcLocalCV(x,N);


maskCV=(abs(CVx)<tauUp&~isnan(CVx)&abs(CVx)>tauLow);

    
    

end


%%_Subfunctions_________________________________________________________

%__________________________________________________________________________
function [CVx] = calcLocalCV(x,N)
% Function to calculate coefficient of variation for use in SMAR technique
% x:	input signal
% N:	window length for SMAR

if nargin<1
    error('Not enough Input arguments');
end

if(N<1)
    error('Invalid Window Length');
end

l=size(x);
wid=l(2);%width
len=l(1);%length

if(rem(N,2)==0)
   
    N=N+1; 
   
end

wSize=(N-1)/2;

CVx=nan(len,wid);

for i=wSize+1:len-wSize
    idx=i-wSize:i+wSize;
    x_val=x(idx,:);
    CVx(i,:)=std(x_val)/nanmean(x_val);
end


end