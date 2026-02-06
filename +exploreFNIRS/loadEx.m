function [filename] = loadEx(filename)
% LOADEX Load a saved exploreFNIRS experiment session
%
% Restores a previously saved exploreFNIRS session from a .mat file,
% including all loaded fNIRS data, analysis settings, ROI configurations,
% and data hierarchy information. This allows users to continue analysis
% from where they left off or share experiment configurations.
%
% Reference:
%   Internal pf2 implementation for exploreFNIRS session persistence.
%
% Syntax:
%   LoadEx()
%   filename = LoadEx()
%   filename = LoadEx(filename)
%
% Inputs:
%   filename - (Optional) Path to the .mat file to load [char]
%              If omitted, opens uigetfile dialog for interactive selection.
%              File must contain an ExFNIRS structure saved by SaveEx.
%              Typical naming convention: *_exf.mat
%
% Outputs:
%   filename - Full path to the loaded file [char]
%              Returns empty string or 0 if user cancels the file dialog.
%
% Global Variables Modified:
%   ExFNIRS - Main exploreFNIRS state structure, with these fields restored:
%     .settings       - GUI and analysis settings [struct]
%     .data           - Loaded fNIRS data [cell array]
%     .dataHierarchy  - Subject/session grouping information [struct]
%     .dataTable      - Summary table of loaded data [table]
%     .currentROI     - Currently selected ROI configuration [struct]
%     .UpdateNeeded   - Set to 4 to trigger full GUI refresh [double]
%
% Algorithm:
%   1. If no filename provided, open file selection dialog
%   2. Load ExFNIRS structure from specified .mat file
%   3. Validate that file contains ExFNIRS data
%   4. Copy specific fields to global ExFNIRS (preserving session paths)
%   5. Set UpdateNeeded flag to trigger GUI refresh
%
% Example:
%   % Load session with file dialog
%   exploreFNIRS.loadEx();
%
%   % Load specific saved experiment
%   exploreFNIRS.loadEx('/path/to/myexperiment_exf.mat');
%
%   % Load and capture the filename for logging
%   loadedFile = exploreFNIRS.loadEx();
%   fprintf('Loaded session from: %s\n', loadedFile);
%
% Notes:
%   - Only specific fields are restored to preserve current session paths
%   - Throws error if file doesn't contain valid ExFNIRS structure
%   - Compatible with files saved by SaveEx using MATLAB v7.3 format
%   - After loading, the GUI automatically refreshes to display loaded data
%
% See also: exploreFNIRS.saveEx, exploreFNIRS, exploreFNIRS.browseEx
pathname='';

if(nargin<1)
    [filename, pathname] = uigetfile({'*.mat';'*.*'},'Load Explore FNIRS experiment');
    if(isempty(filename)||~ischar(filename)||(isnumeric(filename)&&filename==0))
        return
    end
end

if(~isempty(pathname))
    filename=sprintf('%s/%s',pathname,filename);
end


tempLoadEx=load(filename,'ExFNIRS');


if(~isfield(tempLoadEx,'ExFNIRS')||isempty(tempLoadEx))
    error('No data found');
end




global ExFNIRS

fieldsToKeep={'settings','data','dataHierarchy','dataTable','currentROI'};

for f=1:length(fieldsToKeep)
    if(isfield(tempLoadEx.ExFNIRS,fieldsToKeep{f}))
        ExFNIRS.(fieldsToKeep{f})=tempLoadEx.ExFNIRS.(fieldsToKeep{f});
    end
end

ExFNIRS.UpdateNeeded=4;

end

