function [b, a] = fir1(n, Wn, varargin)
% FIR1 Window-based linear-phase FIR filter design (toolbox-free)
%
% Designs an order-N windowed-sinc FIR filter. Clean-room reimplementation so
% the toolbox does not depend on the Signal Processing Toolbox;
% interface-compatible with the Signal Processing Toolbox FIR1 for the
% low/high/band-pass/band-stop cases used across processFNIRS2 (default
% Hamming window, magnitude normalized to unity in the passband).
%
% Reference:
%   Oppenheim, A. V. & Schafer, R. W. (2010). Discrete-Time Signal
%   Processing, 3rd ed. Prentice Hall. ISBN: 978-0131988422 (windowed-sinc
%   / Fourier-series FIR design).
%
% Syntax:
%   [b, a] = fir1(n, Wn)
%   [b, a] = fir1(n, Wn, ftype)
%   [b, a] = fir1(n, Wn, ftype, window)
%   [b, a] = fir1(n, Wn, ftype, window, scaleopt)
%
% Inputs:
%   n        - Filter order (the filter has n+1 taps). For high-pass and
%              band-stop designs an odd order is bumped up by one (a type-I
%              filter is required) with a warning, as in the standard routine.
%   Wn       - Normalized cutoff, 0 < Wn < 1 (1 = Nyquist). Scalar for
%              low/high-pass; two-element [W1 W2] for band-pass/band-stop.
%   ftype    - 'low' (default for scalar Wn), 'high', 'bandpass' (default for
%              two-element Wn), or 'stop'.
%   window   - Window of length n+1 (column or row). Defaults to
%              pf2_base.external.hamming(n+1).
%   scaleopt - 'scale' (default) normalizes the passband magnitude to 1;
%              'noscale' leaves the windowed coefficients unscaled.
%
% Outputs:
%   b - FIR coefficients [1 x (n+1) double].
%   a - Always 1 (returned so callers can use the [b, a] filtering interface).
%
% Algorithm:
%   1. Form the ideal (sinc-based) impulse response for the requested band on
%      the symmetric index grid m = (0:n) - n/2.
%   2. Multiply by the design window.
%   3. Unless 'noscale' is requested, divide by the magnitude response at the
%      passband reference frequency (DC for low/stop, Nyquist for high, band
%      center for band-pass) so that response equals one.
%
% See also: butter, filtfilt_classic, hamming, pf2_bpf_fir, pf2_lpf

narginchk(2, 5);

% ---- Parse options -----------------------------------------------------
ftype = '';
win = [];
doScale = true;
for ii = 1:numel(varargin)
    arg = varargin{ii};
    if ischar(arg) || isstring(arg)
        s = lower(char(arg));
        switch s
            case {'low', 'high', 'bandpass', 'stop', 'dc-0', 'dc-1'}
                ftype = s;
            case 'scale'
                doScale = true;
            case 'noscale'
                doScale = false;
            otherwise
                error('pf2_base:fir1:badOption', 'Unknown option "%s".', s);
        end
    elseif isnumeric(arg)
        win = arg(:);
    else
        error('pf2_base:fir1:badOption', 'Unsupported argument to fir1.');
    end
end

if ~(isscalar(n) && n == floor(n) && n >= 1)
    error('pf2_base:fir1:badOrder', 'Filter order n must be a positive integer.');
end
Wn = Wn(:).';
if ~(numel(Wn) == 1 || numel(Wn) == 2)
    error('pf2_base:fir1:badWn', 'Wn must have one or two elements.');
end
if any(Wn <= 0) || any(Wn >= 1)
    error('pf2_base:fir1:WnRange', 'Wn must lie strictly between 0 and 1 (1 = Nyquist).');
end
if numel(Wn) == 2 && Wn(1) >= Wn(2)
    error('pf2_base:fir1:WnOrder', 'For band designs Wn(1) must be less than Wn(2).');
end

% Resolve band type and translate DC-0/DC-1 aliases.
if numel(Wn) == 2
    if isempty(ftype), ftype = 'bandpass'; end
    if strcmp(ftype, 'dc-1'), ftype = 'stop'; end
    if strcmp(ftype, 'dc-0'), ftype = 'bandpass'; end
    if ~ismember(ftype, {'bandpass', 'stop'})
        error('pf2_base:fir1:badFtype', 'Two-element Wn requires ''bandpass'' or ''stop''.');
    end
else
    if isempty(ftype), ftype = 'low'; end
    if ~ismember(ftype, {'low', 'high'})
        error('pf2_base:fir1:badFtype', 'Scalar Wn requires ''low'' or ''high''.');
    end
end

% High-pass / band-stop need an even order (type-I, symmetric, tap at Nyquist).
needsEven = ismember(ftype, {'high', 'stop'});
if needsEven && mod(n, 2) == 1
    n = n + 1;
    warning('pf2_base:fir1:orderBumped', ...
        'High-pass/band-stop FIR requires an even order; using order %d.', n);
end

nfilt = n + 1;
if isempty(win)
    win = pf2_base.external.hamming(nfilt);
elseif numel(win) ~= nfilt
    error('pf2_base:fir1:badWindow', 'Window length must equal n+1 (%d).', nfilt);
end
win = win(:).';

% ---- Ideal impulse response on the symmetric grid ----------------------
m = (0:n) - n/2;

switch ftype
    case 'low'
        hd = Wn * msinc(Wn * m);
        fref = 0;
    case 'high'
        hd = -Wn * msinc(Wn * m);
        hd = addCenter(hd, m, 1);          % spectral inversion of lowpass
        fref = 1;                           % normalize at Nyquist
    case 'bandpass'
        hd = Wn(2) * msinc(Wn(2) * m) - Wn(1) * msinc(Wn(1) * m);
        fref = mean(Wn);                    % normalize at band center
    case 'stop'
        hd = Wn(1) * msinc(Wn(1) * m) - Wn(2) * msinc(Wn(2) * m);
        hd = addCenter(hd, m, 1);
        fref = 0;                           % DC passes
end

b = hd .* win;

% ---- Normalize passband magnitude --------------------------------------
if doScale
    nIdx = 0:n;
    gain = abs(sum(b .* exp(-1i * pi * fref * nIdx)));
    if gain > 0
        b = b / gain;
    end
end

a = 1;

end

%%_Subfunctions_____________________________________________________________

function y = msinc(x)
% MSINC Normalized sinc, sin(pi*x)/(pi*x), with msinc(0) = 1 (toolbox-free)
y = ones(size(x));
nz = (x ~= 0);
y(nz) = sin(pi * x(nz)) ./ (pi * x(nz));
end

function hd = addCenter(hd, m, val)
% ADDCENTER Add VAL to the center (m == 0) tap for spectral inversion
%
% Only valid for even-order designs, where m = (0:n)-n/2 contains an exact
% integer 0. High-pass/band-stop (the only callers) bump odd orders to even
% before this runs, so the center tap always exists; assert to guard against
% future misuse with an odd order (half-integer grid, no exact zero).
idx = find(m == 0, 1);
assert(~isempty(idx), 'pf2_base:fir1:noCenterTap', ...
    'Spectral inversion requires an even order (a center tap at m == 0).');
hd(idx) = hd(idx) + val;
end
