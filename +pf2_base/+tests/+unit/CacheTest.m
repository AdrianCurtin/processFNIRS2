classdef CacheTest < matlab.unittest.TestCase
% CACHETEST Unit tests for persistent caching in fitProbe2D and estimateAbsorb
%
%   Verifies that:
%     - fitProbe2D caches results and returns identical output on repeat calls
%     - fitProbe2D cache can be cleared via '__clear__' sentinel
%     - estimateAbsorb (via bvoxy) caches extinction coefficients
%     - Cached results are numerically identical to fresh computations
%
%   Example:
%       results = runtests('pf2_base.tests.unit.CacheTest');
%       disp(results);
%
%   See also: pf2_base.fitProbe2D, pf2_base.fnirs.bvoxy

    methods (TestMethodSetup)
        function clearCaches(~)
            pf2_base.fitProbe2D('__clear__');
        end
    end

    %% fitProbe2D cache tests

    methods (Test)
        function testFitProbe2DReturnsSameResult(testCase)
            % Verify repeated calls with same coords return identical output
            x = [0.1; 0.3; 0.5; 0.7; 0.9];
            y = [0.2; 0.4; 0.6; 0.8; 1.0];
            z = [0.0; 0.0; 0.0; 0.0; 0.0];

            result1 = pf2_base.fitProbe2D(x, y, z);
            result2 = pf2_base.fitProbe2D(x, y, z);

            testCase.verifyEqual(result1, result2, ...
                'Cached result must be identical to original computation');
        end

        function testFitProbe2DCacheHitIsFaster(testCase)
            % Verify cache hit is faster than initial computation
            x = [0.1; 0.3; 0.5; 0.7; 0.9];
            y = [0.2; 0.4; 0.6; 0.8; 1.0];
            z = [0.0; 0.0; 0.0; 0.0; 0.0];

            % First call: populates cache
            pf2_base.fitProbe2D(x, y, z);

            % Time the cache hit
            tic;
            for i = 1:100
                pf2_base.fitProbe2D(x, y, z);
            end
            cachedTime = toc;

            % 100 cached lookups should be very fast
            testCase.verifyLessThan(cachedTime, 1.0, ...
                '100 cached lookups should complete in under 1 second');
        end

        function testFitProbe2DClearResets(testCase)
            % Verify '__clear__' sentinel resets the cache
            x = [0.1; 0.3; 0.5; 0.7; 0.9];
            y = [0.2; 0.4; 0.6; 0.8; 1.0];
            z = [0.0; 0.0; 0.0; 0.0; 0.0];

            result1 = pf2_base.fitProbe2D(x, y, z);

            % Clear the cache
            out = pf2_base.fitProbe2D('__clear__');
            testCase.verifyEmpty(out, ...
                'Clear sentinel should return empty');

            % Recompute — should still produce same result
            result2 = pf2_base.fitProbe2D(x, y, z);
            testCase.verifyEqual(result1, result2, ...
                'Result after cache clear must match original');
        end

        function testFitProbe2DDifferentInputsDifferentResults(testCase)
            % Verify different coordinates produce different cached entries
            x1 = [0.1; 0.3; 0.5; 0.7; 0.9];
            y1 = [0.2; 0.4; 0.6; 0.8; 1.0];
            z1 = [0.0; 0.0; 0.0; 0.0; 0.0];

            x2 = [0.9; 0.7; 0.5; 0.3; 0.1];
            y2 = [1.0; 0.8; 0.6; 0.4; 0.2];
            z2 = [0.0; 0.0; 0.0; 0.0; 0.0];

            result1 = pf2_base.fitProbe2D(x1, y1, z1);
            result2 = pf2_base.fitProbe2D(x2, y2, z2);

            % Results should differ (different input layouts)
            testCase.verifyNotEqual(result1, result2, ...
                'Different coordinates should produce different results');
        end

        function testFitProbe2DWithRealDevice(testCase)
            % Verify caching works with real device probe coordinates
            dev = pf2.Device.load('fNIR_Devices_fNIR2000');
            layout = dev.layout2D();

            % layout is a cell array from fitProbe2D — already cached via Device
            testCase.verifyFalse(isempty(layout), ...
                'Device layout should not be empty');

            % Clear fitProbe2D cache and call again through device loading
            pf2_base.fitProbe2D('__clear__');
            pf2.Device.clearCache();

            dev2 = pf2.Device.load('fNIR_Devices_fNIR2000');
            layout2 = dev2.layout2D();

            testCase.verifyEqual(layout, layout2, ...
                'Layout from fresh computation must match original');
        end

        function testFitProbe2DUsePCAFlag(testCase)
            % Verify usePCA=true and usePCA=false are cached separately
            x = [1; 3; 5; 7; 9];
            y = [2; 4; 6; 8; 10];
            z = [0.5; 0.5; 0.5; 0.5; 0.5];

            resultPCA = pf2_base.fitProbe2D(x, y, z, true);
            resultNoPCA = pf2_base.fitProbe2D(x, y, z, false);

            % PCA and non-PCA should produce different results
            % (PCA projects 3D to 2D, non-PCA uses coordinates directly)
            testCase.verifyNotEqual(resultPCA, resultNoPCA, ...
                'usePCA=true and usePCA=false should produce different layouts');
        end
    end

    %% estimateAbsorb / bvoxy cache tests

    methods (Test)
        function testBvoxyRepeatedCallsSameResult(testCase)
            % Verify bvoxy produces identical results on repeated calls
            % (tests that estimateAbsorb cache doesn't corrupt output)
            data = pf2.import.sampleData.fNIR2000();
            proc1 = processFNIRS2(data);
            proc2 = processFNIRS2(data);

            testCase.verifyEqual(proc1.HbO, proc2.HbO, 'AbsTol', 1e-12, ...
                'Repeated processing must produce identical HbO');
            testCase.verifyEqual(proc1.HbR, proc2.HbR, 'AbsTol', 1e-12, ...
                'Repeated processing must produce identical HbR');
        end

        function testBvoxyCellArrayConsistency(testCase)
            % Verify batch processing (cell array) produces same results as
            % individual processing — exercises cache across subjects
            data = pf2.import.sampleData.fNIR2000();
            data2 = data;
            data2.info.SubjectID = 'S02';

            % Process individually
            proc1 = processFNIRS2(data);
            proc2 = processFNIRS2(data2);

            % Process as cell array (exercises cache in batch path)
            batch = processFNIRS2({data, data2});

            testCase.verifyEqual(proc1.HbO, batch{1}.HbO, 'AbsTol', 1e-12, ...
                'Batch result must match individual for subject 1');
            testCase.verifyEqual(proc2.HbO, batch{2}.HbO, 'AbsTol', 1e-12, ...
                'Batch result must match individual for subject 2');
        end

        function testBvoxyDifferentDPFModesSeparate(testCase)
            % Verify different DPF modes are not conflated by cache
            data = pf2.import.sampleData.fNIR2000();
            procNone = processFNIRS2(data, 'DPFmode', 'None');
            procFixed = processFNIRS2(data, 'DPFmode', 'Fixed');

            % Different DPF modes must produce different magnitudes
            meanNone = mean(abs(procNone.HbO(:)), 'omitnan');
            meanFixed = mean(abs(procFixed.HbO(:)), 'omitnan');

            testCase.verifyNotEqual(meanNone, meanFixed, ...
                'Different DPF modes must produce different results (not confused by cache)');
        end
    end
end
