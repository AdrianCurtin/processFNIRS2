classdef INIFileTest < matlab.unittest.TestCase
% INIFILETEST Round-trip tests for the clean-room INI reader/writer
%
% Validates pf2_base.external.INI: sections of varied value types are added,
% written to a temporary file, read back into a fresh object, and compared
% for equality. Also exercises whole-line and inline comments using the
% project's '%' comment character. Temporary files are removed on cleanup.

    properties
        TmpFile
    end

    methods (TestMethodSetup)
        function makeTempFile(tc)
            tc.TmpFile = [tempname, '.ini'];
        end
    end

    methods (TestMethodTeardown)
        function removeTempFile(tc)
            if ~isempty(tc.TmpFile) && exist(tc.TmpFile, 'file')
                delete(tc.TmpFile);
            end
        end
    end

    methods (Test)

        function testRoundTripVariedTypes(tc)
            % Build a section with numeric scalar, vector, matrix, logical,
            % char, and a struct whose field is a cell array. Write, read
            % back into a fresh object, and assert recovered equality.
            payload = struct( ...
                'ScalarNum',  3.14159, ...
                'IntScalar',  42, ...
                'RowVec',     [1 2 3 4], ...
                'Matrix',     [1 2; 3 4], ...
                'Flag',       true, ...
                'Name',       'fNIR2000C', ...
                'Nested',     struct('Labels', {{'A', 'B', 'C'}}));

            w = pf2_base.external.INI('File', tc.TmpFile);
            w.add('Device', payload);
            w.write();

            tc.verifyTrue(exist(tc.TmpFile, 'file') == 2);

            r = pf2_base.external.INI('File', tc.TmpFile);
            r.read();
            got = r.get('Device');

            tc.verifyEqual(got.ScalarNum, 3.14159, 'AbsTol', 1e-12);
            tc.verifyEqual(got.IntScalar, 42);
            tc.verifyEqual(got.RowVec, [1 2 3 4]);
            tc.verifyEqual(got.Matrix, [1 2; 3 4]);
            tc.verifyEqual(logical(got.Flag), true);
            tc.verifyEqual(got.Name, 'fNIR2000C');
            tc.verifyTrue(isstruct(got.Nested));
            tc.verifyEqual(got.Nested.Labels, {'A', 'B', 'C'});
        end

        function testMultipleSectionsRoundTrip(tc)
            w = pf2_base.external.INI('File', tc.TmpFile);
            w.add('Info', struct('Subject', 'S01', 'Age', 25));
            w.add('Probe', struct('Wavelength', [730 850], 'NChannels', 16));
            w.write();

            r = pf2_base.external.INI('File', tc.TmpFile);
            r.read();

            tc.verifyTrue(ismember('Info', r.Sections));
            tc.verifyTrue(ismember('Probe', r.Sections));

            info = r.get('Info');
            tc.verifyEqual(info.Subject, 'S01');
            tc.verifyEqual(info.Age, 25);

            probe = r.get('Probe');
            tc.verifyEqual(probe.Wavelength, [730 850]);
            tc.verifyEqual(probe.NChannels, 16);
        end

        function testCommentLinesIgnored(tc)
            % Whole-line and inline '%' comments must not pollute the values.
            lines = { ...
                '% This is a whole-line comment', ...
                '[Settings]', ...
                '% another comment inside the section', ...
                'Gain = 5            % inline trailing comment', ...
                'Label = ''hello''     % name with inline comment', ...
                '', ...
                '% trailing comment'};
            fid = fopen(tc.TmpFile, 'w');
            fprintf(fid, '%s\n', lines{:});
            fclose(fid);

            r = pf2_base.external.INI('File', tc.TmpFile, 'CommentChar', '%');
            r.read();
            s = r.get('Settings');

            tc.verifyEqual(s.Gain, 5);
            tc.verifyEqual(s.Label, 'hello');
            % No spurious comment-derived fields.
            tc.verifyEqual(sort(fieldnames(s)), {'Gain'; 'Label'});
        end

        function testReadDeviceCfg(tc)
            % Smoke test against a real bundled device .cfg, which uses '%'
            % as the comment marker, to confirm the parser handles real-world
            % configuration files.
            cfgDir = fullfile(fileparts(fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))))), 'devices');
            cfgs = dir(fullfile(cfgDir, '*.cfg'));
            if isempty(cfgs)
                tc.assumeFail('no device .cfg files found');
            end
            cfgPath = fullfile(cfgDir, cfgs(1).name);
            r = pf2_base.external.INI('File', cfgPath, 'CommentChar', '%');
            r.read();
            tc.verifyNotEmpty(r.Sections);
        end

    end
end
