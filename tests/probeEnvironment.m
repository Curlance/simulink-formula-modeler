function result = probeEnvironment()
% Exercise required capabilities without modifying user models.
root = fileparts(fileparts(mfilename('fullpath')));
folder = fullfile(root, 'artifacts', 'environment');
if ~isfolder(folder), mkdir(folder); end
[~, token] = fileparts(tempname(folder));
model = ['fm_probe_' token];
new_system(model);
cleanup = onCleanup(@() close_system(model, 0));
add_block('simulink/Sources/Constant', [model '/Input'], 'Value', '1');
add_block('simulink/Sinks/Terminator', [model '/Sink']);
add_line(model, 'Input/1', 'Sink/1');
set_param(model, 'SimulationCommand', 'update');
fprintf('SIMULINK_CREATE_UPDATE_OK\n');
g = tf(ss(-1, 1, 1, 0));
[num, den] = tfdata(g, 'v');
% Leading zero coefficients do not change the polynomial.
firstNonzero = find(num ~= 0, 1, 'first');
assert(~isempty(firstNonzero), 'fm:ProbeControl', 'Unexpected zero numerator.');
trimmed = num(firstNonzero:end);
assert(isscalar(trimmed) && abs(trimmed - 1) < 1e-12, ...
    'fm:ProbeControl', 'Unexpected numerator coefficients.');
assert(isequal(size(den), [1 2]) && norm(den - [1 1]) < 1e-12, ...
    'fm:ProbeControl', 'Unexpected denominator coefficients.');
assert(abs(evalfr(g, 2) - 1/3) < 1e-12, ...
    'fm:ProbeControl', 'Transfer response does not match independent expectation.');
fprintf('CONTROL_COMPUTATION_OK\n');
z = sym('z');
assert(isequal(simplify((z+1)^2-z^2-2*z), sym(1)), ...
    'fm:ProbeSymbolic', 'Symbolic identity check failed.');
fprintf('SYMBOLIC_COMPUTATION_OK\n');
result = struct('matlabVersion', version, 'simulinkPassed', true, ...
    'controlPassed', true, 'symbolicPassed', true, ...
    'numerator', num, 'denominator', den);
fid = fopen(fullfile(folder, 'runtime-check.json'), 'w', 'n', 'UTF-8');
assert(fid >= 0, 'fm:ProbeReport', 'Cannot write environment report.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(result));
clear fileCleanup cleanup;
disp(result);
end
