function data=pf2_subtractAmbient(rawData,ambientData,channelList)
% PF2_SUBTRACTAMBIENT Subtract ambient light from fNIRS raw intensity
%
% Removes ambient (dark) channel readings from fNIRS raw intensity data
% to correct for background light contamination. Matches ambient channels
% to measurement channels using the channel list mapping.
%
% Ambient light subtraction is a simple but effective preprocessing step
% for fNIRS systems that include dedicated dark/ambient detectors.
%
% Syntax:
%   data = pf2_subtractAmbient(rawData, ambientData, channelList)
%
% Inputs:
%   rawData     - Raw light intensity matrix [T x (C*W)]
%                 T = number of time samples
%                 C*W = channels x wavelengths (interleaved)
%   ambientData - Ambient/dark channel intensity matrix [T x C]
%                 T = number of time samples (must match rawData)
%                 C = number of unique channels
%   channelList - Channel number mapping vector [1 x (C*W)]
%                 Maps each column in rawData to its channel number
%                 Columns with the same channel number share the same
%                 ambient channel (e.g., different wavelengths)
%
% Outputs:
%   data        - Ambient-corrected raw intensity matrix [T x (C*W)]
%                 Same size as rawData
%                 data = rawData - matched_ambient
%
% Algorithm:
%   For each unique channel number in channelList:
%     1. Find all raw columns belonging to this channel
%     2. Subtract the corresponding ambient column from all of them
%
% Notes:
%   - Ambient channels typically measure detector dark current and
%     environmental light leakage
%   - Subtraction should be done BEFORE log transform (Intensity to OD)
%   - channelList allows proper matching when wavelengths are interleaved
%   - NaN values in ambient will propagate to output
%
% Example:
%   % For an 18-channel system with 2 wavelengths interleaved:
%   % rawData is [T x 36], ambientData is [T x 18]
%   channelList = [1:18, 1:18];  % First 18 cols = WL1, second 18 = WL2
%   correctedRaw = pf2_subtractAmbient(rawData, ambientData, channelList);
%
% See also: pf2_ambient_ICA_clean, icaClean, pf2_Intensity2OD

[uCh]=unique(channelList);
%uCh=channelList(idx);


for i=1:length(uCh)
    
   rawData(:,channelList==uCh(i))=rawData(:,channelList==uCh(i))-ambientData(:,i); 
end

data=rawData;