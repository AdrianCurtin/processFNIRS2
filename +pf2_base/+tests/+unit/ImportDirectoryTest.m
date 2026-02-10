classdef ImportDirectoryTest < matlab.unittest.TestCase
% IMPORTDIRECTORYTEST Unit tests for pf2.import.importDirectory
%
% Tests recursive file discovery, directory-to-info field mapping,
% and error handling for the batch import function.
%
% Usage:
%   results = runtests('pf2_base.tests.unit.ImportDirectoryTest');
%
% See also: pf2.import.importDirectory

    properties (Access = private)
        RawData       % Sample data for export to temp dirs
        TempRoot      % Root temp directory for test trees
        ProjectRoot   % Project root path
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.ProjectRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            try
                testCase.RawData = pf2.import.sampleData.fNIR2000();
            catch e
                testCase.assumeFail(sprintf('Failed to load sample data: %s', e.message));
            end
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.TempRoot = tempname;
            mkdir(testCase.TempRoot);
        end
    end

    methods (TestMethodTeardown)
        function teardownMethod(testCase)
            if isfolder(testCase.TempRoot)
                rmdir(testCase.TempRoot, 's');
            end
        end
    end

    methods (Test)
        function testFindsFilesInSubdirectories(testCase)
            % Files at depth 2 should be found (the original bug)
            root = testCase.TempRoot;
            mkdir(fullfile(root, 'GroupA', 'S01'));
            mkdir(fullfile(root, 'GroupA', 'S02'));

            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'GroupA', 'S01', 'data.snirf'));
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'GroupA', 'S02', 'data.snirf'));

            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            allData = pf2.import.importDirectory(root, '*.snirf', 'Verbose', false);
            testCase.verifyLength(allData, 2);
        end

        function testFindsFilesAtMultipleDepths(testCase)
            % Files at both depth 1 and depth 2 should be found
            root = testCase.TempRoot;
            mkdir(fullfile(root, 'GroupA'));
            mkdir(fullfile(root, 'GroupA', 'S01'));

            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'GroupA', 'top.snirf'));
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'GroupA', 'S01', 'deep.snirf'));

            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            allData = pf2.import.importDirectory(root, '*.snirf', 'Verbose', false);
            testCase.verifyLength(allData, 2);
        end

        function testDirFieldMapping(testCase)
            % Dir1/Dir2 should map directory names to .info fields
            root = testCase.TempRoot;
            mkdir(fullfile(root, 'Control', 'P001'));
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'Control', 'P001', 'data.snirf'));

            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            allData = pf2.import.importDirectory(root, '*.snirf', ...
                'Dir1', 'Group', 'Dir2', 'SubjectID', 'Verbose', false);

            testCase.verifyLength(allData, 1);
            testCase.verifyEqual(allData{1}.info.Group, 'Control');
            testCase.verifyEqual(allData{1}.info.SubjectID, 'P001');
        end

        function testDirFieldMappingMultipleGroups(testCase)
            % Multiple groups with multiple subjects
            root = testCase.TempRoot;
            mkdir(fullfile(root, 'Control', 'P001'));
            mkdir(fullfile(root, 'Experimental', 'P002'));
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'Control', 'P001', 'data.snirf'));
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'Experimental', 'P002', 'data.snirf'));

            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            allData = pf2.import.importDirectory(root, '*.snirf', ...
                'Dir1', 'Group', 'Dir2', 'SubjectID', 'Verbose', false);

            testCase.verifyLength(allData, 2);

            groups = cellfun(@(d) d.info.Group, allData, 'UniformOutput', false);
            subjects = cellfun(@(d) d.info.SubjectID, allData, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(groups, 'Control')));
            testCase.verifyTrue(any(strcmp(groups, 'Experimental')));
            testCase.verifyTrue(any(strcmp(subjects, 'P001')));
            testCase.verifyTrue(any(strcmp(subjects, 'P002')));
        end

        function testFindsFilesInRootDir(testCase)
            % Files directly in the root should still be found
            root = testCase.TempRoot;
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'data.snirf'));

            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            allData = pf2.import.importDirectory(root, '*.snirf', 'Verbose', false);
            testCase.verifyLength(allData, 1);
        end

        function testErrorOnNoFilesFound(testCase)
            % Should error when no matching files exist
            root = testCase.TempRoot;
            testCase.verifyError(@() pf2.import.importDirectory(root, '*.snirf', 'Verbose', false), ...
                'pf2:importDirectory:noFilesFound');
        end

        function testErrorOnInvalidDirectory(testCase)
            % Should error when directory doesn't exist
            testCase.verifyError(@() pf2.import.importDirectory('/nonexistent/path', '*.snirf'), ...
                'pf2:importDirectory:notADirectory');
        end

        function testSourcePathPopulated(testCase)
            % Each imported struct should have .info.sourcePath
            root = testCase.TempRoot;
            mkdir(fullfile(root, 'GroupA'));
            pf2.export.asSNIRF(testCase.RawData, fullfile(root, 'GroupA', 'data.snirf'));

            oldDir = cd(testCase.ProjectRoot);
            restoreDir = onCleanup(@() cd(oldDir));

            allData = pf2.import.importDirectory(root, '*.snirf', 'Verbose', false);
            testCase.verifyTrue(isfield(allData{1}.info, 'sourcePath'));
            testCase.verifyTrue(contains(allData{1}.info.sourcePath, 'data.snirf'));
        end
    end
end
