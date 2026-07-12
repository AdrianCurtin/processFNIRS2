function [y, idx] = nanmin(varargin)
%NANMIN Minimum, ignoring NaNs (Statistics Toolbox fallback).
%
%   Drop-in for the Statistics and Machine Learning Toolbox NANMIN. Base
%   MATLAB's MIN already ignores NaNs by default, so every NANMIN form
%   (nanmin(X), nanmin(X,Y), nanmin(X,[],DIM)) forwards directly to MIN.
%   Resides in compat_shims, added to the END of the path by
%   pf2_initialize so the toolbox version wins when installed and this is
%   used only when the toolbox is absent.
%
%   Inputs:
%     varargin - Same arguments accepted by MIN.
%
%   Outputs:
%     y   - Minima ignoring NaNs.
%     idx - Indices of the minima (when requested).
%
%   See also: MIN, nanmax

if nargout > 1
    [y, idx] = min(varargin{:});
else
    y = min(varargin{:});
end
end
