function varargout=ConfigureMethods(varargin)
% CONFIGUREMETHODS Open GUI to create and edit raw processing methods
%
% Launches the method configuration GUI for creating, editing, and managing
% raw processing methods. The GUI allows you to build custom processing
% pipelines by selecting functions, setting parameters, and defining the
% order of operations for Stage 1 (Raw-to-Optical Density) processing.
%
% Methods created here are saved to the user's preferences directory and
% persist across MATLAB sessions.
%
% Syntax:
%   pf2.Methods.Raw.ConfigureMethods()
%   pf2.Methods.Raw.ConfigureMethods(options)
%   output = pf2.Methods.Raw.ConfigureMethods(...)
%
% Inputs:
%   options - Optional arguments passed to processFNIRS2_configureMethods
%             (see processFNIRS2_configureMethods for details)
%
% Outputs:
%   output - Optional output from the configuration GUI
%
% Example:
%   % Open the raw method configuration GUI
%   pf2.Methods.Raw.ConfigureMethods();
%
%   % Typical workflow: configure methods, then use them
%   pf2.Methods.Raw.ConfigureMethods();  % Create/edit methods in GUI
%   pf2.Methods.Raw.List();              % View available methods
%   pf2.Methods.Raw.SetMethod('myNewMethod');  % Select your method
%
% Notes:
%   - Methods are stored in: prefdir/pf2_raw_methods_stored_processFNIRS2.cfg
%   - Use ImportMethods to load methods from external .cfg files
%
% See also: pf2.Methods.Raw.List, pf2.Methods.Raw.SetMethod,
%           pf2.Methods.Raw.ImportMethods, pf2.Methods.Oxy.ConfigureMethods,
%           processFNIRS2_configureMethods



if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods('raw',varargin{:});
else
   processFNIRS2_configureMethods('raw',varargin{:}); 
end