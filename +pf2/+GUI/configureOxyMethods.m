function varargout=configureOxyMethods(varargin)

% ConfigureMethods is a wrapper function for processFNIRS2_configureMethods

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods('oxy',varargin{:});
else
   processFNIRS2_configureMethods('oxy',varargin{:}); 
end