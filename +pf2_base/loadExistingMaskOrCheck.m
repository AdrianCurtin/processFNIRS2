function fNIR=loadExistingMaskOrCheck(fNIR,nirFilename)

	if(nargin<2||isempty(nirFilename))
		if(pf2_base.isnestedfield(fNIR,'info.filename'))
		   nirFilename=fNIR.info.filename; 
		else
		   error('No filename found'); 
		end
	end

	if(~isempty(nirFilename))
		[pathstr, name, ext] = fileparts(nirFilename);
		if(length(pathstr)>0)
			filestr=[pathstr,'/',name,'_CH.mat'];
		else
			filestr=[name,'_CH.mat'];
        end
		
        if exist(filestr, 'file') == 2
			chMaskFile=load(filestr);
            
            maskFields=fields(chMaskFile);
            
            potentiallyValidMasks=find(contains(lower(maskFields),'mask'));
            % Just accept anything that says mask
            for m=1:length(potentiallyValidMasks)
                potentialField=chMaskFile.(maskFields{potentiallyValidMasks(m)});
                if(isnumeric(potentialField))
                    fNIR.fchMask=potentialField;
                    fprintf('Channel mask loaded from: %s\n',filestr);
                    fprintf('%i channels rejected, %i channels marked noisy\n',(sum(fNIR.fchMask==0)),sum(fNIR.fchMask==0.5));
                    
                    return;
                end
                
            end
            
        end
        
        fNIR=probeCheckGUI(fNIR,nirFilename);
		
	end


end