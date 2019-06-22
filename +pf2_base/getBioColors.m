function colorsTable=getBioColors()
% pf2_base.getBioColors
% Returns colors used to plot biomarkers

colorsTable=table([204/256,37/256,41/256],[57/256,106/256,177/256],[0.2,0.2,0.2],[107/256,76/256,154/256],[0,0.7,0.7],'VariableNames',{'HbO','HbR','HbDiff','HbTotal','CBSI'});
