function checkBlock(b)
%CHECKBLOCK Conservative whitelist before any model update/evaluation.
type=get_param(b,'BlockType'); p=get_param(b,'ObjectParameters');
if ~strcmp(get_param(b,'Mask'),'off'), fail('Masked blocks are unsupported.'); end
if ~strcmp(get_param(b,'LinkStatus'),'none'), fail('Library-linked blocks are unsupported.'); end
callbacks={'InitFcn','StartFcn','StopFcn','LoadFcn','OpenFcn','PreSaveFcn','PostSaveFcn', ...
    'CopyFcn','DeleteFcn','DestroyFcn','ModelCloseFcn','ParentCloseFcn','MoveFcn','NameChangeFcn','UndoDeleteFcn','ErrorFcn'};
for i=1:numel(callbacks)
    if isfield(p,callbacks{i}) && ~isempty(get_param(b,callbacks{i})), fail('Block callbacks are unsupported.'); end
end
if isfield(p,'OutDataTypeStr')
    dt=get_param(b,'OutDataTypeStr');
    if ~ismember(dt,{'double','Inherit: Inherit via internal rule','Inherit: Same as input','Inherit: Same as first input','Inherit: auto','Inherit: Inherit via back propagation','Inherit: Inherit from ''Constant value'''}), fail('Only double scalar arithmetic is supported.'); end
end
if isfield(p,'SaturateOnIntegerOverflow') && strcmp(get_param(b,'SaturateOnIntegerOverflow'),'on'), fail('Saturating arithmetic is unsupported.'); end
require('Commented',{'off'});
if ~strcmp(type,'Constant'), require('SampleTime',{'-1','0'}); end
require('VariableSizeSignals',{'off','Inherit','inherit'});
switch type
    case 'Integrator'
        require('ExternalReset',{'none'}); require('LimitOutput',{'off'});
        require('InitialConditionSource',{'internal'}); require('ShowStatePort',{'off'});
        require('ShowSaturationPort',{'off'}); require('WrapState',{'off'});
    case 'Inport'
        if strcmp(get_param(b,'Parent'),bdroot(b))
            require('PortDimensions',{'1'}); require('SignalType',{'real'});require('OutDataTypeStr',{'double'});
        else
            require('PortDimensions',{'-1','1'});require('SignalType',{'auto','real'});
            require('OutDataTypeStr',{'double','Inherit: auto'});
        end
        require('SampleTime',{'-1','0'}); require('Interpolate',{'on'});
    case 'Outport'
        require('PortDimensions',{'-1','1'}); require('SignalType',{'auto','real'});
        require('SampleTime',{'-1','0'});
    case 'Constant'
        require('SampleTime',{'inf','Inf','-1'});
    case 'Gain'
        require('Multiplication',{'Element-wise(K.*u)'});
    case 'Product'
        require('Multiplication',{'Element-wise(.*)'});
        s=get_param(b,'Inputs');
        if numel(s)==1 && (ismember(s,'*/') || (~isnan(str2double(s)) && str2double(s)==1))
            fail('Single-input Product reduction is unsupported.');
        end
    case 'Sum'
        s=strrep(get_param(b,'Inputs'),'|','');
        if numel(s)==1 && (ismember(s,'+-') || (~isnan(str2double(s)) && str2double(s)==1))
            fail('Single-input Sum reduction is unsupported.');
        end
    case 'Math'
        require('Operator',{'pow','exp'}); require('OutputSignalType',{'real','auto'});
    case 'Trigonometry'
        require('Operator',{'sin','cos'});
    case 'SubSystem'
        require('TreatAsAtomicUnit',{'off'});require('Variant',{'off'});
        require('ReferencedSubsystem',{''});require('IsSubsystemVirtual',{'on'});
        require('SystemSampleTime',{'-1','0'});
        ph=get_param(b,'PortHandles');
        control={'Enable','Trigger','Reset','Ifaction','Event'};
        for k=1:numel(control)
            if isfield(ph,control{k})&&~isempty(ph.(control{k})),fail('不支持有控制端口的子系统。');end
        end
    case 'Goto'
        require('TagVisibility',{'local','scoped','global'});
end
% Scalar proof: scalar sources/operators and SISO dynamics; subsystem and
% routing boundaries are transparent, with inherited internal port types.
    function require(key,values)
        if isfield(p,key) && ~ismember(get_param(b,key),values), fail(['Unsupported ' key ' setting.']); end
    end
    function fail(message)
        error('fm:UnsupportedConfiguration','%s: %s',b,message);
    end
end
