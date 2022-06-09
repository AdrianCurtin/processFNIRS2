function [colormapOut] = getColormap(colormapString)
%GETCOLORMAP given an input string, returns a string to the appropriate
%   allows extensible plotting for colormaps
%   ex: 'lines' will

matlabBuiltin={'parula','turbo','hsv','hot','cool','spring','summer','autumn','winter','gray','bone','copper','pink','jet','lines','colorcube','prism','flag','white'};
if(contains(colormapString,matlabBuiltin))
    colormapOut=str2func(colormapString);
    return;
end

brewerBuiltin={'BrBG','Accent','BluesPuBuGn','PiYG','Dark2','BuGnPuRd','PRGn','Paired','BuPuPurples','PuOr','Pastel1','GnBuRdPu','RdBu','Pastel2','GreensReds','RdGy','Set1','GreysYlGn','RdYlBu','Set2','OrRdYlGnBu','RdYlGn','Set3','OrangesYlOrBr','Spectral','PuBuYlOrRd'};

if(contains(colormapString,brewerBuiltin))
    colormapOut=@(N)pf2_base.external.colormaps.brewermap(N,colormapString);
    return;
elseif(strcmp(colormapString,'brewermap'))
    colormapOut=@(N)pf2_base.external.colormaps.brewermap(N,'Set1');
    return;
end

matplotlibBuiltin={'cividis','inferno','magma','plasma','tab10','tab20','tab20b','tab20c','twilight','twilight_shifted','viridis'};

if(contains(colormapString,matplotlibBuiltin))
    colormapOut=str2func(strcat('@(N)pf2_base.external.colormaps.matplotlib.',colormapString,'(N)'));
    return;
elseif(strcmp(colormapString,'brewermap'))
    colormapOut=str2func('pf2_base.external.colormaps.matplotlib.tab10');
    return;
end

colormapOut=str2func('lines');
