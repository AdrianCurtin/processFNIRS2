function [y, idx] = nanmax(varargin)
%NANMAX Maximum, ignoring NaNs (Statistics Toolbox fallback).
%
%   Drop-in for the Statistics and Machine Learning Toolbox NANMAX. Base
%   MATLAB's MAX already ignores NaNs by default, so every NANMAX form
%   (nanmax(X), nanmax(X,Y), nanmax(X,[],DIM)) forwards directly to MAX.
%   Resides in compat_shims, added to the END of the path by
%   pf2_initialize so the toolbox version wins when installed and this is
%   used only when the toolbox is absent.
%
%   Inputs:
%     varargin - Same arguments accepted by MAX.
%
%   Outputs:
%     y   - Maxima ignoring NaNs.
%     idx - Indices of the maxima (when requested).
%
%   See also: MAX, nanmin

if nargout > 1
    [y, idx] = max(varargin{:});
else
    y = max(varargin{:});
end
end
