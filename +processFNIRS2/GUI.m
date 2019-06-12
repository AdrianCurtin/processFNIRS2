function vargout=GUI(varargin)

% GUI is a wrapper function for processFNIRS2_GUI

if(nargout>0)
    varagout{1:nargout}=processFNIRS2_GUI(varargin{:});
else
   processFNIRS2_GUI(varargin{:}); 
end