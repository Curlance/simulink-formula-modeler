classdef FormulaModelerApp < handle
    % Chinese interface; public perform() actions are exercised by UI tests.
    properties
        Figure
        NameField
        StatesField
        InputsField
        ParametersArea
        InitialArea
        EquationsArea
        OutputsArea
        ResultArea
        StatusLabel
        ExampleDropdown
        ModelField
        AnalysisMode
        SymbolicField
        OperatingStatesArea
        OperatingInputsArea
        EquilibriumCheckbox
        Root
        LastModel = ''
        LastResult = []
        Busy = false
        Buttons = {}
    end
    methods
        function app = FormulaModelerApp(varargin)
            app.Root = fileparts(fileparts(mfilename('fullpath')));
            addpath(app.Root);
            visibility='on'; if nargin>0, visibility=varargin{1}; end
            app.Figure=uifigure('Name','公式与 Simulink 建模工具', ...
                'Position',[60 40 1260 880],'Visible',visibility);
            main=uigridlayout(app.Figure,[3 1]); main.RowHeight={40,'1x',28};
            top=uigridlayout(main,[1 3]); top.ColumnWidth={245,115,'1x'};
            app.ExampleDropdown=uidropdown(top,'Items', ...
                {'一阶系统','质量—弹簧—阻尼','耦合多输入系统','非线性工作点示例','符号参数示例'}, ...
                'ItemsData',{'first_order','mass_spring_damper','coupled_states','nonlinear_equilibrium','symbolic_mass_spring'});
            app.button(top,'加载示例','example');
            uilabel(top,'Text','公式 → 原生模型；实际模型 → 方程；数值 / 符号分析与工作点线性化。','WordWrap','on');
            body=uigridlayout(main,[1 2]); body.ColumnWidth={'1x','1x'};
            form=uigridlayout(body,[9 2]); form.ColumnWidth={118,'1x'};
            form.RowHeight={30,30,30,80,65,'1x',86,63,34};
            app.label(form,'模型名称',1); app.NameField=uieditfield(form,'text'); app.place(app.NameField,1,2);
            app.label(form,'状态变量（逗号）',2); app.StatesField=uieditfield(form,'text'); app.place(app.StatesField,2,2);
            app.label(form,'输入变量（逗号）',3); app.InputsField=uieditfield(form,'text'); app.place(app.InputsField,3,2);
            app.label(form,'参数（JSON）',4); app.ParametersArea=uitextarea(form); app.place(app.ParametersArea,4,2);
            app.label(form,'仿真初值（JSON）',5); app.InitialArea=uitextarea(form); app.place(app.InitialArea,5,2);
            app.label(form,'状态方程',6); app.EquationsArea=uitextarea(form); app.place(app.EquationsArea,6,2);
            app.label(form,'输出表达式（JSON）',7); app.OutputsArea=uitextarea(form); app.place(app.OutputsArea,7,2);
            hint=uilabel(form,'Text', ...
                '每行：der(x) = -a*x+b*u。输出：{"y":"x"}。未赋值参数可填 "symbolic"；生成与仿真前需改为数值。', ...
                'WordWrap','on'); app.place(hint,8,[1 2]);
            b=app.button(form,'检查并整理公式','check'); app.place(b,9,[1 2]);
            right=uigridlayout(body,[5 1]); right.RowHeight={65,244,25,'1x',137};
            modelRow=uigridlayout(right,[2 2]); modelRow.ColumnWidth={'1x',102}; modelRow.RowHeight={28,22};
            app.ModelField=uieditfield(modelRow,'text','Placeholder','选择可信的本地 .slx 文件或填写已加载模型名'); app.place(app.ModelField,1,1);
            b=app.button(modelRow,'选择模型','browse'); app.place(b,1,2);
            hint=uilabel(modelRow,'Text','提取 / 仿真读取此模型；分析读取左侧当前方程。'); app.place(hint,2,[1 2]);
            analysis=uigridlayout(right,[6 2]); analysis.ColumnWidth={125,'1x'};
            analysis.RowHeight={30,30,52,52,24,24};
            app.label(analysis,'分析模式',1);
            app.AnalysisMode=uidropdown(analysis,'Items',{'数值传递函数','符号参数传递函数','非线性工作点线性化'}, ...
                'ItemsData',{'numeric','symbolic','linearize'},'Value','numeric', ...
                'ValueChangedFcn',@(~,~)app.updateMode()); app.place(app.AnalysisMode,1,2);
            app.label(analysis,'保留符号参数',2);
            app.SymbolicField=uieditfield(analysis,'text','Placeholder','留空 = 全部；或逗号分隔：m,c,k'); app.place(app.SymbolicField,2,2);
            app.label(analysis,'状态工作点（JSON）',3);
            app.OperatingStatesArea=uitextarea(analysis); app.place(app.OperatingStatesArea,3,2);
            app.label(analysis,'输入工作点（JSON）',4);
            app.OperatingInputsArea=uitextarea(analysis); app.place(app.OperatingInputsArea,4,2);
            app.EquilibriumCheckbox=uicheckbox(analysis,'Text','要求平衡点（取消后保留非平衡漂移项）','Value',true);
            app.place(app.EquilibriumCheckbox,5,[1 2]);
            hint=uilabel(analysis,'Text','工作点用于局部小扰动近似，与左侧仿真初值分别设置。','WordWrap','on'); app.place(hint,6,[1 2]);
            uilabel(right,'Text','结果 / 条件 / 错误说明','FontWeight','bold');
            app.ResultArea=uitextarea(right,'Editable','off');
            actions=uigridlayout(right,[3 3]);
            labels={'导出公式','生成模型','打开模型','提取模型方程','运行所选分析','保存分析结果','单位输入仿真'};
            commands={'export','generate','open','extract','analyze','saveAnalysis','simulate'};
            for k=1:numel(labels), app.button(actions,labels{k},commands{k}); end
            app.StatusLabel=uilabel(main,'Text','就绪');
            editors={app.ParametersArea,app.InitialArea,app.EquationsArea,app.OutputsArea,app.OperatingStatesArea,app.OperatingInputsArea};
            for k=1:numel(editors), editors{k}.FontName='Consolas'; editors{k}.FontSize=14; end
            app.ResultArea.FontName='Microsoft YaHei'; app.ResultArea.FontSize=13;
            app.loadExample('first_order');
        end
        function loadExample(app,name)
            allowed={'first_order','mass_spring_damper','coupled_states','nonlinear_equilibrium','symbolic_mass_spring'};
            if ~ismember(name,allowed), error('fm:UIExample','未找到该示例。'); end
            raw=jsondecode(fileread(fullfile(app.Root,'examples',[name '.json'])));
            app.setRaw(raw); app.ExampleDropdown.Value=name;
            app.OperatingStatesArea.Value={jsonencode(raw.initial)};
            inputPoint=struct(); inputs=app.names(app.InputsField.Value);
            for k=1:numel(inputs), inputPoint.(inputs{k})=0; end
            app.OperatingInputsArea.Value={jsonencode(inputPoint)};
            app.SymbolicField.Value=''; app.EquilibriumCheckbox.Value=true;
            if strcmp(name,'nonlinear_equilibrium')
                app.AnalysisMode.Value='linearize';
                app.OperatingStatesArea.Value={'{"x":1}'}; app.OperatingInputsArea.Value={'{"u":1}'};
            elseif strcmp(name,'symbolic_mass_spring'), app.AnalysisMode.Value='symbolic';
            else, app.AnalysisMode.Value='numeric'; end
            app.updateMode(); app.LastResult=[];
            app.show(['已加载：' app.exampleLabel(name) '。请检查左侧公式与右侧分析设置，再运行分析。']);
            app.StatusLabel.Text=['已加载：' app.exampleLabel(name)];
        end
        function setRaw(app,raw)
            app.NameField.Value=char(raw.name);
            app.StatesField.Value=strjoin(cellstr(string(raw.states)),', ');
            app.InputsField.Value=strjoin(cellstr(string(raw.inputs)),', ');
            app.ParametersArea.Value={jsonencode(raw.parameters)};
            app.InitialArea.Value={jsonencode(raw.initial)};
            app.EquationsArea.Value=cellstr(string(raw.equations));
            app.OutputsArea.Value={jsonencode(raw.outputs)};
        end
        function raw=getRaw(app)
            raw=struct('name',strtrim(app.NameField.Value));
            raw.states=app.names(app.StatesField.Value); raw.inputs=app.names(app.InputsField.Value);
            try
                raw.parameters=jsondecode(app.areaText(app.ParametersArea));
                raw.initial=jsondecode(app.areaText(app.InitialArea));
                raw.outputs=jsondecode(app.areaText(app.OutputsArea));
            catch cause
                error('fm:UIJSON','参数、初值或输出区 JSON 格式错误。使用英文双引号、冒号和逗号。\n%s',cause.message);
            end
            equations=cellstr(string(app.EquationsArea.Value));
            equations=cellfun(@strtrim,equations,'UniformOutput',false);
            raw.equations=equations(~cellfun(@isempty,equations));
        end
        function spec=checkedSpec(app)
            raw=app.getRaw(); unresolved=false;
            if isstruct(raw.parameters)&&isscalar(raw.parameters)
                vals=struct2cell(raw.parameters);
                unresolved=any(cellfun(@(v)ischar(v)||isstring(v),vals));
            end
            if unresolved, spec=fm.analysis.validateSymbolicSpec(raw);
            else, spec=fm.core.validateSpec(raw); end
        end
        function result=analyzeCurrent(app)
            raw=app.getRaw();
            switch app.AnalysisMode.Value
                case 'numeric'
                    result=fm.analysis.deriveTransferFunction(fm.core.validateSpec(raw));
                case 'symbolic'
                    selected=app.names(app.SymbolicField.Value);
                    options=struct();
                    if ~isempty(selected), options.symbolicParameters=selected; end
                    result=fm.analysis.deriveSymbolicTransferFunction(raw,options);
                case 'linearize'
                    try
                        point=struct('states',jsondecode(app.areaText(app.OperatingStatesArea)), ...
                            'inputs',jsondecode(app.areaText(app.OperatingInputsArea)));
                    catch cause
                        error('fm:UIOperatingPoint','工作点 JSON 格式错误：%s',cause.message);
                    end
                    options=struct('requireEquilibrium',app.EquilibriumCheckbox.Value);
                    result=fm.analysis.linearizeAt(fm.core.validateSpec(raw),point,options);
                otherwise, error('fm:UIAction','未知分析模式。');
            end
            app.LastResult=result;
        end
        function result=perform(app,action)
            result=[];
            switch action
                case 'example', app.loadExample(app.ExampleDropdown.Value);
                case 'browse'
                    [file,folder]=uigetfile('*.slx','选择可信的 Simulink 模型',app.Root);
                    if isequal(file,0), return; end
                    app.setModelPath(fullfile(folder,file));
                case 'check'
                    result=app.checkedSpec(); app.show(fm.ui.specText(result));
                case 'export'
                    spec=app.checkedSpec(); folder=app.newOutputPath('formulas');
                    result=fm.ui.exportFormulas(spec,folder);
                    app.show(['公式已导出：' folder]);
                case 'generate'
                    spec=fm.core.validateSpec(app.getRaw());
                    result=fm.simulink.generateModel(spec,app.newOutputPath('model'));
                    app.LastModel=char(result); app.setModelPath(app.LastModel);
                    app.show(['模型已生成：' app.LastModel]);
                case 'open', model=app.selectedModel(); open_system(model); result=model;
                case 'extract'
                    result=fm.simulink.extractEquations(app.selectedModel());
                    app.setRaw(result);
                    app.OperatingStatesArea.Value={jsonencode(result.initial)};
                    inputs=struct(); for k=1:numel(result.inputNames), inputs.(result.inputNames{k})=0; end
                    app.OperatingInputsArea.Value={jsonencode(inputs)};
                    app.show([fm.ui.specText(result) newline '工作点字段已按模型初值和零输入重置；执行线性化前请核对。']);
                case 'analyze', result=app.analyzeCurrent(); app.show(result.text);
                case 'simulate'
                    model=app.selectedModel(); spec=fm.simulink.extractEquations(model);
                    result=fm.validation.compareSimulation(spec,model,struct('stopTime',5));
                    folder=app.newOutputPath('simulation'); mkdir(folder);
                    save(fullfile(folder,'simulation.mat'),'result');
                    fig=figure('Name','单位输入仿真','Visible',app.Figure.Visible);
                    hold on; labels=cell(1,numel(result.channels));
                    for k=1:numel(result.channels)
                        ch=result.channels(k); plot(ch.time,ch.model,'LineWidth',1.4); labels{k}=ch.name;
                    end
                    xlabel('时间（秒）'); ylabel('输出'); grid on;
                    legend(labels,'Interpreter','none','Location','best');
                    title('各输入恒为 1；采用模型指定初值');
                    saveas(fig,fullfile(folder,'response.png'));
                    if strcmp(app.Figure.Visible,'off'), close(fig); end
                    app.show(sprintf('仿真完成：0–5 秒，各输入恒为 1。\n模型与参考方程最大绝对误差：%.6g\n容差检查通过：%d\n保存位置：%s', ...
                        max([result.channels.maxAbsoluteError]),result.passed,folder));
                case 'saveAnalysis'
                    result=app.analyzeCurrent(); folder=app.newOutputPath(app.AnalysisMode.Value); mkdir(folder);
                    app.writeText(fullfile(folder,'analysis.txt'),result.text);
                    app.writeText(fullfile(folder,'analysis.tex'),result.latex);
                    save(fullfile(folder,'analysis.mat'),'result');
                    app.show([result.text newline newline '分析已保存：' folder]);
                otherwise, error('fm:UIAction','未知操作：%s',action);
            end
        end
        function invoke(app,action)
            if app.Busy, return; end
            app.Busy=true; label=app.actionLabel(action);
            app.StatusLabel.Text=['正在执行：' label];
            for k=1:numel(app.Buttons), app.Buttons{k}.Enable='off'; end
            cleanup=onCleanup(@()app.finishAction()); drawnow;
            try
                app.perform(action); app.StatusLabel.Text=['已完成：' label];
            catch ME
                app.StatusLabel.Text=['执行失败：' label]; app.show(fm.ui.errorText(ME));
            end
            clear cleanup;
        end
        function finishAction(app)
            app.Busy=false; if ~isvalid(app.Figure), return; end
            for k=1:numel(app.Buttons), app.Buttons{k}.Enable='on'; end
        end
        function updateMode(app)
            symbolic=strcmp(app.AnalysisMode.Value,'symbolic'); linear=strcmp(app.AnalysisMode.Value,'linearize');
            app.SymbolicField.Enable=app.onOff(symbolic);
            app.OperatingStatesArea.Enable=app.onOff(linear);
            app.OperatingInputsArea.Enable=app.onOff(linear);
            app.EquilibriumCheckbox.Enable=app.onOff(linear);
        end
        function show(app,text)
            if iscell(text), text=strjoin(text,newline); end
            app.ResultArea.Value=splitlines(string(text));
        end
        function path=newOutputPath(app,kind)
            parent=fullfile(app.Root,'artifacts','exports'); if ~isfolder(parent), mkdir(parent); end
            [~,token]=fileparts(tempname(parent)); path=fullfile(parent,[kind '_' token]);
        end
        function setModelPath(app,path)
            app.ModelField.Value=path; app.ModelField.Tooltip=path;
        end
        function model=selectedModel(app)
            model=strtrim(app.ModelField.Value);
            if isempty(model), error('fm:UIModel','请先生成模型或选择本地模型。'); end
        end
        function delete(app)
            if ~isempty(app.Figure)&&isvalid(app.Figure), delete(app.Figure); end
        end
    end
    methods (Access=private)
        function b=button(app,parent,label,action)
            b=uibutton(parent,'Text',label,'ButtonPushedFcn',@(~,~)app.invoke(action));
            app.Buttons{end+1}=b;
        end
    end
    methods (Static, Access=private)
        function place(control,row,column), control.Layout.Row=row; control.Layout.Column=column; end
        function label(parent,text,row)
            control=uilabel(parent,'Text',text,'VerticalAlignment','top','WordWrap','on');
            control.Layout.Row=row; control.Layout.Column=1;
        end
        function values=names(text)
            if isempty(strtrim(text)), values={}; return; end
            values=cellfun(@strtrim,strsplit(text,',','CollapseDelimiters',false),'UniformOutput',false);
            if any(cellfun(@isempty,values)), error('fm:UIIdentifier','变量列表中存在空项，请检查英文逗号。'); end
        end
        function text=areaText(area), text=strjoin(cellstr(string(area.Value)),newline); end
        function text=onOff(value), if value, text='on'; else, text='off'; end, end
        function text=exampleLabel(name)
            ids={'first_order','mass_spring_damper','coupled_states','nonlinear_equilibrium','symbolic_mass_spring'};
            labels={'一阶系统','质量—弹簧—阻尼','耦合多输入系统','非线性工作点示例','符号参数示例'};
            text=labels{find(strcmp(ids,name),1)};
        end
        function text=actionLabel(name)
            ids={'example','browse','check','export','generate','open','extract','analyze','saveAnalysis','simulate'};
            labels={'加载示例','选择模型','检查公式','导出公式','生成模型','打开模型','提取模型方程','分析','保存分析','单位输入仿真'};
            idx=find(strcmp(ids,name),1); if isempty(idx), text=name; else, text=labels{idx}; end
        end
        function writeText(path,text)
            if isfile(path), error('fm:UIOverwrite','目标文件已存在：%s',path); end
            fid=fopen(path,'w','n','UTF-8'); if fid<0, error('fm:UIWrite','无法写入：%s',path); end
            cleanup=onCleanup(@()fclose(fid)); if iscell(text), text=strjoin(text,newline); end
            fprintf(fid,'%s\n',char(text));
        end
    end
end
