function fNIR=loadExistingMaskOrCheck(fNIR,nirFilename,channelCheckVersion)
% LOADEXISTINGMASKORCHECK Load saved channel mask or launch quality check GUI
%
% Checks for a previously saved channel mask file (*_CH.mat) associated
% with the given fNIRS recording. If found, loads the mask into fchMask.
% Otherwise, launches the channel quality check GUI (probeCheckGUI or
% ChannelCheck) for interactive channel rejection.
%
% Syntax:
%   fNIR = pf2_base.loadExistingMaskOrCheck(fNIR)
%   fNIR = pf2_base.loadExistingMaskOrCheck(fNIR, nirFilename)
%   fNIR = pf2_base.loadExistingMaskOrCheck(fNIR, nirFilename, channelCheckVersion)
%
% Inputs:
%   fNIR                - fNIRS data structure [struct]
%                         Must contain info.filename if nirFilename is omitted.
%   nirFilename         - (optional) Full path to the original recording file.
%                         Used to locate the *_CH.mat sidecar. If omitted,
%                         reads from fNIR.info.filename.
%   channelCheckVersion - (optional) Which GUI to launch when no saved mask
%                         exists. 1 = probeCheckGUI (default, legacy),
%                         2 = pf2.qc.ChannelCheck (App Designer).
%
% Outputs:
%   fNIR - fNIRS structure with fchMask field updated [struct]
%          Values: 1 = good, 0.5 = marginal, 0 = rejected.
%
% Algorithm:
%   1. Derive *_CH.mat path from nirFilename (or fNIR.info.filename)
%   2. If *_CH.mat exists, load and search for any field containing 'mask'
%   3. If found, assign to fNIR.fchMask and return
%   4. Otherwise, launch the selected channel check GUI
%
% Example:
%   data = pf2.import.importNIR('recording.nir');
%   data = pf2_base.loadExistingMaskOrCheck(data);
%
% See also: pf2.qc.ChannelCheck, probeCheckGUI

	if(nargin<2||isempty(nirFilename))
		if(pf2_base.isnestedfield(fNIR,'info.filename'))
		   nirFilename=fNIR.info.filename;
		else
		   error('No filename found');
		end
	end
	if nargin < 3 || isempty(channelCheckVersion)
		channelCheckVersion = 1;
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

		if channelCheckVersion == 2
			app = pf2.qc.ChannelCheck(fNIR, ...
				'CalledFromImport', true, 'SkipConfirmation', true);
			if isvalid(app)
				fNIR = app.OutputData;
				delete(app);
			end
		else
			fNIR=probeCheckGUI(fNIR,nirFilename);
		end

	end


end