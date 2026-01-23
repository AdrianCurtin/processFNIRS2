function ImportMethods(raw_methods_path_string)
% IMPORTMETHODS Import raw processing methods from an external .cfg file
%
% Loads raw processing method configurations from an external configuration
% file and adds them to the user's available methods. This enables sharing
% method configurations between users or projects, and loading pre-defined
% method sets.
%
% Syntax:
%   pf2.Methods.Raw.ImportMethods(raw_methods_path_string)
%
% Inputs:
%   raw_methods_path_string - Full path to the .cfg file containing raw
%                             method definitions. File should be in the
%                             processFNIRS2 method configuration format.
%
% Example:
%   % Import methods from a shared configuration file
%   pf2.Methods.Raw.ImportMethods('/path/to/shared_raw_methods.cfg');
%
%   % Import methods and verify they loaded
%   pf2.Methods.Raw.ImportMethods('project_methods.cfg');
%   pf2.Methods.Raw.List();  % Should show imported methods
%
%   % Typical workflow for sharing methods
%   % User A: Export methods by copying their pf2_raw_methods_stored_processFNIRS2.cfg
%   % User B: Import the shared methods
%   pf2.Methods.Raw.ImportMethods('shared_methods.cfg');
%   pf2.Methods.Raw.SetMethod('imported_method_name');
%
% Notes:
%   - Imported methods are merged with existing user methods
%   - If a method name conflicts, the imported version may overwrite
%   - Methods persist after import in user's preference directory
%
% See also: pf2.Methods.Raw.ConfigureMethods, pf2.Methods.Raw.List,
%           pf2.Methods.Oxy.ImportMethods, processFNIRS2_configureMethods

processFNIRS2_configureMethods('importMethodsCallback',1,[],1,raw_methods_path_string,true);