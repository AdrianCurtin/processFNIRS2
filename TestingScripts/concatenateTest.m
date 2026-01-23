% Load fNIRS files

clear all
x=pf2.import.sampleData.Hitachi_ETG4000_3x5;
x2=pf2.import.sampleData.fNIR1200;

% Set Start times to 0  
x=pf2(pf2.data.setT0(x,min(x.time)));
x2=pf2(pf2.data.setT0(x2,min(x2.time)));

%% Concatenate fNIRS Files
x3=pf2.data.concatenate(x,x2);

%% Plot Default


pf2.data.plot(x3)

%% Plot Raw

pf2.data.plot.raw(x3)


%% Plot Oxy

%% Show only marker 1
pf2.data.plot.oxy(x3,[],1)


%% Show all markers

pf2.data.plot.oxy(x3)

%% Display concatenated data

pf2(x3);