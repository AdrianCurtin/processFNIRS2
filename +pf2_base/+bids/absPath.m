function ap = absPath(p)
% ABSPATH Absolute path of an existing directory
%
% Resolves a (possibly relative) directory path to its absolute form without
% changing the working directory. The directory must exist.
%
% Inputs:
%   p - directory path (char or string)
%
% Outputs:
%   ap - absolute path char
%
% Example:
%   pf2_base.bids.absPath('bids_out')
%
% See also: pf2.export.asBIDS

p = char(p);
d = dir(p);
if isempty(d)
    % Not yet listable; fall back to fullfile against pwd for relative paths
    if ispc
        isAbsolute = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
    else
        isAbsolute = startsWith(p, '/');
    end
    if isAbsolute
        ap = p;
    else
        ap = fullfile(pwd, p);
    end
    return;
end
ap = d(1).folder;   % .folder of '.' entry is the absolute path of p
end
