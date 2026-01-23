function dod = pf2_Intensity2OD( d )
% PF2_INTENSITY2OD Convert raw light intensity to optical density
%
% Converts raw light intensity measurements to optical density (OD) using the
% logarithmic transform from Beer-Lambert law. This is the first step in
% converting fNIRS raw data to hemoglobin concentrations. Normalizes to the
% mean intensity and applies log10 transformation.
%
% Reference:
%   Imported from HomerLibrary, modified to use log10 instead of natural log.
%   Standard Beer-Lambert law: OD = -log10(I / I0)
%
% Syntax:
%   dod = pf2_Intensity2OD(d)
%
% Inputs:
%   d - Raw light intensity matrix [T x C double]
%       T = number of time samples, C = number of channels (wavelengths)
%       Values should be positive; zero/negative values trigger a warning.
%
% Outputs:
%   dod - Optical density matrix [T x C double], same size as input
%         Computed as: -log10(abs(d) / mean(abs(d)))
%         Positive values indicate decreased light transmission.
%
% Algorithm:
%   1. Compute temporal mean intensity for each channel: dm = mean(abs(d))
%   2. Normalize by mean: d_norm = abs(d) / dm
%   3. Apply logarithmic transform: dod = -log10(d_norm)
%
% Example:
%   % Convert raw intensity to OD
%   data = pf2.Import.SampleData.fNIR2000();
%   od = pf2_Intensity2OD(data.raw);
%   fprintf('OD range: [%.3f, %.3f]\n', min(od(:)), max(od(:)));
%
%   % Check for invalid values
%   if any(data.raw(:) <= 0)
%       warning('Non-positive values detected in raw data');
%   end
%
% Notes:
%   - Issues warning if any data points are zero or negative
%   - Uses abs() to handle any sign issues in raw data
%   - NaN values in input will propagate to output
%
% See also: pf2_base.fnirs.bvoxy, processStageRaw2OD, pf2_base.fnirs.processStageOD2Hb

% convert to dod
dm = nanmean(abs(d),1);
nTpts = size(d,1);
dod = -log10(abs(d)./(ones(nTpts,1)*dm));

if ~isempty(find(d(:)<=0))
    disp( 'OD conversion WARNING: Some data points in d are zero or negative.' );
end
