function fnir=ApplyChannelMask(fnir)
% Deletes all fields that are marked as bad channels

global PF2

validFields=pf2_base.pf2_getFNIRSbiomFields();

if(isfield(fnir,'fchMask'))
    for i=1:length(validFields)
       if(isfield(fnir,validFields{i}))
          fnir.(validFields{i})(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
       end
    end
end

end