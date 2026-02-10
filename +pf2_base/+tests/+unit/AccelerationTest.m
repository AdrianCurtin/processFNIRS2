classdef AccelerationTest < matlab.unittest.TestCase
    % ACCELERATIONTEST Unit tests for GPU/parallel acceleration utilities
    %
    %   Tests the functions in +pf2_base/+accel/:
    %     - isGPUAvailable: cached GPU detection
    %     - toGPU: conditional GPU transfer
    %     - gather: safe CPU gather
    %     - canParfor: parallel pool detection
    %
    %   GPU-specific tests use assumeTrue to skip gracefully on machines
    %   without a GPU.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.AccelerationTest');
    %       disp(results);
    %
    %   See also: pf2_base.accel.isGPUAvailable, pf2_base.accel.toGPU,
    %             pf2_base.accel.gather, pf2_base.accel.canParfor

    properties
        gpuInfo  % Cached GPU info for use in tests
    end

    methods (TestClassSetup)
        function probeGPU(testCase)
            testCase.gpuInfo = pf2_base.accel.isGPUAvailable('Reset');
        end
    end

    %% isGPUAvailable tests
    methods (Test)
        function testIsGPUAvailable_ReturnsStruct(testCase)
            info = pf2_base.accel.isGPUAvailable();
            testCase.verifyTrue(isstruct(info), 'Should return a struct');
            testCase.verifyTrue(isfield(info, 'available'), 'Missing .available');
            testCase.verifyTrue(isfield(info, 'backend'), 'Missing .backend');
            testCase.verifyTrue(isfield(info, 'deviceName'), 'Missing .deviceName');
            testCase.verifyTrue(isfield(info, 'totalMemory'), 'Missing .totalMemory');
        end

        function testIsGPUAvailable_AvailableIsLogical(testCase)
            info = pf2_base.accel.isGPUAvailable();
            testCase.verifyClass(info.available, 'logical');
        end

        function testIsGPUAvailable_BackendIsValid(testCase)
            info = pf2_base.accel.isGPUAvailable();
            validBackends = {'metal', 'cuda', 'none'};
            testCase.verifyTrue(ismember(info.backend, validBackends), ...
                sprintf('Backend "%s" not in expected set', info.backend));
        end

        function testIsGPUAvailable_CachingWorks(testCase)
            % Two calls should return identical results (cached)
            info1 = pf2_base.accel.isGPUAvailable();
            info2 = pf2_base.accel.isGPUAvailable();
            testCase.verifyEqual(info1.available, info2.available);
            testCase.verifyEqual(info1.backend, info2.backend);
        end

        function testIsGPUAvailable_ResetFlag(testCase)
            % Reset should not error and should return valid struct
            info = pf2_base.accel.isGPUAvailable('Reset');
            testCase.verifyTrue(isstruct(info));
            testCase.verifyTrue(isfield(info, 'available'));
        end

        function testIsGPUAvailable_ConsistentAfterReset(testCase)
            info1 = pf2_base.accel.isGPUAvailable();
            info2 = pf2_base.accel.isGPUAvailable('Reset');
            testCase.verifyEqual(info1.available, info2.available);
        end

        function testIsGPUAvailable_MemoryNonNegative(testCase)
            info = pf2_base.accel.isGPUAvailable();
            testCase.verifyGreaterThanOrEqual(info.totalMemory, 0);
        end

        function testIsGPUAvailable_NoGPUMeansNoneBackend(testCase)
            info = pf2_base.accel.isGPUAvailable();
            if ~info.available
                testCase.verifyEqual(info.backend, 'none');
                testCase.verifyEqual(info.deviceName, 'none');
                testCase.verifyEqual(info.totalMemory, 0);
            end
        end
    end

    %% toGPU tests
    methods (Test)
        function testToGPU_SmallArrayStaysOnCPU(testCase)
            data = rand(10, 10);  % 100 elements, below default 10000
            [result, onGPU] = pf2_base.accel.toGPU(data);
            testCase.verifyFalse(onGPU, 'Small array should stay on CPU');
            testCase.verifyEqual(result, data);
        end

        function testToGPU_CustomMinElements(testCase)
            data = rand(5, 5);  % 25 elements
            [~, onGPU] = pf2_base.accel.toGPU(data, 'MinElements', 50);
            testCase.verifyFalse(onGPU, 'Below custom threshold should stay on CPU');
        end

        function testToGPU_LargeArrayWithGPU(testCase)
            testCase.assumeTrue(testCase.gpuInfo.available, 'GPU not available');
            data = rand(200, 200);  % 40000 elements > 10000
            [result, onGPU] = pf2_base.accel.toGPU(data);
            testCase.verifyTrue(onGPU, 'Large array should go to GPU');
            testCase.verifyTrue(isa(result, 'gpuArray'));
        end

        function testToGPU_ForceFlag(testCase)
            testCase.assumeTrue(testCase.gpuInfo.available, 'GPU not available');
            data = rand(3, 3);  % tiny array
            [result, onGPU] = pf2_base.accel.toGPU(data, 'Force', true);
            testCase.verifyTrue(onGPU, 'Force should override size threshold');
            testCase.verifyTrue(isa(result, 'gpuArray'));
        end

        function testToGPU_NoGPUNeverTransfers(testCase)
            testCase.assumeFalse(testCase.gpuInfo.available, 'GPU is available, skip');
            data = rand(200, 200);
            [~, onGPU] = pf2_base.accel.toGPU(data);
            testCase.verifyFalse(onGPU);
        end

        function testToGPU_PreservesValues(testCase)
            testCase.assumeTrue(testCase.gpuInfo.available, 'GPU not available');
            data = rand(200, 200);
            [result, ~] = pf2_base.accel.toGPU(data);
            gathered = pf2_base.accel.gather(result);
            testCase.verifyEqual(gathered, data, 'AbsTol', 1e-15);
        end
    end

    %% gather tests
    methods (Test)
        function testGather_CPUArrayUnchanged(testCase)
            data = rand(5, 5);
            result = pf2_base.accel.gather(data);
            testCase.verifyEqual(result, data);
            testCase.verifyFalse(isa(result, 'gpuArray'));
        end

        function testGather_GPUArrayToCPU(testCase)
            testCase.assumeTrue(testCase.gpuInfo.available, 'GPU not available');
            data = gpuArray(rand(10, 10));
            result = pf2_base.accel.gather(data);
            testCase.verifyFalse(isa(result, 'gpuArray'));
            testCase.verifyClass(result, 'double');
        end

        function testGather_IntegerArray(testCase)
            data = int32([1 2 3; 4 5 6]);
            result = pf2_base.accel.gather(data);
            testCase.verifyEqual(result, data);
        end

        function testGather_SinglePrecision(testCase)
            data = single(rand(5, 5));
            result = pf2_base.accel.gather(data);
            testCase.verifyEqual(result, data);
            testCase.verifyClass(result, 'single');
        end
    end

    %% canParfor tests
    methods (Test)
        function testCanParfor_ReturnsLogicals(testCase)
            [canUse, poolRunning] = pf2_base.accel.canParfor();
            testCase.verifyClass(canUse, 'logical');
            testCase.verifyClass(poolRunning, 'logical');
        end

        function testCanParfor_PoolRunningImpliesCanUse(testCase)
            [canUse, poolRunning] = pf2_base.accel.canParfor();
            if poolRunning
                testCase.verifyTrue(canUse, ...
                    'If pool is running, canUse must be true');
            end
        end

        function testCanParfor_Idempotent(testCase)
            [c1, p1] = pf2_base.accel.canParfor();
            [c2, p2] = pf2_base.accel.canParfor();
            testCase.verifyEqual(c1, c2);
            testCase.verifyEqual(p1, p2);
        end
    end
end
