function outStr=Methods()


methodListStr=sprintf('Currently Loaded Methods:');

methodListStr=sprintf('%s\n%s',methodListStr,processFNIRS2.Methods.Raw);

methodListStr=sprintf('%s\n%s',methodListStr,processFNIRS2.Methods.Oxy);

if(nargout==0)
   fprintf(methodListStr); 
   return;
else
   outStr=methodListStr; 
end