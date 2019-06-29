function [maskCV]=pf2_SMAR2(x,N,tauUp,tauDiff)
% Implementation of Sliding Motion Artificat Rejection algorithim from Ayaz, 2010
% Updated with differentiation

if nargin<1
    error('Not enough Input arguments');
elseif nargin==1
     N=10;  %Default Window Length
end

if(nargin<3)
     tauUp=0.2;
end

if(nargin<4)
    tauDiff=0.2;
end

if(N<1)
    error('Invalid Window Length');
end

[CVx,CVdiff]=calcLocalCV(x,N);


Xcorr=x;

maskCV=~(abs(CVx)>tauUp|isnan(CVx)|abs(CVdiff)>tauDiff);


    
    

end


%%_Subfunctions_________________________________________________________

%__________________________________________________________________________
function [CVx,CVdiff] = calcLocalCV(x,N)
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
    CVx(i,:)=nanstd(x_val)./nanmean(x_val);
end

CVdiff=diff(CVx);
CVdiff=[zeros(1,wid);CVdiff];
CVddiff=diff(CVdiff);
CVdiff=[zeros(1,wid);CVddiff];


end