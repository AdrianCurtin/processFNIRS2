function varargout=browseEx(varargin)
% BROWSEEX Open file browser dialog for loading fNIRS data into exploreFNIRS
%
% Launches the exploreFNIRS file browser GUI to interactively select and
% load fNIRS data files for multi-subject analysis. This is a convenience
% wrapper around exploreFNIRS_browse that provides a shorter function name
% for command-line use.
%
% Reference:
%   Internal pf2 implementation for exploreFNIRS GUI workflow.
%
% Syntax:
%   BrowseEx()
%   data = BrowseEx()
%   data = BrowseEx(initialPath)
%
% Inputs:
%   initialPath - (Optional) Starting directory path [char]
%                 If omitted, browser opens in the current directory or
%                 last used location. Pass a valid directory path to start
%                 browsing from a specific location.
%
% Outputs:
%   data - Loaded fNIRS data from selected files [cell array or struct]
%          Returns the output from exploreFNIRS_browse. When no output
%          is requested, data is loaded directly into the exploreFNIRS
%          workspace.
%
% Example:
%   % Launch browser with file dialog
%   exploreFNIRS.BrowseEx();
%
%   % Launch browser starting in specific directory
%   exploreFNIRS.BrowseEx('/path/to/fnirs/data');
%
%   % Load data and capture in variable
%   myData = exploreFNIRS.BrowseEx();
%
% Notes:
%   - Supports loading multiple file formats (NIR, SNIRF, Hitachi, NIRx)
%   - Selected files are automatically imported using appropriate readers
%   - For programmatic loading without GUI, use LoadEx instead
%
% See also: exploreFNIRS.LoadEx, exploreFNIRS.SaveEx, exploreFNIRS,
%           exploreFNIRS_browse

if(nargout>0)
    varargout{1:nargout}=exploreFNIRS_browse(varargin{:});
else
   exploreFNIRS_browse(varargin{:}); 
end