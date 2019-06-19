function pathstr=pf2_defaultRootPath()

% This function returns the default root path for processFNIRS2
% 	this function should be in the \+pf2_base\ directory

filedir=mfilename('fullpath');

slashes=find(filedir=='/'|filedir=='\');
lastslash=slashes(end-1);

pathstr=filedir(1:lastslash);