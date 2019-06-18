function varargout=Process(varargin)
% This function is a wrapper for processFNIRS2's main function

if(nargout>0)
    [varargout(:)]=processFNIRS2(varargin{:});

else
    processFNIRS2(varargin{:});
end