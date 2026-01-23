function [HbO, HbR, Total, HbDiff,CBSI,units]=bvoxy_basic(Iin1,Iin2,wv1,wv2,DPF)
% BVOXY_BASIC Simplified Beer-Lambert conversion for two-wavelength fNIRS
%
% Converts raw intensity or optical density data to hemoglobin concentrations
% using a simplified interface to the full bvoxy function. Assumes standard
% two-wavelength fNIRS data with equal-length vectors for both wavelengths.
%
% Reference:
%   Modified Beer-Lambert Law. See pf2_base.fnirs.bvoxy for full details.
%
% Syntax:
%   [HbO, HbR, Total, HbDiff, CBSI, units] = bvoxy_basic(Iin1, Iin2)
%   [HbO, HbR, Total, HbDiff, CBSI, units] = bvoxy_basic(Iin1, Iin2, wv1, wv2)
%   [HbO, HbR, Total, HbDiff, CBSI, units] = bvoxy_basic(Iin1, Iin2, wv1, wv2, DPF)
%
% Inputs:
%   Iin1 - First wavelength data [T x 1 double], typically ~700nm
%          Can be raw intensity or optical density (specify via isOD in bvoxy).
%   Iin2 - Second wavelength data [T x 1 double], typically ~850nm
%          Must be same length as Iin1.
%   wv1  - First wavelength in nm (default: 700)
%   wv2  - Second wavelength in nm (default: 850)
%   DPF  - Differential pathlength factor [1 x 2 double] for [wv1, wv2]
%          (default: [NaN, NaN] triggers age-based DPF calculation)
%
% Outputs:
%   HbO    - Oxygenated hemoglobin [T x 1]
%   HbR    - Deoxygenated hemoglobin [T x 1]
%   Total  - Total hemoglobin (HbO + HbR) [T x 1]
%   HbDiff - Differential hemoglobin (HbO - HbR) [T x 1]
%   CBSI   - Correlation-based signal improvement [T x 1]
%   units  - Output units string ('uM' or 'mM*mm')
%
% Example:
%   % Convert two wavelength channels
%   [HbO, HbR] = bvoxy_basic(data.raw(:,1), data.raw(:,2));
%
% See also: pf2_base.fnirs.bvoxy, processStageOD2Hb

if(nargin<5)
    DPF=[nan,nan];
end

if(nargin<3)
    wv1=700;
    wv2=850;
end



[HbO, HbR, Total, HbDiff,CBSI,~,~,units,~]=pf2_base.fnirs.bvoxy([Iin1,Iin2],1:length(Iin1),[ones(size(wv1))*wv1,ones(size(wv2))*wv2],1:length(Iin1),DPF,'isOD',false);