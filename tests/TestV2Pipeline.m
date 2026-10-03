classdef TestV2Pipeline < matlab.unittest.TestCase
    % Parent-owned integration, independent of module-specific fixtures.
    methods (Test)
        function nestedModelToWorkingPointAndPerturbation(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'tests'));
            folder=fullfile(root,'artifacts','v2','pipeline');
            if ~isfolder(folder), mkdir(folder); end
            path=createComplexDemo(tempname(folder));
            spec=fm.simulink.extractEquations(path);
            testCase.assertNumElements(spec.stateNames,1);
            testCase.assertNumElements(spec.inputNames,1);
            testCase.assertNumElements(spec.outputNames,1);
            point=struct('states',struct(),'inputs',struct());
            point.states.(spec.stateNames{1})=1;
            point.inputs.(spec.inputNames{1})=1;
            r=fm.analysis.linearizeAt(spec,point);
            testCase.verifyEqual(r.A,-3,'AbsTol',1e-12);
            testCase.verifyEqual(r.B,1,'AbsTol',1e-12);
            testCase.verifyEqual(r.C,2,'AbsTol',1e-12);
            testCase.verifyEqual(r.D,0,'AbsTol',1e-12);
            testCase.verifyEqual(r.f0,0,'AbsTol',1e-12);
            testCase.verifyEqual(r.y0,1,'AbsTol',1e-12);
            testCase.verifyTrue(r.isEquilibrium);
            testCase.verifyEqual(evalfr(r.transferSystem,2),2/5,'AbsTol',1e-12);
            % Native model and independently derived small-signal response.
            epsilons=[0.04 0.02]; maxErrors=zeros(size(epsilons));
            for j=1:numel(epsilons)
                e=epsilons(j);
                simulation=fm.validation.compareSimulation(spec,path, ...
                    struct('stopTime',1,'inputValues',1+e,'tolerance',1e-6));
                testCase.verifyTrue(simulation.passed);
                channel=simulation.channels(1);
                linearOutput=1+(2*e/3)*(1-exp(-3*channel.time));
                maxErrors(j)=max(abs(channel.model-linearOutput));
            end
            testCase.verifyGreaterThan(maxErrors(1),1e-8);
            testCase.verifyGreaterThan(maxErrors(1)/maxErrors(2),3);
            testCase.verifyLessThan(maxErrors(1)/maxErrors(2),5);
            save(fullfile(fileparts(path),'perturbation-errors.mat'),'maxErrors','epsilons');
        end
        function symbolicFormulaSubstitutionMatchesNumericalAnalysis(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            raw=jsondecode(fileread(fullfile(root,'examples','symbolic_mass_spring.json')));
            symbolic=fm.analysis.deriveSymbolicTransferFunction(raw);
            raw.parameters=struct('m',2,'c',1,'k',3);
            numeric=fm.analysis.deriveTransferFunction(fm.core.validateSpec(raw));
            m=sym('m','real'); c=sym('c','real'); k=sym('k','real');
            for frequency=[0 2 1+2i]
                value=double(subs(symbolic.transferMatrix, ...
                    [m c k symbolic.laplaceVariable],[2 1 3 frequency]));
                testCase.verifyEqual(value,evalfr(numeric.system,frequency),'AbsTol',1e-10);
            end
        end
    end
end
