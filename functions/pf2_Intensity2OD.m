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
%   data = pf2.import.sampleData.fNIR2000();
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
nTpts = size(d,1);

% Compute baseline mean from positive values only so that zero-padded
% regions do not drag down the mean and distort good samples' OD.
dAbs = abs(d);
dPos = dAbs;
dPos(dPos <= 0) = NaN;
dm = mean(dPos, 1, 'omitnan');

% Dead channels (no positive samples) → NaN baseline
dm(dm == 0 | isnan(dm)) = NaN;

dod = -log10(dAbs ./ (ones(nTpts,1) * dm));

% Replace any remaining non-finite values (from zero/negative raw) with NaN
dod(~isfinite(dod)) = NaN;

if any(d(:) <= 0)
    disp( 'OD conversion WARNING: Some data points in d are zero or negative.' );
end
