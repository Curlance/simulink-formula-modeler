classdef TestSimulation < matlab.unittest.TestCase
    % Reference dynamics are hand-authored, independent of the formula AST.
    methods (Test)
        function runtimeComparisonMatchesAnalyticResponse(testCase)
            raw=TestSimulation.fixture('first_order');
            parent=fullfile(fileparts(fileparts(mfilename('fullpath'))),'artifacts','simulation');
            if ~isfolder(parent), mkdir(parent); end
            folder=tempname(parent); [~,token]=fileparts(folder); raw.name=['fm_compare_' token];
            spec=fm.core.validateSpec(raw);
            path=fm.simulink.generateModel(spec,folder);
            result=fm.validation.compareSimulation(spec,path,struct('stopTime',1));
            testCase.verifyTrue(result.passed);
            channel=result.channels(1);
            testCase.verifyEqual(channel.model,1.5*(1-exp(-2*channel.time)),'AbsTol',1e-6);
            testCase.verifyError(@()fm.validation.compareSimulation(spec,path,struct('stopTime',-1)),'fm:SimulationOptions');
        end
        function firstOrderNonzeroInitial(testCase)
            raw=TestSimulation.fixture('first_order');
            raw.initial.x=0.4;
            [outputs,spec]=TestSimulation.simulateFixture(raw,1);
            ts=outputs.getElement(1).Values;
            expected=1.5+(0.4-1.5)*exp(-2*ts.Time);
            testCase.verifyEqual(spec.outputNames,{'y'});
            testCase.verifyLessThan(max(abs(double(ts.Data(:))-expected(:))),1e-6);
        end
        function massSpringMatchesIndependentODE(testCase)
            raw=TestSimulation.fixture('mass_spring_damper');
            raw.initial.x=0.2; raw.initial.v=-0.1;
            [outputs,spec]=TestSimulation.simulateFixture(raw,1);
            reference=ode45(@(~,z)[z(2);(1-z(2)-3*z(1))/2],[0 2],[0.2;-0.1], ...
                odeset('RelTol',1e-11,'AbsTol',1e-13));
            for k=1:numel(spec.outputNames)
                ts=outputs.getElement(k).Values;
                values=deval(reference,ts.Time);
                if strcmp(spec.outputNames{k},'position'), row=1;
                elseif strcmp(spec.outputNames{k},'velocity'), row=2;
                else, error('fm:TestOutput','Unexpected output name.'); end
                expected=values(row,:)';
                testCase.verifyLessThan(max(abs(double(ts.Data(:))-expected)),1e-6);
            end
        end
        function coupledInputsPreservePortOrder(testCase)
            raw=TestSimulation.fixture('coupled_states');
            [outputs,spec]=TestSimulation.simulateFixture(raw,[1 2]);
            reference=ode45(@(~,z)[-2*z(1)+1;z(1)-3*z(2)+2],[0 2],[0;0], ...
                odeset('RelTol',1e-11,'AbsTol',1e-13));
            for k=1:numel(spec.outputNames)
                ts=outputs.getElement(k).Values;
                values=deval(reference,ts.Time);
                if strcmp(spec.outputNames{k},'y1'), row=1;
                elseif strcmp(spec.outputNames{k},'y2'), row=2;
                else, error('fm:TestOutput','Unexpected output name.'); end
                expected=values(row,:)';
                testCase.verifyLessThan(max(abs(double(ts.Data(:))-expected)),1e-6);
            end
        end
    end
    methods (Static, Access=private)
        function raw=fixture(name)
            root=fileparts(fileparts(mfilename('fullpath')));
            raw=jsondecode(fileread(fullfile(root,'examples',[name '.json'])));
        end
        function [outputs,spec]=simulateFixture(raw,inputValues)
            root=fileparts(fileparts(mfilename('fullpath')));
            parent=fullfile(root,'artifacts','simulation');
            if ~isfolder(parent), mkdir(parent); end
            [~,token]=fileparts(tempname(parent));
            raw.name=['fm_sim_' token];
            spec=fm.core.validateSpec(raw);
            folder=fullfile(parent,raw.name);
            path=fm.simulink.generateModel(spec,folder);
            load_system(path);
            cleanup=onCleanup(@()close_system(spec.name,0));
            assert(numel(inputValues)==numel(spec.inputNames),'fm:TestInput','Input count mismatch.');
            t=(0:0.01:2)';
            ds=Simulink.SimulationData.Dataset;
            for k=1:numel(inputValues)
                ds=ds.addElement(timeseries(inputValues(k)*ones(size(t)),t),spec.inputNames{k});
            end
            in=Simulink.SimulationInput(spec.name);
            in=in.setExternalInput(ds);
            in=in.setModelParameter('StopTime','2','Solver','ode45', ...
                'RelTol','1e-9','AbsTol','1e-11','MaxStep','0.01', ...
                'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset');
            out=sim(in);
            outputs=out.get('yout');
            assert(isa(outputs,'Simulink.SimulationData.Dataset'), ...
                'fm:TestOutput','Expected Dataset output.');
            assert(outputs.numElements==numel(spec.outputNames), ...
                'fm:TestOutput','Output count mismatch.');
            save(fullfile(folder,'simulation.mat'),'out','spec');
        end
    end
end
