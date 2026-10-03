function result = probeSimulationInput()
% Verify installed simulation APIs against an independent analytic response.
root=fileparts(fileparts(mfilename('fullpath')));
folder=fullfile(root,'artifacts','simulation');
if ~isfolder(folder), mkdir(folder); end
[~,token]=fileparts(tempname(folder));
model=['fm_api_' token];
new_system(model);
cleanup=onCleanup(@()close_system(model,0));
add_block('simulink/Sources/In1',[model '/u']);
add_block('simulink/Math Operations/Sum',[model '/sum'],'Inputs','+-');
add_block('simulink/Continuous/Integrator',[model '/x'],'InitialCondition','0');
add_block('simulink/Sinks/Out1',[model '/y']);
add_line(model,'u/1','sum/1');
add_line(model,'x/1','sum/2');
add_line(model,'sum/1','x/1');
add_line(model,'x/1','y/1');
t=(0:0.01:2)';
ds=Simulink.SimulationData.Dataset;
ds=ds.addElement(timeseries(ones(size(t)),t),'u');
in=Simulink.SimulationInput(model);
in=in.setExternalInput(ds);
in=in.setModelParameter('StopTime','2','Solver','ode45', ...
    'RelTol','1e-9','AbsTol','1e-11','MaxStep','0.01', ...
    'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset');
out=sim(in);
y=out.get('yout');
assert(isa(y,'Simulink.SimulationData.Dataset'),'fm:ProbeOutput','Expected Dataset output.');
assert(y.numElements==1,'fm:ProbeOutput','Expected one output.');
entry=y.getElement(1);
ts=entry.Values;
expected=1-exp(-ts.Time);
maxError=max(abs(double(ts.Data(:))-expected(:)));
assert(maxError<1e-7,'fm:ProbeSimulation','Analytic response comparison failed.');
result=struct('passed',true,'maxAbsoluteError',maxError,'tolerance',1e-7, ...
    'sampleCount',numel(ts.Time),'matlabVersion',version);
fid=fopen(fullfile(folder,'api-probe.json'),'w','n','UTF-8');
assert(fid>=0,'fm:ProbeWrite','Cannot save simulation probe report.');
fileCleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(result));
clear fileCleanup;
disp(result);
fprintf('EXTERNAL_INPUT_ANALYTIC_CHECK_OK\n');
end
