classdef TestUIV2 < matlab.unittest.TestCase
    methods (Test)
        function chineseLabelsAndModeControls(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            t.verifyEqual(app.Figure.Name,'公式与 Simulink 建模工具');
            t.verifyEqual(char(app.SymbolicField.Enable),'off');
            t.verifyEqual(char(app.OperatingStatesArea.Enable),'off');
            app.AnalysisMode.Value='symbolic'; app.updateMode();
            t.verifyEqual(char(app.SymbolicField.Enable),'on');
            t.verifyEqual(char(app.OperatingInputsArea.Enable),'off');
            app.loadExample('nonlinear_equilibrium');
            t.verifyEqual(app.AnalysisMode.Value,'linearize');
            t.verifyEqual(char(app.OperatingStatesArea.Enable),'on');
            t.verifyTrue(app.EquilibriumCheckbox.Value);
        end
        function loadExampleClearsPreviousResults(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            app.perform('analyze'); t.verifyNotEmpty(app.LastResult);
            app.loadExample('nonlinear_equilibrium');
            t.verifyEmpty(app.LastResult);
            text=strjoin(cellstr(string(app.ResultArea.Value)),newline);
            t.verifyTrue(contains(text,'非线性工作点示例'));
            t.verifyFalse(contains(text,'G['));
        end
        function symbolicModePreservesSelectedParameters(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            app.AnalysisMode.Value='symbolic'; app.SymbolicField.Value='a'; app.updateMode();
            result=app.perform('analyze');
            a=sym('a','real'); s=result.laplaceVariable;
            actual=double(subs(result.transferMatrix(1),[a s],[2 2]));
            t.verifyEqual(actual,0.75,'AbsTol',1e-12);
            app.ParametersArea.Value={'{"a":2,"b":6}'};
            next=app.perform('analyze');
            actual=double(subs(next.transferMatrix(1),[a next.laplaceVariable],[2 2]));
            t.verifyEqual(actual,1.5,'AbsTol',1e-12);
        end
        function unresolvedFormulasExportWithoutNumericPlaceholder(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            app.loadExample('symbolic_mass_spring');
            spec=app.perform('check'); t.verifyEqual(spec.parameters.m,'symbolic');
            paths=app.perform('export');
            plain=fileread(paths.text);
            t.verifyTrue(contains(plain,'m = 未赋值实符号'));
            t.verifyFalse(contains(plain,'m = 1'));
            t.verifyTrue(contains(fileread(paths.latex),'ctexart'));
            t.verifyError(@()app.perform('generate'),'fm:NumericValue');
        end
        function workingPointEditsAreUsed(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            app.loadExample('nonlinear_equilibrium');
            result=app.perform('analyze');
            t.verifyEqual(result.A,-3,'AbsTol',1e-12);
            t.verifyEqual(result.B,1,'AbsTol',1e-12);
            t.verifyEqual(result.C,2,'AbsTol',1e-12);
            t.verifyTrue(result.isEquilibrium);
            app.OperatingStatesArea.Value={'{"x":2}'};
            app.OperatingInputsArea.Value={'{"u":8}'};
            next=app.perform('analyze');
            t.verifyEqual(next.A,-12,'AbsTol',1e-12);
            t.verifyEqual(next.C,4,'AbsTol',1e-12);
            t.verifyEqual(next.y0,4,'AbsTol',1e-12);
            t.verifyTrue(next.isEquilibrium);
        end
        function nonEquilibriumRequiresExplicitChoice(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            app.loadExample('nonlinear_equilibrium');
            app.OperatingInputsArea.Value={'{"u":0}'};
            app.invoke('analyze');
            t.verifyEqual(app.StatusLabel.Text,'执行失败：分析');
            t.verifyEqual(app.OperatingInputsArea.Value,{'{"u":0}'});
            app.EquilibriumCheckbox.Value=false;
            result=app.perform('analyze');
            t.verifyFalse(result.isEquilibrium);
            t.verifyEqual(result.f0,-1,'AbsTol',1e-12);
            t.verifyEmpty(result.transferSystem);
        end
        function chineseErrorsRetainSourceDetails(t)
            app=launch('off'); cleanup=onCleanup(@()delete(app));
            app.EquationsArea.Value={'der(x)=missing_var+u'}; app.invoke('check');
            text=strjoin(cellstr(string(app.ResultArea.Value)),newline);
            t.verifyTrue(contains(text,'未声明变量'));
            t.verifyTrue(contains(text,'missing_var'));
            t.verifyFalse(app.Busy);
        end
    end
end
