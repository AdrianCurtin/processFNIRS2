function fNIR = physioRegress(fNIR, varargin)
% PHYSIOREGRESS Adaptive physiological (cardiac) nuisance regression
%
% Removes cardiac oscillations from the hemoglobin signal using the MEASURED
% heart rate, rather than a fixed frequency band. Heart rate is taken from an
% HR feature signal or derived from a PPG/EKG waveform, converted to an
% instantaneous phase, and expanded into sine/cosine regressors at the
% fundamental and its harmonics (a RETROICOR-style correction). This adapts to
% drifting/elevated heart rates (e.g. aroused toddlers) where a static notch
% is fragile.
%
% Reference:
%   Glover, G. H., Li, T. Q., & Ress, D. (2000). Image-based method for
%   retrospective correction of physiological motion effects in fMRI:
%   RETROICOR. Magnetic Resonance in Medicine, 44(1), 162-167.
%   DOI: 10.1002/1522-2594(200007)44:1<162::AID-MRM23>3.0.CO;2-E
%
% Syntax:
%   fNIR = pf2_base.fnirs.physioRegress(fNIR)
%   fNIR = pf2_base.fnirs.physioRegress(fNIR, 'Name', Value)
%
% Inputs:
%   fNIR - Processed fNIRS struct with hemoglobin fields and a cardiac-related
%          signal in .Aux (HR, PPG, or EKG).
%
% Name-Value Parameters:
%   'Signal'     - Aux signal name (default: auto-detect, preferring HR, then
%                  PPG, then EKG).
%   'Harmonics'  - Number of harmonics to model (default: 2).
%   'Biomarkers' - Fields to correct (default: {'HbO','HbR'}).
%
% Outputs:
%   fNIR - Corrected struct (channel means preserved). When both HbO and HbR
%          are corrected, the derived fields (HbTotal/HbDiff/CBSI) are
%          recomputed so they stay consistent. A .physioRegressInfo field
%          records the signal, mean frequency, and harmonics. If no cardiac
%          signal is present, the input is returned unchanged with a warning
%          (graceful no-op).
%
% Algorithm:
%   1. Obtain an instantaneous heart-rate series (HR feature used directly;
%      PPG/EKG waveforms passed through pf2.data.aux.heartRateFrom).
%   2. Resample HR onto the fNIRS time base and integrate to a phase phi(t).
%   3. Build regressors [cos(k*phi), sin(k*phi)] for k = 1..Harmonics.
%   4. Remove the regressor contribution from each channel by least squares.
%
% Example:
%   proc = processFNIRS2(data);
%   proc = pf2_base.fnirs.physioRegress(proc, 'Harmonics', 3);
%
% See also: pf2.data.aux.heartRateFrom, pf2_base.fnirs.accelRegress,
%           pf2_base.fnirs.shortChannelRegression

p = inputParser;
p.addRequired('fNIR', @isstruct);
p.addParameter('Signal', '', @(x) ischar(x) || isstring(x));
p.addParameter('Harmonics', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('Biomarkers', {'HbO', 'HbR'}, @iscell);
p.parse(fNIR, varargin{:});
nHarm = round(p.Results.Harmonics);
biomarkers = p.Results.Biomarkers;

% --- Resolve a cardiac signal (HR > PPG > EKG) ---------------------------
sigName = char(string(p.Results.Signal));
if isempty(sigName)
    for cand = {'HR', 'PPG', 'EKG'}
        nm = pf2_base.fnirs.findAuxByType(fNIR, cand{1}, '');
        if ~isempty(nm)
            sigName = nm;
            break;
        end
    end
end

if isempty(sigName) || ~isfield(fNIR, 'Aux') || isempty(fNIR.Aux)
    warning('pf2:physioRegress:noSignal', ...
        'No cardiac (HR/PPG/EKG) Aux signal found; returning input unchanged.');
    return;
end

try
    sig = pf2_base.resolveAux(fNIR.Aux, sigName);
catch
    warning('pf2:physioRegress:noSignal', ...
        'Cardiac signal "%s" could not be resolved; returning unchanged.', sigName);
    return;
end

tNative = sig.time(:);
fsN = 1 / median(diff(tNative));
x = sig.data(:, 1);

switch sig.type
    case {'PPG', 'EKG'}
        hrNative = pf2.data.aux.heartRateFrom(x, fsN);
    otherwise
        % HR (bpm) feature, or an unknown signal treated as an HR series
        hrNative = x;
end

% --- Instantaneous phase on the fNIRS grid -------------------------------
t = fNIR.time(:);
hrGrid = interp1(tNative, hrNative, t, 'linear', 'extrap');
fHz = hrGrid / 60;                       % bpm -> Hz
fHz = max(fHz, 30/60);                    % floor at 30 bpm (avoid non-increasing phase)
phi = 2 * pi * cumtrapz(t, fHz);         % instantaneous cardiac phase

% Aliasing guard: fNIRS sampling rates are low, so the cardiac fundamental
% (and especially its harmonics) can sit at or above Nyquist, where the
% sinusoidal regressors alias to low frequencies and would remove genuine
% hemodynamic variance. Drop harmonics above Nyquist; refuse entirely if even
% the fundamental is unresolved.
fsGrid = 1 / median(diff(t));
nyq = fsGrid / 2;
meanF = mean(fHz, 'omitnan');
if meanF >= nyq
    warning('pf2:physioRegress:aliased', ...
        ['Mean cardiac frequency (%.2f Hz) is at/above Nyquist (%.2f Hz) for ', ...
         'fs=%.2f Hz; cardiac regression would alias onto neural variance. ', ...
         'Returning input unchanged.'], meanF, nyq, fsGrid);
    return;
end
nHarmEff = min(nHarm, max(1, floor(nyq / max(meanF, eps))));
if nHarmEff < nHarm
    warning('pf2:physioRegress:harmonicsClipped', ...
        'Clipped harmonics from %d to %d to stay below Nyquist (%.2f Hz).', ...
        nHarm, nHarmEff, nyq);
end

% --- RETROICOR-style regressors ------------------------------------------
R = zeros(numel(t), 2 * nHarmEff);
for k = 1:nHarmEff
    R(:, 2*k-1) = cos(k * phi);
    R(:, 2*k)   = sin(k * phi);
end

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

fNIR.physioRegressInfo = struct('signal', sigName, 'type', sig.type, ...
    'harmonics', nHarmEff, 'requestedHarmonics', nHarm, ...
    'meanFreqHz', meanF, 'nyquistHz', nyq, ...
    'biomarkers', {biomarkers});

end

%%_Subfunctions_________________________________________________________

function y = regressOut(y, X)
% REGRESSOUT Remove variance explained by regressors X from y (mean retained)
validMask = ~isnan(y) & all(~isnan(X), 2);
if sum(validMask) < size(X, 2) + 1
    return;
end
Xreg = [X(validMask, :), ones(sum(validMask), 1)];
beta = pinv(Xreg) * y(validMask);
Xfull = [X, ones(size(X, 1), 1)];
y = y - Xfull * beta + beta(end);
end
