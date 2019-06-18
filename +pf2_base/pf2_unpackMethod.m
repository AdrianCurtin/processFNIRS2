function x=pf2_unpackMethod(method)
	% pf2_unpackMethod
	%	Unpacks methods stored in configureation files into argument values, outputs and other functions
	
	%Converts mymethods function from .S to fields in F
    x=method;
    
    if(iscell(x)&&isfield(x{1},'F'))
       x=x{1}; 
    end
    
    if(isfield(x,'F'))
        %return;
    else
        if(iscell(x)&&~isstruct(x))
            t=x;
            x=cell(0);
            x.F=t;
            for i=length(x.F):-1:1
               if(~isfield(x.F{i},'f'))
                  x.F(i)=[]; 
               end
            end
            x.name=('Unknown Method');
        else
            x.F=cell(0);
            x_fields=fields(x);

            numMethods=1;
            for j=1:length(x_fields)
               if(strcmp(sprintf('S%i',j),x_fields))
                   x.F{numMethods}=x.(sprintf('S%i',j));
                   x=rmfield(x,sprintf('S%i',j));
                   numMethods=numMethods+1;
               end
            end
        end
    end
    
    for idx=1:length(x.F)
        Fidx=x.F{idx};
        if(length(Fidx)>1) %This is a struct array for some reason?
           %Change it back!
           F_noarray.f=Fidx(1).f;
           F_noarray.args=cell(0,0);
           F_noarray.argvals=cell(0,0);
           F_noarray.default_argvals=cell(0,0);
		   F_noarray.output=cell(0);
           for j=1:length(Fidx)
                F_noarray.args{j}=Fidx(j).args;
                F_noarray.argvals{j}=Fidx(j).argvals;
                F_noarray.default_argvals{j}=Fidx(j).default_argvals;
				if(isfield(Fidx(j),'output'))
                    F_noarray.output{j}=Fidx(j).output;
                else
                    F_noarray.output{j}=Fidx(j).output;
                end
           end
           x.F{idx}=F_noarray;
        end
    end
    

end