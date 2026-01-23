function [qvalues,k,passed]=performFDR_twostep(pvalues,pThreshold)
% PERFORMFDR_TWOSTEP Two-step adaptive FDR correction for multiple comparisons
%
% Applies the Benjamini-Krieger-Yekutieli two-step adaptive FDR procedure,
% which provides more statistical power than the standard BH procedure when
% many null hypotheses are true (as is typical in fNIRS with many channels).
%
% Reference:
%   Benjamini, Y., Krieger, A.M., & Yekutieli, D. (2006). Adaptive linear
%   step-up procedures that control the false discovery rate.
%   Biometrika, 93(3), 491-507. DOI: 10.1093/biomet/93.3.491
%
% Syntax:
%   [qvalues, k, passed] = performFDR_twostep(pvalues)
%   [qvalues, k, passed] = performFDR_twostep(pvalues, pThreshold)
%
% Inputs:
%   pvalues    - Matrix or vector of uncorrected p-values
%                Can be a numeric array or table (tables are converted)
%                NaN values are ignored in calculations
%   pThreshold - FDR threshold for significance (default: 0.05)
%                Typical values: 0.01, 0.05, 0.10
%
% Outputs:
%   qvalues    - FDR-corrected q-values, same size as pvalues
%                Adjusted for estimated number of true nulls
%                Values > 1 are capped at 1
%   k          - Critical rank from the FDR procedure
%   passed     - Logical matrix indicating significant results
%                true where qvalues <= pThreshold AND pvalues <= 0.05
%
% Algorithm (Two-step adaptive BH procedure):
%   Step 1: Apply standard BH at level q' = q
%           Get initial set of rejections (r0)
%   Step 2: If some (but not all) hypotheses rejected:
%           - Estimate m0 = m - r0 (number of true nulls)
%           - Apply BH at adjusted level q* = q * m / m0
%           This increases power by accounting for true discoveries
%
% Notes:
%   - More powerful than standard BH when proportion of nulls is high
%   - Results are constrained to raw p <= 0.05
%   - Falls back to standard FDR if all or none pass step 1
%   - Assumes tests are independent or positively dependent
%
% Example:
%   % Two-step FDR for 36-channel statistical map
%   pvals = rand(1, 36) .* [ones(1,6)*0.01, ones(1,30)];  % 6 true effects
%   [qvals_std, ~, sig_std] = performFDR(pvals, 0.05);
%   [qvals_2step, ~, sig_2step] = performFDR_twostep(pvals, 0.05);
%   fprintf('Standard BH: %d significant\n', sum(sig_std));
%   fprintf('Two-step BH: %d significant\n', sum(sig_2step));
%
% See also: performFDR, exploreFNIRS.fx.autoContrast

if(istable(pvalues))
    pvalues=table2array(pvalues);
end

if(nargin<2)
    pThreshold=0.05;
end

m=length(pvalues(:));
q_prime=pThreshold;

% Step 1: Standard FDR at level q'
[qvalues,k,passed]=exploreFNIRS.fx.performFDR(pvalues,q_prime);

% Step 2: If some (but not all) passed, adjust threshold
if(sum(passed(:))>0&&sum(~passed(:))>0)
    m=sum(~isnan(pvalues));
    numPassed=sum(passed);
    mo=m-numPassed;
    q_star=q_prime*m/mo;  % Adjusted threshold

    [qvalues,k,passed]=exploreFNIRS.fx.performFDR(pvalues,q_star);
end

% Final adjustments
if(m/k<m)
    qvalues(qvalues>1)=1;
    passed=passed&pvalues<=0.05;
else
   qvalues=pvalues;
   qvalues(qvalues>1)=1;
   passed=qvalues<=pThreshold&pvalues<=0.05;
end
