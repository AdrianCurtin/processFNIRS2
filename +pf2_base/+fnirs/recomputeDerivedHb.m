function fNIR = recomputeDerivedHb(fNIR, biomarkers)
% RECOMPUTEDERIVEDHB Refresh HbTotal/HbDiff/CBSI from corrected HbO/HbR
%
% After an in-place correction of HbO and HbR (e.g. accelerometer or
% physiological nuisance regression), the derived hemoglobin fields
% (HbTotal = HbO + HbR, HbDiff = HbO - HbR, CBSI) become stale: HbTotal no
% longer equals HbO + HbR, and CBSI still reflects the pre-correction signal.
% This helper recomputes whichever of those fields already exist so the struct
% stays internally consistent. It is a no-op unless BOTH HbO and HbR were among
% the corrected biomarkers and are present.
%
% Syntax:
%   fNIR = pf2_base.fnirs.recomputeDerivedHb(fNIR, biomarkers)
%
% Inputs:
%   fNIR       - Processed fNIRS struct (HbO/HbR already corrected in place).
%   biomarkers - Cellstr of fields that were corrected. The recompute only runs
%                when this contains both 'HbO' and 'HbR'.
%
% Outputs:
%   fNIR - Struct with the present HbTotal/HbDiff/CBSI fields recomputed from
%          the corrected HbO/HbR. Trailing marker columns (channels < 0, which
%          legacy bvoxy appends to every Hb field) are left untouched.
%
% Algorithm:
%   HbTotal = HbO + HbR, HbDiff = HbO - HbR, and CBSI = (HbO - alpha*HbR)/2 with
%   per-channel alpha = std(HbO)/std(HbR), matching pf2_base.fnirs.bvoxy. Only
%   real channels (channels >= 0) are recomputed; marker columns are preserved.
%
% Note:
%   Because least-squares regression is linear, recomputing HbTotal/HbDiff this
%   way is identical to having regressed the nuisance out of those fields
%   directly. CBSI is nonlinear (depends on the std ratio) and is recomputed
%   from the corrected HbO/HbR.
%
% See also: pf2_base.fnirs.accelRegress, pf2_base.fnirs.physioRegress,
%           pf2_base.fnirs.bvoxy

if ~(isfield(fNIR, 'HbO') && isfield(fNIR, 'HbR') ...
        && any(strcmp(biomarkers, 'HbO')) && any(strcmp(biomarkers, 'HbR')))
    return;
end

HbO = fNIR.HbO;
HbR = fNIR.HbR;
n = size(HbO, 2);
if size(HbR, 2) ~= n
    return;   % unexpected shape mismatch; leave derived fields as-is
end

% Real hemoglobin channels vs trailing marker columns appended by legacy
% bvoxy (channels < 0). Marker columns hold marker codes, not summed Hb, so
% they must not be recomputed.
realCols = true(1, n);
if isfield(fNIR, 'channels') && numel(fNIR.channels) == n
    realCols = fNIR.channels(:)' >= 0;
end

if isfield(fNIR, 'HbTotal') && size(fNIR.HbTotal, 2) == n
    fNIR.HbTotal(:, realCols) = HbO(:, realCols) + HbR(:, realCols);
end
if isfield(fNIR, 'HbDiff') && size(fNIR.HbDiff, 2) == n
    fNIR.HbDiff(:, realCols) = HbO(:, realCols) - HbR(:, realCols);
end
if isfield(fNIR, 'CBSI') && size(fNIR.CBSI, 2) == n
    o = HbO(:, realCols);
    d = HbR(:, realCols);
    alpha = std(o, 0, 1, 'omitnan') ./ std(d, 0, 1, 'omitnan');
    fNIR.CBSI(:, realCols) = (o - alpha .* d) / 2;
end

end
