function varargout=ConfigureFunctions(varargin)

% ConfigureFunctions is a wrapper function for processFNIRS2_configureMethods_functionAddEdit

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods_functionAddEdit();
else
   processFNIRS2_configureMethods_functionAddEdit(); 
   varargout=[];
end