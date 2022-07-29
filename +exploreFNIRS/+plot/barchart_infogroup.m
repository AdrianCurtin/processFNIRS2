function barchart_infogroup(handles,exSettings,exGby,gbyVars)

global ExFNIRS
curInfoGroup=exSettings.curInfoGroup;

errorFeature=exSettings.plot_bar_err_feature;
plotFeature=exSettings.plot_bar_feature;
plotPoints=exSettings.plot_bar_all;


gbyVars_original=gbyVars;

if(~isempty(curInfoGroup)&&~strcmp(curInfoGroup,'(Time)'))
    [ismem,idx]=ismember(curInfoGroup,gbyVars);
    if(ismem)
        gbyVars(idx)=[];
        useCurInfoGroup=true;
    else
        useCurInfoGroup=false;
    end
else
    useCurInfoGroup=false;
end



numGroups=length(exGby);

if(numGroups==0)
    return;
end

ExFNIRS.figHandles.main=figure(1100);
clf(ExFNIRS.figHandles.main)
cla(ExFNIRS.figHandles.main);
dcm_obj = datacursormode(ExFNIRS.figHandles.main);
set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
% end

num2Plot=numGroups;

curInfoStr=exSettings.curInfoStr;
useInfoAsCategoricalGroup=false;
uCategoricalVals=[];

subplotGby=[];

for g=1:numGroups
    curTable=exGby(g).gbyTables;
    curData=curTable(:,curInfoStr);
    
    curData=table2array(curData);

    subplotGby.gby(g)=exGby(g);
    
    if(isstring(curData)||iscategorical(curData)||ischar(curData)||islogical(curData))
       useInfoAsCategoricalGroup=true;
       if(any(ismissing(curData(:))))
            curData(ismissing(curData))="Missing";
       end
       uCategoricalVals=unique([uCategoricalVals(:);curData(:)]);
    end
end

if(useInfoAsCategoricalGroup)
    if(~isempty(curInfoStr)&&~strcmp(curInfoStr,'(Time)'))
        [ismem,idx]=ismember(curInfoStr,gbyVars);
        if(ismem)
            gbyVars(idx)=[];
        end
    end
end


if(useInfoAsCategoricalGroup&&~isempty(uCategoricalVals))
    lenUCatVals=length(uCategoricalVals);
    numOldGroups=numGroups;
    numNewGroups=numGroups*lenUCatVals;
    newExGby=[];

    if(strcmp(curInfoStr,curInfoGroup)&&~strcmp(plotFeature,'Count'))
        newInfoStr=strcat(curInfoStr,'_');
        useNewInfoStr=true;
    else
        useNewInfoStr=false;
    end
    for g=1:numGroups
        curTable=exGby(g).gbyTables;
        for j=1:lenUCatVals
            newIdx=j+(g-1)*lenUCatVals;
            if(strcmp(plotFeature,'Count'))
                newExGby(newIdx).gbyTables=curTable(curTable{:,curInfoStr}==uCategoricalVals(j),:);
            else
                temp=curTable{:,curInfoStr};
                curTable2=curTable;
                curTable2.categoricalLabelStr(:)=uCategoricalVals(j);
                
                if(useNewInfoStr)
                    curTable2.(newInfoStr)=(temp==uCategoricalVals(j));
                else
                    curTable2(:,curInfoStr)=[];
                    
                    curTable2.(curInfoStr)=(temp==uCategoricalVals(j));
                end
                newExGby(newIdx).gbyTables=curTable2;
            end
            
        end
    end

    if(useNewInfoStr)
        curInfoStr=newInfoStr; % has no effect unless both info string and info group are the same
    end

    exGby=newExGby;
    numGroups=numNewGroups;
    gbyVars{end+1}=curInfoStr;
end


gbyStrs=cell(numGroups,1);
curInfoGby=cell(0);
curInfoStrGby=cell(0);
gbyIdx=nan(numGroups,1);


for g=numGroups:-1:1
    gbyStrs{g}='';
   if(~isempty(exGby(g).gbyTables))
       for i=1:length(gbyVars)
           if(i==length(gbyVars)&&useInfoAsCategoricalGroup&&~strcmp(plotFeature,'Count'))
               gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(exGby(g).gbyTables.categoricalLabelStr(1)));
           else
               gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(exGby(g).gbyTables.(gbyVars{i})(1)));
           end
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(exGby(g).gbyTables.(curInfoGroup)(1));
       end
       if(~isempty(gbyStrs{g}))
        gbyStrs{g}(end)='';
       end
   else
       gbyStrs(g)=[];
       exGby(g)=[];
       curInfoGby(g)=[];
       numGroups=numGroups-1;
   end
   
end


[uGbyStrs,~,uGroupIdx]=unique(cellstr(gbyStrs));
numUgroups=length(uGbyStrs);


if(exSettings.use_gui_color)
    cIndex=exSettings.guiColor(1:numUgroups,:);
else
    cIndex=exSettings.cmap(numUgroups);%linspecer(num2Plot,'qualitative');
end


if(useCurInfoGroup)
    
    [uCurInfoG,a,uCurIdx]=unique(cellstr(curInfoGby));
    numCurInfoG=length(uCurInfoG);
    barChartData=nan(max(uCurIdx),numUgroups,3);
else
    barChartData=nan(1,numUgroups,3);
    uCurInfoG='';
    numCurInfoG=1;
end



gAStrs=cell(numUgroups,1);
gAerrStrs=cell(numUgroups,1);
    
 


if(exSettings.within_sub_avg_mode==3)
    dataH=ExFNIRS.dataHierarchy;
elseif(exSettings.within_sub_avg_mode==2)
    dataH='SubjectID';
else
    dataH=[];
end

barGroup=zeros(numCurInfoG,1);

barChartDataPoints=cell(1,numCurInfoG);

maxDataPoint=[];
minDataPoint=[];





for g=1:numGroups
    curTable=exGby(g).gbyTables;
    curData=curTable(:,curInfoStr);
    
    if(useCurInfoGroup)
        cBarSec=uCurIdx(g); % which section to put the bar in 
        curBarGroup=uGroupIdx(g);
    else
       cBarSec=1;
       curBarGroup=g;
    end
    
    curData=table2array(curData);

    if(isempty(curData))
        continue;
    end
    
    if(isstring(curData)||iscategorical(curData)||ischar(curData))
       %warning('Strings and categories return count');
       [~,~,curData]=unique(curData);
       plotFeature='Count';
       % return;
    end

    if(islogical(curData))
       %warning('boolean/logical values return count ');
       curData=double(curData);
    end
    curData(curData==-9999)=nan;
    
    %switch modes here

    if(strcmp(plotFeature,'Count'))
        curDataH=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean);
        plotPoints=false;
        curHAvg=length(curDataH);
    elseif(strcmp(plotFeature,'Mean'))
        curDataH=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean);
        curHAvg=nanmean(curDataH);
    elseif(strcmp(plotFeature,'Median'))
        curDataH=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmedian);
        curHAvg=nanmedian(curDataH);
    else
        error('Unknown parameter');
        %curHAvg=nanmedian(hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
    end
    
    plottingDataPoints=plotPoints;

    if(exSettings.plot_bar_ga)
          barChartData(cBarSec,curBarGroup,1)=curHAvg;
    else
            barChartData(cBarSec,curBarGroup,1)=nan;
    end

    gAStrs{curBarGroup}=sprintf('%s',uGbyStrs{curBarGroup}); 

    if(plotPoints||strcmp(errorFeature,'Violin'))
        barChartDataPoints(cBarSec,curBarGroup)={curDataH};
    end             


    if(~strcmp(plotFeature,'Count'))

      errMultiply=exSettings.plot_bar_err_mult;
     
      gaFeat=curHAvg;

      numErrFeatures=1;

      if(true)
            minDataPoint=nanmin([minDataPoint,nanmin(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmin))]);
            maxDataPoint=nanmax([maxDataPoint,nanmax(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmax))]);
      end
      
      if(strcmp(errorFeature,'MaxMin'))
          numErrFeatures=2; %min and max)
          curHerr=nanmin(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmin));
            
          barChartData(cBarSec,curBarGroup,2)=curHerr;
          curHerr=nanmax(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmax));
          barChartData(cBarSec,curBarGroup,3)=curHerr;
      elseif(strcmp(errorFeature,'SD'))
          curHerr=nanstd(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
          barChartData(cBarSec,curBarGroup,2)=curHerr*errMultiply;
      elseif(strcmp(errorFeature,'SEM'))
          curHerr=nanstd(pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean));
          curN=length(curDataH);
          curHerr=curHerr/sqrt(curN);
          barChartData(cBarSec,curBarGroup,2)=curHerr*errMultiply;
      elseif(strcmp(errorFeature,'IQR')||strcmp(errorFeature,'IQR-NoOutliers')||strcmp(errorFeature,'Violin'))
          numErrFeatures=5; %min and max) and median
          gaQuant=quantile(curDataH,3);
          iqr=gaQuant(end)-gaQuant(1);

          gaPlotMin=min(curDataH);
          gaPlotMax=max(curDataH);

          if(contains(errorFeature,'IQR'))
              outlierMax=gaQuant(end)+errMultiply*iqr;
              outlierMin=gaQuant(1)-errMultiply*iqr;
    
              iqrPlotErrMin=max([gaPlotMin,outlierMin]);
              iqrPlotErrMax=min([gaPlotMax,outlierMax]);

              barChartData(cBarSec,curBarGroup,2)=iqrPlotErrMin;
              barChartData(cBarSec,curBarGroup,3)=iqrPlotErrMax;

              barChartData(cBarSec,curBarGroup,6)=gaQuant(2);
          else

            numErrFeatures=4;
            barChartData(cBarSec,curBarGroup,2)=gaPlotMin;
            barChartData(cBarSec,curBarGroup,3)=gaPlotMax;
         
          end

          barChartData(cBarSec,curBarGroup,4)=gaQuant(1);
          barChartData(cBarSec,curBarGroup,5)=gaQuant(end);

          

          if(strcmp(errorFeature,'IQR'))
              dataPointsIdx=(curDataH>iqrPlotErrMax|curDataH<iqrPlotErrMin);
              
              barChartDataPoints(cBarSec,curBarGroup)={curDataH(dataPointsIdx)};

              plottingDataPoints=true;
          end
              
      end
      
      gAErrStrs{curBarGroup}=sprintf('%s',gbyStrs{g});
    end
        
    if(~exSettings.plot_bar_err)
        curHerr=0;
  
        gAErrStrs{curBarGroup}='';
    end

end
    
    
    

if(isempty(barChartData))
    warning('All data is missing');
    return
elseif(all(all(isnan(barChartData(:,:,1))))&&~plotPoints)
    warning('All data is missing');
    return
end

if(exSettings.plot_bar_err&&~strcmp(plotFeature,'Count'))
    pf2_base.external.barweb(barChartData(:,:,1),barChartData(:,:,2:1+numErrFeatures),1,uCurInfoG, [], [], [], cIndex,[],gAStrs,[],'hide',barChartDataPoints,strcmp(errorFeature,'Violin'));
    
    if(strcmp(errorFeature,'SEM')||strcmp(errorFeature,'SD'))&&~plotPoints
        ylimLower=min(min(barChartData(:,:,1)))-max(max(barChartData(:,:,2)));
        ylimUpper=max(max(barChartData(:,:,1)))+max(max(barChartData(:,:,2)));
        yrange=ylimUpper-ylimLower;
        ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
        if(errMultiply==1)
            ylabel_with_space(sprintf('%s %s   +/- %s',plotFeature,curInfoStr,errorFeature));
        else
            ylabel_with_space(sprintf('%s %s   +/- %dx %s',plotFeature,curInfoStr,errMultiply,errorFeature));
        end
    elseif(plotPoints||strcmp(errorFeature,'MaxMin')||strcmp(errorFeature,'Violin')||strcmp(errorFeature,'IQR'))
         ylimLower=minDataPoint;
        ylimUpper=maxDataPoint;
        yrange=ylimUpper-ylimLower;
        ylim([ylimLower-0.1*yrange,ylimUpper+0.1*yrange]);
        if(errMultiply==1)
            ylabel_with_space(sprintf('%s %s   +/- %s',plotFeature,curInfoStr,errorFeature));
        else
            ylabel_with_space(sprintf('%s %s   +/- %dx %s',plotFeature,curInfoStr,errMultiply,errorFeature));
        end
    elseif(strcmp(errorFeature,'IQR-NoOutliers'))
        ylimLower=min(min(barChartData(:,:,2)));
        ylimUpper=max(max(barChartData(:,:,3)));
        yrange=ylimUpper-ylimLower;
        ylim([ylimLower-0.1*yrange,ylimUpper+0.1*yrange]);
        if(errMultiply==1)
            ylabel_with_space(sprintf('%s %s   +/- %s',plotFeature,curInfoStr,errorFeature));
        else
            ylabel_with_space(sprintf('%s %s   +/- %dx %s',plotFeature,curInfoStr,errMultiply,errorFeature));
        end
    end
    
    if(useCurInfoGroup)
       title_with_space(sprintf('%s by %s',curInfoStr,curInfoGroup)); 
       xlabel_with_space(curInfoGroup);
    else
       title_with_space(sprintf('%s',curInfoStr)); 

       xLabGby=strjoin(gbyVars,'x');
       xlabel_with_space(xLabGby);
    end
else
    pf2_base.external.barweb(barChartData(:,:,1),[],1,uCurInfoG, [], [], [], cIndex,[],gAStrs,[],'hide',barChartDataPoints);


    if(~plotPoints||strcmp(plotFeature,'Count'))
        ylimLower=min(min(barChartData(:,:,1)));
        ylimUpper=max(max(barChartData(:,:,1)));
    else
        ylimLower=min(min(barChartData(:,:,2)));
        ylimUpper=max(max(barChartData(:,:,3)));
    end
    yrange=ylimUpper-ylimLower;
    ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
    ylabel_with_space(sprintf('%s %s',plotFeature,curInfoStr));
    
    if(useCurInfoGroup)
       title_with_space(sprintf('%s by %s',curInfoStr,curInfoGroup)); 
       xlabel_with_space(curInfoGroup);
    end
end

if(exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2))
    if(~isempty(gAStrs)&&(~isempty(gAStrs{1})||length(gAStrs)>1))
        legend(gAStrs(:),'Location', 'Best');
        legend boxoff;
    end
end


fprintf('\nInfo Table Values\n');
global barChartTable;
barChartTable=table({''},{''},nan,nan,'VariableNames',{'FeatureName','Group',strcat(curInfoStr,'_',plotFeature),strcat(curInfoStr,'_',errorFeature)});
barChartTable(1,:)=[];
for i=1:size(gAStrs,1)
    
    for j=1:length(uCurInfoG)
        idx=(i-1)*(length(uCurInfoG))+j;
        fprintf('%s:%s\tMean %.2f\tError: %.2f\n',gAStrs{i},uCurInfoG{j},barChartData(j,i,1),barChartData(j,i,2));
        barChartTable(idx,:)={gAStrs{i},uCurInfoG{j},barChartData(j,i,1),barChartData(j,i,2)};
    end
    

end



fprintf('\n');
        
hold off;
   
if(exSettings.LME_enable)
    x=gbyVars_original;
    curLMEGbyString='';

    useAllInteractions=exSettings.LME_all_interactions;

    %mdlPrtString='Time';

    if(useAllInteractions)
        
        for i=1:length(x)
            curLMEGbyString=sprintf('%s*%s',curLMEGbyString,x{i});
        end
    else
        for i=1:length(x)
             curLMEGbyString=sprintf('%s+%s',curLMEGbyString,x{i});
        end
    end
    
    if(~isempty(curLMEGbyString))
        curLMEGbyString(1)=[];
    end
    
    dummyCodeStr='reference';
    if(exSettings.LME_use_customStr&&~isempty(exSettings.LME_customStr))
        lmeString=sprintf('%s~%s',exSettings.curInfoStr,exSettings.LME_customStr);
        if(contains(lmeString,'-1+')||contains(lmeString,'~-1'))
           dummyCodeStr='full';
        end
    elseif(exSettings.LME_use_intercept)
        lmeString=sprintf('%s~%s+(%s)',exSettings.curInfoStr,curLMEGbyString,exSettings.LME_randomFxStr);
        
    else
       lmeString=sprintf('%s~-1+%s+(%s)',exSettings.curInfoStr,curLMEGbyString,exSettings.LME_randomFxStr);
       dummyCodeStr='full';
    end
    

    try
        rng(2019);
        curInfoChartLME=fitlme(ExFNIRS.selectedTable,lmeString,'FitMethod','REML','CheckHessian',true,'DummyVarCoding',dummyCodeStr);
        
        nullMdlstring=sprintf('%s~1+(1|SubjectID)',exSettings.curInfoStr);
        curInfoChartLME_ML=fitlme(ExFNIRS.selectedTable,lmeString,'FitMethod','ML','DummyVarCoding',dummyCodeStr);
        nullInfoChartLME=fitlme(ExFNIRS.selectedTable,nullMdlstring,'FitMethod','ML','DummyVarCoding',dummyCodeStr);
        
%         curInfoChartLME_emm= pf2_base.external.emmeans(curInfoChartLME, {'orig'}, 'effects');
%         h = emmip(curInfoChartLME_emm,'orig');

        fprintf('Info Chart LME model: %s',exSettings.curInfoStr);
        if(useAllInteractions)
            fprintf(' - All Interactions\n');
        else
            fprintf(' - No Interactions\n');
        end
        ExFNIRS.curInfoChartModel=curInfoChartLME;
        
        disp(curInfoChartLME);
        displayLME(curInfoChartLME);
        disp(compare(nullInfoChartLME,curInfoChartLME_ML));
        
        %disp(curInfoChartLME.anova);
        mdlTest=eye(length(curInfoChartLME.Coefficients.Name));
        if(exSettings.LME_use_intercept)
            mdlTest=mdlTest(2:end,:);
        end
        
        [curMdlFit{1:4}]=coefTest(curInfoChartLME,mdlTest,zeros(size(mdlTest,1),1),'DFMethod','satterthwaite');
            fprintf('\nModel Fit (H0: All F=0): p=%.5f\tF=%.2f\tdf1=%i\tdf2=%i\n\n',curMdlFit{1},curMdlFit{2},curMdlFit{3},curMdlFit{4});
            tic
            curChartContrast=exploreFNIRS.fx.autoContrast(curInfoChartLME);
            toc
            disp(curChartContrast);
        ExFNIRS.curInfoChartContrast=curChartContrast;
    catch ME
        warning('Could not generate model for info figure %s',exSettings.curInfoStr);
        warning(ME.message);
    end
end
end




function possibleStr=num2strOrNot(possibleStr)
if(iscell(possibleStr))
    for i=1:length(possibleStr)
        if(isempty(possibleStr{i}))
            possibleStr{i}='';
        elseif(isstring(possibleStr{i}))
            if(ismissing(possibleStr{i}))
                possibleStr{i}='Missing';
            else
                possibleStr{i}=sprintf('%s',possibleStr{i})
            end
        elseif(~ischar(possibleStr{i})&&isnumeric(possibleStr{i}))
            possibleStr{i}=num2str(possibleStr{i}); 
        elseif(islogical(possibleStr{i})&&possibleStr{i})
            possibleStr{i}='true';
        elseif(islogical(possibleStr{i})&&~possibleStr{i})
            possibleStr{i}='false';
        end
    end
elseif(~ischar(possibleStr)&&isnumeric(possibleStr))
    possibleStr=num2str(possibleStr);
elseif(isstring(possibleStr))
    if(ismissing(possibleStr))
        possibleStr='Missing';
    else
        possibleStr=sprintf('%s',possibleStr);
    end
elseif(islogical(possibleStr)&&possibleStr)
    possibleStr='true';
elseif(islogical(possibleStr)&&~possibleStr)
    possibleStr='false';
end

    
    if(isempty(possibleStr))
        possibleStr='';
    end

if(isempty(possibleStr))
    possibleStr='';
end


end


function h=xlabel_with_space(figHandle,labelstring)
if(nargin<2)
    labelstring=figHandle;
    figHandle=gca;
end

if(iscell(labelstring))
    labelstring=labelstring{1};
end

if(~isempty(labelstring))
    labelstring(labelstring=='_')=' ';
end
h=xlabel(figHandle,labelstring);

end

function h=ylabel_with_space(figHandle,labelstring)
if(nargin<2)
    labelstring=figHandle;
    figHandle=gca;
end

if(iscell(labelstring))
    labelstring=labelstring{1};
end

if(~isempty(labelstring))
    labelstring(labelstring=='_')=' ';
end
h=ylabel(figHandle,labelstring);

end

function h=title_with_space(figHandle,labelstring)
if(nargin<2)
    labelstring=figHandle;
    figHandle=gca;
end


if(~isempty(labelstring))
    labelstring(labelstring=='_')=' ';
end
h=title(figHandle,labelstring);

end

function h=suptitle_with_space(axHandle,labelstring)

if(nargin<2)
    labelstring=axHandle;

    if(~isempty(labelstring))
        labelstring(labelstring=='_')=' ';
    end
    h=pf2_base.external.suptitle(labelstring);
else
    if(~isempty(labelstring))
        labelstring(labelstring=='_')=' ';
    end
    h=pf2_base.external.suptitle(axHandle,labelstring);
end


end

function addDebugAnnotation(figHandle,optionalstring)
global ExFNIRS
exSettings=ExFNIRS.settings;
curTime = datetime(now,'ConvertFrom','datenum');
debugString=sprintf('%s\n%s (%s)\n%s',ExFNIRS.curMethodName,ExFNIRS.statusGroupByStr,exSettings.within_sub_avg_mode_label,curTime);
if(nargin>1)
    debugString=sprintf('%s\n%s',debugString,optionalstring);
end

debugString(debugString==('_'))='-';
th=annotation(figHandle,'textbox',[0 0 0.1 1],'String',debugString,'FitBoxToText','on');
th.FontSize = 6;
th.LineStyle='none';
th.HorizontalAlignment='left';
th.VerticalAlignment='bottom';
curPos=th.Position;
end

function displayLME(lme_mdl)
%disp(lme_mdl.Forumla);
fprintf(2,'\nUse These DFs\n');
[~,~,stats]=fixedEffects(lme_mdl,'DFMethod','satterthwaite');
disp(stats);
%disp(lme_mdl.RandomEffects);
% [~,~,stats]=randomEffects(lme_mdl,'DFMethod','satterthwaite');
% disp(stats);
disp(anova(lme_mdl,'DFMethod','satterthwaite'));
end