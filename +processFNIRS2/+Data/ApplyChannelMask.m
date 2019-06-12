function fnir=ApplyChannelMask(fnir)
% Deletes all fields that are marked as bad channels

if(isfield(fnir,'fchMask'))
    if(isfield(fnir,'oxy'))
        fnir.oxy(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'hbo'))
        fnir.hbo(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'hbr'))
        fnir.hbr(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'HbDiff'))
        fnir.HbDiff(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'CBSI'))
        fnir.CBSI(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'total'))
        fnir.CBSI(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'Total'))
        fnir.Total(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'HbTotal'))
        fnir.HbTotal(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'HbR'))
        fnir.HbR(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'HbO'))
        fnir.HbO(:,~(fnir.fchMask>0))=NaN;
    end
   
    if(isfield(fnir,'cbsi'))
        fnir.cbsi(:,~(fnir.fchMask>0))=NaN;
    end
    
    if(isfield(fnir,'total'))
        fnir.total(:,~(fnir.fchMask>0))=NaN;
    end
end

end