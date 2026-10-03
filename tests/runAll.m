% Run from MATLAB or: matlab -batch "run('tests/runAll.m')"
% Artifacts contain actual results; failures and incomplete tests fail the run.
fmTestRoot = fileparts(mfilename('fullpath'));
fmProjectRoot = fileparts(fmTestRoot);
addpath(fmProjectRoot);
if isfolder(fullfile(fmProjectRoot, 'app'))
    addpath(fullfile(fmProjectRoot, 'app'));
end
fmStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
fmReportDir = fullfile(fmProjectRoot, 'artifacts', 'tests', fmStamp);
if isfolder(fmReportDir)
    error('fm:ReportCollision', 'Test report directory already exists.');
end
mkdir(fmReportDir);
fprintf('MATLAB_VERSION=%s\n', version);
fprintf('TEST_REPORT_DIRECTORY=%s\n', fmReportDir);
fmSuite = matlab.unittest.TestSuite.fromFolder(fmTestRoot, 'IncludingSubfolders', true);
if isempty(fmSuite)
    error('fm:NoTests', 'No tests discovered. A test-free run is not successful.');
end
fmResults = run(fmSuite);
fmResultsTable = table(fmResults);
writetable(fmResultsTable, fullfile(fmReportDir, 'results.csv'));
save(fullfile(fmReportDir, 'results.mat'), 'fmResults');
fmSummary = struct('matlabVersion', version, 'total', numel(fmResults), ...
    'passed', sum([fmResults.Passed]), 'failed', sum([fmResults.Failed]), ...
    'incomplete', sum([fmResults.Incomplete]));
fmSummaryFile = fopen(fullfile(fmReportDir, 'summary.json'), 'w', 'n', 'UTF-8');
if fmSummaryFile < 0
    error('fm:ReportWrite', 'Cannot create test summary file.');
end
try
    fprintf(fmSummaryFile, '%s\n', jsonencode(fmSummary));
catch fmReportError
    fclose(fmSummaryFile);
    rethrow(fmReportError);
end
fclose(fmSummaryFile);
disp(fmResultsTable);
fprintf('TEST_TOTAL=%d PASSED=%d FAILED=%d INCOMPLETE=%d\n', ...
    fmSummary.total, fmSummary.passed, fmSummary.failed, fmSummary.incomplete);
assert(all([fmResults.Passed]) && ~any([fmResults.Incomplete]), ...
    'fm:TestFailure', 'Tests failed or were incomplete. Inspect the saved reports.');
