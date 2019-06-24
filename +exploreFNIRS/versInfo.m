function versInfoString=versInfo()

vers='0.2a';
versInfo=sprintf('Explore fNIRS v%s',vers);

if(nargout==0)
   fprintf(versInfo);
else
    versInfoString=versInfo;
end