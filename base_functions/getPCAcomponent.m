function outSig=getPCAcomponent(x,componentNumber)
% Returns matlab's first PCA component
if(nargin<2)
    componentNumber=1;
end


fprintf('Calculating PCA...\n');
[coef,score,latent,tsquared,explained,mu1]=pf2_base.compat.pca(x,'Algorithm','svd');


if(isnan((explained(componentNumber))))
   z=1; 
end

fprintf('Variance in component %i explains %.1f%% variability\n',componentNumber,(explained(componentNumber)));
outSig=coef(:,componentNumber)*mean(abs(score(:,componentNumber)));

end