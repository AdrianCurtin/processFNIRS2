function outStr=Oxy()

global PF2

methodListStr='';

%rawMethods=PF2.myRawMethods.cfg.Sections;
oxyMethods=PF2.myOxyMethods.cfg.Sections;

methodListStr=sprintf('%sCurrently Loaded Oxy Methods:\n\n',methodListStr);
%methodListStr=sprintf('%sRaw Processing Methods (Light->OD):\n',methodListStr);

%for i=1:length(rawMethods)
%	methodListStr=sprintf('%s%i. %s\n',methodListStr,i,rawMethods{i});
%end

%methodListStr=sprintf('%s\n',methodListStr);

methodListStr=sprintf('%sOxy Processing Methods (Hb->Hb-Processed):\n',methodListStr);

for i=1:length(oxyMethods)
	methodListStr=sprintf('%s%i. %s\n',methodListStr,i,oxyMethods{i});
end

if(nargout==0)
	fprintf('%s',methodListStr);
	return;
else
	outStr=methodListStr;
end