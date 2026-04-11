function barchart(handles,exSettings,exGby,gbyVars, showBarChart,showTopo)
% BARCHART Create bar charts with error bars and LME analysis for exploreFNIRS
%
% Generates grouped bar charts displaying fNIRS biomarker data across
% experimental conditions with optional error bars, violin plots, and
% linear mixed-effects (LME) statistical modeling. Supports topographic
% display of ANOVA F-statistics across the probe.
%
% Reference:
%   Internal exploreFNIRS visualization. Uses barweb for grouped bar charts
%   (Bolu Ajiboye, 2005, MATLAB File Exchange). LME analysis uses MATLAB's
%   fitlme with Satterthwaite degrees of freedom approximation.
%
% Syntax:
%   barchart(handles, exSettings, exGby, gbyVars, showBarChart, showTopo)
%
% Inputs:
%   handles      - GUI handles structure from exploreFNIRS
%   exSettings   - Settings structure containing:
%                  .curInfoGroup   - Variable for X-axis grouping
%                  .ChannelMode    - 'fNIR', 'ROI', or 'Aux'
%                  .ylim_fixed     - Use consistent Y-axis across subplots
%                  .ylim_manual    - Use manually specified Y-axis limits
%                  .plot_bar_ga    - Show grand average bars
%                  .plot_bar_all   - Show individual data points
%                  .plot_bar_err   - Show error bars
%                  .plot_bar_err_feature - Error type ('SEM','SD','IQR', etc.)
%                  .plot_bar_err_mult - Error bar multiplier
%                  .plot_bar_feature - Summary statistic ('Mean','Median')
%                  .LME_enable     - Enable LME statistical analysis
%                  .LME_randomFxStr - Random effects formula (e.g., '1|SubjectID')
%                  .LME_all_interactions - Include all interaction terms
%                  .topoSigThrehold - {type, value} for significance threshold
%   exGby        - Array of grouped-by data structures containing:
%                  .gbyTables     - Table with subject-level data
%                  .gbyGrandBar   - Grand average structure with biomarker data
%                  .gbyFNIRS_blk  - Block-level fNIRS data
%   gbyVars      - Cell array of grouping variable names
%   showBarChart - Logical flag to display bar chart (false for stats only)
%   showTopo     - Logical flag to display topographic ANOVA maps
%
% Outputs:
%   (No direct outputs - creates figures and populates ExFNIRS global)
%
% Global Variables Modified:
%   ExFNIRS.curChartLMEResults    - Full fitLME results struct
%   ExFNIRS.curChartModels        - Cell array of fitted LME models
%   ExFNIRS.curChartModelsAIC     - AIC values for model comparison
%   ExFNIRS.curChartModelsANOVA   - ANOVA tables for each model
%   ExFNIRS.curChartModelsCoefficents_pval - p-values table
%   ExFNIRS.curChartModelsCoefficents_tstat - t-statistics table
%   ExFNIRS.curChartModelsANOVACoefficents_pval - ANOVA p-values
%   ExFNIRS.curChartModelsANOVACoefficents_Fstat - F-statistics
%   ExFNIRS.curMdlFits            - Model fit test results
%
% Error Bar Options:
%   'SEM'          - Standard error of the mean
%   'SD'           - Standard deviation
%   'MaxMin'       - Range (minimum to maximum)
%   'IQR'          - Interquartile range with outliers as points
%   'IQR-NoOutliers' - IQR without outlier display
%   'Violin'       - Violin plot showing full distribution
%
% LME Model Output:
%   - Fixed effects coefficients with Satterthwaite DFs
%   - ANOVA table with F-statistics
%   - Model comparison against null (intercept-only) model
%   - Automatic contrast generation
%
% Notes:
%   - Called internally by exploreFNIRS GUI
%   - Topographic mode displays F-statistics with FDR correction
%   - Data cursor shows group statistics on click
%   - Console output includes formatted statistics tables
%
% Example:
%   % Called internally from exploreFNIRS GUI
%   exploreFNIRS.plot.barchart(handles, exSettings, exGby, gbyVars, true, false);
%
% See also: exploreFNIRS.plot.scatter, exploreFNIRS.plot.temporal,
%           exploreFNIRS.fx.performFDR, exploreFNIRS.fx.autoContrast

curInfoGroup=exSettings.curInfoGroup;

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

biomStrs=get(handles.listbox_biomarker,'String');
selBioM=get(handles.listbox_biomarker,'Value');
selectedBioM=biomStrs(selBioM);
numBioM=length(selBioM);

optStrs=cellstr(get(handles.listbox_optode,'String'));
selOpt=get(handles.listbox_optode,'Value');
selectedOptStr=cellstr(optStrs(selOpt',:));
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

multiPlot=true;

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

minValFromBarChart=inf;
maxValFromBarChart=-inf;

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
                        numErrFeatures=4;
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
        subplotGby{curSubplotIdx}.barChartData=barChartData{curChart};
        subplotGby{curSubplotIdx}.gAStrs=gAStrs(:,1);

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


        subplotGby{curSubplotIdx}.xBarLabels=xBarLabels;


        if(exSettings.plot_bar_err&&~plotCount)
            pf2_base.external.barweb(barChartData{curChart}(:,:,1),barChartData{curChart}(:,:,2:1+numErrFeatures),1,xBarLabels, 'ColorMap', cIndex,'Legend',gAStrs,'LegendType','hide','DataPoints',barChartDataPoints{curChart},'PlotViolin',strcmp(errorFeature,'Violin'));


            if(plottingDataPoints||strcmp(errorFeature,'MaxMin')||strcmp(errorFeature,'IQR')||strcmp(errorFeature,'Violin'))
                [jSz,kSz]=size(barChartDataPoints{curChart});

                for j=1:jSz
                    for k=1:kSz
                        if(~isempty(barChartDataPoints{curChart}{j,k}))
                            maxValFromBarChart=nanmax(maxValFromBarChart,nanmax(barChartDataPoints{curChart}{j,k}(:)));
                            minValFromBarChart=nanmin(minValFromBarChart,nanmin(barChartDataPoints{curChart}{j,k}(:)));
                        end
                    end
                end


            elseif(strcmp(errorFeature,'IQR-NoOutliers'))
                minValFromBarChart=min(min(min(barChartData{curChart}(:,:,2))));
                maxValFromBarChart=max(max(max(barChartData{curChart}(:,:,3))));


            else
                maxValFromBarChart=max(max(max(barChartData{curChart}(:,:,1)+barChartData{curChart}(:,:,2))));
                minValFromBarChart=min(min(min(barChartData{curChart}(:,:,1)-barChartData{curChart}(:,:,2))));
            end




            ylimLower=minValFromBarChart;
            ylimUpper=maxValFromBarChart;
            yrange=ylimUpper-ylimLower;


        else
            maxValFromBarChart=max(max(barChartData{curChart}(:,:,1)));
            minValFromBarChart=min(min(barChartData{curChart}(:,:,1)));

            pf2_base.external.barweb(barChartData{curChart}(:,:,1),[],1,xBarLabels, 'ColorMap', cIndex,'Legend',gAStrs,'LegendType','hide', 'DataPoints',barChartDataPoints{curChart});

            ylimLower=minValFromBarChart;
            ylimUpper=maxValFromBarChart;
            yrange=ylimUpper-ylimLower;

        end

        if(exSettings.ylim_fixed)
            %ylim([min(ylimLower-0.05*yrange,0),max(ylimUpper+0.05*yrange,0)]);
            if(yrange==0)
                yrange=abs(ylimUpper)*2;
            end
            ylim([ylimLower-0.1*yrange,ylimUpper+0.1*yrange]);
            cylim=ylim;
            exSettings.ylim_fixed_min=min(cylim(1),exSettings.ylim_fixed_min);
            exSettings.ylim_fixed_max=max(cylim(2),exSettings.ylim_fixed_max);
        elseif(exSettings.ylim_manual&&~plotCount)
            ylim([exSettings.ylim_manual_min,exSettings.ylim_manual_max]);
        else
            ylim([ylimLower-0.1*yrange,ylimUpper+0.1*yrange]);
        end

        switch exSettings.ChannelMode
            case 'fNIR'
                chNamePart=sprintf('Opt. %s',selectedOptStr{chIdx});
                chNamePartLong=sprintf('Optode %s',selectedOptStr{chIdx});
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
                title_with_space(sprintf('Optode %s',optStrs{ch}));
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


% --- LME Statistical Analysis ---
% Delegates to exploreFNIRS.stats.fitLME instead of fitting inline

lmeResults = [];
curChartLME = cell(1, length(subplotHandles));

if(exSettings.LME_enable)
    fprintf('Generating Models...\nAccessed at ExFNIRS.curChartModels\n')

    global ExFNIRS

    % Build fitLME arguments from GUI settings
    lmeArgs = { ...
        'UseIntercept', logical(exSettings.LME_use_intercept), ...
        'AllInteractions', logical(exSettings.LME_all_interactions), ...
        'RandomEffects', exSettings.LME_randomFxStr, ...
        'Biomarkers', selectedBioM(:)', ...
        'Channels', selectedOpt, ...
        'Verbose', true, ...
        'TimeModel', exSettings.LME_timeModel, ...
        'PolynomialOrder', exSettings.LME_polyOrder, ...
        'SkipContrasts', showTopo, ...
        'ModelFitTest', true, ...
        'ExcludeShortSeparation', false};
    if(exSettings.LME_info_covariate)
        lmeArgs = [lmeArgs, {'InfoCovariate', exSettings.curInfoStr}];
    end
    if(exSettings.LME_use_customStr && ~isempty(exSettings.LME_customStr))
        lmeArgs = [lmeArgs, {'CustomFormula', exSettings.LME_customStr}];
    end

    switch exSettings.ChannelMode
        case 'fNIR'
            lmeArgs = [lmeArgs, {'DataType', 'fNIRS'}];
        case 'ROI'
            lmeArgs = [lmeArgs, {'DataType', 'ROI'}];
        case 'Aux'
            lmeArgs = [lmeArgs, {'DataType', 'Aux', 'AuxField', selectedBioM{1}}];
    end

    lmeResults = exploreFNIRS.stats.fitLME(exGby, gbyVars_original, lmeArgs{:});

    % Store consolidated results
    ExFNIRS.curChartLMEResults = lmeResults;

    % Legacy globals for backward compat
    ExFNIRS.curChartModels = lmeResults.models;
    ExFNIRS.curChartModelsAIC = lmeResults.AIC;
    ExFNIRS.curChartModelsANOVA = lmeResults.anova;
    ExFNIRS.curChartModelsANOVACoefficents_pval = lmeResults.anova_pval;
    ExFNIRS.curChartModelsANOVACoefficents_Fstat = lmeResults.anova_Fstat;
    ExFNIRS.curChartModelsANOVACoefficents_df1 = lmeResults.anova_df1;
    ExFNIRS.curChartModelsANOVACoefficents_df2 = lmeResults.anova_df2;
    ExFNIRS.curChartModelsCoefficents = lmeResults.coefficients;
    ExFNIRS.curChartModelsCoefficents_pval = lmeResults.coef_pval;
    ExFNIRS.curChartModelsCoefficents_tstat = lmeResults.coef_tstat;
    ExFNIRS.curChartModelsCoefficents_df = lmeResults.coef_df;

    % Build legacy curMdlFits table: rows=biomarker, cols=channel, values=p
    % Old format: ExFNIRS.curMdlFits{bioM, mdlChName} = p-value
    legacyMdlFits = table();
    if ~isempty(lmeResults.modelFit) && height(lmeResults.modelFit) > 0 && ...
            ismember('p', lmeResults.modelFit.Properties.VariableNames)
        mfRows = lmeResults.modelFit.Properties.RowNames;
        for mfI = 1:length(mfRows)
            parts = strsplit(mfRows{mfI}, '_');
            if length(parts) >= 2
                mfBio = parts{end};
                mfCh = strjoin(parts(1:end-1), '_');
            else
                mfBio = parts{1};
                mfCh = parts{1};
            end
            legacyMdlFits{mfBio, mfCh} = lmeResults.modelFit{mfI, 'p'};
        end
    end
    ExFNIRS.curMdlFits = legacyMdlFits;

    % Build curChartLME cell array for topo section compat
    for sH = 1:length(subplotHandles)
        if(~isfield(subplotGby{sH}, 'gby')), continue; end
        [bIdx, chI] = mapSubplotToResults(subplotGby{sH}, lmeResults, plotGroupByBioM);
        if(~isempty(bIdx) && ~isempty(chI) && bIdx <= size(lmeResults.models,1) && chI <= size(lmeResults.models,2))
            curChartLME{sH} = lmeResults.models{bIdx, chI};
        end
    end
end


LME_topo_mode='anova';

lmeString='None~';
if(~isempty(lmeResults))
    lmeString = lmeResults.formula;
end


for sH=1:length(subplotHandles)

    fprintf('\nInfo Table Values\n');
    curData=subplotGby{sH};
    if(isfield(curData,'gAStrs'))
        for i=1:size(curData.gAStrs,1)
            for j=1:size(curData.xBarLabels,1)
                fprintf('%s:%s\tMean %.2f\tError: %.2f\n',curData.gAStrs{i},curData.xBarLabels{j},curData.barChartData(j,i,1),curData.barChartData(j,i,2));
            end

        end
    end
    fprintf('\n');



    if(exSettings.LME_enable && isfield(subplotGby{sH},'gby') && ~isempty(lmeResults))
        [bIdx, chI] = mapSubplotToResults(subplotGby{sH}, lmeResults, plotGroupByBioM);

        if(~isempty(bIdx) && ~isempty(chI) && bIdx <= size(lmeResults.models,1) && chI <= size(lmeResults.models,2) && ~isempty(lmeResults.models{bIdx, chI}))
            mdl = lmeResults.models{bIdx, chI};

            switch (exSettings.ChannelMode)
                case 'fNIR'
                    chName=sprintf('Opt%s',optStrs{subplotGby{sH}.curCh});
                case 'ROI'
                    chName=sprintf('ROI%i_%s',subplotGby{sH}.curCh,optStrs{subplotGby{sH}.curCh});
                case 'Aux'
                    chName=sprintf('%s',subplotGby{sH}.curBioM{1});
            end

            fprintf('Chart %i LME model: %s',sH,chName);
            if(~plotGroupByBioM)
                fprintf(' [%s]',subplotGby{sH}.curBioM{1});
            end
            if(exSettings.LME_all_interactions)
                fprintf(' - All Interactions\n');
            else
                fprintf(' - No Interactions\n');
            end

            disp(mdl);
            displayLME(mdl);

            % Null comparison
            if(~isempty(lmeResults.nullComparison{bIdx, chI}))
                nc = lmeResults.nullComparison{bIdx, chI};
                pVal = nc.pValue(end);
                if(pVal < 0.05 && ~isnan(pVal))
                    fprintf(2,'\nModel is significantly better than naive model\n');
                elseif(~isnan(pVal))
                    fprintf(2,'\nModel is not significantly better than naive model\n');
                else
                    fprintf(2,'\nModel comparison inconclusive\n');
                end
                disp(nc);
            end

            % Model fit test
            if(~isempty(lmeResults.modelFit) && height(lmeResults.modelFit) > 0)
                rowNames = lmeResults.modelFit.Properties.RowNames;
                curBioM = subplotGby{sH}.curBioM;
                if(iscell(curBioM)), curBioM = curBioM{1}; end
                matchRow = find(contains(rowNames, chName) & contains(rowNames, curBioM), 1);
                if(~isempty(matchRow))
                    mfVals = lmeResults.modelFit{matchRow, :};
                    fprintf('\nModel Fit (H0: All F=0): p=%.5f\tF=%.2f\tdf1=%i\tdf2=%i\n\n', ...
                        mfVals(1), mfVals(2), mfVals(3), mfVals(4));
                end
            end

            % Contrasts (not in topo mode)
            if(~showTopo && ~isempty(lmeResults.contrasts{bIdx, chI}))
                disp(lmeResults.contrasts{bIdx, chI});
            end
        else
            fprintf(2,'Could not generate model for figure %i\n',sH);
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

        chArr=1:length(chNames);

        for z=1:length(chNames)
            temp=strsplit(chNames{z},'_');
            switch (exSettings.ChannelMode)
                case 'fNIR'
                    %chArr(z)=sscanf(temp{1},'Opt%i');
                case 'ROI'
                    %chArr(z)=sscanf(temp{1},'ROI%i');
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

                mdlPresent = ones(size(curChartLME));
                nMdls=length(curChartLME);
                for sHidx=1:nMdls
                    mdlPresent(sHidx)=~isempty(curChartLME{sHidx});
                end

                curMdlIdx = 0;

                switch(LME_topo_mode)
                    case 'coef'
                        for c=1:numCoeff
                            fNIR_t{b,c}=nan(1,nMdls);
                            fNIR_p{b,c}=nan(1,nMdls);
                            fNIR_df{b,c}=nan(1,nMdls);
                        end
                    case 'anova'
                        for a=1:numANOVA
                            fNIR_f{b,a}=nan(1,nMdls);
                            fNIR_p{b,a}=nan(1,nMdls);
                            fNIR_df{b,a}=nan(1,nMdls);
                            fNIR_df2{b,a}=nan(1,nMdls);
                        end

                end
            end



            for coefIdx=1:size(ExFNIRS.curChartModelsCoefficents_tstat,1)

                curMdlIdx=curMdlIdx+1;
                while(curMdlIdx<length(curChartLME) && isempty(curChartLME{curMdlIdx}))
                    curMdlIdx=curMdlIdx+1;
                end

                %curCh= chArr(coefIdx);

                curChName=chNames(coefIdx);

                b_idx=strcmp(bioMarr{coefIdx},selectedBioM);
                bioMLabel(b)=selectedBioM(b_idx);
                switch(LME_topo_mode)
                    case 'coef'

                        for c=1:numCoeff

                            fNIR_t{b_idx,c}(curMdlIdx)=ExFNIRS.curChartModelsCoefficents_tstat{curChName,coefNames(c)};
                            fNIR_p{b_idx,c}(curMdlIdx)=ExFNIRS.curChartModelsCoefficents_pval{curChName,coefNames(c)};
                            fNIR_df{b_idx,c}(curMdlIdx)=ExFNIRS.curChartModelsCoefficents_df{curChName,coefNames(c)};
                        end
                    case 'anova'
                        for a=1:numANOVA

                            fNIR_f{b_idx,a}(curMdlIdx)=ExFNIRS.curChartModelsANOVACoefficents_Fstat{curChName,anovaNames(a)};
                            fNIR_p{b_idx,a}(curMdlIdx)=ExFNIRS.curChartModelsANOVACoefficents_pval{curChName,anovaNames(a)};
                            fNIR_df{b_idx,a}(curMdlIdx)=ExFNIRS.curChartModelsANOVACoefficents_df1{curChName,anovaNames(a)};
                            fNIR_df2{b_idx,a}(curMdlIdx)=ExFNIRS.curChartModelsANOVACoefficents_df2{curChName,anovaNames(a)};
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
                                                pf2.data.plot.ImageValues([],curT,minVal,[],coefNames{c},'t-Stat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                            case 'ROI'
                                                roiInfo=ExFNIRS.currentROI;
                                                pf2.data.plot.ImageValues([],mapROIvaluesToCh(roiInfo,curT),minVal,[],coefNames{c},'t-Stat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
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
                                                pf2.probe.plot.interpolateValues3D(curF,setF.device.Info.CfgName,estimatedPval_min,[],titleSTR,'F-val','bufferDistance',1);%InterpolateValues(fNIR,data2plot,minVal,maxVal,bufferMult,titleString,clrBarTitle
                                            case 'ROI'
                                                roiInfo=ExFNIRS.currentROI;
                                                pf2.probe.plot.interpolateROIvalues(mapROIvaluesToCh(roiInfo,curF),[],'ROIinfo',roiInfo,'minVal',estimatedPval_min,'maxVal',[],'bufferMult',1,'titleString',titleSTR,'clrBarTitle','F-val');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
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
                                    %                             pf2.data.plot.InterpolateROIvalues(roiInfo,vals,minVal,maxVal,1,coefNames{c},'tstat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
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
                                    %                             pf2.data.plot.InterpolateROIvalues(roiInfo,vals,minVal,maxVal,1,coefNames{c},'tstat');%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
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


function [bIdx, chI] = mapSubplotToResults(spGby, lmeResults, plotGroupByBioM)
% MAPSUBPLOTTORESULTS Map subplot gby struct to (biomarker, channel) indices in results
    bIdx = [];
    chI = [];

    curCh = spGby.curCh;
    curBioM = spGby.curBioM;
    if iscell(curBioM)
        curBioM = curBioM{1};
    end

    % Find channel index
    chI = find(lmeResults.channels == curCh, 1);
    if isempty(chI), return; end

    % Find biomarker index
    if plotGroupByBioM
        % When grouped by biomarker, fitLME gets all biomarkers, bIdx=1 maps to first
        bIdx = find(strcmp(curBioM, lmeResults.biomarkers), 1);
        if isempty(bIdx), bIdx = 1; end
    else
        bIdx = find(strcmp(curBioM, lmeResults.biomarkers), 1);
        if isempty(bIdx), bIdx = 1; end
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


function txt = myDataTipUpdateFcn(pointDataTip, event_obj)

hAxes=get(pointDataTip,'Parent');
pos = event_obj.Position;
selectedObjectTag=event_obj.Target.Tag;

if(~isempty(selectedObjectTag))
    txt={sprintf('%s\nt=%.2f, y=%.2f',selectedObjectTag,pos(1),pos(2))};
else
    txt = {sprintf('t=%.2f, y=%.2f',pos(1),pos(2))};
end
%disp(['You clicked X:',num2str(pos(1)),', Y:',num2str(pos(2))]);

end
