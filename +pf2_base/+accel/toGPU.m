function [data, onGPU] = toGPU(data, varargin)
% TOGPU Transfer array to GPU if available and data exceeds size threshold
%
% Conditionally transfers a numeric array to the GPU. Returns the data
% unchanged (on CPU) when no GPU is available or the array is too small
% to benefit from GPU acceleration. The onGPU flag lets callers branch
% without additional isgpuarray checks.
%
% Syntax:
%   [data, onGPU] = pf2_base.accel.toGPU(data)
%   [data, onGPU] = pf2_base.accel.toGPU(data, 'MinElements', 50000)
%   [data, onGPU] = pf2_base.accel.toGPU(data, 'Force', true)
%
% Inputs:
%   data - Numeric array to (potentially) transfer
%
% Name-Value Parameters:
%   MinElements - Minimum numel(data) for transfer (default: 10000)
%   Force       - Transfer regardless of size threshold (default: false)
%
% Outputs:
%   data  - gpuArray if transferred, otherwise unchanged CPU array
%   onGPU - logical, true if data is now on GPU
%
% Example:
%   [S, onGPU] = pf2_base.accel.toGPU(signal, 'MinElements', 5000);
%   R = S' * S;  % runs on GPU if onGPU is true
%   R = pf2_base.accel.gather(R);  % bring back to CPU
%
% See also: gpuArray, pf2_base.accel.isGPUAvailable, pf2_base.accel.gather

    p = inputParser;
    p.addRequired('data', @isnumeric);
    p.addParameter('MinElements', 10000, @(x) isnumeric(x) && isscalar(x));
    p.addParameter('Force', false, @islogical);
    p.parse(data, varargin{:});

    onGPU = false;

    info = pf2_base.accel.isGPUAvailable();
    if ~info.available
        return;
    end

    if ~p.Results.Force && numel(data) < p.Results.MinElements
        return;
    end

    try
        data = gpuArray(data);
        onGPU = true;
    catch
        % Transfer failed (e.g. unsupported type, out of memory)
        onGPU = false;
    end
end
