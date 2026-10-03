classdef TestSymbolicAnalysis < matlab.unittest.TestCase
    methods (Test)
        function firstOrderExactAndChineseDerivation(test)
            raw=fixture({'x'},{'u'},struct('a',2,'b',3), ...
                {'der(x)=-a*x+b*u'},struct('y','x'));
            raw.initial.x=17;
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            a=sym('a','real'); b=sym('b','real'); s=r.laplaceVariable;
            equalSym(test,r.A,-a); equalSym(test,r.B,b);
            equalSym(test,r.C,1); equalSym(test,r.D,0);
            equalSym(test,r.transferMatrix,b/(s+a));
            test.verifyEqual(r.symbolicParameters,{'a','b'});
            test.verifyTrue(contains(r.text,'零初值'));
            test.verifyTrue(contains(r.text,'A = '));
            test.verifyTrue(contains(r.text,'G(s)=C(s I-A)^(-1)B+D'));
            test.verifyTrue(contains(r.text,'y <- u'));
            test.verifyTrue(contains(r.latex,'x(0)=0'));
            test.verifyTrue(contains(r.latex,[' \\' newline]));
            test.verifyFalse(contains(r.latex,[' \' newline]));
            raw.initial.x=-9;
            r2=fm.analysis.deriveSymbolicTransferFunction(raw);
            equalSym(test,r.transferMatrix,r2.transferMatrix);
        end
        function massSpringExactHandDerivation(test)
            raw=fixture({'x','v'},{'F'},struct('m','symbolic','c','symbolic','k','symbolic'), ...
                {'der(v)=(F-c*v-k*x)/m','der(x)=v'},struct('position','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            m=sym('m','real'); c=sym('c','real'); k=sym('k','real'); s=r.laplaceVariable;
            equalSym(test,r.A,[0 1;-k/m -c/m]); equalSym(test,r.B,[0;1/m]);
            equalSym(test,r.C,[1 0]); equalSym(test,r.D,0);
            equalSym(test,r.transferMatrix,1/(m*s^2+c*s+k));
            test.verifyEqual(numel(r.parameterConditions),1);
            test.verifyEqual(r.parameterConditions(1),m~=0);
            test.verifyTrue(contains(r.conditions,'m ~= 0'));
        end
        function mimoOrderedNamesAndDirectFeedthrough(test)
            outputs=struct(); outputs.z_out='3*z+2*w+q'; outputs.a_out='z-4*w+5*b';
            raw=fixture({'z','w'},{'q','b'},struct('alpha','symbolic','beta',2), ...
                {'der(w)=-beta*w+4*b','der(z)=-alpha*z+2*q+b'},outputs);
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            a=sym('alpha','real'); beta=sym('beta','real'); s=r.laplaceVariable;
            equalSym(test,r.A,[-a 0;0 -beta]); equalSym(test,r.B,[2 1;0 4]);
            equalSym(test,r.C,[3 2;1 -4]); equalSym(test,r.D,[1 0;0 5]);
            expected=[6/(s+a)+1,3/(s+a)+8/(s+beta);2/(s+a),1/(s+a)-16/(s+beta)+5];
            equalSym(test,r.transferMatrix,expected);
            test.verifyEqual(r.stateNames,{'z','w'}); test.verifyEqual(r.inputNames,{'q','b'});
            test.verifyEqual(r.outputNames,{'z_out','a_out'});
            test.verifyTrue(contains(r.latex,'z\_out'));
        end
        function numericFrequencyResponseAfterSubstitution(test)
            raw=fixture({'x','v'},{'F'},struct('m',2,'c',3,'k',4), ...
                {'der(v)=(F-c*v-k*x)/m','der(x)=v'},struct('position','x','velocity','v'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            numeric=fm.analysis.deriveTransferFunction(fm.core.validateSpec(raw));
            G=subs(r.transferMatrix,r.parameterSymbols,[2 3 4]);
            for point=[0 1i 3i 1+2i -2+3i]
                actual=double(subs(G,r.laplaceVariable,point));
                independent=[1;point]/(2*point^2+3*point+4);
                test.verifyEqual(actual,independent,'AbsTol',1e-12);
                test.verifyEqual(actual,evalfr(numeric.system,point),'AbsTol',1e-12);
            end
        end
        function mixedSelectedNumericAndUnresolved(test)
            raw=fixture({'x'},{'u'},struct('a',2,'b','symbolic','c',3), ...
                {'der(x)=-a*x+b*u'},struct('y','c*x'));
            opts=struct('symbolicParameters',{{'c'}});
            r=fm.analysis.deriveSymbolicTransferFunction(raw,opts);
            b=sym('b','real'); c=sym('c','real');
            test.verifyEqual(r.symbolicParameters,{'b','c'});
            equalSym(test,r.A,-2); equalSym(test,r.transferMatrix,c*b/(r.laplaceVariable+2));
            opts.symbolicParameters={}; r=fm.analysis.deriveSymbolicTransferFunction(raw,opts);
            test.verifyEqual(r.symbolicParameters,{'b'});
            equalSym(test,r.transferMatrix,3*b/(r.laplaceVariable+2));
        end
        function explicitEmptySelectionNumeric(test)
            raw=fixture({'x'},{'u'},struct('a',2,'b',3),{'der(x)=-a*x+b*u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw,struct('symbolicParameters',{{}}));
            test.verifyEmpty(r.symbolicParameters); test.verifyClass(r.A,'sym');
            equalSym(test,r.transferMatrix,3/(r.laplaceVariable+2));
        end
        function validatorKeepsUnresolvedDeclarations(test)
            raw=fixture({'x'},{'u'},struct('a',"symbolic",'b',5),{'der(x)=-a*x+b*u'},struct('y','x'));
            spec=fm.analysis.validateSymbolicSpec(raw);
            test.verifyEqual(spec.parameters,raw.parameters);
            test.verifyTrue(spec.symbolicSpec); test.verifyEqual(spec.unresolvedParameters,{'a'});
            test.verifyEqual(spec.stateNames,{'x'}); test.verifyEqual(spec.derivatives{1}.kind,'binary');
            test.verifyError(@()fm.core.validateSpec(spec),'fm:NumericValue');
            r=fm.analysis.deriveSymbolicTransferFunction(spec);
            test.verifyEqual(r.parameterDeclarations,raw.parameters);
        end
        function sharedStructureChecks(test)
            raw=fixture({'x'},{'u'},struct('a','symbolic'),{'der(x)=-a*x+u'},struct('y','x'));
            raw.equations={'der(x)=missing*x+u'};
            test.verifyError(@()fm.analysis.validateSymbolicSpec(raw),'fm:UnknownSymbol');
            raw.equations={'der(x)=system(u)'};
            test.verifyError(@()fm.analysis.validateSymbolicSpec(raw),'fm:ExpressionSyntax');
            raw.equations={'der(x)=-a*x+u'}; raw.parameters.x=1;
            test.verifyError(@()fm.analysis.validateSymbolicSpec(raw),'fm:DuplicateIdentifier');
        end
        function invalidParameterDeclarations(test)
            values={'2','a+1','Symbolic',' symbolic','symbolic ',"sin(1)", ...
                NaN,Inf,1+1i,[1 2],true,{},struct(),string(missing),['symbolic';'symbolic']};
            for k=1:numel(values)
                raw=fixture({'x'},{'u'},struct('p',1),{'der(x)=-p*x+u'},struct('y','x'));
                raw.parameters.p=values{k};
                test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:InvalidParameter');
            end
        end
        function invalidOptions(test)
            raw=fixture({'x'},{'u'},struct('p',2),{'der(x)=-p*x+u'},struct('y','x'));
            options={[],struct('typo',1),struct('symbolicParameters','p'), ...
                struct('symbolicParameters',{{'q'}}),struct('symbolicParameters',{{'p','p'}})};
            for k=1:numel(options)
                test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw,options{k}), ...
                    'fm:symbolic:InvalidOptions');
            end
        end
        function rejectsLuckySubstitutionNonlinearity(test)
            equations={'(p-1)*x^2+u','sin(p-1)*x*x+u','(p-1)*x*u+u', ...
                '(p-1)*sin(x)+u','x^(p+1)+u','2^u+x','x/(1+p*x)+u'};
            for k=1:numel(equations)
                raw=fixture({'x'},{'u'},struct('p',1),{['der(x)=' equations{k}]},struct('y','x'));
                test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:Nonlinear');
            end
        end
        function unresolvedCannotBecomeLuckyPlaceholder(test)
            raw=fixture({'x'},{'u'},struct('p','symbolic'),{'der(x)=(p-1)*x^2+u'},struct('y','x'));
            spec=fm.analysis.validateSymbolicSpec(raw);
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(spec), 'fm:symbolic:Nonlinear');
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(spec, ...
                struct('symbolicParameters',{{}})),'fm:symbolic:Nonlinear');
        end
        function rejectsSymbolicNonlinearOutput(test)
            raw=fixture({'x'},{'u'},struct('p',0),{'der(x)=-x+u'},struct('y','p*x*u'));
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:Nonlinear');
        end
        function rejectsSymbolicOffsets(test)
            raw=fixture({'x'},{'u'},struct('p',0),{'der(x)=-x+u+p'},struct('y','x'));
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:AffineOffset');
            raw.equations={'der(x)=-x+u'}; raw.outputs.y='x+p';
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:AffineOffset');
            raw.outputs.y='x+1e-20';
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:AffineOffset');
        end
        function exactCancellationAndExplicitNumericalDegeneracy(test)
            raw=fixture({'x'},{'u'},struct('p',1), ...
                {'der(x)=x*x-x^2+(p-p)*sin(x)+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw); equalSym(test,r.A,0); equalSym(test,r.B,1);
            raw.equations={'der(x)=(p-1)*x*x+u'};
            r=fm.analysis.deriveSymbolicTransferFunction(raw,struct('symbolicParameters',{{}}));
            equalSym(test,r.transferMatrix,1/r.laplaceVariable);
        end
        function tinyCoefficientsStayExactNonzero(test)
            raw=fixture({'x'},{'u'},struct(),{'der(x)=1e-20*x+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            test.verifyEqual(double(r.A),1e-20); test.verifyNotEqual(r.A,sym(0));
        end
        function originalDivisionSurvivesSimplification(test)
            raw=fixture({'x'},{'u'},struct('p',0),{'der(x)=-(p/p)*x+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw); p=sym('p','real');
            equalSym(test,r.A,-1); equalSym(test,r.transferMatrix,1/(r.laplaceVariable+1));
            test.verifyEqual(r.parameterConditions,p~=0);
            test.verifyEqual(r.domainConditions(1).source,'p');
            test.verifyTrue(contains(r.conditions,'p ~= 0'));
            test.verifyFalse(isAlways(subs(r.parameterConditions,p,0),'Unknown','false'));
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw, ...
                struct('symbolicParameters',{{}})),'fm:symbolic:DivisionByZero');
        end
        function nestedDivisionAndZeroMultiplierDomains(test)
            raw=fixture({'x'},{'u'},struct('p','symbolic','q','symbolic'), ...
                {'der(x)=-x+u+0*(1/p)'},struct('y','x/(p/q)'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            p=sym('p','real'); q=sym('q','real');
            test.verifyEqual(numel(r.domainConditions),3);
            test.verifyEqual(r.domainConditions(1).relation,p~=0);
            test.verifyEqual(r.domainConditions(2).relation,q~=0);
            test.verifyEqual(r.domainConditions(3).relation,p/q~=0);
            equalSym(test,r.C,q/p);
        end
        function invalidDomainsRejectBeforeCancellation(test)
            expressions={'x/(p-p)+u','0*(1/0)+u','0^(-1)*x+u','(-1)^0.5*x+u'};
            for k=1:numel(expressions)
                raw=fixture({'x'},{'u'},struct('p','symbolic'),{['der(x)=' expressions{k}]},struct('y','x'));
                if k==4, id='fm:symbolic:Domain'; else, id='fm:symbolic:DivisionByZero'; end
                test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),id);
            end
        end
        function cancelledStateDivisionStillRejected(test)
            expressions={'x/x+u-1','0*(1/x)+u','(x^2)/x+u'};
            for k=1:numel(expressions)
                raw=fixture({'x'},{'u'},struct(),{['der(x)=' expressions{k}]},struct('y','x'));
                test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:Nonlinear');
            end
        end
        function negativePowerDomain(test)
            raw=fixture({'x'},{'u'},struct('p','symbolic'),{'der(x)=-p^(-2)*x+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw); p=sym('p','real');
            equalSym(test,r.A,-1/p^2); test.verifyEqual(r.parameterConditions,p~=0);
        end
        function fractionalPowerDomainSurvivesCancellation(test)
            raw=fixture({'x'},{'u'},struct('p','symbolic'),{'der(x)=-(p^0.5)^2*x+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw); p=sym('p','real');
            equalSym(test,r.A,-p); test.verifyEqual(r.parameterConditions,p>=0);
            test.verifyFalse(isAlways(subs(r.parameterConditions,p,-1),'Unknown','false'));
        end
        function realPowerExplicitBranchCondition(test)
            raw=fixture({'x'},{'u'},struct('p','symbolic','q','symbolic'),{'der(x)=-p^q*x+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            p=sym('p','real'); q=sym('q','real');
            condition=r.parameterConditions(1);
            test.verifyTrue(isAlways(subs(condition,[p q],[-2 3]),'Unknown','false'));
            test.verifyFalse(isAlways(subs(condition,[p q],[-2 sym(1)/2]),'Unknown','false'));
            test.verifyFalse(isAlways(subs(condition,[p q],[0 -1]),'Unknown','false'));
            test.verifyTrue(isAlways(subs(condition,[p q],[0 2]),'Unknown','false'));
        end
        function parameterFunctionsAndRealNotPositive(test)
            raw=fixture({'x'},{'u'},struct('p','symbolic'), ...
                {'der(x)=-(sin(p)+cos(p)+exp(p)+p^2)*x+u'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw); p=r.parameterSymbols(1);
            equalSym(test,r.A,-sin(p)-cos(p)-exp(p)-p^2);
            test.verifyTrue(isAlways(imag(p)==0,'Unknown','false'));
            test.verifyFalse(isAlways(p>0,'Unknown','false'));
            test.verifyFalse(isAlways(p<0,'Unknown','false'));
            % Keep the independent reference exact: numeric sin(-1)/cos(-1)
            % round before conversion to sym and cannot satisfy an identity.
            reference=-sin(sym(-1))-cos(sym(-1))-exp(sym(-1))-1;
            test.verifyTrue(isAlways(subs(r.A,p,-1)==reference,'Unknown','false'));
        end
        function laplaceVariableCollision(test)
            raw=fixture({'x'},{'u'},struct('s','symbolic','s_laplace',2), ...
                {'der(x)=-s*x+s_laplace*u'},struct('s_laplace_2','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw);
            test.verifyEqual(char(r.laplaceVariable),'s_laplace_3');
            equalSym(test,r.transferMatrix,sym('s_laplace','real')/(r.laplaceVariable+sym('s','real')));
            test.verifyFalse(isAlways(imag(r.laplaceVariable)==0,'Unknown','false'));
        end
        function resolventConditionSurvivesUnobservableCancellation(test)
            raw=fixture({'x','z'},{'u'},struct('a','symbolic'), ...
                {'der(x)=-x+u','der(z)=-a*z'},struct('y','x'));
            r=fm.analysis.deriveSymbolicTransferFunction(raw); a=sym('a','real');
            equalSym(test,r.transferMatrix,1/(r.laplaceVariable+1));
            test.verifyFalse(isAlways(subs(r.resolventCondition,r.laplaceVariable,-a),'Unknown','false'));
        end
        function noInputsReject(test)
            raw=fixture({'x'},{},struct(),{'der(x)=-x'},struct('y','x'));
            test.verifyError(@()fm.analysis.deriveSymbolicTransferFunction(raw),'fm:symbolic:NoInputs');
        end
    end
end
function raw=fixture(states,inputs,parameters,equations,outputs)
initial=struct();
for k=1:numel(states), initial.(states{k})=0; end
raw=struct('name','symbolic_fixture','states',{states},'inputs',{inputs}, ...
    'parameters',parameters,'initial',initial,'equations',{equations},'outputs',outputs);
end
function equalSym(test,actual,expected)
residual=simplify(actual-sym(expected));
test.verifyTrue(all(isAlways(residual(:)==0,'Unknown','false')));
end
