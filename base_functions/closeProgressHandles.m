function closeProgressHandles()
% This function closes any progress status figures currently open that have
% handles stored in global variable ProgressHandles.h

global ProgressHandles

if(isempty(ProgressHandles))
        ProgressHandles.h=struct();
    return;
else
   validFields=fields(ProgressHandles.h);
   
   for i=1:length(validFields)
        if(isvalid(ProgressHandles.h.(validFields{i})))
            close(ProgressHandles.h.(validFields{i}));
            ProgressHandles.h=rmfield(ProgressHandles.h,validFields{i});
        else
            ProgressHandles.h=rmfield(ProgressHandles.h,validFields{i});
        end
   end
    
end