function tests=TestFormulaExport
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
t.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end
function testRoundTrip(t)
expressions={'-x^2','x-(u-x)','x/(u/x)','2^3^2','sin(x)+cos(u)*exp(-x)','1e-12*x','2^-x'};
for k=1:numel(expressions)
    a=fm.parser.parseExpression(expressions{k}); text=fm.export.expressionText(a);
    b=fm.parser.parseExpression(text); verifyEqual(t,b,a);
end
end
function testLatex(t)
a=fm.parser.parseExpression('state_x/(u-state_x)');
verifyEqual(t,fm.export.expressionLatex(a),'\frac{\mathrm{state\_x}}{\left(\mathrm{u} - \mathrm{state\_x}\right)}');
verifyEqual(t,fm.export.expressionLatex(fm.parser.parseExpression('-x^2')),'\left(-\left(\mathrm{x}\right)^{2}\right)');
verifyTrue(t,contains(fm.export.expressionLatex(fm.parser.parseExpression('1e20')),'\times 10^{20}'));
end
function testIndependentDocuments(t)
s=fixture(); text=fm.export.toText(s); latex=fm.export.toLatex(s);
verifyTrue(t,contains(text,'Inputs: u')); verifyTrue(t,contains(text,'x(0) = 2'));
verifyTrue(t,contains(text,'a = 3')); verifyTrue(t,contains(text,'der(x) = (((-a) * x) + u)'));
verifyTrue(t,contains(latex,'\documentclass{article}')); verifyTrue(t,contains(latex,'\end{document}'));
verifyTrue(t,contains(latex,'Initial conditions')); verifyTrue(t,contains(latex,'Outputs:'));
end
function testWritesAndRefusesOverwrite(t)
root=fileparts(fileparts(mfilename('fullpath'))); folder=tempname(fullfile(root,'artifacts','core'));
paths=fm.export.writeReport(fixture(),folder);
verifyEqual(t,fileread(paths.text),fm.export.toText(fixture()));
verifyEqual(t,fileread(paths.latex),fm.export.toLatex(fixture()));
verifyTrue(t,contains(fileread(paths.markdown),'Original derivative equations:'));
verifyError(t,@() fm.export.writeReport(fixture(),folder),'fm:ReportExists');
verifyEqual(t,fileread(paths.text),fm.export.toText(fixture()));
end
function testEmptyRoles(t)
s=fixture(); s.inputs={}; s.parameters=struct(); s.equations={'der(x)=-x'};
verifyTrue(t,contains(fm.export.toText(s),'Inputs: (none)'));
verifyTrue(t,contains(fm.export.toLatex(s),'None.'));
end
function testNegativeNumberPower(t)
a=struct('kind','number','value',-2,'args',{{}});
b=struct('kind','number','value',2,'args',{{}});
ast=struct('kind','binary','value','^','args',{{a,b}});
text=fm.export.expressionText(ast);
verifyEqual(t,fm.core.evaluateAst(fm.parser.parseExpression(text),struct()),4);
end
function testLongExpressionRoundTrip(t)
source=strjoin(repmat({'x'},1,30),'+');
ast=fm.parser.parseExpression(source);
verifyEqual(t,fm.parser.parseExpression(fm.export.expressionText(ast)),ast);
end
function s=fixture()
s=struct('name','export_model','states',{{'x'}},'inputs',{{'u'}},'parameters',struct('a',3),'initial',struct('x',2),'equations',{{'der(x)=-a*x+u'}},'outputs',struct('y','x'));
end
