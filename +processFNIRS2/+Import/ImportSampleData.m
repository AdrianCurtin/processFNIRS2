function fNIR=ImportSampleData()

[filepath]=mfilename('fullpath');

slashes=find(filepath'=='/'|filepath'=='\');
filepath=filepath(1:slashes(end)); %strip filename

nirfilepath=sprintf('%s../../sampledata/sampleNIR.nir',filepath);
mrkfilepath=sprintf('%s../../sampledata/sampleNIR.mrk',filepath);

fNIR=processFNIRS2.Import.ImportNIR(nirfilepath,mrkfilepath);