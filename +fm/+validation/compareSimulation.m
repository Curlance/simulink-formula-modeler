function result = compareSimulation(spec,modelPath,options)
%COMPARESIMULATION Simulate an actual model with constant scalar inputs.
% The independently integrated reference evaluates the supplied validated AST.
% This is a runtime consistency check; independent analytic fixtures live in tests.
if nargin<3, options=struct(); end
spec=fm.core.validateSpec(spec);
if ~isstruct(options)||~isscalar(options), error('fm:SimulationOptions','Options must be a scalar struct.'); end
if ~isfield(options,'stopTime'), options.stopTime=5; end
if ~isfield(options,'inputValues'), options.inputValues=ones(1,numel(spec.inputNames)); end
if ~isfield(options,'tolerance'), options.tolerance=1e-5; end
for key={'stopTime','tolerance'}
    v=options.(key{1});
    if ~(isnumeric(v)&&isscalar(v)&&isreal(v)&&isfinite(v)&&v>0)
        error('fm:SimulationOptions','%s must be a positive finite real scalar.',key{1});
    end
end
u=options.inputValues;
if ~(isnumeric(u)&&isreal(u)&&all(isfinite(u(:)))&&numel(u)==numel(spec.inputNames))
    error('fm:SimulationOptions','Provide one finite real constant value per input port.');
end
modelPath=char(modelPath); [~,model]=fileparts(modelPath);
wasLoaded=bdIsLoaded(model);
if wasLoaded
    current=get_param(model,'FileName');
    if ~strcmp(modelPath,model)&&~strcmpi(strrep(current,'\','/'),strrep(modelPath,'\','/'))
        error('fm:ModelCollision','Another model with this name is already loaded.');
    end
else
    load_system(modelPath);
end
cleanup=onCleanup(@()closeOwned(model,wasLoaded));
% Reject mismatched states/ports before comparing arrays.
actual=fm.simulink.extractEquations(model);
if ~isequal(actual.stateNames,spec.stateNames)||~isequal(actual.inputNames,spec.inputNames)||~isequal(actual.outputNames,spec.outputNames)
    error('fm:SimulationMismatch','Reference state/input/output order differs from actual model. Extract again.');
end
t=linspace(0,options.stopTime,501)';
in=Simulink.SimulationInput(model);
if ~isempty(u)
    ds=Simulink.SimulationData.Dataset;
    for k=1:numel(u), ds=ds.addElement(timeseries(u(k)*ones(size(t)),t),spec.inputNames{k}); end
    in=in.setExternalInput(ds);
end
in=in.setModelParameter('StartTime','0','StopTime',num2str(options.stopTime,17), ...
    'Solver','ode45','SolverType','Variable-step','RelTol','1e-9','AbsTol','1e-11', ...
    'MaxStep',num2str(options.stopTime/500,17),'SaveOutput','on', ...
    'OutputSaveName','yout','SaveFormat','Dataset');
out=sim(in);
data=out.get('yout');
if ~isa(data,'Simulink.SimulationData.Dataset')||data.numElements~=numel(spec.outputNames)
    error('fm:SimulationOutput','Unexpected model output format or count.');
end
x0=zeros(numel(spec.stateNames),1);
for k=1:numel(x0), x0(k)=spec.initial.(spec.stateNames{k}); end
reference=ode45(@referenceRHS,[0 options.stopTime],x0,odeset('RelTol',1e-11,'AbsTol',1e-13));
channels=struct('name',{},'time',{},'model',{},'reference',{},'maxAbsoluteError',{});
for k=1:numel(spec.outputNames)
    signal=data.getElement(k).Values;
    time=signal.Time(:); values=double(signal.Data(:));
    states=deval(reference,time); expected=zeros(size(time));
    for j=1:numel(time)
        env=bindings(states(:,j));
        expected(j)=fm.core.evaluateAst(spec.outputExpressions{k},env);
    end
    if any(~isfinite(values))||numel(values)~=numel(expected)
        error('fm:SimulationOutput','Nonfinite or non-scalar output for %s.',spec.outputNames{k});
    end
    channels(k)=struct('name',spec.outputNames{k},'time',time,'model',values, ...
        'reference',expected,'maxAbsoluteError',max(abs(values-expected)));
end
result=struct('passed',all([channels.maxAbsoluteError]<=options.tolerance), ...
    'channels',channels,'options',options,'solver','ode45', ...
    'relativeTolerance',1e-9,'absoluteTolerance',1e-11, ...
    'conditions','Constant inputs from t=0; specified initial states; scalar continuous model.', ...
    'referenceMethod','ode45 integration of parsed equations; see separate independent-fixture tests.');
    function env=bindings(x)
        env=spec.parameters;
        for a=1:numel(x), env.(spec.stateNames{a})=x(a); end
        for a=1:numel(u), env.(spec.inputNames{a})=u(a); end
    end
    function dx=referenceRHS(~,x)
        env=bindings(x); dx=zeros(numel(x),1);
        for a=1:numel(x), dx(a)=fm.core.evaluateAst(spec.derivatives{a},env); end
    end
end
function closeOwned(model,wasLoaded)
if ~wasLoaded&&bdIsLoaded(model), close_system(model,0); end
end
