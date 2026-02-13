function cOxy = calcCBSI(oxy, deoxy)
% CALCCBSI Correlation-based signal improvement (CBSI) for fNIRS
%
% Exploits the expected negative correlation between HbO and HbR to
% suppress systemic and motion artifacts. The corrected signal is:
%
%   CBSI = (HbO - alpha * HbR) / 2
%
% where alpha = std(HbO) / std(HbR) per channel.
%
% Inputs:
%   oxy   - [T x C] oxygenated hemoglobin (HbO)
%   deoxy - [T x C] deoxygenated hemoglobin (HbR)
%
% Outputs:
%   cOxy  - [T x C] corrected signal
%
% References:
%   Cui, X., Bray, S. & Reiss, A. L. (2010). Functional near infrared
%   spectroscopy (NIRS) signal improvement based on negative correlation
%   between oxygenated and deoxygenated hemoglobin dynamics. NeuroImage,
%   49(4), 3039-3046. DOI: 10.1016/j.neuroimage.2009.11.050

    if isempty(oxy)
        cOxy = [];
        warning('CBSI error: Oxy arrays and Deoxy arrays are empty');
        return;
    end

    if ~isequal(size(oxy), size(deoxy))
        error('Oxy and Deoxy size mismatch');
    end

    alpha = std(oxy, 0, 1, 'omitnan') ./ std(deoxy, 0, 1, 'omitnan');
    cOxy = (oxy - alpha .* deoxy) / 2;
end
