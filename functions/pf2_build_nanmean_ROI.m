function roi_out=pf2_build_nanmean_ROI(fNIR)
% PF2_BUILD_NANMEAN_ROI Build ROI signals using nanmean averaging
%
% Constructs Region of Interest (ROI) time series by averaging the specified
% channels using nanmean. This is the standard approach for creating ROI
% signals when channels may contain NaN values (e.g., from artifact rejection).
%
% The function reads ROI definitions from the fNIR.ROI.info field and applies
% nanmean across the channels belonging to each ROI, ignoring NaN values.
%
% Reference:
%   Internal pf2 implementation. Standard ROI averaging approach.
%
% Syntax:
%   roi_out = pf2_build_nanmean_ROI(fNIR)
%
% Inputs:
%   fNIR - fNIRS data structure containing:
%          .HbO, .HbR, .HbTotal, .HbDiff - Hemoglobin time series [T x C]
%          .ROI.info - Table defining ROI channel assignments
%                      RowNames: ROI names (e.g., 'LeftPFC', 'RightPFC')
%                      Column 'Optodes' or 'Channels': cell array of channel
%                      numbers belonging to each ROI
%
% Outputs:
%   roi_out - fNIRS structure with ROI fields populated:
%             .ROI.HbO, .ROI.HbR, etc. - [T x R] where R = number of ROIs
%             Each column is the nanmean of the channels in that ROI
%
% ROI Definition Formats:
%   Well-defined ROI (table format):
%     fNIR.ROI.info = table({[1,2,3,4]; [5,6,7,8]}, ...
%                          'VariableNames', {'Optodes'}, ...
%                          'RowNames', {'LeftPFC', 'RightPFC'});
%
%   Weakly-defined ROI (cell array - auto-named as ROI1, ROI2, ...):
%     fNIR.ROI.info = {[1,2,3,4]; [5,6,7,8]};
%
% Example:
%   % Define ROIs for a frontal probe
%   fNIR.ROI.info = table({[1,2,3]; [7,8,9]}, ...
%                        'VariableNames', {'Optodes'}, ...
%                        'RowNames', {'LeftDLPFC', 'RightDLPFC'});
%
%   % Build ROI averages
%   fNIR = pf2_build_nanmean_ROI(fNIR);
%
%   % Plot ROI time series
%   plot(fNIR.time, fNIR.ROI.HbO);
%   legend(fNIR.ROI.info.Properties.RowNames);
%
% Notes:
%   - Uses nanmean to handle NaN values from artifact rejection
%   - If all channels in an ROI are NaN at a time point, ROI value is NaN
%   - For PCA-based ROI construction, use pf2_build_pca_ROI instead
%
% See also: pf2_build_pca_ROI, pf2_base.fnirs.ezBuildROI, pf2_base.fnirs.buildROI

roi_out=pf2_base.fnirs.ezBuildROI(fNIR,@nanmean);

end
