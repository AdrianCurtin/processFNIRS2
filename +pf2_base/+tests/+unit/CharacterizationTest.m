classdef CharacterizationTest < matlab.unittest.TestCase
    % CHARACTERIZATIONTEST Golden-output regression oracle for processFNIRS2
    %
    % Captures the CURRENT numeric behavior of the processFNIRS2 processing
    % core across a representative matrix of configurations (DPF modes,
    % baseline settings, method chains, and one ProcessingContext-based call)
    % so that an upcoming refactor of how processing configuration is threaded
    % (global PF2/setF -> ProcessingContext) can be proven output-preserving.
    %
    % The golden data is generated against pre-refactor code and committed to
    % +pf2_base/+tests/+data/characterization_golden.mat. This test re-runs
    % each configuration and asserts the outputs (HbO, HbR, HbTotal, HbDiff,
    % CBSI, units, DPF_factor, and reproducibility processingInfo fields)
    % match the golden values, with NaN positions matching exactly.
    %
    % To keep the golden file small enough to commit while preserving
    % full-coverage drift detection, each biomarker matrix is stored as TWO
    % compact artifacts rather than the full matrix:
    %   1. A deterministic CHECKSUM over the COMPLETE array (the primary gate).
    %      The matrix size and its IEEE-754 byte representation (via typecast
    %      to uint8, which preserves every bit including NaN bit patterns and
    %      their positions) are fed to SHA-256. Any change to any element, or
    %      any move of a NaN, changes the checksum. This is exact, full-array
    %      coverage in a fixed ~64-character string.
    %   2. A small evenly-spaced SLICE (up to ~200 rows across the time axis,
    %      all channels) stored at full double precision. The slice is a
    %      human-debuggable diagnostic: when the checksum mismatches, the slice
    %      diff (AbsTol 1e-9, NaN positions identical) localizes the drift.
    %
    % The checksum match is the authoritative full-coverage assertion; the
    % slice comparison preserves the original 1e-9 numerical intent for the
    % sampled rows and aids debugging.
    %
    % The configuration matrix is the SINGLE SOURCE OF TRUTH: both the
    % generator (generateGolden) and the comparison tests obtain their configs
    % from the static configs() method, so they can never drift.
    %
    % Syntax:
    %   results = runtests('pf2_base.tests.unit.CharacterizationTest');
    %
    % To regenerate the golden file (only when CURRENT behavior is the
    % intended baseline, e.g. before a refactor):
    %   pf2_base.tests.unit.CharacterizationTest.generateGolden();
    %
    % Inputs:
    %   None (test harness supplies the TestCase).
    %
    % Outputs:
    %   None (verifications are reported through the matlab.unittest framework).
    %
    % Notes:
    %   - All configurations are deterministic. No random data is generated;
    %     inputs come from fixed sample datasets and methods involving
    %     randomness are excluded from the matrix.
    %   - Global state (PF2/setF) is cleared and reinitialized before every
    %     run so per-config captures cannot leak settings from one another.
    %
    % Example:
    %   % Run the regression suite
    %   results = runtests('pf2_base.tests.unit.CharacterizationTest');
    %   assert(all([results.Passed]));
    %
    % See also: processFNIRS2, pf2_base.ProcessingContext

    properties (Constant)
        % Absolute tolerance for biomarker matrix comparison. Beer-Lambert
        % output magnitudes are O(1) uM; 1e-9 leaves ~9 significant digits of
        % headroom while still catching any real numeric drift.
        AbsTol = 1e-9
        % Relative tolerance for the same comparison (applied in addition to
        % AbsTol to keep large-magnitude samples honest).
        RelTol = 1e-9
        % Tolerance for scalar reproducibility fields (DPF_factor etc.).
        ScalarTol = 1e-12
        % Maximum number of evenly-spaced time rows retained in the debug
        % slice per biomarker. Caps golden size; if a matrix has fewer rows,
        % all rows are kept.
        MaxSliceRows = 200
    end

    methods (Static)
        function goldenPath = goldenFilePath()
            % GOLDENFILEPATH Absolute path to the committed golden .mat file.
            %
            % Outputs:
            %   goldenPath - char, full path to characterization_golden.mat
            here = fileparts(mfilename('fullpath'));           % .../+unit
            testsDir = fileparts(here);                         % .../+tests
            goldenPath = fullfile(testsDir, '+data', 'characterization_golden.mat');
        end

        function configs = configs()
            % CONFIGS Single source of truth for the characterization matrix.
            %
            % Returns the ordered list of configurations exercised by both the
            % generator and the comparison tests. Each entry is a struct with:
            %   label      - unique char identifier (also the field key)
            %   input      - 'fNIR2000' (no markers) or 'fNIR1200' (markers)
            %   rawMethod  - raw method section name
            %   oxyMethod  - oxy method section name
            %   dpfMode    - 'None' | 'Fixed' | 'Calc'
            %   fixedDPF   - fixed DPF value (used when dpfMode == 'Fixed')
            %   age        - subject age for 'Calc' DPF
            %   blStart    - baseline start time (s)
            %   blLength   - baseline length (s)
            %   useContext - true to run via a ProcessingContext, else globals
            %
            % Outputs:
            %   configs - 1xN struct array of configuration descriptors.

            defs = {
            % label                       input      raw            oxy     dpfMode  fixedDPF age blStart blLength useContext
              'f2000_none_default'       'fNIR2000' 'None'         'None'  'None'    5.93   25   0     10     false
              'f2000_fixed_default'      'fNIR2000' 'None'         'None'  'Fixed'   6.00   25   0     10     false
              'f2000_calc_default'       'fNIR2000' 'None'         'None'  'Calc'    5.93   25   0     10     false
              'f2000_calc_age60'         'fNIR2000' 'None'         'None'  'Calc'    5.93   60   0     10     false
              'f2000_calc_bl_5_15'       'fNIR2000' 'None'         'None'  'Calc'    5.93   25   5     15     false
              'f2000_calc_lpf'           'fNIR2000' 'None'         'LPF'   'Calc'    5.93   25   0     10     false
              'f2000_tddr_calc'          'fNIR2000' 'OD_TDDR'      'None'  'Calc'    5.93   25   0     10     false
              'f2000_tddr_lpf_fixed'     'fNIR2000' 'OD_TDDR_lpf'  'LPF'   'Fixed'   5.50   25   0     10     false
              'f1200_none_default'       'fNIR1200' 'None'         'None'  'None'    5.93   25   0     10     false
              'f1200_calc_default'       'fNIR1200' 'None'         'None'  'Calc'    5.93   25   0     10     false
              'f1200_fixed_bl_2_8'       'fNIR1200' 'None'         'None'  'Fixed'   6.00   25   2      8     false
              'f1200_tddr_calc'          'fNIR1200' 'OD_TDDR'      'None'  'Calc'    5.93   30   0     10     false
              'f2000_ctx_calc'           'fNIR2000' 'None'         'None'  'Calc'    5.93   40   3     12     true
            };

            n = size(defs, 1);
            configs = repmat(struct( ...
                'label', '', 'input', '', 'rawMethod', '', 'oxyMethod', '', ...
                'dpfMode', '', 'fixedDPF', 0, 'age', 0, ...
                'blStart', 0, 'blLength', 0, 'useContext', false), 1, n);
            for i = 1:n
                configs(i).label      = defs{i, 1};
                configs(i).input      = defs{i, 2};
                configs(i).rawMethod  = defs{i, 3};
                configs(i).oxyMethod  = defs{i, 4};
                configs(i).dpfMode    = defs{i, 5};
                configs(i).fixedDPF   = defs{i, 6};
                configs(i).age        = defs{i, 7};
                configs(i).blStart    = defs{i, 8};
                configs(i).blLength   = defs{i, 9};
                configs(i).useContext = defs{i, 10};
            end
        end

        function data = loadInput(inputName)
            % LOADINPUT Load a deterministic sample dataset by name.
            %
            % Inputs:
            %   inputName - 'fNIR2000' (no markers) or 'fNIR1200' (markers)
            %
            % Outputs:
            %   data - imported fNIRS data struct
            switch inputName
                case 'fNIR2000'
                    data = pf2.import.sampleData.fNIR2000();
                case 'fNIR1200'
                    data = pf2.import.sampleData();
                otherwise
                    error('CharacterizationTest:UnknownInput', ...
                        'Unknown input dataset ''%s''.', inputName);
            end
        end

        function out = runConfig(cfg)
            % RUNCONFIG Execute processFNIRS2 for a single configuration.
            %
            % Resets global state, loads the input dataset deterministically,
            % and processes it either via globals or a ProcessingContext as
            % dictated by the config. This is shared by the generator and the
            % comparison tests so both drive identical code paths.
            %
            % Inputs:
            %   cfg - one element of the configs() struct array.
            %
            % Outputs:
            %   out - processed fNIRS struct from processFNIRS2.

            % Reset global processing state so nothing leaks between configs.
            clear global PF2 setF outputData; %#ok<CLGLB>
            pf2_base.pf2_initialize();

            data = pf2_base.tests.unit.CharacterizationTest.loadInput(cfg.input);

            if cfg.useContext
                ctx = pf2_base.ProcessingContext.fromGlobals();
                ctx.dpfMode = cfg.dpfMode;
                ctx.dpfFixedValue = cfg.fixedDPF;
                ctx.subjectAge = cfg.age;
                ctx.baselineStartTime = cfg.blStart;
                ctx.baselineLength = cfg.blLength;
                ctx.setRawMethod(cfg.rawMethod);
                ctx.setOxyMethod(cfg.oxyMethod);
                out = processFNIRS2(data, 'Context', ctx);
            else
                out = processFNIRS2(data, cfg.rawMethod, cfg.oxyMethod, ...
                    'DPFmode', cfg.dpfMode, ...
                    'FixedDPF', cfg.fixedDPF, ...
                    'defaultSubjectAge', cfg.age, ...
                    'blStartTime', cfg.blStart, ...
                    'blLength', cfg.blLength);
            end
        end

        function rowIdx = sliceRows(nRows)
            % SLICEROWS Indices of the evenly-spaced debug slice rows.
            %
            % Deterministically selects up to MaxSliceRows row indices spread
            % across the time axis (always including the first and last row).
            % Shared by the generator and the comparison test so both sample
            % identical rows.
            %
            % Inputs:
            %   nRows - total number of rows (time samples) in the matrix.
            %
            % Outputs:
            %   rowIdx - column vector of unique, sorted row indices.
            maxRows = pf2_base.tests.unit.CharacterizationTest.MaxSliceRows;
            if nRows <= 0
                rowIdx = zeros(0, 1);
                return;
            end
            if nRows <= maxRows
                rowIdx = (1:nRows).';
            else
                rowIdx = unique(round(linspace(1, nRows, maxRows))).';
            end
        end

        function fp = fingerprint(M)
            % FINGERPRINT Compact full-coverage descriptor of a numeric matrix.
            %
            % Produces a checksum over the COMPLETE array plus a small
            % evenly-spaced debug slice. The checksum is SHA-256 over the
            % matrix dimensions and its raw IEEE-754 bytes (typecast to
            % uint8), so it changes if ANY element changes value or ANY NaN
            % moves position. The slice retains full double precision for a
            % handful of rows to support human-readable diffs.
            %
            % Inputs:
            %   M - numeric matrix (biomarker output, [T x C]).
            %
            % Outputs:
            %   fp - struct with fields:
            %        .size     - size(M)
            %        .checksum - 64-char SHA-256 hex string over the full array
            %        .sliceRows- row indices retained in .slice
            %        .slice    - M(sliceRows, :) at full double precision

            M = double(M);
            sz = size(M);

            % Full-array checksum. typecast preserves every bit (including NaN
            % bit patterns and their positions); prefixing the dimensions
            % guards against reshape-only changes. SHA-256 over the byte
            % stream is deterministic and reproducible across sessions.
            dimBytes = typecast(uint64(sz(:).'), 'uint8');
            dataBytes = typecast(M(:).', 'uint8');
            md = java.security.MessageDigest.getInstance('SHA-256');
            md.update(dimBytes);
            md.update(dataBytes);
            digest = typecast(md.digest(), 'uint8');
            fp = struct();
            fp.size = sz;
            fp.checksum = sprintf('%02x', digest);

            % Evenly-spaced debug slice (all channels) at full precision.
            rowIdx = pf2_base.tests.unit.CharacterizationTest.sliceRows(sz(1));
            fp.sliceRows = rowIdx;
            if isempty(M)
                fp.slice = M;
            else
                fp.slice = M(rowIdx, :);
            end
        end

        function record = captureOutputs(out)
            % CAPTUREOUTPUTS Extract the golden-relevant fields from a result.
            %
            % Inputs:
            %   out - processed fNIRS struct from processFNIRS2.
            %
            % Outputs:
            %   record - struct with compact biomarker fingerprints (full-array
            %            checksum + debug slice), units, DPF_factor and
            %            reproducibility processingInfo fields.

            record = struct();
            fpFn = @pf2_base.tests.unit.CharacterizationTest.fingerprint;
            record.HbO = fpFn(out.HbO);
            record.HbR = fpFn(out.HbR);
            record.HbTotal = fpFn(out.HbTotal);
            record.HbDiff = fpFn(out.HbDiff);
            record.CBSI = fpFn(out.CBSI);
            record.units = out.units;
            record.DPF_factor = out.DPF_factor;

            pi = out.processingInfo;
            keep = {'dpfMode', 'dpfValue', 'subjectAge', 'baselineStart', ...
                'baselineLength', 'rawMethod', 'oxyMethod'};
            info = struct();
            for k = 1:numel(keep)
                if isfield(pi, keep{k})
                    info.(keep{k}) = pi.(keep{k});
                else
                    info.(keep{k}) = [];
                end
            end
            record.processingInfo = info;
        end

        function golden = generateGolden(varargin)
            % GENERATEGOLDEN Build and write the committed golden .mat file.
            %
            % Runs every configuration in configs() against the CURRENT code
            % and stores the captured outputs as a struct array keyed by
            % config label. Intended to be run intentionally before a refactor.
            %
            % Syntax:
            %   golden = pf2_base.tests.unit.CharacterizationTest.generateGolden();
            %   pf2_base.tests.unit.CharacterizationTest.generateGolden('SavePath', p);
            %
            % Inputs:
            %   'SavePath' - optional char, destination .mat path
            %                (default: goldenFilePath()).
            %
            % Outputs:
            %   golden - the generated golden struct (also saved to disk).

            p = inputParser;
            addParameter(p, 'SavePath', '', @ischar);
            parse(p, varargin{:});
            savePath = p.Results.SavePath;
            if isempty(savePath)
                savePath = pf2_base.tests.unit.CharacterizationTest.goldenFilePath();
            end

            cfgs = pf2_base.tests.unit.CharacterizationTest.configs();
            golden = struct();
            golden.generated = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
            golden.configs = cfgs;
            golden.records = struct();

            for i = 1:numel(cfgs)
                cfg = cfgs(i);
                fprintf('Capturing config %d/%d: %s\n', i, numel(cfgs), cfg.label);
                out = pf2_base.tests.unit.CharacterizationTest.runConfig(cfg);
                golden.records.(cfg.label) = ...
                    pf2_base.tests.unit.CharacterizationTest.captureOutputs(out);
            end

            outDir = fileparts(savePath);
            if ~isempty(outDir) && ~isfolder(outDir)
                mkdir(outDir);
            end
            save(savePath, '-struct', 'golden', '-v7');
            fprintf('Wrote golden file: %s\n', savePath);
        end
    end

    properties (TestParameter)
        % One parameterization per config label, derived from the single
        % source of truth so the test grid mirrors the golden grid exactly.
        configLabel = pf2_base.tests.unit.CharacterizationTest.labelCell()
    end

    methods (Static, Access = private)
        function labels = labelCell()
            % LABELCELL Cell array of config labels for parameterization.
            cfgs = pf2_base.tests.unit.CharacterizationTest.configs();
            labels = {cfgs.label};
        end
    end

    properties (Access = private)
        Golden
    end

    methods (TestClassSetup)
        function loadGolden(testCase)
            % LOADGOLDEN Load the committed golden data once for the suite.
            goldenPath = pf2_base.tests.unit.CharacterizationTest.goldenFilePath();
            testCase.assertTrue(isfile(goldenPath), ...
                sprintf(['Golden file not found at %s. Generate it with ' ...
                'pf2_base.tests.unit.CharacterizationTest.generateGolden().'], ...
                goldenPath));
            testCase.Golden = load(goldenPath);
        end
    end

    methods (Test)
        function matchesGolden(testCase, configLabel)
            % MATCHESGOLDEN Re-run a config and assert it matches the golden.
            %
            % Inputs:
            %   configLabel - parameter naming the config to verify.

            testCase.assertTrue(isfield(testCase.Golden.records, configLabel), ...
                sprintf('No golden record for config ''%s''.', configLabel));
            expected = testCase.Golden.records.(configLabel);

            cfgs = pf2_base.tests.unit.CharacterizationTest.configs();
            cfg = cfgs(strcmp({cfgs.label}, configLabel));
            out = pf2_base.tests.unit.CharacterizationTest.runConfig(cfg);
            actual = pf2_base.tests.unit.CharacterizationTest.captureOutputs(out);

            % Biomarker matrices: the full-array checksum is the primary
            % full-coverage gate; the slice diff is a 1e-9 diagnostic.
            bioFields = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI'};
            for f = 1:numel(bioFields)
                fn = bioFields{f};
                testCase.verifyFingerprintMatch(actual.(fn), expected.(fn), fn);
            end

            % Units string is exact.
            testCase.verifyEqual(actual.units, expected.units, ...
                sprintf('units mismatch for %s', configLabel));

            % DPF_factor scalar.
            testCase.verifyEqual(actual.DPF_factor, expected.DPF_factor, ...
                'AbsTol', testCase.ScalarTol, ...
                sprintf('DPF_factor mismatch for %s', configLabel));

            % Reproducibility processingInfo fields.
            testCase.verifyProcessingInfo(actual.processingInfo, ...
                expected.processingInfo, configLabel);
        end
    end

    methods (Access = private)
        function verifyFingerprintMatch(testCase, actual, expected, name)
            % VERIFYFINGERPRINTMATCH Compare two biomarker fingerprints.
            %
            % The full-array checksum is the authoritative full-coverage gate:
            % it must match EXACTLY (any element change or NaN move breaks it).
            % The size and evenly-spaced debug slice are diagnostic assertions
            % that localize drift and preserve the 1e-9 numerical intent for
            % the sampled rows, with NaN positions required to match exactly.
            %
            % Inputs:
            %   actual   - fingerprint struct from the current run.
            %   expected - fingerprint struct from the golden file.
            %   name     - biomarker name (for diagnostic messages).

            % Size first (cheap, informative).
            testCase.verifyEqual(actual.size, expected.size, ...
                sprintf('%s size mismatch', name));

            % Primary gate: exact full-array checksum.
            testCase.verifyEqual(actual.checksum, expected.checksum, ...
                sprintf(['%s full-array checksum mismatch: a numeric change ' ...
                'was detected somewhere in the matrix.'], name));

            % Diagnostic: debug slice within tight tolerance, NaN-aware.
            testCase.verifyEqual(actual.sliceRows, expected.sliceRows, ...
                sprintf('%s slice-row indices mismatch', name));

            sa = actual.slice;
            se = expected.slice;
            testCase.verifyEqual(size(sa), size(se), ...
                sprintf('%s slice size mismatch', name));

            nanA = isnan(sa);
            nanE = isnan(se);
            testCase.verifyEqual(nanA, nanE, ...
                sprintf('%s slice NaN-position mismatch', name));

            finiteMask = ~nanE;
            testCase.verifyEqual(sa(finiteMask), se(finiteMask), ...
                'AbsTol', testCase.AbsTol, 'RelTol', testCase.RelTol, ...
                sprintf('%s slice numeric mismatch beyond tolerance', name));
        end

        function verifyProcessingInfo(testCase, actual, expected, label)
            % VERIFYPROCESSINGINFO Compare reproducibility info fields.
            fns = fieldnames(expected);
            for i = 1:numel(fns)
                fn = fns{i};
                ev = expected.(fn);
                av = actual.(fn);
                if isnumeric(ev) && isscalar(ev) && ~isempty(ev)
                    testCase.verifyEqual(av, ev, 'AbsTol', testCase.ScalarTol, ...
                        sprintf('processingInfo.%s mismatch for %s', fn, label));
                else
                    testCase.verifyEqual(av, ev, ...
                        sprintf('processingInfo.%s mismatch for %s', fn, label));
                end
            end
        end
    end
end
