classdef TestUI < matlab.unittest.TestCase
    methods (Test)
        function exampleLoadingPreservesData(testCase)
            app = launch('off');
            cleanup = onCleanup(@()delete(app));
            examples = {'first_order','mass_spring_damper','coupled_states','nonlinear_equilibrium','symbolic_mass_spring'};
            for k = 1:numel(examples)
                app.loadExample(examples{k});
                testCase.verifyEqual(app.ExampleDropdown.Value, examples{k});
                raw = app.getRaw();
                expected = jsondecode(fileread(fullfile(app.Root,'examples',[examples{k} '.json'])));
                testCase.verifyEqual(raw.name, expected.name);
                testCase.verifyEqual(raw.states(:), cellstr(string(expected.states(:))));
                testCase.verifyEqual(raw.inputs(:), cellstr(string(expected.inputs(:))));
                testCase.verifyEqual(raw.parameters, expected.parameters);
                testCase.verifyEqual(raw.initial, expected.initial);
                testCase.verifyEqual(raw.outputs, expected.outputs);
                testCase.verifyEqual(raw.equations(:), cellstr(string(expected.equations(:))));
            end
        end
        function checksAndAnalysisUseCurrentInputs(testCase)
            app = launch('off');
            cleanup = onCleanup(@()delete(app));
            spec = app.perform('check');
            testCase.verifyEqual(spec.stateNames, {'x'});
            result = app.perform('analyze');
            testCase.verifyEqual(evalfr(result.system,2), 3/4, 'AbsTol',1e-10);
            app.ParametersArea.Value = {'{"a":2,"b":6}'};
            result = app.perform('analyze');
            testCase.verifyEqual(evalfr(result.system,2), 6/4, 'AbsTol',1e-10);
        end
        function errorsPreserveInputAndReleaseButtons(testCase)
            app = launch('off');
            cleanup = onCleanup(@()delete(app));
            bad = {'der(x) = unknown_symbol + u'};
            app.EquationsArea.Value = bad;
            app.invoke('check');
            testCase.verifyEqual(app.EquationsArea.Value(:),bad(:));
            testCase.verifyFalse(app.Busy);
            testCase.verifyEqual(app.StatusLabel.Text,'执行失败：检查公式');
            for k = 1:numel(app.Buttons)
                testCase.verifyEqual(char(app.Buttons{k}.Enable),'on');
            end
        end
        function rejectsEmptyVariableEntries(testCase)
            app = launch('off');
            cleanup = onCleanup(@()delete(app));
            app.StatesField.Value = 'x,,v';
            testCase.verifyError(@()app.getRaw(),'fm:UIIdentifier');
        end
    end
end
