function varargout=importNIR(varargin)
% This function is a wrapper function for pf2.Import.ImportNIR

%warning('Please replace with pf2.Import.ImportNIR()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.Import.ImportNIR(varargin{:});
else
   pf2.Import.ImportNIR(varargin{:}); 
end

