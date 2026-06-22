function tf = hasStatsToolbox()
%HASSTATSTOOLBOX Test for an available Statistics and Machine Learning Toolbox.
%
%   Capability check used to gate features that genuinely require the
%   Statistics and Machine Learning Toolbox (linear mixed-effects models,
%   ANOVA on LinearMixedModel, k-means clustering). Single-subject
%   processing, QC, coupling, and plotting no longer require the toolbox
%   because pf2_base.compat.* provides base-MATLAB replacements; use this
%   only for the irreducible toolbox-only paths.
%
%   Inputs:
%     (none)
%
%   Outputs:
%     tf - Logical scalar. TRUE when a Statistics Toolbox license can be
%          checked out AND the marquee function FITLME is on the path.
%
%   Notes:
%     Both conditions are required: a license may exist without the files
%     installed, and vice versa. The result is NOT cached: a user who
%     installs the toolbox mid-session (then runs `rehash toolboxcache`)
%     must see the new capability immediately, and the license/exist probes
%     are cheap enough to run per gated call.
%
%   Example:
%     if ~pf2_base.hasStatsToolbox()
%         error('pf2:needsStats', ...
%             ['Group LME/ANOVA requires the Statistics and Machine ' ...
%              'Learning Toolbox. Single-subject processing works without it.']);
%     end
%
%   See also: LICENSE, pf2_base.compat.corr

tf = license('test', 'Statistics_Toolbox') == 1 && exist('fitlme', 'file') == 2;

end
