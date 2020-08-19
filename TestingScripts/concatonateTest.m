% Load fNIRS files

clear all
x=pf2.Import.SampleData.Hitachi_ETG4000_3x5;
x2=pf2.Import.SampleData.fNIR1200;

% Set Start times to 0  
x=pf2(pf2.Data.SetT0(x,min(x.time)));
x2=pf2(pf2.Data.SetT0(x2,min(x2.time)));

%% Concatonate fNIRS Files
x3=pf2.Data.Concatonate(x,x2);

%% Plot Default


pf2.Data.Plot(x3)

%% Plot Raw

pf2.Data.Plot.Raw(x3)


%% Plot Oxy

%% Show only marker 1
pf2.Data.Plot.Oxy(x3,[],1)


%% Show all markers

pf2.Data.Plot.Oxy(x3)

%% Display concatonated data

pf2(x3);