function varargout=getFNIRS(varargin)
% This function is a wrapper function for processFNIRS2.Data.Split

%warning('Please replace with processFNIRS2.Data.Split()\n');

if(nargout>0)
    varargout{1:nargout}=processFNIRS2.Data.Split(varargin{:});
else
   processFNIRS2.Data.Split(varargin{:}); 
   varargout=[];
end

