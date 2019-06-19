function pf2_initialize()
% this will initalize pf2


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
    addpath('base_functions','functions','GUI');
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
   
   PF2.baseline.useAbsoluteTime=false; %enable to force baseline from absolute time instead of relative time (non-GUI only)
   PF2.baseline.windowStartTime=0; % time from start of viewing window (GUI only)
   PF2.baseline.blLength=10; % time in seconds from start time
   fprintf('Defaulting to %.1f second baseline from t=%.1f\n',PF2.baseline.blLength,PF2.baseline.startTime);
   %processFNIRS2_configureMethods() 
end


