function result = wcoherence(x, y, fs, varargin)
% WCOHERENCE Wavelet coherence (WCT) between two time series
%
% Computes wavelet coherence using the continuous wavelet transform,
% providing time-frequency resolved coupling between two signals.
% Returns mean coherence in a frequency band as the scalar coupling
% value, plus the full time-frequency coherence matrix for visualization.
%
% Syntax:
%   result = exploreFNIRS.coupling.wcoherence(x, y, fs)
%   result = exploreFNIRS.coupling.wcoherence(x, y, fs, 'FreqRange', [0.01 0.1])
%   result = exploreFNIRS.coupling.wcoherence(x, y, fs, 'PhaseOutput', true)
%
% Inputs:
%   x  - [T x 1] First time series (column vector)
%   y  - [T x 1] Second time series (column vector)
%   fs - Sampling frequency (Hz), positive scalar
%
% Name-Value Parameters:
%   FreqRange       - [fLow fHigh] frequency band in Hz (default: [0.01, fs/2])
%                     Typical fNIRS: [0.01, 0.1] for hemodynamic
%   VoicesPerOctave - Frequency resolution (default: 10, range 1-48)
%   ApplyCOI        - Exclude cone-of-influence region from scalar value
%                     (default: true)
%   PhaseOutput     - Return phase angles from cross-spectrum (default: false)
%   CwtX            - Pre-computed CWT struct for x (from pf2_base.wavelet.cwt).
%                     Skips CWT computation for x when provided.
%   CwtY            - Pre-computed CWT struct for y (from pf2_base.wavelet.cwt).
%                     Skips CWT computation for y when provided.
%
% Outputs:
%   result - Struct with fields:
%     .value     - Mean WCT magnitude in FreqRange (scalar, COI-masked if enabled)
%     .pvalue    - NaN (use permutation test for significance)
%     .method    - 'wcoherence'
%     .windowed  - false
%     .wcoh      - [F x T] wavelet coherence matrix (0 to 1)
%     .freqs     - [F x 1] frequency vector (Hz)
%     .times     - [T x 1] time vector (seconds)
%     .coi       - [T x 1] cone of influence boundary (Hz)
%     .freqRange - [fLow fHigh] band used for scalar value
%     .phase     - [F x T] phase angles in radians (if PhaseOutput=true)
%
% Notes:
%   No Wavelet Toolbox required. Delegates to pf2_base.wavelet.wcoherence
%   which uses an FFT-based Morlet CWT.
%
%   The cone of influence marks the region where edge effects are
%   significant. By default, these regions are excluded from the scalar
%   .value computation.
%
% References:
%   Grinsted, A., Moore, J.C. & Jevrejeva, S. (2004). Application of the
%   cross wavelet transform and wavelet coherence to geophysical time
%   series. Nonlinear Processes in Geophysics, 11, 561-566.
%
% See also: exploreFNIRS.coupling.coherence, exploreFNIRS.coupling.pearson,
%   exploreFNIRS.coupling.plotWcoherence, pf2_base.wavelet.wcoherence

    result = pf2_base.wavelet.wcoherence(x, y, fs, varargin{:});

end
