function ProcessRawOnly(varargin)
% This function is a wrapper for processFNIRS2's main function with the 'Skip Oxy' argument


[varargout(:)]=processFNIRS2(varargin{:},'SkipOxy',true);