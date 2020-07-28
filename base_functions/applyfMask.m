function fnir=applyfMask(fnir)
% Deletes all fields that are marked as bad channels

global PF2

warning('Please replace with processFNIRS.Data.ApplyChannelMask');

fnir=pf2.Data.ApplyChannelMask(fnir);

end