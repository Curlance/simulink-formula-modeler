function manifest = buildDemoV2()
%BUILDDEMOV2 Parent-owned acceptance via real UI actions and an independent model.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); addpath(fullfile(root,'tests'));
parent=fullfile(root,'artifacts','v2','demo'); if ~isfolder(parent), mkdir(parent); end
folder=tempname(parent); mkdir(folder);
app=launch('off'); cleanup=onCleanup(@()delete(app));

% Actual unresolved symbolic parameter input and independent known transfer.
app.loadExample('symbolic_mass_spring');
spec=app.perform('check'); assert(strcmp(spec.parameters.m,'symbolic'));
formulaPaths=app.perform('export'); symbolic=app.perform('analyze');
m=sym('m','real'); c=sym('c','real'); k=sym('k','real'); s=symbolic.laplaceVariable;
expected=1/(m*s^2+c*s+k);
assert(isAlways(simplify(symbolic.transferMatrix(1,1)-expected)==0,'Unknown','false'), ...
    'fm:V2Demo','Symbolic transfer differs from independent mass-spring expression.');
app.perform('saveAnalysis'); drawnow;
exportapp(app.Figure,fullfile(folder,'symbolic-interface.png'));

% Build a native nested nonlinear system independently of the formula generator.
modelPath=createComplexDemo(fullfile(folder,'nested_model'));
app.setModelPath(modelPath); extracted=app.perform('extract');
assert(numel(extracted.stateNames)==1 && numel(extracted.inputNames)==1 && numel(extracted.outputNames)==1);
pointX=struct(); pointX.(extracted.stateNames{1})=1;
pointU=struct(); pointU.(extracted.inputNames{1})=1;
app.OperatingStatesArea.Value={jsonencode(pointX)};
app.OperatingInputsArea.Value={jsonencode(pointU)};
app.AnalysisMode.Value='linearize'; app.EquilibriumCheckbox.Value=true; app.updateMode();
linear=app.perform('analyze');
assert(linear.isEquilibrium && norm(linear.A+3)<1e-12 && norm(linear.B-1)<1e-12 ...
    && norm(linear.C-2)<1e-12 && norm(linear.D)<1e-12,'fm:V2Demo','Unexpected local Jacobian.');
assert(abs(evalfr(linear.transferSystem,2)-2/5)<1e-12,'fm:V2Demo','Unexpected local transfer.');
app.perform('saveAnalysis'); drawnow;
exportapp(app.Figure,fullfile(folder,'complex-linearization-interface.png'));

% Compare actual model output with a separately hand-written nonlinear ODE.
result=fm.validation.compareSimulation(extracted,modelPath, ...
    struct('stopTime',2,'inputValues',1.1,'tolerance',1e-6));
assert(result.passed,'fm:V2Demo','Extracted equations disagree with nested model.');
ref=ode45(@(~,x)-x.^3+1.1,[0 2],1,odeset('RelTol',1e-11,'AbsTol',1e-13));
channel=result.channels(1); xRef=deval(ref,channel.time);
independentError=max(abs(channel.model(:)-xRef(:).^2));
assert(independentError<1e-6,'fm:V2Demo','Native nested model disagrees with independent ODE.');
save(fullfile(folder,'verification.mat'),'symbolic','linear','result','independentError');

load_system(modelPath); [~,model]=fileparts(modelPath);
modelCleanup=onCleanup(@()close_system(model,0));
print(['-s' model],'-dpng',fullfile(folder,'nested-model.png'));
print(['-s' model '/Plant/Dynamics'],'-dpng',fullfile(folder,'nested-dynamics.png'));
manifest=struct('passed',true,'matlabVersion',version,'artifactDirectory',folder, ...
    'complexModel',modelPath,'symbolicFormulaLatex',formulaPaths.latex, ...
    'independentODEError',independentError,'tolerance',1e-6);
fid=fopen(fullfile(parent,'latest-manifest.json'),'w','n','UTF-8');
assert(fid>=0,'fm:V2Demo','Cannot write manifest.'); cFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(manifest)); clear cFile;
disp(manifest); fprintf('V2_UI_COMPLEX_SYMBOLIC_LINEARIZATION_OK\n');
end
