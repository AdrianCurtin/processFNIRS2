function p = takizawa_easy()
% TAKIZAWA_EASY Factory for the "takizawa_easy" oxy method (lenient rejection)
%
% Builds the shipped "takizawa_easy" oxy (Stage 3) processing method as an
% OxyPipeline: automatic channel rejection using the Takizawa criteria with the
% lenient (non-strict) rule combination. Rejected channels are marked in the
% data's fchMask rather than having their hemoglobin values transformed. Used by
% pf2_initialize and pf2.methods.resetDefaults to (re-)seed the default oxy
% methods. Returns a pipeline object you can save() to register or run()
% directly.
%
% The strict/lenient switch is the pf2_TakizawaRejection strictCriteria flag:
% lenient (strictCriteria = 0) combines the rejection rules with AND, so a
% channel is dropped only when it fails every rule; the strict variant
% (takizawa_hard) uses OR.
%
% Syntax:
%   p = pf2_base.methods.seeds.oxy.takizawa_easy()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.OxyPipeline named 'takizawa_easy', ready for save() or run()
%
% Example:
%   % Build and register the takizawa_easy oxy method
%   p = pf2_base.methods.seeds.oxy.takizawa_easy();
%   p.save();
%
% References:
%   Takizawa, R., Kasai, K., Kawakubo, Y., Marumo, K., Kawasaki, S.,
%   Yamasue, H., & Fukuda, M. (2008). Reduced frontopolar activation during
%   verbal fluency task in schizophrenia: A multi-channel near-infrared
%   spectroscopy study. Schizophrenia Research, 99(1-3), 250-262.
%   DOI: 10.1016/j.schres.2007.10.025
%
% See also: pf2_base.methods.seeds.oxy.takizawa_hard, pf2_base.methods.seeds.oxy.LPF,
%           pf2.methods.resetDefaults, pf2_TakizawaRejection, pf2_base.OxyPipeline

p = pf2_base.OxyPipeline('takizawa_easy', ...
    'Description', 'Takizawa automatic channel rejection, lenient criteria (Takizawa et al. 2008)');
p = p.add('pf2_TakizawaRejection', 'strictCriteria', 0);
end
