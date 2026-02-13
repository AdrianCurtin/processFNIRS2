classdef GraphMetricsTest < matlab.unittest.TestCase
% GRAPHMETRICSTEST Unit tests for graph theory metrics module
%
% Tests graph metric functions against synthetic matrices with known
% properties: complete graph K5, star graph, ring lattice, block-diagonal
% (two communities), directed graph, and integration pipeline.

    properties
        K5          % Complete graph K5 (5 nodes, all connected)
        star        % Star graph (1 center + 4 leaves)
        ring        % Ring lattice (10 nodes, each connected to 2 nearest)
        blockDiag   % Block-diagonal (2 communities, 4+4 nodes)
        directed    % Directed asymmetric graph
    end

    methods (TestMethodSetup)
        function createTestGraphs(testCase)
            % K5: Complete graph with 5 nodes
            K5mat = ones(5) - eye(5);
            testCase.K5 = exploreFNIRS.graph.threshold(K5mat, ...
                'Method', 'absolute', 'Value', 0.5);

            % Star: center node (1) connected to all others
            starMat = zeros(5);
            starMat(1, 2:5) = 1;
            starMat(2:5, 1) = 1;
            testCase.star = exploreFNIRS.graph.threshold(starMat, ...
                'Method', 'absolute', 'Value', 0.5);

            % Ring lattice: 10 nodes, each connected to 2 nearest neighbors
            N = 10;
            ringMat = zeros(N);
            for i = 1:N
                j1 = mod(i, N) + 1;
                j2 = mod(i - 2, N) + 1;
                ringMat(i, j1) = 1;
                ringMat(j1, i) = 1;
                ringMat(i, j2) = 1;
                ringMat(j2, i) = 1;
            end
            testCase.ring = exploreFNIRS.graph.threshold(ringMat, ...
                'Method', 'absolute', 'Value', 0.5);

            % Block-diagonal: two fully connected blocks of 4
            blockMat = zeros(8);
            blockMat(1:4, 1:4) = ones(4) - eye(4);
            blockMat(5:8, 5:8) = ones(4) - eye(4);
            testCase.blockDiag = exploreFNIRS.graph.threshold(blockMat, ...
                'Method', 'absolute', 'Value', 0.5);

            % Directed: asymmetric 4-node graph
            dirMat = [0 1 0 0; 0 0 1 0; 0 0 0 1; 1 0 0 0];
            testCase.directed = exploreFNIRS.graph.threshold(dirMat, ...
                'Method', 'absolute', 'Value', 0.5);
        end
    end

    %% Threshold tests
    methods (Test)
        function testThresholdAbsolute(testCase)
            mat = [0 0.5 0.2; 0.5 0 0.8; 0.2 0.8 0];
            G = exploreFNIRS.graph.threshold(mat, 'Method', 'absolute', 'Value', 0.3);
            testCase.verifyEqual(G.N, 3);
            testCase.verifyEqual(G.A(1,2), 1);  % 0.5 >= 0.3
            testCase.verifyEqual(G.A(1,3), 0);  % 0.2 < 0.3
            testCase.verifyEqual(G.A(2,3), 1);  % 0.8 >= 0.3
        end

        function testThresholdProportional(testCase)
            mat = [0 0.9 0.5 0.1; 0.9 0 0.3 0.2; ...
                   0.5 0.3 0 0.7; 0.1 0.2 0.7 0];
            G = exploreFNIRS.graph.threshold(mat, 'Method', 'proportional', ...
                'Value', 0.5);
            % 6 edges total, keep top 50% = 3 edges
            testCase.verifyGreaterThan(G.density, 0);
            testCase.verifyLessThanOrEqual(G.density, 0.6);
        end

        function testThresholdBinarize(testCase)
            mat = [0 0.7 0.3; 0.7 0 0.9; 0.3 0.9 0];
            G = exploreFNIRS.graph.threshold(mat, 'Binarize', true, ...
                'Method', 'absolute', 'Value', 0.5);
            testCase.verifyTrue(G.binarized);
            % All non-zero entries should be exactly 1
            nonzero = G.W(G.W > 0);
            testCase.verifyEqual(unique(nonzero), 1);
        end

        function testThresholdZeroDiagonal(testCase)
            mat = eye(3) + ones(3) * 0.5;
            G = exploreFNIRS.graph.threshold(mat, 'ZeroDiagonal', true);
            testCase.verifyEqual(diag(G.W), zeros(3, 1));
        end

        function testThresholdAcceptsStruct(testCase)
            connResult.matrix = ones(4) - eye(4);
            connResult.channels = [1 2 3 4];
            connResult.labels = {'A','B','C','D'};
            connResult.method = 'pearson';
            connResult.biomarker = 'HbO';
            G = exploreFNIRS.graph.threshold(connResult);
            testCase.verifyEqual(G.N, 4);
            testCase.verifyEqual(G.source.method, 'pearson');
        end

        function testThresholdAcceptsGroupResult(testCase)
            grpResult.Mean = ones(4) - eye(4);
            grpResult.channels = [1 2 3 4];
            grpResult.labels = {'A','B','C','D'};
            G = exploreFNIRS.graph.threshold(grpResult);
            testCase.verifyEqual(G.N, 4);
        end

        function testThresholdDirectedDetection(testCase)
            testCase.verifyTrue(testCase.directed.directed);
            testCase.verifyFalse(testCase.K5.directed);
        end

        function testThresholdDensity(testCase)
            % K5: all edges present, density = 1
            testCase.verifyEqual(testCase.K5.density, 1, 'AbsTol', 1e-10);
        end
    end

    %% Degree tests
    methods (Test)
        function testDegreeK5(testCase)
            d = exploreFNIRS.graph.degree(testCase.K5);
            % K5: every node has degree 4
            testCase.verifyEqual(d.degree, repmat(4, 1, 5));
            testCase.verifyEqual(d.strength, repmat(4, 1, 5));
        end

        function testDegreeStar(testCase)
            d = exploreFNIRS.graph.degree(testCase.star);
            % Center: degree 4, leaves: degree 1
            testCase.verifyEqual(d.degree(1), 4);
            testCase.verifyEqual(d.degree(2), 1);
        end

        function testDegreeDirected(testCase)
            d = exploreFNIRS.graph.degree(testCase.directed);
            testCase.verifyTrue(isfield(d, 'inDegree'));
            testCase.verifyTrue(isfield(d, 'outDegree'));
            % Cycle: each node has inDegree=1, outDegree=1
            testCase.verifyEqual(d.inDegree, ones(1, 4));
            testCase.verifyEqual(d.outDegree, ones(1, 4));
        end
    end

    %% Clustering coefficient tests
    methods (Test)
        function testClusteringK5(testCase)
            cc = exploreFNIRS.graph.clusteringCoefficient(testCase.K5);
            % K5: clustering coefficient = 1 for all nodes
            testCase.verifyEqual(cc.C, ones(1, 5), 'AbsTol', 1e-10);
            testCase.verifyEqual(cc.meanC, 1, 'AbsTol', 1e-10);
        end

        function testClusteringStar(testCase)
            cc = exploreFNIRS.graph.clusteringCoefficient(testCase.star);
            % Star: no triangles, clustering = 0
            testCase.verifyEqual(cc.meanC, 0, 'AbsTol', 1e-10);
        end

        function testTransitivityK5(testCase)
            cc = exploreFNIRS.graph.clusteringCoefficient(testCase.K5);
            testCase.verifyEqual(cc.transitivity, 1, 'AbsTol', 1e-10);
        end
    end

    %% Betweenness centrality tests
    methods (Test)
        function testBetweennessStar(testCase)
            bc = exploreFNIRS.graph.betweenness(testCase.star);
            % Center node should have highest betweenness
            [~, maxIdx] = max(bc.BC);
            testCase.verifyEqual(maxIdx, 1);
            % Leaves should have BC = 0
            testCase.verifyEqual(bc.BC(2:5), zeros(1, 4), 'AbsTol', 1e-10);
        end

        function testBetweennessK5(testCase)
            bc = exploreFNIRS.graph.betweenness(testCase.K5);
            % K5: all betweenness should be equal
            testCase.verifyEqual(bc.BC, repmat(bc.BC(1), 1, 5), 'AbsTol', 1e-10);
        end
    end

    %% Path length tests
    methods (Test)
        function testPathLengthK5(testCase)
            pl = exploreFNIRS.graph.charPathLength(testCase.K5);
            % K5: all direct connections, lambda = 1
            testCase.verifyEqual(pl.lambda, 1, 'AbsTol', 1e-10);
            testCase.verifyEqual(pl.nComponents, 1);
            testCase.verifyEqual(pl.diameter, 1, 'AbsTol', 1e-10);
        end

        function testPathLengthDisconnected(testCase)
            % Two isolated nodes
            mat = zeros(4);
            mat(1,2) = 1; mat(2,1) = 1;
            mat(3,4) = 1; mat(4,3) = 1;
            G = exploreFNIRS.graph.threshold(mat, 'Method', 'absolute', 'Value', 0.5);
            pl = exploreFNIRS.graph.charPathLength(G);
            testCase.verifyEqual(pl.nComponents, 2);
            % Lambda should be finite (only considers reachable pairs)
            testCase.verifyTrue(isfinite(pl.lambda));
        end

        function testPathLengthRing(testCase)
            pl = exploreFNIRS.graph.charPathLength(testCase.ring);
            % Ring with 10 nodes, max path = 5 hops
            testCase.verifyEqual(pl.nComponents, 1);
            testCase.verifyGreaterThan(pl.lambda, 1);
        end
    end

    %% Efficiency tests
    methods (Test)
        function testEfficiencyK5(testCase)
            eff = exploreFNIRS.graph.efficiency(testCase.K5);
            % K5: global efficiency = 1 (all distances = 1)
            testCase.verifyEqual(eff.globalEfficiency, 1, 'AbsTol', 1e-10);
        end

        function testEfficiencyDisconnected(testCase)
            mat = zeros(4);
            mat(1,2) = 1; mat(2,1) = 1;
            G = exploreFNIRS.graph.threshold(mat, 'Method', 'absolute', 'Value', 0.5);
            eff = exploreFNIRS.graph.efficiency(G);
            % Disconnected: efficiency < 1
            testCase.verifyLessThan(eff.globalEfficiency, 1);
        end

        function testLocalEfficiencyK5(testCase)
            eff = exploreFNIRS.graph.efficiency(testCase.K5);
            % K5: all local efficiencies = 1
            testCase.verifyEqual(eff.localEfficiency, ones(1, 5), 'AbsTol', 1e-10);
        end
    end

    %% Modularity tests
    methods (Test)
        function testModularityBlockDiagonal(testCase)
            mod = exploreFNIRS.graph.modularity(testCase.blockDiag, 'NReplicates', 20);
            % Should detect 2 communities
            testCase.verifyEqual(mod.nCommunities, 2);
            testCase.verifyGreaterThan(mod.Q, 0);
            % Nodes 1-4 should be in one community, 5-8 in another
            testCase.verifyEqual(length(unique(mod.communityID(1:4))), 1);
            testCase.verifyEqual(length(unique(mod.communityID(5:8))), 1);
            testCase.verifyNotEqual(mod.communityID(1), mod.communityID(5));
        end

        function testModularityK5(testCase)
            mod = exploreFNIRS.graph.modularity(testCase.K5, 'NReplicates', 10);
            % K5 has no clear community structure
            testCase.verifyLessThanOrEqual(mod.Q, 0.1);
        end

        function testParticipationCoefficient(testCase)
            mod = exploreFNIRS.graph.modularity(testCase.blockDiag, 'NReplicates', 20);
            % No inter-community edges: participation = 0
            testCase.verifyEqual(mod.participationCoeff, zeros(1, 8), 'AbsTol', 1e-10);
        end
    end

    %% Small-world tests (kept small for speed)
    methods (Test)
        function testSmallWorldRing(testCase)
            sw = exploreFNIRS.graph.smallWorld(testCase.ring, 'NRandom', 10);
            testCase.verifyTrue(isfield(sw, 'sigma'));
            testCase.verifyTrue(isfield(sw, 'omega'));
            testCase.verifyTrue(isfinite(sw.sigma) || isnan(sw.sigma));
        end
    end

    %% Hub detection tests
    methods (Test)
        function testDetectHubsStar(testCase)
            hubs = exploreFNIRS.graph.detectHubs(testCase.star);
            % Center node should be the hub
            testCase.verifyTrue(hubs.isHub(1));
        end

        function testDetectHubsWithModularity(testCase)
            mod = exploreFNIRS.graph.modularity(testCase.blockDiag, 'NReplicates', 10);
            hubs = exploreFNIRS.graph.detectHubs(testCase.blockDiag, 'Modularity', mod);
            testCase.verifyTrue(isfield(hubs, 'hubType'));
        end
    end

    %% computeMetrics integration tests
    methods (Test)
        function testComputeMetricsDefault(testCase)
            result = exploreFNIRS.graph.computeMetrics(ones(5) - eye(5));
            testCase.verifyTrue(isfield(result, 'graph'));
            testCase.verifyTrue(isfield(result, 'degree'));
            testCase.verifyTrue(isfield(result, 'clustering'));
            testCase.verifyTrue(isfield(result, 'betweenness'));
            testCase.verifyTrue(isfield(result, 'efficiency'));
            testCase.verifyTrue(isfield(result, 'pathLength'));
            testCase.verifyTrue(isfield(result, 'modularity'));
            testCase.verifyTrue(isfield(result, 'hubs'));
            % smallWorld NOT computed by default
            testCase.verifyFalse(isfield(result, 'smallWorld'));
        end

        function testComputeMetricsSubset(testCase)
            result = exploreFNIRS.graph.computeMetrics(ones(5) - eye(5), ...
                'Metrics', {'degree', 'clustering'});
            testCase.verifyTrue(isfield(result, 'degree'));
            testCase.verifyTrue(isfield(result, 'clustering'));
            testCase.verifyFalse(isfield(result, 'modularity'));
        end

        function testComputeMetricsAcceptsGraphStruct(testCase)
            result = exploreFNIRS.graph.computeMetrics(testCase.K5, ...
                'Metrics', {'degree'});
            testCase.verifyEqual(result.degree.degree, repmat(4, 1, 5));
        end

        function testComputeMetricsWithConnResult(testCase)
            connResult.matrix = ones(4) - eye(4);
            connResult.channels = [1 2 3 4];
            connResult.labels = {'A','B','C','D'};
            connResult.method = 'pearson';
            connResult.biomarker = 'HbO';
            result = exploreFNIRS.graph.computeMetrics(connResult, ...
                'Metrics', {'degree', 'efficiency'});
            testCase.verifyEqual(result.degree.degree, repmat(3, 1, 4));
        end
    end

    %% metricsToTable tests
    methods (Test)
        function testMetricsToTable(testCase)
            result = exploreFNIRS.graph.computeMetrics(ones(5) - eye(5));
            T = exploreFNIRS.graph.metricsToTable(result);
            testCase.verifyEqual(height(T), 5);
            testCase.verifyTrue(ismember('Degree', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('ClusteringCoeff', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('HubScore', T.Properties.VariableNames));
        end

        function testMetricsToTableMultiGroup(testCase)
            r1 = exploreFNIRS.graph.computeMetrics(ones(4) - eye(4));
            r2 = exploreFNIRS.graph.computeMetrics(0.5 * (ones(4) - eye(4)));
            T = exploreFNIRS.graph.metricsToTable([r1, r2], ...
                'GroupLabels', {'Control', 'Patient'});
            testCase.verifyEqual(height(T), 8);
            testCase.verifyTrue(ismember('Group', T.Properties.VariableNames));
        end
    end

    %% Plot tests (headless)
    methods (Test)
        function testPlotNetworkCreates(testCase)
            fig = exploreFNIRS.graph.plotNetwork(testCase.K5, 'Visible', 'off');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishghandle(fig));
        end

        function testPlotNetworkCircleLayout(testCase)
            fig = exploreFNIRS.graph.plotNetwork(testCase.ring, ...
                'Layout', 'circle', 'Visible', 'off');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishghandle(fig));
        end

        function testPlotNetworkWithCommunity(testCase)
            mod = exploreFNIRS.graph.modularity(testCase.blockDiag, 'NReplicates', 10);
            fig = exploreFNIRS.graph.plotNetwork(testCase.blockDiag, ...
                'CommunityID', mod.communityID, 'Visible', 'off');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishghandle(fig));
        end

        function testPlotMetricsCreates(testCase)
            result = exploreFNIRS.graph.computeMetrics(ones(5) - eye(5), ...
                'Metrics', {'degree', 'clustering', 'betweenness', ...
                'efficiency', 'hubs'});
            fig = exploreFNIRS.graph.plotMetrics(result, ...
                'Metric', 'degree', 'Visible', 'off');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishghandle(fig));
        end

        function testPlotMetricsMultiGroup(testCase)
            r1 = exploreFNIRS.graph.computeMetrics(ones(4) - eye(4), ...
                'Metrics', {'degree'});
            r2 = exploreFNIRS.graph.computeMetrics(0.5 * (ones(4) - eye(4)), ...
                'Metrics', {'degree'});
            fig = exploreFNIRS.graph.plotMetrics([r1, r2], ...
                'Metric', 'degree', 'GroupLabels', {'A','B'}, 'Visible', 'off');
            testCase.addTeardown(@() close(fig));
            testCase.verifyTrue(ishghandle(fig));
        end
    end

end
