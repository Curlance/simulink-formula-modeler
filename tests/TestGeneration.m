function tests=TestGeneration
tests=functiontests(localfunctions);
end
function testNativeGeneration(t)
[s,folder]=fixture('native'); path=fm.simulink.generateModel(s,folder);
verifyTrue(t,isfile(path)); verifyTrue(t,isfile(fullfile(folder,[s.name '.json'])));
verifyTrue(t,isfile(fullfile(folder,['build_' s.name '.m'])));
load_system(path); c=onCleanup(@()close_system(s.name,0));
set_param(s.name,'SimulationCommand','update');
blocks=find_system(s.name,'SearchDepth',1,'Type','Block');
types=cellfun(@(b)get_param(b,'BlockType'),blocks,'UniformOutput',false);
verifyTrue(t,all(ismember(types,{'Inport','Outport','Integrator','Gain','Sum','Product','Constant','Math','Trigonometry'})));
verifyEqual(t,getVariable(get_param(s.name,'ModelWorkspace'),'a'),2);
verifyEqual(t,get_param([s.name '/state_x'],'InitialCondition'),'3');
r=fm.simulink.extractEquations(s.name); bindings=struct('x',2,'u',4,'a',2);
verifyEqual(t,fm.core.evaluateAst(r.derivatives{1},bindings),-4+sin(4)+cos(2)+exp(-2)+2^2/2,'AbsTol',1e-12);
end
function testArtifactCollision(t)
[s,folder]=fixture('collision'); fm.simulink.generateModel(s,folder);
verifyError(t,@()fm.simulink.generateModel(s,folder),'fm:ArtifactCollision');
end
function testLoadedCollision(t)
[s,folder]=fixture('loaded'); new_system(s.name); c=onCleanup(@()close_system(s.name,0));
verifyError(t,@()fm.simulink.generateModel(s,folder),'fm:ModelCollision');
verifyTrue(t,bdIsLoaded(s.name));
end
function testStateOrderAndNoInputs(t)
[s,folder]=fixture('order'); s=rmfield(s,intersect(fieldnames(s),{'schemaVersion','stateNames','inputNames','outputNames','derivatives','outputExpressions'}));
s.states={'z','aState'}; s.inputs={}; s.initial=struct('z',1,'aState',2); s.equations={'der(z) = aState','der(aState) = -z'}; s.outputs=struct('y','z');
s=fm.core.validateSpec(s); p=fm.simulink.generateModel(s,folder); r=fm.simulink.extractEquations(p);
verifyEqual(t,r.stateNames,{'z','aState'}); verifyEmpty(t,r.inputNames);
end
function testBuildScript(t)
[s,folder]=fixture('rebuild'); p=fm.simulink.generateModel(s,folder);
run(fullfile(folder,['build_' s.name '.m']));
rebuilt=fullfile(folder,'rebuilt',[s.name '.slx']);
verifyTrue(t,isfile(rebuilt));
a=fm.simulink.extractEquations(p); b=fm.simulink.extractEquations(rebuilt);
verifyEqual(t,b.equations,a.equations); verifyEqual(t,b.initial,a.initial);
load_system(rebuilt); c=onCleanup(@()close_system(s.name,0));
set_param(s.name,'SimulationCommand','update');
end
function [s,folder]=fixture(tag)
root=fileparts(fileparts(mfilename('fullpath'))); parent=fullfile(root,'artifacts','model'); if ~exist(parent,'dir'),mkdir(parent);end
folder=tempname(parent); [~,id]=fileparts(folder); name=matlab.lang.makeValidName(['fm_' tag '_' id]);
r=struct('name',name,'states',{{'x'}},'inputs',{{'u'}},'parameters',struct('a',2),'initial',struct('x',3),'equations',{{'der(x) = -a*x + sin(u) + cos(x) + exp(-x) + x^2/a'}},'outputs',struct('y','x+u'));
s=fm.core.validateSpec(r);
end
