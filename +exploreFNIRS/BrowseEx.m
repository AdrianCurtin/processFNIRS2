function varargout=BrowseEx(varargin)

% ConfigureMethods is a wrapper function for processFNIRS2_configureMethods

if(nargout>0)
    varargout{1:nargout}=exploreFNIRS_browse(varargin{:});
else
   exploreFNIRS_browse(varargin{:}); 
end