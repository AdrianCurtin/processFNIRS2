function fNIR = accelRegress(fNIR, varargin)
% ACCELREGRESS Remove motion artifact using accelerometer regressors
%
% Regresses an accelerometer/IMU signal (and derived motion features) out of
% the hemoglobin time series. Unlike data-driven motion correction (TDDR,
% spline, wavelet), this uses an INDEPENDENT motion reference, which helps
% disambiguate true head movement from neural transients in motion-prone
% populations.
%
% Reference:
%   Metz, A. J., Wolf, M., Achermann, P., & Scholkmann, F. (2015). A new
%   approach for automatic removal of movement artifacts in near-infrared
%   spectroscopy time series by means of acceleration data. Algorithms, 8(4),
%   1052-1075. DOI: 10.3390/a8041052
%
% Syntax:
%   fNIR = pf2_base.fnirs.accelRegress(fNIR)
%   fNIR = pf2_base.fnirs.accelRegress(fNIR, 'Name', Value)
%
% Inputs:
%   fNIR - Processed fNIRS struct with hemoglobin fields and an accelerometer
%          signal in .Aux.
%
% Name-Value Parameters:
%   'Signal'       - Aux signal name (default: auto-detected ACCEL signal,
%                    falling back to 'accelerometer').
%   'Biomarkers'   - Fields to correct (default: {'HbO','HbR'}).
%   'IncludeAxes'  - Use the individual axes (aligned to the grid) as
%                    regressors (default: true).
%   'IncludeNorm'  - Use the gravity-removed vector norm (default: true).
%   'IncludeJerk'  - Use the jerk (derivative of the norm) (default: true).
%
% Outputs:
%   fNIR - Corrected struct. The mean of each channel is preserved; only the
%          accelerometer-explained variance is removed. When both HbO and HbR
%          are corrected, the derived fields (HbTotal/HbDiff/CBSI) are
%          recomputed so they stay consistent. A .accelRegressInfo field
%          records the signal, regressors, and biomarkers used.
%
% Algorithm:
%   Aligns the accelerometer to fNIRS time (pf2.data.auxOnGrid), assembles the
%   regressor set (axes / norm / jerk), and removes the regressor contribution
%   from each channel via least squares (mean retained).
%
% Example:
%   proc = processFNIRS2(data);
%   proc = pf2_base.fnirs.accelRegress(proc);
%
% See also: pf2_base.fnirs.accelMotionDetect, pf2.data.aux.accelFeatures,
%           pf2_base.fnirs.shortChannelRegression

p = inputParser;
p.addRequired('fNIR', @isstruct);
p.addParameter('Signal', '', @(x) ischar(x) || isstring(x));
p.addParameter('Biomarkers', {'HbO', 'HbR'}, @iscell);
p.addParameter('IncludeAxes', true, @(x) islogical(x) && isscalar(x));
p.addParameter('IncludeNorm', true, @(x) islogical(x) && isscalar(x));
p.addParameter('IncludeJerk', true, @(x) islogical(x) && isscalar(x));
p.parse(fNIR, varargin{:});
biomarkers = p.Results.Biomarkers;
includeAxes = p.Results.IncludeAxes;
includeNorm = p.Results.IncludeNorm;
includeJerk = p.Results.IncludeJerk;

sigName = char(string(p.Results.Signal));
if isempty(sigName)
    sigName = pf2_base.fnirs.findAuxByType(fNIR, 'ACCEL', 'accelerometer');
end

% Align accelerometer to the fNIRS grid
acc = pf2.data.auxOnGrid(fNIR, sigName);
fs = fNIR.fs;
if isempty(fs) || ~isfinite(fs)
    fs = 1 / median(diff(fNIR.time));
end
feat = pf2.data.aux.accelFeatures(acc, fs);

% Assemble the regressor matrix
R = [];
if includeAxes
    R = [R, acc]; %#ok<AGROW>
end
if includeNorm
    R = [R, feat.norm]; %#ok<AGROW>
end
if includeJerk
    R = [R, feat.jerk]; %#ok<AGROW>
end

if isempty(R)
    warning('pf2:accelRegress:noRegressors', ...
        'No accelerometer regressors selected; returning input unchanged.');
    return;
end

% Mean-center regressors; zero-fill any residual NaN so least squares is finite
R = R - mean(R, 1, 'omitnan');
R(isnan(R)) = 0;

for b = 1:numel(biomarkers)
    fn = biomarkers{b};
    if ~isfield(fNIR, fn)
        continue;
    end
    Y = fNIR.(fn);
    for c = 1:size(Y, 2)
        Y(:, c) = regressOut(Y(:, c), R);
    end
    fNIR.(fn) = Y;
end

% Keep the derived fields (HbTotal/HbDiff/CBSI) consistent with corrected HbO/HbR
fNIR = pf2_base.fnirs.recomputeDerivedHb(fNIR, biomarkers);

fNIR.accelRegressInfo = struct('signal', sigName, 'biomarkers', {biomarkers}, ...
    'includeAxes', includeAxes, 'includeNorm', includeNorm, ...
    'includeJerk', includeJerk, 'nRegressors', size(R, 2));

end

%%_Subfunctions_________________________________________________________

function y = regressOut(y, X)
% REGRESSOUT Remove the variance in y explained by regressors X (mean kept)
validMask = ~isnan(y) & all(~isnan(X), 2);
if sum(validMask) < size(X, 2) + 1
    return;
end
Xreg = [X(validMask, :), ones(sum(validMask), 1)];
beta = pinv(Xreg) * y(validMask);
Xfull = [X, ones(size(X, 1), 1)];
y = y - Xfull * beta + beta(end);
end
