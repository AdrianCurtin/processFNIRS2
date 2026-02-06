function result = sci(data, varargin)
% SCI Scalp Coupling Index for fNIRS channel quality assessment
%
% Measures optode-scalp contact quality by cross-correlating cardiac
% pulsations across the two wavelengths at each channel. Good coupling
% means both wavelengths see the same heartbeat, yielding a high
% cross-correlation value.
%
% Reference:
%   Pollonini, L., Olds, C., Abaya, H., Bortfeld, H., Beauchamp, M. S.,
%   & Oghalai, J. S. (2014). Auditory cortex activation to natural speech
%   and simulated cochlear implant speech measured with functional
%   near-infrared spectroscopy. Hearing Research, 309, 84-93.
%   DOI: 10.1016/j.hearres.2013.11.007
%
% Syntax:
%   result = pf2.qc.sci(data)
%   result = pf2.qc.sci(data, 'CardiacBand', [0.5, 2.5])
%   result = pf2.qc.sci(data, 'Threshold', 0.8)
%   result = pf2.qc.sci(data, 'Wavelengths', wl, 'ChannelNumbers', ch)
%
% Name-Value Parameters:
%   'CardiacBand'    - [1x2] Bandpass range for cardiac extraction in Hz
%                      (default: [0.5, 2.5])
%   'FilterOrder'    - Butterworth filter order (default: 4)
%   'Wavelengths'    - [1 x C_raw] wavelength per raw column (nm).
%                      Values > 0 = wavelength in nm, 0 = dark, NaN = skip.
%                      Override for when automatic detection fails.
%   'ChannelNumbers' - [1 x C_raw] optode/channel number per raw column.
%                      Must be same length as Wavelengths.
%   'Threshold'      - SCI threshold for good/bad classification
%                      (default: 0.75)
%
% Inputs:
%   data - fNIRS data struct with at minimum:
%          .raw  - [T x C_raw] raw light intensity
%          .fs   - Sampling frequency (Hz)
%          Wavelength layout resolved from (in order):
%            1. Explicit Wavelengths/ChannelNumbers parameters
%            2. data.probeinfo.Probe{1}.TableCh
%            3. data.info.synthetic.wavelengths (alternating ch1_wl1, ch1_wl2, ...)
%
% Outputs:
%   result - Struct with fields:
%            .sci       - [1 x nChannels] SCI values (0 to 1)
%            .isGood    - [1 x nChannels] logical (sci >= threshold)
%            .channels  - [1 x nChannels] channel indices
%            .threshold - Threshold used
%            .cardiacBand - [low, high] Hz
%            .fs        - Sampling rate
%
% Algorithm:
%   1. Resolve wavelength layout from data or explicit parameters
%   2. For each channel, extract the two raw wavelength signals
%   3. Bandpass filter both to the cardiac band using bpf()
%   4. Compute zero-lag normalized cross-correlation
%   5. SCI = abs(cross-correlation value), range 0 to 1
%
% Example:
%   data = pf2.import.importNIR('subject01.nir');
%   result = pf2.qc.sci(data);
%   fprintf('Good channels: %d/%d\n', sum(result.isGood), numel(result.channels));
%
%   % With explicit wavelength layout
%   wl = repmat([730, 850], 1, 18);  % 18 channels, 2 wavelengths each
%   ch = repelem(1:18, 2);
%   result = pf2.qc.sci(data, 'Wavelengths', wl, 'ChannelNumbers', ch);
%
% See also: pf2.qc.powerSpectrum, pf2.qc.plotQuality, bpf

%% Parse inputs
p = inputParser;
p.FunctionName = 'pf2.qc.sci';

addRequired(p, 'data', @isstruct);
addParameter(p, 'CardiacBand', [0.5, 2.5], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'FilterOrder', 4, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Wavelengths', [], @isnumeric);
addParameter(p, 'ChannelNumbers', [], @isnumeric);
addParameter(p, 'Threshold', 0.75, @(x) isnumeric(x) && isscalar(x));

parse(p, data, varargin{:});
opts = p.Results;

%% Validate required fields
assert(isfield(data, 'raw'), 'pf2:qc:sci:noRaw', ...
    'Data struct must contain a .raw field with intensity data.');
assert(isfield(data, 'fs'), 'pf2:qc:sci:noFs', ...
    'Data struct must contain a .fs field with sampling frequency.');

fs = data.fs;

% Check Nyquist constraint
nyquist = fs / 2;
assert(opts.CardiacBand(2) < nyquist, 'pf2:qc:sci:nyquist', ...
    'Upper cardiac band (%.1f Hz) must be below Nyquist (%.1f Hz).', ...
    opts.CardiacBand(2), nyquist);

%% Resolve wavelength layout
[channelMap, nChannels] = resolveWavelengthLayout(data, opts);

%% Compute SCI for each channel
sciValues = zeros(1, nChannels);

for ch = 1:nChannels
    col1 = channelMap(ch, 1);
    col2 = channelMap(ch, 2);

    if col1 == 0 || col2 == 0
        % Could not map this channel
        sciValues(ch) = 0;
        continue;
    end

    wl1 = data.raw(:, col1);
    wl2 = data.raw(:, col2);

    % Skip if either signal is constant (dead channel)
    if std(wl1) == 0 || std(wl2) == 0
        sciValues(ch) = 0;
        continue;
    end

    % Bandpass filter to cardiac band
    wl1_filt = bpf(wl1, opts.FilterOrder, fs, opts.CardiacBand(1), opts.CardiacBand(2));
    wl2_filt = bpf(wl2, opts.FilterOrder, fs, opts.CardiacBand(1), opts.CardiacBand(2));

    % Compute zero-lag normalized cross-correlation
    xc = xcorr(wl1_filt, wl2_filt, 0, 'normalized');
    sciValues(ch) = abs(xc);
end

%% Build output
result.sci = sciValues;
result.isGood = sciValues >= opts.Threshold;
result.channels = 1:nChannels;
result.threshold = opts.Threshold;
result.cardiacBand = opts.CardiacBand;
result.fs = fs;

end


%% Local functions

function [channelMap, nChannels] = resolveWavelengthLayout(data, opts)
% RESOLVEWAVELENGHTLAYOUT Determine which raw columns belong to each channel
%
% Returns channelMap [nChannels x 2] where each row gives the two column
% indices in data.raw for that channel's two wavelengths.

% Method 1: Explicit parameters
if ~isempty(opts.Wavelengths) && ~isempty(opts.ChannelNumbers)
    wl = opts.Wavelengths;
    chNums = opts.ChannelNumbers;
    assert(numel(wl) == numel(chNums), 'pf2:qc:sci:paramMismatch', ...
        'Wavelengths and ChannelNumbers must have the same length.');

    uniqueCh = unique(chNums(chNums > 0));
    nChannels = numel(uniqueCh);
    channelMap = zeros(nChannels, 2);

    for i = 1:nChannels
        cols = find(chNums == uniqueCh(i) & wl > 0 & ~isnan(wl));
        if numel(cols) >= 2
            channelMap(i, :) = cols(1:2);
        end
    end
    return;
end

% Method 2: probeinfo.Probe{1}.TableCh
if isfield(data, 'probeinfo') && isfield(data.probeinfo, 'Probe') ...
        && iscell(data.probeinfo.Probe) && ~isempty(data.probeinfo.Probe) ...
        && isfield(data.probeinfo.Probe{1}, 'TableCh')
    tableCh = data.probeinfo.Probe{1}.TableCh;
    % TableCh typically has columns: [optodeNumber, wavelengthIndex, ...]
    % Extract channel numbers and wavelength indices
    if size(tableCh, 2) >= 2
        chNums = tableCh(:, 1)';
        wlIdx = tableCh(:, 2)';

        uniqueCh = unique(chNums(chNums > 0));
        nChannels = numel(uniqueCh);
        channelMap = zeros(nChannels, 2);

        for i = 1:nChannels
            cols = find(chNums == uniqueCh(i));
            if numel(cols) >= 2
                channelMap(i, :) = cols(1:2);
            end
        end
        return;
    end
end

% Method 3: Synthetic data — alternating ch1_wl1, ch1_wl2, ch2_wl1, ch2_wl2, ...
if isfield(data, 'info') && isfield(data.info, 'synthetic') ...
        && isfield(data.info.synthetic, 'wavelengths')
    wls = data.info.synthetic.wavelengths;
    nRawCols = size(data.raw, 2);
    nWl = numel(wls);

    if nWl > 0 && mod(nRawCols, nWl) == 0
        nChannels = nRawCols / nWl;
        channelMap = zeros(nChannels, 2);
        for i = 1:nChannels
            channelMap(i, :) = [(i-1)*nWl + 1, (i-1)*nWl + 2];
        end
        return;
    end
end

% No method worked
error('pf2:qc:sci:noWavelengthLayout', ...
    ['Cannot determine wavelength layout. Pass ''Wavelengths'' and ' ...
     '''ChannelNumbers'' parameters explicitly.']);

end
