function varargout=configureRawMethods(varargin)
% CONFIGURERAWMETHODS Open the GUI to configure raw (Stage 1) methods
%
% Wrapper that launches the processFNIRS2 method-configuration GUI scoped to
% the raw (light-to-optical-density, Stage 1) processing stage. All arguments
% and outputs are forwarded to processFNIRS2_configureMethods with the 'raw'
% stage pre-selected.
%
% Syntax:
%   pf2.GUI.configureRawMethods()
%   out = pf2.GUI.configureRawMethods(...)
%
% Inputs:
%   varargin - Any arguments accepted by processFNIRS2_configureMethods
%              (after the implicit 'raw' stage argument).
%
% Outputs:
%   varargout - Whatever processFNIRS2_configureMethods returns when an
%               output is requested (e.g. the app handle).
%
% Example:
%   % Open the raw method configuration GUI
%   pf2.GUI.configureRawMethods();
%
% See also: pf2.GUI.configureOxyMethods, pf2.methods.raw.configureMethods,
%           processFNIRS2_configureMethods

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods('raw',varargin{:});
else
   processFNIRS2_configureMethods('raw',varargin{:}); 
end