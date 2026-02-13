function fnir=applyChannelMask(fnir, rejectLevel)
% APPLYCHANNELMASK Set bad channels to NaN based on channel quality mask
%
% Applies the channel rejection mask (fchMask) to all biomarker fields in
% an fNIRS struct by setting data from rejected channels to NaN. Channels
% with fchMask values at or below the rejectLevel threshold are considered
% rejected. This allows downstream analysis to ignore poor quality channels
% while preserving data structure dimensions.
%
% Syntax:
%   fnir = pf2.data.applyChannelMask(fnir)
%   fnir = pf2.data.applyChannelMask(fnir, rejectLevel)
%
% Inputs:
%   fnir        - fNIRS data structure [struct]
%                 Must contain 'fchMask' field [1 x C] where values indicate
%                 channel quality (1=good, 0.5=marginal, 0=bad). Biomarker
%                 fields (HbO, HbR, HbTotal, HbDiff, CBSI) will be modified.
%   rejectLevel - (optional) Rejection threshold (default: 0)
%                 Channels with fchMask <= rejectLevel are set to NaN.
%                 0 = reject only fully bad channels, 0.5 = also reject marginal.
%
% Outputs:
%   fnir - Modified fNIRS struct with rejected channels set to NaN [struct]
%          Biomarker data columns for channels where fchMask <= rejectLevel
%          are replaced with NaN values.
%
% Example:
%   % Load and process data, then apply channel mask
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%
%   % Mark channels 3 and 5 as bad
%   processed.fchMask([3, 5]) = 0;
%
%   % Apply the mask to set those channels to NaN
%   masked = pf2.data.applyChannelMask(processed);
%   fprintf('Channel 3 is now NaN: %d\n', all(isnan(masked.HbO(:,3))));
%
% Notes:
%   - Only affects biomarker fields (HbO, HbR, etc.), not raw data
%   - Channel dimensions are preserved; rejected data becomes NaN
%
% See also: pf2.data.editChannelMaskGUI, processFNIRS2, pf2.settings.setRejectLevel

if nargin < 2 || isempty(rejectLevel)
    rejectLevel = 0;
end

validFields=pf2_base.pf2_getFNIRSbiomFields();

if(isfield(fnir,'fchMask'))
    for i=1:length(validFields)
       if(isfield(fnir,validFields{i}))
          fnir.(validFields{i})(:,~(fnir.fchMask>rejectLevel))=NaN;
       end
    end
end

end