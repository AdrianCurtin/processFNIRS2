function [outStr,pf2ver,dateStr]=pf2version()

pf2ver='v0.8';
dateStr='February 28 2025';


verString=sprintf('processFNIRS2 Release %s\n',pf2ver);
verString=sprintf('%sBuild Date: %s\n',verString,dateStr);

if(nargout==0)
	fprintf(verString);
	return;
else
	outStr=verString;
	return;
end
