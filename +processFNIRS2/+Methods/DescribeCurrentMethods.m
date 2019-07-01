function [outputStr] = DescribeCurrentMethod(methodStage)

if(nargout==0)
    
if(nargin==0)
    processFNIRS2.Methods.Raw.DescribeMethod();
    processFNIRS2.Methods.Oxy.DescribeMethod();
else

    switch methodStage
        case 1
            processFNIRS2.Methods.Raw.DescribeMethod();
        case 'raw'
            processFNIRS2.Methods.Raw.DescribeMethod();
        case 2
            processFNIRS2.Methods.Oxy.DescribeMethod();
        case 'oxy'
            processFNIRS2.Methods.Oxy.DescribeMethod();
    end

end

elseif(nargout>0)
    if(nargin==0)
        outputStr=processFNIRS2.Methods.Raw.DescribeMethod();
        outputStr=sprintf('%s\n%s',outputStr,processFNIRS2.Methods.Oxy.DescribeMethod());
    else

        switch methodStage
            case 1
                outputStr=processFNIRS2.Methods.Raw.DescribeMethod();
            case 'raw'
                outputStr=processFNIRS2.Methods.Raw.DescribeMethod();
            case 2
                outputStr=processFNIRS2.Methods.Oxy.DescribeMethod();
            case 'oxy'
                outputStr=processFNIRS2.Methods.Oxy.DescribeMethod();
        end

    end
    
end

