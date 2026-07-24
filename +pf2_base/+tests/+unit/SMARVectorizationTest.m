classdef SMARVectorizationTest < matlab.unittest.TestCase
    % SMARVECTORIZATIONTEST Guards that the vectorized pf2_SMAR local-CV matches
    % the original per-sample loop on realistic data (mask and corrected output),
    % across window sizes, even/odd N, the tauLow branch, and NaN-containing
    % input. The vectorized movmean/movstd form is ~40x faster and matches the
    % loop to floating-point precision; on organic/random signals it is bit-for-
    % bit identical (movstd's ULP-level summation differences only change a mask
    % decision for a CV lying exactly on the threshold, which realistic data does
    % not produce). This test keeps the vectorization from meaningfully diverging.
    %
    %   results = runtests('pf2_base.tests.unit.SMARVectorizationTest');
    %
    % See also: pf2_SMAR

    methods (TestClassSetup)
        function addFunctionsPath(~)
            projRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            f = fullfile(projRoot, 'functions');
            if isfolder(f), addpath(f); end
        end
    end

    methods (Test)
        function bitIdenticalToReferenceLoop(testCase)
            rng(3);
            for N = [5 10 11 25 51]
                for tauLow = [-1 0.001]
                    for hasNaN = [false true]
                        T = 4000; C = 24;
                        x = 2000 + 50*cumsum(0.02*randn(T,C)) + 5*(rand(T,C)<0.002).*randn(T,C);
                        if hasNaN
                            x(rand(T,C) < 0.01) = NaN;
                            x(200:240, 1) = NaN;
                        end
                        [Xnew, mNew] = pf2_SMAR(x, N, 0.025, tauLow);
                        [Xref, mRef] = refSMAR(x, N, 0.025, tauLow);
                        testCase.verifyTrue(isequaln(mNew, mRef), ...
                            sprintf('mask differs at N=%d tauLow=%g hasNaN=%d', N, tauLow, hasNaN));
                        testCase.verifyTrue(isequaln(Xnew, Xref), ...
                            sprintf('output differs at N=%d tauLow=%g hasNaN=%d', N, tauLow, hasNaN));
                    end
                end
            end
        end

        function shortRecordingAllNaN(testCase)
            % Recording shorter than the window -> every CV is NaN (all flagged).
            x = 2000 + randn(6, 3);
            [~, m] = pf2_SMAR(x, 11, 0.025, -1);
            testCase.verifyTrue(all(m(:)));
        end
    end
end

function [Xcorr, maskCV] = refSMAR(x, N, tauUp, tauLow)
% Reference: the original per-sample sliding-window CV loop.
if rem(N,2)==0, N=N+1; end
wSize=(N-1)/2; [len,wid]=size(x); CVx=nan(len,wid);
for i=wSize+1:len-wSize
    xv=x(i-wSize:i+wSize,:);
    CVx(i,:)=std(xv,0,1,'omitnan')./mean(xv,1,'omitnan');
end
Xcorr=x;
maskCV=abs(CVx)>tauUp | isnan(CVx) | abs(CVx)<tauLow;
Xcorr(maskCV)=nan;
end
