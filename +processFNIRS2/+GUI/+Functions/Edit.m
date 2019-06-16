function varargout=Edit(varargin)

% ConfigureFunctions is a wrapper function for processFNIRS2_configureMethods_functionAddEdit

if(nargin<1)
	error('Please provide function name to edit');
end

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods_functionAddEdit(varargin{:});
else
   processFNIRS2_configureMethods_functionAddEdit(varargin{:}); 
end