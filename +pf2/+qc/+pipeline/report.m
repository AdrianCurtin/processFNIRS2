function report(qcReport)
% REPORT Print a readable channel-by-channel QC summary
%
% Displays the QC pipeline results in a formatted table to the command
% window. Shows per-check pass/fail status for every channel with
% diagnostic values and rejection reasons.
%
% Syntax:
%   pf2.qc.pipeline.report(qcReport)
%
% Inputs:
%   qcReport - QC report struct from pf2.qc.pipeline.assess
%
% Example:
%   rpt = pf2.qc.pipeline.assess(data);
%   pf2.qc.pipeline.report(rpt);
%
% See also: pf2.qc.pipeline.assess, pf2.qc.pipeline.plotReport

%% Validate
assert(isstruct(qcReport) && isfield(qcReport, 'pass'), ...
    'pf2:qc:pipeline:badReport', ...
    'Input must be a QC report from pf2.qc.pipeline.assess.');

nChannels = numel(qcReport.channels);
nPassed = sum(qcReport.pass);
nRejected = nChannels - nPassed;
passRate = round(100 * nPassed / nChannels);

%% Build column headers
checks = qcReport.checkNames;
nChecks = numel(checks);

%% Header
fprintf('\n=== fNIRS Quality Control Report ===\n');
fprintf('Timestamp: %s\n', char(qcReport.timestamp));
fprintf('Sampling rate: %.1f Hz\n', qcReport.fs);
fprintf('Channels: %d assessed, %d passed (%d%%), %d rejected\n', ...
    nChannels, nPassed, passRate, nRejected);

% Report skipped checks
for ci = 1:nChecks
    checkName = checks{ci};
    if isfield(qcReport, checkName) && isfield(qcReport.(checkName), 'skipped') ...
            && qcReport.(checkName).skipped
        reason = '';
        if isfield(qcReport.(checkName), 'skipReason')
            reason = [' — ' qcReport.(checkName).skipReason];
        end
        fprintf('  Note: %s check SKIPPED (not applicable at this fs)%s\n', ...
            capitalize(checkName), reason);
    end
end
fprintf('\n');

% Column header line
fprintf('%-8s', 'Channel');
for ci = 1:nChecks
    fprintf('  %-12s', capitalize(checks{ci}));
end
fprintf('  %-8s\n', 'Overall');

% Separator
sepLen = 8 + nChecks * 14 + 10;
fprintf('%s\n', repmat('-', 1, sepLen));

%% Print each channel
for ch = 1:nChannels
    fprintf('  %-6d', ch);

    for ci = 1:nChecks
        checkName = checks{ci};
        switch checkName
            case 'sci'
                if isfield(qcReport, 'sci')
                    if isfield(qcReport.sci, 'skipped') && qcReport.sci.skipped
                        fprintf('  %-12s', 'skip');
                    else
                        val = qcReport.sci.values(ch);
                        if qcReport.sci.pass(ch)
                            fprintf('  %.2f        ', val);
                        else
                            fprintf('  %.2f *      ', val);
                        end
                    end
                else
                    fprintf('  %-12s', '-');
                end

            case 'cardiac'
                if isfield(qcReport, 'cardiac')
                    if isfield(qcReport.cardiac, 'skipped') && qcReport.cardiac.skipped
                        fprintf('  %-12s', 'skip');
                    elseif qcReport.cardiac.detected(ch)
                        snr = qcReport.cardiac.snr(ch);
                        if qcReport.cardiac.pass(ch)
                            fprintf('  Y %.1f       ', snr);
                        else
                            fprintf('  Y %.1f *     ', snr);
                        end
                    else
                        fprintf('  N            ');
                    end
                else
                    fprintf('  %-12s', '-');
                end

            case 'cov'
                if isfield(qcReport, 'cov')
                    val = qcReport.cov.values(ch);
                    if qcReport.cov.pass(ch)
                        fprintf('  %.3f        ', val);
                    else
                        fprintf('  %.3f *      ', val);
                    end
                else
                    fprintf('  %-12s', '-');
                end

            case 'takizawa'
                if isfield(qcReport, 'takizawa')
                    if qcReport.takizawa.pass(ch)
                        fprintf('  PASS        ');
                    else
                        % Show which rules failed
                        failedRules = find(~qcReport.takizawa.rules(:, ch));
                        ruleStr = strjoin(arrayfun(@num2str, failedRules, ...
                            'UniformOutput', false), ',');
                        fprintf('  R%-11s', ruleStr);
                    end
                else
                    fprintf('  %-12s', '-');
                end
        end
    end

    % Overall
    if qcReport.pass(ch)
        fprintf('  PASS\n');
    else
        fprintf('  FAIL\n');
    end
end

%% Rejection summary
if nRejected > 0
    fprintf('\nRejection reasons:\n');
    for ch = 1:nChannels
        if qcReport.pass(ch)
            continue;
        end
        reasons = {};

        if isfield(qcReport, 'saturation') && ~qcReport.saturation.pass(ch)
            reasons{end+1} = sprintf('Saturation=%.1f%% (>%.1f%%)', ...
                100*qcReport.saturation.totalPct(ch), ...
                100*qcReport.saturation.threshold); %#ok<AGROW>
        end
        if isfield(qcReport, 'sci') && ~qcReport.sci.pass(ch)
            reasons{end+1} = sprintf('SCI=%.2f (<%.2f)', ...
                qcReport.sci.values(ch), qcReport.sci.threshold); %#ok<AGROW>
        end
        if isfield(qcReport, 'cardiac') && ~qcReport.cardiac.pass(ch)
            if qcReport.cardiac.detected(ch)
                reasons{end+1} = sprintf('Cardiac SNR=%.1f (<%.1f)', ...
                    qcReport.cardiac.snr(ch), qcReport.cardiac.threshold); %#ok<AGROW>
            else
                reasons{end+1} = 'No cardiac peak detected'; %#ok<AGROW>
            end
        end
        if isfield(qcReport, 'cov') && ~qcReport.cov.pass(ch)
            reasons{end+1} = sprintf('CoV=%.3f (>%.3f)', ...
                qcReport.cov.values(ch), qcReport.cov.threshold); %#ok<AGROW>
        end
        if isfield(qcReport, 'takizawa') && ~qcReport.takizawa.pass(ch)
            failedRules = find(~qcReport.takizawa.rules(:, ch));
            ruleNames = qcReport.takizawa.ruleNames(failedRules);
            reasons{end+1} = sprintf('Takizawa: %s', strjoin(ruleNames, ', ')); %#ok<AGROW>
        end

        if isempty(reasons)
            reasons = {'failed an enabled check (no specific metric recorded)'};
        end
        fprintf('  Ch %d: %s\n', ch, strjoin(reasons, '; '));
    end
end

fprintf('\n');

end


%% Local functions

function s = capitalize(str)
% CAPITALIZE Capitalize first letter of a string
    if isempty(str)
        s = str;
        return;
    end
    s = [upper(str(1)), str(2:end)];
end
