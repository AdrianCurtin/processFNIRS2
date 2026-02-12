function pf2_initialize()
% PF2_INITIALIZE Initialize processFNIRS2 global state and defaults
%
% Sets up the global PF2 structure with default processing parameters,
% loads saved method configurations from disk, and initializes the toolbox
% for use. This function is called automatically by processFNIRS2() on
% first use, but can be called explicitly to reset or reinitialize.
%
% Syntax:
%   pf2_initialize()
%
% Inputs:
%   None
%
% Outputs:
%   None (modifies global PF2 structure)
%
% Global Variables Modified:
%   PF2 - Main processing configuration structure with fields:
%
%   Path Configuration:
%     .defaultRootPath     - processFNIRS2 installation directory
%     .defaultOxyMethodsPath - Path to saved Oxy method configs
%     .defaultRawMethodsPath - Path to saved Raw method configs
%
%   Method Configuration:
%     .myRawMethods        - Loaded raw processing method definitions
%     .myOxyMethods        - Loaded oxy processing method definitions
%     .stageRawMethod      - Currently selected raw method (set later)
%     .stageOxyMethod      - Currently selected oxy method (set later)
%
%   DPF (Differential Pathlength Factor) Settings:
%     .curDPF_fixed        - Fixed DPF value (default: 5.93, van der Zee 1992)
%     .dpf_mode            - DPF calculation mode: 'None', 'Fixed', or 'Calc'
%                            Default: 'Calc' (age-dependent)
%     .curDPF_age          - Subject age for DPF calculation (default: 25)
%
%   Baseline Settings:
%     .baseline.startTime       - Baseline start time in seconds (default: 0)
%     .baseline.blLength        - Baseline duration in seconds (default: 10)
%     .baseline.useAbsoluteTime - Use absolute vs relative time (default: false)
%     .baseline.windowStartTime - GUI window start time (default: 0)
%
%   Quality Control:
%     .RejectLevel         - Channel rejection threshold (default: 0)
%
% Method Configuration Files:
%   Raw methods: <prefdir>/pf2_raw_methods_stored_processFNIRS2.cfg
%   Oxy methods: <prefdir>/pf2_oxy_methods_stored_processFNIRS2.cfg
%
% Notes:
%   - Only initializes if PF2.myRawMethods or PF2.baseline is missing
%   - Adds 'base_functions', 'functions', and 'GUI' to MATLAB path
%   - Prints loaded method names to console during initialization
%   - Uses MATLAB prefdir() for user-specific method storage
%
% Example:
%   % Force reinitialization
%   clear global PF2
%   pf2_initialize();
%
%   % Check initialization state
%   global PF2
%   if isfield(PF2, 'myRawMethods')
%       disp('Already initialized');
%   end
%
% See also: processFNIRS2, pf2.methods.raw.setMethod, pf2.settings.SetDPFmode

global PF2

%
%Load default parameters here
hObject=1;
handles=1;


if(~isfield(PF2,'defaultRootPath'))
    [pF2_folder,~,~] = fileparts(mfilename('fullpath'));
    PF2.defaultRootPath=pf2_base.pf2_defaultRootPath();
    curdir=cd;
    cd(PF2.defaultRootPath);
    addpath(PF2.defaultRootPath,'base_functions','functions','GUI');
    cd(curdir);
end

PF2.defaultOxyMethodsPath=sprintf('%s/pf2_oxy_methods_stored_processFNIRS2.cfg',prefdir);
PF2.defaultRawMethodsPath=sprintf('%s/pf2_raw_methods_stored_processFNIRS2.cfg',prefdir);

if(~isfield(PF2,'myRawMethods')||~isfield(PF2,'baseline'))

   disp('Initializing processfNIRS2');
   PF2.myRawMethods=processFNIRS2_configureMethods('loadMethodsCallback',hObject,handles,[],PF2.defaultRawMethodsPath,true);
   for i=1:length(PF2.myRawMethods.cfg.Sections)
      fprintf('Loaded Raw method: %s\n',PF2.myRawMethods.cfg.Sections{i}); 
   end
   
   PF2.myOxyMethods=processFNIRS2_configureMethods('loadMethodsCallback',hObject,handles,[],PF2.defaultOxyMethodsPath,true);
   for i=1:length(PF2.myOxyMethods.cfg.Sections)
      fprintf('Loaded Oxy method: %s\n',PF2.myOxyMethods.cfg.Sections{i}); 
   end
   
   PF2.curDPF_fixed=5.93;   %Default differential pathlength for adult human head (van der Zee 1992)
   PF2.dpf_mode='Calc';   %Default age to calculate differential pathlength factor from.
   PF2.curDPF_age=25;   %Default age to calculate differential pathlength factor from.
   fprintf('Initializing default age for DPF calculation to %.0f\n',PF2.curDPF_age);
   PF2.baseline=[];
   PF2.baseline.startTime=0; %or minimum time
   PF2.RejectLevel=0; % Reject channels when mask ==0
   
   PF2.baseline.useAbsoluteTime=false; %enable to force baseline from absolute time instead of relative time (non-GUI only)
   PF2.baseline.windowStartTime=0; % time from start of viewing window (GUI only)
   PF2.baseline.blLength=10; % time in seconds from start time
   fprintf('Defaulting to %.1f second baseline from t=%.1f\n',PF2.baseline.blLength,PF2.baseline.startTime);
   %processFNIRS2_configureMethods() 
end


