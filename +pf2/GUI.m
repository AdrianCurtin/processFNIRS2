function vargout=gui(varargin)
% GUI Launch the processFNIRS2 graphical user interface
%
% Namespaced wrapper that opens the main processFNIRS2 GUI, exposed inside
% the pf2 package so the interface can be launched as pf2.GUI(...). All
% arguments and outputs are forwarded unchanged to processFNIRS2_GUI.
%
% Syntax:
%   pf2.GUI()
%   pf2.GUI(data)
%   app = pf2.GUI(...)
%
% Inputs:
%   varargin - Any arguments accepted by processFNIRS2_GUI, typically an
%              fNIRS data struct to open in the interface.
%
% Outputs:
%   vargout - Whatever processFNIRS2_GUI returns (e.g. the app handle) when
%             an output is requested.
%
% Example:
%   % Open the GUI on sample data
%   data = pf2.import.sampleData.fNIR2000();
%   pf2.GUI(data);
%
% See also: processFNIRS2, pf2.process, pf2.help

if(nargout>0)
    varagout{1:nargout}=processFNIRS2_GUI(varargin{:});
else
   processFNIRS2_GUI(varargin{:}); 
end