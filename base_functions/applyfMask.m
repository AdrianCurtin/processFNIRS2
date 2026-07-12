function fnir=applyfMask(fnir, rejectLevel)
% Deletes all fields that are marked as bad channels

warning('Please replace with pf2.data.applyChannelMask');

if nargin < 2
    fnir=pf2.data.applyChannelMask(fnir);
else
    fnir=pf2.data.applyChannelMask(fnir, rejectLevel);
end

end
