% This script is available for download to academic researchers for
% internal research use only. All commercial use requires a license 
% from Stanford's OTL. Please contact imelda.oropeza@stanford.edu for 
% more details.
%
% -------------------------------------------------------------------
%
% assume the original signal is oxy and deoxy, and the corrected signal is
% oxy0.
%
% Xu Cui
% Stanford University
% 2009/09/28

% offline version (post-experiment data analysis)

function cOxy=calcCBSI(oxy,deoxy)

if(~isempty(oxy)&&size(oxy,1)==size(deoxy,1)&&size(oxy,2)==size(deoxy,2))

    alpha = nanstd(oxy)./nanstd(deoxy);
    oxy0=zeros(size(oxy));
    for i=1:length(alpha)
       oxy0(:,i)=oxy(:,i)-alpha(i)*deoxy(:,i); 
    end
    %oxy0 = oxy - alpha .* deoxy;
    cOxy= real(oxy0 / 2);

elseif(isempty(oxy))
    cOxy=[];
    warning('CBSI error: Oxy arrays and Deoxy arrays are empty');
else
    error('Oxy and Deoxy size mismatch');
end

%% online version (real time)
%windowSize = 100;
%for kk=2:N % as time goes, more and more data is coming
%    alpha = std(oxy(max(1,kk-windowSize*10):kk,:)) ./ std(deoxy(max(1,kk-windowSize*10):kk,:));
%    oxy0(kk) = ( oxy(kk) - alpha .* deoxy(kk) ) / 2;
%nd