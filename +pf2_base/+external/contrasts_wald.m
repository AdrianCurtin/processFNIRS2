function [H0] = contrasts_wald(fitmodel,emm,L)
% Hypothesis testing using Wald t/Z-tests on specified joint coefficients
% (i.e. on input contrasts)
% Copyright 2019, J. Hartman, Cornell University
% % written using Matlab version R2016a 
% 
% INPUTS:
% fitmodel is a GeneralizedLinearMixedModel object
% emm is struct output from emmeans
% L is a nx1 logical vector of contrast coefficients, where emm.table has 
% n rows. Weightings for marginal estimates should already be in emm.DM.
% 
% OUTPUTS:
% pVal is the probability of accepting null hypothesis H0
% H0 is the contrast used for the null hypothesis. It is an mx1 vector,
% where fitmodel has m estimated coefficients.
% 
% example:
% mdl = fitglme(data_table, 'area ~ treatment + hospital +(1|subject)');
% emm = emmeans(mdl, {'treatment'}, 'unbalanced');
% (after inspecting emm.table and selecting your contrast)
% pVal = contrasts_wald(mdl, emm, [1 -1 0 0 0]);


% H0: LB=C, default is C=0
[pVal,F,df1,df2] = coefTest(fitmodel,L * emm.DM); 

% % if you want to see how the native function works
% [pVal,F,df1,df2] = manual_coefTest(fitmodel,L * emm.DM);

H0 = emm;
H0.pVal = pVal;
H0.Wald = sqrt(F);
H0.contrasts = table(fitmodel.Coefficients.Estimate,(L*emm.DM)',...
    'VariableNames',{'Coefficients','Contrast_weights'},'RowNames',fitmodel.CoefficientNames');

end

function [pval,waldStat,df1,df2] = manual_coefTest(mdl,L,varargin)
% input varargin must be in order 1) C (H0:LB=C)

% check some inputs
if nargin==2
    C = zeros(size(L,1),1); % H0: LB=0 is default
else 
    if numel(varargin)==1
        C = varargin{1};
    else
        error('Too many inputs');
    end
end

% unpack model-estimated variables
Sig = mdl.CoefficientCovariance;
betas = mdl.Coefficients.Estimate;

% calc wald statistic
df1 = size(L,1);
df2 = mdl.DFE;
waldStat = (L*betas - C)'  / (L*Sig*L') * (L*betas-C) ./ df1;
pval = fcdf(waldStat,df1,df2,'upper'); 

end