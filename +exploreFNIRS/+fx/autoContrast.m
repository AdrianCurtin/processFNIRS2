
function [contrastTable,contrastCoefTable]=autoContrast(mdl,pThreshold)

%autoContrast provides the post-hoc testing for the provided model with a
%specified pThreshold used to stop the testing at the anova level

% The function performs slightly differently according to whether or not
% the model was generated using an intercept and attempts to only test
% hypotheses of interest. Both the raw p-values and bonferroni corrected
% values are presented

if(nargin<2)
    pThreshold=0.1; % Value at which an anova term is considered eligible for post-hoc testing
end

mdlCoefNames=mdl.CoefficientNames';
mdlCoefNames_with_colon=mdlCoefNames';
for i=1:length(mdlCoefNames_with_colon)
    mdlCoefNames_with_colon{i}=sprintf('%s:',mdlCoefNames_with_colon{i});
end

numMdlCoef=length(mdlCoefNames); 

[uCoefParts,b,uCoefIdx]=unique(strsplit(sprintf('%s:',mdlCoefNames{:}),':'));
    %Attempt to identify all unique coefficients and separate them from
    %interactions

[~,idx]=sort(b);
uCoefParts=uCoefParts(idx);

hasIntercept=contains(uCoefParts{1},'(Intercept)'); 

if(hasIntercept)
    uCoefParts{1}='Intercept';
    
    posthocmode='effects';
else
    posthocmode='full';
end

anv=anova(mdl,'DFMethod','satterthwaite');

anvTerms=anv.Term;
numAnv=length(anvTerms);
numRootAnvTerms=zeros(1,numAnv);  %Number of root terms in anova term
                                    % A=1, A:B=2, A:B:C = 3

rootAnvTerms={};                                    
                                    
for i=1:numAnv % Find all 'root' non-interaction terms
   
   curTerm=strsplit(anvTerms{i},':');
   if(hasIntercept&&contains(curTerm{1},'Intercept'))
       curTerm{1}='Intercept';
       anvTerms{i}='Intercept';
   end
   rootAnvTerms(end+1:end+length(curTerm))=curTerm;
   
   numRootAnvTerms(i)=length(curTerm);
end
[~,uTermIdx]=unique(rootAnvTerms);
rootAnvTerms=rootAnvTerms((sort(uTermIdx)));
   
for i=1:length(rootAnvTerms) % Link "root" interaction term to individual anv terms
   uCoefTerms{i}=uCoefParts(contains(uCoefParts,sprintf('%s',rootAnvTerms{i})));
end


rootCoefNames=cell(length(rootAnvTerms),1);
    %Non-interaction coeficients for each anova term (
    %Example: Anova term = "Difficulty"   
    %   Coefnames = {"Difficulty_easy","Difficulty_hard"}
rootCoefIdx=nan(length(rootAnvTerms),max(numRootAnvTerms));
    %Interaction matrix for each term attempting to denote the constituant
    %parts of the specific coeficient
    %
    %                   c1       c2    c3    c4     c5       c6
    % Example: mdl = Intercept + A_1+ B_1 + B_2 + A_1:B_1 +A1:B_2
    %           Int.    A       B
    %   coef1 = [1,     0,      ,0]
    %   coef2 = [0,     1,      ,0]
    %   coef3 = [0,     0,      ,1]
    %   coef4 = [0,     0,      ,2]
    %   coef5 = [0,     1,      ,1]
    %   coef6 = [0,     1,      ,2]
    %               (term levels are integer arrays)
    
coefTermParts=cell(length(mdlCoefNames),size(rootAnvTerms,2));
    %Interaction matrix for each term attempting to denote the constituant
    %parts of the specific coeficient, but as strings with levels
    % ex: coeficient = Trial_Easy:Condition_Reverse
    %       =   {"",    "Trial_Easy",   "Condition_Reverse"}

coefTermPartsIdx=nan(size(coefTermParts));
for i=1:numMdlCoef %find which are the root terms in coefficients
                    % ex A_condition1  A_condition_2   (A is the root term)
   curCoefTerms=strsplit(mdlCoefNames{i},':');
   numCoefTerms=length(curCoefTerms);
   curAnvTerms='';
   curRootTerm=nan(size(curCoefTerms));
   for t=1:numCoefTerms  %For each term in curent coeficient
       curTerm=curCoefTerms{t};
       curTerm(curTerm=='('|curTerm==')')=[]; %remove paraentheses from intercept
       for j=1:length(rootAnvTerms)  %Go through root anova terms and find matching names
           if(~isempty(regexp(curTerm,sprintf('^%s',rootAnvTerms{j})))) % if found
               rootCoefNames{j}=[{curTerm},rootCoefNames{j}]; %append the term to rootcoefnames
               rootCoefIdx(i,j)=find(ismember(uCoefTerms{j},curTerm)); %and the index for that anova term
               coefTermParts{i,j}=curTerm;
               curRootTerm(t)=j;
               curAnvTerms=sprintf('%s:%s',curAnvTerms,rootAnvTerms{j});
               break;
           end
       end   
   end
   curAnvTerms(1)='';
   coefTermAnv(i)=find(ismember(anvTerms,curAnvTerms));
   if(numCoefTerms>1)
       curCoefIdx=rootCoefIdx(i,:);
       for t=1:length(curCoefTerms)
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
                    isStr=isStr&&contains(mdlCoefNames{r},strParts{s});
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


sigAnvIdx=find(anv.pValue<pThreshold); %Find significant anova terms

if(isempty(sigAnvIdx))
    contrastTable=table();
    return;
else
   sigAnvNames=anv.Term(sigAnvIdx);
end

sigCoef=mdl.Coefficients;
sigCoefIdx=sigCoef.pValue<=pThreshold;

cRows=[];  %Contrast rows (for ftest)
cAnvGrp=[]; %Whic
cName={};
nRows=0;
isV0=logical(0);

for s=1:length(sigAnvNames)  %Look for contrasts within each term
   curAnvIdx=sigAnvIdx(s); 
   
   basic_contrast_idx=find(coefTermAnv==curAnvIdx);
        % The most basic contrast is each term vs the intercept
        %   (or if no intercept 0)    ex: H = [0 0 1]  where HxB=0
                                       % (mdl: Int + A_1 + A_2)
        % And the comparison between levels of the same term
        %           ex: H = [0 1 -1]   (mdl: Int + A_1 + A_2)
        
   interaction_contrast_idx=coefTermPartsIdx(coefTermAnv==curAnvIdx,:);
        % For interactions the equivalent is the contrast of the term vs
        % the base effect and other interaction terms
        % Ex:   A_1:B_1 vs A_1   H= [0 0 1 1] 
        %      or   A_1:B_1 vs B_1   H=[0 1 0 1]
        %
        % In some (usually custom) cases there may be no explicit
        % non-interaction term. Here, no base effect needs to be added
        %  Ex:   A_1:B_1 vs intercept H=[0 0 1 0]
        
   for c=1:length(basic_contrast_idx) 
       %Build contrasts for each singular term
       
       isIntercept=contains(mdlCoefNames{basic_contrast_idx(c)},'(Intercept)');
       
       if(isIntercept)
           termNameBasic='Intercept';
       else
           termNameBasic=mdlCoefNames{basic_contrast_idx(c)};
       end
       
       isInteraction=numRootAnvTerms(curAnvIdx)>1; %Interaction if current term has more than 1 root anova term in it
       
       % Compare term vs intercept and term vs 0
       if(~isInteraction)  
           
            cRow=zeros(1,numMdlCoef);
            
            cRow(basic_contrast_idx(c))=1;   
            nRows=nRows+1;
            cRows(nRows,:)=cRow;
            
            % Compare term vs 0 (or intercept)  [0 0 1]

            if(isIntercept) 
                cName{nRows}='Intercept vs 0';  % [1 0 0 0]
                isV0(nRows)=true;
                cAnvGrp(nRows)=0;
            elseif(hasIntercept)
                cName{nRows}=sprintf('%s vs %s',termNameBasic,'Intercept'); %[0 0 1]
                isV0(nRows)=false;
                cAnvGrp(nRows)=c;
            else
                cName{nRows}=sprintf('%s vs 0',termNameBasic); %[0 0 1]
                isV0(nRows)=true;
                cAnvGrp(nRows)=0;
            end

            % Compare term + intercept vs 0  (if intercept present)
            %   [1 0 1]
            if(~isIntercept&&hasIntercept)  %Also can test (Intercept + effect vs 0)
                cRow(1)=1;  %Include the intercept this time:  cRow= [0 0 1] -> [1 0 1]
                nRows=nRows+1;
                cRows(nRows,:)=cRow;
                cName{nRows}=sprintf('%s vs 0',termNameBasic); %[1 0 1]
                isV0(nRows)=true;
                cAnvGrp(nRows)=0;
            end
       end
     
       % Compare term matched interaction levels with base (intercept or 0)
       %                          I. A1 B2 A1:B2
       %       Ex: A1:B2 bs A1   [0  0   1   1]
       
       if(isInteraction)
          
          cIdx=interaction_contrast_idx(c,:);
          cIdx=cIdx(~isnan(cIdx));
          [cIdx,uidx]=unique(cIdx);
          cIdx=cIdx(uidx);
          numContrasts=length(cIdx);
          if(numContrasts>1)
              for c2=1:numContrasts % compare within matched groups with higher level
                  
                  cRow=zeros(1,numMdlCoef);
                  cRow(cIdx)=1;  %Use all interaction components
                  cRow(cIdx(c2))=0;   %Contrast with one root factor
                  
                  rootTermName=mdlCoefNames{cIdx(c2)};
                  cRow(basic_contrast_idx(c))=1; %set the intercation term to 1
                  
                  nRows=nRows+1;
                  cRows(nRows,:)=cRow;
                  cName{nRows}=sprintf('%s vs %s',termNameBasic,rootTermName);
                  
                  isV0(nRows)=false;
                  
                  cAnvGrp(nRows)=c;
              end
          end
          
          
              %In the case where there is only 1 contrast to be made
              % This is probably because of an A:B +1 situation
              cRow=zeros(1,numMdlCoef);
              cRow(cIdx)=1;  %Use all interaction components
              cRow(basic_contrast_idx(c))=1; %also use basic contrast term (should be identical)
              nRows=nRows+1;
              cRows(nRows,:)=cRow;
              if(hasIntercept)
                    cName{nRows}=sprintf('%s vs %s',termNameBasic,'Intercept'); %[0 0 1]
                    isV0(nRows)=false;
                    cAnvGrp(nRows)=c;
                    
                    cRow=zeros(1,numMdlCoef);
                    cRow(cIdx)=1;  %Use all interaction components
                    cRow(basic_contrast_idx(c))=1; %also use basic contrast term (should be identical)
                    cRow(1)=1; %Also use intercept
                    nRows=nRows+1;
                    cRows(nRows,:)=cRow;
                    cName{nRows}=sprintf('%s vs 0',termNameBasic); %[0 0 1]
                    isV0(nRows)=true;
                    cAnvGrp(nRows)=0;
              else
                    cName{nRows}=sprintf('%s vs 0',termNameBasic); %[0 0 1]
                    isV0(nRows)=true;
                    cAnvGrp(nRows)=0;
              end
          
       end
       
      if(isInteraction) %check for full model case (and multiple terms) 
%           if(sigCoefIdx(c))
%               
%               cIdx=rootCoefIdx(c,:); % now these are the model terms of all interactions
%               cmp_contrast_idx=rootCoefIdx;
%               cmp_contrast_idx(c,:)=nan;
%               %cIdx=cIdx(~isnan(cIdx));
%               numContrasts=length(cIdx);
%               for c2=1:numContrasts % compare with groups 1 above
%                   cmp_contrast=cmp_contrast_idx(:,c2)==cIdx(c2);
%                   cRow=zeros(1,numMdlCoef);
%                   cRow(c)=1;
%                   cRow(cmp_contrast)=-1;
% 
%                   if(any(ismember(cRows,cRow,'rows'))||any(ismember(cRows,cRow*-1,'rows'))... %skip if duplicated or
%                         ||sum(cmp_contrast)==1) % skips when the full interaction term (ex  a:b1 vs a:b2) is a better descripter
%                                                 % Usually just because
%                                                 % there is only 1 contrast
%                                                 % to be made
%                     continue;
%                   else
%                     nRows=nRows+1;
%                     cRows(nRows,:)=cRow;
%                     uc=uCoefTerms{c2};
%                     [cmpNameParts,p_idx]=unique(split(strcat(mdlCoefNames_with_colon{cmp_contrast}),':'));
%                     [a,b_idx]=sort(p_idx);
%                     cmpNameParts=cmpNameParts(b_idx);
%                     cmpName=char(join(cmpNameParts,':'));
%                     cName{nRows}=sprintf('%s vs %s',uc{cIdx(c2)},cmpName(1:end-1));
%                     cAnvGrp(nRows)=c;
%                     isV0(nRows)=false;
%                   end
%               end

%               for c2=1:numContrasts % repeat within similar groupss
%                   cmp_contrast=cmp_contrast_idx(:,c2)==cIdx(c2);
%                   
%                   cmp_contrast_vals=find(cmp_contrast==1);
%                   for cmp=1:length(cmp_contrast_vals)
%                        
%                       cRow=zeros(1,numMdlCoef);
%                       cRow(c)=1;
%                       cRow(cmp_contrast_vals(cmp))=-1;
% 
%                       if(any(ismember(cRows,cRow,'rows'))||any(ismember(cRows,cRow*-1,'rows'))||(cmp_contrast_vals(cmp)>length(numRootAnvTerms)))
%                         continue;
%                       else
%                           
%                         nRows=nRows+1;
%                         cRows(nRows,:)=cRow;
%                         uc=uCoefTerms{c2};
% 
%                         cName{nRows}=sprintf('%s vs %s',mdlCoefNames{c},mdlCoefNames{cmp_contrast_vals(cmp)});
%                         cAnvGrp(nRows)=c;
%                         isV0(nRows)=false;
%                       end
% 
%                   end
%               end
%               
%               for c2=1:numContrasts % make more general comparisons if possible
%                   cmp_contrast=rootCoefIdx(:,c2)==cIdx(c2);
%                   
%                   u_contrast_levels=unique(rootCoefIdx(rootCoefIdx(:,c2)~=cIdx(c2),c2));
%                   
%                   for cmp=1:length(u_contrast_levels)
%                       
%                       if(isnan(u_contrast_levels(cmp))||isnan(cIdx(c2)))
%                           continue;
%                       end
%                       
%                       cmp_contrast_val= rootCoefIdx(:,c2)==u_contrast_levels(cmp);
%                       cRow=zeros(1,numMdlCoef);
%                       cRow(cmp_contrast)=1;
%                       cRow(cmp_contrast_val)=-1;
% 
%                       if(any(ismember(cRows,cRow,'rows'))||any(ismember(cRows,cRow*-1,'rows')))
%                           %if the contrast is already being compared, skip
%                         continue;
%                       else
%                           nRows=nRows+1;
%                          cRows(nRows,:)=cRow;
%                             uc=uCoefTerms{c2};
%                             cName{nRows}=sprintf('%s vs %s',uc{cIdx(c2)},uc{u_contrast_levels(cmp)});
%                             cAnvGrp(nRows)=c;
%                             isV0(nRows)=false;
%                       end
% 
%                   end
%               end
          
       else
            for c2=c+1:length(basic_contrast_idx) % compare within similar groups
              nRows=nRows+1;
              cRow=zeros(1,numMdlCoef);
              cRow(basic_contrast_idx(c2))=-1;
              cRow(basic_contrast_idx(c))=1;

              cRows(nRows,:)=cRow;
              cName{nRows}=sprintf('%s vs %s',termNameBasic,mdlCoefNames{basic_contrast_idx(c2)});
              cAnvGrp(nRows)=c;
              isV0(nRows)=false;
            end
       end
   end
end

[~,~,mdlCoef]=fixedEffects(mdl,'DFMethod','satterthwaite');

[~,uNameIdx]=unique(cName);

% UDATE vs. 0 index for unqiue names
isV0=isV0(uNameIdx);

uNameIdx=sort(uNameIdx);
for c=1:length(uNameIdx)
    row_idx=uNameIdx(c);
    curRow=cRows(row_idx,:);
   [pVal(c),F(c),df(c),df2(c)]= coefTest(mdl,curRow,0,'DFMethod','satterthwaite');
   
   %df2(c)=mdlCoef.DF(c); %overwrite with satterwaite coefs
   
   mdlCoefAnv=mdlCoef(curRow==1,:);
   mdlCoefCompare=mdlCoef(curRow==-1,:);
   if(isempty(mdlCoefCompare))
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
   
   if(pVal(c)<0.001)
       sig(c)=" *** ";
   elseif(pVal(c)<0.01)
       sig(c)=" **  ";
   elseif(pVal(c)<0.05)
       sig(c)=" *   ";
   elseif(pVal(c)<0.1)
       sig(c)=" +   ";
   else
       sig(c)="     ";
   end
end

cAnvGrp=cAnvGrp(uNameIdx);

[uAnvG,~,idxAnvG]=unique(cAnvGrp);
uCount=histcounts(cAnvGrp);
uCounts=uCount(idxAnvG);
pVal_corr=pVal(:).*uCounts(:);
pVal_corr(pVal_corr>1)=1;

contrastTable=table(deltaE',SD_p',F',df',df2',pVal',pVal_corr,sig',cRows(uNameIdx,:),'VariableNames',{'deltaE','SD','F','df1','df2','pVal','pVal_corr','sig','coefContrasts'},'RowNames',cName(uNameIdx)');


%Sorts with vs 0. on top
contrastTable=[contrastTable(isV0,:);contrastTable(~isV0,:)];




