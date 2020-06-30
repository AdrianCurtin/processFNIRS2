
function [contrastTable]=autoContrast(mdl,pThreshold)

if(nargin<2)
    pThreshold=0.1;
end

coefNames=mdl.CoefficientNames;
numCoef=length(coefNames);

[uCoefParts,b,uCoefIdx]=unique(strsplit(sprintf('%s:',coefNames{:}),':'));

[~,idx]=sort(b);
uCoefParts=uCoefParts(idx);
if(contains(uCoefParts{1},'(Intercept)'))
    uCoefParts{1}='Intercept';
    posthocmode='effects';
else
    posthocmode='full';
end
anv=anova(mdl,'DFMethod','satterthwaite');
hasIntercept=false;
anvTerms=anv.Term;
numAnv=length(anvTerms);
for i=1:numAnv % Get "root' terms (non-interaction terms)
   
   curTerm=strsplit(anvTerms{i},':');
   numAnvTerms(i)=length(curTerm);
   if(contains(curTerm{1},'Intercept'))
      hasIntercept=true; 
      anvTerms{i}='Intercept';
   end
   if(length(curTerm)==1)
       curTerm=curTerm{1};
       curTerm(curTerm=='('|curTerm==')')=[];
       rootAnvTerm{i}=curTerm;
       uCoefTerms{i}=uCoefParts(contains(uCoefParts,sprintf('%s',curTerm)));
   elseif(numAnv==1&&length(curTerm)>1&&~hasIntercept)
       rootAnvTerm=curTerm;
       for j=1:length(curTerm)
            uCoefTerms{j}=uCoefParts(contains(uCoefParts,sprintf('%s',curTerm{j})));
        end
   end
end


rootCoefNames=cell(length(rootAnvTerm),1);
rootCoefIdx=nan(length(rootAnvTerm),max(numAnvTerms));
coefTermParts=cell(length(coefNames),size(rootAnvTerm,2));
coefTermPartsIdx=nan(size(coefTermParts));
for i=1:numCoef %find which are the root terms in coefficients
   curTerms=strsplit(coefNames{i},':');
   numCoefTerms=length(curTerms);
   curAnvTerms='';
   curRootTerm=nan(size(curTerms));
   for t=1:numCoefTerms
       curTerm=curTerms{t};
       curTerm(curTerm=='('|curTerm==')')=[];
       for j=1:length(rootAnvTerm)
           if(~isempty(regexp(curTerm,sprintf('^%s',rootAnvTerm{j}))))
               rootCoefNames{j}=[{curTerm},rootCoefNames{j}];
               rootCoefIdx(i,j)=find(ismember(uCoefTerms{j},curTerm));
               coefTermParts{i,j}=curTerm;
               curRootTerm(t)=j;
               curAnvTerms=sprintf('%s:%s',curAnvTerms,rootAnvTerm{j});
               break;
           end
       end   
   end
   curAnvTerms(1)='';
   coefTermAnv(i)=find(ismember(anvTerms,curAnvTerms));
   if(numCoefTerms>1)
       curCoefIdx=rootCoefIdx(i,:);
       for t=1:length(curTerms)
           j=curRootTerm(t);
           curCoefIdx_loo=curCoefIdx;
           curCoefIdx_loo(j)=nan; %set current term to 0
           strParts={};
           for(t2=1:length(curCoefIdx_loo))
               if(~isnan(curCoefIdx_loo(t2))&&curCoefIdx_loo(t2)>0)
                    strParts{end+1}=uCoefTerms{t2}{curCoefIdx_loo(t2)};
               end
           end
           
           for r=1:i
                isStr=true;
               for s=1:length(strParts)
                    isStr=isStr&&contains(coefNames{r},strParts{s});
               end
               if(isStr)
                  break; 
               end
           end
           
           coefTermPartsIdx(i,j)=r;
       end
       
   end
end

rootCoefIdx(rootCoefIdx==0)=nan;


sigAnv=find(anv.pValue<pThreshold);

if(isempty(sigAnv))
    contrastTable=table();
    return;
else
   sigAnvNames=anv.Term(sigAnv);
end

sigCoef=mdl.Coefficients;
sigCoefIdx=sigCoef.pValue<=pThreshold;

cRows=[];
cAnvGrp=[];
cName={};
nRows=[];

for s=1:length(sigAnvNames)
   sIdx=sigAnv(s); 
   basic_contrast_idx=find(coefTermAnv==sIdx);
   interaction_contrast_idx=coefTermPartsIdx(coefTermAnv==sIdx,:);
   for c=1:length(basic_contrast_idx)
      if(numAnvTerms(sIdx)==1&&hasIntercept) %compare with intercept only
          nRows(end+1)=1;
          cRow=zeros(1,numCoef);
          cRow(1)=-1;
          cRow(basic_contrast_idx(c))=1;
          cRows(end+1,:)=cRow;
          if(contains(coefNames{basic_contrast_idx(c)},'(Intercept)'))
            cName{end+1}='Intercept vs 0';
          else
            cName{end+1}=sprintf('%s vs %s',coefNames{basic_contrast_idx(c)},'Intercept');
          end
          cAnvGrp(end+1)=c;
      elseif(numAnvTerms(sIdx)>1&&length(numAnvTerms)>1) %compare term and numterms-1 vs 0
          
          nRows(end+1)=1;
          cIdx=interaction_contrast_idx(c,:);
          cIdx=cIdx(~isnan(cIdx));
          [cIdx,uidx]=unique(cIdx);
          cIdx=cIdx(uidx);
          numContrasts=length(cIdx);
          for c2=1:numContrasts % compare within matched groups
              cRow=zeros(1,numCoef);
              cRow(cIdx)=1;
              cRow(cIdx(c2))=0;
              cRow(basic_contrast_idx(c))=1;
              cRows(end+1,:)=cRow;
              cName{end+1}=sprintf('%s vs %s',coefNames{basic_contrast_idx(c)},coefNames{cIdx(c2)});
                cAnvGrp(end+1)=c;
          end
           
          
       
      else %compare vs 0
          if(sigCoefIdx(c))
              nRows(end+1)=1;
              cRow=zeros(1,numCoef);
              %curCterms=coefTermIdx(basic_contrast_idx(c),:);
              %curCterms=curCterms(curCterms>0);
              cRow(basic_contrast_idx(c))=1;
              cRows(end+1,:)=cRow;
              cName{end+1}=sprintf('%s vs 0',coefNames{basic_contrast_idx(c)});
              cAnvGrp(end+1)=c;
          end
      end
      if(numAnvTerms(sIdx)>1)&&length(numAnvTerms)==1&&~hasIntercept %check for full model case (and multiple terms) 
          if(sigCoefIdx(c))
              nRows(end+1)=1;
              cIdx=rootCoefIdx(c,:); % now these are the model terms of all interactions
              cmp_contrast_idx=rootCoefIdx;
              cmp_contrast_idx(c,:)=nan;
              %cIdx=cIdx(~isnan(cIdx));
              numContrasts=length(cIdx);
              for c2=1:numContrasts % compare with groups 1 above
                  cmp_contrast=cmp_contrast_idx(:,c2)==cIdx(c2);
                  cRow=zeros(1,numCoef);
                  cRow(c)=1;
                  cRow(cmp_contrast)=-1;

                  if(any(ismember(cRows,cRow,'rows'))||any(ismember(cRows,cRow*-1,'rows'))...
                        ||sum(cmp_contrast)==1) % skips when the full interaction term is a better descripter
                    continue;
                  else
                    cRows(end+1,:)=cRow;
                    uc=uCoefTerms{c2};
                    cName{end+1}=sprintf('%s vs %s',uc{cIdx(c2)},coefNames{c});
                    cAnvGrp(end+1)=c;
                  end
              end

              for c2=1:numContrasts % repeat within similar groupss
                  cmp_contrast=cmp_contrast_idx(:,c2)==cIdx(c2);
                  
                  cmp_contrast_vals=find(cmp_contrast==1);
                  for cmp=1:length(cmp_contrast_vals)
                       
                      cRow=zeros(1,numCoef);
                      cRow(c)=1;
                      cRow(cmp_contrast_vals(cmp))=-1;

                      if(any(ismember(cRows,cRow,'rows'))||any(ismember(cRows,cRow*-1,'rows')))
                        continue;
                      else
                        cRows(end+1,:)=cRow;
                        uc=uCoefTerms{c2};

                        cName{end+1}=sprintf('%s vs %s',coefNames{c},coefNames{cmp_contrast_vals(cmp)});
                        cAnvGrp(end+1)=c;
                      end

                  end
              end
          end
       else
            for c2=c+1:length(basic_contrast_idx) % compare within similar groups
              nRows(end+1)=1;
              cRow=zeros(1,numCoef);
              cRow(basic_contrast_idx(c2))=-1;
              cRow(basic_contrast_idx(c))=1;

              cRows(end+1,:)=cRow;
              cName{end+1}=sprintf('%s vs %s',coefNames{basic_contrast_idx(c)},coefNames{basic_contrast_idx(c2)});
              cAnvGrp(end+1)=c;
          end
       end
   end
end

[~,~,mdlCoef]=fixedEffects(mdl,'DFMethod','satterthwaite');
for c=1:size(cRows,1)
    curRow=cRows(c,:);
   [pVal(c),F(c),df(c),df2(c)]= coefTest(mdl,curRow,0,'DFMethod','satterthwaite');
   
   %df2(c)=mdlCoef.DF(c); %overwrite with satterwaite coefs
   
   mdlCoefAnv=mdlCoef(curRow==1,:);
   mdlCoefCompare=mdlCoef(curRow==-1,:);
   if(contains(cName{c},'Intercept'))
        deltaE(c)=sum(mdlCoefAnv.Estimate);
   else
        deltaE(c)=sum(mdlCoefAnv.Estimate)-sum(mdlCoefCompare.Estimate);
   end
   
   SD_anv_temp=mdlCoefAnv.SE;
   SD_cmp=mdlCoefCompare.SE;
   
   SD_p(c)=sqrt(sum((mdlCoefAnv.DF).*(SD_anv_temp.^2))+...
       sum((mdlCoefCompare.DF).*(SD_cmp.^2)))...
       /sqrt(sum(mdlCoefAnv.DF)+sum(mdlCoefCompare.DF));
   SD_anv(c)=sqrt(sum((mdlCoefAnv.DF).*(SD_anv_temp.^2)))...
       /sqrt(sum(mdlCoefAnv.DF));
   %SE_p(c)=SD_p(c)/sqrt(mean(mdlCoefAnv.DF));
   HedgesG(c)=deltaE(c)/SD_p(c);
   GlassesDelta(c)=deltaE(c)/SD_anv(c);
end

[uAnvG,~,idxAnvG]=unique(cAnvGrp);
uCount=histcounts(cAnvGrp);
uCounts=uCount(idxAnvG);
pVal_corr=pVal(:).*uCounts(:);
pVal_corr(pVal_corr>1)=1;

contrastTable=table(deltaE',SD_p',F',df',df2',pVal',pVal_corr,'VariableNames',{'deltaE','SD','F','df1','df2','pVal','pVal_corr'},'RowNames',cName');

