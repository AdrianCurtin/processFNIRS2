function InstallMEX

global WAVELABPATH

MEX_OK = 1;

% MEX file names and their destination directories (relative to WAVELABPATH)
mexFiles = {
    'CPAnalysis',     'Packets/One-D';
    'WPAnalysis',     'Packets/One-D';
    'FWT_PO',         'Orthogonal';
    'FWT2_PO',        'Orthogonal';
    'IWT_PO',         'Orthogonal';
    'IWT2_PO',        'Orthogonal';
    'UpDyadHi',       'Orthogonal';
    'UpDyadLo',       'Orthogonal';
    'DownDyadHi',     'Orthogonal';
    'DownDyadLo',     'Orthogonal';
    'dct_iv',         'Packets/One-D';
    'FCPSynthesis',   'Pursuit';
    'FWPSynthesis',   'Pursuit';
    'dct_ii',         'Meyer';
    'dst_ii',         'Meyer';
    'dct_iii',        'Meyer';
    'dst_iii',        'Meyer';
    'FWT_PBS',        'Biorthogonal';
    'IWT_PBS',        'Biorthogonal';
    'FWT_TI',         'Invariant';
    'IWT_TI',         'Invariant';
    'FMIPT',          'Median';
    'IMIPT',          'Median';
    'FAIPT',          'Papers/MIPT';
    'IAIPT',          'Papers/MIPT';
    'LMIRefineSeq',   'Papers/MIPT';
    'MedRefineSeq',   'Papers/MIPT';
};

% Check if all MEX files are available for the current architecture
for k = 1:size(mexFiles, 1)
    if exist(mexFiles{k, 1}, 'file') ~= 3
        fprintf('Could not find MEX file for %s\n', mexFiles{k, 1});
        MEX_OK = 0;
        break;
    end
end

if MEX_OK
    return;
end

% Determine whether to compile
if batchStartupOptionUsed
    doInstall = true;
else
    disp('WaveLab detects that some MEX files are not installed for this architecture.');
    R = input('Install them now? [[Yes]/No] ', 's');
    doInstall = isempty(R) || any(strcmpi(R, {'yes', 'y'}));
end

if ~doInstall
    return;
end

fprintf('Compiling WaveLab MEX files for %s ...\n', computer('arch'));

origDir = pwd;
srcDir = fullfile(WAVELABPATH, 'MEXSource');
cd(srcDir);

nCompiled = 0;
nFailed = 0;
for k = 1:size(mexFiles, 1)
    name = mexFiles{k, 1};
    destRel = mexFiles{k, 2};
    srcFile = fullfile(srcDir, [name '.c']);
    destDir = fullfile(WAVELABPATH, destRel);

    % Skip if already compiled for this architecture
    if exist(name, 'file') == 3
        continue;
    end

    if ~isfile(srcFile)
        fprintf('  [skip] %s.c not found\n', name);
        continue;
    end

    try
        fprintf('  Compiling %s.c ...', name);
        mex(srcFile, '-outdir', destDir);
        fprintf(' OK\n');
        nCompiled = nCompiled + 1;
    catch ME
        fprintf(' FAILED: %s\n', ME.message);
        nFailed = nFailed + 1;
    end
end

cd(origDir);
fprintf('WaveLab MEX compilation: %d compiled, %d failed, %d already present\n', ...
    nCompiled, nFailed, size(mexFiles, 1) - nCompiled - nFailed);

%
%  Part of Wavelab Version 850
%  Built Tue Jan  3 13:20:38 EST 2006
%  This is Copyrighted Material
%  For Copying permissions see COPYING.m
%  Comments? e-mail wavelab@stat.stanford.edu
