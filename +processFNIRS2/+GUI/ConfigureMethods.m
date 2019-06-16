function varargout=ConfigureMethods(varargin)

% ConfigureMethods is a wrapper function for processFNIRS2_configureMethods

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods(varargin{:});
else
   processFNIRS2_configureMethods(varargin{:}); 
end