function [colormapNames] = listColormaps(colormapType)
if(nargin<1)
    colormapType='qualitative';
end
%LISTCOLORMAPS Given a colormap type, lists colormaps

brewerBuiltin={'BrBG','Accent','BluesPuBuGn','PiYG','Dark2','BuGnPuRd','PRGn','Paired','BuPuPurples','PuOr','Pastel1','GnBuRdPu','RdBu','Pastel2','GreensReds','RdGy','Set1','GreysYlGn','RdYlBu','Set2','OrRdYlGnBu','RdYlGn','Set3','OrangesYlOrBr','Spectral','PuBuYlOrRd'};
matlabBuiltin={'parula','turbo','hsv','hot','cool','spring','summer','autumn','winter','gray','bone','copper','pink','jet','lines','colorcube','prism','flag','white'};
matplotlibBuiltin={'cividis','inferno','magma','plasma','tab10','tab20','tab20b','tab20c','twilight','twilight_shifted','viridis'};


matlabQualitativeTypes={'lines','colorcube','prism','flag'};
brewerQualitative={'Accent','Dark2','Paired','Pastel1','Pastel2','Set1','Set2','Set3'};
matplotlibQualitative={'tab10','tab20','tab20b','tab20c'};

qualitativeTypes=[matlabQualitativeTypes(1),brewerQualitative,matplotlibQualitative,matlabQualitativeTypes(2:end)];

matlabSequentialTypes={'parula','turbo','hsv','hot','cool','spring','summer','autumn','winter','gray','bone','copper','pink'};
brewerSequential={'Blues','BuGn','BuPu','GnBu','Greens','Greus','OrRd','Oranges','PuBu','PuBuGn','PuRd','Purples','RdPu','Reds','YlGn','YlGnBu','YlOrBr','YlOrRd'};
matplotlibSequential={'viridis','inferno','plasma','cividis'};
sequentialTypes=[matlabSequentialTypes,brewerSequential,matplotlibSequential];

matlabDivergingTypes={'cool'};
brewerDivergingTypes={'BrBG','PiYG','PRGn','PuOr','RdBu','RdGy','RdYlBu','RdYlGn','Spectral'};
matplotlibDiverging={'twilight','twilight_shifted'};
divergingTypes=[matlabDivergingTypes,brewerDivergingTypes,matplotlibDiverging];

switch(colormapType)
    case 'qualitative'
        colormapNames=qualitativeTypes;
    case 'diverging'
        colormapNames=divergingTypes;
    case 'sequential'
        colormapNames=sequentialTypes;
    case 'all'
        colormapNames=[qualitativeTypes,divergingTypes,sequentialTypes];
    otherwise
        error('Please specify: qualitative,diverging,sequantial, or all');
end

