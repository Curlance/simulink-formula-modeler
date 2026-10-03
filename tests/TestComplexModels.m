function tests=TestComplexModels
% Real native fixtures + independent closed forms/ODEs + extracted rebuilds.
tests=functiontests(localfunctions);
end
function testNestedPortsEditsAndIndependentSimulation(t)
[m,c,folder]=fresh('hierarchy'); %#ok<ASGLU>
input(m,'u',1);sub([m '/Outer']);sub([m '/Outer/Inner']);
input([m '/Outer'],'first',1);input([m '/Outer'],'second',2);
input([m '/Outer/Inner'],'a',1);input([m '/Outer/Inner'],'b',2);
add('Continuous/Integrator',[m '/Outer/Inner/x'],'InitialCondition','0.4');
add('Math Operations/Sum',[m '/Outer/Inner/add'],'Inputs','++');
output([m '/Outer/Inner'],'position',1);output([m '/Outer/Inner'],'through',2);
wire([m '/Outer/Inner'],'a/1','add/1');wire([m '/Outer/Inner'],'b/1','add/2');
wire([m '/Outer/Inner'],'add/1','x/1');wire([m '/Outer/Inner'],'x/1','position/1');wire([m '/Outer/Inner'],'b/1','through/1');
wire([m '/Outer'],'first/1','Inner/2');wire([m '/Outer'],'second/1','Inner/1');
output([m '/Outer'],'position',1);output([m '/Outer'],'through',2);
wire([m '/Outer'],'Inner/1','position/1');wire([m '/Outer'],'Inner/2','through/1');
add('Sources/Constant',[m '/bias'],'Value','2');output(m,'y',1);output(m,'feed',2);
wire(m,'u/1','Outer/1');wire(m,'bias/1','Outer/2');wire(m,'Outer/1','y/1');wire(m,'Outer/2','feed/1');
add('Sinks/Terminator',[m '/unused']);wire(m,'Outer/2','unused/1');
s=fm.simulink.extractEquations(m);
verifyEqual(t,s.stateNames,{'Outer_Inner__x'});verifyEqual(t,s.sourceMap.states.Outer_Inner__x,[m '/Outer/Inner/x']);
verifyEqual(t,s.inputNames,{'u'});verifyEqual(t,s.outputNames,{'y','feed'});
compare(t,m,s,folder,1,@(time)[0.4+3*time,ones(size(time))]);
ph=get_param([m '/Outer'],'PortHandles');delete_line(get_param(ph.Inport(2),'Line'));wire(m,'u/1','Outer/2');
set_param([m '/Outer/Inner/x'],'InitialCondition','-0.3');s=fm.simulink.extractEquations(m);
b=bindings(s,[8],3);verifyEqual(t,fm.core.evaluateAst(s.derivatives{1},b),6);verifyEqual(t,s.initial.Outer_Inner__x,-0.3);
end
function testScopedSiblingRoutingAndClosedLoop(t)
[m,c,folder]=fresh('routing'); %#ok<ASGLU>
input(m,'u',1);output(m,'y',1);sub([m '/Drive']);sub([m '/Plant']);
input([m '/Drive'],'u',1);add('Signal Routing/Goto',[m '/Drive/send'],'GotoTag','command','TagVisibility','scoped');wire([m '/Drive'],'u/1','send/1');
add('Signal Routing/Goto Tag Visibility',[m '/visibility'],'GotoTag','command');
add('Signal Routing/From',[m '/Plant/receive'],'GotoTag','command');
add('Continuous/Integrator',[m '/Plant/x'],'InitialCondition','0.2');
add('Math Operations/Sum',[m '/Plant/sum'],'Inputs','+-');
add('Signal Routing/Goto',[m '/Plant/stateSend'],'GotoTag','feedback','TagVisibility','local');
add('Signal Routing/From',[m '/Plant/stateRead'],'GotoTag','feedback');
wire([m '/Plant'],'x/1','stateSend/1');wire([m '/Plant'],'receive/1','sum/1');wire([m '/Plant'],'stateRead/1','sum/2');wire([m '/Plant'],'sum/1','x/1');
output([m '/Plant'],'y',1);wire([m '/Plant'],'x/1','y/1');wire(m,'u/1','Drive/1');wire(m,'Plant/1','y/1');
s=fm.simulink.extractEquations(m);compare(t,m,s,folder,1,@(time)1-0.8*exp(-time));
set_param([m '/Drive/send'],'TagVisibility','global');delete_block([m '/visibility']);
s=fm.simulink.extractEquations(m);verifyEqual(t,fm.core.evaluateAst(s.derivatives{1},bindings(s,0.2,1)),0.8,'AbsTol',1e-14);
end
function testSiblingLocalTagsAreIndependent(t)
[m,c,folder]=fresh('localtags'); %#ok<ASGLU>
input(m,'u',1);
for k=1:2
 s=[m '/S' num2str(k)];sub(s);input(s,'u',1);output(s,'y',1);
 add('Signal Routing/Goto',[s '/send'],'GotoTag','same','TagVisibility','local');
 add('Signal Routing/From',[s '/receive'],'GotoTag','same');
 add('Continuous/Integrator',[s '/x'],'InitialCondition',num2str(k));
 wire(s,'u/1','send/1');wire(s,'receive/1','x/1');wire(s,'x/1','y/1');
 output(m,['y' num2str(k)],k);wire(m,'u/1',['S' num2str(k) '/1']);wire(m,['S' num2str(k) '/1'],['y' num2str(k) '/1']);
end
s=fm.simulink.extractEquations(m);verifyEqual(t,s.stateNames,{'S1__x','S2__x'});
compare(t,m,s,folder,1,@(time)[1+time,2+time]);
end
function testRoutingMissingAmbiguousAndScopeEscape(t)
[m,c]=simple('route_errors'); %#ok<ASGLU>
add('Signal Routing/From',[m '/orphan'],'GotoTag','not_present');
pathError(t,@()fm.simulink.extractEquations(m),'fm:UnresolvedRouting',[m '/orphan']);delete_block([m '/orphan']);
add('Signal Routing/Goto',[m '/one'],'GotoTag','t','TagVisibility','global');wire(m,'u/1','one/1');
add('Signal Routing/Goto',[m '/two'],'GotoTag','t','TagVisibility','local');wire(m,'u/1','two/1');
pathError(t,@()fm.simulink.extractEquations(m),'fm:AmbiguousRouting',[m '/two']);delete_block([m '/two']);
set_param([m '/one'],'TagVisibility','scoped');pathError(t,@()fm.simulink.extractEquations(m),'fm:RoutingScope',[m '/one']);
delete_block([m '/one']);sub([m '/Scope']);
add('Signal Routing/Goto Tag Visibility',[m '/Scope/visibility'],'GotoTag','t');
add('Signal Routing/Goto',[m '/Scope/send'],'GotoTag','t','TagVisibility','scoped');add('Sources/Constant',[m '/Scope/value'],'Value','1');wire([m '/Scope'],'value/1','send/1');
add('Signal Routing/From',[m '/outside'],'GotoTag','t');pathError(t,@()fm.simulink.extractEquations(m),'fm:UnresolvedRouting',[m '/outside']);
end
function testTransferFcnDirectFeedthroughAndScaledDenominator(t)
[m,c,folder]=dynamic('tf','Continuous/Transfer Fcn'); %#ok<ASGLU>
set_param([m '/Plant'],'Numerator','[4 14 16]','Denominator','[2 6 4]');
s=fm.simulink.extractEquations(m);verifyEqual(t,cellfun(@(n)s.initial.(n),s.stateNames),[0 0]);
% G(s)=2+(s+4)/(s^2+3s+2), unit step: 4-3 exp(-t)+exp(-2t).
compare(t,m,s,folder,1,@(time)4-3*exp(-time)+exp(-2*time));
set_param([m '/Plant'],'Numerator','[0 0 2]');s=fm.simulink.extractEquations(m);
compare(t,m,s,fullfile(folder,'edited'),1,@(time)0.5-exp(-time)+0.5*exp(-2*time));
end
function testStateSpaceNonzeroInitialWorkspaceAndIndependentODE(t)
[m,c,folder]=dynamic('ss','Continuous/State-Space'); %#ok<ASGLU>
mw=get_param(m,'ModelWorkspace');assignin(mw,'plantA',[0 1;-2 -3]);assignin(mw,'initialState',[0.4;-0.2]);
set_param([m '/Plant'],'A','plantA','B','[0; 2]','C','[1 0.5]','D','0.25','InitialCondition','initialState');
s=fm.simulink.extractEquations(m);verifyEqual(t,cellfun(@(n)s.initial.(n),s.stateNames),[0.4 -0.2]);
verifyFalse(t,isfield(s.parameters,'plantA'));verifyEqual(t,s.sourceMap.stateIndices.Plant_x2,2);
reference=ode45(@(~,z)[z(2);2-2*z(1)-3*z(2)],[0 2],[0.4;-0.2],odeset('RelTol',1e-12,'AbsTol',1e-14));
compare(t,m,s,folder,1,@(time)ssOutput(reference,time));
assignin(mw,'initialState',[0.7;0.1]);assignin(mw,'plantA',[0 1;-4 -5]);s=fm.simulink.extractEquations(m);
b=bindings(s,[0.7 0.1],1);verifyEqual(t,fm.core.evaluateAst(s.derivatives{2},b),-1.3,'AbsTol',1e-13);verifyEqual(t,s.initial.Plant_x1,0.7);
end
function testScalarInitialExpansionAndSafeNumericGrammar(t)
w=struct('k',2,'M',[1 2;3 4]);p=@(x)fm.simulink.parseNumericParameter(x,w,'model/block','A');
verifyEqual(t,p('[1e-2, -k; +3 .4]'),[0.01 -2;3 0.4]);verifyEqual(t,p('M'),[1 2;3 4]);
verifyEqual(t,p('k/2'),1);
for x={'[1:3]','[1 2;3]','[1,,2]','[ones(2)]','M(1)','system(''bad'')','[1 Inf]','[1 2];disp(1)','[k+1 2]'}
 verifyError(t,@()p(x{1}),'fm:UnsafeParameter');
end
[m,c,folder]=dynamic('ssscalar','Continuous/State-Space'); %#ok<ASGLU>
set_param([m '/Plant'],'A','[-1 0; 0 -2]','B','[1;1]','C','[1 1]','D','0','InitialCondition','0.3');
s=fm.simulink.extractEquations(m);verifyEqual(t,cellfun(@(n)s.initial.(n),s.stateNames),[0.3 0.3]);
compare(t,m,s,folder,1,@(time)1.5-0.7*exp(-time)-0.2*exp(-2*time));
end
function testDynamicDimensionImproperAndInitialRestoreRejected(t)
[m,c]=dynamic('badss','Continuous/State-Space'); %#ok<ASGLU>
set_param([m '/Plant'],'A','[-1 0;0 -2]','B','[1 0;0 1]','C','[1 1]','D','[0 0]');
pathError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedDynamics',[m '/Plant']);
mw=get_param(m,'ModelWorkspace');assignin(mw,'badInitial',[1;2]);
set_param([m '/Plant'],'B','[1;1]','D','0','InitialCondition','badInitial');assignin(mw,'badInitial',[1;2;3]);
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedDynamics');
set_param([m '/Plant'],'InitialCondition','zeros(2,1)');verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsafeParameter');
set_param([m '/Plant'],'InitialCondition','0');set_param(m,'LoadInitialState','on');verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedModel');
end
function testDirectFeedthroughCycleAndStateFeedback(t)
[m,c]=dynamic('feedback','Continuous/State-Space'); %#ok<ASGLU>
set_param([m '/Plant'],'A','-2','B','1','C','1','D','0','InitialCondition','0.2');
ph=get_param([m '/Plant'],'PortHandles');delete_line(get_param(ph.Inport(1),'Line'));wire(m,'Plant/1','Plant/1');
s=fm.simulink.extractEquations(m);verifyEqual(t,fm.core.evaluateAst(s.derivatives{1},bindings(s,0.2,1)),-0.2,'AbsTol',1e-15);
set_param([m '/Plant'],'D','1');pathError(t,@()fm.simulink.extractEquations(m),'fm:AlgebraicLoop',[m '/Plant']);
end
function testUnknownDeadNestedBlockFullPath(t)
[m,c]=simple('unknown'); %#ok<ASGLU>
sub([m '/Outer']);sub([m '/Outer/Inner']);bad=[m '/Outer/Inner/Unsupported Delay'];add('Discrete/Unit Delay',bad);
pathError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedBlock',bad);
end
function testControlledMaskedAtomicAndDiscreteRejected(t)
[m,c]=simple('controls'); %#ok<ASGLU>
sub([m '/Sub']);set_param([m '/Sub'],'TreatAsAtomicUnit','on');verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
set_param([m '/Sub'],'TreatAsAtomicUnit','off');add('Ports & Subsystems/Enable',[m '/Sub/enable']);
pathError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration',[m '/Sub']);delete_block([m '/Sub/enable']);
mask=Simulink.Mask.create([m '/Sub']);mask.Initialization='disp(''must not execute'')';verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
end
function testStableLegalNamesSourceMapAndNoMutation(t)
[m,c,folder]=simple('names'); %#ok<ASGLU>
set_param([m '/x'],'Name','state one');
set_param([m '/state one'],'UserData',struct('fmName','sin'),'UserDataPersistent','on');
set_param([m '/y'],'Name','input value');set_param([m '/u'],'Name','input-value');
p=fullfile(folder,[m '.slx']);save_system(m,p);dirty=get_param(m,'Dirty');before=get_param([m '/state one'],'InitialCondition');
s=fm.simulink.extractEquations(m);s2=fm.simulink.extractEquations(p);
verifyEqual(t,s.stateNames,s2.stateNames);verifyEqual(t,s.inputNames,s2.inputNames);verifyEqual(t,s.outputNames,s2.outputNames);
verifyEqual(t,s.stateNames,{'sin_1'});verifyEqual(t,s.inputNames,{'input_value'});verifyEqual(t,s.outputNames,{'input_value_1'});
verifyEqual(t,get_param(m,'Dirty'),dirty);verifyEqual(t,get_param([m '/state one'],'InitialCondition'),before);verifyTrue(t,bdIsLoaded(m));
close_system(m,0);s3=fm.simulink.extractEquations(p);verifyFalse(t,bdIsLoaded(m));verifyEqual(t,s3.stateNames,s.stateNames);
end
function testDeadAlgebraicRoutingCycleRejected(t)
[m,c]=simple('deadloop'); %#ok<ASGLU>
add('Signal Routing/Goto',[m '/send'],'GotoTag','loop','TagVisibility','local');add('Signal Routing/From',[m '/receive'],'GotoTag','loop');
wire(m,'receive/1','send/1');pathError(t,@()fm.simulink.extractEquations(m),'fm:AlgebraicLoop',[m '/receive']);
end
function [m,c,folder]=fresh(label)
root=fileparts(fileparts(mfilename('fullpath')));parent=fullfile(root,'artifacts','v2','model','fixtures');if ~isfolder(parent),mkdir(parent);end
folder=tempname(parent);mkdir(folder);[~,id]=fileparts(folder);m=matlab.lang.makeValidName(['v2_' label '_' id]);m=m(1:min(end,namelengthmax));
new_system(m);c=onCleanup(@()saveClose(m,folder));
end
function [m,c,folder]=simple(label)
[m,c,folder]=fresh(label);input(m,'u',1);output(m,'y',1);add('Continuous/Integrator',[m '/x'],'InitialCondition','0.2');wire(m,'u/1','x/1');wire(m,'x/1','y/1');
end
function [m,c,folder]=dynamic(label,lib)
[m,c,folder]=fresh(label);input(m,'u',1);output(m,'y',1);add(lib,[m '/Plant']);wire(m,'u/1','Plant/1');wire(m,'Plant/1','y/1');
end
function input(sys,name,port)
add('Sources/In1',[sys '/' name],'Port',num2str(port));
if strcmp(sys,bdroot(sys)),set_param([sys '/' name],'PortDimensions','1','OutDataTypeStr','double','SignalType','real');end
end
function output(sys,name,port)
add('Sinks/Out1',[sys '/' name],'Port',num2str(port));
end
function sub(path)
add_block('built-in/Subsystem',path);
end
function add(lib,path,varargin)
add_block(['simulink/' lib],path,varargin{:});p=get_param(path,'ObjectParameters');
if isfield(p,'SaturateOnIntegerOverflow'),set_param(path,'SaturateOnIntegerOverflow','off');end
end
function wire(sys,src,dst)
add_line(sys,src,dst,'autorouting','on');
end
function saveClose(m,folder)
if bdIsLoaded(m)
 try,save_system(m,fullfile(folder,[m '.slx']));catch,end
 close_system(m,0);
end
end
function b=bindings(s,x,u)
b=s.parameters;for k=1:numel(s.stateNames),b.(s.stateNames{k})=x(k);end
for k=1:numel(s.inputNames),b.(s.inputNames{k})=u(k);end
end
function pathError(t,f,id,path)
try,f();verifyFail(t,['Expected ' id]);catch e,verifyEqual(t,e.identifier,id);verifyTrue(t,contains(e.message,path),e.message);end
end
function y=ssOutput(reference,time)
x=deval(reference,time);y=(x(1,:)+0.5*x(2,:)+0.25)';
end
function compare(t,m,s,folder,inputValue,expected)
if ~isfolder(folder),mkdir(folder);end
save_system(m,fullfile(folder,[m '.slx']));
original=simulate(m,inputValue);rebuiltSpec=s;rebuiltSpec.name=[m(1:min(numel(m),namelengthmax-8)) '_rebuilt'];
p=fm.simulink.generateModel(rebuiltSpec,fullfile(folder,'rebuilt'));load_system(p);cleanup=onCleanup(@()close_system(rebuiltSpec.name,0)); %#ok<NASGU>
rebuilt=simulate(rebuiltSpec.name,inputValue);errors=zeros(2,numel(s.outputNames));
for k=1:numel(s.outputNames)
 a=original.getElement(k).Values;b=rebuilt.getElement(k).Values;
 ref=expected(a.Time);ref2=expected(b.Time);
 errors(1,k)=max(abs(double(a.Data(:))-ref(:,k)));errors(2,k)=max(abs(double(b.Data(:))-ref2(:,k)));
 verifyLessThan(t,errors(1,k),2e-7);verifyLessThan(t,errors(2,k),2e-7);
end
fprintf('INDEPENDENT %s max_native=%.12g max_rebuilt=%.12g\n',m,max(errors(1,:)),max(errors(2,:)));
save(fullfile(folder,'independent-comparison.mat'),'original','rebuilt','s','errors');
fid=fopen(fullfile(folder,'comparison.json'),'w');fprintf(fid,'%s',jsonencode(struct('model',m,'maxNativeError',max(errors(1,:)),'maxRebuiltError',max(errors(2,:)),'tolerance',2e-7)));fclose(fid);
end
function outputs=simulate(m,value)
time=(0:0.01:2)';ds=Simulink.SimulationData.Dataset;ds=ds.addElement(timeseries(value*ones(size(time)),time),'u');
in=Simulink.SimulationInput(m);in=in.setExternalInput(ds);
in=in.setModelParameter('StopTime','2','Solver','ode45','RelTol','1e-10','AbsTol','1e-12','MaxStep','0.01', ...
 'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset');result=sim(in);outputs=result.get('yout');
end
