function barchart(handles,exSettings,exGby,gbyVars, showBarChart,showTopo)

curInfoGroup=exSettings.curInfoGroup;

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

biomStrs=get(handles.listbox_biomarker,'String');
selBioM=get(handles.listbox_biomarker,'Value');
selectedBioM=biomStrs(selBioM);
numBioM=length(selBioM);

optStrs=get(handles.listbox_optode,'String');
selOpt=get(handles.listbox_optode,'Value');
selectedOptStr=optStrs(selOpt',:);
numOpt=length(selOpt);



if(strcmp(exSettings.ChannelMode,'Aux'))
    if(length(selectedBioM)>1)
        error('Not supported yet!')
    end
    auxTable=get(handles.listbox_optode,'UserData');
    selectedOpt=nan(length(selOpt));
    for sI=1:length(selOpt)
        selectedOpt(sI)=auxTable{selectedBioM,selectedOptStr{sI}};
    end
    
else
    selectedOpt=selOpt;
end

if(numOpt==0||numGroups==0||numBioM==0)
    return;
end


if(exSettings.ylim_fixed)
    exSettings.ylim_fixed_min=inf;
    exSettings.ylim_fixed_max=-inf;
end

if(showBarChart)
    multiPlot=false;
    global ExFNIRS
    ExFNIRS.figHandles.main=figure(1000);
    clf(ExFNIRS.figHandles.main);
    cla(ExFNIRS.figHandles.main);
    addDebugAnnotation(ExFNIRS.figHandles.main);
    dcm_obj = datacursormode(ExFNIRS.figHandles.main);
    set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
    % end
end

gbyStrs=cell(numGroups,1);
curInfoGby=cell(0);

for g=1:numGroups
    gbyStrs{g}='';
   if(~isempty(exGby(g).gbyTables))
       for i=1:length(gbyVars)
           gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(exGby(g).gbyTables.(gbyVars{i})(1)));
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(exGby(g).gbyTables.(curInfoGroup)(1));
       end
   end 
   if(~isempty(gbyStrs{g}))
        gbyStrs{g}(end)='';
   end
end

[numUgroups]=length(unique(cellstr(gbyStrs)));

if(numUgroups==1&&~showTopo)
    num2Plot=numBioM;
    plotGroupByBioM=true;
    cCell=table2cell(pf2_base.getBioColors());
    for i=1:length(cCell)
        cIndex(i,:)=cCell{i};
    end
    cIndex=cIndex(selBioM,:);
else
    num2Plot=numGroups;
    plotGroupByBioM=false;
    if(exSettings.use_gui_color)
        cIndex=exSettings.guiColor(1:numUgroups,:);
    else
        cIndex=exSettings.cmap(numUgroups);%linspecer(num2Plot,'qualitative');
    end
end



barChartTimes=[];
barChartEndTimes=[];
for i=1:numGroups
    if(isempty(exGby(i).gbyGrandBar))
        curGrandTime=[];
        curGrandEndTime=[];
    else
        curGrandTime=exGby(i).gbyGrandBar.segmentTimes(:,1);
        curGrandEndTime=exGby(i).gbyGrandBar.segmentTimes(:,3);
    end
    barChartTimes=[barChartTimes;curGrandTime];
    barChartEndTimes=[barChartEndTimes;curGrandEndTime];
end
barChartTimes=sort(unique(round(barChartTimes)));
barChartEndTimes=sort(unique(round(barChartEndTimes)));

[uCurInfoG,firstCurIdx,uCurIdx]=unique(cellstr(curInfoGby));
numCurInfoG=max(uCurIdx);
uCurGIdxCount=nan(size(uCurIdx));
for i =1:numCurInfoG
    uCurGIdxCount(uCurIdx==i)=1:sum(uCurIdx==i);
end

if(~useCurInfoGroup||isnan(numCurInfoG))
   useCurInfoGroup=false;
   numCurInfoG=1; 
   uCurInfoG='';
end

validBarChartTimesIdx=barChartEndTimes<=exSettings.plot_end&barChartTimes>=exSettings.plot_start;
barChartTimes=barChartTimes(validBarChartTimesIdx);
barChartEndTimes=barChartEndTimes(validBarChartTimesIdx);
numChartTimes=length(barChartTimes);

for i=1:length(barChartTimes)
   barChartTimeStrings{i}=sprintf('%i-%i',barChartTimes(i),barChartEndTimes(i)); 
end

errorFeature=exSettings.plot_bar_err_feature;
plotFeature=exSettings.plot_bar_feature;
plotPoints=exSettings.plot_bar_all;


if(strcmp(plotFeature,'Count')&&exSettings.plot_bar_ga)
  plotFeature='N';
  plotCount=true;
else
    plotCount=false;
end

if(plotGroupByBioM)
    subplotHandles=cell(numOpt,1);
else
    subplotHandles=cell(numOpt*numBioM,1);
end

subplotGby=subplotHandles;
numCharts=length(subplotHandles);

% barChartData 1 x n Groups of cells
%       i,j,k
%       i: chartTime/InfoGroup
%       j: Biomarkers or uGroups
%       k: 1: summary stat, ie: mean/median
%          2: lower error bar  ex: std or min
%          3: upper error bar, ex: std/sem or max
%          4: lower bound override (force 0:summary stat)
%           5: upper bound override (can use both to plot IQR instead)

barChartDataPoints=cell(1,numUgroups);

for chIdx=1:numOpt
    ch=selectedOpt(chIdx);
    %legendGFXhandles{1}=[];
    %legendGFXstrs{1}=cell(0);
    if(plotGroupByBioM)
        barChartData{1}=nan(numCurInfoG,numBioM,5);
        barChartDataPoints{1}=cell(numCurInfoG,numBioM);
        num2Plot=numBioM;
    elseif(numUgroups>1)
        for i=1:numBioM
            barChartData{i}=nan(numChartTimes,numUgroups,5);
            barChartDataPoints{i}=cell(numChartTimes,numUgroups);
        end
        num2Plot=numUgroups;
    else
        barChartData{1}=nan(numCurInfoG,1,5);
        barChartDataPoints{1}=cell(numCurInfoG,1);
    end

    
    
    chartGby=cell(size(subplotHandles));
    
    %barChartTimes=times;
    
    gAStrs=cell(num2Plot,1);
    gAerrStrs=cell(num2Plot,1);
    
    for b=1:numBioM
        bioM=selectedBioM(b);
        if(iscell(bioM))
            bioM=bioM{1};
        end
        
        
        if(numUgroups>1)
            curChart=b;
        else
            curChart=1;
        end
        
        for g=1:numGroups
            
            curFNIRS=exGby(g).gbyFNIRS_blk;
            curGrand=exGby(g).gbyGrandBar;
            

            if(isfield(chartGby{curChart},'gby'))
                chartGby{curChart}.gby(end+1)=exGby(g);
            else
                chartGby{curChart}.gby(1)=exGby(g);
                chartGby{curChart}.curCh=ch;
                if(plotGroupByBioM)
                    chartGby{curChart}.curBioM=selectedBioM;
                else
                    chartGby{curChart}.curBioM=selectedBioM(b);
                end
            end
            
            
            if(useCurInfoGroup)
                curGroupInfoIdx=uCurIdx(g);
                curGroupIdxOffset=(curGroupInfoIdx-1)*numChartTimes;
                curUgroupIdx=uCurGIdxCount(g);
            else
                curGroupInfoIdx=g;
                curGroupIdxOffset=0;
                curUgroupIdx=g;
            end
            
            if(isempty(curGrand))
                if(plotGroupByBioM)
                    barChartData{curChart}(:,b,1:3)=nan;
                    
                else
                    barChartData{curChart}(:,curUgroupIdx,1:3)=nan;
                end
                
               if(numUgroups>1||numBioM==1)
                    gAStrs{curUgroupIdx,curChart}=sprintf('%s',gbyStrs{g}); 
               elseif(numBioM>1&&~multiPlot)
                    gAStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
               end
                
               continue; 
            end
            
            %if(exSettings.plot_bar_ga)
                  [timeIdx,timeIdxRev]=ismember(round(curGrand.time),barChartTimes);
                  timeIdxRev=timeIdxRev(timeIdxRev>0);
                  
                  switch(exSettings.ChannelMode)
                      case 'fNIR'
                          data2plot=curGrand.(bioM);
                      case 'ROI'
                          if(~pf2_base.isnestedfield(curGrand,'ROI.HbO.data'))
                              error('ROI data must be calculated using a build ROI step');
                          end
                          
                          data2plot=curGrand.ROI.(bioM);
                      case 'Aux'
                          data2plot=curGrand.Aux.(bioM);
                  end
   
                  plottingDataPoints=plotPoints;
                  
                  if(plotGroupByBioM)
                      if(exSettings.plot_bar_ga)
                        barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,1)=data2plot.(plotFeature)(timeIdx,ch);
                      else
                        barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,1)=nan(size(data2plot.(plotFeature)(timeIdx,ch)));
                      end
                      %barChartDataPoints{curChart}{timeIdxRev+curGroupIdxOffset,b}=[];
                  else
                      if(exSettings.plot_bar_ga)
                            barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,1)=data2plot.(plotFeature)(timeIdx,ch);
                      else
                            barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,1)=nan(size(data2plot.(plotFeature)(timeIdx,ch)));
                      end
                      
                      %barChartDataPoints{curChart}{timeIdxRev+curGroupIdxOffset,curUgroupIdx}=[];
                  end

                  if(plotGroupByBioM&&(plotPoints||strcmp(errorFeature,'Violin')))
                      barChartDataPoints{curChart}(timeIdxRev+curGroupIdxOffset,b)={data2plot.data(timeIdx,ch,:)};
                  elseif(plotPoints||strcmp(errorFeature,'Violin'))
                      barChartDataPoints{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx)={data2plot.data(timeIdx,ch,:)};
                  end

                  if(numUgroups>1||numBioM==1)
                       gAStrs{curUgroupIdx,curChart}=sprintf('%s',gbyStrs{g}); 
                  elseif(numBioM>1)
                       gAStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
                  end
            %else

            %end
            
            if(exSettings.plot_bar_err&&~plotCount)
                  
                  errMultiply=exSettings.plot_bar_err_mult;
                  [timeIdx,timeIdxRev]=ismember(round(curGrand.time),barChartTimes);
                  timeIdxRev=timeIdxRev(timeIdxRev>0);
                  ga2plot=data2plot;%curGrand.(bioM);
                  numErrFeatures=1;
                  if(strcmp(errorFeature,'MaxMin'))
                      numErrFeatures=2; %min and max)

                      if(plotGroupByBioM)
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=ga2plot.Min(timeIdx,ch);
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,3)=ga2plot.Max(timeIdx,ch);
                          
                      else
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,2)=ga2plot.Min(timeIdx,ch);
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,3)=ga2plot.Max(timeIdx,ch);
                      end
                  

                  elseif(strcmp(errorFeature,'IQR')||strcmp(errorFeature,'IQR-NoOutliers')||strcmp(errorFeature,'Violin'))
                      numErrFeatures=5; %min and max) and median
                      gaQuant=quantile(ga2plot.data(timeIdx,ch,:),3);
                      iqr=gaQuant(end)-gaQuant(1);

                      gaPlotMin=min(ga2plot.Min(timeIdx,ch));
                      gaPlotMax=max(ga2plot.Max(timeIdx,ch));

                      if(contains(errorFeature,'IQR'))

                      

                          outlierMax=gaQuant(end)+errMultiply*iqr;
                          outlierMin=gaQuant(1)-errMultiply*iqr;
    
                          iqrPlotErrMin=max([gaPlotMin,outlierMin]);
                          iqrPlotErrMax=min([gaPlotMax,outlierMax]);

                          dataPlotMin_barchart=iqrPlotErrMin;
                          dataPlotMax_barchart=iqrPlotErrMax;

                      else
                          dataPlotMin_barchart=gaPlotMin;
                          dataPlotMax_barchart=gaPlotMax;
                      end
                      

                      if(plotGroupByBioM)
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=dataPlotMin_barchart;
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,3)=dataPlotMax_barchart;

                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,4)=gaQuant(1);
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,5)=gaQuant(end);

                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,6)=gaQuant(2);

                          if(strcmp(errorFeature,'IQR'))
                              dataPointsIdx=(ga2plot.data(timeIdx,ch,:)>iqrPlotErrMax|ga2plot.data(timeIdx,ch,:)<iqrPlotErrMin);
                              
                              barChartDataPoints{curChart}(timeIdxRev+curGroupIdxOffset,b)={ga2plot.data(timeIdx,ch,dataPointsIdx)};

                              plottingDataPoints=true;
                          end
                      else
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,2)=dataPlotMin_barchart;
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,3)=dataPlotMax_barchart;

                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,4)=gaQuant(1);
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,5)=gaQuant(end);

                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,6)=gaQuant(2);

                          if(strcmp(errorFeature,'IQR'))
                            dataPointsIdx=(ga2plot.data(timeIdx,ch,:)>iqrPlotErrMax|ga2plot.data(timeIdx,ch,:)<iqrPlotErrMin);
                          
                            barChartDataPoints{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx)={ga2plot.data(timeIdx,ch,dataPointsIdx)};

                            plottingDataPoints=true;
                          end
                      end
                  
                  else
                      if(plotGroupByBioM)
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=ga2plot.(errorFeature)(timeIdx,ch)*errMultiply;
                      else
                          barChartData{curChart}(timeIdxRev+curGroupIdxOffset,curUgroupIdx,2)=ga2plot.(errorFeature)(timeIdx,ch)*errMultiply;
                      end
                  end
                  if(numUgroups>1||numBioM==1)
                       gAErrStrs{curGroupInfoIdx,curChart}=sprintf('%s',gbyStrs{curGroupInfoIdx}); 
                  elseif(numBioM>1&&~multiPlot)
                       gAErrStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
                  end
            else
                    barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,2)=0;
                    barChartData{curChart}(timeIdxRev+curGroupIdxOffset,b,3)=0;
                  if(numUgroups>1||numBioM==1)
                       gAErrStrs{curGroupInfoIdx,curChart}=''; 
                  elseif(numBioM>1&&~multiPlot)
                       gAErrStrs{b,curChart}=''; 
                  end 
            end
          end
    
    end
    
    
    
    for curChart=1:length(barChartData)
        if(isempty(barChartData{curChart}))
            warning('All data is missing');
            continue;
        elseif(exSettings.plot_bar_ga==1&&all(all(isnan(barChartData{curChart}(:,:,1)))))
            warning('All data is missing');
            continue;
        end
        if(~plotGroupByBioM)
                lastPlotNum=numBioM*numOpt;
                if(numOpt>1)
                    curSubplotIdx=chIdx+(numOpt*(curChart-1));
                    
                    numX=numBioM;
                    numY=numOpt;
                    subplotGby{curSubplotIdx}=chartGby{curChart};
                else
                    curSubplotIdx=chIdx+(numOpt*(curChart-1));
                    numX=1;
                    numY=numBioM;
                    subplotGby{curSubplotIdx}=chartGby{curChart};
                end
        else
                lastPlotNum=numOpt;
                curSubplotIdx=chIdx;
                numX=1;
                numY=numOpt;
                subplotGby{curSubplotIdx}=chartGby{curChart};
        end
        if(~showBarChart)
            continue;
        end
        subplotHandles{curSubplotIdx}=subplot(numX,numY,curSubplotIdx);
        
        if(useCurInfoGroup&&numChartTimes>1)
            xBarLabels=cell(numChartTimes*numCurInfoG,1);
            timeStrs=num2str(round(barChartTimes));
            for g=1:numCurInfoG
                for t=1:numChartTimes
                    xBarLabels{(g-1)*numChartTimes+t}=sprintf('%s-%ss',curInfoGby{firstCurIdx(g)},timeStrs(t,:));
                end
            end
        elseif(useCurInfoGroup&&numChartTimes==1)
            xBarLabels=cell(numChartTimes*numCurInfoG,1);
            for g=1:numCurInfoG
                    xBarLabels{g}=curInfoGby{firstCurIdx(g)};
            end
        else
            xBarLabels=barChartTimeStrings;
        end
        
        

        if(exSettings.plot_bar_err&&~plotCount)
            pf2_base.external.barweb(barChartData{curChart}(:,:,1),barChartData{curChart}(:,:,2:1+numErrFeatures),1,xBarLabels, [], [], [], cIndex,[],gAStrs,[],'hide',barChartDataPoints{curChart},strcmp(errorFeature,'Violin'));
            
            if(strcmp(errorFeature,'MaxMin')||strcmp(errorFeature,'IQR')||strcmp(errorFeature,'IQR-NoOutliers')||strcmp(errorFeature,'Violin'))
                minValFromBarChart=min(min(min(barChartData{curChart}(:,:,2))));
                maxValFromBarChart=max(max(max(barChartData{curChart}(:,:,3))));
            else
                maxValFromBarChart=max(max(max(barChartData{curChart}(:,:,1)+barChartData{curChart}(:,:,2))));
                minValFromBarChart=min(min(min(barChartData{curChart}(:,:,1)-barChartData{curChart}(:,:,2))));
            end

            if(plottingDataPoints)
                [jSz,kSz]=size(barChartDataPoints{curChart});
                for j=1:jSz
                    for k=1:kSz
                        if(~isempty(barChartDataPoints{curChart}{j,k}))
                            maxValFromBarChart=nanmax(maxValFromBarChart,nanmax(barChartDataPoints{curChart}{j,k}));
                            minValFromBarChart=nanmin(minValFromBarChart,nanmin(barChartDataPoints{curChart}{j,k}));
                        end
                    end
                end
            end
            
            
            ylimLower=minValFromBarChart;
            ylimUpper=maxValFromBarChart;
            yrange=ylimUpper-ylimLower;
            ylim([ylimLower-0.1*yrange,ylimUpper+0.1*yrange]);
            
        else
            maxValFromBarChart=max(max(barChartData{curChart}(:,:,1)));
            minValFromBarChart=min(min(barChartData{curChart}(:,:,1)));

            pf2_base.external.barweb(barChartData{curChart}(:,:,1),[],1,xBarLabels, [], [], [], cIndex,[],gAStrs,[],'hide',barChartDataPoints{curChart});
            ylimLower=minValFromBarChart;
            ylimUpper=maxValFromBarChart;
            yrange=ylimUpper-ylimLower;
            
        end
        
        if(exSettings.ylim_fixed)
            ylim([min(ylimLower-0.05*yrange,0),max(ylimUpper+0.05*yrange,0)]);
            cylim=ylim;
            exSettings.ylim_fixed_min=min(cylim(1),exSettings.ylim_fixed_min);
            exSettings.ylim_fixed_max=max(cylim(2),exSettings.ylim_fixed_max);
        elseif(exSettings.ylim_manual&&~plotCount)
            ylim([exSettings.ylim_manual_min,exSettings.ylim_manual_max]);
        else
            ylim([min(ylimLower-0.1*yrange,0),max(ylimUpper+0.1*yrange,0)]);
        end
        
        switch exSettings.ChannelMode
            case 'fNIR'
                chNamePart=sprintf('Opt. %i',ch);
                chNamePartLong=sprintf('Optode %i',ch);
            case 'ROI'
                chNamePart=selectedOptStr{chIdx};
                chNamePartLong=sprintf('ROI: %s',selectedOptStr{chIdx});
            case 'Aux'
                chNamePart=selectedOptStr{chIdx};
                chNamePartLong=sprintf('Aux: %s %s',selectedOptStr{chIdx},bioM);
        end
        
        if(numBioM==1||numUgroups>1)  
            if(numBioM==1)
                bioM=selectedBioM(curChart);
                if(iscell(bioM))
                    bioM=bioM{1};
                end
                
                if(plotCount)
                    ylabel_with_space(sprintf('%s [%s]',plotFeature,bioM));
                elseif(strcmp(exSettings.ChannelMode,'Aux'))
                    if(errMultiply==1)
                        ylabel_with_space(sprintf('%s %s %s +/- %s',plotFeature,bioM,chNamePart,errorFeature));
                    else
                        ylabel_with_space(sprintf('%s %s %s +/- %dx %s',plotFeature,bioM,chNamePart,errMultiply,errorFeature));
                    end
                else
                    if(errMultiply==1)
                        ylabel_with_space(sprintf('%s \\Delta[%s] (\\muM)  +/- %s',plotFeature,bioM,errorFeature));
                    else
                        ylabel_with_space(sprintf('%s \\Delta[%s] (\\muM)  +/- %dx %s',plotFeature,bioM,errMultiply,errorFeature));
                    end
                end
            else
                bioM=selectedBioM(curChart);
                 if(iscell(bioM))
                    bioM=bioM{1};
                end
                if(plotCount)
                    ylabel_with_space(sprintf('%s [%s]',plotFeature,bioM));
                elseif(strcmp(exSettings.ChannelMode,'Aux'))
                    if(errMultiply==1)
                        ylabel_with_space(sprintf('%s %s %s +/- (%s)',plotFeature,bioM,chNamePart,errorFeature));
                    else
                        ylabel_with_space(sprintf('%s %s %s +/- %d*(%s)',plotFeature,bioM,chNamePart,errMultiply,errorFeature));
                    end
                else
                    if(errMultiply==1)
                        ylabel_with_space(sprintf('%s \\Delta[%s] (\\muM)  +/- (%s)',plotFeature,bioM,errorFeature));
                    else
                        ylabel_with_space(sprintf('%s %s %s +/- %dx(%s)',plotFeature,bioM,chNamePart,errMultiply,errorFeature));
                    end
                end
                
            end
        elseif(numBioM==b)
            if(plotCount)
                ylabel_with_space(sprintf('%s [%s]',plotFeature,'X'));
            elseif(strcmp(exSettings.ChannelMode,'Aux'))
                    ylabel_with_space(sprintf('%s Aux +/- (%s)',plotFeature,errorFeature));
            else
                ylabel_with_space(sprintf('%s \\Delta[%s] (\\muM)  +/- (%s)',plotFeature,'X',errorFeature));
            end
        end
        
        
        switch exSettings.ChannelMode
            case 'fNIR'
                title_with_space(sprintf('Optode %i',ch));
            case 'ROI'
                title_with_space(sprintf('ROI: %s',optStrs{ch}));
            case 'Aux'
                title_with_space(chNamePartLong);
        end
        
        if(useCurInfoGroup&&numChartTimes==1)
            xlabel_with_space(sprintf('%s (t=%s)',curInfoGroup,barChartTimeStrings{1}));
        elseif(useCurInfoGroup)
            xlabel_with_space(sprintf('Time (s) x %s',curInfoGroup));
        else
            xlabel_with_space('Time (s)');
        end
        
        if((numBioM>1||numUgroups>1)&&(exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2&&curSubplotIdx==lastPlotNum)))
            for i=1:size(gAStrs,1)
               if(isnumeric(gAStrs{i,curChart}))
                   gAStrs{i,curChart}='';
               end
            end
            legend(gAStrs(:,curChart),'Location', 'Best');
            legend boxoff;
        end
        hold off;
    end
end

if(plotCount)
   exSettings.ylim_fixed_min=0; 
end


if(exSettings.LME_enable)
    fprintf('Generating Models...\nAccessed at ExFNIRS.curChartModels\n')

    global ExFNIRS

    ExFNIRS.curChartModels=cell(0);
    ExFNIRS.curChartModelsAIC=[];
    ExFNIRS.curChartModelsCoefficents=cell(0);
    ExFNIRS.curChartModelsCoefficents_pval=table();
    ExFNIRS.curChartModelsCoefficents_tstat=table();
    ExFNIRS.curChartModelsCoefficents_df=table();
    ExFNIRS.curChartModelsANOVA=cell(0);
    ExFNIRS.curChartModelsANOVACoefficents_pval=table();
    ExFNIRS.curChartModelsANOVACoefficents_Fstat=table();
    ExFNIRS.curChartModelsANOVACoefficents_df1=table();
    ExFNIRS.curChartModelsANOVACoefficents_df2=table();
    ExFNIRS.curMdlFits=table();

    
end


 LME_topo_mode='anova';
 
 lmeString='None~';
 
 
for sH=1:length(subplotHandles)
    
    if(exSettings.LME_enable&&isfield(subplotGby{sH},'gby'))
        switch (exSettings.ChannelMode)
            case 'fNIR'
                mergedTables{sH}=exploreFNIRS.export.mergeGbyTablesLong(subplotGby{sH}.gby,subplotGby{sH}.curBioM,subplotGby{sH}.curCh,barChartTimes,false,false);
                varNameStart='Opt';
        
            case 'ROI'     
                mergedTables{sH}=exploreFNIRS.export.mergeGbyTablesLong(subplotGby{sH}.gby,subplotGby{sH}.curBioM,subplotGby{sH}.curCh,barChartTimes,false,true);
                varNameStart='ROI';
        
            case 'Aux'
                mergedTables{sH}=exploreFNIRS.export.mergeGbyTablesLong(subplotGby{sH}.gby,subplotGby{sH}.curBioM,subplotGby{sH}.curCh,barChartTimes,true,false);
                varNameStart='aux';
        end
        x=gbyVars;
        curLMEGbyString='';
        mdlPrtString='';
        
        useAllInteractions=exSettings.LME_all_interactions;
        
        basicMdlStrings=cell(0);
        
        
        if(exSettings.LME_info_covariate)
            basicMdlStrings{length(basicMdlStrings)+1}=exSettings.curInfoStr;
        end
%         if(plotGroupByBioM&&numBioM>1)
%             %basicMdlStrings{length(basicMdlStrings)+1}='BioM';
%             warning('GroupBy Biomarker Plots not supported yet\n Only using first biomarker');
%         end
        
        for z=1:length(basicMdlStrings)
            if(z==1)
                mdlPrtString=basicMdlStrings{z};
            else
                mdlPrtString=sprintf('%s*%s',mdlPrtString,basicMdlStrings{z});
            end
        end
        
        if(isempty(mdlPrtString))
            mdlPrtString='1';
        end

        
        if(useAllInteractions)
            curLMEGbyString=mdlPrtString;
            for i=1:length(x)
                curLMEGbyString=sprintf('%s*%s',curLMEGbyString,x{i});
            end
        else
            for i=1:length(x)
                curLMEGbyString=sprintf('%s+%s*%s',curLMEGbyString,mdlPrtString,x{i});
            end
            if(~isempty(curLMEGbyString))
                curLMEGbyString(1)=[];
            end

            
        end
        
        if(numChartTimes>1)
            curLMEGbyString=sprintf('%s+Time',curLMEGbyString);
        end
        
        dummyCodeStr='reference';
        
        if(strcmp(exSettings.ChannelMode,'Aux'))
            varName=sprintf('%s_%s',varNameStart,subplotGby{sH}.curBioM{1});
        else
            varName=sprintf('%s%i_%s',varNameStart,subplotGby{sH}.curCh,subplotGby{sH}.curBioM{1});
        end
        
        if(exSettings.LME_use_customStr&&~isempty(exSettings.LME_customStr))
            lmeString=sprintf('%s~%s',varName,exSettings.LME_customStr);
            if(contains(lmeString,'-1+')||contains(lmeString,'~-1'))
               dummyCodeStr='full';
               lmeString(lmeString=='*')=':';
            end
        elseif(exSettings.LME_use_intercept)
            lmeString=sprintf('%s~%s+(%s)',varName,curLMEGbyString,exSettings.LME_randomFxStr);
            if(isempty(curLMEGbyString))
                lmeString=sprintf('%s~1+(%s)',varName,exSettings.LME_randomFxStr);
            end
            
        else
            lmeString=sprintf('%s~-1+%s+(%s)',varName,curLMEGbyString,exSettings.LME_randomFxStr);
            dummyCodeStr='full';
            lmeString(lmeString=='*')=':';
        end

        try
            if((~exSettings.LME_use_discreteTime||strcmp(LME_topo_mode,'anova'))&&numChartTimes>1)
                mergedTables{sH}.Time=str2double(mergedTables{sH}.Time);
            end
            
            
            rng(2019);
            curChartLME{sH}=fitlme(mergedTables{sH},lmeString,'FitMethod','REML','CheckHessian',true,'DummyVarCoding',dummyCodeStr);
          %   curChartLME_emm{sH}= pf2_base.external.emmeans(curChartLME{sH}, {'orig'}, 'effects');
%             h = emmip(curChartLME_emm{sH},'orig');
            nullMdlstring=sprintf('%s~1+(1|SubjectID)',varName);
            curChartLME_ML=fitlme(mergedTables{sH},lmeString,'FitMethod','ML','CheckHessian',true,'DummyVarCoding',dummyCodeStr);
            nullChartLME=fitlme(mergedTables{sH},nullMdlstring,'FitMethod','ML','CheckHessian',true,'DummyVarCoding',dummyCodeStr);
            nullCompare{sH}=compare(curChartLME_ML,nullChartLME);
            pVal=nullCompare{sH}.pValue(end);
            if(pVal>0.05)
                nullCompareStr{sH}='Model is marginally worse than naive model';
            elseif(~isnan(pVal))
                nullCompareStr{sH}='Model is significantly worse than naive model';
            else
                nullCompare{sH}=compare(nullChartLME,curChartLME_ML);
                pVal=nullCompare{sH}.pValue(end);
                if(pVal>0.05)
                    nullCompareStr{sH}='Model is marginally better than naive model';
                else
                    nullCompareStr{sH}='Model is significantly better than naive model';
                end
            end
            
            switch (exSettings.ChannelMode)
                case 'fNIR'
                         chName=sprintf('Opt%i',subplotGby{sH}.curCh);
                         mdlChName=chName;
                case 'ROI'     
                         chName=sprintf('ROI%i_%s',subplotGby{sH}.curCh,optStrs{subplotGby{sH}.curCh});
                         mdlChName=sprintf('ROI%i',subplotGby{sH}.curCh);
                case 'Aux'
                        chName=sprintf('%s',subplotGby{sH}.curBioM{1});
                         mdlChName=chName;
            end

           
            fprintf('Chart %i LME model: %s',sH,chName);
            if(~plotGroupByBioM)
                fprintf(' [%s]',subplotGby{sH}.curBioM{1});
            end
            if(useAllInteractions)
                fprintf(' - All Interactions\n');
            else
                fprintf(' - No Interactions\n');
            end
            ExFNIRS.curChartModels{sH}=curChartLME{sH};
            ExFNIRS.curChartModelsAIC(sH)=curChartLME{sH}.ModelCriterion.AIC;
            [~,~,ExFNIRS.curChartModelsCoefficents{sH}]=randomEffects(curChartLME{sH},'DFMethod','satterthwaite');
            ExFNIRS.curChartModelsANOVA{sH}=anova(curChartLME{sH},'DFMethod','satterthwaite');
            
            anovaNames=curChartLME{sH}.anova.Term;
            
            for a=1:length(anovaNames)
               str=anovaNames{a};
               str(str=='('|str==')')=''; % replace shitty characters
               str(str==':'|str=='_')=''; % replace shitty characters
               str(str==' '|str=='-')=''; % replace shitty characters
               anovaNames{a}=str;
            end
            
            varNames=ExFNIRS.curChartModelsCoefficents{sH}.Name;
            for v=1:length(varNames)
               str=varNames{v};
               str(str=='('|str==')')=''; % replace shitty characters
               str(str==':'|str=='_')=''; % replace shitty characters
               str(str==' '|str=='-')=''; % replace shitty characters
               varNames{v}=str;
            end
            
            if(true)%~plotGroupByBioM)
                curBioM=subplotGby{sH}.curBioM{1};
                curRowName=sprintf('%s_%s',chName,curBioM);
                
                
                
                
                ExFNIRS.curChartModelsANOVACoefficents_pval{curRowName,anovaNames}= ExFNIRS.curChartModelsANOVA{sH}.pValue';
                ExFNIRS.curChartModelsANOVACoefficents_Fstat{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.FStat';
                if(ismember('DF2',properties(ExFNIRS.curChartModelsANOVA{sH})))
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF2';
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF1';
                else
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF';
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=zeros(size(ExFNIRS.curChartModelsANOVA{sH}.DF'));
                end
                
                
                

                
                ExFNIRS.curChartModelsCoefficents_pval{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.pValue';
                ExFNIRS.curChartModelsCoefficents_tstat{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.tStat';
                ExFNIRS.curChartModelsCoefficents_df{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.DF';
                ExFNIRS.curChartModels_ch(sH)=subplotGby{sH}.curCh;
            else
                curBioM=subplotGby{sH}.curBioM{1};
                curRowName=sprintf('%s_%s',chName,curBioM);
                ExFNIRS.curChartModelsCoefficents_pval{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.pValue';
                ExFNIRS.curChartModelsCoefficents_tstat{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.tStat';
                ExFNIRS.curChartModelsCoefficents_df{curRowName,varNames}=ExFNIRS.curChartModelsCoefficents{sH}.DF';
                
                
                ExFNIRS.curChartModelsANOVACoefficents_pval{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.pValue';
                ExFNIRS.curChartModelsANOVACoefficents_Fstat{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.FStat';
                if(ismember('DF2',properties(ExFNIRS.curChartModelsANOVA{sH})))
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF2';
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF1';
                else
                    ExFNIRS.curChartModelsANOVACoefficents_df1{curRowName,anovaNames}=ExFNIRS.curChartModelsANOVA{sH}.DF';
                    ExFNIRS.curChartModelsANOVACoefficents_df2{curRowName,anovaNames}=zeros(size(ExFNIRS.curChartModelsANOVA{sH}.DF'));
                end
                
                ExFNIRS.curChartModels_ch(sH)=subplotGby{sH}.curCh;
            end
            disp(curChartLME{sH});
            displayLME(curChartLME{sH});
            fprintf(2,'\n%s\n',nullCompareStr{sH});
            disp(nullCompare{sH});
            
            mdlTest=eye(length(curChartLME{sH}.Coefficients.Name));
            if(exSettings.LME_use_intercept)
                mdlTest=mdlTest(2:end,:);
            end
            [curMdlFit{1:4}]=coefTest(curChartLME{sH},mdlTest,zeros(size(mdlTest,1),1),'DFMethod','satterthwaite');
            fprintf('\nModel Fit (H0: All F=0): p=%.5f\tF=%.2f\tdf1=%i\tdf2=%i\n\n',curMdlFit{1},curMdlFit{2},curMdlFit{3},curMdlFit{4});
            if(~showTopo)
                curChartContrast=exploreFNIRS.fx.autoContrast(curChartLME{sH});
                if(~isempty(curChartContrast))
                    disp(curChartContrast);
                end
            end
            ExFNIRS.curMdlFits{curBioM,mdlChName}=curMdlFit{1};
            %curChartLME{sH}.contrastTable=exploreFNIRS.fx.autoContrast(curChartLME{sH},0.5);
        catch ME
            fprintf(2,'Could not generate model for figure %i\n',sH);
            fprintf(2,'\nLME: %s\n',lmeString);
            fprintf(2,ME.message);
            fprintf(2,'\n');
        end
    end
    
    
    if(showBarChart&&exSettings.ylim_fixed)
        set(subplotHandles{sH},'YLim',[exSettings.ylim_fixed_min, exSettings.ylim_fixed_max]);
    end
end

doublePlotWithFDR=false;
FDRfound=false;

if(showTopo)
    if(~exSettings.LME_enable)
        warning('LME must be enabled');
    else
        
        topoH=figure(2000);
        clf(topoH);
        lmeString=strsplit(lmeString,'~');
        lmeString=sprintf('[X]~%s',lmeString{2});
        addDebugAnnotation(topoH,lmeString);
        
        chNames=ExFNIRS.curChartModelsCoefficents_tstat.Properties.RowNames;
        coefNames=ExFNIRS.curChartModelsCoefficents_tstat.Properties.VariableNames;
        numCoeff=size(ExFNIRS.curChartModelsCoefficents_tstat,2);
        
        numANOVA=size(ExFNIRS.curChartModelsANOVACoefficents_Fstat,2);
        anovaNames=ExFNIRS.curChartModelsANOVACoefficents_Fstat.Properties.VariableNames;
        
         for z=1:length(chNames)
            temp=strsplit(chNames{z},'_');
             switch (exSettings.ChannelMode)
                case 'fNIR'
                         chArr(z)=sscanf(temp{1},'Opt%i');
                case 'ROI'     
                         chArr(z)=sscanf(temp{1},'ROI%i');
                case 'Aux'
            end
            
            bioMarr(z)=temp(end);
         end
         bioMLabel=cell(0,0);
        
        
         
        if(true&&~isempty(chNames))%~plotGroupByBioM)
            for b=1:numBioM
                bioM=selectedBioM(b);
               curMdlP=ExFNIRS.curMdlFits(bioM,:);  
              fprintf('\n <strong>Significant Models [%s]: </strong>',bioM{1});  
              [curMdlQ,curMdlK]=exploreFNIRS.fx.performFDR(curMdlP,exSettings.topoSigThrehold{2});
              [curMdlQ_rev,curMdlK_rev]=exploreFNIRS.fx.performFDR_twostep(curMdlP,exSettings.topoSigThrehold{2});  
                
              for i=1:size(curMdlP,2)
                  varName=curMdlP.Properties.VariableNames{i};
                  if((curMdlP{1,i}<exSettings.topoSigThrehold{2}&&strcmp(exSettings.topoSigThrehold{1},'p'))||...
                       (curMdlP{1,i}<0.05&&~strcmp(exSettings.topoSigThrehold{1},'p')))   
                      fprintf('\n%s_%s p=%.4f',varName,bioM{1},curMdlP{1,i});
                      if(curMdlP{1,i}<exSettings.topoSigThrehold{2}&&strcmp(exSettings.topoSigThrehold{1},'p'))
                          fprintf('<strong>* </strong>');
                      end
                      
                      if(strcmp(exSettings.topoSigThrehold{1},'q'))
                          fprintf(', q=%.4f',curMdlQ(i));
                      end
                      if(curMdlQ(i)<exSettings.topoSigThrehold{2}&&strcmp(exSettings.topoSigThrehold{1},'q'))
                          fprintf('<strong>* </strong>');
                      end
                      if(strcmp(exSettings.topoSigThrehold{1},'q-twostep'))
                          fprintf(', q adaptive=%.4f',curMdlQ_rev(i));
                      end
                      if(curMdlQ_rev(i)<exSettings.topoSigThrehold{2}&&strcmp(exSettings.topoSigThrehold{1},'q-twostep'))
                          fprintf('<strong>* </strong>');
                      end
                  end
                  
              end
              
              fprintf('\n');
                
              switch(LME_topo_mode)
                    case 'coef'
                        for c=1:numCoeff
                            fNIR_t{b,c}=nan(1,max(chArr));
                            fNIR_p{b,c}=nan(1,max(chArr));
                            fNIR_df{b,c}=nan(1,max(chArr));
                        end
                  case 'anova'
                        for a=1:numANOVA
                            fNIR_f{b,a}=nan(1,max(chArr));
                            fNIR_p{b,a}=nan(1,max(chArr));
                            fNIR_df{b,a}=nan(1,max(chArr));
                            fNIR_df2{b,a}=nan(1,max(chArr));
                        end

              end
            end


            
            for coefIdx=1:size(ExFNIRS.curChartModelsCoefficents_tstat,1)
                    
               curCh= chArr(coefIdx);
               
               curChName=chNames(coefIdx);

               b_idx=strcmp(bioMarr{coefIdx},selectedBioM);
               bioMLabel(b)=selectedBioM(b_idx);
               switch(LME_topo_mode)
                    case 'coef'
   
                       for c=1:numCoeff

                           fNIR_t{b_idx,c}(curCh)=ExFNIRS.curChartModelsCoefficents_tstat{curChName,coefNames(c)};
                           fNIR_p{b_idx,c}(curCh)=ExFNIRS.curChartModelsCoefficents_pval{curChName,coefNames(c)};
                           fNIR_df{b_idx,c}(curCh)=ExFNIRS.curChartModelsCoefficents_df{curChName,coefNames(c)};
                       end
                   case 'anova'
                       for a=1:numANOVA

                           fNIR_f{b_idx,a}(curCh)=ExFNIRS.curChartModelsANOVACoefficents_Fstat{curChName,anovaNames(a)};
                           fNIR_p{b_idx,a}(curCh)=ExFNIRS.curChartModelsANOVACoefficents_pval{curChName,anovaNames(a)};
                           fNIR_df{b_idx,a}(curCh)=ExFNIRS.curChartModelsANOVACoefficents_df1{curChName,anovaNames(a)};
                           fNIR_df2{b_idx,a}(curCh)=ExFNIRS.curChartModelsANOVACoefficents_df2{curChName,anovaNames(a)};
                       end
               end
            end
                   
            for b=1:numBioM
                if(b==1)
                   sigStr=sprintf('Thresholded at %s=%.2f',exSettings.topoSigThrehold{1},exSettings.topoSigThrehold{2});
                   th=annotation(topoH,'textbox',[0,1,0,0],'String',sigStr,'FitBoxToText','on'); 
                end
               switch(LME_topo_mode)
                    case 'coef'
                        for c=1:numCoeff
                            subplot(numBioM,numCoeff,c+(b-1)*numCoeff)
                            curT=fNIR_t{b,c};
                            curP=fNIR_p{b,c};
                            curDf=fNIR_df{b,c};
                            
                            

                            curQ=exploreFNIRS.fx.performFDR(curP);

                            if(any(curQ<0.05))
                                FDRfound=true;
                                %FDR RESULTS FOUND
                            end

                            global setF
                            
                            switch(setF.device.Info.CfgName)
                                case 'fNIR_Devices_fNIR1000'
                                    curT=nan(2,8);
                                    curP=nan(2,8);
                                    curDf=nan(2,8);

                                    curT(:)=fNIR_t{b,c};
                                    curP(:)=fNIR_p{b,c};
                                    curDf(:)=fNIR_df{b,c};


                                    switch(exSettings.ChannelMode)
                                        case 'fNIR'
                                            interpolateNIR(curT,'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',curP,'TitleText',coefNames{c},'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                        case 'ROI'
                                            roiInfo=ExFNIRS.currentROI;
                                            interpolateNIR(mapROIvaluesToCh(roiInfo,curT),'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',mapROIvaluesToCh(roiInfo,curP),'TitleText',coefNames{c},'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                    end
                                otherwise
                                    passingVals=curT(curP<0.05);
                                    if(~isempty(passingVals))
                                        minVal(1)=min(abs(passingVals));
                                        minVal(2)=-1*min(abs(passingVals));
                                        switch(exSettings.ChannelMode)
                                            case 'fNIR'
                                                pf2.Data.Plot.ImageValues([],curT,minVal,[],coefNames{c},'t-Stat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                            case 'ROI'
                                                roiInfo=ExFNIRS.currentROI;
                                                pf2.Data.Plot.ImageValues([],mapROIvaluesToCh(roiInfo,curT),minVal,[],coefNames{c},'t-Stat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                        end
                                    else
                                        plot(0,0);
                                        curAxes=gca;
                                        axesPos=curAxes.OuterPosition;
                                        axis off
                                        title_with_space(sprintf('%s_N_S',coefNames{c}));
                                        if(a==1) % first column
                                            th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',selectedBioM(b),'FitBoxToText','on');
                                        end
                                    end
                            end
                            if(c==1) % first column
                                ylabel_with_space(selectedBioM(b));
                            end
                        end
                   case 'anova'
                       for a=1:numANOVA
                            subplot(numBioM,numANOVA,a+(b-1)*numANOVA)
                            curF=fNIR_f{b,a};
                            curP=fNIR_p{b,a};
                            curDf1=fNIR_df{b,a};
                            curDf2=fNIR_df2{b,a};
                            m=length(curP(:));
                            [curQ,curK]=exploreFNIRS.fx.performFDR(curP,exSettings.topoSigThrehold{2});
                            [curQ_rev,curK_rev]=exploreFNIRS.fx.performFDR_twostep(curP,exSettings.topoSigThrehold{2});
                            
                            estimateFPval=finv(ones(size(curF(:)))*(1-exSettings.topoSigThrehold{2}), curDf1(:), curDf2(:));
                            estimateFPval_q=finv(ones(size(curF(:)))*(1-exSettings.topoSigThrehold{2}*curK/m), curDf1(:), curDf2(:));
                            estimateFPval_qrev=finv(ones(size(curF(:)))*(1-exSettings.topoSigThrehold{2}*curK_rev/m), curDf1(:), curDf2(:));
                            
                            switch(exSettings.topoSigThrehold{1})
                                case 'p'

                                case 'q'
                                    estimateFPval=estimateFPval_q;
                                case 'q-twostep'
                                    estimateFPval=estimateFPval_qrev;
                            end
                            
                            estimatedPval_min=nanmin(estimateFPval);
                            
                            if(any(curF(:)>=estimatedPval_min))
                                
                                titleSTR=anovaNames{a};

                                if(any(curQ<0.05))
                                    FDRfound=true;
                                    titleSTR=sprintf('%s*',anovaNames{a});
                                    %FDR RESULTS FOUND
                                end
                                
                                global setF
                            
                                switch(setF.device.Info.CfgName)
                                    case 'fNIR_Devices_fNIR1000'
                                        curF=nan(2,8);
                                        curP=nan(2,8);
                                        curDf1=nan(2,8);
                                        curDf2=nan(2,8);

                                        len=length(fNIR_f{b,a});
                                        curF(1:len)=fNIR_f{b,a};
                                        curP(1:len)=fNIR_p{b,a};
                                        curDf1(1:len)=fNIR_df{b,a};
                                        curDf2(1:len)=fNIR_df2{b,a};


                                        
                    
                                        switch(exSettings.ChannelMode)
                                            case 'fNIR'
                                                interpolateNIR(curF,'Mode','fstat','fontSize',12,'transparent',true,'lowerThreshold',estimatedPval_min,'TitleText',titleSTR,'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                            case 'ROI'
                                                roiInfo=ExFNIRS.currentROI;
                                                interpolateNIR(mapROIvaluesToCh(roiInfo,curF),'Mode','fstat','fontSize',12,'transparent',true,'lowerThreshold',estimatedPval_min,'TitleText',titleSTR,'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                        end
                                    otherwise
                                                                               
                                        switch(exSettings.ChannelMode)
                                            case 'fNIR'
                                                pf2.Data.Plot.InterpolateValues(curF,[],estimatedPval_min,[],1,titleSTR,'F-val');%InterpolateValues(fNIR,data2plot,minVal,maxVal,bufferMult,titleString,clrBarTitle)
                                            case 'ROI'
                                                roiInfo=ExFNIRS.currentROI;
                                                pf2.Data.Plot.InterpolateValues(mapROIvaluesToCh(roiInfo,curF),[],'minVal',estimatedPval_min,'maxVal',[],'bufferMult',1,'titleString',titleSTR,'clrBarTitle','F-val');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                        end
                                end

                                
                                if(a==1) % first column
                                    curAxes=gca;
                                    axesPos=curAxes.OuterPosition;
                                    th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',selectedBioM(b),'FitBoxToText','on');
                                end
                            else
                                plot(0,0);
                                curAxes=gca;
                                axesPos=curAxes.OuterPosition;
                                axis off
                                title_with_space(sprintf('%s_N_S',anovaNames{a}));
                                if(a==1) % first column
                                    th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',selectedBioM(b),'FitBoxToText','on');
                                end
                            end
                        end
                       
               end
            end
        end
        
        if(doublePlotWithFDR&&FDRfound)
            topoHfdr=figure(2001);
            clf(topoHfdr);
            addDebugAnnotation(topoHfdr);


                for b=1:numBioM
                    switch(LME_topo_mode)
                     case 'coef'
                        for c=1:numCoeff
                            subplot(numBioM,numCoeff,c+(b-1)*numCoeff)
                            curT=fNIR_t{b,c};
                            curP=fNIR_p{b,c};
                            curQ=exploreFNIRS.fx.performFDR(curP);

                            switch(exSettings.ChannelMode)
                                case 'fNIR'
                                    interpolateNIR(curT,'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',curQ,'TitleText',coefNames{c},'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                case 'ROI'
                                    roiInfo=ExFNIRS.currentROI;
                                    interpolateNIR(mapROIvaluesToCh(roiInfo,curT),'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',mapROIvaluesToCh(roiInfo,curQ),'TitleText',coefNames{c},'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
        %                             maxVal=nanmax([nanmax(abs(curT(:))),1]);
        %                             minVal=nanmin([maxVal+0.1;abs(curT(curP<0.05))]);
        %                             if(maxVal<=minVal)
        %                                 minVal=maxVal;
        %                                 maxVal=maxVal+0.05;
        %                             end
        %                             
        %                             numROI=size(ExFNIRS.currentROI,1);
        %                             vals=abs(curT(1:numROI));
        %                             pf2.Data.Plot.InterpolateROIvalues(roiInfo,vals,minVal,maxVal,1,coefNames{c},'tstat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                            end
                            if(c==1) % first column
                                ylabel_with_space(selectedBioM(b));
                            end
                        end
                        case 'anova'
                           for a=1:numANOVA
                            subplot(numBioM,numANOVA,a+(b-1)*numANOVA)
                            curT=fNIR_f{b,a};
                            curP=fNIR_p{b,a};
                            curQ=exploreFNIRS.fx.performFDR(curP);

                            switch(exSettings.ChannelMode)
                                case 'fNIR'
                                    interpolateNIR(curT,'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',curQ,'TitleText',numANOVA{a},'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                case 'ROI'
                                    roiInfo=ExFNIRS.currentROI;
                                    interpolateNIR(mapROIvaluesToCh(roiInfo,curT),'Mode','tstat','fontSize',12,'transparent',true,'pValueMask',mapROIvaluesToCh(roiInfo,curQ),'TitleText',numANOVA{a},'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
        %                             maxVal=nanmax([nanmax(abs(curT(:))),1]);
        %                             minVal=nanmin([maxVal+0.1;abs(curT(curP<0.05))]);
        %                             if(maxVal<=minVal)
        %                                 minVal=maxVal;
        %                                 maxVal=maxVal+0.05;
        %                             end
        %                             
        %                             numROI=size(ExFNIRS.currentROI,1);
        %                             vals=abs(curT(1:numROI));
        %                             pf2.Data.Plot.InterpolateROIvalues(roiInfo,vals,minVal,maxVal,1,coefNames{c},'tstat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                            end
                            if(a==1) % first column
                                ylabel_with_space(selectedBioM(b));
                            end
                        end
                            
                    end
                end
            suptitle_with_space('FDR Edition');
        end
        
    end
end
end




function possibleStr=num2strOrNot(possibleStr)
if(iscell(possibleStr))
    for i=1:length(possibleStr)
       if(~ischar(possibleStr{i})&&isnumeric(possibleStr{i}))
            possibleStr{i}=num2str(possibleStr{i}); 
       end
    end
elseif(~ischar(possibleStr)&&isnumeric(possibleStr))
    possibleStr=num2str(possibleStr);
end

end

function outStr=getFormattedTrialString(fNIR)

if(~isfield(fNIR,'info'))
    outStr='Missing Info';
    return;
end

outStr='';

subStr=num2strOrNot(fNIR.info.SubjectID);
groupStr=num2strOrNot(fNIR.info.Group);
sessionStr=num2strOrNot(fNIR.info.Session);
conditionStr=num2strOrNot(fNIR.info.Condition);
trialStr=num2strOrNot(fNIR.info.Trial);
blockStr=num2strOrNot(fNIR.info.Block);

useID=true&&~isempty(subStr);
useGroup=true&&~isempty(groupStr);
useSession=true&&~isempty(sessionStr);
useCondition=true&&~isempty(conditionStr);
useTrial=true&&~isempty(trialStr);
useBlock=true&&~isempty(blockStr);

if(useID)
    outStr=sprintf('%sSubjectID:%s\n',outStr,subStr);
end
if(useGroup)
    outStr=sprintf('%sGroup:%s\n',outStr,groupStr);
end
if(useSession)
    outStr=sprintf('%sSession:%s\n',outStr,sessionStr);
end
if(useCondition)
    outStr=sprintf('%sCondition:%s\n',outStr,conditionStr);
end
if(useTrial)
    outStr=sprintf('%sTrial:%s\n',outStr,trialStr);
end
if(useBlock)
    outStr=sprintf('%sBlock:%s\n',outStr,blockStr);
end

outStr(end)='';
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