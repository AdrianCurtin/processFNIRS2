function [outputStr] = DescribeCurrentMethod(methodStage)

if(nargout==0)
    
if(nargin==0)
    pf2.Methods.Raw.DescribeMethod();
    pf2.Methods.Oxy.DescribeMethod();
else

    switch methodStage
        case 1
            pf2.Methods.Raw.DescribeMethod();
        case 'raw'
            pf2.Methods.Raw.DescribeMethod();
        case 2
            pf2.Methods.Oxy.DescribeMethod();
        case 'oxy'
            pf2.Methods.Oxy.DescribeMethod();
    end

end

elseif(nargout>0)
    if(nargin==0)
        outputStr=pf2.Methods.Raw.DescribeMethod();
        outputStr=sprintf('%s\n%s',outputStr,pf2.Methods.Oxy.DescribeMethod());
    else

        switch methodStage
            case 1
                outputStr=pf2.Methods.Raw.DescribeMethod();
            case 'raw'
                outputStr=pf2.Methods.Raw.DescribeMethod();
            case 2
                outputStr=pf2.Methods.Oxy.DescribeMethod();
            case 'oxy'
                outputStr=pf2.Methods.Oxy.DescribeMethod();
        end

    end
    
end

