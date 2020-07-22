function varargout=setT0fnirs(varargin)
% This function is a wrapper function for processFNIRS2.Data.Split

%warning('Please replace with processFNIRS2.Data.SetT0()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.Data.SetT0(varargin{:});
else
   pf2.Data.SetT0(varargin{:}); 
end

