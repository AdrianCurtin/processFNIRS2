function dataOut=applyTimeChMask(data,ftimeChMask)
% APPLYTIMECHMASK Apply a time-by-channel logical mask by NaN-ing bad samples
%
% Applies a per-sample, per-channel logical mask to a signal matrix by
% replacing every entry flagged as bad (mask == false) with NaN. The mask
% has the same dimensions as the data, so it can encode both whole-channel
% rejection and time-localized artifact rejection (e.g. the masks produced
% by SMAR or threshold-based detectors) in a single operation.
%
% Reference:
%   Internal pf2 implementation. Standard NaN-masking convention used
%   throughout the pf2 motion-artifact and quality-control pipeline.
%
% Syntax:
%   dataOut = applyTimeChMask(data, ftimeChMask)
%
% Inputs:
%   data        - Input signal matrix [T x C] where T=samples, C=channels
%                 Can be raw intensity, optical density, or hemoglobin data.
%   ftimeChMask - Logical mask [T x C] with the same size as data
%                 true  = keep the sample (good)
%                 false = reject the sample (replaced with NaN)
%
% Outputs:
%   dataOut - Masked signal matrix [T x C], same size as input
%             Samples where ftimeChMask is false are set to NaN; all other
%             samples are returned unchanged.
%
% Algorithm:
%   1. Set data(~ftimeChMask) = NaN (reject flagged samples in place)
%   2. Return the masked matrix
%
% Example:
%   % Reject motion-artifact samples flagged by SMAR
%   data = pf2.import.sampleData.fNIR2000();
%   mask = pf2_SMAR_mask(data.raw);          % true = clean
%   cleaned = applyTimeChMask(data.raw, mask);
%   fprintf('Rejected %.1f%% of samples\n', 100*mean(isnan(cleaned(:))));
%
% Notes:
%   - The mask must match the size of data exactly; mismatched dimensions
%     will error during logical indexing.
%   - NaN values already present in data are preserved.
%
% See also: pf2_SMAR_mask, pf2_thresholdValues_mask, pf2_thresholdValues

data(~ftimeChMask)=nan;

dataOut=data;