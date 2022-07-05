function handles = barweb(barvalues, errors, width, groupnames, bw_title, bw_xlabel, bw_ylabel, bw_colormap, gridstatus, bw_legend, error_sides, legend_type,error_is_y,data_points,hideBar)

%
% Usage: handles = barweb(barvalues, errors, width, groupnames, bw_title, bw_xlabel, bw_ylabel, bw_colormap, gridstatus, bw_legend, error_sides, legend_type)
%
% Ex: handles = barweb(my_barvalues, my_errors, [], [], [], [], [], bone, [], bw_legend, 1, 'axis')
%
% barweb is the m-by-n-by-o matrix of barvalues to be plotted.
% m groups, n bars (per group), o can be 3 points(min, mid/summary, max), or 2points (min, max),
%     or 1 point for just mid/summary
% barweb calls the MATLAB bar function and plots m groups of n bars using the width and bw_colormap parameters.
% If you want all the bars to be the same color, then set bw_colormap equal to the RBG matrix value ie. (bw_colormap = [1 0 0] for all red bars)
% barweb then calls the MATLAB errorbar function to draw barvalues with error bars of length error.
% groupnames is an m-length cellstr vector of groupnames (i.e. groupnames = {'group 1'; 'group 2'}).  For no groupnames, enter [] or {}
% The errors matrix is of the same form of the barvalues matrix, namely m group of n errors.
% Gridstatus is either 'x','xy', 'y', or 'none' for no grid.
% No legend will be shown if the legend paramter is not provided
% 'error_sides = 2' plots +/- std while 'error_sides = 1' plots just + std
% legend_type = 'axis' produces the legend along the x-axis while legend_type = 'plot' produces the standard legend.  See figure for more details
%
% The following default values are used if parameters are left out or skipped by using [].
% width = 1 (0 < width < 1; widths greater than 1 will produce overlapping bars)
% groupnames = '1', '2', ... number_of_groups
% bw_title, bw_xlabel, bw_ylabel = []
% bw_color_map = jet
% gridstatus = 'none'
% bw_legend = []
% error_sides = 2;
% legend_type = 'plot';
%
% A list of handles are returned so that the user can change the properties of the plot
% handles.ax: handle to current axis
% handles.bars: handle to bar plot
% handles.errors: a vector of handles to the error plots, with each handle corresponding to a column in the error matrix
% handles.legend: handle to legend
%
%
% See the MATLAB functions bar and errorbar for more information
%
% Author: Bolu Ajiboye
% Created: October 18, 2005 (ver 1.0)
% Updated: Dec 07, 2006 (ver 2.1)
% Updated: July 21, 2008 (ver 2.3)

% Get function arguments
BottomError=true;


if nargin < 1
	error('Must have at least the first argument:  barweb(barvalues, errors, width, groupnames, bw_title, bw_xlabel, bw_ylabel, bw_colormap, gridstatus, bw_legend, barwebtype)');
elseif(nargin<2)
    errors=[];
end

if (nargin<3)
    width=1;
end

if(nargin<4)
    groupnames=1:size(barvalues,1);
end

if(nargin<5)
    bw_title = [];
end

if(nargin<6)
    bw_xlabel=[];
end

if(nargin<7)
    bw_ylabel = [];
end

if(nargin<8)
    bw_colormap=jet;
end

if(nargin<9)
    gridstatus='none';
end

if(nargin<10)
    bw_legend = [];
end

if(nargin<11)
    error_sides = 2;
end

if(nargin<12)
    legend_type = 'plot';
end

if(nargin<13)
    error_is_y=false;
end

if(nargin<14)
    dataPoints=[];
end

if(nargin<15)
    hideBar=false;
    % show point instead of bar (with errorbars)
    % not implemented yet
end


change_axis = 0;
ymax = 0;

if(isempty(errors))
    errors=nan(size(barvalues));
end

if size(barvalues,1) ~= size(errors,1) || size(barvalues,2) ~= size(errors,2)
	error('barvalues and errors matrix must be of same dimension');
else
	if size(barvalues,2) == 1 && size(barvalues,1)~=length(groupnames)&&~isempty(groupnames)
        warning('Mismatch between groupnames and columns, assuming data is transposed');
		barvalues = barvalues';
		errors = errors';
    end

    
    errorVals=size(errors,3);
    if(errorVals==1)
        errorsLower=errors(:,:,1)*BottomError;
        errorsUpper=errors(:,:,1);
    elseif(errorVals>1)
        errorsLower=errors(:,:,1);
        errorsUpper=errors(:,:,2);

        error_is_y=true;
    end

    

    if(errorVals>2)
        barLower=errors(:,:,3);
        reDrawAsReactangles=true;
        hideBar=true;
    else
        barLower=zeros(size(barvalues));
        reDrawAsReactangles=false;
        hideBar=false;
    end

    if(errorVals>3)
        barUpper=errors(:,:,4);
    else
        barUpper=barvalues;
    end

    if(errorVals>4)
        barMids=errors(:,:,5);
    else
        barMids=barvalues;
    end

    if(error_is_y)
        errorsLower=barvalues-errorsLower;
        errorsUpper=errorsUpper-barvalues;
    end


	if size(barvalues,1) == 1
		barvalues = [barvalues; zeros(1,length(barvalues))];
		errors = [errors; zeros(1,size(barvalues,2))];
		change_axis = 1;
    end

	numgroups = size(barvalues, 1); % number of groups
	numbars = size(barvalues, 2); % number of bars in a group
	if isempty(width)
		width = 1;
	end
	
	% Plot bars
    % (even if invisible, we use for the xpoints)
    handles.bars = bar(barvalues, width,'edgecolor','k', 'linewidth', 2);
    
	hold on
	if ~isempty(bw_colormap)
		colormap(bw_colormap);
	else
		colormap(jet);
	end
	if ~isempty(bw_legend) && ~strcmp(legend_type, 'axis')&&strcmp(legend_type,'plot')
		handles.legend = legend(bw_legend, 'location', 'best', 'fontsize',12);
		legend boxoff;
	else
		handles.legend = [];
    end
	
%     if(numgroups==1&&numbars==2)
%         barvalues=[barvalues;barvalues];
%     end

    xOffsets=nan([1,numbars]);
    for i=1:numbars
        xOffsets(i)=handles.bars(i).XOffset;   
    end

    barW=mean(diff(xOffsets));
    if(isnan(barW))
        barW=0.75;
    else
        barW=barW*0.75;
    end
    
	% Plot errors + assign colors
	for i = 1:numbars 
        x = bsxfun(@plus, handles.bars(i).XData, [handles.bars(i).XOffset]'); 

        if ~isempty(bw_colormap)
            newI=rem(i,length(bw_colormap(:,1)));
            if(newI==0)
                newI=length(bw_colormap(:,1));
            end
            curColor=bw_colormap(newI,:);
        else
            curColor=[0,0,0];
        end
        
        if(hideBar&&~reDrawAsReactangles)
            handles.errors(i) = errorbar(x, barvalues(:,i), errorsLower(:,i), 'Color',curColor, 'linestyle', 'none', 'linewidth', 3); 
        else
            % otherwise we draw errors last
            handles.errors(i) = errorbar(x, barvalues(:,i), errorsLower(:,i),errorsUpper(:,i), 'k', 'linestyle', 'none', 'linewidth', 1); 
       
        end

        
        

        if ~isempty(bw_colormap)&&~hideBar
                handles.bars(i).FaceColor=curColor;
                if(length(bw_legend)>=i&&~isempty(bw_legend{i}))
                    set(handles.bars(i),'Tag',bw_legend{i});
                end
        elseif(hideBar)
            set(handles.bars(i),'Visible',false);
            if(reDrawAsReactangles)
                for ii=1:length(x)

                    h1=abs(barUpper(ii,i)-barMids(ii,i));
                    h2=abs(barMids(ii,i)-barLower(ii,i));

                    baseY1=min([barUpper(ii,i),barMids(ii,i)]);
                    baseY2=min([barMids(ii,i),barLower(ii,i)]);

                    if(h1>0)
                        handles.rectangles(i,ii,1)=rectangle('position',[x(ii)-barW/2,baseY1, barW, h1]);
                        if ~isempty(bw_colormap)
                            handles.rectangles(i,ii,1).FaceColor=curColor; 
                            handles.rectangles(i,ii,1).LineWidth=2; 
                        end
                    end
                    if(h2>0)
                        handles.rectangles(i,ii,2)=rectangle('position',[x(ii)-barW/2,baseY2, barW, h2]);
                        if ~isempty(bw_colormap)
                            handles.rectangles(i,ii,2).FaceColor=curColor; 
                            handles.rectangles(i,ii,2).LineWidth=2; 
                        end
                    end

                    
                end
                
            else
                if ~isempty(bw_colormap)
                  
                    handles.statpoints(i)=plot(x(1),barvalues(1,i),'Marker','.');
                    handles.statpoints(i).MarkerSize=32;
                    handles.statpoints(i).MarkerEdgeColor=curColor; 
                    handles.statpoints(i).MarkerFaceColor=curColor; 
                    
                    
                    if(length(bw_legend)>=i&&~isempty(bw_legend{i}))
                        set(handles.statpoints(i),'Tag',bw_legend{i});
                    end
                end 
            end
        end
        
        

        if(length(bw_legend)>=i&&~isempty(bw_legend{i}))
            set(handles.errors(i),'Tag',bw_legend{i});
        end
        set(handles.errors(i),'HandleVisibility','off');
        
        nonNanErrors=errors;
        nonNanErrors(isnan(errors))=0;
        ymax = nanmax([ymax; barvalues(:,i)+nonNanErrors(:,i)]); 
        ymin=nanmin(barvalues(:,i)-nonNanErrors(:,i));
	end
	
	if error_sides == 1
		set(gca,'children', flipud(get(gca,'children')));
    end
	
    if ymin>0||isnan(ymin)
        ymin=0;
    end
    if(ymin~=ymax)
        if(ymax==ymin||isnan(ymax))
            ymax=ymin+0.0001;
            warning('Invalid data');
        end
        if(ymin>ymax)
           temp=ymin;
           ymin=ymax;
           ymax=temp;
        end
        ylim([ymin ymax*1.1]);
    end
    
    if(numbars==1&&change_axis)
        xlim([0.25 numgroups-change_axis+0.75]);    
    else
        xlim([0.5 numgroups-change_axis+0.5]);
    end
    
	if strcmp(legend_type, 'axis')
		for i = 1:numbars
			xdata = get(handles.errors(i),'xdata');
			for j = 1:length(xdata)
				text(xdata(j),  -0.03*ymax*1.1, bw_legend(i), 'Rotation', 60, 'fontsize', 12, 'HorizontalAlignment', 'right');
			end
		end
		set(gca,'xaxislocation','top');
	end
	
	if ~isempty(bw_title)
		title(bw_title, 'fontsize',14);
	end
	if ~isempty(bw_xlabel)
		xlabel(bw_xlabel, 'fontsize',14);
	end
	if ~isempty(bw_ylabel)
		ylabel(bw_ylabel, 'fontsize',14);
	end
	
	set(gca, 'xticklabel', groupnames, 'box', 'off', 'ticklength', [0 0], 'fontsize', 12, 'xtick',1:numgroups, 'linewidth', 2,'xgrid','off','ygrid','off');
	if ~isempty(gridstatus) && any(gridstatus == 'x')
		set(gca,'xgrid','on');
	end
	if ~isempty(gridstatus) && any(gridstatus ==  'y')
		set(gca,'ygrid','on');
	end
	
	handles.ax = gca;
	
	hold off
end