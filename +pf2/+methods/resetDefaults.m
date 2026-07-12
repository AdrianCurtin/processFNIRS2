function resetDefaults(varargin)
% RESETDEFAULTS Wipe stored methods and re-seed from repo factory functions.
%
% Syntax:
%   pf2.methods.resetDefaults()                  % both stages
%   pf2.methods.resetDefaults('Stage', 'raw')    % raw stage only
%   pf2.methods.resetDefaults('Stage', 'oxy')    % oxy stage only
%   pf2.methods.resetDefaults('Confirm', false)  % skip confirmation
%
% Behavior:
%   1. Asks the user to confirm (unless 'Confirm' is false).
%   2. Deletes the prefdir cfg file(s) for the requested stage(s).
%   3. Clears cached globals so pf2_initialize re-seeds on next call.
%   4. Calls pf2_initialize(), which now applies all repo seeds via
%      the factory functions in +pf2/+methods/+seeds/+raw and +oxy.
%
% Use this when the stored methods cfg has become corrupted, or after
% upgrading pf2 and wanting the latest shipped defaults.
%
% Example:
%   % Restore the shipped defaults for both stages (prompts to confirm)
%   pf2.methods.resetDefaults();
%
%   % Reset only the raw stage without a confirmation prompt
%   pf2.methods.resetDefaults('Stage', 'raw', 'Confirm', false);
%
% See also: pf2.methods.seeds.list

ip = inputParser;
ip.addParameter('Stage',   'both', @(x) ismember(lower(char(x)), {'raw','oxy','both'}));
ip.addParameter('Confirm', true,   @islogical);
ip.parse(varargin{:});
stage   = lower(char(ip.Results.Stage));
confirm = ip.Results.Confirm;

if confirm
    msg = sprintf(['This will DELETE your stored pf2 methods and replace ' ...
        'them with the repo defaults. Stage: %s. Continue?'], stage);
    resp = input([msg ' (y/N) '], 's');
    if isempty(resp) || ~strncmpi(resp, 'y', 1)
        fprintf('Aborted.\n');
        return
    end
end

rawPath = fullfile(prefdir, 'pf2_raw_methods_stored_processFNIRS2.cfg');
oxyPath = fullfile(prefdir, 'pf2_oxy_methods_stored_processFNIRS2.cfg');

if ismember(stage, {'raw','both'}) && exist(rawPath, 'file')
    delete(rawPath);
    fprintf('Deleted %s\n', rawPath);
end
if ismember(stage, {'oxy','both'}) && exist(oxyPath, 'file')
    delete(oxyPath);
    fprintf('Deleted %s\n', oxyPath);
end

% Force re-init: clear the relevant globals so pf2_initialize will rebuild.
global PF2 %#ok<GVMIS>
if ~isempty(PF2)
    if ismember(stage, {'raw','both'}) && isfield(PF2, 'myRawMethods')
        PF2 = rmfield(PF2, 'myRawMethods');
    end
    if ismember(stage, {'oxy','both'}) && isfield(PF2, 'myOxyMethods')
        PF2 = rmfield(PF2, 'myOxyMethods');
    end
    if ~isfield(PF2, 'myRawMethods') && ~isfield(PF2, 'myOxyMethods')
        % If both are missing, drop baseline so pf2_initialize fully reruns.
        if isfield(PF2, 'baseline')
            PF2 = rmfield(PF2, 'baseline');
        end
    end
end

% Re-initialize: this creates empty cfgs in prefdir.
pf2_base.pf2_initialize();

% Now apply the seeds.
seeds = pf2.methods.seeds.list();
for k = 1:numel(seeds)
    s = seeds(k);
    if strcmp(stage, 'raw') && ~strcmp(s.stage, 'raw'), continue; end
    if strcmp(stage, 'oxy') && ~strcmp(s.stage, 'oxy'), continue; end
    factory = ['pf2.methods.seeds.' s.stage '.' s.name];
    try
        p = feval(factory);
        p.save(s.stage, 'Replace', true);
        fprintf('Seeded %s method: %s\n', s.stage, s.name);
    catch ME
        warning('pf2:methods:seedFailed', ...
            'Failed to seed %s method ''%s'': %s', s.stage, s.name, ME.message);
    end
end

% Pipeline.save() above already updated PF2.myRawMethods / myOxyMethods
% in-memory via pf2.methods.{raw,oxy}.create, so no extra reload needed.

fprintf('Done. %d methods seeded.\n', numel(seeds));
end
