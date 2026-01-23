function varargout=getFNIRS(varargin)
% This function is a wrapper function for pf2.Data.Split

%warning('Please replace with pf2.Data.Split()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.Data.Split(varargin{:});
else
   pf2.Data.Split(varargin{:}); 

end

