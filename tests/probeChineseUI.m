function probeChineseUI()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
folder=fullfile(root,'artifacts','v2','ui'); if ~isfolder(folder), mkdir(folder); end
app=launch('off'); cleanup=onCleanup(@()delete(app));
app.loadExample('mass_spring_damper'); app.perform('check'); app.perform('analyze');
text=strjoin(cellstr(string(app.ResultArea.Value)),newline);
assert(contains(text,'状态空间'),'fm:UIProbe','Chinese analysis text missing.');
folderExport=tempname(folder); spec=app.perform('check');
paths=fm.ui.exportFormulas(spec,folderExport);
assert(contains(fileread(paths.text),'状态方程'),'fm:UIProbe','Chinese formula export missing.');
fid=fopen(fullfile(folder,'latex-path.txt'),'w','n','UTF-8'); fprintf(fid,'%s',paths.latex); fclose(fid);
app.perform('analyze'); drawnow; exportapp(app.Figure,fullfile(folder,'chinese-numeric.png'));
app.loadExample('nonlinear_equilibrium');
assert(strcmp(app.AnalysisMode.Value,'linearize'));
assert(strcmp(app.OperatingInputsArea.Value{1},'{"u":1}'));
drawnow; exportapp(app.Figure,fullfile(folder,'chinese-operating-point.png'));
suite=matlab.unittest.TestSuite.fromFile(fullfile(root,'tests','TestUI.m'));
r=run(suite); assert(all([r.Passed]) && ~any([r.Incomplete]),'fm:UIProbe','Chinese UI regression failed.');
fprintf('CHINESE_UI_TESTS=%d PASSED=%d\n',numel(r),sum([r.Passed]));
fprintf('CHINESE_UI_EXPORT_OK\n');
end
