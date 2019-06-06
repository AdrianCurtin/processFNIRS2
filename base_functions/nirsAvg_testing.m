%% Loading data

[fNIR.raw,fNIR.mrk,~,fNIR.fchMask]=ImportNIR('sampleNIR.nir','sampleNIR.mrk');
processFNIRS2('UseDeviceCFG','device_fNIR1200.cfg');
processFNIRS2('Raw_Method','None','Oxy_Method','None');
fNIR.info.Age=25;
output=processFNIRS2(fNIR);


%%  Testing for nirsAvg
outputFirst30Seconds=getFNIRS(output,0,30,'relative',true);
lenTime=length(outputFirst30Seconds.time);
outputFirst30Seconds.HbO(:,1)=ceil((1:lenTime)/2);
outputFirst30Seconds.HbR(:,1)=ceil((1:lenTime)/2);

centerAt=false;
timeOut='mid';
out1s=nirsAvg(outputFirst30Seconds,1,'centerOnT0',centerAt,'timeOutMode',timeOut);
out2s=nirsAvg(outputFirst30Seconds,2,'centerOnT0',centerAt,'timeOutMode',timeOut);
out5s=nirsAvg(outputFirst30Seconds,5,'centerOnT0',centerAt,'timeOutMode',timeOut);
out10s=nirsAvg(outputFirst30Seconds,100,'centerOnT0',centerAt,'timeOutMode',timeOut);

figure(1)
hold off
stairs(outputFirst30Seconds.time,outputFirst30Seconds.HbO(:,1))
hold on

outputFirst30Seconds.time(1:10)
stairs(out1s.time,out1s.HbO(:,1))
hold on
fprintf('1s\n');
out1s.segmentTimes(1:2,:)
stairs(out2s.time,out2s.HbO(:,1))
fprintf('2s\n');
out2s.segmentTimes(1:2,:)
stairs(out5s.time,out5s.HbO(:,1))
fprintf('5s\n');
out5s.segmentTimes(1:2,:)
stairs(out10s.time,out10s.HbO(:,1))
fprintf('10s\n');
out10s.segmentTimes(1:2,:)
hold off
xlabel('time(s)')