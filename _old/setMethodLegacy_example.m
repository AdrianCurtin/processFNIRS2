function method=setMethodLegacy_example(method)

%Function sample code to set and define global variables for the legacy processfNIR script
%Use to set global vars for the processNIR script

if(nargin<1)
    method=6;
end
    
global set;

processfNIR();%initializes default filter values
                %View processfNIR to edit these values when using new
                %filters

switch(method)
    case -1  %%ICA for import
        set.f.icaDark.enable=false;
        set.f.subtractDark.enable=false;
        set.f.import=true;
    case 0  %%Nothing

    case 1 % LPF only
        set.f.smar.enable=true;
        set.f.lpf.enable=true;

    case 2 %BPF and smar %0.01
        set.f.bpf.enable=true;
        set.f.smar.enable=true;
        set.f.bpf.Lower=0.01; %High Pass

    case 3 %BPF and smar
        set.f.bpf.enable=true;
        set.f.smar.enable=true;
        set.f.bpf.Lower=0.025; %High Pass (should correspond to about 40 seconds

    case 4 %smar and LPF 
        set.f.bpf.enable=true;
        set.f.smar.enable=true;


    case 5 %smar and wavelet
        set.f.smar.enable=true;
        set.f.waveletDenoise.enable=true;

    case 6 %CAR and smar and wavelet
        set.f.smar.enable=true;
        set.f.waveletDenoise.enable=true;
        set.f.CAR.enable=true;
        
    case 7 %BPF only (0.25Hz)
        set.f.bpf.enable=true;
        set.f.smar.enable=true;
        set.f.bpf.Lower=0.01; %High Pass
        set.f.bpf.Upper=0.25;  %Low Pass 
        
    case 8 %BPF only (0.2Hz)
        set.f.bpf.enable=true;
        set.f.smar.enable=true;
        set.f.bpf.Lower=0.01; %High Pass
        set.f.bpf.Upper=0.2;  %Low Pass 

        
end