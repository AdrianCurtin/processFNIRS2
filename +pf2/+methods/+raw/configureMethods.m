function varargout=configureMethods(varargin)
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
%   pf2.methods.raw.configureMethods()
%   pf2.methods.raw.configureMethods(options)
%   output = pf2.methods.raw.configureMethods(...)
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
%   pf2.methods.raw.configureMethods();
%
%   % Typical workflow: configure methods, then use them
%   pf2.methods.raw.configureMethods();  % Create/edit methods in GUI
%   pf2.methods.raw.list();              % View available methods
%   pf2.methods.raw.setMethod('myNewMethod');  % Select your method
%
% Notes:
%   - Methods are stored in: prefdir/pf2_raw_methods_stored_processFNIRS2.cfg
%   - Use ImportMethods to load methods from external .cfg files
%
% See also: pf2.methods.raw.list, pf2.methods.raw.setMethod,
%           pf2.methods.raw.importMethods, pf2.methods.oxy.configureMethods,
%           processFNIRS2_configureMethods



if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods('raw',varargin{:});
else
   processFNIRS2_configureMethods('raw',varargin{:}); 
end