function [] = scatter(handles,exSettings,exGby,gbyVars,plotTopo)
% if one timepoint 
% 	if multi biomarker + multichannels
% 	groupby x channels (fig biomarker)
% 	if 1 biomarker + mult channels
% 	groupby x channels
% 	if 1 channel + mult biomarker
% 	groupby x biomarkers
% 	if 1 channel + 1 biomarker
% 	groupby
% if 1 groups
% 	biomarker mode
% 	if 1 timepoint
% 	groupby x channels
% 	if multi timepoints
% 	groupby x time   (fig channels)
% if no groupby
% 	if one timepoint
% 		biomarker x channels
% 	if multitimepoints & multi channel
% 		time x channels (fig biomarker)
% 	if multitimepoints & 1 channel
% 		time x biomarker

global ExFNIRS

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
    xlim_fixed_min=inf;
    exSettings.ylim_fixed_max=-inf;
    xlim_fixed_max=-inf;
end


% end

gbyStrs=cell(numGroups,1);
gbyShortStrs=cell(numGroups,1);
curInfoGby=cell(0);

for g=1:numGroups
    gbyStrs{g}='';
    gbyShortStrs{g}='';
   if(~isempty(exGby(g).gbyTables))
       for i=1:length(gbyVars)
           gbyStrs{g}=sprintf('%s%s:%s,',gbyStrs{g},gbyVars{i},num2strOrNot(exGby(g).gbyTables.(gbyVars{i})(1)));
           gbyShortStrs{g}=sprintf('%s%s:%s,',gbyShortStrs{g},gbyVars{i}(1),num2strOrNot(exGby(g).gbyTables.(gbyVars{i})(1)));
       end 
       if(useCurInfoGroup)
           curInfoGby{g}=num2strOrNot(exGby(g).gbyTables.(curInfoGroup)(1));
       end
   end 
   if(~isempty(gbyStrs{g}))
        gbyStrs{g}(end)='';
        gbyShortStrs{g}(end)='';
   end
end

numUgroups=length(unique(cellstr(gbyStrs)));

if(numUgroups==1)
    num2Plot=numBioM;
    plotGroupByBioM=true;
    temp=table2cell(pf2_base.getBioColors())';
    for i=1:size(temp,1)
       cIndex(i,:)=temp{i,:}; 
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
for i=1:numGroups
    if(isfield(exGby(i).gbyGrandBar,'time'))
        curGrandTime=exGby(i).gbyGrandBar.time;
        barChartTimes=[barChartTimes;curGrandTime];
    end
end
barChartTimes=sort(unique(round(barChartTimes)));

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


barChartTimes=barChartTimes(barChartTimes<exSettings.plot_end&barChartTimes>=exSettings.plot_start);
numChartTimes=length(barChartTimes);
errorFeature=exSettings.plot_bar_err_feature;
plotFeature=exSettings.plot_bar_feature;

if(strcmp(plotFeature,'Count')&&exSettings.plot_bar_ga)
    plotFeature='N';
    plotCount=true;
else
    plotCount=false;
end

if(plotGroupByBioM)
    subplotHandles=cell(numOpt*numCurInfoG*numChartTimes,1);
else
    subplotHandles=cell(numOpt*numBioM*numChartTimes*numCurInfoG,1);
end
if(plotTopo)
    if(numChartTimes>1)
        if(numCurInfoG>1&&numBioM>1&&numUgroups>1) %everything
            xType='ugroup';
			yType='time';
			figType='groupby,bio';
            numSubX=numUgroups;
            numSubY=numChartTimes;
        elseif(numCurInfoG<=1&&numBioM>=1&&numUgroups>1) %no infogroup
            xType='ugroup';
			yType='time';
			figType='bioM';
            numSubX=numUgroups;
            numSubY=numChartTimes;
        elseif(numCurInfoG>1&&numUgroups<=1&&numBioM>1) % no groups bu infogroup
			xType='groupby';
			yType='time';
			figType='bioM';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
        elseif(numUgroups<=1&&numCurInfoG<=1&&numBioM>1) % only biomarkers and time
			xType='bioM';
			yType='time';
			figType='';
            numSubX=numBioM;
            numSubY=numChartTimes;
		else
			xType='time';
			yType='bioM';
			figType='';
            numSubX=numChartTimes;
            numSubY=1;
        end
    else
        if(numCurInfoG>1&&numUgroups>1)
			xType='groupby';
			yType='ugroup';
			figType='bioM';
            numSubX=numCurInfoG;
            numSubY=numUgroups;
		elseif(numCurInfoG<=1&&numUgroups>1)
			xType='ugroup';
			yType='bioM';
			figType='';
            numSubX=numUgroups;
            numSubY=numBioM;
        elseif(numCurInfoG>1&&numUgroups<=1)
			xType='groupby';
			yType='bioM';
			figType='';
            numSubX=numCurInfoG;
            numSubY=numBioM;
		else
			xType='bioM';
			yType='';
			figType='';
            numSubX=numBioM;
            numSubY=1;
		end
    end
elseif(~plotGroupByBioM)
	if(numChartTimes>1)
		if(numOpt>1&&numCurInfoG>1)
			xType='groupby';
			yType='time';
			figType='bio,channels';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
		elseif(numOpt==1&&numCurInfoG>1)
			xType='groupby';
			yType='time';
			figType='bioM';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='time';
			yType='channels';
			figType='bioM';
            numSubX=numChartTimes;
            numSubY=numOpt;
		else
			xType='time';
			yType='bioM';
			figType='channels';
            numSubX=numChartTimes;
            numSubY=numBioM;
		end
	else
		if(numOpt>1&&numCurInfoG>1)
			xType='groupby';
			yType='channels';
			figType='bioM';
            numSubX=numCurInfoG;
            numSubY=numOpt;
		elseif(numOpt==1&&numCurInfoG>1)
			xType='groupby';
			yType='bioM';
			figType='';
            numSubX=numCurInfoG;
            numSubY=numBioM;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='channels';
			yType='bioM';
			figType='';
            numSubX=numOpt;
            numSubY=numBioM;
		else
			xType='bioM';
			yType='channels';
			figType='';
            numSubX=numBioM;
            numSubY=1;
		end
	end
else %plot with biomarkers embedded
	if(numChartTimes>1)
		if(numOpt>=1&&numCurInfoG>1)
			xType='groupby';
			yType='time';
			figType='channels';
            numSubX=numCurInfoG;
            numSubY=numChartTimes;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='time';
			yType='channels';
			figType='';
            numSubX=numChartTimes;
            numSubY=numOpt;
		else
			xType='time';
			yType='channels';
			figType='';
            numSubX=numChartTimes;
            numSubY=1;
		end
	else
		if(numOpt>=1&&numCurInfoG>1)
			xType='groupby';
			yType='channels';
			figType='';
            numSubX=numCurInfoG;
            numSubY=numOpt;
		elseif(numCurInfoG<=1&&numOpt>1)
			xType='channels';
			yType='';
			figType='';
            numSubX=numOpt;
            numSubY=1;
		else
			xType='channels';
			yType='';
			figType='';
            numSubX=1;
            numSubY=1;
		end
	end
end

if(plotTopo)
    emptyTopoData=[];
    emptyTopoData.r=nan(1,numOpt);
    emptyTopoData.p=nan(1,numOpt);
    emptyTopoData.rho=nan(1,numOpt);
    emptyTopoData.pval=nan(1,numOpt);
    emptyTopoData.n=nan(1,numOpt);
end

switch(figType)
    case 'channels'
        for i=1:numOpt
            sH{i,1}.h=figure(1200+i);
            clf(sH{i,1}.h);
            dcm_obj = datacursormode(sH{i,1}.h);
            set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
            for s=1:(numSubX*numSubY)
                xInd=rem(s,numSubX);
                if(xInd==0)
                    xInd=numSubX;
                end
                h=subplot(numSubY,numSubX,s);
                sH{i,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                legend(h, 'off');
            end
        end
    case 'bioM'
        for i=1:numBioM
            sH{i,1}.h=figure(1200+i);
            clf(sH{i,1}.h);
            dcm_obj = datacursormode(sH{i,1}.h);
            set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
            for s=1:(numSubX*numSubY)
                xInd=rem(s,numSubX);
                if(xInd==0)
                    xInd=numSubX;
                end
                h=subplot(numSubY,numSubX,s);
                sH{i,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                if(plotTopo)
                   topoData{i,1}.subH{floor((s-1)/numSubX)+1,xInd}=emptyTopoData;
                end
                legend(h, 'off');
            end
        end
    case 'bio,channels'
        for i=1:numOpt
            for b=1:numBioM
                sH{i,b}.h=figure(1200+i+50*b);
                clf(sH{i,b}.h);
                dcm_obj = datacursormode(sH{i,b}.h);
                set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
                for s=1:(numSubX*numSubY)
                    xInd=rem(s,numSubX);
                    if(xInd==0)
                        xInd=numSubX;
                    end
                    h=subplot(numSubY,numSubX,s);
                    sH{i,b}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                    legend(h, 'off');
                end
            end

        end
    case 'groupby,bio'
        for i=1:numCurInfoG
            for b=1:numBioM
                sH{i,b}.h=figure(1200+i+50*b);
                clf(sH{i,b}.h);
                dcm_obj = datacursormode(sH{i,b}.h);
                set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
                for s=1:(numSubX*numSubY)
                    xInd=rem(s,numSubX);
                    if(xInd==0)
                        xInd=numSubX;
                    end
                    h=subplot(numSubY,numSubX,s);
                    sH{i,b}.subH{floor((s-1)/numSubX)+1,xInd}=h;
                    if(plotTopo)
                       topoData{i,b}.subH{floor((s-1)/numSubX)+1,xInd}=emptyTopoData;
                    end
                    legend(h, 'off');
                end
            end

        end
    otherwise
        sH{1,1}.h=figure(1200);
        clf(sH{1,1}.h);
        dcm_obj = datacursormode(sH{1,1}.h);
        set(dcm_obj,'UpdateFcn',@myDataTipUpdateFcn);
        for s=1:(numSubX*numSubY)
            xInd=rem(s,numSubX);
            if(xInd==0)
                xInd=numSubX;
            end
            h=subplot(numSubY,numSubX,s);
            sH{1,1}.subH{floor((s-1)/numSubX)+1,xInd}=h;
            if(plotTopo)
               topoData{1,1}.subH{floor((s-1)/numSubX)+1,xInd}=emptyTopoData;
            end
            legend(h, 'off');
        end
end

curSx=1;
curSy=1;
curFigIdx=[1,1];


curInfoStr=exSettings.curInfoStr;

curUinfoStr="";
curUinfoStr(1)=[];

plotInfoStr=false;
        
    
    

if(exSettings.within_sub_avg_mode==3)
    dataH=ExFNIRS.dataHierarchy;
elseif(exSettings.within_sub_avg_mode==2)
    dataH='SubjectID';
else
    dataH=[];
end



for chIdx=1:numOpt
    
    if(strcmp(figType,'channels'))
        figure(sH{chIdx}.h);
        curFigIdx=[chIdx,1];
    elseif(strcmp(xType,'channels'))
        curSx=chIdx;
    elseif(strcmp(yType,'channels'))
        curSy=chIdx;
    end
    
    ch=selectedOpt(chIdx);
    legendGFXhandles{1}=[];
    legendGFXstrs{1}=cell(0);
    
    if(plotGroupByBioM)
        num2Plot=numBioM;
    elseif(numUgroups>1)
        num2Plot=numUgroups;
    end
    
    %barChartTimes=times;
    
    pointStrs=cell(num2Plot,1);
    gAStrs=cell(num2Plot,1);
    gAerrStrs=cell(num2Plot,1);
    
    for b=1:numBioM
        bioM=selectedBioM(b);
        if(iscell(bioM))
            bioM=bioM{1};
        end
        
        if(strcmp(figType,'bio,channels'))
            figure(sH{chIdx,b}.h);
            datacursormode(sH{chIdx,b}.h)
            curFigIdx=[chIdx,b];
        elseif(strcmp(figType,'bioM'))
            figure(sH{b,1}.h);
            datacursormode(sH{b,1}.h)
            curFigIdx=[b,1];
        elseif(strcmp(xType,'bioM'))
            curSx=b;
        elseif(strcmp(yType,'bioM'))
            curSy=b;
        end
        
        
        if(numUgroups>1)
            curChart=b;
        else
            curChart=1;
        end
        
        
        for g=1:numGroups
            curGrand=exGby(g).gbyGrandBar;
            curTable=exGby(g).gbyTables;
            
            if(isempty(curGrand)||isempty(curTable))
               continue; 
            end
            
            curData=curTable(:,curInfoStr);
            
            curData=table2array(curData);
    
            if(isstring(curData)||ischar(curData))
               %warning('Strings return count');
               curData=string(curData);
               [uDataX,~,curDataIdx]=unique(curData);
               if(~isempty(uDataX))
                   curUinfoStr(end+1:end+length(uDataX))=uDataX;
                   [curUinfoStr,~,curUidxX]=unique(curUinfoStr);
                   curData=nan(size(curDataIdx));
                   for udx=1:length(uDataX)
                       cdx=find(ismember(curUinfoStr,uDataX(udx)));
                       curData(curDataIdx==udx)=cdx;
                   end
                   %plotFeature='String';
                   % return;
                   plotInfoStr=true;
               end
            end
            curData(curData==-9999)=nan;
            
            if(useCurInfoGroup)
                curGroupInfoIdx=uCurIdx(g);
                curGroupIdxOffset=(curGroupInfoIdx-1)*numChartTimes;
                curUgroupIdx=uCurGIdxCount(g);
            else
                curGroupInfoIdx=1;
                curGroupIdxOffset=0;
                curUgroupIdx=g;
            end
            
            if(useCurInfoGroup)
                if(strcmp(xType,'groupby'))
                    curSx=curGroupInfoIdx;
                elseif(strcmp(yType,'groupby'))
                    curSy=curGroupInfoIdx;
                end
            end
            
            if(strcmp(xType,'ugroup'))
                curSx=curUgroupIdx;
            elseif(strcmp(yType,'ugroup'))
                curSy=curUgroupIdx;
            end
            
            
            if(strcmp(figType,'groupby,bio'))
                figure(sH{curGroupInfoIdx,b}.h);
                datacursormode(sH{curGroupInfoIdx,b}.h)
                curFigIdx=[curGroupInfoIdx,b];
            end
            
            if(plotInfoStr)
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@mode);
            elseif(strcmp(plotFeature,'Count'))
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nnz);
            elseif(strcmp(plotFeature,'Mean'))
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmean);
            elseif(strcmp(plotFeature,'Median'))
                [curHAvg,outH]=pf2_base.hierarchicalAverage(curData,curTable(:,dataH),@nanmedian);
            
            else
                error('Unknown parameter');
                %curHAvg=nanmedian(hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
            end
            
            if(numChartTimes==0)
                error('No data in selected time range!');
            end
            
            for t=1:numChartTimes
                if(strcmp(xType,'time'))
                    curSx=t;
                elseif(strcmp(yType,'time'))
                    curSy=t;
                end
                
                curPlotHandle=sH{curFigIdx(1),curFigIdx(2)}.subH{curSy,curSx};
                lastSubPlot=(curSy==numSubY&&curSx==numSubX);
                hold(curPlotHandle,'on')
                
                
                [timeIdx,timeIdxRev]=ismember(round(curGrand.time),barChartTimes(t));
                timeIdxRev=timeIdxRev(timeIdxRev>0);
                
                if(isempty(timeIdxRev))
                    
                    continue;
                end
                
                
              switch(exSettings.ChannelMode)
                  case 'fNIR'
                      data2plot=curGrand.(bioM);
                      dataHierarchy=curGrand.info.Hierarchy;
                  case 'ROI'
                      if(~pf2_base.isnestedfield(curGrand,'ROI.HbO.data'))
                          error('ROI data must be calculated using a build ROI step');
                      end
                          
                      data2plot=curGrand.ROI.(bioM);
                      dataHierarchy=curGrand.info.Hierarchy;
                  case 'Aux'
                      data2plot=curGrand.Aux.(bioM);
                      dataHierarchy=curGrand.Aux.(bioM).Hierarchy;
              end 
                curFeatureY=permute(data2plot.data(timeIdx,ch,:),[3,1,2]);
                
                if(strcmp(plotFeature,'Count')||strcmp(plotFeature,'N'))
                    [curFeatureY]=pf2_base.hierarchicalAverage(curFeatureY,dataHierarchy,@nnz);
                elseif(strcmp(plotFeature,'Mean'))
                    [curFeatureY]=pf2_base.hierarchicalAverage(curFeatureY,dataHierarchy,@nanmean);
                elseif(strcmp(plotFeature,'Median'))
                    [curFeatureY]=pf2_base.hierarchicalAverage(curFeatureY,dataHierarchy,@nanmedian);
                else
                    error('Unknown parameter');
                    %curHAvg=nanmedian(hierarchicalAverage(curData,curTable(:,dataH),@nanmedian));
                end
                
                if(length(curFeatureY)~=length(curHAvg))
                    if(length(curFeatureY)>length(curHAvg))
                        curFeatureY=curFeatureY(ismember(curGrand.info.Observation,outH));
                    else
                        temp=nan(size(curHAvg));
                        temp(ismember(outH,curGrand.info.Observation))=curFeatureY;
                        curFeatureY=temp;
                    end
                end
                
                if(~plotGroupByBioM||numBioM==1)
                     %gAStrs{curUgroupIdx,curChart}=sprintf('%s',gbyStrs{curUgroupIdx}); 
                     sColor=cIndex(curUgroupIdx,:);
                elseif(numBioM>1)
                     %gAStrs{b,curChart}=sprintf('%s',selectedBioM{b}); 
                     sColor=cIndex(b,:);
                end
                
                
               
                
                if(exSettings.plot_scatter_nonparametric)
                    
                    topoMode='rhocorr';
                    
                    validIdx=sum([isnan(curHAvg),isnan(curFeatureY)],2)==0;
                    validIdx=validIdx&(~isempty(curHAvg)&&~isempty(curFeatureY));
                    xVals=curHAvg(validIdx);
                    yVals=curFeatureY(validIdx);
                    
                    [~,p] = sort(xVals,'descend');
                    r = 1:length(xVals);
                    r(p) = r;
                    xVals=r';
                    
                    [~,p] = sort(yVals,'descend');
                    r = 1:length(yVals);
                    r(p) = r;
                    yVals=r';
                    
                    validIdx=sum([isnan(xVals),isnan(yVals)],2)==0;
                    validIdx=validIdx&(~isempty(curHAvg)&&~isempty(curFeatureY));
                    
                    xVals=xVals(validIdx);
                    yVals=yVals(validIdx);
                    N=length(xVals);
                else
                    validIdx=sum([isnan(curHAvg),isnan(curFeatureY)],2)==0;
                    validIdx=validIdx&(~isempty(curHAvg)&&~isempty(curFeatureY));
                    xVals=curHAvg(validIdx);
                    yVals=curFeatureY(validIdx);
                    N=length(xVals);
                    topoMode='rcorr';
                end
                
                
                
                 if(plotInfoStr)
                   uData=[xVals,yVals];
                   microvar=(nanmax(yVals)-nanmin(yVals))/100;
                    [uRows,~,uRowIdx]=unique(uData,'rows');
                    bincounts = histc(uRowIdx,1:max(uRowIdx));
                    for xv=1:length(bincounts)
                        if(bincounts(xv)>1)
                           stepsize=0.8/(bincounts(xv)-1);
                           offset=(-0.4:stepsize:0.4);
                           if(bincounts(xv)<10)
                               offset=offset/(10-bincounts(xv));
                           else
                                offset=(abs(offset).^1.5).*sign(offset);
                           end
                           xVals(uRowIdx==xv)=[uRows(xv,1)+offset];
                           yVals(uRowIdx==xv)=[uRows(xv,2)-microvar+g/numGroups*(2*microvar)];
                        end

                    end
                 end
                
                if(exSettings.plot_scatter_flipxy)
                    temp=xVals;
                    xVals=yVals;
                    yVals=temp;
                end
                
                if(plotTopo)
                    
                    switch(yType)
                        case 'ugroup'
                            rowLabel=gbyShortStrs{g};
                        case 'groupby'
                            rowLabel=curInfoGby{g};
                        case 'bioM'
                            rowLabel=sprintf('\\Delta[%s]',bioM);
                        case 'time'
                            rowLabel=sprintf('t=%i',round(barChartTimes(t)));
                        otherwise
                            rowLabel='Unkown';
                    end

                    switch(xType)
                        case 'ugroup'
                            titleSTR=gbyShortStrs{g};
                        case 'groupby'
                            titleSTR=curInfoGby{g};
                        case 'bioM'
                            titleSTR=sprintf('\\Delta[%s]',bioM);
                        case 'time'
                            titleSTR=sprintf('t=%i',round(barChartTimes(t)));
                        otherwise
                            titleSTR='Unkown';
                    end

                    
                    
                    
                    
                    
                    if(~isempty(xVals)&&~isempty(yVals))
                         [rho,pval] = corr(xVals,yVals,'Type','Spearman');
                         [r,p]=corr(xVals,yVals,'Type','Pearson');

                         curData=topoData{curFigIdx(1),curFigIdx(2)}.subH{curSy,curSx};

                         curData.p(chIdx)=p;
                         curData.r(chIdx)=r;
                         curData.rho(chIdx)=rho;
                         curData.pval(chIdx)=pval;
                         curData.N(chIdx)=N;

                         topoData{curFigIdx(1),curFigIdx(2)}.subH{curSy,curSx}=curData;

                         if(chIdx==numOpt)
                             if(exSettings.plot_scatter_nonparametric)
                                 curP=curData.pval;
                                 curR=curData.rho;
                                 clrBtitle='rho';
                             else
                                 curP=curData.p;
                                 curR=curData.r;
                                 clrBtitle='r';
                             end
                             
                             curDf=curData.N-2;
                             m=length(curP);
                            [curQ,curK]=exploreFNIRS.fx.performFDR(curP,exSettings.topoSigThrehold{2});
                            [curQ_rev,curK_rev]=exploreFNIRS.fx.performFDR_twostep(curP,exSettings.topoSigThrehold{2});
                            
                            curT=(curR./sqrt((1-curR.^2)/(N-2)));

                            estimate_tPval=tinv(ones(size(curT(:)))*(1-exSettings.topoSigThrehold{2}), curDf(:));
                            estimate_tPval_q=tinv(ones(size(curT(:)))*(1-exSettings.topoSigThrehold{2}*curK/m), curDf(:));
                            estimate_tPval_qrev=tinv(ones(size(curT(:)))*(1-exSettings.topoSigThrehold{2}*curK_rev/m), curDf(:));
                            
                            estimate_rPval=estimate_tPval(:)./(sqrt(curDf(:)+estimate_tPval(:).^2));
                            estimate_rPval_q=estimate_tPval_q(:)./(sqrt(curDf(:)+estimate_tPval_q(:).^2));
                            estimate_rPval_qrev=estimate_tPval_qrev(:)./(sqrt(curDf(:)+estimate_tPval_qrev(:).^2));

                            switch(exSettings.topoSigThrehold{1})
                                case 'p'
                                    curpthresh=exSettings.topoSigThrehold{2};
                                case 'q'
                                    estimate_rPval=estimate_rPval_q;
                                    curpthresh=exSettings.topoSigThrehold{2}*curK/m;
                                case 'q-twostep'
                                    estimate_rPval=estimate_rPval_qrev;
                                    curpthresh=exSettings.topoSigThrehold{2}*curK_rev/m;
                            end
                            
                            
                            if(any(curP<=curpthresh))
                               
                                
                                if(any(curP>curpthresh&curR>estimate_rPval'))
                                    minR1=min(estimate_rPval(curR>estimate_rPval'));
                                    curR(curP>curpthresh&curR>estimate_rPval')=minR1/2;
                                else
                                    minR1=min(estimate_rPval(curR>estimate_rPval'));
                                end
                                
                                
                                if(any(curP>curpthresh&curR<-1*estimate_rPval'))
                                    minR2=max(-1*estimate_rPval(curR<(-1*estimate_rPval')));
                                    curR(curP>curpthresh&curR<(-1*estimate_rPval'))=minR2/2;
                                else
                                    minR2=max(-1*estimate_rPval(curR<(-1*estimate_rPval')));
                                end
                                
                                if(isempty(minR2))
                                    minR2=-1*minR1;
                                elseif(isempty(minR1))
                                    minR1=-1*minR2;
                                end
                               
                                
                                switch(exSettings.ChannelMode)
                                    case 'fNIR'
                                         axes(curPlotHandle);
                                         pf2.Probe.Plot.InterpolateValues(curR,[],[minR1,minR2],[],1,titleSTR,clrBtitle);
                                        %interpolateNIR(abs(curR),'Mode',topoMode,'fontSize',12,'transparent',true,'lowerThreshold',min([abs(minR2),minR1]),'TitleText',titleSTR,'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                    case 'ROI'
                                        roiInfo=ExFNIRS.currentROI;
                                        interpolateNIR(mapROIvaluesToCh(roiInfo,abs(curR)),'Mode','corr','fontSize',12,'transparent',true,'lowerThreshold',min([abs(minR2),minR1]),'TitleText',titleST,'ChannelLabels',true)%,7,11,2,1,false,'[Hb-Oxy] Natural High Vs. Low',12,'hot',true)
                                end
                                if(curSx==1) % first column
                                    curAxes=curPlotHandle;
                                    axesPos=curAxes.OuterPosition;
                                    th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',rowLabel,'FitBoxToText','on');
                                end
                            else
                                plot(curPlotHandle,0,0);
                                curAxes=curPlotHandle;
                                axes(curPlotHandle);
                                axesPos=curAxes.OuterPosition;
                                axis off
                                title_with_space(sprintf('%s_N_S',titleSTR));
                                if(curSx==1) % first column
                                    th=annotation(gcf,'textbox',[0,max(axesPos(2),0.05),axesPos(3),axesPos(4)/2],'String',rowLabel,'FitBoxToText','on');
                                end
                            end
                         end
                    elseif(chIdx==numOpt)
                        plot(curPlotHandle,0,0);
                        curAxes=curPlotHandle;
                        axes(curPlotHandle);
                        axesPos=curAxes.OuterPosition;
                        axis off
                        title_with_space(sprintf('%s_N_S',titleSTR));
                        if(curSx==1) % first column
                            th=annotation(gcf,'textbox',[0,axesPos(2),axesPos(3),axesPos(4)/2],'String',rowLabel,'FitBoxToText','on');
                        end
                    end

                else
                    sHdots=scatter(curPlotHandle,xVals,yVals,25,sColor,'filled');
                    if(~plotGroupByBioM)
                       pointStrs{curUgroupIdx}= gbyStrs{g};
                       curPointStr=pointStrs{curUgroupIdx};
                       %if(exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2&&lastSubPlot))
                           sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{curUgroupIdx}=sHdots;
                       %end
                    else
                       pointStrs{b}=bioM;
                       curPointStr=bioM;
                      %if(exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2&&lastSubPlot))
                           sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{b}=sHdots;
                       %end
                    end 

                    tagStr=sprintf('%s',curPointStr); 
                    set(sHdots,'tag',tagStr);

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

                    if(plotGroupByBioM&&numBioM>1)
                        curFeatureString=sprintf('\\Delta[X]');
                    elseif(strcmp(exSettings.ChannelMode,'Aux'))
                        curFeatureString=sprintf('%s:%s',bioM,chNamePart);
                    else
                        curFeatureString=sprintf('\\Delta[%s]',bioM);
                    end

                    if(exSettings.plot_scatter_nonparametric)
                        curFeatureString=sprintf('Rank %s',curFeatureString);
                    end

                    switch(xType)
                        case 'time'
                            title_with_space(curPlotHandle,sprintf('t=%i',round(barChartTimes(t))));
                        case 'groupby'
                            title_with_space(curPlotHandle,curInfoGby{g});
                        case 'channels'
                            title_with_space(curPlotHandle,chNamePart);
                        case 'bioM'
                            title_with_space(curPlotHandle,bioM);
                    end


                    if(exSettings.plot_scatter_flipxy)

                        switch(yType)
                            case 'time'
                                xlabel_with_space(curPlotHandle,{sprintf('t=%i',round(barChartTimes(t)));curFeatureString});
                            case 'groupby'
                                xlabel_with_space(curPlotHandle,{curInfoGby{curUgroupIdx};curFeatureString});
                            case 'channels'
                                xlabel_with_space(curPlotHandle,{chNamePart;curFeatureString});
                            case 'bioM'
                                if(numBioM>1)
                                    xlabel_with_space(curPlotHandle,{bioM,curFeatureString});
                                else
                                    xlabel_with_space(curPlotHandle,curFeatureString);
                                end
                            otherwise
                                ylabel_with_space(curPlotHandle,{chNamePart;curFeatureString});
                        end
                        if(exSettings.plot_scatter_nonparametric)
                            ylabel_with_space(curPlotHandle,sprintf('Rank %s',curInfoStr));
                        else
                            ylabel_with_space(curPlotHandle,curInfoStr);
                        end
                        
                    else


                        switch(yType)
                            case 'time'
                                ylabel_with_space(curPlotHandle,{sprintf('t=%i',round(barChartTimes(t)));curFeatureString});
                            case 'groupby'
                                ylabel_with_space(curPlotHandle,{curInfoGby{curUgroupIdx};curFeatureString});
                            case 'channels'
                                ylabel_with_space(curPlotHandle,{chNamePart;curFeatureString});
                            case 'bioM'
                                if(numBioM>1)
                                    ylabel_with_space(curPlotHandle,{bioM,curFeatureString});
                                else
                                    ylabel_with_space(curPlotHandle,curFeatureString);
                                end
                            otherwise
                                ylabel_with_space(curPlotHandle,{chNamePart;curFeatureString});
                        end
                        if(exSettings.plot_scatter_nonparametric)
                            xlabel_with_space(curPlotHandle,sprintf('Rank %s',curInfoStr));
                        else
                            xlabel_with_space(curPlotHandle,curInfoStr);
                        end
                    end



                    if(exSettings.plot_scatter_line||exSettings.plot_scatter_err)
                        if(N>2)
                            [coefficients,PolyS] = polyfit(xVals, yVals, 1);
                            CI = pf2_base.external.polyparci(coefficients,PolyS);
                            xFit = linspace(min(xVals), max(xVals), 1000);
                            [yFit,deltaY] = polyval(coefficients, xFit,PolyS);

                            if(exSettings.plot_scatter_extend)
                                curXlim=xlim(curPlotHandle);
                                xFitExtend = linspace(min(curXlim), max(curXlim), 1000);
                                yFitExtend = polyval(coefficients, xFitExtend);
                            end

                            errMulitply=exSettings.plot_bar_err_mult;
                            %CI=[0,0;0,0];

                            yEst=polyval(coefficients, xVals,PolyS);
                            yDiff=yVals-yEst;
                            SD=std(yDiff);

                            %SD=sqrt(N)*(CI(:,2)-CI(:,1))'/3.92;
                            SEM=SD/sqrt(N);

                            switch(exSettings.plot_scatter_err_feature)
                                case 'SEM'
                                    %yCI_Upper = polyval(coefficients+SEM*errMulitply, xFit);
                                    %yCI_Lower = polyval(coefficients-SEM*errMulitply, xFit);
                                    yCI_Upper = yFit+SEM*errMulitply;
                                    yCI_Lower = yFit-SEM*errMulitply;
                                case 'SD'
                                    %yCI_Upper = polyval(coefficients+SD*errMulitply, xFit);
                                    %yCI_Lower = polyval(coefficients-SD*errMulitply, xFit);
                                    yCI_Upper = yFit+SD*errMulitply;
                                    yCI_Lower = yFit-SD*errMulitply;
                                case '95%CI'
                                    yCI_Upper = polyval(CI(1,:), xFit);
                                    yCI_Lower = polyval(CI(2,:), xFit);
                                case '50%PI'
                                    yCI_Upper = yFit+deltaY*(tinv(0.50,(N-1)));
                                    yCI_Lower = yFit-deltaY*(tinv(0.50,(N-1)));
                                case '67%PI'
                                    yCI_Upper = yFit+deltaY*(tinv(0.67,(N-1)));
                                    yCI_Lower = yFit-deltaY*(tinv(0.67,(N-1)));
                                case '90%PI'
                                    yCI_Upper = yFit+deltaY*(tinv(0.90,(N-1)));
                                    yCI_Lower = yFit-deltaY*(tinv(0.90,(N-1)));
                                case '95%PI'
                                    yCI_Upper = yFit+deltaY*(tinv(0.95,(N-1)));
                                    yCI_Lower = yFit-deltaY*(tinv(0.95,(N-1)));
                            end
                        end
                    end



                    if(exSettings.plot_scatter_err&&N>2)
                        errStyle=exSettings.plot_scatter_error_style;

                        plotShaded=false;

                        switch(errStyle)
                            case 'Dashed'
                                errStyle='--';
                                lineWidth=2;
                            case 'Fine'
                                errStyle='-';
                                lineWidth=0.5;
                            case 'Shaded'
                                errStyle='-';
                                lineWidth=0.5;
                                plotShaded=true;
                            otherwise
                                error('Unspecified error style');
                        end

                        errColor=sColor+(1-sColor)*0.55;
                        if(plotShaded)
                              errAlpha=0.15;
                              yPatch=[yCI_Lower,fliplr(yCI_Upper)];
                              xPatch=[xFit,fliplr(xFit)];
                              %xPatch(isnan(yPatch))=[];
                              %yPatch(isnan(yPatch))=[];

                              h=patch(curPlotHandle,xPatch,yPatch,-1,'facecolor',errColor,'edgecolor','none','facealpha',errAlpha);
                              set(h,'HandleVisibility','off');
                              set(h,'HitTest','off');
                              set(h.Annotation.LegendInformation,'IconDisplayStyle','off');
                        end

                        h=plot(curPlotHandle,xFit,yCI_Upper,'LineStyle',errStyle,'Color',errColor,'LineWidth',lineWidth);
                        set(h.Annotation.LegendInformation,'IconDisplayStyle','off');
                        h=plot(curPlotHandle,xFit,yCI_Lower,'LineStyle',errStyle,'Color',errColor,'LineWidth',lineWidth);
                        set(h.Annotation.LegendInformation,'IconDisplayStyle','off');
                    else
                          if(numUgroups>1||numBioM==1)
                               gAErrStrs{curGroupInfoIdx}=''; 
                          elseif(numBioM>1)
                               gAErrStrs{b}='';
                          end 
                    end

                    if(exSettings.plot_scatter_line&&N>2)
                        hold(curPlotHandle,'on')
                        if(exSettings.plot_scatter_extend)
                            gaH=plot(curPlotHandle,xFitExtend, yFitExtend, 'r-', 'LineWidth', 2,'Color',sColor);
                        else
                            gaH=plot(curPlotHandle,xFit, yFit, 'r-', 'LineWidth', 2,'Color',sColor);
                        end

                        set(gaH.Annotation.LegendInformation,'IconDisplayStyle','off');

                        [rho,pval] = corr(xVals,yVals,'Type','Spearman');


                        [r,p]=corr(xVals,yVals,'Type','Pearson');

                        if(~plotGroupByBioM)
                           fitStr=gbyStrs{g};
                           gAStrs{curUgroupIdx}= fitStr;
                           %if(exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2&&lastSubPlot))
                               sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{curUgroupIdx}=gaH;
                           %end
                        else
                           gAStrs{b}=bioM;
                           fitStr=bioM;
                           %if(exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2&&lastSubPlot))
                               sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h{b}=gaH;
                           %end
                        end

                        tagStr=sprintf('%s (N %i)\nRho=%.3f, p=%.4f\nr=%.3f p=%.4f',fitStr,N,rho,pval,r,p); 
                        set(gaH,'tag',tagStr);
                    elseif(~exSettings.plot_scatter_line)
                        %sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h=cell(0);
                        %gAStrs=cell(0);
                    end


                    curLgdHandles=sH{curFigIdx(1),curFigIdx(2)}.legendHandles{curSy,curSx}.h(:);
                    numCurLgd=length(curLgdHandles);
                    numFilled=0;
                    for i=1:numCurLgd
                        numFilled=numFilled+~isempty(curLgdHandles{i});
                    end

                    if(exSettings.ylim_fixed)
                        ylim(curPlotHandle,'auto');
                        cylim=ylim(curPlotHandle);
                        exSettings.ylim_fixed_min=min(exSettings.ylim_fixed_min,cylim(1));
                        exSettings.ylim_fixed_max=max(exSettings.ylim_fixed_max,cylim(2));

                        xlim(curPlotHandle,'auto');
                        cxlim=xlim(curPlotHandle);
                        xlim_fixed_min=min(xlim_fixed_min,cxlim(1));
                        xlim_fixed_max=max(xlim_fixed_max,cxlim(2));
                    elseif(exSettings.ylim_manual)
                        if(exSettings.plot_scatter_flipxy)
                            if(~plotCount)
                                xlim(curPlotHandle,[exSettings.ylim_manual_min,exSettings.ylim_manual_max]);
                            else
                                xlim(curPlotHandle,[0,exSettings.ylim_manual_max]);
                            end
                        else
                            if(~plotCount)
                                ylim(curPlotHandle,[exSettings.ylim_manual_min,exSettings.ylim_manual_max]);
                            else
                                ylim(curPlotHandle,[0,exSettings.ylim_manual_max]);
                            end
                        end
                    elseif(plotCount)
                        if(exSettings.plot_scatter_flipxy)
                            cxlim=xlim(curPlotHandle);
                            xlim(curPlotHandle,[0,cxlim(2)]);
                        else
                            cylim=ylim(curPlotHandle);
                            ylim(curPlotHandle,[0,cylim(2)]);
                        end

                    else
                        ylim(curPlotHandle,'auto');
                    end
                end
            end
                
        end
    end
end

if(plotCount)
    if(exSettings.plot_scatter_flipxy)
        xlim_fixed_min=0;
    else
        exSettings.ylim_fixed_min=0; 
    end
end


for i=1:size(sH,1)
    for b=1:size(sH,2)
        for x=1:numSubX
            for y=1:numSubY
                if(exSettings.ylim_fixed&&~plotTopo)
                    ylim(sH{i,b}.subH{y,x},[exSettings.ylim_fixed_min,exSettings.ylim_fixed_max]);
                    xlim(sH{i,b}.subH{y,x},[xlim_fixed_min,xlim_fixed_max]);
                end
                
                 

                if(plotInfoStr&&exSettings.plot_scatter_flipxy)
                    ylim(sH{i,b}.subH{y,x},[0,length(curUinfoStr)]+0.5);
                    yticks(sH{i,b}.subH{y,x},1:(length(curUinfoStr)));
                   yticklabels(sH{i,b}.subH{y,x},curUinfoStr); 
                   
                elseif(plotInfoStr)
                    xlim(sH{i,b}.subH{y,x},[0,length(curUinfoStr)]+0.5);
                    xticks(sH{i,b}.subH{y,x},1:(length(curUinfoStr)));
                   xticklabels(sH{i,b}.subH{y,x},curUinfoStr); 
                   
                end
                    
                    
                
                if((exSettings.plot_legend_mode==3||(exSettings.plot_legend_mode==2&&(x==numSubX)&&y==numSubY))&&~plotTopo)
                    lgStrs=[];
                    for k=1:length(pointStrs)
                       if(isnumeric(pointStrs{k}))
                           pointStrs{k}='';
                       end
                       lgStrs=[lgStrs;pointStrs(k)];
                    end

                    legend(sH{i,b}.subH{y,x},pointStrs(:),'Location', 'Best');
                end

                hold(sH{i,b}.subH{y,x},'off')
            end
        end

        addDebugAnnotation(sH{i,b}.h);
        
        
        if(exSettings.plot_scatter_nonparametric)
            suptStr=sprintf('Rank %s',curInfoStr);
        else
            suptStr=curInfoStr;
        end
        
        switch(figType)
            case 'bioM'
                suptStr=sprintf('%s: %s',suptStr,selectedBioM{i});
                suptitle_with_space(sH{i,b}.h,suptStr);
            case 'channels'
                suptStr=sprintf('%s: Optode %i',suptStr,selectedOpt(i));
                suptitle_with_space(sH{i,b}.h,suptStr);
            case 'bio,channels'
                suptStr=sprintf('%s: Optode %i [%s]',suptStr,selectedOpt(i),selectedBioM{b});
                suptitle_with_space(sH{i,b}.h,suptStr);
            case 'groupby,bio'
                suptStr=sprintf('%s: %s [%s]',suptStr,uCurInfoG{i},selectedBioM{b});
                suptitle_with_space(sH{i,b}.h,suptStr);
            otherwise
                suptitle_with_space(suptStr);
        end
        
        if(plotTopo)
           sigStr=sprintf('Thresholded at %s=%.2f',exSettings.topoSigThrehold{1},exSettings.topoSigThrehold{2});
           th=annotation(sH{i,b}.h,'textbox',[0,1,0,0],'String',sigStr,'FitBoxToText','on'); 
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
