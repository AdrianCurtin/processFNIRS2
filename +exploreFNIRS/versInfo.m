function versInfoString=versInfo()

vers='0.3a';
versInfo=sprintf('Explore fNIRS v%s\n',vers);

if(nargout==0)
   fprintf(versInfo);
else
    versInfoString=versInfo;
end