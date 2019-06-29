# Estimated-marginal-means
Estimated marginal (predicted) means from generalized linear mixed effect models in Matlab.
Requires the Stats toolbox.

The intent of these Matlab functions is to replicate (at least partially) the incredibly useful '<a href="https://cran.r-project.org/web/packages/emmeans/">emmeans</a>' package in R. For now, only output from fitglme can be used.

For hypothesis testing, the main difference between using these functions and the native support (e.g. coefTest) is that contrast_wald can take contrasts of the EMMs as input (rather than contrasts defined by the coefficients). Using these EMM contrasts is easier for models with many parameters and also for models with categorical predictors where testing the reference level can be confusing.
