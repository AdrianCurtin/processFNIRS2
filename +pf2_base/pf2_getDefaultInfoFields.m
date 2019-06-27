function [outFields,defaultValues]=pf2_getDefaultInfoFields()

outFields={'SubjectID','Group','Session','Trial','Block','Condition','Age','Sex'};

subNum=round(rand(1)*1000);

defaultValues={sprintf('Unknown%i',subNum),'Unknown','Unknown','Unknown','Unknown','Unknown',[],'Unknown'};