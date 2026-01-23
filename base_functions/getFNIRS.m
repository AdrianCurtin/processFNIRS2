function varargout=getFNIRS(varargin)
% This function is a wrapper function for pf2.data.split

%warning('Please replace with pf2.data.split()\n');

if(nargout>0)
    varargout{1:nargout}=pf2.data.split(varargin{:});
else
   pf2.data.split(varargin{:}); 

end

