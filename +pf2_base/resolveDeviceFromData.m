function dev = resolveDeviceFromData(data)
% RESOLVEDEVICEFROMDATA Return data.device if present, otherwise load it
%
% Convenience helper for consumer functions that need a pf2.Device.
% Returns the existing Device object from data.device when available,
% otherwise creates one via pf2.Device.load(data).
%
% Syntax:
%   dev = pf2_base.resolveDeviceFromData(data)
%
% Inputs:
%   data - fNIRS data struct
%
% Outputs:
%   dev - pf2.Device object
%
% See also: pf2.Device, pf2.Device.load

if isfield(data, 'device') && isa(data.device, 'pf2.Device')
    dev = data.device;
else
    dev = pf2.Device.load(data);
end

end
