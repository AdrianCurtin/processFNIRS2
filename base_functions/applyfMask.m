function fnir=applyfMask(fnir)
% Deletes all fields that are marked as bad channels

global PF2.RejectLevel

if(isfield(fnir,'fchMask'))
    if(isfield(fnir,'oxy'))
        fnir.oxy(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'hbo'))
        fnir.hbo(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'hbr'))
        fnir.hbr(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'HbDiff'))
        fnir.HbDiff(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'CBSI'))
        fnir.CBSI(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'total'))
        fnir.CBSI(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'Total'))
        fnir.Total(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'HbTotal'))
        fnir.HbTotal(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'HbR'))
        fnir.HbR(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'HbO'))
        fnir.HbO(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
   
    if(isfield(fnir,'cbsi'))
        fnir.cbsi(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
    
    if(isfield(fnir,'total'))
        fnir.total(:,~(fnir.fchMask>PF2.RejectLevel))=NaN;
    end
end

end