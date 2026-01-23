function [qvalues,k,passed]=performFDR(pvalues,pThreshold)
% PERFORMFDR False Discovery Rate (FDR) correction for multiple comparisons
%
% Applies the Benjamini-Hochberg FDR procedure to correct p-values for
% multiple comparisons in fNIRS statistical analysis. This method controls
% the expected proportion of false positives among rejected hypotheses.
%
% Reference:
%   Benjamini, Y. & Hochberg, Y. (1995). Controlling the false discovery
%   rate: a practical and powerful approach to multiple testing.
%   J. Royal Statistical Society B, 57(1), 289-300.
%
% Syntax:
%   [qvalues, k, passed] = performFDR(pvalues)
%   [qvalues, k, passed] = performFDR(pvalues, pThreshold)
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
%                q = p * m / k, where m = total tests, k = rank
%                Values > 1 are capped at 1
%   k          - Critical rank: largest i where p(i) <= q * i / m
%                Used for adjusting q-values
%   passed     - Logical matrix indicating significant results
%                true where qvalues <= pThreshold AND pvalues < 0.05
%
% Algorithm (Benjamini-Hochberg procedure):
%   1. Sort p-values in ascending order
%   2. For each p-value at rank i, calculate threshold: q * i / m
%   3. Find largest k where p(k) <= threshold
%   4. Reject all hypotheses with rank <= k
%   5. Calculate adjusted q-values: q(i) = p(i) * m / k
%
% Notes:
%   - Results are further constrained to raw p < 0.05
%   - This is the standard (non-adaptive) BH procedure
%   - For two-step adaptive FDR, see performFDR_twostep
%   - Assumes tests are independent or positively dependent
%
% Example:
%   % Correct channel p-values for 18-channel analysis
%   pvals = [0.001, 0.012, 0.023, 0.045, 0.067, 0.089, ...
%            0.10, 0.15, 0.20, 0.25, 0.30, 0.35, ...
%            0.40, 0.50, 0.60, 0.70, 0.80, 0.90];
%   [qvals, k, sig] = performFDR(pvals, 0.05);
%   fprintf('Significant channels: %d\n', sum(sig));
%
% See also: performFDR_twostep, exploreFNIRS.fx.autoContrast

if(istable(pvalues))
    pvalues=table2array(pvalues);
end

if(nargin<2)
    pThreshold=0.05;
end

qvalues=nan(size(pvalues));
kVals=nan(size(pvalues(:)));
[pSorted,pIdx]=sort(pvalues(:));

numP=length(pSorted);
kPass=zeros(1,numP);
m=numP;

for i=1:numP
    qThreshold=pThreshold/m*i;
    k=numP-i+1;
    qvalues(pIdx(i))=pvalues(pIdx(i))*m/i;

    if(qvalues(pIdx(i))<=pThreshold&&pvalues(pIdx(i))<=0.05)
        kPass(pIdx(i))=1;
    end
    kVals(pIdx(i))=i;
end

k_ind=find(kPass==1);
if(isempty(k_ind))
    k=1;
else
   k=max(k_ind);
end

qvalues=pvalues*m/k;
qvalues(qvalues>1)=1;
passed=qvalues<=pThreshold;

if(any(kPass(:)))
   k=max(kVals(kPass(:)==1));
   qvalues=pvalues*m/k;
   passed=qvalues<=pThreshold&pvalues<0.05;
end
