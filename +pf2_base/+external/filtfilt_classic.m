function y = filtfilt_classic(b, a, x)
% FILTFILT_CLASSIC Zero-phase forward-and-reverse digital filtering
%
% Applies the filter described by coefficient vectors B and A (or by a
% second-order-section matrix and gain) to the data in X, first forward and
% then in reverse, so the cascaded operation has exactly zero phase
% distortion. Startup and ending transients are suppressed by reflecting the
% signal about its endpoints and by initializing the filter to the
% steady-state response of the reflected edge. This is a clean-room
% reimplementation of the classic forward-backward filtering routine,
% provided so the toolbox does not depend on the Signal Processing Toolbox
% and so it tolerates the calling conventions used across processFNIRS2
% (both transfer-function and SOS inputs). Operates column-wise; a row vector
% input is treated as a single column and returned as a row vector.
%
% Reference:
%   Gustafsson, F. (1996). Determining the initial states in forward-backward
%   filtering. IEEE Transactions on Signal Processing, 44(4), 988-992.
%   DOI: 10.1109/78.492552
%
% Syntax:
%   y = filtfilt_classic(b, a, x)
%   y = filtfilt_classic(sos, g, x)
%
% Inputs:
%   b - Numerator coefficients [1 x nb double], OR a second-order-section
%       matrix [L x 6 double] with rows [b0 b1 b2 a0 a1 a2].
%   a - Denominator coefficients [1 x na double] matching b, OR (when b is an
%       SOS matrix) a scalar/vector of section gains. A scalar gain of 1
%       leaves the SOS coefficients unscaled.
%   x - Input signal [T x C double]. Filtering is applied independently to
%       each column. A [1 x T] row vector is accepted and returned as a row.
%
% Outputs:
%   y - Zero-phase filtered signal, same size and orientation as x.
%
% Algorithm:
%   1. Resolve inputs to one or more biquad/transfer-function stages and the
%      edge-transient length nfact = 3*(filter order).
%   2. For each stage compute the steady-state initial state zi by solving the
%      linear system (I - A_state) * zi = B_state - b0*A_state derived from the
%      Direct-Form-II-transposed state-space realization.
%   3. Reflect-pad each column by nfact samples at both ends
%      (xpad = [2*x(1)-x(nfact+1:-1:2); x; 2*x(end)-x(end-1:-1:end-nfact)]).
%   4. Filter forward (initial state zi*xpad(1)), reverse, filter again
%      (initial state zi*y(1)), reverse, and discard the nfact pad samples.
%
% Example:
%   [b, a] = butter(4, 0.2);
%   t = (0:199).';
%   x = sin(2*pi*0.02*t) + 0.3*randn(200,1);
%   y = pf2_base.external.filtfilt_classic(b, a, x);
%
% Notes:
%   - The input length must exceed 3*(filter order) or an error is raised, as
%     in the standard routine.
%   - SOS stages are applied sequentially; gains are folded into the numerator
%     of their section (a trailing extra gain multiplies the last section).
%
% See also: filter, butter, pf2_lpf, pf2_hpf, pf2_bpf_butter

narginchk(3, 3);

if isempty(b) || isempty(a) || isempty(x)
    y = [];
    return;
end

% Treat a row vector as a single column; restore orientation on output.
isRowVec = (size(x, 1) == 1);
if isRowVec
    x = x(:);
end
Npts = size(x, 1);

% Resolve coefficients into a set of stages, each with its own b, a, and the
% corresponding steady-state initial condition zi.
[bStages, aStages, ziStages, nfact] = resolveStages(b, a);

if Npts <= nfact
    error('pf2_base:filtfilt_classic:dataTooShort', ...
        'Input data length (%d) must be greater than 3*order (%d).', ...
        Npts, nfact);
end

y = x;
for s = 1:numel(bStages)
    y = applyStage(bStages{s}, aStages{s}, y, ziStages{s}, nfact);
end

if isRowVec
    y = y.';
end

end

%%_Subfunctions_____________________________________________________________

function [bStages, aStages, ziStages, nfact] = resolveStages(b, a)
% RESOLVESTAGES Normalize coefficient inputs into per-stage b, a, zi
%
% Inputs:
%   b - Numerator vector or [L x 6] SOS matrix
%   a - Denominator vector or scalar/vector SOS gain
%
% Outputs:
%   bStages  - Cell array of numerator column vectors, one per stage
%   aStages  - Cell array of denominator column vectors, one per stage
%   ziStages - Cell array of steady-state initial-condition vectors
%   nfact    - Edge-transient length = 3*(total filter order)

isSOS = (size(b, 2) == 6) && (size(b, 1) >= 1) && (numel(a) <= size(b, 1) + 1);
% Disambiguate a genuine 1x6 transfer function from a single-section SOS:
% a true SOS section has a0 == 1 (the 4th element) and a scalar gain.
if isSOS && size(b, 1) == 1
    isSOS = (numel(a) <= 2) && (abs(b(4) - 1) < eps(b(4)) + eps);
end

if isSOS
    L = size(b, 1);
    g = a(:);
    % Fold the section gains into the numerators. A trailing (L+1)-th gain
    % multiplies the last section's numerator.
    if numel(g) == L + 1
        b(L, 1:3) = g(L + 1) * b(L, 1:3);
        g(L + 1) = [];
    end
    for ii = 1:numel(g)
        b(ii, 1:3) = g(ii) * b(ii, 1:3);
    end

    bStages = cell(1, L);
    aStages = cell(1, L);
    ziStages = cell(1, L);
    ord = 0;
    for ii = 1:L
        bb = b(ii, 1:3).';
        aa = b(ii, 4:6).';
        [bb, aa] = trimStage(bb, aa);
        bStages{ii} = bb;
        aStages{ii} = aa;
        ziStages{ii} = steadyStateIC(bb, aa);
        ord = ord + (numel(aa) - 1);
    end
    nfact = max(1, 3 * ord);
else
    bb = b(:);
    aa = a(:);
    nfilt = max(numel(bb), numel(aa));
    if numel(bb) < nfilt
        bb(nfilt, 1) = 0;
    elseif numel(aa) < nfilt
        aa(nfilt, 1) = 0;
    end
    bStages = {bb};
    aStages = {aa};
    ziStages = {steadyStateIC(bb, aa)};
    nfact = max(1, 3 * (nfilt - 1));
end

end

function [b, a] = trimStage(b, a)
% TRIMSTAGE Drop trailing-zero coefficients common to b and a
%
% Inputs:
%   b - Numerator column vector
%   a - Denominator column vector
%
% Outputs:
%   b - Trimmed numerator (length matches a)
%   a - Trimmed denominator

n = max(numel(b), numel(a));
b(end + 1:n, 1) = 0;
a(end + 1:n, 1) = 0;
% Remove trailing rows where both b and a are zero (first-order section).
while numel(a) > 1 && a(end) == 0 && b(end) == 0
    a(end) = [];
    b(end) = [];
end

end

function zi = steadyStateIC(b, a)
% STEADYSTATEIC Steady-state initial conditions for forward-backward filtering
%
% Solves (I - A_state) * zi = B_state - b0 * A_state derived from the
% Direct-Form-II-transposed state-space realization, giving the filter state
% that produces a constant (DC) output equal to the constant input. This is
% the standard Gustafsson (1996) initialization that minimizes edge
% transients.
%
% Inputs:
%   b - Numerator column vector [nfilt x 1], normalized so a(1) ~= 0
%   a - Denominator column vector [nfilt x 1]
%
% Outputs:
%   zi - Initial state vector [(nfilt-1) x 1]

% Normalize by a(1).
if a(1) ~= 1
    b = b / a(1);
    a = a / a(1);
end

nfilt = numel(a);
if nfilt <= 1
    zi = zeros(0, 1);
    return;
end

n = nfilt - 1;
% A_state is the companion-form transition matrix for the DF-II-transposed
% realization: first column is -a(2:nfilt), and a superdiagonal identity.
Astate = [-a(2:nfilt), [eye(n - 1); zeros(1, n - 1)]];
rhs = b(2:nfilt) - b(1) * a(2:nfilt);
zi = (eye(n) - Astate) \ rhs;

end

function y = applyStage(b, a, x, zi, nfact)
% APPLYSTAGE Reflect-pad and zero-phase filter every column of x for one stage
%
% Inputs:
%   b     - Numerator column vector
%   a     - Denominator column vector
%   x     - Signal matrix [T x C]
%   zi    - Steady-state initial condition for this stage
%   nfact - Edge-transient (reflection) length
%
% Outputs:
%   y - Filtered signal matrix [T x C], same size as x

C = size(x, 2);
y = zeros(size(x), 'like', x);
for col = 1:C
    xc = x(:, col);
    % Reflect padding about the endpoints.
    pre = 2 * xc(1) - xc(nfact + 1:-1:2);
    post = 2 * xc(end) - xc(end - 1:-1:end - nfact);
    xp = [pre; xc; post];

    % Forward pass.
    yp = filter(b, a, xp, zi * xp(1));
    % Reverse, second pass.
    yp = yp(end:-1:1);
    yp = filter(b, a, yp, zi * yp(1));
    % Reverse back and strip the pad.
    yp = yp(end:-1:1);
    y(:, col) = yp(nfact + 1:end - nfact);
end

end
