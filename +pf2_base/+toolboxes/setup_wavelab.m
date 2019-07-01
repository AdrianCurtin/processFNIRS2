function setup_wavelab()

root=pf2_base.pf2_defaultRootPath();

curdir=cd;
waveFolder=sprintf('%sOtherToolboxes/%s',root,'Wavelab850');
cd(waveFolder);
startup
cd(curdir);

