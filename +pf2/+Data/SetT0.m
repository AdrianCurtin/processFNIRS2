function outFNIR=SetT0(fnirStruct,t0time)

%This function takes an incoming fNIRstruct and shifts the time such that
%t0 is now 0;

outFNIR=fnirStruct;



hasDatetime = isfield(outFNIR,'datetime');
hasT0 = isfield(outFNIR,'t0');

if(isduration(t0time))
    tDiff=seconds(t0time);
elseif(isdatetime(t0time))
    if(hasT0)
        outFNIR.t0=t0time;
        % if new time is earlier, this should be negative
        tDiff=seconds(t0time-fnirStruct.t0);
    elseif(hasDatetime)
        % if datetime field is available, use the datetime to subtract
        if(all(size(outFNIR.time)==size(outFNIR.datetime)))
            %outFNIR.t0=outFNIR.datetime(1);
            tDiff=outFNIR.time(1)-seconds(outFNIR.datetime(1)-outFNIR.t0);
            
        else
            error('All datetimes must be the same size as times');
        end
    else
        error('t0 cannot be set as a datetime if fnirs struct does not have datetime measures');
    end
else
    tDiff=t0time;
end

if(isfield(outFNIR,'time'))
    outFNIR.time=outFNIR.time-tDiff;
end

if(isfield(outFNIR,'t0')&&~isfield(outFNIR,'datetime'))
    %if we don't have datetime field, but do have t0, build datetime
    outFNIR.datetime=outFNIR.t0+(duration(0,0,outFNIR.time));
elseif(~isfield(outFNIR,'t0')&&isfield(outFNIR,'datetime'))
    %if we have datetime field, but don't have t0, build t0
    outFNIR.t0=outFNIR.datetime(1)-(duration(0,0,outFNIR.time(1)));
end

if(isfield(outFNIR,'t0'))
    outFNIR.t0=fnirStruct.t0+duration(0,0,tDiff);
end


if(isfield(outFNIR,'markers'))
   if(isfield(outFNIR.markers,'data'))
       outFNIR.markers.data(:,1)= outFNIR.markers.data(:,1)-tDiff;
   elseif(~isempty(outFNIR.markers))
      outFNIR.markers(:,1)= outFNIR.markers(:,1)-tDiff;
   end
end

if(isfield(outFNIR,'raw'))
   %outFNIR.raw(:,1)= outFNIR.raw(:,1)-t0time;
end

if(pf2_base.isnestedfield(outFNIR,'Aux')) && ~isempty(outFNIR.Aux)
    auxFields=fields(outFNIR.Aux);
    for f=1:length(auxFields)
    	curFieldName=auxFields{f};
        outFNIR.Aux.(curFieldName)(:,1) = outFNIR.Aux.(curFieldName)(:,1) -tDiff; 
    end
end

if(pf2_base.isnestedfield(outFNIR,'Aux.t'))
    outFNIR.Aux.t(:,1)= outFNIR.Aux.t(:,1)-tDiff;
end

if(pf2_base.isnestedfield(outFNIR,'Aux.time'))
    outFNIR.Aux.time(:,1)= outFNIR.Aux.time(:,1)-tDiff;
end