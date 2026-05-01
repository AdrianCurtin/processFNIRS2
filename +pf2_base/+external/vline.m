function hhh=vline(varargin)
% function h=vline(x, lineVarargin, lineLabels)
% 
% Draws a vertical line on the current axes at the location specified by 'x'.  Optional arguments are
% 'linetype' (default is 'r:') and 'label', which applies a text label to the graph near the line.  The
% label appears in the same color as the line.
%
% The line is held on the current axes, and after plotting the line, the function returns the axes to
% its prior hold state.
%
% The HandleVisibility property of the line object is set to "off", so not only does it not appear on
% legends, but it is not findable by using findobj.  Specifying an output argument causes the function to
% return a handle to the line, so it can be manipulated or deleted.  Also, the HandleVisibility can be 
% overridden by setting the root's ShowHiddenHandles property to on.
%
% h = vline(42,'g','The Answer')
%
% returns a handle to a green vertical line on the current axes at x=42, and creates a text object on
% the current axes, close to the line, which reads "The Answer".
%
% vline also supports vector inputs to draw multiple lines at once.  For example,
%
% vline([4 8 12],{'g','r','b'},{'l1','lab2','LABELC'})
%
% draws three lines with the appropriate labels and colors.
% 
% By Brandon Kuczenski for Kensington Labs.
% brandon_kuczenski@kensingtonlabs.com
% 8 November 2001

% Modified by Adrian Curtin
% To allow multiple arguments and not fail when empty

validX= @(x) isempty(x)||isnumeric(x)||isdatetime(x)||isduration(x);
validAxesHandle= @(x) isa(x,'matlab.graphics.axis.Axes')&&isvalid(x);
% Accept linespec ('r:'), cells of options ({'Color',[0 0 0]}), or RGB triple/quad.
validStrCell = @(x) ischar(x) || iscell(x) || ...
    (isnumeric(x) && isvector(x) && (numel(x)==3 || numel(x)==4));
validHeight= @(x) isnumeric(x)&&~isempty(x);

if(isa(varargin{1},'matlab.graphics.axis.Axes')) %If first argument is axes then move to front
   ax=varargin{1};
   varargin=varargin(2:end);
else
   ax=gca;
end

p=inputParser;

addRequired(p,'x',validX);
addOptional(p,'lineVarargin','r:',validStrCell);
addOptional(p,'lineLabels',cell(0),validStrCell);
addOptional(p,'lineLabelHeights',0.1,validHeight);
addParameter(p,'ax',ax,validAxesHandle,'PartialMatchPriority',1);
addParameter(p,'lineTags',cell(0),validStrCell,'PartialMatchPriority',2);
addParameter(p,'handleVisibility',true,@islogical,'PartialMatchPriority',3);

parse(p,varargin{:});

x=p.Results.x;
lineVarargin=p.Results.lineVarargin;
lineLabels=p.Results.lineLabels;
lineTags=p.Results.lineTags;
lineLabelHeights=p.Results.lineLabelHeights;
ax=p.Results.ax;
handleVisibility=p.Results.handleVisibility;

if(~isempty(lineTags)&&(ischar(lineTags)||isstring(lineTags)))
   lineTags=cellstr(lineTags); 
end


if isempty(x)
    hhh=[];
    return;
end
    
% Translate a bare numeric color (RGB[A] triple/quad) into a Name-Value
% pair that plot() accepts. Otherwise wrap as {linespec}.
if isnumeric(lineVarargin) && isvector(lineVarargin) && ...
        (numel(lineVarargin)==3 || numel(lineVarargin)==4)
    lineVarargin = {'Color', lineVarargin};
elseif ~iscell(lineVarargin)
    lineVarargin = {lineVarargin};
end

if ~iscell(lineLabels)
    lineLabels={lineLabels};
end

x=x(:);
numLines=length(x);
hh=cell(numLines,1);

for lineNum=1:numLines
    xVal=x(lineNum);
    if numLines==size(lineVarargin,1)
        linetype=lineVarargin(lineNum,:);
    elseif(size(lineVarargin,1)>=lineNum)
        linetype=lineVarargin(lineNum,:);
    else
        linetype=lineVarargin(1,:);
    end
       
    if(~isempty(lineLabels))
        if(length(lineLabels)==1)
            label=lineLabels{1};
            if(isnumeric(label))
                label=num2str(label);
            end
            
        elseif(length(lineLabels)>=lineNum)
            label=lineLabels{lineNum};
            if(isnumeric(label))
                label=num2str(label);
            end
        else
            label=[];
        end
        
        if(isempty(lineTags))
           lineTag=label; 
        end
    else
        label=[];
        lineTag='vline';
    end
    
    if(~isempty(lineTags))
        if(length(lineTags)==1)
            lineTag=lineTags{1};
        elseif(length(lineTags)>=lineNum)
            lineTag=lineTags{lineNum};
        else
            lineTag='vline';
        end
    end
    
    if(length(lineLabelHeights)==1)
        yLabelHeight=lineLabelHeights;
    elseif(length(lineLabelHeights)>=lineNum)
        yLabelHeight=lineLabelHeights(lineNum);
    else
        yLabelHeight=0.1;
    end
    yLabelHeight=max(0,min(1,yLabelHeight));
    
    
    g=ishold(ax);
    hold(ax,'on');

    y=get(ax,'ylim');
    h=plot(ax,[xVal xVal],y,linetype{:});
    if ~isempty(label)
        if(isnumeric(label))
            label=num2str(label);
        end
        
        xx=get(ax,'xlim');
        xrange=xx(2)-xx(1);
        yrange=y(2)-y(1);
        xunit=(xVal-xx(1))/xrange;
        if xunit<0.8
            text(ax,xVal+0.01*xrange,y(1)+yLabelHeight*yrange,label,'color',get(h,'color'))
        else
            text(ax,xVal-.05*xrange,y(1)+yLabelHeight*yrange,label,'color',get(h,'color'))
        end
    end     

    if g==0
        hold(ax,'off');
    end
    set(h,'tag',lineTag);
    if(~handleVisibility)
        set(h,'handlevisibility','off');
    end
    hh(lineNum)={h};
end % else

if(nargout&&length(hh)==1)
    hhh=h;
elseif(nargout)
    hhh=hh;
end
