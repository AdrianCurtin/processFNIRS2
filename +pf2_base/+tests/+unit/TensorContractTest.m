classdef TensorContractTest < matlab.unittest.TestCase
% TENSORCONTRACTTEST Round-trip tests for the foundation-model export contract
%
% Verifies the contract v1.0 tensor exporter (pf2.export.asTensor) and the
% embeddings re-import path (pf2.import.importEmbeddings) defined in
% TRANSFORMER_ROADMAP.md §4. Exports processed sample data to a self-describing
% .h5 file, reads it back with the native HDF5 reader, and asserts the on-disk
% schema, shapes, float32 storage, attributes, and JSON metadata blobs. Also
% synthesizes embeddings files and checks they re-attach aligned to the time
% base.
%
% Test Data:
%   pf2.import.sampleData.fNIR2000() processed via processFNIRS2 (deterministic,
%   headless). Embeddings .h5 files are synthesized in-test.
%
% Usage:
%   results = runtests('pf2_base.tests.unit.TensorContractTest');
%   results = run(pf2_base.tests.unit.TensorContractTest);
%
% See also: pf2.export.asTensor, pf2.import.importEmbeddings,
%           pf2.probe.montage, pf2.data.slidingWindows, matlab.unittest.TestCase

    properties (Access = private)
        ProcessedData    % Processed fNIRS struct (HbO/HbR/...)
        TempFiles        % Cell array of temp files to clean up
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            % SETUPONCE Load and process the sample dataset once
            testCase.TempFiles = {};
            data = pf2.import.sampleData.fNIR2000();
            testCase.ProcessedData = processFNIRS2(data);
        end
    end

    methods (TestMethodTeardown)
        function cleanupTempFiles(testCase)
            % CLEANUPTEMPFILES Remove any temp files created during a test
            for k = 1:numel(testCase.TempFiles)
                f = testCase.TempFiles{k};
                if ~isempty(f) && exist(f, 'file')
                    delete(f);
                end
            end
            testCase.TempFiles = {};
        end
    end

    methods (Access = private)
        function f = tempH5(testCase)
            % TEMPH5 Register and return a temp .h5 path
            f = [tempname '.h5'];
            testCase.TempFiles{end+1} = f;
        end
    end

    methods (Test)

        function testDefaultExportRoundTrip(testCase)
            % TESTDEFAULTEXPORTROUNDTRIP [T x C x F] export schema + values
            proc = testCase.ProcessedData;
            f = testCase.tempH5();

            outPath = pf2.export.asTensor(proc, f);
            testCase.verifyEqual(exist(outPath, 'file'), 2.0, ...
                'Export did not produce a file.');

            % Shape and dtype
            info = h5info(outPath, '/tensor');
            testCase.verifyEqual(info.Datatype.Class, 'H5T_FLOAT', ...
                'Tensor is not stored as float.');
            % h5read returns the on-disk (row-major) axes reversed; permute
            % back to the forward [T x C x F] order matching `dims`.
            tensorDisk = h5read(outPath, '/tensor');
            testCase.verifyClass(tensorDisk, 'single', ...
                'Tensor read back is not float32.');
            tensor = permute(tensorDisk, ndims(tensorDisk):-1:1);

            features = h5readatt(outPath, '/', 'featureNames');
            features = cellstr(string(features));
            T = size(proc.HbO, 1);
            C = size(proc.HbO, 2);
            F = numel(features);
            testCase.verifyEqual(size(tensor), [T C F], ...
                'Tensor shape is not [T x C x F].');

            % Values match source biomarkers within float32 tolerance
            for k = 1:F
                src = single(proc.(features{k}));
                testCase.verifyEqual(tensor(:, :, k), src, 'AbsTol', single(1e-5), ...
                    sprintf('Feature %s values diverged.', features{k}));
            end

            % Root attributes
            testCase.verifyEqual(char(h5readatt(outPath, '/', 'pf2ContractVersion')), '1.0');
            testCase.verifyEqual(char(h5readatt(outPath, '/', 'createdBy')), 'processFNIRS2');
            testCase.verifyEqual(char(h5readatt(outPath, '/', 'dims')), 'time x channel x feature');
            testCase.verifyEqual(double(h5readatt(outPath, '/', 'samplingRate')), double(proc.fs));
            testCase.verifyEqual(char(h5readatt(outPath, '/', 'units')), char(string(proc.units)));
            testCase.verifyEqual(double(h5readatt(outPath, '/', 'nWindows')), 0);

            % Time dataset
            timeVec = h5read(outPath, '/time');
            testCase.verifyEqual(numel(timeVec), T);
            testCase.verifyEqual(timeVec(:), double(proc.time(:)), 'AbsTol', 1e-9);

            % Montage JSON decodes to a struct with expected fields
            montageJson = h5read(outPath, '/montage');
            descriptor = jsondecode(char(string(montageJson)));
            testCase.verifyClass(descriptor, 'struct');
            for fld = {'device', 'wavelengths', 'coordinateSystem', 'channels'}
                testCase.verifyTrue(isfield(descriptor, fld{1}), ...
                    sprintf('Montage descriptor missing field %s.', fld{1}));
            end

            % processingInfo manifest present and decodes
            procJson = h5read(outPath, '/manifest/processingInfo');
            procStruct = jsondecode(char(string(procJson)));
            testCase.verifyClass(procStruct, 'struct');
            testCase.verifyTrue(isfield(procStruct, 'dpfMode'));
        end

        function testWindowedExport(testCase)
            % TESTWINDOWEDEXPORT [W x T x C x F] + /windowOnsets schema
            proc = testCase.ProcessedData;
            f = testCase.tempH5();

            blocks  = pf2.data.slidingWindows(proc, 'Length', 10, 'Embed', false);
            windows = pf2.data.extractBlocks(proc, blocks, 'PreTime', 0, 'PostTime', 0);
            W = numel(windows);

            outPath = pf2.export.asTensor(proc, f, 'Windows', windows, ...
                'Features', {'HbO', 'HbR'});

            % Permute reversed on-disk axes back to forward [W x T x C x F].
            tensorDisk = h5read(outPath, '/tensor');
            testCase.verifyClass(tensorDisk, 'single');
            tensor = permute(tensorDisk, ndims(tensorDisk):-1:1);
            testCase.verifyEqual(ndims(tensor), 4, 'Windowed tensor is not 4-D.');
            sz = size(tensor);
            testCase.verifyEqual(sz(1), W, 'First dim is not W.');
            testCase.verifyEqual(sz(3), size(proc.HbO, 2), 'Third dim is not C.');
            testCase.verifyEqual(sz(4), 2, 'Feature dim is not 2.');

            testCase.verifyEqual(char(h5readatt(outPath, '/', 'dims')), ...
                'window x time x channel x feature');
            testCase.verifyEqual(double(h5readatt(outPath, '/', 'nWindows')), W);

            onsets = h5read(outPath, '/windowOnsets');
            testCase.verifyEqual(numel(onsets), W, ...
                '/windowOnsets length does not equal W.');
        end

        function testQCManifestIncluded(testCase)
            % TESTQCMANIFESTINCLUDED /manifest/qc present and decodes when QC=true
            proc = testCase.ProcessedData;
            f = testCase.tempH5();

            outPath = pf2.export.asTensor(proc, f, 'QC', true);

            qcJson = h5read(outPath, '/manifest/qc');
            qc = jsondecode(char(string(qcJson)));
            testCase.verifyClass(qc, 'struct');
            testCase.verifyTrue(isfield(qc, 'pass'), 'QC manifest missing .pass.');
            testCase.verifyEqual(numel(qc.pass), size(proc.HbO, 2), ...
                'QC pass mask length does not match channel count.');
        end

        function testImportEmbeddingsPerTimepoint(testCase)
            % TESTIMPORTEMBEDDINGSPERTIMEPOINT [T x E] re-import + time alignment
            proc = testCase.ProcessedData;
            ef = testCase.tempH5();

            T = numel(proc.time);
            E = 8;
            emb = single(reshape(1:(T*E), T, E)) / single(T*E);  % deterministic [T x E]
            % Emulate a Python/h5py (row-major) file: write the reversed array
            % so h5py would read shape (T, E) and MATLAB's reverse-on-read in
            % importEmbeddings recovers the forward [T x E].
            embDisk = permute(emb, [2 1]);
            h5create(ef, '/embeddings', size(embDisk), 'Datatype', 'single');
            h5write(ef, '/embeddings', embDisk);
            h5writeatt(ef, '/', 'dims', 'time x feature');
            h5writeatt(ef, '/', 'modelName', 'testModel');

            out = pf2.import.importEmbeddings(proc, ef);
            testCase.verifyTrue(isfield(out, 'embeddings'));
            testCase.verifyEqual(size(out.embeddings.data), [T E]);
            testCase.verifyEqual(out.embeddings.data, double(emb), 'AbsTol', 1e-6, ...
                'Per-timepoint embeddings did not round-trip to [T x E].');
            testCase.verifyEqual(out.embeddings.time, double(proc.time(:)), ...
                'AbsTol', 1e-9, 'Embedding time not aligned to data.time.');
            testCase.verifyEqual(char(string(out.embeddings.dims)), 'time x feature');
            testCase.verifyEqual(char(out.embeddings.info.modelName), 'testModel');
            testCase.verifyEqual(numel(out.embeddings.names), E);
        end

        function testImportEmbeddingsPerWindow(testCase)
            % TESTIMPORTEMBEDDINGSPERWINDOW [W x E] re-import + window onsets
            proc = testCase.ProcessedData;
            ef = testCase.tempH5();

            W = 5;
            E = 4;
            onsets = (0:W-1)' * 10;
            emb = single(reshape(1:(W*E), W, E));  % [W x E]
            % Emulate a Python/h5py (row-major) file: write the reversed array.
            embDisk = permute(emb, [2 1]);
            h5create(ef, '/embeddings', size(embDisk), 'Datatype', 'single');
            h5write(ef, '/embeddings', embDisk);
            h5writeatt(ef, '/', 'dims', 'window x feature');
            h5create(ef, '/windowOnsets', size(onsets), 'Datatype', 'double');
            h5write(ef, '/windowOnsets', onsets);

            out = pf2.import.importEmbeddings(proc, ef);
            testCase.verifyEqual(size(out.embeddings.data), [W E]);
            testCase.verifyEqual(out.embeddings.data, double(emb), 'AbsTol', 1e-6, ...
                'Per-window embeddings did not round-trip to [W x E].');
            testCase.verifyEqual(out.embeddings.time, onsets, 'AbsTol', 1e-9, ...
                'Per-window embedding time does not equal window onsets.');
            testCase.verifyEqual(char(string(out.embeddings.dims)), 'window x feature');
        end

        function testPythonCrossLanguageRead(testCase)
            % TESTPYTHONCROSSLANGUAGEREAD h5py sees (T,C,F) matching dims +
            % json.loads on the metadata blobs. Skipped when python3/h5py
            % are unavailable (does not hard-fail).
            import matlab.unittest.constraints.IsEqualTo

            % Require python3 + h5py; otherwise assume away the sub-check.
            [st, ~] = system('python3 -c "import h5py, json"');
            testCase.assumeEqual(st, 0, ...
                'python3 with h5py not available; skipping cross-language read.');

            proc = testCase.ProcessedData;
            f = testCase.tempH5();
            outPath = pf2.export.asTensor(proc, f);

            T = size(proc.HbO, 1);
            C = size(proc.HbO, 2);
            features = cellstr(string(h5readatt(outPath, '/', 'featureNames')));
            F = numel(features);

            scriptPath = [tempname '.py'];
            testCase.TempFiles{end+1} = scriptPath;
            py = [ ...
                "import sys, json, h5py" newline ...
                "p = sys.argv[1]" newline ...
                "f = h5py.File(p, 'r')" newline ...
                "t = f['/tensor']" newline ...
                "assert str(t.dtype) == 'float32', 'tensor dtype ' + str(t.dtype)" newline ...
                "dims = f.attrs['dims']" newline ...
                "dims = dims.decode() if isinstance(dims, bytes) else str(dims)" newline ...
                "shape = tuple(int(x) for x in t.shape)" newline ...
                "exp = (int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]))" newline ...
                "assert shape == exp, 'shape ' + str(shape) + ' != ' + str(exp)" newline ...
                "assert dims == 'time x channel x feature', 'dims ' + dims" newline ...
                "m = f['/montage'][()]" newline ...
                "m = m.decode() if isinstance(m, bytes) else m" newline ...
                "json.loads(m)" newline ...
                "pi = f['/manifest/processingInfo'][()]" newline ...
                "pi = pi.decode() if isinstance(pi, bytes) else pi" newline ...
                "json.loads(pi)" newline ...
                "print('OK ' + str(shape) + ' ' + str(t.dtype) + ' dims=' + dims)" newline ];
            fid = fopen(scriptPath, 'w');
            fwrite(fid, char(join(py, '')));
            fclose(fid);

            cmd = sprintf('python3 "%s" "%s" %d %d %d', ...
                scriptPath, outPath, T, C, F);
            [rc, txt] = system(cmd);
            testCase.verifyEqual(rc, 0, ...
                sprintf('Python cross-language read failed:\n%s', txt));
            testCase.verifyTrue(contains(txt, 'OK'), ...
                sprintf('Python check did not report OK:\n%s', txt));
        end

    end
end
