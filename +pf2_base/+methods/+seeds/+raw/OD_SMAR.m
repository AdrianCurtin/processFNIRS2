function p = OD_SMAR()
% OD_SMAR Factory for the "OD_SMAR" raw method (SMAR motion correction)
%
% Builds the shipped "OD_SMAR" raw (Stage 1) processing method as a RawPipeline:
% 0.1 Hz low-pass filter on raw light intensity, then Sliding-window Motion
% Artifact Rejection (SMAR), which rejects samples whose windowed coefficient
% of variation exceeds a threshold, then log transform to optical density.
% This is the order used in published SMAR work. SMAR runs on intensity
% because its CV criterion is only meaningful on a positive signal, and the
% low-pass runs first because filtering after SMAR would spread its NaN gaps.
% Used by pf2_initialize and pf2.methods.resetDefaults to (re-)seed the
% default raw methods. Returns a pipeline object you can save() to register
% or run() directly.
%
% References:
%   Ayaz, H., Izzetoglu, M., Shewokis, P. A., & Onaral, B. (2010).
%   Sliding-window motion artifact rejection for Functional Near-Infrared
%   Spectroscopy. 2010 Annual International Conference of the IEEE
%   Engineering in Medicine and Biology, 6567-6570.
%   DOI: 10.1109/iembs.2010.5627113
%
%   Mark, J. A., Curtin, A., Kraft, A. E., Ziegler, M. D., & Ayaz, H. (2024).
%   Mental workload assessment by monitoring brain, heart, and eye with six
%   biomedical modalities during six cognitive tasks. Frontiers in
%   Neuroergonomics, 5. DOI: 10.3389/fnrgo.2024.1345507
%
% Syntax:
%   p = pf2_base.methods.seeds.raw.OD_SMAR()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.RawPipeline named 'OD_SMAR', ready for save() or run()
%
% Example:
%   p = pf2_base.methods.seeds.raw.OD_SMAR();
%   p.save();
%
% See also: pf2_base.methods.seeds.raw.OD_TDDR, pf2.methods.resetDefaults,
%           pf2_base.RawPipeline, pf2_SMAR, pf2_lpf

p = pf2_base.RawPipeline('OD_SMAR', ...
    'Description', '0.1 Hz low-pass and SMAR (sliding-window motion artifact rejection) on raw intensity, then log transform');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
p = p.add('pf2_SMAR');
p = p.add('pf2_Intensity2OD');
end
