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
			chMaskFile=load(filestr,'fmask');
			fNIR.fchMask=chMaskFile.fmask;
			fprintf('Channel mask loaded from: %s\n',filestr);
			fprintf('%i channels rejected, %i channels marked noisy',(sum(fNIR.fchMask==0)),sum(fNIR.fchMask==0.5));
		else
			fNIR=probeCheckGUI(fNIR,nirFilename);
		end
	end


end