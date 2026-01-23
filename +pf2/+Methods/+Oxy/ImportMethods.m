function ImportMethods(Oxy_methods_path_string)
% IMPORTMETHODS Import oxy processing methods from an external .cfg file
%
% Loads hemoglobin processing method configurations from an external
% configuration file and adds them to the user's available methods. This
% enables sharing method configurations between users or projects, and
% loading pre-defined method sets.
%
% Syntax:
%   pf2.Methods.Oxy.ImportMethods(Oxy_methods_path_string)
%
% Inputs:
%   Oxy_methods_path_string - Full path to the .cfg file containing oxy
%                             method definitions. File should be in the
%                             processFNIRS2 method configuration format.
%
% Example:
%   % Import methods from a shared configuration file
%   pf2.Methods.Oxy.ImportMethods('/path/to/shared_oxy_methods.cfg');
%
%   % Import methods and verify they loaded
%   pf2.Methods.Oxy.ImportMethods('project_methods.cfg');
%   pf2.Methods.Oxy.List();  % Should show imported methods
%
%   % Typical workflow for sharing methods
%   % User A: Export methods by copying their pf2_oxy_methods_stored_processFNIRS2.cfg
%   % User B: Import the shared methods
%   pf2.Methods.Oxy.ImportMethods('shared_methods.cfg');
%   pf2.Methods.Oxy.SetMethod('imported_method_name');
%
% Notes:
%   - Imported methods are merged with existing user methods
%   - If a method name conflicts, the imported version may overwrite
%   - Methods persist after import in user's preference directory
%
% See also: pf2.Methods.Oxy.ConfigureMethods, pf2.Methods.Oxy.List,
%           pf2.Methods.Raw.ImportMethods, processFNIRS2_configureMethods

processFNIRS2_configureMethods('importMethodsCallback',1,[],1,Oxy_methods_path_string,false);