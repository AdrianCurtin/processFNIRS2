function [qmf, wavename, desc] = resolveWavelet(name)
% RESOLVEWAVELET Map user-friendly wavelet name to an orthonormal QMF filter
%
% Converts shorthand wavelet names (e.g. 'db2', 'sym4', 'coif3') into
% the corresponding orthonormal QMF filter via
% pf2_base.wavelet.makeONFilter. The wavename output provides the equivalent
% MATLAB Wavelet Toolbox name (informational only — not required for
% processing, which uses the pf2_base.wavelet transforms exclusively).
%
% Syntax:
%   [qmf, wavename, desc] = pf2_base.wavelet.resolveWavelet(name)
%
% Inputs:
%   name - Wavelet shorthand string (case-insensitive). Supported:
%            'haar'             - Haar wavelet
%            'db2'..'db10'      - Daubechies (Par = vanishing_moments*2)
%            'sym4'..'sym10'    - Symmlet
%            'coif1'..'coif5'   - Coiflet
%            'beylkin'          - Beylkin 18-tap
%            'vaidyanathan'     - Vaidyanathan 24-tap
%            'battle1','battle3','battle5' - Battle-Lemarie spline
%
% Outputs:
%   qmf      - QMF filter vector from makeONFilter [1 x N double]
%   wavename - Equivalent MATLAB Wavelet Toolbox name (informational).
%              Empty for wavelets without a Toolbox equivalent
%              (beylkin, vaidyanathan, battle).
%   desc     - Human-readable description string for logging
%
% Example:
%   [qmf, wn, d] = pf2_base.wavelet.resolveWavelet('db4');
%   % qmf = pf2_base.wavelet.makeONFilter('Daubechies', 8), wn = 'db4'
%
% See also: pf2_base.wavelet.makeONFilter, pf2_MotionCorrectWavelet,
%   waveClean, pf2_kbWF

    name = lower(strtrim(name));

    % --- Daubechies: db2..db10 ---
    tok = regexp(name, '^db(\d+)$', 'tokens');
    if ~isempty(tok)
        vm = str2double(tok{1}{1});  % vanishing moments
        par = vm * 2;                % makeONFilter Par = filter length
        validPar = [4 6 8 10 12 14 16 18 20];
        if ~ismember(par, validPar)
            error('pf2_base:wavelet:invalidWavelet', ...
                'Daubechies ''db%d'' is not supported. Valid: db2,db3,db4,db5,db6,db7,db8,db9,db10.', vm);
        end
        qmf = pf2_base.wavelet.makeONFilter('Daubechies', par);
        wavename = sprintf('db%d', vm);
        desc = sprintf('Daubechies-%d (%d vanishing moments)', par, vm);
        return;
    end

    % --- Symmlet: sym4..sym10 ---
    tok = regexp(name, '^sym(\d+)$', 'tokens');
    if ~isempty(tok)
        par = str2double(tok{1}{1});
        validPar = 4:10;
        if ~ismember(par, validPar)
            error('pf2_base:wavelet:invalidWavelet', ...
                'Symmlet ''sym%d'' is not supported. Valid: sym4..sym10.', par);
        end
        qmf = pf2_base.wavelet.makeONFilter('Symmlet', par);
        wavename = sprintf('sym%d', par);
        desc = sprintf('Symmlet-%d (%d vanishing moments)', par, par);
        return;
    end

    % --- Coiflet: coif1..coif5 ---
    tok = regexp(name, '^coif(\d+)$', 'tokens');
    if ~isempty(tok)
        par = str2double(tok{1}{1});
        validPar = 1:5;
        if ~ismember(par, validPar)
            error('pf2_base:wavelet:invalidWavelet', ...
                'Coiflet ''coif%d'' is not supported. Valid: coif1..coif5.', par);
        end
        qmf = pf2_base.wavelet.makeONFilter('Coiflet', par);
        wavename = sprintf('coif%d', par);
        desc = sprintf('Coiflet-%d (%d vanishing moments)', par, 2*par);
        return;
    end

    % --- Battle-Lemarie: battle1, battle3, battle5 ---
    tok = regexp(name, '^battle(\d+)$', 'tokens');
    if ~isempty(tok)
        par = str2double(tok{1}{1});
        validPar = [1 3 5];
        if ~ismember(par, validPar)
            error('pf2_base:wavelet:invalidWavelet', ...
                'Battle-Lemarie ''battle%d'' is not supported. Valid: battle1, battle3, battle5.', par);
        end
        qmf = pf2_base.wavelet.makeONFilter('Battle', par);
        wavename = '';
        desc = sprintf('Battle-Lemarie (degree %d spline)', par);
        return;
    end

    % --- Haar ---
    if strcmp(name, 'haar')
        qmf = pf2_base.wavelet.makeONFilter('Haar');
        wavename = 'haar';
        desc = 'Haar wavelet';
        return;
    end

    % --- Beylkin ---
    if strcmp(name, 'beylkin')
        qmf = pf2_base.wavelet.makeONFilter('Beylkin');
        wavename = '';
        desc = 'Beylkin 18-tap filter';
        return;
    end

    % --- Vaidyanathan ---
    if strcmp(name, 'vaidyanathan')
        qmf = pf2_base.wavelet.makeONFilter('Vaidyanathan');
        wavename = '';
        desc = 'Vaidyanathan 24-tap filter';
        return;
    end

    % --- Unknown ---
    error('pf2_base:wavelet:unknownWavelet', ...
        'Unknown wavelet ''%s''. Supported: haar, db2-db10, sym4-sym10, coif1-coif5, beylkin, vaidyanathan, battle1/3/5.', name);
end
