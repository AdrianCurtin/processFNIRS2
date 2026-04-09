function fMask = pf2_TakizawaRejection(fNIR, strictCriteria)
% PF2_TAKIZAWAREJECTION Automatic channel rejection using Takizawa criteria
%
% Thin wrapper around pf2.qc.takizawa for backward compatibility with
% the processing pipeline and config system. All logic now lives in
% pf2.qc.takizawa — see that function for full documentation, configurable
% thresholds, and detailed per-rule output.
%
% Reference:
%   Takizawa, R., Kasai, K., Kawakubo, Y., Marumo, K., Kawasaki, S.,
%   Yamasue, H., & Fukuda, M. (2008). Reduced frontopolar activation
%   during verbal fluency task in schizophrenia: A multi-channel
%   near-infrared spectroscopy study. Schizophrenia Research, 99(1-3),
%   250-262. DOI: 10.1016/j.schres.2007.10.025
%
%   Takizawa, R., Fukuda, M., Kawasaki, S., Kasai, K., Mimura, M.,
%   Pu, S., Noda, T., Niwa, S.-I., & Okazaki, Y. (2014).
%   Neuroimaging-aided differential diagnosis of the depressive state.
%   NeuroImage, 85, 498-507. DOI: 10.1016/j.neuroimage.2013.05.126
%
% Syntax:
%   fMask = pf2_TakizawaRejection(fNIR)
%   fMask = pf2_TakizawaRejection(fNIR, strictCriteria)
%
% Inputs:
%   fNIR           - Processed fNIRS struct with fields: HbO, HbR, HbTotal,
%                    time, units, DPF_factor
%   strictCriteria - (optional) Logical, use OR instead of AND for
%                    combining rejection rules (default: false)
%
% Outputs:
%   fMask - Logical channel mask [1 x C] where 1=good, 0=rejected
%
% Example:
%   fMask = pf2_TakizawaRejection(processedData);
%   fMask = pf2_TakizawaRejection(processedData, true);  % strict mode
%
% See also: pf2.qc.takizawa, pf2_SMAR, pf2.data.applyChannelMask

if nargin < 2
    strictCriteria = false;
end

report = pf2.qc.takizawa(fNIR, 'Strict', strictCriteria);
fMask = report.pass;

end
