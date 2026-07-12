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
%                NaN values are excluded from the test count
%   pThreshold - FDR threshold for significance (default: 0.05)
%                Typical values: 0.01, 0.05, 0.10
%
% Outputs:
%   qvalues    - FDR-corrected q-values, same size as pvalues
%                q_i = min_{j>=i}( p_(j) * m / j ), m = number of valid tests
%                Values > 1 are capped at 1
%   k          - Critical rank: largest i where p(i) <= pThreshold * i / m
%                Minimum value of 1
%   passed     - Logical matrix indicating significant results
%                true where qvalues <= pThreshold
%
% Algorithm (Benjamini-Hochberg procedure):
%   1. Sort valid (non-NaN) p-values in ascending order
%   2. For each p-value at rank i, calculate threshold: q * i / m
%   3. Find largest k where p(k) <= threshold
%   4. Compute candidate q-values q_i = p_(i) * m / i
%   5. Enforce monotonicity via running min from the tail:
%      q_i = min_{j>=i}( p_(j) * m / j )
%
% Notes:
%   - NaN p-values are excluded from the test count and remain NaN in output
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

if istable(pvalues)
    pvalues=table2array(pvalues);
end

if nargin<2
    pThreshold=0.05;
end

% Count valid (non-NaN) tests
m=sum(~isnan(pvalues(:)));

if m==0
    qvalues=nan(size(pvalues));
    k=1;
    passed=false(size(pvalues));
    return;
end

% Sort valid p-values
validIdx=find(~isnan(pvalues(:)));
pVec=pvalues(validIdx);
[pSorted,sortOrd]=sort(pVec(:));

% Find critical k: largest rank i where p(i) <= pThreshold * i / m
k=0;
for i=1:m
    if pSorted(i)<=pThreshold*i/m
        k=i;
    end
end
k=max(k,1);

% Standard BH adjusted p-values: q_i = min_{j>=i}( p_(j) * m / j )
qSorted=pSorted.*m./(1:m)';
for i=(m-1):-1:1
    qSorted(i)=min(qSorted(i),qSorted(i+1));
end
qSorted(qSorted>1)=1;

% Unsort back to original positions
qVec=zeros(m,1);
qVec(sortOrd)=qSorted;
qvalues=nan(size(pvalues));
qvalues(validIdx)=qVec;
passed=qvalues<=pThreshold;
