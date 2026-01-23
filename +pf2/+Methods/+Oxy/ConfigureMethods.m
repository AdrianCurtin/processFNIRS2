function varargout=ConfigureMethods(varargin)
% CONFIGUREMETHODS Open GUI to create and edit oxy processing methods
%
% Launches the method configuration GUI for creating, editing, and managing
% hemoglobin processing methods. The GUI allows you to build custom processing
% pipelines by selecting functions, setting parameters, and defining the
% order of operations for Stage 3 (post-Beer-Lambert) processing.
%
% Methods created here are saved to the user's preferences directory and
% persist across MATLAB sessions.
%
% Syntax:
%   pf2.Methods.Oxy.ConfigureMethods()
%   pf2.Methods.Oxy.ConfigureMethods(options)
%   output = pf2.Methods.Oxy.ConfigureMethods(...)
%
% Inputs:
%   options - Optional arguments passed to processFNIRS2_configureMethods
%             (see processFNIRS2_configureMethods for details)
%
% Outputs:
%   output - Optional output from the configuration GUI
%
% Example:
%   % Open the oxy method configuration GUI
%   pf2.Methods.Oxy.ConfigureMethods();
%
%   % Typical workflow: configure methods, then use them
%   pf2.Methods.Oxy.ConfigureMethods();  % Create/edit methods in GUI
%   pf2.Methods.Oxy.List();              % View available methods
%   pf2.Methods.Oxy.SetMethod('myNewMethod');  % Select your method
%
% Notes:
%   - Methods are stored in: prefdir/pf2_oxy_methods_stored_processFNIRS2.cfg
%   - Use ImportMethods to load methods from external .cfg files
%
% See also: pf2.Methods.Oxy.List, pf2.Methods.Oxy.SetMethod,
%           pf2.Methods.Oxy.ImportMethods, pf2.Methods.Raw.ConfigureMethods,
%           processFNIRS2_configureMethods

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods('oxy',varargin{:});
else
   processFNIRS2_configureMethods('oxy',varargin{:}); 
end