function info = isGPUAvailable(varargin)
% ISGPUAVAILABLE Cached GPU device detection
%
% Probes for a GPU device once and caches the result in a persistent
% variable. Subsequent calls return instantly. Use the 'Reset' flag to
% force re-probing (e.g. after hardware changes or for testing).
%
% Syntax:
%   info = pf2_base.accel.isGPUAvailable()
%   info = pf2_base.accel.isGPUAvailable('Reset')
%
% Inputs:
%   'Reset' - (optional) Re-probe GPU even if cached result exists
%
% Outputs:
%   info - Struct with fields:
%     .available   - logical, true if a usable GPU was found
%     .backend     - char: 'cuda' or 'none' in practice ('metal' is an
%                    aspirational, non-wired hook — see note below)
%     .deviceName  - char: GPU device name or 'none'
%     .totalMemory - double: total GPU memory in bytes (0 if none)
%
% Example:
%   info = pf2_base.accel.isGPUAvailable();
%   if info.available
%       fprintf('GPU: %s (%.0f MB)\n', info.deviceName, info.totalMemory/1e6);
%   end
%
% See also: gpuDevice, pf2_base.accel.toGPU

    persistent cachedInfo

    doReset = nargin > 0 && ischar(varargin{1}) && strcmpi(varargin{1}, 'Reset');

    if ~isempty(cachedInfo) && ~doReset
        info = cachedInfo;
        return;
    end

    info.available = false;
    info.backend = 'none';
    info.deviceName = 'none';
    info.totalMemory = 0;

    try
        if ~(exist('gpuDevice', 'file') || exist('gpuDevice', 'builtin'))
            cachedInfo = info;
            return;
        end

        dev = gpuDevice;
        if dev.Index > 0 && dev.DeviceAvailable
            info.available = true;
            info.deviceName = dev.Name;
            info.totalMemory = dev.TotalMemory;

            % Detect backend from device name.
            %
            % ASPIRATIONAL — the 'metal' branch is NOT wired up. MATLAB's
            % gpuArray (Parallel Computing Toolbox) is CUDA-only and is
            % unsupported on macOS, so gpuDevice() throws on Apple hardware
            % and execution never reaches this point with a Metal device. In
            % practice info.backend is only ever 'cuda' here. Honoring a Metal
            % backend would require a non-gpuArray path (e.g. the third-party
            % "Metal for MATLAB" toolbox) plus reworking pf2_base.accel.toGPU/
            % gather and the GPU hot loops against that API. The branch is
            % retained only as a forward-looking hook; do not treat a 'metal'
            % result as a usable compute backend.
            nameLower = lower(dev.Name);
            if contains(nameLower, 'apple') || contains(nameLower, 'metal')
                info.backend = 'metal';
            else
                info.backend = 'cuda';
            end
        end
    catch
        % GPU not available or Parallel Computing Toolbox missing
    end

    cachedInfo = info;
end
