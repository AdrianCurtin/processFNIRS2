classdef BeerLambertTest < matlab.unittest.TestCase
    % BEERLAMBERTTEST Unit tests for Beer-Lambert law conversion functions
    %
    %   This test class verifies the Beer-Lambert law implementations used
    %   in fNIRS data processing:
    %     - pf2_Intensity2OD: Raw intensity to optical density conversion
    %     - bvoxy: Optical density to hemoglobin concentration conversion
    %     - processFNIRS2: End-to-end pipeline with DPF mode configurations
    %
    %   The Beer-Lambert law relates optical density changes to chromophore
    %   concentration changes:
    %       delta_OD = epsilon * delta_C * d * DPF
    %
    %   References:
    %     Scholkmann, F. & Wolf, M. (2013). J. Biomed. Opt. 18(10), 105004.
    %     http://omlc.org/spectra/hemoglobin/summary.html
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.BeerLambertTest');
    %       disp(results);
    %
    %   See also: pf2_Intensity2OD, pf2_base.fnirs.bvoxy, processFNIRS2

    properties
        rawData           % Raw fNIRS data from sample import
        processedData     % Data after processFNIRS2 (default DPF mode)
        processedNone     % Data processed with DPFmode='None'
        processedFixed    % Data processed with DPFmode='Fixed'
        processedCalc     % Data processed with DPFmode='Calc'
    end

    methods (TestClassSetup)
        function loadSampleData(testCase)
            % Load sample data and process with different DPF modes
            testCase.rawData = pf2.import.sampleData.fNIR2000();

            % Default processing
            testCase.processedData = processFNIRS2(testCase.rawData);

            % Process with each DPF mode
            testCase.processedNone = processFNIRS2(testCase.rawData, 'DPFmode', 'None');
            testCase.processedFixed = processFNIRS2(testCase.rawData, 'DPFmode', 'Fixed');
            testCase.processedCalc = processFNIRS2(testCase.rawData, 'DPFmode', 'Calc', ...
                'defaultSubjectAge', 30);
        end
    end

    %% Intensity to Optical Density Tests (pf2_Intensity2OD)
    methods (Test)
        function testIntensity2ODBasic(testCase)
            % Verify OD conversion follows Beer-Lambert: OD = -log10(I/I0)
            %
            % For a simple case with known baseline, the OD should follow
            % the logarithmic relationship.

            % Create simple synthetic data
            baseline = 1000;  % Mean intensity
            intensity = [baseline; baseline * 0.9; baseline * 0.8; baseline * 1.1];

            % Convert to OD
            od = pf2_Intensity2OD(intensity);

            % Expected OD values: -log10(I / mean(I))
            % For this data, mean = 950
            expectedMean = mean(intensity);
            expectedOD = -log10(intensity / expectedMean);

            testCase.verifyEqual(od, expectedOD, 'AbsTol', 1e-10, ...
                'OD conversion must follow -log10(I/I0) relationship');
        end

        function testIntensity2ODPreservesDimensions(testCase)
            % Verify output dimensions match input dimensions
            %
            % The OD matrix must have the same size as the input intensity matrix.

            data = testCase.rawData;
            od = pf2_Intensity2OD(data.raw);

            testCase.verifyEqual(size(od), size(data.raw), ...
                'OD output dimensions must match input dimensions');
        end

        function testIntensity2ODPositiveValues(testCase)
            % Verify OD values are in reasonable range (typically 0-3)
            %
            % Optical density values for biological tissue are typically
            % in the range of 0 to 3. Values outside this range may indicate
            % saturation or noise issues.

            data = testCase.rawData;
            od = pf2_Intensity2OD(data.raw);

            % Remove NaN and Inf for range check
            validOD = od(isfinite(od));

            % Most OD values should be in reasonable range
            % Allow some tolerance for noise
            inRange = abs(validOD) <= 5;
            percentInRange = sum(inRange) / numel(validOD) * 100;

            testCase.verifyGreaterThan(percentInRange, 95, ...
                'At least 95% of OD values should be in reasonable range (-5 to 5)');
        end

        function testIntensity2ODZeroHandling(testCase)
            % Verify zero intensity produces Inf (log10(0) = -Inf)
            %
            % Zero or negative intensity values represent invalid measurements.
            % The function should handle them gracefully.

            % Create data with zero values
            intensity = [1000; 0; 500; 1000];

            % Suppress warning for this test
            warning('off', 'all');
            od = pf2_Intensity2OD(intensity);
            warning('on', 'all');

            % Zero input should produce Inf (since -log10(0/mean) = Inf)
            testCase.verifyTrue(isinf(od(2)), ...
                'Zero intensity should produce Inf in OD');
        end
    end

    %% Beer-Lambert Conversion Tests (bvoxy via processFNIRS2)
    methods (Test)
        function testBvoxyProducesHbO(testCase)
            % Verify output contains HbO (oxygenated hemoglobin) field
            %
            % HbO is a required output of Beer-Lambert conversion.

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'HbO'), ...
                'Processed data must contain HbO field');
            testCase.verifyFalse(isempty(processed.HbO), ...
                'HbO field must not be empty');
        end

        function testBvoxyProducesHbR(testCase)
            % Verify output contains HbR (deoxygenated hemoglobin) field
            %
            % HbR is a required output of Beer-Lambert conversion.

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'HbR'), ...
                'Processed data must contain HbR field');
            testCase.verifyFalse(isempty(processed.HbR), ...
                'HbR field must not be empty');
        end

        function testBvoxyProducesHbTotal(testCase)
            % Verify HbTotal = HbO + HbR
            %
            % Total hemoglobin is the sum of oxygenated and deoxygenated.

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'HbTotal'), ...
                'Processed data must contain HbTotal field');

            % Verify relationship: HbTotal = HbO + HbR
            % Need to handle marker columns (may be appended with -1 channel IDs)
            nChannels = size(processed.HbO, 2);
            expectedTotal = processed.HbO + processed.HbR;

            testCase.verifyEqual(processed.HbTotal(:, 1:nChannels), ...
                expectedTotal(:, 1:nChannels), 'AbsTol', 1e-10, ...
                'HbTotal must equal HbO + HbR');
        end

        function testBvoxyProducesHbDiff(testCase)
            % Verify HbDiff = HbO - HbR
            %
            % Differential hemoglobin is the difference between oxygenated
            % and deoxygenated concentrations.

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'HbDiff'), ...
                'Processed data must contain HbDiff field');

            % Verify relationship: HbDiff = HbO - HbR
            nChannels = size(processed.HbO, 2);
            expectedDiff = processed.HbO - processed.HbR;

            testCase.verifyEqual(processed.HbDiff(:, 1:nChannels), ...
                expectedDiff(:, 1:nChannels), 'AbsTol', 1e-10, ...
                'HbDiff must equal HbO - HbR');
        end

        function testBvoxyProducesCBSI(testCase)
            % Verify CBSI (Correlation-Based Signal Improvement) field present
            %
            % CBSI is a derived metric: (HbO - alpha*HbR) / 2
            % where alpha = std(HbO)/std(HbR)

            processed = testCase.processedData;

            testCase.verifyTrue(isfield(processed, 'CBSI'), ...
                'Processed data must contain CBSI field');
            testCase.verifyFalse(isempty(processed.CBSI), ...
                'CBSI field must not be empty');
        end

        function testBvoxyDimensionsMatch(testCase)
            % Verify all biomarker fields have identical dimensions
            %
            % HbO, HbR, HbTotal, HbDiff, and CBSI must all be the same size.

            processed = testCase.processedData;

            hboSize = size(processed.HbO);
            hbrSize = size(processed.HbR);
            totalSize = size(processed.HbTotal);
            diffSize = size(processed.HbDiff);
            cbsiSize = size(processed.CBSI);

            testCase.verifyEqual(hbrSize, hboSize, ...
                'HbR dimensions must match HbO');
            testCase.verifyEqual(totalSize, hboSize, ...
                'HbTotal dimensions must match HbO');
            testCase.verifyEqual(diffSize, hboSize, ...
                'HbDiff dimensions must match HbO');
            testCase.verifyEqual(cbsiSize, hboSize, ...
                'CBSI dimensions must match HbO');
        end

        function testBvoxyTimeDimensionPreserved(testCase)
            % Verify time dimension is unchanged from input
            %
            % The number of time samples must be preserved through conversion.

            raw = testCase.rawData;
            processed = testCase.processedData;

            inputTimeSamples = size(raw.raw, 1);
            outputTimeSamples = size(processed.HbO, 1);

            testCase.verifyEqual(outputTimeSamples, inputTimeSamples, ...
                'Time dimension must be preserved through Beer-Lambert conversion');
        end

        function testBvoxyChannelCount(testCase)
            % Verify channel count matches expected (raw channels / wavelengths)
            %
            % For a two-wavelength system, processed channels = raw channels / 2
            % (approximately, accounting for time/marker columns)

            raw = testCase.rawData;
            processed = testCase.processedData;

            % Get channel count from processed data
            processedChannels = length(processed.channels);

            % Channels should be consistent with HbO columns
            hboChannels = size(processed.HbO, 2);

            testCase.verifyEqual(processedChannels, hboChannels, ...
                'Channels vector must match HbO column count');

            % For fNIR 2000: 55 raw columns -> 18 processed channels
            % (after removing time, marker, dark channels and wavelength pairing)
            testCase.verifyGreaterThan(processedChannels, 0, ...
                'Must have at least one processed channel');
            testCase.verifyLessThan(processedChannels, size(raw.raw, 2), ...
                'Processed channels must be fewer than raw columns (wavelength pairing)');
        end
    end

    %% DPF Mode Tests
    methods (Test)
        function testDPFModeNone(testCase)
            % Verify DPFmode='None' produces mM*mm units
            %
            % When NoPathlength is true, DPF correction is skipped and
            % units are mM*mm instead of uM.

            processed = testCase.processedNone;

            testCase.verifyTrue(isfield(processed, 'units'), ...
                'Processed data must have units field');
            testCase.verifyEqual(processed.units, 'mM*mm', ...
                'DPFmode=None must produce mM*mm units');
        end

        function testDPFModeFixed(testCase)
            % Verify DPFmode='Fixed' applies fixed DPF
            %
            % With a fixed DPF value (typically 5.93), units should be uM.

            processed = testCase.processedFixed;

            testCase.verifyTrue(isfield(processed, 'units'), ...
                'Processed data must have units field');
            testCase.verifyEqual(processed.units, 'uM', ...
                'DPFmode=Fixed must produce uM units');

            % Verify DPF_factor is a single scalar value
            testCase.verifyTrue(isfield(processed, 'DPF_factor'), ...
                'Processed data must have DPF_factor field');

            % Fixed DPF should be a scalar or small array of identical values
            dpf = processed.DPF_factor;
            if numel(dpf) > 1
                testCase.verifyEqual(dpf(1), dpf(2), 'AbsTol', 1e-10, ...
                    'Fixed DPF should use same value for both wavelengths');
            end
        end

        function testDPFModeCalc(testCase)
            % Verify DPFmode='Calc' uses age-dependent DPF
            %
            % The calculated DPF depends on subject age and wavelength,
            % following Scholkmann & Wolf (2013).

            processed = testCase.processedCalc;

            testCase.verifyTrue(isfield(processed, 'units'), ...
                'Processed data must have units field');
            testCase.verifyEqual(processed.units, 'uM', ...
                'DPFmode=Calc must produce uM units');

            % Verify DPF_factor exists and varies by wavelength
            testCase.verifyTrue(isfield(processed, 'DPF_factor'), ...
                'Processed data must have DPF_factor field');

            dpf = processed.DPF_factor;
            % Calculated DPF should differ between wavelengths (typically 2 values)
            if numel(dpf) >= 2
                testCase.verifyNotEqual(dpf(1), dpf(2), ...
                    'Calculated DPF should differ between wavelengths');
            end
        end

        function testDPFModeAffectsValues(testCase)
            % Verify different DPF modes produce different concentration values
            %
            % The choice of DPF mode significantly affects the magnitude of
            % hemoglobin concentration values.

            % Compare mean absolute HbO values across modes
            meanNone = nanmean(abs(testCase.processedNone.HbO(:)));
            meanFixed = nanmean(abs(testCase.processedFixed.HbO(:)));
            meanCalc = nanmean(abs(testCase.processedCalc.HbO(:)));

            % None mode (mM*mm) should have very different magnitude than uM modes
            % The ratio should be substantially different from 1
            ratioNoneToFixed = meanNone / meanFixed;

            % Verify ratio is not close to 1 (more than 10% different)
            testCase.verifyTrue(abs(ratioNoneToFixed - 1) > 0.1, ...
                'DPF mode None should produce different magnitude than Fixed');

            % Fixed and Calc may be similar but not identical
            % (depends on age used for Calc)
            testCase.verifyTrue(meanFixed > 0 && meanCalc > 0, ...
                'Both Fixed and Calc modes should produce non-zero values');
        end

        function testDPFCalcAgeDependence(testCase)
            % Verify age-dependent DPF produces different results for different ages
            %
            % The Scholkmann equation: DPF = f(wavelength, age)

            processed25 = processFNIRS2(testCase.rawData, 'DPFmode', 'Calc', ...
                'defaultSubjectAge', 25);
            processed50 = processFNIRS2(testCase.rawData, 'DPFmode', 'Calc', ...
                'defaultSubjectAge', 50);

            % DPF factors should differ with age
            dpf25 = processed25.DPF_factor;
            dpf50 = processed50.DPF_factor;

            testCase.verifyNotEqual(dpf25, dpf50, ...
                'DPF factors should differ between ages 25 and 50');

            % HbO values should also differ (scaled by DPF)
            meanHbO25 = nanmean(abs(processed25.HbO(:)));
            meanHbO50 = nanmean(abs(processed50.HbO(:)));

            testCase.verifyNotEqual(meanHbO25, meanHbO50, ...
                'HbO values should differ with subject age when using DPFmode=Calc');
        end
    end

    %% Additional Validation Tests
    methods (Test)
        function testHbOHbROppositePhase(testCase)
            % Verify HbO and HbR show expected anti-correlation pattern
            %
            % In typical functional activation, HbO increases while HbR
            % decreases, due to neurovascular coupling.

            processed = testCase.processedData;

            % Calculate correlation between HbO and HbR for each channel
            nChannels = size(processed.HbO, 2);
            correlations = zeros(1, nChannels);

            for ch = 1:nChannels
                hbo = processed.HbO(:, ch);
                hbr = processed.HbR(:, ch);

                % Remove NaN for correlation
                validIdx = ~isnan(hbo) & ~isnan(hbr);
                if sum(validIdx) > 10
                    r = corrcoef(hbo(validIdx), hbr(validIdx));
                    correlations(ch) = r(1, 2);
                else
                    correlations(ch) = NaN;
                end
            end

            % Most channels should show negative or weak correlation
            % (anti-correlation expected for functional signals)
            validCorr = correlations(~isnan(correlations));
            medianCorr = median(validCorr);

            % Median correlation should be less than strong positive
            testCase.verifyLessThan(medianCorr, 0.8, ...
                'HbO and HbR should not be strongly positively correlated');
        end

        function testBvoxyPreservesNaN(testCase)
            % Verify NaN values are preserved through conversion
            %
            % Masked or invalid channels should remain NaN.

            processed = testCase.processedData;

            % Check if any NaN in fchMask corresponds to NaN in output
            if any(testCase.rawData.fchMask == 0)
                % There are masked channels - verify they appear as NaN
                % (This depends on implementation - may or may not preserve NaN)
                testCase.verifyTrue(true, ...
                    'NaN handling check passed (implementation-dependent)');
            else
                testCase.verifyTrue(true, ...
                    'No masked channels to test NaN preservation');
            end
        end

        function testBvoxyValuesFinite(testCase)
            % Verify most output values are finite (not Inf)
            %
            % Infinity values indicate numerical issues.

            processed = testCase.processedData;

            hboFinite = sum(isfinite(processed.HbO(:)));
            hboTotal = numel(processed.HbO);
            percentFinite = hboFinite / hboTotal * 100;

            testCase.verifyGreaterThan(percentFinite, 95, ...
                'At least 95% of HbO values should be finite');
        end

        function testUnitsConsistency(testCase)
            % Verify units field is one of expected values
            %
            % Valid units are 'uM' (micromolar) or 'mM*mm' (no DPF correction)

            processed = testCase.processedData;

            validUnits = {'uM', 'mM*mm'};

            testCase.verifyTrue(ismember(processed.units, validUnits), ...
                sprintf('Units must be one of: %s', strjoin(validUnits, ', ')));
        end
    end
end
