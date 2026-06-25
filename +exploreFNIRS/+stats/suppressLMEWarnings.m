function cleanupObj = suppressLMEWarnings()
% SUPPRESSLMEWARNINGS Scope-suppress fitlme rank/Hessian warning spam
%
% Turns off the specific MATLAB LinearMixedModel warning identifiers that
% fitlme repeats per channel/term when a design is rank-deficient or has
% more covariance parameters than the data support (the typical symptom of
% a between-subjects confound). Only these identifiers are muted; unrelated
% warnings are left untouched, unlike a blanket warning('off','all'). The
% previous warning state is restored automatically when the returned
% onCleanup object goes out of scope, so suppression is strictly scoped to
% the fit.
%
% This is the single source of truth for the suppressed identifier set,
% shared by exploreFNIRS.stats.fitLME / fitInfoLME and the
% Experiment LME methods, so the list cannot drift between them.
%
% Syntax:
%   cleanupObj = exploreFNIRS.stats.suppressLMEWarnings()
%
% Outputs:
%   cleanupObj - onCleanup handle that restores the prior warning state when
%                it goes out of scope. Keep it alive for the duration of the
%                fit (e.g. assign to a local variable).
%
% Notes:
%   The clean, consolidated explanation of an inestimable design comes from
%   the caller (e.g. Experiment.warnBetweenSubjectConfound); this helper
%   only mutes the raw, repeated fitlme spam.

    ids = {
        'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDHessian_REML'
        'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDHessian_ML'
        'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDCovarianceUnconstrainedScale'
        'stats:classreg:regr:lmeutils:StandardLinearMixedModel:Message_NotSPDCovarianceNaturalScale'
        'stats:classreg:regr:lmeutils:StandardLinearLikeMixedModel:Message_NaNInfInHessian'
        'stats:classreg:regr:lmeutils:StandardLinearLikeMixedModel:Message_TooManyCovarianceParameters'
        'stats:classreg:regr:lmeutils:StandardLinearLikeMixedModel:MustBeFullRank_X'
        'stats:classreg:regr:lmeutils:StandardLinearLikeMixedModel:InValidX_Rank'
    };
    prev = repmat(warning('query', ids{1}), numel(ids), 1);
    for i = 1:numel(ids)
        prev(i) = warning('off', ids{i});
    end
    cleanupObj = onCleanup(@() warning(prev));
end
