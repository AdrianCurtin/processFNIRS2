function [filename] = saveEx(filename)
% SAVEEX Save the current exploreFNIRS experiment session
%
% Persists the current exploreFNIRS session to a .mat file, including all
% loaded fNIRS data, analysis settings, ROI configurations, and data
% hierarchy. The saved file can be reloaded later with LoadEx to continue
% analysis or shared with collaborators.
%
% Reference:
%   Internal pf2 implementation for exploreFNIRS session persistence.
%
% Syntax:
%   SaveEx()
%   filename = SaveEx()
%   filename = SaveEx(filename)
%
% Inputs:
%   filename - (Optional) Output path for the .mat file [char]
%              If omitted, opens uiputfile dialog for interactive selection.
%              Default filter suggests *_exf.mat naming convention.
%              Recommended format: experimentname_exf.mat
%
% Outputs:
%   filename - Full path to the saved file [char]
%              Returns empty string or 0 if user cancels the file dialog.
%
% Global Variables Used:
%   ExFNIRS - Main exploreFNIRS state structure [struct]
%             Must contain .data field or function throws an error.
%             All fields are saved including settings, dataHierarchy,
%             dataTable, and currentROI.
%
% Algorithm:
%   1. If no filename provided, open save file dialog
%   2. Validate that ExFNIRS.data exists
%   3. Construct full filepath from path and filename
%   4. Save ExFNIRS structure using MATLAB v7.3 format
%   5. Print confirmation message to console
%
% Example:
%   % Save session with file dialog
%   exploreFNIRS.saveEx();
%
%   % Save to specific file
%   exploreFNIRS.saveEx('/path/to/myexperiment_exf.mat');
%
%   % Save and capture filename for logging
%   savedFile = exploreFNIRS.saveEx();
%   fprintf('Session saved to: %s\n', savedFile);
%
%   % Typical workflow: process data, then save
%   % ... perform analysis in exploreFNIRS GUI ...
%   exploreFNIRS.saveEx('study_analysis_exf.mat');
%
% Notes:
%   - Uses MATLAB v7.3 format (HDF5) to support large datasets (>2GB)
%   - Throws error if ExFNIRS.data field is not present
%   - Progress messages printed to console during save operation
%   - File can be loaded by LoadEx or standard MATLAB load() function
%
% See also: exploreFNIRS.loadEx, exploreFNIRS, exploreFNIRS.browseEx
pathname='';

if(nargin<1)
    [filename, pathname] = uiputfile({'*_exf.mat';'*.mat';'*.*'},'Save Explore FNIRS experiment');
    if(isempty(filename)||~ischar(filename)||(isnumeric(filename)&&filename==0))
        return
    end
end



global ExFNIRS

if(~isfield(ExFNIRS,'data'))
    error('No data present in ExFNIRS');
end

if(~isempty(pathname))
    filename=sprintf('%s/%s',pathname,filename);
end

fprintf('Saving experiment to %s...\n',filename);

save(filename,'ExFNIRS','-v7.3');

fprintf('Done!\n');



end

