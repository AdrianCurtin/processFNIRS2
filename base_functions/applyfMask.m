function fnir=applyfMask(fnir)
% Deletes all fields that are marked as bad channels

global PF2

warning('Please replace with pf2.data.applyChannelMask');

fnir=pf2.data.applyChannelMask(fnir);

end