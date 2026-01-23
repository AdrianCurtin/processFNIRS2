function fNIR=Hitachi_ETG4000_3x5()

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../../sampledata/sample_MES_Probe1.csv',filepath);

if(nargout>0)
	fNIR=pf2.import.importHitachiMES(nirfilepath,[],false); % just load data
else
	fNIR=pf2.import.importHitachiMES(nirfilepath,[],true); % show GUI
end