
function possibleStr=num2strOrNot(possibleStr)
if(iscell(possibleStr))
    for i=1:length(possibleStr)
       if(~ischar(possibleStr{i})&&isnumeric(possibleStr{i}))
            possibleStr{i}=num2str(possibleStr{i}); 
       end
    end
elseif(~ischar(possibleStr)&&isnumeric(possibleStr))
    possibleStr=num2str(possibleStr);
end
