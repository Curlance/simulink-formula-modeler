function spec = extractEquations(modelPathOrName)
%EXTRACTEQUATIONS Read a native continuous scalar graph, including hierarchy.
% No update, simulation, parameter mutation, or workspace evaluation occurs.
arg=char(modelPathOrName); [~,base,ext]=fileparts(arg);
if isempty(ext) && bdIsLoaded(arg), model=arg; owned=false;
else
    if bdIsLoaded(base)
        loaded=get_param(base,'FileName');
        if ~strcmpi(strrep(loaded,'\','/'),strrep(arg,'\','/'))
            error('fm:ModelCollision','A different model named %s is already loaded.',base);
        end
        model=base; owned=false;
    else
        try, load_system(arg); catch e, error('fm:ModelLoad','Cannot load model: %s',e.message); end
        model=base; owned=true;
    end
end
cleanup=onCleanup(@() closeIfOwned(model,owned)); %#ok<NASGU>
if ~strcmp(get_param(model,'BlockDiagramType'),'model'), error('fm:UnsupportedModel','Expected a model, not a library.'); end
if ~isempty(get_param(model,'DataDictionary')), error('fm:UnsupportedModel','%s：不支持数据字典，请使用模型工作区数值参数。',model); end
if strcmp(get_param(model,'LoadInitialState'),'on'),error('fm:UnsupportedModel','%s：不支持恢复模型级初始状态；请使用各模块的初值。',model);end
callbacks={'PreLoadFcn','PostLoadFcn','InitFcn','StartFcn','PauseFcn','ContinueFcn','StopFcn','PreSaveFcn','PostSaveFcn','CloseFcn'};
mp=get_param(model,'ObjectParameters');
for cbIndex=1:numel(callbacks)
    if isfield(mp,callbacks{cbIndex}) && ~isempty(get_param(model,callbacks{cbIndex})),error('fm:UnsupportedModel','%s：不支持模型回调 %s。',model,callbacks{cbIndex});end
end
mw=get_param(model,'ModelWorkspace');
if ~strcmp(mw.DataSource,'Model File'), error('fm:UnsupportedWorkspace','Workspace must use Model File storage.'); end
parameters=struct(); workspace=struct(); vars=whos(mw);
for i=1:numel(vars)
    value=getVariable(mw,vars(i).name);
    if ~(isnumeric(value)&&isreal(value)&&ismatrix(value)&&all(isfinite(value(:))))
        error('fm:UnsupportedParameter','%s 工作区参数 %s 必须是有限实数标量或二维数组。',model,vars(i).name);
    end
    workspace.(vars(i).name)=full(double(value));
    if isscalar(value),parameters.(vars(i).name)=double(value);end
end
blocks=find_system(model,'LookUnderMasks','all','FollowLinks','off','IncludeCommented','on','Type','Block');
blocks=sort(blocks(:)');
types=cellfun(@(b)get_param(b,'BlockType'),blocks,'UniformOutput',false);
allowed={'Integrator','Inport','Outport','Constant','Gain','Sum','Product','Math','Trigonometry', ...
    'SubSystem','Goto','From','GotoTagVisibility','Terminator','TransferFcn','StateSpace'};
for i=1:numel(blocks)
    if ~ismember(types{i},allowed), error('fm:UnsupportedBlock','不支持模块 %s（%s）。',blocks{i},types{i}); end
    fm.simulink.checkBlock(blocks{i});
end
routes=fm.simulink.resolveRoutes(blocks,types,model);
parents=cellfun(@(b)get_param(b,'Parent'),blocks,'UniformOutput',false);
inputs=byPort(blocks(strcmp(types,'Inport') & strcmp(parents,model)));
outputs=byPort(blocks(strcmp(types,'Outport') & strcmp(parents,model)));
subsystems=blocks(strcmp(types,'SubSystem'));
for i=1:numel(subsystems)
    byPort(blocks(strcmp(types,'Inport') & strcmp(parents,subsystems{i})));
    byPort(blocks(strcmp(types,'Outport') & strcmp(parents,subsystems{i})));
end
stateBlocks=blocks(ismember(types,{'Integrator','TransferFcn','StateSpace'}));
orders=inf(1,numel(stateBlocks));
for i=1:numel(stateBlocks)
    h=get_param(stateBlocks{i},'UserData');
    if isstruct(h)&&isscalar(h)&&isfield(h,'fmOrder')&&isnumeric(h.fmOrder)&&isscalar(h.fmOrder)&&isfinite(h.fmOrder),orders(i)=h.fmOrder;end
end
[~,ix]=sort(orders);stateBlocks=stateBlocks(ix);
used=[fieldnames(parameters)' {'sin','cos','exp','der','pi','Inf','NaN','i','j','ans'}];
names=containers.Map('KeyType','char','ValueType','any'); dynamics=containers.Map('KeyType','char','ValueType','any');
stateNames={};inputNames=cell(1,numel(inputs));outputNames=cell(1,numel(outputs));initial=struct();
sourceMap=struct('states',struct(),'stateIndices',struct(),'inputs',struct(),'outputs',struct());
for i=1:numel(stateBlocks)
    b=stateBlocks{i}; label=labelOf(b,model);
    if strcmp(get_param(b,'BlockType'),'Integrator')
        n=1; x=fm.core.evaluateAst(param(b,'InitialCondition'),parameters);
    else
        d=fm.simulink.dynamicMatrices(b,workspace);dynamics(b)=d;n=numel(d.initial);x=d.initial;
    end
    local=cell(1,n);
    for j=1:n
        if strcmp(get_param(b,'BlockType'),'Integrator'),candidate=label;else,candidate=sprintf('%s_x%d',label,j);end
        local{j}=uniqueName(candidate); stateNames{end+1}=local{j}; %#ok<AGROW>
        initial.(local{j})=x(j);sourceMap.states.(local{j})=b;sourceMap.stateIndices.(local{j})=j;
    end
    names(b)=local;
end
for i=1:numel(inputs)
    inputNames{i}=uniqueName(labelOf(inputs{i},model));names(inputs{i})=inputNames(i);sourceMap.inputs.(inputNames{i})=inputs{i};
end
for i=1:numel(outputs)
    outputNames{i}=uniqueName(labelOf(outputs{i},model));sourceMap.outputs.(outputNames{i})=outputs{i};
end
if isempty(stateNames)||isempty(outputs),error('fm:UnsupportedModel','%s：需要至少一个连续状态和一个顶层输出。',model);end
cache=containers.Map('KeyType','char','ValueType','any');active=containers.Map('KeyType','char','ValueType','logical');
equations={}; out=struct();
for i=1:numel(stateBlocks)
    b=stateBlocks{i}; local=names(b);
    if strcmp(get_param(b,'BlockType'),'Integrator')
        equations{end+1}=sprintf('der(%s) = %s',local{1},fm.export.expressionText(source(b,1))); %#ok<AGROW>
    else
        d=dynamics(b);
        for j=1:numel(local)
            a=linear(d.A(j,:),local);
            if d.B(j)~=0,a=addAst(a,scaleAst(d.B(j),source(b,1)));end
            equations{end+1}=sprintf('der(%s) = %s',local{j},fm.export.expressionText(a)); %#ok<AGROW>
        end
    end
end
for i=1:numel(outputs),out.(outputNames{i})=fm.export.expressionText(source(outputs{i},1));end
% Walk every branch, not only the equations' reachable output graph.
for i=1:numel(blocks)
    b=blocks{i};ph=get_param(b,'PortHandles');
    for j=1:numel(ph.Inport),source(b,j);end
    for j=1:numel(ph.Outport),visit(b,j);end
end
raw=struct('name',model,'states',{stateNames},'inputs',{inputNames},'parameters',parameters,'initial',initial,'equations',{equations},'outputs',out);
spec=fm.core.validateSpec(raw);spec.sourceMap=sourceMap;
    function a=param(b,key)
        try
            a=fm.parser.parseExpression(get_param(b,key));fm.core.evaluateAst(a,parameters);
        catch e
            error('fm:UnsafeParameter','%s 参数 %s 必须为有限实数标量表达式：%s',b,key,e.message);
        end
    end
    function name=uniqueName(candidate)
        candidate=regexprep(candidate,'[^A-Za-z0-9_]','_');
        if isempty(candidate)||isempty(regexp(candidate(1),'[A-Za-z]','once')),candidate=['x_' candidate];end
        candidate=candidate(1:min(numel(candidate),namelengthmax));name=candidate;k=1;
        while ismember(name,used)||~isvarname(name)
            suffix=sprintf('_%d',k); name=[candidate(1:min(numel(candidate),namelengthmax-numel(suffix))) suffix]; k=k+1;
        end
        used{end+1}=name;
    end
    function a=source(b,port)
        inputHandles=get_param(b,'PortHandles');
        if port>numel(inputHandles.Inport),error('fm:InvalidPorts','%s 缺少输入端口 %d。',b,port);end
        line=get_param(inputHandles.Inport(port),'Line');
        if line==-1,error('fm:DisconnectedPort','%s 输入端口 %d 未连接。',b,port);end
        src=get_param(line,'SrcPortHandle');
        if src==-1,error('fm:InvalidPorts','%s 的源端口无效。',b);end
        a=visit(get_param(src,'Parent'),get_param(src,'PortNumber'));
    end
    function a=visit(b,port)
        key=sprintf('%s:%d',b,port);
        if isKey(cache,key),a=cache(key);return;end
        type=get_param(b,'BlockType');
        if strcmp(type,'Integrator') || (strcmp(type,'Inport')&&strcmp(get_param(b,'Parent'),model))
            sourceNames=names(b);a=node('symbol',sourceNames{1},{});cache(key)=a;return;
        end
        if isKey(active,key)&&active(key),error('fm:AlgebraicLoop','在 %s 输出端口 %d 检测到代数环。',b,port);end
        active(key)=true;
        if port~=1 && ~strcmp(type,'SubSystem'),error('fm:InvalidPorts','%s 不支持输出端口 %d。',b,port);end
        switch type
            case 'Inport',a=source(get_param(b,'Parent'),str2double(get_param(b,'Port')));
            case 'SubSystem'
                children=byPort(blocks(strcmp(types,'Outport')&strcmp(parents,b)));
                if port>numel(children),error('fm:InvalidPorts','%s 缺少内部 Outport %d。',b,port);end
                a=source(children{port},1);
            case 'From',a=source(routes(b),1);
            case {'TransferFcn','StateSpace'}
                outputDynamics=dynamics(b);a=linear(outputDynamics.C,names(b));
                if outputDynamics.D~=0,a=addAst(a,scaleAst(outputDynamics.D,source(b,1)));end
            case 'Constant',a=param(b,'Value');
            case 'Gain',a=node('binary','*',{param(b,'Gain'),source(b,1)});
            case 'Sum'
                signs=strrep(get_param(b,'Inputs'),'|','');
                if all(isstrprop(signs,'digit')),signs=repmat('+',1,str2double(signs));end
                if isempty(signs)||any(~ismember(signs,'+-')),error('fm:UnsupportedSum','%s：Sum 符号不支持。',b);end
                a=source(b,1);if signs(1)=='-',a=node('unary','-',{a});end
                for k=2:numel(signs),a=node('binary',signs(k),{a,source(b,k)});end
            case 'Product'
                signs=get_param(b,'Inputs');
                if all(isstrprop(signs,'digit')),signs=repmat('*',1,str2double(signs));end
                if isempty(signs)||any(~ismember(signs,'*/')),error('fm:UnsupportedProduct','%s：Product 运算不支持。',b);end
                a=source(b,1);if signs(1)=='/',a=node('binary','/',{node('number',1,{}),a});end
                for k=2:numel(signs),a=node('binary',signs(k),{a,source(b,k)});end
            case 'Math'
                op=get_param(b,'Operator');
                if strcmp(op,'pow'),a=node('binary','^',{source(b,1),source(b,2)});
                elseif strcmp(op,'exp'),a=node('call','exp',{source(b,1)});
                else,error('fm:UnsupportedMath','%s：不支持运算 %s。',b,op);end
            case 'Trigonometry'
                op=get_param(b,'Operator');a=node('call',op,{source(b,1)});
            otherwise,error('fm:UnsupportedBlock','不支持信号源 %s（%s）。',b,type);
        end
        active(key)=false;cache(key)=a;
    end
end
function a=linear(coeff,names)
a=node('number',0,{});
for j=1:numel(coeff),if coeff(j)~=0,a=addAst(a,scaleAst(coeff(j),node('symbol',names{j},{})));end,end
end
function a=addAst(a,b)
if strcmp(a.kind,'number')&&a.value==0,a=b;else,a=node('binary','+',{a,b});end
end
function a=scaleAst(value,b)
if value==1,a=b;else,a=node('binary','*',{node('number',value,{}),b});end
end
function a=node(kind,value,args)
a=struct('kind',kind,'value',value,'args',{args});
end
function name=labelOf(block,model)
hint=get_param(block,'UserData');name=get_param(block,'Name');
if isstruct(hint)&&isscalar(hint)&&isfield(hint,'fmName')&&ischar(hint.fmName)&&isrow(hint.fmName)&&~isempty(hint.fmName),name=hint.fmName;end
parent=get_param(block,'Parent');
if ~strcmp(parent,model),name=[parent(numel(model)+2:end) '__' name];end
end
function blocks=byPort(blocks)
ports=cellfun(@(b)str2double(get_param(b,'Port')),blocks);[ports,ix]=sort(ports);blocks=blocks(ix);
if ~isequal(reshape(ports,1,[]),1:numel(blocks))
    error('fm:InvalidPorts','端口编号必须从 1 连续排列：%s。',strjoin(blocks,', '));
end
end
function closeIfOwned(model,owned)
if owned&&bdIsLoaded(model),close_system(model,0);end
end
