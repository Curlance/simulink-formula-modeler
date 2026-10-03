classdef TestInputOutput < matlab.unittest.TestCase
    methods (Test)
        function firstOrderAndInitialState(test)
            spec = fixture({'x'},{'u'},struct('a',2,'b',3), ...
                {'der(x)=-a*x+b*u'},struct('y','x'));
            spec.initial.x = 17;
            r = fm.analysis.deriveTransferFunction(spec);
            test.verifyEqual(r.A,-2); test.verifyEqual(r.B,3);
            test.verifyEqual(r.C,1); test.verifyEqual(r.D,0);
            test.verifyEqual(evalfr(r.system,4),0.5,'AbsTol',1e-12);
            test.verifyEqual(trim(r.numerator{1}),3,'AbsTol',1e-12);
            test.verifyEqual(trim(r.denominator{1}),[1 2],'AbsTol',1e-12);
            test.verifyTrue(contains(r.conditions,'zero initial conditions'));
            test.verifyTrue(contains(r.text,'y <- u'));
            test.verifyTrue(contains(r.latex,'\frac'));
            spec.initial.x = -23;
            r2 = fm.analysis.deriveTransferFunction(spec);
            test.verifyEqual(r2.numerator,r.numerator);
            test.verifyEqual(r2.denominator,r.denominator);
        end
        function massSpringDamper(test)
            spec = fixture({'x','v'},{'F'},struct('m',2,'c',3,'k',4), ...
                {'der(v)=(F-c*v-k*x)/m','der(x)=v'},struct('position','x'));
            r = fm.analysis.deriveTransferFunction(spec);
            test.verifyEqual(r.A,[0 1;-2 -1.5]);
            test.verifyEqual(r.B,[0;0.5]);
            test.verifyEqual(r.C,[1 0]); test.verifyEqual(r.D,0);
            for s = [0 1 2+3i]
                test.verifyEqual(evalfr(r.system,s),1/(2*s^2+3*s+4),'AbsTol',1e-12);
            end
            test.verifyEqual(trim(r.numerator{1}),0.5,'AbsTol',1e-12);
            test.verifyEqual(trim(r.denominator{1}),[1 1.5 2],'AbsTol',1e-12);
        end
        function mimoAndIdentifierOrder(test)
            outputs = struct(); outputs.z_out = '3*z+2*a+q'; outputs.a_out = 'z-4*a+5*b';
            spec = fixture({'z','a'},{'q','b'},struct(), ...
                {'der(a)=-2*a+4*b','der(z)=-z+2*q+b'},outputs);
            r = fm.analysis.deriveTransferFunction(spec);
            test.verifyEqual(r.stateNames,{'z','a'});
            test.verifyEqual(r.inputNames,{'q','b'});
            test.verifyEqual(r.outputNames,{'z_out','a_out'});
            test.verifyEqual(r.A,[-1 0;0 -2]); test.verifyEqual(r.B,[2 1;0 4]);
            test.verifyEqual(r.C,[3 2;1 -4]); test.verifyEqual(r.D,[1 0;0 5]);
            for s = [0 3 1+2i]
                expected = [6/(s+1)+1,3/(s+1)+8/(s+2);2/(s+1),1/(s+1)-16/(s+2)+5];
                test.verifyEqual(evalfr(r.system,s),expected,'AbsTol',1e-11);
                for iy=1:2
                    for iu=1:2
                        channel = r.channels(iy,iu);
                        test.verifyEqual(polyval(channel.numerator,s)/polyval(channel.denominator,s),expected(iy,iu),'AbsTol',1e-11);
                    end
                end
            end
            test.verifyEqual(r.channels(2,1).outputName,'a_out');
            test.verifyEqual(r.channels(2,1).inputName,'q');
            test.verifyTrue(contains(r.latex,'z\_out'));
        end
        function pureDirectFeedthrough(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x'},struct('y','7*u'));
            r = fm.analysis.deriveTransferFunction(spec);
            test.verifyEqual(r.D,7); test.verifyEqual(r.C,0);
            test.verifyEqual(evalfr(r.system,2),7,'AbsTol',1e-12);
        end
        function parameterOnlyOperations(test)
            spec = fixture({'x'},{'u'},struct('p',2), ...
                {'der(x)=-(sin(0)+cos(0)+exp(0)+p^2/2)*x+(p-1)*u'},struct('y','x/(p+2)'));
            r = fm.analysis.extractStateSpace(spec);
            test.verifyEqual(r.A,-4); test.verifyEqual(r.B,1);
            test.verifyEqual(r.C,0.25);
        end
        function structuralCancellationAndTinyCoefficients(test)
            spec = fixture({'x'},{'u'},struct(), ...
                {'der(x)=(x-x)*u+1e-20*x+u'},struct('y','x^1+(u^0-1)'));
            r = fm.analysis.extractStateSpace(spec);
            test.verifyEqual(r.A,1e-20); test.verifyEqual(r.B,1);
        end
        function nonlinearRejection(test)
            expressions = {'x*x+u','x*u','x/(u+1)','sin(x)+u','cos(u)+x', ...
                'exp(x)+u','x^2+u','2^u+x','x^3-x+u'};
            for k=1:numel(expressions)
                spec = fixture({'x'},{'u'},struct(),{['der(x)=' expressions{k}]},struct('y','x'));
                test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:Nonlinear');
            end
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x*u'));
            test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:Nonlinear');
        end
        function nonzeroOffsets(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u+1e-20'},struct('y','x'));
            test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:AffineOffset');
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x+1'));
            test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:AffineOffset');
        end
        function invalidConstantArithmetic(test)
            % Hand-authored schema isolates analysis errors even if core rejects earlier.
            spec = fixture({'x'},{'u'},struct('p',2),{'der(x)=-x+u'},struct('y','x'));
            expressions = {'x/(p-p)','(1/0)*x','0^(-1)*x'};
            for k=1:numel(expressions)
                spec.derivatives{1} = fm.parser.parseExpression(expressions{k});
                test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:DivisionByZero');
            end
            for expression = {'exp(1000)*x','(-1)^0.5*x'}
                spec.derivatives{1} = fm.parser.parseExpression(expression{1});
                test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:NonfiniteResult');
            end
        end
        function rejectTimeSymbolAndInputless(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x'));
            spec.derivatives{1} = fm.parser.parseExpression('t*x+u');
            test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:UnknownSymbol');
            spec = fixture({'x'},{},struct(),{'der(x)=-x'},struct('y','x'));
            test.verifyError(@() fm.analysis.extractStateSpace(spec),'fm:analysis:NoInputs');
            test.verifyError(@() fm.analysis.deriveTransferFunction(spec),'fm:analysis:NoInputs');
        end
    end
end

function spec = fixture(states,inputs,parameters,equations,outputs)
initial = struct();
for k=1:numel(states), initial.(states{k}) = 0; end
raw = struct('name','analysis_fixture','states',{states},'inputs',{inputs}, ...
    'parameters',parameters,'initial',initial,'equations',{equations},'outputs',outputs);
spec = fm.core.validateSpec(raw);
end

function coefficients = trim(coefficients)
% Remove only exact leading zero padding from MATLAB's tf representation.
first = find(coefficients ~= 0,1);
if isempty(first), coefficients = 0; else, coefficients = coefficients(first:end); end
end
