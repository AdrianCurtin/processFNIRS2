function fNIR=editChannelMaskGUI(fNIR)

%This is a wrapper for ProbeCheckGUI
if(nargin<1)
    fNIR=probeCheckGUI('probeCheck',''); 
elseif(isstruct(fNIR))
    fNIR=probeCheckGUI(fNIR);
elseif(ischar(fNIR)||isstring(fNIR))
   fNIR=probeCheckGUI('probeCheck',fNIR); 
end