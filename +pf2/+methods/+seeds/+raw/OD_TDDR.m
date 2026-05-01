function p = OD_TDDR()
% OD_TDDR Default raw method: Intensity2OD followed by TDDR motion correction.
%
% Reference:
%   Fishburn, F. A. et al. (2019). Temporal Derivative Distribution Repair
%   (TDDR): A motion correction method for fNIRS. NeuroImage, 184, 171-179.
%   DOI: 10.1016/j.neuroimage.2018.09.025
%
% Returns:
%   p - pf2_base.RawPipeline ready for save() or run()

p = pf2_base.RawPipeline('OD_TDDR', ...
    'Description', 'Log transform then TDDR motion correction');
p = p.add('pf2_Intensity2OD');
p = p.add('pf2_MotionCorrectTDDR');
end
