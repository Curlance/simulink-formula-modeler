classdef TestLinearization < matlab.unittest.TestCase
    % Independent numeric/analytic references; no finite-difference classifier.
    methods (Test)
        function manualMimoJacobiansAndOrdering(test)
            outputs = struct('product','z*a+q^2','mixed','exp(a)+sin(z)+q*b');
            spec = fixture({'z','a'},{'q','b'},struct(), ...
                {'der(a)=a^2+z*b-3','der(z)=-z^2+q'},outputs);
            point = struct('states',struct('a',-1,'z',2),'inputs',struct('b',1,'q',4));
            r = fm.analysis.linearizeAt(spec,point);
            test.verifyEqual(r.A,[-4 0;1 -2]);
            test.verifyEqual(r.B,[1 0;0 2]);
            test.verifyEqual(r.C,[-1 2;cos(2) exp(-1)],'AbsTol',1e-14);
            test.verifyEqual(r.D,[8 0;1 4]);
            test.verifyEqual(r.f0,[0;0]);
            test.verifyEqual(r.y0,[14;exp(-1)+sin(2)+4],'AbsTol',1e-14);
            test.verifyEqual(r.x0,[2;-1]); test.verifyEqual(r.u0,[4;1]);
            test.verifyEqual(r.stateNames,{'z','a'});
            test.verifyEqual(r.inputNames,{'q','b'});
            test.verifyEqual(r.outputNames,{'product','mixed'});
            test.verifyTrue(contains(r.latex,'\begin{bmatrix}-4 & 0 \\ 1 & -2\end{bmatrix}'));
            test.verifyClass(r.system,'ss'); test.verifyClass(r.transferSystem,'tf');
            for s = [0 2 1+3i]
                % Independent hand-computed triangular resolvent.
                h = [1/(s+4) 0;1/((s+2)*(s+4)) 2/(s+2)];
                expected = [-1 2;cos(2) exp(-1)]*h+[8 0;1 4];
                test.verifyEqual(evalfr(r.transferSystem,s),expected,'AbsTol',1e-11);
            end
        end

        function nonzeroPendulumEquilibrium(test)
            spec = fixture({'theta','omega'},{'torque'},struct('k',9.81,'d',0.4), ...
                {'der(theta)=omega','der(omega)=-k*sin(theta)-d*omega+torque'}, ...
                struct('angle','theta','sensor','sin(theta)+torque^2'));
            point = struct('states',struct('theta',pi/6,'omega',0), ...
                'inputs',struct('torque',9.81/2));
            r = fm.analysis.linearizeAt(spec,point);
            test.verifyTrue(r.isEquilibrium);
            test.verifyLessThan(r.equilibriumResidual,1e-12);
            test.verifyEqual(r.A,[0 1;-9.81*sqrt(3)/2 -0.4],'AbsTol',1e-13);
            test.verifyEqual(r.B,[0;1]);
            test.verifyEqual(r.C,[1 0;sqrt(3)/2 0],'AbsTol',1e-14);
            test.verifyEqual(r.D,[0;9.81]);
            for s = [0 2+3i]
                test.verifyEqual(evalfr(r.transferSystem(1,1),s), ...
                    1/(s^2+0.4*s+9.81*sqrt(3)/2),'AbsTol',1e-12);
            end
        end

        function completeAffineResidualAndDefaultRejection(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x^2+u'},struct('y','x^2+u^2'));
            point = pointAt(2,1);
            test.verifyError(@() fm.analysis.linearizeAt(spec,point),'fm:linearize:NotEquilibrium');
            try
                fm.analysis.linearizeAt(spec,point);
            catch cause
                test.verifyTrue(contains(cause.message,'f0 = -3'));
                test.verifyTrue(contains(cause.message,'||f0||_inf = 3'));
            end
            r = fm.analysis.linearizeAt(spec,point,struct('requireEquilibrium',false));
            test.verifyFalse(r.isEquilibrium); test.verifyEmpty(r.transferSystem);
            test.verifyEqual(r.A,-4); test.verifyEqual(r.B,1);
            test.verifyEqual(r.C,4); test.verifyEqual(r.D,2);
            test.verifyEqual(r.f0,-3); test.verifyEqual(r.y0,5);
            test.verifyEqual(r.equilibriumResidual,3);
            test.verifyEqual(r.system.UserData.f0,-3);
            test.verifyTrue(contains(r.text,'非平衡工作点'));
            test.verifyTrue(contains(r.text,'不是平衡点传递函数'));
            test.verifyTrue(contains(r.text,'delta_x_dot = f0 + A*delta_x + B*delta_u'));
            test.verifyTrue(contains(r.text,'x=2'));
            test.verifyTrue(contains(r.text,'u=1'));
            test.verifyFalse(contains(r.latex,'G(s)'));
            for h = [0.1 0.05 0.025]
                dx = h; du = -0.3*h;
                actual = [-(2+dx)^2+1+du;(2+dx)^2+(1+du)^2];
                affine = [r.f0;r.y0]+[r.A r.B;r.C r.D]*[dx;du];
                test.verifyEqual(actual-affine,[-dx^2;dx^2+du^2],'AbsTol',2e-14);
            end
            test.verifyEqual(r.f0+r.A*0+r.B*0,-3);
            writeUtf8(fullfile(evidenceFolder(),'affine-report.txt'),r.text);
            writeUtf8(fullfile(evidenceFolder(),'affine-report.tex'),r.latex);
        end

        function toleranceDoesNotEraseResidual(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x+3'));
            point = pointAt(0,5e-9);
            r = fm.analysis.linearizeAt(spec,point);
            test.verifyTrue(r.isEquilibrium); test.verifyEqual(r.f0,5e-9);
            test.verifyEqual(r.equilibriumResidual,5e-9);
            test.verifyEqual(r.y0,3); test.verifyClass(r.transferSystem,'tf');
            test.verifyTrue(contains(r.conditions,'忽略容差内残差'));
            test.verifyError(@() fm.analysis.linearizeAt(spec,point, ...
                struct('equilibriumTolerance',0)),'fm:linearize:NotEquilibrium');
            r = fm.analysis.linearizeAt(spec,pointAt(0,0),struct('equilibriumTolerance',0));
            test.verifyTrue(r.isEquilibrium);
        end

        function independentTaylorRemainderScaling(test)
            spec = fixture({'x'},{'u'},struct(), ...
                {'der(x)=-x^2+u+sin(x)-sin(2)'}, ...
                struct('y','exp(x)+x*u+cos(u)'));
            r = fm.analysis.linearizeAt(spec,pointAt(2,4));
            epsilons = [0.08 0.04 0.02 0.01]; errors = zeros(2,numel(epsilons));
            for k = 1:numel(epsilons)
                dx = epsilons(k); du = -0.6*epsilons(k);
                % Direct independent MATLAB function, no AST evaluator.
                actual = [-(2+dx)^2+(4+du)+sin(2+dx)-sin(2); ...
                    exp(2+dx)+(2+dx)*(4+du)+cos(4+du)];
                predicted = [r.f0;r.y0]+[r.A r.B;r.C r.D]*[dx;du];
                errors(:,k) = abs(actual-predicted);
            end
            ratios = errors(:,1:end-1)./errors(:,2:end);
            test.verifyGreaterThan(ratios,3.7*ones(size(ratios)));
            test.verifyLessThan(ratios,4.4*ones(size(ratios)));
            saveEvidence('taylor-scaling.mat',struct('epsilons',epsilons,'errors',errors,'ratios',ratios));
        end

        function nonlinearOdeSmallSignalResponse(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x^2+u'},struct('y','x^2+u^2'));
            spec.initial.x = -99; % The explicit operating point governs this API.
            r = fm.analysis.linearizeAt(spec,pointAt(2,4));
            t = (0:0.01:1).'; epsilons = [0.1 0.05 0.025]; errors = zeros(1,3);
            odeOptions = odeset('RelTol',1e-11,'AbsTol',1e-12);
            for k = 1:numel(epsilons)
                du = epsilons(k);
                [~,x] = ode45(@(~,x) -x.^2+4+du,t,2,odeOptions);
                actualY = x.^2+(4+du)^2;
                linearY = lsim(r.transferSystem,du*ones(size(t)),t);
                % Independent analytic zero-initial-perturbation solution.
                reference = du*(1-exp(-4*t))+8*du;
                test.verifyEqual(linearY,reference,'AbsTol',1e-11);
                errors(k) = max(abs(actualY-r.y0-linearY));
            end
            ratios = errors(1:end-1)./errors(2:end);
            test.verifyGreaterThan(ratios,[3.8 3.8]);
            test.verifyLessThan(ratios,[4.2 4.2]);
            test.verifyTrue(contains(r.conditions,'delta_x(0)=0'));
            test.verifyTrue(contains(r.latex,'\delta x(0)=0'));
            saveEvidence('ode-small-signal.mat',struct('epsilons',epsilons,'errors',errors,'ratios',ratios));
        end

        function analyticVariablePowersAndQuotient(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=x^u'},struct('y','x/(u+1)+2^u'));
            r = fm.analysis.linearizeAt(spec,pointAt(2,3),struct('requireEquilibrium',false));
            test.verifyEqual(r.f0,8); test.verifyEqual(r.A,12);
            test.verifyEqual(r.B,8*log(2),'AbsTol',1e-14);
            test.verifyEqual(r.C,1/4);
            test.verifyEqual(r.D,-1/8+8*log(2),'AbsTol',1e-14);
            test.verifyTrue(contains(r.conditions,'x > 0'));
            test.verifyTrue(contains(r.conditions,'~= 0'));
        end

        function negativeBasesAndParameterIntegerPowers(test)
            spec = fixture({'x'},{'u'},struct('p',3),{'der(x)=x^p+u'}, ...
                struct('y','x^(-2)+x^0'));
            r = fm.analysis.linearizeAt(spec,pointAt(-2,8));
            test.verifyEqual(r.A,12); test.verifyEqual(r.B,1);
            test.verifyEqual(r.C,1/4); test.verifyEqual(r.D,0);
            test.verifyEqual(r.y0,1.25);
            test.verifyTrue(contains(r.conditions,'x ~= 0'));
        end

        function zeroBaseIntegerPowerConventions(test)
            spec = fixture({'x'},{'u'},struct(), ...
                {'der(x)=x^0+x^1+x^2+x^3-1+u'},struct('y','x^2'));
            r = fm.analysis.linearizeAt(spec,pointAt(0,0));
            test.verifyEqual(r.A,1); test.verifyEqual(r.B,1);
            test.verifyEqual(r.C,0); test.verifyEqual(r.y0,0);
        end

        function positiveFractionalPowers(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=x^0.5+u'},struct('y','x^(-0.5)'));
            r = fm.analysis.linearizeAt(spec,pointAt(4,-2));
            test.verifyEqual(r.A,1/4); test.verifyEqual(r.C,-1/16);
            test.verifyEqual(r.y0,1/2);
        end

        function constantZeroBaseAndTinyConstantArithmetic(test)
            spec = fixture({'x'},{'u'},struct(), ...
                {'der(x)=-x+0^u'},struct('y','(1e-300)^0.5+x/(1e-200)'));
            r = fm.analysis.linearizeAt(spec,pointAt(0,2));
            test.verifyEqual(r.A,-1); test.verifyEqual(r.B,0);
            test.verifyEqual(r.y0,1e-150,'RelTol',1e-14);
            test.verifyEqual(r.C,1e200,'RelTol',1e-14);
            test.verifyEqual(r.D,0);
        end

        function singularDivisionsNotCancelled(test)
            for expression = {'1/x','x/x','0*(1/x)','1/(u-u)'}
                spec = fixture({'x'},{'u'},struct(),{['der(x)=' expression{1}]},struct('y','x'));
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(0,0), ...
                    struct('requireEquilibrium',false)),'fm:linearize:Singular');
            end
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x'},struct('y','1/u'));
            test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(0,0)),'fm:linearize:Singular');
        end

        function singularAndNonrealPowers(test)
            for expression = {'x^(-1)','x^(-2)','0^u'}
                spec = fixture({'x'},{'u'},struct(),{['der(x)=' expression{1}]},struct('y','x'));
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(0,-1)), ...
                    'fm:linearize:Singular');
            end
            for expression = {'x^0.5','x^1.5','(x^2)^0.5','x^(2+u^2)'}
                spec = fixture({'x'},{'u'},struct(),{['der(x)=' expression{1}]},struct('y','x'));
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(0,0)), ...
                    'fm:linearize:Nondifferentiable');
            end
            for expression = {'x^0.5','x^(1/3)','x^u','x^(2+u^2)'}
                spec = fixture({'x'},{'u'},struct(),{['der(x)=' expression{1}]},struct('y','x'));
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(-2,0)), ...
                    'fm:linearize:Domain');
            end
        end

        function nonfiniteValuesAndDerivatives(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=exp(x)'},struct('y','x'));
            test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(1000,0)),'fm:linearize:Nonfinite');
            spec = fixture({'x'},{'u'},struct(),{'der(x)=x^(-1)'},struct('y','x'));
            % Finite function (1e200) but derivative overflows.
            test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(1e-200,0)),'fm:linearize:Nonfinite');
        end

        function incompleteAndExtraWorkingPointNames(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x'));
            points = {struct('states',struct(),'inputs',struct('u',0)), ...
                struct('states',struct('x',0),'inputs',struct()), ...
                struct('states',struct('x',0,'other',0),'inputs',struct('u',0)), ...
                struct('states',struct('x',0),'inputs',struct('u',0,'other',0))};
            for k = 1:numel(points)
                test.verifyError(@() fm.analysis.linearizeAt(spec,points{k}),'fm:linearize:OperatingPointNames');
            end
            point = pointAt(0,0); point.extra = 0;
            test.verifyError(@() fm.analysis.linearizeAt(spec,point),'fm:linearize:OperatingPoint');
            test.verifyError(@() fm.analysis.linearizeAt(spec,struct('states',struct('x',0))), ...
                'fm:linearize:OperatingPoint');
        end

        function invalidPointValueTypes(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x'));
            invalid = {NaN,Inf,1i,[0 1],[],'0',true,{0},struct()};
            for k = 1:numel(invalid)
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(invalid{k},0)), ...
                    'fm:linearize:OperatingPointValue');
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(0,invalid{k})), ...
                    'fm:linearize:OperatingPointValue');
            end
            point = pointAt(0,0); point.states = [];
            test.verifyError(@() fm.analysis.linearizeAt(spec,point),'fm:linearize:OperatingPoint');
        end

        function invalidOptions(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x+u'},struct('y','x'));
            invalid = {[],struct('requireEquilibrium',1),struct('requireEquilibrium','false'), ...
                struct('requireEquilibrium',[true false]),struct('other',1), ...
                struct('equilibriumTolerance',-1),struct('equilibriumTolerance',NaN), ...
                struct('equilibriumTolerance',Inf),struct('equilibriumTolerance',1i), ...
                struct('equilibriumTolerance',[1 2]),struct('equilibriumTolerance','1e-8')};
            for k = 1:numel(invalid)
                test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(0,0),invalid{k}), ...
                    'fm:linearize:Options');
            end
        end

        function rawSpecRevalidationAndNumericParameters(test)
            spec = fixture({'x'},{'u'},struct('p',2),{'der(x)=-p*x+u'},struct('y','x'));
            raw = rmfield(spec,{'schemaVersion','stateNames','inputNames','outputNames', ...
                'derivatives','outputExpressions'});
            r = fm.analysis.linearizeAt(raw,pointAt(1,2)); test.verifyEqual(r.A,-2);
            spec.derivatives{1} = fm.parser.parseExpression('100*x');
            r = fm.analysis.linearizeAt(spec,pointAt(1,2)); test.verifyEqual(r.A,-2);
            spec.parameters.p = 'symbolic';
            test.verifyError(@() fm.analysis.linearizeAt(spec,pointAt(1,2)),'fm:NumericValue');
        end

        function autonomousSystemAndEmptyInputMap(test)
            spec = fixture({'x'},{},struct(),{'der(x)=-(x-2)^3-(x-2)'},struct('y','x^2'));
            point = struct('states',struct('x',2),'inputs',struct());
            r = fm.analysis.linearizeAt(spec,point);
            test.verifyEqual(r.A,-1); test.verifyEqual(r.C,4);
            test.verifySize(r.B,[1 0]); test.verifySize(r.D,[1 0]);
            test.verifySize(r.u0,[0 1]); test.verifyClass(r.system,'ss');
            test.verifyClass(r.transferSystem,'tf');
            point.inputs = [];
            test.verifyError(@() fm.analysis.linearizeAt(spec,point),'fm:linearize:OperatingPoint');
        end

        function chineseReportAndRequiredFields(test)
            spec = fixture({'x'},{'u'},struct(),{'der(x)=-x^2+u'},struct('y','x*u'));
            r = fm.analysis.linearizeAt(spec,pointAt(2,4));
            expected = {'A','B','C','D','f0','y0','x0','u0','equilibriumResidual','isEquilibrium', ...
                'stateNames','inputNames','outputNames','system','transferSystem','text','latex','conditions'};
            test.verifyTrue(all(isfield(r,expected)));
            for phrase = {'工作点','平衡残差','局部近似','delta_x','delta_u','delta_y','f0','y0','并非全局等价'}
                test.verifyTrue(contains(r.text,phrase{1}),phrase{1});
            end
            test.verifyTrue(contains(r.latex,'\begin{bmatrix}'));
            test.verifyTrue(contains(r.latex,'\delta\dot{x}&=f_0'));
            test.verifyTrue(contains(r.latex,'\|f_0\|_\infty'));
            test.verifyTrue(contains(r.latex,[' \\' newline]));
            test.verifyFalse(contains(r.latex,[' \' newline]));
            test.verifyEqual(r.system.StateName,{'x'});
            test.verifyEqual(r.system.InputName,{'u'});
            test.verifyEqual(r.system.OutputName,{'y'});
            saveEvidence('example-result.mat',struct('result',r));
            folder = evidenceFolder();
            writeUtf8(fullfile(folder,'example-report.txt'),r.text);
            writeUtf8(fullfile(folder,'example-report.tex'),r.latex);
        end
    end
end

function spec = fixture(states,inputs,parameters,equations,outputs)
initial = struct();
for k = 1:numel(states), initial.(states{k}) = 0; end
raw = struct('name','linearization_fixture','states',{states},'inputs',{inputs}, ...
    'parameters',parameters,'initial',initial,'equations',{equations},'outputs',outputs);
spec = fm.core.validateSpec(raw);
end

function point = pointAt(x,u)
point = struct('states',struct(),'inputs',struct());
point.states.x = x; point.inputs.u = u;
end

function folder = evidenceFolder()
folder = fullfile(fileparts(fileparts(mfilename('fullpath'))),'artifacts','v2','linearize');
if ~isfolder(folder), mkdir(folder); end
end

function saveEvidence(name,values)
save(fullfile(evidenceFolder(),name),'-struct','values');
end

function writeUtf8(path,text)
fid = fopen(path,'w','n','UTF-8');
assert(fid >= 0,'fm:linearize:EvidenceWrite','Cannot write test evidence.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',text);
end
