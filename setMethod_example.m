function method=setMethod(method)

if(nargin<1)
    method=-1; %by default initailize everything
end

if(method==-1)
        processFNIRS2('UseDeviceCFG','device_fNIR1200.cfg'); %Load the default device configureation here from current then  common directory (or absolute)
		processFNIRS2('ImportRawMethods','pf2_methods_myRawMethods.cfg');
		processFNIRS2('ImportOxyMethods','pf2_methods_myOxyMethods.cfg');
		processFNIRS2('blLength',0); %use global mean for import
        %processFNIRS2('OutputLegacyMarkers',true); %use to leave markers in .markers.data instead of just .markers
end



switch(method)
    case -1  %%Import
        processFNIRS2('Raw_Method','None','Oxy_Method','None'); 
    case 0  %%Nothing
        processFNIRS2('Raw_Method','None','Oxy_Method','None');  

    case 1  %%Only LPF
        processFNIRS2('Raw_Method','x1_lpf','Oxy_Method','None');  
        
    case 2  %LPF and SMAR
        processFNIRS2('Raw_Method','x2_lpf_smar','Oxy_Method','medfilt');  

    case 3  %bandpass & SMAR
        processFNIRS2('Raw_Method','x3_bpf_smar','Oxy_Method','medfilt');  
        
    case 4  %LPF & SMAR & CAR
        processFNIRS2('Raw_Method','x2_lpf_smar','Oxy_Method','medfilt_car');  
        
    case 5  %LPF & MARA 
        processFNIRS2('Raw_Method','x6_lpf_MARA','Oxy_Method','medfilt'); 
        
    case 6  %LPF & MARA & CAR
        processFNIRS2('Raw_Method','x6_lpf_MARA','Oxy_Method','medfilt_car'); 
        
    case 7  %LPF & TDRR 
        processFNIRS2('Raw_Method','x6_lpf_TDRR','Oxy_Method','medfilt'); 
        
    case 8  %LPF & TDRR & CAR
        processFNIRS2('Raw_Method','x6_lpf_TDRR','Oxy_Method','medfilt_car'); 
        
    case 9  %LPF & SMAR-SR
        processFNIRS2('Raw_Method','x6_lpf_SMAR_SR','Oxy_Method','medfilt'); 
        
    case 10  %LPF & SMAR-SR & CAR
        processFNIRS2('Raw_Method','x6_lpf_SMAR_SR','Oxy_Method','medfilt_car'); 

        
    case 22  %lpf & SMAR (for alternate VFT baseline)
        processFNIRS2('Raw_Method','x2_lpf_smar','Oxy_Method','medfilt');  
        
    case 23  %bandpass & SMAR (for alternate VFT baseline)
        processFNIRS2('Raw_Method','x3_bpf_smar','Oxy_Method','medfilt'); 
        
    case 24  %lpf & SMAR (for alternate VFT baseline)
        processFNIRS2('Raw_Method','x2_lpf_smar','Oxy_Method','medfilt_car');
end