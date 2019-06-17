function outSig=getPCAcomponent(x,componentNumber)
if(nargin<2)
    componentNumber=1;
end


fprintf('Calculating PCA...\n');
[coef,score,latent,tsquared,explained,mu1]=pca(x,'Algorithm','svd');


fprintf('Variance in component %i explains %.1f%% variability\n',componentNumber,(explained(componentNumber)));
outSig=coef(:,componentNumber)*sum(abs(score(:,componentNumber)));

end