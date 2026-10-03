function buildDemo()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root); addpath(fullfile(root,'app'));
app=launch('off'); cleanup=onCleanup(@()delete(app));
app.loadExample('mass_spring_damper');
app.perform('check');
app.perform('export');
modelPath=app.perform('generate');
app.perform('extract');
result=app.perform('analyze');
app.perform('saveAnalysis');
simulation=app.perform('simulate');
assert(simulation.passed,'fm:Demo','Simulation reference comparison failed.');
assert(abs(evalfr(result.system(1,1),2)-1/13)<1e-9,'fm:Demo','Unexpected transfer response.');
folder=fullfile(root,'artifacts','demo');
if ~isfolder(folder), mkdir(folder); end
load_system(modelPath);
[~,model]=fileparts(modelPath);
modelCleanup=onCleanup(@()close_system(model,0));
print(['-s' model],'-dpng',fullfile(folder,'generated-model.png'));
drawnow;
exportapp(app.Figure,fullfile(folder,'working-interface.png'));
fid=fopen(fullfile(folder,'model-path.txt'),'w','n','UTF-8');
assert(fid>=0); fprintf(fid,'%s\n',modelPath); fclose(fid);
fid=fopen(fullfile(folder,'analysis.txt'),'w','n','UTF-8');
assert(fid>=0); fprintf(fid,'%s\n',result.text); fclose(fid);
fprintf('DEMO_MODEL=%s\n',modelPath);
fprintf('UI_END_TO_END_DEMO_OK\n');
end
