function fNIR=ImportSampleData_Hitachi()

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../sampledata/sample_MES_Probe1.csv',filepath);

if(nargout>0)
	fNIR=processFNIRS2.Import.ImportHitachiMES(nirfilepath,[],false); % just load data
else
	fNIR=processFNIRS2.Import.ImportHitachiMES(nirfilepath,[],true); % show GUI
end