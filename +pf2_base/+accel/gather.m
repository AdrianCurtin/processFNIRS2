function data = gather(data)
% GATHER Bring GPU data back to CPU; no-op for CPU arrays
%
% Thin wrapper around MATLAB's gather() that avoids isgpuarray checks
% at every call site. Safe to call on any numeric array.
%
% Syntax:
%   data = pf2_base.accel.gather(data)
%
% Inputs:
%   data - Numeric array (gpuArray or standard)
%
% Outputs:
%   data - Standard CPU array
%
% Example:
%   [S, onGPU] = pf2_base.accel.toGPU(signal);
%   R = S' * S;
%   R = pf2_base.accel.gather(R);  % always CPU, regardless of input
%
% See also: gather, pf2_base.accel.toGPU

    if isa(data, 'gpuArray')
        data = gather(data);
    end
end
