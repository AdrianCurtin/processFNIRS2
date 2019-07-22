function y = filtfilt_interp(b,a,x)

%interpolates values and then filters and deletes values afterwards

isNanArr=(isnan(x));

minFilt=5;

for i=1:size(x,2)
	if(sum(~isnan(x(:,i)))<minFilt)
		continue;
	end

	xIdx=1:size(isNanArr,1);
	nanIdx=xIdx(isNanArr(:,i));
	xGoodIdx=xIdx(~isNanArr(:,i));
		
	x(nanIdx,i) = interp1(xGoodIdx,x(~isNanArr(:,i),i),nanIdx);
end

y=filtfilt(b,a,x);

y(isNanArr)=nan;

