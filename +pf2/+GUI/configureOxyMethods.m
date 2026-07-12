function varargout=configureOxyMethods(varargin)
% CONFIGUREOXYMETHODS Open the GUI to configure oxy (Stage 3) methods
%
% Wrapper that launches the processFNIRS2 method-configuration GUI scoped to
% the oxy (hemoglobin, Stage 3) processing stage. All arguments and outputs
% are forwarded to processFNIRS2_configureMethods with the 'oxy' stage
% pre-selected.
%
% Syntax:
%   pf2.GUI.configureOxyMethods()
%   out = pf2.GUI.configureOxyMethods(...)
%
% Inputs:
%   varargin - Any arguments accepted by processFNIRS2_configureMethods
%              (after the implicit 'oxy' stage argument).
%
% Outputs:
%   varargout - Whatever processFNIRS2_configureMethods returns when an
%               output is requested (e.g. the app handle).
%
% Example:
%   % Open the oxy method configuration GUI
%   pf2.GUI.configureOxyMethods();
%
% See also: pf2.GUI.configureRawMethods, pf2.methods.oxy.configureMethods,
%           processFNIRS2_configureMethods

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods('oxy',varargin{:});
else
   processFNIRS2_configureMethods('oxy',varargin{:}); 
end