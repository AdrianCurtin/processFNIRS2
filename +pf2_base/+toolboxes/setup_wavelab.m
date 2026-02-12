function setup_wavelab()
%SETUP_WAVELAB Initialize WaveLab 850 toolbox with auto-compilation
%
%   Adds WaveLab directories to the MATLAB path and compiles MEX files
%   if they are missing for the current architecture.

root = pf2_base.pf2_defaultRootPath();
waveFolder = fullfile(root, 'otherToolboxes', 'Wavelab850');

if ~isfolder(waveFolder)
    error('pf2:wavelab', 'WaveLab folder not found: %s', waveFolder);
end

origDir = pwd;
try
    cd(waveFolder);
    startup;   % Calls WavePath (sets paths + WAVELABPATH) then InstallMEX
    cd(origDir);
catch ME
    cd(origDir);
    warning('pf2:wavelab', 'WaveLab setup failed: %s', ME.message);
end
