classdef AccelMotionTest < matlab.unittest.TestCase
    % ACCELMOTIONTEST Unit tests for accelerometer-informed motion handling
    %
    % Covers pf2_base.fnirs.accelMotionDetect (motion flagging), accelRegress
    % (artifact removal), and pf2.data.extractBlocks aux-conditioned trial
    % rejection on synthetic data with known motion bursts.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.AccelMotionTest');

    methods (Test)
        function testDetectFlagsMotionBursts(testCase)
            d = makeAccelData();
            [mask, info] = pf2_base.fnirs.accelMotionDetect(d, 'Metric', 'norm');
            % Burst regions [30,33] and [80,83] should be flagged
            inBurst1 = d.time >= 30 & d.time <= 33;
            inBurst2 = d.time >= 80 & d.time <= 83;
            clean = d.time < 25 | (d.time > 40 & d.time < 75) | d.time > 90;
            testCase.verifyGreaterThan(mean(mask(inBurst1)), 0.5);
            testCase.verifyGreaterThan(mean(mask(inBurst2)), 0.5);
            testCase.verifyLessThan(mean(mask(clean)), 0.05);
            testCase.verifyGreaterThanOrEqual(size(info.windows, 1), 2);
        end

        function testDetectAutoSignalAndClean(testCase)
            d = makeAccelData();
            % auto-detect ACCEL signal by type (no 'Signal' given)
            mask = pf2_base.fnirs.accelMotionDetect(d);
            testCase.verifyTrue(islogical(mask));
            testCase.verifyEqual(numel(mask), numel(d.time));
        end

        function testAccelRegressRemovesArtifact(testCase)
            d = makeAccelData();
            accNorm = sqrt(sum(d.Aux.accelerometer.data.^2, 2));
            accNorm = accNorm - median(accNorm);
            neural = sin(2*pi*0.05*d.time);   % planted neural component

            before = corr(d.HbO(:,1), accNorm);
            corrected = pf2_base.fnirs.accelRegress(d, 'Biomarkers', {'HbO'});
            after = corr(corrected.HbO(:,1), accNorm);

            testCase.verifyLessThan(abs(after), abs(before), ...
                'Accel regression should reduce correlation with motion');
            testCase.verifyLessThan(abs(after), 0.1);
            % The neural component must be PRESERVED (not just artifact removed)
            testCase.verifyGreaterThan(corr(corrected.HbO(:,1), neural), 0.9, ...
                'Neural component should survive accel regression');
            testCase.verifyTrue(isfield(corrected, 'accelRegressInfo'));
        end

        function testExtractBlocksRejectByAuxAutoDetect(testCase)
            % RejectByAux=true should auto-detect the ACCEL-type signal
            d = makeAccelData();
            onsets = [20; 30; 80; 100];
            d.markers = pf2_base.normalizeMarkers([onsets, ones(4,1), 5*ones(4,1)]);
            blocks = pf2.data.defineBlocks(d, 1, 5, 'Embed', false);
            segKept = pf2.data.extractBlocks(d, blocks, 'PreTime', 0, 'PostTime', 0, ...
                'RejectByAux', true);
            testCase.verifyEqual(numel(segKept), 2, ...
                'Auto-detected accel rejection should drop the 2 motion epochs');
        end

        function testExtractBlocksRejectByAux(testCase)
            d = makeAccelData();
            % Markers: clean (20,100), motion-overlapping (30,80)
            onsets = [20; 30; 80; 100];
            d.markers = pf2_base.normalizeMarkers([onsets, ones(4,1), 5*ones(4,1)]);
            blocks = pf2.data.defineBlocks(d, 1, 5, 'Embed', false);

            segAll = pf2.data.extractBlocks(d, blocks, 'PreTime', 0, 'PostTime', 0);
            segKept = pf2.data.extractBlocks(d, blocks, 'PreTime', 0, 'PostTime', 0, ...
                'RejectByAux', 'accelerometer');

            testCase.verifyEqual(numel(segAll), 4);
            testCase.verifyEqual(numel(segKept), 2, ...
                'Two motion-overlapping epochs should be rejected');
        end
    end
end

function d = makeAccelData()
% MAKEACCELDATA Synthetic fNIRS struct with motion bursts in accel + HbO
rng(7);
fs = 10;
t = (0:1/fs:120)';
n = numel(t);

% Accelerometer: small baseline noise + bursts at [30,33] and [80,83]
acc = 0.01 * randn(n, 3);
burst = (t >= 30 & t <= 33) | (t >= 80 & t <= 83);
acc(burst, :) = acc(burst, :) + 0.3 * randn(sum(burst), 3);
accNorm = sqrt(sum(acc.^2, 2));
accNorm = accNorm - median(accNorm);

% HbO: slow neural component + motion contamination proportional to accel norm
neural = sin(2*pi*0.05*t);
HbO = [neural + 10*accNorm + 0.01*randn(n,1), ...
       0.5*neural + 8*accNorm + 0.01*randn(n,1)];

d.time = t;
d.fs = fs;
d.HbO = HbO;
d.HbR = -0.4 * HbO;
d.HbTotal = d.HbO + d.HbR;
d.HbDiff = d.HbO - d.HbR;
d.CBSI = 0.5 * (d.HbO - d.HbR);
d.Aux.accelerometer.data = acc;
d.Aux.accelerometer.time = t;
d.Aux.accelerometer.unit = 'g';
d.Aux.accelerometer.varNames = {'X','Y','Z'};
d.info = struct('SubjectID', 'synthetic');
end
