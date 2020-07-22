function fNIR=SampleData()

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../sampledata/sampleNIR.nir',filepath);
mrkfilepath=sprintf('%s../../sampledata/sampleNIR.mrk',filepath);

if(nargout>0)
	fNIR=pf2.Import.ImportNIR(nirfilepath,mrkfilepath,false); % just load data
else
	fNIR=pf2.Import.ImportNIR(nirfilepath,mrkfilepath,true); % show GUI
end