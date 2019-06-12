function [ oxy , bv805 , bv , HBO , HBR] = bvoxy ( var1 , var2 , var3, var4 , var5, var6 , var7 )
%function [ HBO , bv805 , HBR ] = bvoxy ( var1 , var2 , var3, var4 , var5, var6 , var7 )
%BVOXY   Blood Volume and Oxygenation calculation.
% [ BV , BV805 , OXY ] = BVOXY(BS,BE,W730,W805,W850) returns Blood Volume,
% Blood Volume directly calculated from the wavelength 805 and Oxygenation
% from the baseline start (BS), the baseline end (BE) and the matrix of the
% three wavelength W730, W805, W850.
%
% [ BV , BV805 , OXY ] = BVOXY(B730,B805,B850,W730,W805,W850) returns Blood Volume,
% Blood Volume directly calculated from the wavelength 805 and Oxygenation from the
% matrix of the baseline for the three wavelength B730, B805 and B850 and the matrix
% of the three wavelength W730, W805, W850.
%
% [ BV , BV805 , OXY ] = BVOXY(BS,BE,SS,SE,W730,W805,W850) returns Blood Volume,
% Blood Volume directly calculated from the wavelength 805 and Oxygenation from the
% baseline start BE, baseline end BE, the sample start SS, sample end SE and the
% matrix of the three wavelength W730, W805, W850.



% 4 entiers (bs,be,ss,se), 3 matrices -> 7 var  ( bs , be , ss , se , w730 , w805 , w850 )

switch nargin
    
	case 5;
        
        bs = var1;
        be = var2;
        ss = 1;
        se = size(var3,1);
        w730 = var3;
        w805 = var4;
        w850 = var5;
        
	case 6;
        
        bs = 1;
        be = size(var1,1);
        ss = be+1;
        se = be+size(var4,1);
        w730 = [ var1 ; var4 ];
        w805 = [ var2 ; var5 ];
        w850 = [ var3 ; var6 ];
        
	case 7;
        
        bs = var1;
        be = var2;
        ss = var3;
        se = var4;
        w730 = var5;
        w805 = var6;
        w850 = var7;
    
end;

% bs = baseline start;
% be = baseline end;
% ss = sample start;
% se = sample end;

% Calcul of the Baseline Vectors
Baseline_730 = mean (w730(bs:be,:));
Baseline_805 = mean (w805(bs:be,:));
Baseline_850 = mean (w850(bs:be,:));

% Optical Density Matrices

Baseline_730 = ones(se-ss+1,1)*Baseline_730;
Baseline_805 = ones(se-ss+1,1)*Baseline_805;
Baseline_850 = ones(se-ss+1,1)*Baseline_850;


OD_730 = - log10 (w730(ss:se,:)./Baseline_730);
OD_805 = - log10 (w805(ss:se,:)./Baseline_805);
OD_850 = - log10 (w850(ss:se,:)./Baseline_850);


      eHBR_730=1.1022;       %
      eHBO_730=0.390;      %  
      eHBR_805=0.73708;      %   saturation coefficients
      eHBO_805=0.836;      %
      eHBR_850=0.69132;      %
      eHBO_850=1.058;      %
            
     %HBR is the variation of the concentration in hemglobin 
     
     L= 0.015; %pathlength factor
     
 HBR=(OD_850*eHBO_730-OD_730*eHBO_850)/(eHBO_730*eHBR_850-eHBO_850*eHBR_730)/L;
  
      %HBR is the variation of the concentration in oxyhemoglobin
            
 HBO=(OD_730*eHBR_850-OD_850*eHBR_730)/(eHBO_730*eHBR_850-eHBO_850*eHBR_730)/L;
      
      
      
 bv=(HBO+HBR);                             % Blood Volume                             
 bv805=OD_805/(eHBR_805+eHBO_805)/L;   % Blood Volume directly from the wavelength 805
 oxy=(HBO-HBR);
