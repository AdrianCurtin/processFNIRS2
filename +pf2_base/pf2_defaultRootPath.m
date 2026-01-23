function pathstr=pf2_defaultRootPath()
% PF2_DEFAULTROOTPATH Returns the installation root path for processFNIRS2
%
% Returns the absolute path to the processFNIRS2 installation directory by
% locating the parent directory of the +pf2_base package. This function
% is used internally for locating configuration files, device definitions,
% and sample data.
%
% Syntax:
%   pathstr = pf2_defaultRootPath()
%
% Inputs:
%   None
%
% Outputs:
%   pathstr - Absolute path to processFNIRS2 root directory [string]
%             Ends with trailing slash/backslash.
%
% Example:
%   rootPath = pf2_defaultRootPath();
%   devicePath = fullfile(rootPath, 'devices');
%
% See also: pf2_initialize, loadDeviceCfg

filedir=mfilename('fullpath');

slashes=find(filedir=='/'|filedir=='\');
lastslash=slashes(end-1);

pathstr=filedir(1:lastslash);