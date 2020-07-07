function fNIR=Hitachi_ETG4000_3x11()

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../../sampledata/sample_MES_Probe2.csv',filepath);

if(nargout>0)
	fNIR=processFNIRS2.Import.ImportHitachiMES(nirfilepath,[],false); % just load data
else
	fNIR=processFNIRS2.Import.ImportHitachiMES(nirfilepath,[],true); % show GUI
end