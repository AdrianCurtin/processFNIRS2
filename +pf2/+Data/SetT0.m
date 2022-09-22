function outFNIR=SetT0(fnirStruct,t0time)

%This function takes an incoming fNIRstruct and shifts the time such that
%t0 is now 0;

outFNIR=fnirStruct;

if(isdatetime(t0time)&&isfield(outFNIR,'t0'))
    % Ex: orig 15:01:25    new t0 is 15:00
    % t0time = orig + 85s  
    tDiff=seconds(t0time-outFNIR.t0);
    outFNIR.t0=t0time;

    t0time=tDiff;
elseif(isdatetime(t0time)&&isfield(outFNIR,'datetime'))
    % if datetime field is available, use the datetime to subtract
    if(all(size(outFNIR.time)==size(outFNIR.datetime)))
        outFNIR.t0=t0time;
        tdiff=outFNIR.time(1)-seconds(outFNIR.datetime(1)-outFNIR.t0);
        t0time=tdiff;
    else
        error('All datetimes must be the same size as times')
    end
end



if(isfield(outFNIR,'time'))
    outFNIR.time=outFNIR.time-t0time;
end

if(isfield(outFNIR,'t0')&&~isfield(outFNIR,'datetime'))
    %datetime shouldn't be changing
    outFNIR.datetime=outFNIR.t0+(duration(0,0,outFNIR.time));
end

if(isfield(outFNIR,'markers'))
   if(isfield(outFNIR.markers,'data'))
       outFNIR.markers.data(:,1)= outFNIR.markers.data(:,1)-t0time;
   elseif(~isempty(outFNIR.markers))
      outFNIR.markers(:,1)= outFNIR.markers(:,1)-t0time;
   end
end

if(isfield(outFNIR,'raw'))
   %outFNIR.raw(:,1)= outFNIR.raw(:,1)-t0time;
end

if(pf2_base.isnestedfield(outFNIR,'Aux')) && ~isempty(outFNIR.Aux)
    auxFields=fields(outFNIR.Aux);
    for f=1:length(auxFields)
    	curFieldName=auxFields{f};
        outFNIR.Aux.(curFieldName)(:,1) = outFNIR.Aux.(curFieldName)(:,1) -t0time; 
    end
end

if(pf2_base.isnestedfield(outFNIR,'Aux.t'))
    outFNIR.Aux.t(:,1)= outFNIR.Aux.t(:,1)-t0time;
end

if(pf2_base.isnestedfield(outFNIR,'Aux.time'))
    outFNIR.Aux.time(:,1)= outFNIR.Aux.time(:,1)-t0time;
end