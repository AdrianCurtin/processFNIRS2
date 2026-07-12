function [canUse, poolRunning] = canParfor()
% CANPARFOR Check if parfor is available and whether a pool is running
%
% Returns whether the Parallel Computing Toolbox is licensed and
% whether a parallel pool is already running. This avoids the 10-30s
% startup penalty when launching parfor on small workloads.
%
% Syntax:
%   [canUse, poolRunning] = pf2_base.accel.canParfor()
%
% Outputs:
%   canUse      - logical, true if parfor is licensed and available
%   poolRunning - logical, true if a parallel pool is already open
%
% Example:
%   [canUse, poolRunning] = pf2_base.accel.canParfor();
%   if canUse && (poolRunning || nPairs > 100)
%       parfor k = 1:nPairs
%           ...
%       end
%   end
%
% See also: gcp, parfor, pf2_base.accel.isGPUAvailable

    canUse = false;
    poolRunning = false;

    try
        if ~license('test', 'Distrib_Computing_Toolbox')
            return;
        end

        % Check if parfor is actually usable (toolbox installed, not just licensed)
        if ~(exist('parfor', 'builtin') || exist('gcp', 'file'))
            return;
        end

        canUse = true;

        % Check for existing pool (avoids startup cost)
        pool = gcp('nocreate');
        poolRunning = ~isempty(pool);
    catch
        % Toolbox not available
    end
end
