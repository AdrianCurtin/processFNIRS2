function varargout=importNIR(varargin)
% This function is a wrapper function for processFNIRS2.Import.ImportNIR

warning('Please replace with processFNIRS2.Import.ImportNIR()\n');

if(nargout>0)
    varargout{1:nargout}=processFNIRS2.Import.ImportNIR(varargin{:});
else
   varargout{1:nargout}=processFNIRS2.Import.ImportNIR(varargin{:}); 
end

