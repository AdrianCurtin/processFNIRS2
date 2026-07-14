function p = takizawa_hard()
% TAKIZAWA_HARD Factory for the "takizawa_hard" oxy method (strict rejection)
%
% Builds the shipped "takizawa_hard" oxy (Stage 3) processing method as an
% OxyPipeline: automatic channel rejection using the Takizawa criteria with the
% strict rule combination. Rejected channels are marked in the data's fchMask
% rather than having their hemoglobin values transformed. Used by
% pf2_initialize and pf2.methods.resetDefaults to (re-)seed the default oxy
% methods. Returns a pipeline object you can save() to register or run()
% directly.
%
% The strict/lenient switch is the pf2_TakizawaRejection strictCriteria flag:
% strict (strictCriteria = 1) combines the rejection rules with OR, so a channel
% is dropped when it fails any rule; the lenient variant (takizawa_easy) uses
% AND.
%
% Syntax:
%   p = pf2.methods.seeds.oxy.takizawa_hard()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.OxyPipeline named 'takizawa_hard', ready for save() or run()
%
% Example:
%   % Build and register the takizawa_hard oxy method
%   p = pf2.methods.seeds.oxy.takizawa_hard();
%   p.save();
%
% References:
%   Takizawa, R., Kasai, K., Kawakubo, Y., Marumo, K., Kawasaki, S.,
%   Yamasue, H., & Fukuda, M. (2008). Reduced frontopolar activation during
%   verbal fluency task in schizophrenia: A multi-channel near-infrared
%   spectroscopy study. Schizophrenia Research, 99(1-3), 250-262.
%   DOI: 10.1016/j.schres.2007.10.025
%
% See also: pf2.methods.seeds.oxy.takizawa_easy, pf2.methods.seeds.oxy.LPF,
%           pf2.methods.resetDefaults, pf2_TakizawaRejection, pf2_base.OxyPipeline

p = pf2_base.OxyPipeline('takizawa_hard', ...
    'Description', 'Takizawa automatic channel rejection, strict criteria (Takizawa et al. 2008)');
p = p.add('pf2_TakizawaRejection', 'strictCriteria', 1);
end
