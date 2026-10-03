function tests=TestRoundTrip
tests=functiontests(localfunctions);
end
function testEditedGainConstantAndConnection(t)
[m,c]=fixture; %#ok<ASGLU>
r=fm.simulink.extractEquations(m); verifyEqual(t,value(r),-3);
g=find_system(m,'BlockType','Gain'); set_param(g{1},'Gain','-3');
r=fm.simulink.extractEquations(m); verifyEqual(t,value(r),-11);
k=find_system(m,'BlockType','Constant'); set_param(k{1},'Value','5');
r=fm.simulink.extractEquations(m); verifyEqual(t,value(r),-7);
ph=get_param([m '/state_x'],'PortHandles'); delete_line(get_param(ph.Inport(1),'Line'));
add_line(m,'input_u/1','state_x/1','autorouting','on');
r=fm.simulink.extractEquations(m); verifyEqual(t,value(r),7);
verifyTrue(t,contains(fm.export.toText(r),'u'));
end
function testWorkspaceAndInitialEdits(t)
[m,c]=fixture; %#ok<ASGLU>
assignin(get_param(m,'ModelWorkspace'),'k',4);
g=find_system(m,'BlockType','Gain'); set_param(g{1},'Gain','-k/2');
set_param([m '/state_x'],'InitialCondition','k+1');
r=fm.simulink.extractEquations(m); verifyEqual(t,r.initial.x,5); verifyEqual(t,value(r),-7);
end
function testIntegratorSettingsRejected(t)
[m,c]=fixture; %#ok<ASGLU>
set_param([m '/state_x'],'LimitOutput','on');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
set_param([m '/state_x'],'LimitOutput','off','ExternalReset','rising');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
end
function testExpandedDynamicsAndHierarchy(t)
[m,c]=fixture; %#ok<ASGLU>
add_block('simulink/Continuous/Transfer Fcn',[m '/extra'],'Numerator','[2]','Denominator','[1 3]');
add_line(m,'input_u/1','extra/1');
r=fm.simulink.extractEquations(m); verifyEqual(t,numel(r.stateNames),2);
b=r.parameters; b.x=4;b.u=7;b.extra_x1=2;
verifyEqual(t,fm.core.evaluateAst(r.derivatives{2},b),1);
mw=get_param(m,'ModelWorkspace');assignin(mw,'tfNumerator',[2]);set_param([m '/extra'],'Numerator','tfNumerator');
assignin(mw,'tfNumerator',[1 2 3]);
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedDynamics');
delete_block([m '/extra']); add_block('simulink/Ports & Subsystems/Subsystem',[m '/extra']);
add_line(m,'input_u/1','extra/1');
r=fm.simulink.extractEquations(m);verifyEqual(t,value(r),-3);
set_param([m '/extra'],'TreatAsAtomicUnit','on');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
end
function testUnsafeAndVectorParameters(t)
[m,c]=fixture; %#ok<ASGLU>
k=find_system(m,'BlockType','Constant'); set_param(k{1},'Value','[1 2]');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsafeParameter');
set_param(k{1},'Value','system(1)'); verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsafeParameter');
set_param(k{1},'Value','1'); set_param([m '/input_u'],'PortDimensions','2');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
end
function testAlgebraicLoop(t)
[m,c]=fixture; %#ok<ASGLU>
g=find_system(m,'BlockType','Gain'); ph=get_param(g{1},'PortHandles'); delete_line(get_param(ph.Inport(1),'Line'));
add_line(m,[get_param(g{1},'Name') '/1'],[get_param(g{1},'Name') '/1']);
verifyError(t,@()fm.simulink.extractEquations(m),'fm:AlgebraicLoop');
end
function testDivisionOrderAndSigns(t)
[m,c]=fixture; %#ok<ASGLU>
add_block('simulink/Math Operations/Product',[m '/divide'],'Inputs','/*');
add_line(m,'state_x/1','divide/1'); add_line(m,'input_u/1','divide/2');
ph=get_param([m '/state_x'],'PortHandles'); delete_line(get_param(ph.Inport(1),'Line')); add_line(m,'divide/1','state_x/1');
r=fm.simulink.extractEquations(m); verifyEqual(t,value(r),7/4,'AbsTol',1e-12);
s=find_system(m,'BlockType','Sum'); set_param(s{1},'Inputs','--');
ph=get_param([m '/state_x'],'PortHandles'); delete_line(get_param(ph.Inport(1),'Line')); add_line(m,[get_param(s{1},'Name') '/1'],'state_x/1');
r=fm.simulink.extractEquations(m); verifyEqual(t,value(r),3);
end
function testSampleTimeAndCommentRejected(t)
[m,c]=fixture; %#ok<ASGLU>
g=find_system(m,'BlockType','Gain'); set_param(g{1},'SampleTime','0.1');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
set_param(g{1},'SampleTime','-1','Commented','through');
verifyError(t,@()fm.simulink.extractEquations(m),'fm:UnsupportedConfiguration');
end
function testOutputConnectionAndMetadata(t)
[m,c]=fixture; %#ok<ASGLU>
set_param([m '/state_x'],'UserData',struct('fmName','x','equations',{{'der(x) = 999'}}));
ph=get_param([m '/output_y'],'PortHandles'); delete_line(get_param(ph.Inport(1),'Line'));
add_line(m,'input_u/1','output_y/1');
r=fm.simulink.extractEquations(m);
verifyEqual(t,fm.export.expressionText(r.outputExpressions{1}),'u');
verifyEqual(t,value(r),-3); verifyTrue(t,bdIsLoaded(m));
end
function v=value(r)
b=r.parameters; b.x=4; b.u=7; v=fm.core.evaluateAst(r.derivatives{1},b);
end
function [m,c]=fixture
root=fileparts(fileparts(mfilename('fullpath'))); parent=fullfile(root,'artifacts','v2','model','roundtrip'); if ~exist(parent,'dir'),mkdir(parent);end
folder=tempname(parent); [~,id]=fileparts(folder); m=matlab.lang.makeValidName(['fm_rt_' id]);
s=struct('name',m,'states',{{'x'}},'inputs',{{'u'}},'parameters',struct(),'initial',struct('x',2),'equations',{{'der(x) = -x + 1'}},'outputs',struct('y','x+u'));
p=fm.simulink.generateModel(fm.core.validateSpec(s),folder); load_system(p); c=onCleanup(@()saveAndClose(m,p));
end
function saveAndClose(m,p)
if bdIsLoaded(m), save_system(m,p); close_system(m,0); end
end
