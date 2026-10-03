function tests=TestParser
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
t.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end
function testArithmetic(t)
cases={'2+3*4',14;'(2+3)*4',20;'2^3^2',512;'-2^2',-4;'(-2)^2',4;'2^-2',0.25;'10-6/3',8;'1e-3+.5E+1',5.001;'--2',2;'sin(0)+cos(0)+exp(0)',2};
for k=1:size(cases,1)
    ast=fm.parser.parseExpression(cases{k,1});
    verifyEqual(t,fm.core.evaluateAst(ast,struct()),cases{k,2},'AbsTol',1e-12);
    verifyEqual(t,sort(fieldnames(ast)),sort({'kind';'value';'args'}));
end
end
function testBindings(t)
a=fm.parser.parseExpression('(-k*x+u)/m');
verifyEqual(t,fm.core.evaluateAst(a,struct('k',3,'x',2,'u',10,'m',2)),2);
verifyError(t,@() fm.core.evaluateAst(a,struct()),'fm:MissingBinding');
verifyError(t,@() fm.core.evaluateAst(a,struct('k',NaN)),'fm:Bindings');
end
function testUnsafeSyntax(t)
values={'system(1)','x(1)','x.y','x;1','[1 2]','''x''','x=1','sin(1,2)','sin()','2x','1e','x.*2','@sin','pi','sin','1+','(1','1)'};
for k=1:numel(values), verifyFmError(t,@() fm.parser.parseExpression(values{k})); end
end
function testLimits(t)
verifyError(t,@() fm.parser.parseExpression(repmat('1',1,4097)),'fm:ExpressionLength');
verifyError(t,@() fm.parser.parseExpression([repmat('(',1,160) '1' repmat(')',1,160)]),'fm:ExpressionDepth');
verifyError(t,@() fm.parser.parseExpression('1e999'),'fm:NumberRange');
verifyError(t,@() fm.parser.parseExpression(' '),'fm:EmptyExpression');
verifyError(t,@() fm.parser.parseExpression(1),'fm:ExpressionType');
end
function testDomain(t)
verifyError(t,@() fm.core.evaluateAst(fm.parser.parseExpression('1/0'),struct()),'fm:DivisionByZero');
verifyError(t,@() fm.core.evaluateAst(fm.parser.parseExpression('(-1)^.5'),struct()),'fm:NonRealResult');
verifyError(t,@() fm.core.evaluateAst(fm.parser.parseExpression('exp(1000)'),struct()),'fm:NonRealResult');
end
function testAstBoundary(t)
a=struct('kind','call','value','system','args',{{fm.parser.parseExpression('1')}});
verifyError(t,@() fm.core.evaluateAst(a,struct()),'fm:InvalidAst');
a=fm.parser.parseExpression('x+1'); a.args={};
verifyError(t,@() fm.export.expressionText(a),'fm:InvalidAst');
a=fm.parser.parseExpression('1'); a.extra=1;
verifyError(t,@() fm.export.expressionLatex(a),'fm:InvalidAst');
end
function verifyFmError(t,f)
try
    f(); verifyFail(t,'Expected an fm error.');
catch e
    verifyTrue(t,startsWith(e.identifier,'fm:'),e.message);
end
end
