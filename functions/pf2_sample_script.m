runSkip=true; % if you press run just to see the example, this will skip some optional steps

%% Step 1: Load data
% 
% Example: Loading FNIRS data from a .nir file

%load fNIRS data from FNIR devices model 1100 (same layout as 1200)
[fNIR]=ImportNIR('sampleNIR.nir','sampleNIR.mrk');

% Assign subject age/ other information
fNIR.info.SubjectID='TestSubject1';
fNIR.info.Age=25;
fNIR.info.Sex='F';

% any fields in .info are accessible by exploreFNIRS
%ex : fNIR.info.reactionTime=300 or fNIR.info.protocol='v.1.3'

% try to fill in Subject ID, Age, Sex, Group, Subgroup, Session, Condition,
%   Trial, and Block if possible/available
%%
if(~runSkip)

    %%
    
    % Example of loading data from raw numeric data matrix
    % to load into ProcessFNIR2 for visualization

    % Will first prompt you to select the configuration file for the relevant
    % device

    onlyRawData=fNIR.raw;
    onlyMarkerData=fNIR.mrk.data;

    processFNIRS2(onlyRawData,'markers',onlyMarkerData); %raw data conversion and append markers

    %%
    % Example to visualize loaded fNIR struct
    % Load into ProcessFNIR2 for visualization

    % Will first prompt you to select the configuration file for the relevant
    % device

    processFNIRS2(fNIR); %just load from marker struct

    %%
end
%%  Step 2: Load settings
%
% Example of loading a known and predefined configuration file for your
% device so that the device selection dialog may be skipped
processFNIRS2('UseDeviceCFG','device_fNIR1200.cfg');

% Example of setting the default raw and oxy processing methods to 'None'
% prior without opening the GUI (useful for importing)
processFNIRS2('Raw_Method','None','Oxy_Method','None');

%%  Step 3: Process fNIRS data
%
% Example of converting an FNIRS struct (as loaded in step 1) using the
%               predefined processing methods (identified in step2)
tic
FNIR_processed=processFNIRS2(fNIR);
toc

%%
if(~runSkip)
    %%
    % Example of converting an FNIRS struct (as loaded in step 1) using
    % given methods for raw (medfilt) and oxy (CAR)
    % Note: these method names must match defined methods
    
    FNIR_processed=processFNIRS2(fNIR.raw,'medfilt','car');

    %%
    % Example of converting an FNIRS struct with default methods, but
    % showing the GUI after conversion 
    %   (changes in GUI do not affect output)
    tic
    FNIR_processed=processFNIRS2(fNIR,'ShowGUI',true);
    toc
  %%  
  % Basic plotting function
  % plots channels 1 to 16 and also shows markers 50 and 51
  channels2plot=1:16;
  markers2plot=[50,51];
  plotFNIR(FNIR_processed,channels2plot,markers2plot)
  
%%
end
%% Step 4: Splitting segment into multiple parts
%
% in the given sampleNIR.nir the markers 50 and 51 designate task start and
% end

% Here is some sample code to split the session up by each trial
 % manually
markers=FNIR_processed.markers;
mark50=markers(markers(:,2)==50,:); % get all 51 markers
mark51=markers(markers(:,2)==51,:); % get all 51 markers

numTrials=4;
trialStartTimes=mark50(1:numTrials,1);
trialEndTimes=mark51(1:numTrials,1);

trial3=getFNIRS(FNIR_processed,trialStartTimes(3),trialEndTimes(3)); %returns only the segment from output from trial start 3 to trial end 3

channels2plot=1:16;
markers2plot=[50,51];

plotFNIR(trial3,channels2plot,markers2plot)
title('Sample FNIRS data Trial 3');

        %example using getFNIRSmarkers
                trialTimes=getFNIRSmarkers(FNIR_processed,50,51)
                trial3=getFNIRS(FNIR_processed,trialTimes(3,1),trialTimes(3,2)); %returns only the segment from output from trial start 3 to trial end 3


%%
if(~runSkip)
%% Optional step (move timeline so that trial start time is now 0)
% note explore fnirs will automatically do this if you dont do it, but its
% advisable to keep the baseline period during negative times for an easier
% assessment
trial3_fromt0=setT0fnirs(trial3,trialStartTimes(3));

subplot(1,2,1);
plotFNIR(trial3,1,markers2plot)
title('Original Trial 3');
subplot(1,2,2);
plotFNIR(trial3_fromt0,1,markers2plot)
title('Original Trial 3 from start of trial');
            
%%
end
%% Step 5: Package all rounds together for exploreFNIRS processing
% 
  
baselineTime=10; %specify a ten second baseline period
blStart=-10; %specify that the baseline starts 10 seconds before the task does

exploreFNIRScells=cell(0);
for i=1:numTrials
    segmentStartTime=trialStartTimes(i)+blStart; %subtracts blStartTime from start time to make sure baseline is included in segment
    segmentEndTime=trialEndTimes(i); %could optionally add a trial timelength to start time, add additional time to include area after the end of the trial in the segment
    
    currentFNIRSsegment=getFNIRS(FNIR_processed,segmentStartTime,segmentEndTime); %segment according to baseline (before trial start) and end times
    currentFNIRSsegment.info.Trial=i; %assign a value to trial based on trial number
    currentFNIRSsegment=setT0fnirs(currentFNIRSsegment,trialStartTimes(i)); % shift to t0 if using any temporal comparisons 
    exploreFNIRScells{i}=currentFNIRSsegment; %assign the structure to larger cell array of fnirs cells
end

  
  
%% Step 6: Load all rounds into ExploreFNIRS

timeShiftTo0=false; %we already did this in step 5!
blStart=-5; % tell the baseline to start 5 seconds before the task
blEnd=-0; %specify when the baseline period ends (here at t=0s)
taskStartTime=0; %specify when the task starts
taskEndTime=120; %specify when the task ends
averagingPeriodLength=60; %specify how long to group segments when averaged together for either temporal or full task averaging
        %here 60s will average the times from [0-60s, and 60s-120s] as bins
        


exploreFNIRS(exploreFNIRScells,'timeShiftTo0',timeShiftTo0,'blStart',blStart,'blEnd',blEnd','blockStart',taskStartTime,'blockEnd',taskEndTime,'barSegmentLength',averagingPeriodLength);
  
  
%   %%
%             % Random testing for other skipping processing steps
%             outputTest=output;
%             output2=processFNIRS2(outputTest,'None','SMAR','SkipOxy',true,'SkipOD',true,'ShowGUI',false);
% 
%             %%  Testing for nirsAvg
%             outputFirst30Seconds=getFNIRS(output,0,30,'relative',true);
%             lenTime=length(outputFirst30Seconds.time);
%             outputFirst30Seconds.HbO(:,1)=ceil((1:lenTime)/2);
%             outputFirst30Seconds.HbR(:,1)=ceil((1:lenTime)/2);
% 
%             centerAt=true;
%             timeOut='start';
%             out1s=nirsAvg(outputFirst30Seconds,1,'centerOnT0',centerAt,'timeOutMode',timeOut);
%             out2s=nirsAvg(outputFirst30Seconds,2,'centerOnT0',centerAt,'timeOutMode',timeOut);
%             out5s=nirsAvg(outputFirst30Seconds,5,'centerOnT0',centerAt,'timeOutMode',timeOut);
%             out10s=nirsAvg(outputFirst30Seconds,10,'centerOnT0',centerAt,'timeOutMode',timeOut);
% 
%             figure(1)
%             hold off
%             stairs(outputFirst30Seconds.time,outputFirst30Seconds.HbO(:,1))
%             hold on
% 
%             outputFirst30Seconds.time(1:10)
%             stairs(out1s.time,out1s.HbO(:,1))
%             hold on
%             fprintf('1s\n');
%             out1s.segmentTimes(1:2,:)
%             stairs(out2s.time,out2s.HbO(:,1))
%             fprintf('2s\n');
%             out2s.segmentTimes(1:2,:)
%             stairs(out5s.time,out5s.HbO(:,1))
%             fprintf('5s\n');
%             out5s.segmentTimes(1:2,:)
%             stairs(out10s.time,out10s.HbO(:,1))
%             fprintf('10s\n');
%             out10s.segmentTimes(1:2,:)
%             hold off
% 


%%