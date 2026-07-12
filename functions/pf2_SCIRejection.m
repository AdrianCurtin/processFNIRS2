function fMask = pf2_SCIRejection(fNIR, threshold, cardiacBand)
% PF2_SCIREJECTION Channel rejection based on Scalp Coupling Index
%
% Evaluates raw fNIRS signal quality using the Scalp Coupling Index (SCI),
% which measures how well cardiac pulsations correlate across the two
% wavelengths at each channel. Good optode-scalp coupling means both
% wavelengths capture the same heartbeat, yielding high cross-correlation.
% Channels with SCI below the threshold are rejected.
%
% Unlike Takizawa rejection (which operates on processed hemoglobin data),
% SCI operates on raw intensity and can be applied as a pre-processing
% quality check before any signal processing.
%
% Reference:
%   Pollonini, L., Olds, C., Abaya, H., Bortfeld, H., Beauchamp, M. S.,
%   & Oghalai, J. S. (2014). Auditory cortex activation to natural speech
%   and simulated cochlear implant speech measured with functional
%   near-infrared spectroscopy. Hearing Research, 309, 84-93.
%   DOI: 10.1016/j.hearres.2013.11.007
%
% Syntax:
%   fMask = pf2_SCIRejection(fNIR)
%   fMask = pf2_SCIRejection(fNIR, threshold)
%   fMask = pf2_SCIRejection(fNIR, threshold, cardiacBand)
%
% Inputs:
%   fNIR        - fNIRS data struct with at minimum .raw and .fs fields.
%                 Wavelength layout is resolved from probeinfo or
%                 info.synthetic (see pf2.qc.sci for details).
%   threshold   - SCI threshold for good/bad classification (default: 0.75)
%                 Channels with SCI >= threshold are kept. Typical: 0.5-0.8.
%   cardiacBand - [1x2] cardiac frequency band in Hz (default: [0.5, 2.5])
%
% Outputs:
%   fMask - Logical channel mask [1 x C] where 1=good, 0=rejected
%           Same format as pf2_TakizawaRejection output.
%
% Algorithm:
%   1. Compute SCI via pf2.qc.sci() for all channels
%   2. Mark channels with SCI < threshold as rejected
%   3. Return logical mask (1=good, 0=bad)
%
% Example:
%   data = pf2.import.importNIR('subject01.nir');
%   fMask = pf2_SCIRejection(data);
%   fprintf('Rejected %d/%d channels\n', sum(~fMask), numel(fMask));
%
%   % Stricter threshold
%   fMask = pf2_SCIRejection(data, 0.8);
%
%   % Apply to data
%   data.fchMask = data.fchMask & fMask;
%
% See also: pf2.qc.sci, pf2_TakizawaRejection, pf2.qc.plotQuality

%% Defaults
if nargin < 3, cardiacBand = [0.5, 2.5]; end
if nargin < 2, threshold = 0.75; end

%% Validate
assert(isfield(fNIR, 'raw'), 'pf2:SCIRejection:noRaw', ...
    'Data struct must contain .raw field for SCI computation.');
assert(isfield(fNIR, 'fs'), 'pf2:SCIRejection:noFs', ...
    'Data struct must contain .fs field.');

%% Check Nyquist
nyquist = fNIR.fs / 2;
if cardiacBand(2) >= nyquist
    warning('pf2:SCIRejection:nyquist', ...
        'Cardiac band upper limit (%.1f Hz) >= Nyquist (%.1f Hz). Adjusting.', ...
        cardiacBand(2), nyquist);
    cardiacBand(2) = nyquist * 0.9;
end

%% Compute SCI
try
    sciResult = pf2.qc.sci(fNIR, 'Threshold', threshold, 'CardiacBand', cardiacBand);
catch ME
    warning('pf2:SCIRejection:sciFailed', ...
        'SCI computation failed: %s. Returning all-good mask.', ME.message);
    % Determine channel count from fchMask or raw
    if isfield(fNIR, 'fchMask')
        fMask = true(size(fNIR.fchMask));
    else
        nCh = size(fNIR.raw, 2) / 2;  % Assume 2 wavelengths
        fMask = true(1, nCh);
    end
    return;
end

%% Build mask
% sciResult.isGood is [1 x nChannels] logical
fMask = sciResult.isGood;

end
