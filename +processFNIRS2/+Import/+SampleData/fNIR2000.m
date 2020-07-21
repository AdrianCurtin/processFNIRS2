function fNIR=fNIR2000()

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../../sampledata/sampleNIR_ss.nir',filepath);
mrkfilepath=sprintf('%s../../../sampledata/sampleNIR_ss.mrk',filepath);

if(nargout>0)
	fNIR=processFNIRS2.Import.ImportNIR(nirfilepath,mrkfilepath,false); % just load data
else
	fNIR=processFNIRS2.Import.ImportNIR(nirfilepath,mrkfilepath,true); % show GUI
end