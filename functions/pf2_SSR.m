function [fNIR] = pf2_SSR(fNIR, method, numPCs)
% PF2_SSR Short-separation channel regression for superficial signal removal
%
% Wrapper for pf2_base.fnirs.shortChannelRegression that is compatible with
% the processFNIRS2 method chain system. Removes physiological noise from
% scalp and extracerebral tissue using short-separation channel data as a
% proxy for superficial hemodynamics.
%
% Reference:
%   Saager, R. B. & Berger, A. J. (2005). Direct characterization and
%   removal of interfering absorption trends in two-layer turbid media.
%   J. Opt. Soc. Am. A, 22(9), 1874-1882.
%
% Syntax:
%   fNIR = pf2_SSR(fNIR)
%   fNIR = pf2_SSR(fNIR, method)
%   fNIR = pf2_SSR(fNIR, method, numPCs)
%
% Inputs:
%   fNIR   - Processed fNIRS data structure with hemoglobin fields
%   method - Regression method: 'nearest' (default), 'pca', or 'all'
%   numPCs - Number of principal components for 'pca' method (default: 1)
%
% Outputs:
%   fNIR - Corrected fNIRS structure with superficial signal removed
%
% Algorithm:
%   1. Delegates to pf2_base.fnirs.shortChannelRegression
%   2. If no short channels found, returns data unchanged with warning
%
% Example:
%   data = pf2.import.importSNIRF('subject01.snirf', false);
%   processed = processFNIRS2(data);
%   corrected = pf2_SSR(processed, 'nearest');
%
% Notes:
%   - Intended for use in oxy processing method chains
%   - Requires probeinfo with IsShortSeparation field
%   - Applied after Beer-Lambert conversion (operates on HbO/HbR)
%
% See also: pf2_base.fnirs.shortChannelRegression, pf2_MotionCorrectTDDR

if nargin < 2 || isempty(method)
    method = 'nearest';
end

if nargin < 3 || isempty(numPCs)
    numPCs = 1;
end

fNIR = pf2_base.fnirs.shortChannelRegression(fNIR, ...
    'Method', method, 'NumPCs', numPCs);

end
