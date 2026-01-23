function varargout=importNIR(varargin)
% This function is a wrapper function for pf2.import.importNIR

%warning('Please replace with pf2.import.importNIR()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.import.importNIR(varargin{:});
else
   pf2.import.importNIR(varargin{:}); 
end

