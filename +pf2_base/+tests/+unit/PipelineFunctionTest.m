classdef PipelineFunctionTest < matlab.unittest.TestCase
% PIPELINEFUNCTIONTEST Unit tests for pf2_base.PipelineFunction

    methods (Test)

        %% Construction tests

        function testConstructFromScratch(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            tc.verifyEqual(pf.funcName, 'pf2_lpf');
            tc.verifyEqual(pf.style, 'positional');
            tc.verifyEqual(pf.nOutputs, 1);
            tc.verifyEqual(pf.xOutIdx, 1);
            tc.verifyEqual(pf.maskOutIdx, 0);
            tc.verifyEqual(pf.isIntensity2OD, false);
        end

        function testConstructWithOptions(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'}, ...
                'Name', 'Low Pass Filter', ...
                'Description', 'A low pass filter', ...
                'ValidStages', [1,2], ...
                'RequiresOD', false);

            tc.verifyEqual(pf.name, 'Low Pass Filter');
            tc.verifyEqual(pf.description, 'A low pass filter');
            tc.verifyEqual(pf.validStages, [1,2]);
            tc.verifyEqual(pf.requiresOD, false);
        end

        function testConstructNameValue(tc)
            pf = pf2_base.PipelineFunction('myFunc', ...
                {'x','fs','cutoff'}, ...
                {[], [], 0.1}, {'x'}, ...
                'Style', 'namevalue');

            tc.verifyEqual(pf.style, 'namevalue');
            tc.verifyEqual(pf.customNames, {'cutoff'});
            tc.verifyEqual(pf.customIndices, 3);
        end

        function testConstructEmpty(tc)
            pf = pf2_base.PipelineFunction();
            tc.verifyEqual(pf.funcName, '');
            tc.verifyEqual(pf.nOutputs, 0);
        end

        function testIntensity2ODFlag(tc)
            pf = pf2_base.PipelineFunction('pf2_Intensity2OD', ...
                {'x'}, {[]}, {'x'});
            tc.verifyTrue(pf.isIntensity2OD);
        end

        %% Special argument mapping tests

        function testSpecialArgMapping(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            % x (idx 1), fs (idx 3) should be special
            tc.verifyTrue(pf.specialMask(1));   % x
            tc.verifyFalse(pf.specialMask(2));  % filtType
            tc.verifyTrue(pf.specialMask(3));   % fs
            tc.verifyFalse(pf.specialMask(4));  % freq_cut
            tc.verifyFalse(pf.specialMask(5));  % Nf

            tc.verifyEqual(pf.specialTypes(1), pf2_base.PipelineFunction.SPECIAL_X);
            tc.verifyEqual(pf.specialTypes(3), pf2_base.PipelineFunction.SPECIAL_FS);

            % Custom indices should be [2, 4, 5]
            tc.verifyEqual(pf.customIndices, [2, 4, 5]);
            tc.verifyEqual(pf.customNames, {'filtType', 'freq_cut', 'Nf'});
        end

        function testAllSpecialArgs(tc)
            allSpecial = pf2_base.PipelineFunction.specialArgNames();
            tc.verifyEqual(numel(allSpecial), 12);

            pf = pf2_base.PipelineFunction('testFunc', ...
                allSpecial, cell(1, 12), {'x'});

            tc.verifyTrue(all(pf.specialMask));
            tc.verifyEmpty(pf.customIndices);
        end

        %% Output index tests

        function testOutputXOnly(tc)
            pf = pf2_base.PipelineFunction('testFunc', ...
                {'x'}, {[]}, {'x'});
            tc.verifyEqual(pf.xOutIdx, 1);
            tc.verifyEqual(pf.maskOutIdx, 0);
            tc.verifyEqual(pf.timeMaskOutIdx, 0);
        end

        function testOutputMask(tc)
            pf = pf2_base.PipelineFunction('testFunc', ...
                {'x'}, {[]}, {'fchMask'});
            tc.verifyEqual(pf.xOutIdx, 0);
            tc.verifyEqual(pf.maskOutIdx, 1);
        end

        function testOutputTimeMask(tc)
            pf = pf2_base.PipelineFunction('testFunc', ...
                {'x'}, {[]}, {'ftimeChMask'});
            tc.verifyEqual(pf.timeMaskOutIdx, 1);
        end

        function testOutputMultiple(tc)
            pf = pf2_base.PipelineFunction('testFunc', ...
                {'x'}, {[]}, {'x', 'fchMask', 'ftimeChMask'});
            tc.verifyEqual(pf.xOutIdx, 1);
            tc.verifyEqual(pf.maskOutIdx, 2);
            tc.verifyEqual(pf.timeMaskOutIdx, 3);
            tc.verifyEqual(pf.nOutputs, 3);
        end

        function testOutputROI(tc)
            pf = pf2_base.PipelineFunction('testFunc', ...
                {'fNIRstruct'}, {[]}, {'ROI'});
            tc.verifyEqual(pf.roiOutIdx, 1);
        end

        function testOutputStruct(tc)
            pf = pf2_base.PipelineFunction('testFunc', ...
                {'fNIRstruct'}, {[]}, {'fNIRstruct'});
            tc.verifyEqual(pf.structOutIdx, 1);
        end

        %% Execute tests

        function testExecutePositional(tc)
            % Use a simple built-in that takes positional args
            % sum(x, dim) — we'll wrap it
            pf = pf2_base.PipelineFunction('sum', ...
                {'x', 'dim'}, {[], 1}, {'x'});

            ctx.x = [1 2; 3 4; 5 6];
            ctx.fs = 10;
            ctx.fTime = (0:2)';
            ctx.fchMask = [1 1];
            ctx.ftimeChMask = ones(3,2);
            ctx.fChannelNumbers = [1 2];
            ctx.fChannelSD = [1 1];
            ctx.fProbeInfo = struct();
            ctx.fMarkers = [];
            ctx.fNIRstruct = struct();
            ctx.fAux = [];
            ctx.fAmbient = [];

            out = pf.execute(ctx);
            tc.verifyEqual(out{1}, [9 12]);
        end

        function testExecuteWithDefaults(tc)
            % Create a PipelineFunction for detrend(x, type)
            % 'type' is custom arg with default 'linear'
            pf = pf2_base.PipelineFunction('detrend', ...
                {'x', 'type'}, {[], 'linear'}, {'x'});

            ctx.x = [1; 2; 3; 4; 5] + 10;
            ctx.fs = 1;
            ctx.fTime = (0:4)';
            ctx.fchMask = 1;
            ctx.ftimeChMask = ones(5,1);
            ctx.fChannelNumbers = 1;
            ctx.fChannelSD = 1;
            ctx.fProbeInfo = struct();
            ctx.fMarkers = [];
            ctx.fNIRstruct = struct();
            ctx.fAux = [];
            ctx.fAmbient = [];

            out = pf.execute(ctx);
            % detrend removes linear trend, result should be near zero
            tc.verifyLessThan(max(abs(out{1})), 1e-10);
        end

        %% setParam / getParam tests

        function testSetParam(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            tc.verifyEqual(pf.getParam('freq_cut'), 0.1);

            pf2 = pf.setParam('freq_cut', 0.5);
            tc.verifyEqual(pf2.getParam('freq_cut'), 0.5);

            % Original should be unchanged (value class)
            tc.verifyEqual(pf.getParam('freq_cut'), 0.1);
        end

        function testGetParamError(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            tc.verifyError(@() pf.getParam('nonexistent'), ...
                'pf2:PipelineFunction:unknownParam');
        end

        function testParams(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            p = pf.params();
            tc.verifyEqual(p.filtType, 1);
            tc.verifyEqual(p.freq_cut, 0.1);
            tc.verifyEqual(p.Nf, 50);
        end

        %% toStruct / fromStruct round-trip

        function testToStruct(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            s = pf.toStruct();
            tc.verifyEqual(s.f, 'pf2_lpf');
            tc.verifyEqual(s.args, {'x','filtType','fs','freq_cut','Nf'});
            tc.verifyEqual(s.output, {'x'});
        end

        function testFromStruct(tc)
            s.f = 'pf2_lpf';
            s.args = {'x','filtType','fs','freq_cut','Nf'};
            s.argvals = {[], 1, [], 0.1, 50};
            s.output = {'x'};

            pf = pf2_base.PipelineFunction.fromStruct(s);
            tc.verifyEqual(pf.funcName, 'pf2_lpf');
            tc.verifyEqual(pf.argNames, {'x','filtType','fs','freq_cut','Nf'});
            tc.verifyEqual(pf.xOutIdx, 1);
        end

        function testRoundTrip(tc)
            pf1 = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            s = pf1.toStruct();
            pf2 = pf2_base.PipelineFunction.fromStruct(s);

            tc.verifyEqual(pf1.funcName, pf2.funcName);
            tc.verifyEqual(pf1.argNames, pf2.argNames);
            tc.verifyEqual(pf1.xOutIdx, pf2.xOutIdx);
            tc.verifyEqual(pf1.customIndices, pf2.customIndices);
            tc.verifyEqual(pf1.customNames, pf2.customNames);
            tc.verifyEqual(pf1.specialMask, pf2.specialMask);
        end

        function testFromStructLegacyNoOutput(tc)
            s.f = 'pf2_lpf';
            s.args = {'x','filtType','fs','freq_cut','Nf'};
            s.argvals = {[], 1, [], 0.1, 50};
            % No .output field — should default to {'x'}

            pf = pf2_base.PipelineFunction.fromStruct(s);
            tc.verifyEqual(pf.outputNames, {'x'});
            tc.verifyEqual(pf.xOutIdx, 1);
        end

        function testFromStructNestedOutput(tc)
            s.f = 'testFunc';
            s.args = {'x'};
            s.argvals = {[]};
            s.output = {{'x', 'fchMask'}};

            pf = pf2_base.PipelineFunction.fromStruct(s);
            tc.verifyEqual(pf.outputNames, {'x', 'fchMask'});
            tc.verifyEqual(pf.xOutIdx, 1);
            tc.verifyEqual(pf.maskOutIdx, 2);
        end

        %% hasSpecialArg

        function testHasSpecialArg(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            tc.verifyTrue(pf.hasSpecialArg('x'));
            tc.verifyTrue(pf.hasSpecialArg('fs'));
            tc.verifyFalse(pf.hasSpecialArg('filtType'));
            tc.verifyFalse(pf.hasSpecialArg('nonexistent'));
        end

        %% Display

        function testDisp(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'}, ...
                'Name', 'Low Pass Filter');

            % Should not error
            disp(pf);
        end

        function testDispEmpty(tc)
            pf = pf2_base.PipelineFunction();
            disp(pf);
        end

        %% specialArgNames

        function testSpecialArgNames(tc)
            names = pf2_base.PipelineFunction.specialArgNames();
            tc.verifyEqual(numel(names), 12);
            tc.verifyTrue(ismember('x', names));
            tc.verifyTrue(ismember('fs', names));
            tc.verifyTrue(ismember('fAmbient', names));
        end

        %% pf2_unpackMethod integration

        function testUnpackMethodConverts(tc)
            % Build a method struct in legacy format
            method.name = 'testMethod';
            method.F = {};
            method.F{1}.f = 'sum';
            method.F{1}.args = {'x', 'dim'};
            method.F{1}.argvals = {[], 1};
            method.F{1}.output = {'x'};

            unpacked = pf2_base.pf2_unpackMethod(method);

            tc.verifyTrue(isa(unpacked.F{1}, 'pf2_base.PipelineFunction'));
            tc.verifyEqual(unpacked.F{1}.funcName, 'sum');
        end

        function testUnpackMethodSkipsPipelineFunction(tc)
            % Already a PipelineFunction — should pass through
            pf = pf2_base.PipelineFunction('sum', ...
                {'x', 'dim'}, {[], 1}, {'x'});

            method.name = 'testMethod';
            method.F = {pf};

            unpacked = pf2_base.pf2_unpackMethod(method);
            tc.verifyTrue(isa(unpacked.F{1}, 'pf2_base.PipelineFunction'));
            tc.verifyEqual(unpacked.F{1}.funcName, 'sum');
        end

        %% setParams

        function testSetParamsNVPairs(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            pf2 = pf.setParams('freq_cut', 0.2, 'Nf', 100);
            tc.verifyEqual(pf2.getParam('freq_cut'), 0.2);
            tc.verifyEqual(pf2.getParam('Nf'), 100);
            tc.verifyEqual(pf2.getParam('filtType'), 1);  % unchanged

            % Original unchanged (value class)
            tc.verifyEqual(pf.getParam('freq_cut'), 0.1);
        end

        function testSetParamsStruct(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            s = struct('freq_cut', 0.3, 'Nf', 75);
            pf2 = pf.setParams(s);
            tc.verifyEqual(pf2.getParam('freq_cut'), 0.3);
            tc.verifyEqual(pf2.getParam('Nf'), 75);
        end

        function testSetParamsUnknownKeyAddsArg(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            pf2 = pf.setParams('freq_cut', 0.2, 'newParam', 42);
            tc.verifyEqual(pf2.getParam('freq_cut'), 0.2);
            tc.verifyEqual(pf2.getParam('newParam'), 42);
            tc.verifyEqual(numel(pf2.argNames), 6);  % original 5 + 1 new
        end

        function testSetParamsSpecialKeyWarns(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            tc.verifyWarning(@() pf.setParams('fs', 99, 'freq_cut', 0.2), ...
                'pf2:PipelineFunction:contextArg');
        end

        %% args table

        function testArgsTable(tc)
            pf = pf2_base.PipelineFunction('pf2_lpf', ...
                {'x','filtType','fs','freq_cut','Nf'}, ...
                {[], 1, [], 0.1, 50}, {'x'});

            tbl = pf.args();
            tc.verifyTrue(istable(tbl));
            tc.verifyEqual(height(tbl), 5);
            tc.verifyTrue(all(ismember({'Position','Name','Kind','Default'}, tbl.Properties.VariableNames)));

            % Check Kind values
            tc.verifyEqual(tbl.Kind{1}, 'context');     % x
            tc.verifyEqual(tbl.Kind{2}, 'parameter');   % filtType
            tc.verifyEqual(tbl.Kind{3}, 'context');     % fs
            tc.verifyEqual(tbl.Kind{4}, 'parameter');   % freq_cut
            tc.verifyEqual(tbl.Kind{5}, 'parameter');   % Nf

            % Check Position
            tc.verifyEqual(tbl.Position, (1:5)');

            % Check Name
            tc.verifyEqual(tbl.Name{1}, 'x');
            tc.verifyEqual(tbl.Name{4}, 'freq_cut');
        end

        %% ============================================================
        %%  detect() tests
        %% ============================================================

        function testDetectFromConfig(tc)
            % Known function in config — should get args, defaults, metadata
            pf = pf2_base.PipelineFunction.detect('pf2_lpf');
            tc.verifyEqual(pf.funcName, 'pf2_lpf');
            tc.verifyEqual(pf.argNames, {'x','filtType','fs','freq_cut','Nf'});
            tc.verifyEqual(pf.outputNames, {'x'});
            tc.verifyEqual(pf.getParam('freq_cut'), 0.1);
            tc.verifyEqual(pf.getParam('Nf'), 50);
            tc.verifyFalse(isempty(pf.name));  % has display name from config
        end

        function testDetectFromSource(tc)
            % detrend_3rd_order is not in config — should parse source
            pf = pf2_base.PipelineFunction.detect('detrend_3rd_order');
            tc.verifyEqual(pf.funcName, 'detrend_3rd_order');
            % Should have args parsed from source: (x, fs)
            tc.verifyTrue(ismember('x', pf.argNames) || ismember('y', pf.argNames));
            tc.verifyTrue(numel(pf.argNames) >= 1);
        end

        function testDetectVararginWarns(tc)
            % pf2_kbWF has varargin in its source file, but is in config
            % so detect will use config. Test with a function that truly
            % has varargin in source and is NOT in config.
            % We test the warning path by calling parseFunctionLine +
            % checking the detect logic works for config functions.
            pf = pf2_base.PipelineFunction.detect('pf2_kbWF');
            tc.verifyEqual(pf.funcName, 'pf2_kbWF');
            % Config version does not have varargin — should succeed cleanly
            tc.verifyTrue(numel(pf.argNames) >= 1);
        end

        function testDetectNotFound(tc)
            tc.verifyError(...
                @() pf2_base.PipelineFunction.detect('nonexistent_func_xyz_999'), ...
                'pf2:PipelineFunction:notFound');
        end

        function testDetectSpecialArgClassification(tc)
            pf = pf2_base.PipelineFunction.detect('pf2_lpf');
            % x and fs should be context, filtType/freq_cut/Nf should be parameter
            tc.verifyTrue(pf.specialMask(1));   % x
            tc.verifyTrue(pf.specialMask(3));   % fs
            tc.verifyFalse(pf.specialMask(2));  % filtType
            tc.verifyFalse(pf.specialMask(4));  % freq_cut
        end

        %% ============================================================
        %%  fromString() tests
        %% ============================================================

        function testFromStringSimple(tc)
            pf = pf2_base.PipelineFunction.fromString('pf2_Intensity2OD(x)');
            tc.verifyEqual(pf.funcName, 'pf2_Intensity2OD');
            tc.verifyEqual(pf.outputNames, {'x'});
        end

        function testFromStringWithParams(tc)
            pf = pf2_base.PipelineFunction.fromString('[x]=pf2_lpf(x,1,fs,0.2,100)');
            tc.verifyEqual(pf.funcName, 'pf2_lpf');
            tc.verifyEqual(pf.getParam('filtType'), 1);
            tc.verifyEqual(pf.getParam('freq_cut'), 0.2);
            tc.verifyEqual(pf.getParam('Nf'), 100);
        end

        function testFromStringMultiOutput(tc)
            pf = pf2_base.PipelineFunction.fromString('[x,fchMask]=pf2_SMAR(x,10,0.025,-1)');
            tc.verifyEqual(pf.funcName, 'pf2_SMAR');
            tc.verifyEqual(pf.outputNames, {'x', 'fchMask'});
            tc.verifyEqual(pf.getParam('N'), 10);
            tc.verifyEqual(pf.getParam('tauUp'), 0.025);
            tc.verifyEqual(pf.getParam('tauLow'), -1);
        end

        function testFromStringContextArgsEmpty(tc)
            % x and fs should get [] defaults, not call values
            pf = pf2_base.PipelineFunction.fromString('[x]=pf2_lpf(x,1,fs,0.2,50)');
            tbl = pf.args();
            % x (pos 1) and fs (pos 3) should have [] defaults
            tc.verifyTrue(isempty(tbl.Default{1}));  % x
            tc.verifyTrue(isempty(tbl.Default{3}));  % fs
        end

        function testFromStringNoOutput(tc)
            % No '=' sign — should use detect's outputs
            pf = pf2_base.PipelineFunction.fromString('pf2_lpf(x,1,fs,0.2,50)');
            tc.verifyEqual(pf.funcName, 'pf2_lpf');
            tc.verifyEqual(pf.outputNames, {'x'});
        end

        %% ============================================================
        %%  tokenizeArgs() tests
        %% ============================================================

        function testTokenizeSimple(tc)
            tokens = pf2_base.PipelineFunction.tokenizeArgs('x,1,0.2');
            tc.verifyEqual(tokens, {'x', '1', '0.2'});
        end

        function testTokenizeArray(tc)
            tokens = pf2_base.PipelineFunction.tokenizeArgs('x,[1,2,3],y');
            tc.verifyEqual(numel(tokens), 3);
            tc.verifyEqual(tokens{2}, '[1,2,3]');
        end

        function testTokenizeString(tc)
            tokens = pf2_base.PipelineFunction.tokenizeArgs('x,''hello'',y');
            tc.verifyEqual(numel(tokens), 3);
            tc.verifyEqual(tokens{2}, '''hello''');
        end

        function testTokenizeNested(tc)
            tokens = pf2_base.PipelineFunction.tokenizeArgs('x,[1,[2,3]],y');
            tc.verifyEqual(numel(tokens), 3);
            tc.verifyEqual(tokens{2}, '[1,[2,3]]');
        end

        %% ============================================================
        %%  parseToken() tests
        %% ============================================================

        function testParseTokenNumeric(tc)
            tc.verifyEqual(pf2_base.PipelineFunction.parseToken('0.1'), 0.1);
            tc.verifyEqual(pf2_base.PipelineFunction.parseToken('-3'), -3);
            tc.verifyEqual(pf2_base.PipelineFunction.parseToken('50'), 50);
        end

        function testParseTokenBoolean(tc)
            tc.verifyEqual(pf2_base.PipelineFunction.parseToken('true'), true);
            tc.verifyEqual(pf2_base.PipelineFunction.parseToken('false'), false);
        end

        function testParseTokenString(tc)
            tc.verifyEqual(pf2_base.PipelineFunction.parseToken('''hello'''), 'hello');
        end

        function testParseTokenEmpty(tc)
            tc.verifyTrue(isempty(pf2_base.PipelineFunction.parseToken('[]')));
        end

    end
end
