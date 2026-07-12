classdef ClusterPermutationTest < matlab.unittest.TestCase
% CLUSTERPERMUTATIONTEST Unit tests for cluster-based permutation testing
%
% Tests adjacency matrix computation, cluster finding, and the full
% cluster permutation pipeline.
%
% Run:
%   runtests('pf2_base.tests.unit.ClusterPermutationTest')

    properties (TestParameter)
        clusterStatType = {'sumstat', 'maxstat', 'extent'}
    end

    methods (Test)

        %% computeAdjacency tests

        function testAdjacencyFromDeviceName(testCase)
            % Verify adjacency can be computed from a device config name
            adj = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000', ...
                'MaxDistance', 30);
            testCase.verifyTrue(issparse(adj), 'Adjacency should be sparse');
            testCase.verifyEqual(size(adj,1), size(adj,2), 'Should be square');
            % No self-adjacency
            testCase.verifyEqual(nnz(diag(adj)), 0, 'Diagonal should be zero');
        end

        function testAdjacencyFromDataStruct(testCase)
            % Verify adjacency from a data struct
            data = pf2.import.sampleData.fNIR2000();
            adj = pf2.probe.computeAdjacency(data, 'MaxDistance', 30);
            testCase.verifyTrue(issparse(adj));
            testCase.verifyGreaterThan(nnz(adj), 0, 'Should have some neighbors');
        end

        function testAdjacencySymmetric(testCase)
            % Adjacency matrix must be symmetric
            adj = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000', ...
                'MaxDistance', 40);
            testCase.verifyEqual(full(adj), full(adj'), ...
                'Adjacency must be symmetric');
        end

        function testAdjacencyDistanceThreshold(testCase)
            % Larger distance = more neighbors
            adj30 = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000', ...
                'MaxDistance', 30);
            adj60 = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000', ...
                'MaxDistance', 60);
            testCase.verifyGreaterThanOrEqual(nnz(adj60), nnz(adj30), ...
                'Larger distance should yield more neighbors');
        end

        function testAdjacencyZeroDistance(testCase)
            % Distance = 0 should produce no neighbors (no two channels
            % share the same position)
            adj = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000', ...
                'MaxDistance', 0.001);
            testCase.verifyEqual(nnz(adj), 0, ...
                'Tiny distance should produce no neighbors');
        end

        function testAdjacencyNoMNIError(testCase)
            % Device without MNI should error
            data = struct('raw', rand(100,4), 'time', (1:100)'/10, ...
                'fs', 10, 'fchMask', ones(1,4));
            % Create a minimal device without MNI — any error is acceptable
            threw = false;
            try
                pf2.probe.computeAdjacency(data);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, ...
                'computeAdjacency should error for data without MNI');
        end

        %% findClusters tests

        function testFindClustersSimple(testCase)
            % Simple case: 4 channels in a line, middle two above threshold
            adj = sparse([0 1 0 0; 1 0 1 0; 0 1 0 1; 0 0 1 0]);
            statMap = [0.5, 3.0, 2.5, 0.1];
            threshold = 2.0;

            clusters = exploreFNIRS.stats.findClusters(statMap, adj, threshold);
            testCase.verifyLength(clusters, 1, 'Should find one cluster');
            testCase.verifyEqual(sort(clusters(1).channels), [2, 3]);
        end

        function testFindClustersNoSignificant(testCase)
            % No channels above threshold
            adj = sparse([0 1; 1 0]);
            statMap = [0.5, 0.3];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0);
            testCase.verifyEmpty(clusters);
        end

        function testFindClustersAllSignificant(testCase)
            % All channels above threshold, all connected
            adj = sparse([0 1 1; 1 0 1; 1 1 0]);
            statMap = [3.0, 4.0, 5.0];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0);
            testCase.verifyLength(clusters, 1);
            testCase.verifyEqual(sort(clusters(1).channels), [1, 2, 3]);
        end

        function testFindClustersTwoDisconnected(testCase)
            % Two separate clusters
            adj = sparse([0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]);
            statMap = [3.0, 3.0, 4.0, 4.0];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0);
            testCase.verifyLength(clusters, 2, 'Should find two clusters');
        end

        function testFindClustersSumstat(testCase)
            % Verify sumstat computation
            adj = sparse([0 1 0; 1 0 1; 0 1 0]);
            statMap = [3.0, 4.0, 5.0];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0, 'sumstat');
            testCase.verifyEqual(clusters(1).stat, 12.0, 'AbsTol', 1e-10);
        end

        function testFindClustersMaxstat(testCase)
            % Verify maxstat computation
            adj = sparse([0 1 0; 1 0 1; 0 1 0]);
            statMap = [3.0, 4.0, 5.0];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0, 'maxstat');
            testCase.verifyEqual(clusters(1).stat, 5.0, 'AbsTol', 1e-10);
        end

        function testFindClustersExtent(testCase)
            % Verify extent computation (number of channels)
            adj = sparse([0 1 0; 1 0 1; 0 1 0]);
            statMap = [3.0, 4.0, 5.0];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0, 'extent');
            testCase.verifyEqual(clusters(1).stat, 3);
        end

        function testFindClustersBothTails(testCase)
            % Both positive and negative clusters
            adj = sparse([0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]);
            statMap = [3.0, 4.0, -3.5, -4.5];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0, 'sumstat', 'both');
            testCase.verifyLength(clusters, 2);

            polarities = {clusters.polarity};
            testCase.verifyTrue(ismember('positive', polarities));
            testCase.verifyTrue(ismember('negative', polarities));
        end

        function testFindClustersPositiveTailOnly(testCase)
            % Only positive tail
            adj = sparse([0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0]);
            statMap = [3.0, 4.0, -3.5, -4.5];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0, 'sumstat', 'positive');
            testCase.verifyLength(clusters, 1);
            testCase.verifyEqual(clusters(1).polarity, 'positive');
        end

        function testFindClustersSingleChannel(testCase)
            % Single isolated significant channel (no connected neighbor)
            adj = sparse([0 0 0; 0 0 0; 0 0 0]);
            statMap = [3.0, 0.1, 0.1];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0);
            testCase.verifyLength(clusters, 1);
            testCase.verifyEqual(clusters(1).channels, 1);
        end

        function testFindClustersParameterized(testCase, clusterStatType)
            % Verify all cluster stat types work without error
            adj = sparse([0 1 0; 1 0 1; 0 1 0]);
            statMap = [3.0, 4.0, 2.5];
            clusters = exploreFNIRS.stats.findClusters(statMap, adj, 2.0, clusterStatType);
            testCase.verifyNotEmpty(clusters);
        end

        %% Integration tests (with synthetic data)

        function testClusterPermutationSyntheticSetup(testCase)
            % Verify the pipeline runs without error on minimal synthetic data.
            % We can't do a full permutation test without real LME results,
            % but we can verify the adjacency + findClusters integration.

            % Create synthetic adjacency (5 channels in a line)
            adj = sparse(5, 5);
            adj(1,2) = 1; adj(2,1) = 1;
            adj(2,3) = 1; adj(3,2) = 1;
            adj(3,4) = 1; adj(4,3) = 1;
            adj(4,5) = 1; adj(5,4) = 1;

            % Synthetic stats: channels 2-4 have a strong effect
            statMap = [0.5, 3.5, 4.0, 3.0, 0.2];
            threshold = 2.0;

            clusters = exploreFNIRS.stats.findClusters(statMap, adj, threshold);
            testCase.verifyLength(clusters, 1);
            testCase.verifyEqual(sort(clusters(1).channels), [2, 3, 4]);
            testCase.verifyEqual(clusters(1).stat, 3.5 + 4.0 + 3.0, 'AbsTol', 1e-10);
        end

        function testNullDistributionShape(testCase)
            % Verify null distribution from random stats is well-behaved

            adj = sparse([0 1 0 0; 1 0 1 0; 0 1 0 1; 0 0 1 0]);
            nPerm = 100;
            nullDist = zeros(1, nPerm);
            threshold = 2.0;

            for iPerm = 1:nPerm
                permStat = randn(1, 4);
                clusters = exploreFNIRS.stats.findClusters(permStat, adj, threshold);
                if ~isempty(clusters)
                    nullDist(iPerm) = max(abs([clusters.stat]));
                end
            end

            % Null distribution should have correct size and contain
            % mostly small values (median near zero for random data)
            testCase.verifyEqual(length(nullDist), nPerm);
            testCase.verifyGreaterThan(sum(nullDist == 0), nPerm * 0.3, ...
                'Most permutations of random data should produce no clusters');
        end

        function testAdjacentChannelsMeaningful(testCase)
            % Verify that fNIR2000 device has reasonable adjacency structure
            adj = pf2.probe.computeAdjacency('fNIR_Devices_fNIR2000', ...
                'MaxDistance', 30);
            nCh = size(adj, 1);

            % Each channel should have at least 1 neighbor within 30mm
            neighborsPerCh = full(sum(adj, 2));
            hasNeighbors = neighborsPerCh > 0;

            % At least 50% of channels should have neighbors
            testCase.verifyGreaterThan(sum(hasNeighbors) / nCh, 0.5, ...
                'Most channels should have at least one neighbor at 30mm');
        end

    end

end
