function modelPath = generateModel(spec, folder)
%GENERATEMODEL Editable flat scalar native-block realization.
spec = fm.core.validateSpec(spec);
folder = char(folder); name = spec.name;
modelPath = fullfile(folder,[name '.slx']);
jsonPath = fullfile(folder,[name '.json']);
scriptPath = fullfile(folder,['build_' name '.m']);
if bdIsLoaded(name)
    error('fm:ModelCollision','Model name %s is already loaded.',name);
end
for p = {modelPath,jsonPath,scriptPath}
    if exist(p{1},'file'), error('fm:ArtifactCollision','Refusing to overwrite %s.',p{1}); end
end
if ~exist(folder,'dir'), mkdir(folder); end
new_system(name); cleanup = onCleanup(@() closeOwned(name));
set_param(name,'Solver','ode45','StopTime','10','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset');
mw = get_param(name,'ModelWorkspace');
pars = fieldnames(spec.parameters);
for i=1:numel(pars), assignin(mw,pars{i},spec.parameters.(pars{i})); end
sources = containers.Map('KeyType','char','ValueType','char');
count = 0;
for i=1:numel(spec.inputNames)
    key=spec.inputNames{i}; b=add('simulink/Sources/In1',['input_' key],0,i);
    set_param(b,'Port',num2str(i),'PortDimensions','1','OutDataTypeStr','double','SignalType','real');
    hint(b,key); sources(key)=[get_param(b,'Name') '/1'];
end
for i=1:numel(spec.stateNames)
    key=spec.stateNames{i}; b=add('simulink/Continuous/Integrator',['state_' key],5,i);
    set_param(b,'InitialCondition',num2str(spec.initial.(key),17)); hint(b,key);
    set_param(b,'UserData',struct('fmName',key,'fmOrder',i));
    sources(key)=[get_param(b,'Name') '/1'];
end
for i=1:numel(pars)
    key=pars{i}; b=add('simulink/Sources/Constant',['parameter_' key],0,numel(spec.inputNames)+i);
    set_param(b,'Value',key); sources(key)=[get_param(b,'Name') '/1'];
end
for i=1:numel(spec.stateNames)
    src=emit(spec.derivatives{i},1); wire(src,['state_' spec.stateNames{i} '/1']);
end
for i=1:numel(spec.outputNames)
    src=emit(spec.outputExpressions{i},1); key=spec.outputNames{i};
    b=add('simulink/Sinks/Out1',['output_' key],7,i); set_param(b,'Port',num2str(i)); hint(b,key);
    wire(src,[get_param(b,'Name') '/1']);
end
set_param(name,'SimulationCommand','update');
% Extraction is also the whitelist check on the generated graph.
fm.simulink.extractEquations(name);
save_system(name,modelPath);
raw=struct('name',name,'states',{spec.stateNames},'inputs',{spec.inputNames}, ...
    'parameters',spec.parameters,'initial',spec.initial,'equations',{spec.equations},'outputs',spec.outputs);
writeText(jsonPath,jsonencode(raw));
% The script rebuilds native blocks from the adjacent raw JSON in a fresh folder.
script=sprintf(['%% Reproduce this editable model; requires the Formula Modeler package on path.\n' ...
    'sourceFolder = fileparts(mfilename(''fullpath''));\n' ...
    'raw = jsondecode(fileread(fullfile(sourceFolder,''%s.json'')));\n' ...
    'spec = fm.core.validateSpec(raw);\n' ...
    'fm.simulink.generateModel(spec, fullfile(sourceFolder,''rebuilt''));\n'],name);
writeText(scriptPath,script);
    function b=add(lib,label,col,row)
        b=[name '/' label]; x=40+col*165; y=35+(row-1)*85;
        add_block(lib,b,'Position',[x y x+75 y+40]);
        bp=get_param(b,'ObjectParameters');
        if isfield(bp,'OutDataTypeStr'), set_param(b,'OutDataTypeStr','double'); end
        if isfield(bp,'SaturateOnIntegerOverflow'), set_param(b,'SaturateOnIntegerOverflow','off'); end
    end
    function hint(b,key)
        set_param(b,'UserData',struct('fmName',key),'UserDataPersistent','on');
    end
    function wire(src,dst)
        add_line(name,src,dst,'autorouting','on');
    end
    function src=emit(a,depth)
        if strcmp(a.kind,'symbol'), src=sources(a.value); return; end
        children=cell(1,numel(a.args));
        for j=1:numel(a.args), children{j}=emit(a.args{j},depth+1); end
        count=count+1; label=sprintf('op_%03d',count);
        col=1+mod(depth-1,4); row=count;
        switch a.kind
            case 'number'
                b=add('simulink/Sources/Constant',label,col,row); set_param(b,'Value',num2str(a.value,17));
            case 'unary'
                b=add('simulink/Math Operations/Gain',label,col,row);
                if strcmp(a.value,'-'), gain='-1'; else, gain='1'; end
                set_param(b,'Gain',gain,'Multiplication','Element-wise(K.*u)');
            case 'binary'
                switch a.value
                    case {'+','-'}
                        b=add('simulink/Math Operations/Sum',label,col,row); set_param(b,'Inputs',['+' a.value]);
                    case {'*','/'}
                        b=add('simulink/Math Operations/Product',label,col,row); set_param(b,'Inputs',['*' a.value],'Multiplication','Element-wise(.*)');
                    case '^'
                        b=add('simulink/Math Operations/Math Function',label,col,row); set_param(b,'Operator','pow');
                    otherwise, error('fm:UnsupportedOperation','Unsupported operation %s.',a.value);
                end
            case 'call'
                if ismember(a.value,{'sin','cos'})
                    b=add('simulink/Math Operations/Trigonometric Function',label,col,row); set_param(b,'Operator',a.value);
                elseif strcmp(a.value,'exp')
                    b=add('simulink/Math Operations/Math Function',label,col,row); set_param(b,'Operator','exp');
                else, error('fm:UnsupportedOperation','Unsupported function %s.',a.value); end
            otherwise, error('fm:UnsupportedOperation','Unsupported AST kind %s.',a.kind);
        end
        for j=1:numel(children), wire(children{j},sprintf('%s/%d',label,j)); end
        src=[label '/1'];
    end
end
function closeOwned(name)
if bdIsLoaded(name), close_system(name,0); end
end
function writeText(path,text)
fid=fopen(path,'w','n','UTF-8');
if fid<0, error('fm:FileWrite','Cannot create %s.',path); end
c=onCleanup(@() fclose(fid)); fprintf(fid,'%s',text);
end
