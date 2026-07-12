function varargout=pf2(varargin)
% PF2 Convenience wrapper that launches processFNIRS2 (self-heals the path)
%
% Thin entry point for processFNIRS2. Before delegating, it ensures the
% toolbox's non-package code folders (base_functions, functions, GUI) are on
% the MATLAB path. When only the toolbox root has been added to the path the
% `+pf2`/`+pf2_base` packages resolve, but the loose function and GUI files do
% not, which otherwise produces "undefined function" errors on a naked `pf2`
% call. This wrapper adds them on demand and prints a one-line notice.
%
% Syntax:
%   pf2                      % launch the processing GUI
%   pf2(data)                % process with the GUI
%   out = pf2(data)          % headless processing (GUI suppressed)
%   out = pf2(data, raw, oxy)% as processFNIRS2, with named methods
%
% Inputs:
%   varargin - Any arguments accepted by processFNIRS2 (see its help)
%
% Outputs:
%   varargout - Whatever processFNIRS2 returns (assigning an output
%               suppresses the GUI)
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = pf2(data);
%
% See also: processFNIRS2, pf2_base.pf2_initialize

% Ensure the loose code folders are on the path (idempotent, with a notice).
pf2_ensureToolboxPath();

if nargout > 0
    [varargout{1:nargout}] = processFNIRS2(varargin{:});
else
    processFNIRS2(varargin{:});
end

end

%%_Subfunctions_________________________________________________________

function pf2_ensureToolboxPath()
% PF2_ENSURETOOLBOXPATH Add base_functions/functions/GUI to the path if absent
%
% Adds the toolbox's non-package folders to the MATLAB path when they are not
% already present, printing a single informational message listing what was
% added. No-op (and silent) when everything is already on the path.
%
% Inputs:
%   None
%
% Outputs:
%   None

root = fileparts(mfilename('fullpath'));
subFolders = {'base_functions', 'functions', 'GUI'};

added = {};
pathDirs = regexp(path, pathsep, 'split');
for k = 1:numel(subFolders)
    target = fullfile(root, subFolders{k});
    if isfolder(target) && ~any(strcmp(target, pathDirs))
        addpath(target);
        added{end+1} = subFolders{k}; %#ok<AGROW>
    end
end

if ~isempty(added)
    fprintf('processFNIRS2: added %s to the MATLAB path.\n', ...
        strjoin(added, ', '));
end

end
