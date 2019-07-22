function outFNIR=SetT0(fnirStruct,t0time)

%This function takes an incoming fNIRstruct and shifts the time such that
%t0 is now 0;

outFNIR=fnirStruct;
outFNIR.time=outFNIR.time-t0time;

if(isfield(outFNIR,'markers'))
   if(isfield(outFNIR.markers,'data'))
       outFNIR.markers.data(:,1)= outFNIR.markers.data(:,1)-t0time;
   else
      outFNIR.markers(:,1)= outFNIR.markers(:,1)-t0time;
   end
end

if(isfield(outFNIR,'raw'))
   %outFNIR.raw(:,1)= outFNIR.raw(:,1)-t0time;
end


if(pf2_base.isnestedfield(outFNIR,'Aux.t'))
    outFNIR.Aux.t(:,1)= outFNIR.Aux.t(:,1)-t0time;
end

if(pf2_base.isnestedfield(outFNIR,'Aux.time'))
    outFNIR.Aux.time(:,1)= outFNIR.Aux.time(:,1)-t0time;
end