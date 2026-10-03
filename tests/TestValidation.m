function tests=TestValidation
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
t.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end
function testNormalizesAndOrders(t)
r=fixture(); r.states=["x";"v"]; r.inputs="u"; r.equations=["der(v) = (u-c*v-k*x)/m";"der(x)=v"];
s=fm.core.validateSpec(r);
verifyEqual(t,s.stateNames,{'x','v'}); verifyEqual(t,s.inputNames,{'u'});
verifyEqual(t,s.derivatives{1}.value,'v'); verifyEqual(t,s.schemaVersion,1);
verifyEqual(t,fm.core.evaluateAst(s.derivatives{2},struct('u',10,'c',1,'v',2,'k',3,'x',2,'m',2)),1);
verifyEqual(t,fm.core.validateSpec(s),s);
end
function testJsonInput(t)
r=jsondecode('{"name":"json_model","states":["x"],"inputs":[],"parameters":{},"initial":{"x":1},"equations":["der(x)=-x"],"outputs":{"y":"x"}}');
s=fm.core.validateSpec(r); verifyEqual(t,s.inputs,{}); verifyEqual(t,s.states,{'x'});
verifyEmpty(t,fieldnames(s.parameters)); verifyEqual(t,s.outputNames,{'y'});
end
function testDuplicateRolesAndReserved(t)
r=fixture(); r.outputs.x='x'; verifyError(t,@() fm.core.validateSpec(r),'fm:DuplicateIdentifier');
r=fixture(); r.inputs={'x'}; verifyError(t,@() fm.core.validateSpec(r),'fm:DuplicateIdentifier');
r=fixture(); r.parameters.sin=1; verifyError(t,@() fm.core.validateSpec(r),'fm:Identifier');
r=fixture(); r.name='bad-name'; verifyError(t,@() fm.core.validateSpec(r),'fm:Identifier');
r=fixture(); r.states={'x','x'}; verifyError(t,@() fm.core.validateSpec(r),'fm:DuplicateIdentifier');
end
function testDerivatives(t)
r=fixture(); r.equations={'der(x)=v'}; verifyError(t,@() fm.core.validateSpec(r),'fm:MissingDerivative');
r=fixture(); r.equations={'der(x)=v','der(x)=1'}; verifyError(t,@() fm.core.validateSpec(r),'fm:DuplicateDerivative');
r=fixture(); r.equations={'der(z)=v','der(v)=1'}; verifyError(t,@() fm.core.validateSpec(r),'fm:UnknownDerivative');
r=fixture(); r.equations={'x=v','der(v)=1'}; verifyError(t,@() fm.core.validateSpec(r),'fm:DerivativeSyntax');
end
function testSymbols(t)
r=fixture(); r.equations={'der(x)=z','der(v)=1'}; verifyError(t,@() fm.core.validateSpec(r),'fm:UnknownSymbol');
r=fixture(); r.outputs.z='y'; verifyError(t,@() fm.core.validateSpec(r),'fm:UnknownSymbol');
end
function testNumericValues(t)
values={Inf,NaN,1i,[1 2],'2',true};
for k=1:numel(values)
    r=fixture(); r.parameters.m=values{k}; verifyError(t,@() fm.core.validateSpec(r),'fm:NumericValue');
    r=fixture(); r.initial.x=values{k}; verifyError(t,@() fm.core.validateSpec(r),'fm:NumericValue');
end
r=fixture(); r.initial=rmfield(r.initial,'x'); verifyError(t,@() fm.core.validateSpec(r),'fm:InitialStates');
r=fixture(); r.initial.z=0; verifyError(t,@() fm.core.validateSpec(r),'fm:InitialStates');
end
function testMissingFields(t)
r=fixture(); r=rmfield(r,'initial'); verifyError(t,@() fm.core.validateSpec(r),'fm:MissingField');
r=fixture(); r.outputs=struct(); verifyError(t,@() fm.core.validateSpec(r),'fm:Outputs');
r=fixture(); r.states={}; verifyError(t,@() fm.core.validateSpec(r),'fm:EmptyList');
end
function r=fixture()
r=struct('name','oscillator','states',{{'x','v'}},'inputs',{{'u'}},'parameters',struct('m',2,'c',1,'k',3),'initial',struct('x',1,'v',0),'equations',{{'der(x)=v','der(v)=(u-c*v-k*x)/m'}},'outputs',struct('y','x'));
end
