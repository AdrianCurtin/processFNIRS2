function handles=PF2Analyze(fNIR,handlesIn)
%Callback function sample code for PF2Analyze() button
% Adapt to allow visualization of processing beyond oxy filtering

if(nargin<2)
   handles=handlesIn;
else
   handles=[]; 
end

%Do stuff here

if(~isempty(handles)&&isvalid(handles))
    handles=figure(505);
else
    set(0, 'currentfigure', handles);
end



end