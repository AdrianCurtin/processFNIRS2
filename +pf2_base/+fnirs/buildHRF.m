function [ hrf ] = buildHRF(fs,t, alpha1,alpha2,beta1,beta2,c )
%buildHRF(fs)
%Generates and HRF function (at sampling frequency fs) via the parameters 
%specified via the equation A1 described in:
% Lindquist MA, Meng Loh J, Atlas LY, Wager TD. 
% Modeling the hemodynamic response function in fMRI: efficiency, bias and mis-modeling. 
% Neuroimage. 2009;45(1 Suppl):S187–S198. doi:10.1016/j.neuroimage.2008.10.065
% http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3318970/
if(nargin<1)
    fs=20;
end

if(nargin<2)
    t=15;
end

if(nargin<6)% Values specified next to A1
    alpha1=6;
    alpha2=16;
    beta1=1;
    beta2=beta1;
    c=1/6;
end

time=0:1/fs:t;


% Via equation A1
hrf=(time.^(alpha1-1).*beta1^alpha1.*exp(-beta1.*time))./gamma(alpha1)...
    -c*(time.^(alpha2-1)*beta2^alpha2.*exp(-beta2.*time))./gamma(alpha2);

hrf=hrf/max(hrf);

iEnd=find(hrf<0);

hrf=[time;hrf]';

%hrf=hrf(1:iEnd,:);

hrf(iEnd:end,2)=0;

end

