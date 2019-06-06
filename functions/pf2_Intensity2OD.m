% dod = pf2_Intensity2OD( d )
%
% Imported from HomerLibrary, modified to use log10
%
% UI NAME:
% Intensity_to_OD 
%
% Converts internsity (raw data) to optical density
%
% INPUT
% d - intensity data (#time points x #data channels
%
% OUTPUT
% dod - the change in optical density

function dod = pf2_Intensity2OD( d )

% convert to dod
dm = nanmean(abs(d),1);
nTpts = size(d,1);
dod = -log10(abs(d)./(ones(nTpts,1)*dm));

if ~isempty(find(d(:)<=0))
    disp( 'OD conversion WARNING: Some data points in d are zero or negative.' );
end
