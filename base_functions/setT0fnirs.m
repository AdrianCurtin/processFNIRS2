function varargout=setT0fnirs(varargin)
% This function is a wrapper function for pf2.data.setT0

%warning('Please replace with pf2.data.setT0()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.data.setT0(varargin{:});
else
   pf2.data.setT0(varargin{:}); 
end

