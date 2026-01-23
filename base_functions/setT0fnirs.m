function varargout=setT0fnirs(varargin)
% This function is a wrapper function for pf2.Data.SetT0

%warning('Please replace with pf2.Data.SetT0()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.Data.SetT0(varargin{:});
else
   pf2.Data.SetT0(varargin{:}); 
end

