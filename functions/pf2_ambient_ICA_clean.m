function [data]=pf2_ambient_ICA_clean(rawData,ambientData,channelList,icaWeight,use_fast_ica)
% PF2_AMBIENT_ICA_CLEAN Remove ambient light from fNIRS using per-channel ICA
%
% For each unique channel in channelList, uses ICA (via icaClean) to
% separate and remove the ambient/dark channel contribution from all
% wavelength measurements of that channel. Optionally pads signals with
% ones to stabilize ICA near boundaries.
%
% Syntax:
%   data = pf2_ambient_ICA_clean(rawData, ambientData, channelList)
%   data = pf2_ambient_ICA_clean(rawData, ambientData, channelList, icaWeight)
%   data = pf2_ambient_ICA_clean(rawData, ambientData, channelList, icaWeight, use_fast_ica)
%
% Inputs:
%   rawData     - Raw light intensity [T x (C*W)]
%   ambientData - Ambient channel intensity [T x C]
%   channelList - Channel number mapping [1 x (C*W)]
%   icaWeight   - Padding length added at signal boundaries (default: 0)
%   use_fast_ica - Use FastICA (true) or runica (false) (default: false)
%
% Outputs:
%   data - Ambient-corrected raw intensity [T x (C*W)]
%
% Notes:
%   - Requires FastICA toolbox or EEGLAB's runica on the MATLAB path
%   - Delegates per-channel ICA to icaClean.m
%
% See also: icaClean, pf2_subtractAmbient, pf2_Intensity2OD

if(nargin<5)
   use_fast_ica=false;
end

if(nargin<4)
    icaWeight=0;
end

[uCh]=unique(channelList);

numRawCh=size(rawData,2);
numAmbCh=size(ambientData,2);

if(icaWeight>0)
   rawData=[ones(icaWeight,numRawCh);rawData;ones(icaWeight,numRawCh)];
   ambientData=[ones(icaWeight,numAmbCh);ambientData;ones(icaWeight,numAmbCh)];
end

for i=1:length(uCh)
    chCols = find(channelList==uCh(i));
    for i2=1:length(chCols)
        rawData(:,chCols(i2))=icaClean(rawData(:,chCols(i2)),ambientData(:,i),use_fast_ica);
    end
end

data=rawData(icaWeight+1:end-icaWeight,:);

end
