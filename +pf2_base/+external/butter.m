function varargout = butter(n, Wn, varargin)
% BUTTER Butterworth digital IIR filter design (toolbox-free)
%
% Designs an order-N digital Butterworth filter with normalized cutoff Wn.
% Clean-room reimplementation of the classic analog-prototype + bilinear
% transform recipe, provided so the toolbox does not depend on the Signal
% Processing Toolbox. Interface-compatible with the Signal Processing Toolbox
% BUTTER for the digital low/high/band-pass/band-stop cases used across
% processFNIRS2.
%
% Reference:
%   Oppenheim, A. V. & Schafer, R. W. (2010). Discrete-Time Signal
%   Processing, 3rd ed. Prentice Hall. ISBN: 978-0131988422
%   (Butterworth analog prototype, lowpass-to-X spectral transforms, and the
%   bilinear transform; standard textbook digital-filter design.)
%
% Syntax:
%   [b, a]    = butter(n, Wn)
%   [b, a]    = butter(n, Wn, ftype)
%   [z, p, k] = butter(n, Wn, ...)
%
% Inputs:
%   n     - Filter order (positive integer). For band-pass/band-stop the
%           resulting filter has order 2*n, as in the standard routine.
%   Wn    - Normalized cutoff frequency, 0 < Wn < 1, where 1 corresponds to
%           the Nyquist frequency (fs/2). A scalar selects low/high-pass; a
%           two-element [W1 W2] selects band-pass/band-stop.
%   ftype - Filter type string: 'low' (default for scalar Wn), 'high',
%           'bandpass' (default for two-element Wn), or 'stop'.
%
% Outputs:
%   [b, a]    - Transfer-function coefficients (descending powers of z),
%               real row vectors.
%   [z, p, k] - Zeros (column), poles (column), and scalar gain of the
%               digital filter (preferred for cascading into SOS form).
%
% Algorithm:
%   1. Build the order-N analog Butterworth lowpass prototype (poles on the
%      unit circle in the left half-plane, no finite zeros, unit DC gain).
%   2. Pre-warp the digital cutoff(s) to analog frequency with
%      Wa = 2*tan(pi*Wn/2) (consistent with a bilinear constant of 2).
%   3. Apply the lowpass-to-{lowpass,highpass,bandpass,bandstop} spectral
%      transform to the prototype.
%   4. Map the analog (z, p, k) to the digital domain with the bilinear
%      transform s -> 2*(z-1)/(z+1), padding zeros at z = -1, then form b, a.
%
% Notes:
%   - Digital design only; an analog ('s') request is not supported and
%     raises an error.
%   - For numerically sensitive (low Wn, higher order) designs prefer the
%     three-output [z, p, k] form and convert with pf2_base.external.zp2sos.
%
% See also: zp2sos, fir1, filtfilt_classic, pf2_lpf, pf2_hpf, pf2_bpf_butter

narginchk(2, 4);

% ---- Parse options (ftype string; reject analog 's') -------------------
ftype = '';
for ii = 1:numel(varargin)
    arg = varargin{ii};
    if ~(ischar(arg) || isstring(arg))
        error('pf2_base:butter:badOption', 'Optional arguments must be strings.');
    end
    arg = char(arg);
    if strcmpi(arg, 's')
        error('pf2_base:butter:analogUnsupported', ...
            'Analog ("s") design is not supported; this is a digital-only reimplementation.');
    end
    ftype = lower(arg);
end

if ~(isscalar(n) && n == floor(n) && n >= 1)
    error('pf2_base:butter:badOrder', 'Filter order n must be a positive integer.');
end
Wn = Wn(:).';
if ~(numel(Wn) == 1 || numel(Wn) == 2)
    error('pf2_base:butter:badWn', 'Wn must have one or two elements.');
end
if any(Wn <= 0) || any(Wn >= 1)
    error('pf2_base:butter:WnRange', 'Wn must lie strictly between 0 and 1 (1 = Nyquist).');
end
if numel(Wn) == 2 && Wn(1) >= Wn(2)
    error('pf2_base:butter:WnOrder', 'For band designs Wn(1) must be less than Wn(2).');
end

% Resolve filter band.
if numel(Wn) == 2
    if isempty(ftype), ftype = 'bandpass'; end
    if ~ismember(ftype, {'bandpass', 'stop'})
        error('pf2_base:butter:badFtype', 'Two-element Wn requires ''bandpass'' or ''stop''.');
    end
else
    if isempty(ftype), ftype = 'low'; end
    if ~ismember(ftype, {'low', 'high'})
        error('pf2_base:butter:badFtype', 'Scalar Wn requires ''low'' or ''high''.');
    end
end

% ---- Step 1: analog Butterworth lowpass prototype (cutoff 1 rad/s) -----
k = (1:n).';
Sp = exp(1i * (pi * (2*k - 1) / (2*n) + pi/2));   % LHP poles on unit circle
Sz = zeros(0, 1);
Sg = 1;                                            % unit DC gain prototype

% ---- Step 2: pre-warp digital cutoff(s) to analog ----------------------
Wa = 2 * tan(pi * Wn / 2);

% ---- Step 3: lowpass-prototype -> target spectral transform ------------
[Sz, Sp, Sg] = sftrans(Sz, Sp, Sg, Wa, ftype);

% ---- Step 4: bilinear transform (analog -> digital), constant c = 2 ----
c = 2;
p = (c + Sp) ./ (c - Sp);
if isempty(Sz)
    z = zeros(0, 1);
else
    z = (c + Sz) ./ (c - Sz);
end
% Each pole in excess of the finite zeros maps a zero to z = -1.
nExtra = numel(p) - numel(z);
if nExtra > 0
    z = [z; -ones(nExtra, 1)];
end
% Safe to take real(): Butterworth poles/zeros come in conjugate pairs, so the
% product ratio is real up to floating-point noise.
kk = Sg * real(prod(c - Sz) / prod(c - Sp));

% Force conjugate symmetry so downstream poly()/SOS see exactly real data.
z = cplxpair_safe(z);
p = cplxpair_safe(p);

% ---- Outputs -----------------------------------------------------------
if nargout <= 2
    b = kk * real(poly(z(:).'));
    a = real(poly(p(:).'));
    varargout{1} = b;
    varargout{2} = a;
elseif nargout == 3
    varargout{1} = z;
    varargout{2} = p;
    varargout{3} = kk;
else
    error('pf2_base:butter:tooManyOutputs', ...
        'Only [b,a] (2 outputs) and [z,p,k] (3 outputs) are supported.');
end

end

%%_Subfunctions_____________________________________________________________

function [Sz, Sp, Sg] = sftrans(Sz, Sp, Sg, W, ftype)
% SFTRANS Transform an analog lowpass prototype to low/high/band-pass/stop
%
% Inputs:
%   Sz, Sp, Sg - Prototype zeros (column), poles (column), gain (scalar).
%   W          - Pre-warped analog cutoff: scalar (low/high) or [W1 W2].
%   ftype      - 'low' | 'high' | 'bandpass' | 'stop'.
%
% Outputs:
%   Sz, Sp, Sg - Transformed analog zeros, poles, and gain.

nz = numel(Sz);
np = numel(Sp);

switch ftype
    case 'low'
        Sz = W * Sz;
        Sp = W * Sp;
        Sg = Sg * W^(np - nz);

    case 'high'
        % s -> W/s : invert poles/zeros, add zeros at the origin.
        Sg = Sg * real(prod(-Sz) / prod(-Sp));
        if nz > 0
            Sz = W ./ Sz;
        end
        Sp = W ./ Sp;
        Sz = [Sz; zeros(np - nz, 1)];

    case 'bandpass'
        Fc = sqrt(W(1) * W(2));
        bw = W(2) - W(1);
        Sg = Sg * bw^(np - nz);
        bp = Sp * (bw / 2);
        Sp = [bp + sqrt(bp.^2 - Fc^2); bp - sqrt(bp.^2 - Fc^2)];
        if nz > 0
            bz = Sz * (bw / 2);
            Sz = [bz + sqrt(bz.^2 - Fc^2); bz - sqrt(bz.^2 - Fc^2)];
        end
        Sz = [Sz; zeros(np - nz, 1)];   % add (np-nz) zeros at the origin

    case 'stop'
        Fc = sqrt(W(1) * W(2));
        bw = W(2) - W(1);
        Sg = Sg * real(prod(-Sz) / prod(-Sp));
        bp = (bw / 2) ./ Sp;
        Sp = [bp + sqrt(bp.^2 - Fc^2); bp - sqrt(bp.^2 - Fc^2)];
        if nz > 0
            bz = (bw / 2) ./ Sz;
            Sz = [bz + sqrt(bz.^2 - Fc^2); bz - sqrt(bz.^2 - Fc^2)];
        end
        % Add (np-nz) conjugate zero pairs at +/- 1i*Fc.
        Sz = [Sz; 1i * Fc * ones(np - nz, 1); -1i * Fc * ones(np - nz, 1)];

    otherwise
        error('pf2_base:butter:badFtype', 'Unknown filter type "%s".', ftype);
end

end

function r = cplxpair_safe(r)
% CPLXPAIR_SAFE Order roots into conjugate pairs, tolerant of empty input.
%
% Inputs:
%   r - Root vector (possibly complex), or empty.
%
% Outputs:
%   r - Conjugate-paired column vector (real parts grouped), or empty.

if isempty(r)
    r = zeros(0, 1);
    return;
end
r = r(:);
% Tolerance scaled to the data magnitude (cplxpair default is 100*eps).
tol = 100 * eps(max(1, max(abs(r))));
try
    r = cplxpair(r, tol);
catch
    % Fall back to as-is ordering if pairing fails (real() of poly handles it).
end

end
