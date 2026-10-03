function modelPath = createComplexDemo(folder)
%CREATECOMPLEXDEMO Independent nested nonlinear model used for acceptance.
% dx/dt = u - x^3, y = x^2, x(0)=1. No generated-formula metadata required.
if nargin<1
    root=fileparts(fileparts(mfilename('fullpath')));
    parent=fullfile(root,'artifacts','v2','demo');
    if ~isfolder(parent), mkdir(parent); end
    folder=tempname(parent);
end
if isfolder(folder)||isfile(folder), error('fm:DemoCollision','Use a new demo folder.'); end
mkdir(folder); [~,token]=fileparts(folder);
name=matlab.lang.makeValidName(['fm_nested_' token]);
modelPath=fullfile(folder,[name '.slx']);
new_system(name); cleanup=onCleanup(@()close_system(name,0));
set_param(name,'Solver','ode45','StopTime','2');
add_block('simulink/Sources/In1',[name '/u'],'PortDimensions','1', ...
    'OutDataTypeStr','double','SignalType','real','Position',[30 100 60 120]);
plant=[name '/Plant']; add_block('simulink/Ports & Subsystems/Subsystem',plant,'Position',[150 75 285 150]);
Simulink.SubSystem.deleteContents(plant);
add_block('simulink/Sources/In1',[plant '/force'],'PortDimensions','1', ...
    'OutDataTypeStr','double','SignalType','real','Position',[30 100 60 120]);
inner=[plant '/Dynamics']; add_block('simulink/Ports & Subsystems/Subsystem',inner,'Position',[160 80 310 155]);
Simulink.SubSystem.deleteContents(inner);
add_block('simulink/Sources/In1',[inner '/drive'],'PortDimensions','1', ...
    'OutDataTypeStr','double','SignalType','real','Position',[20 70 50 90]);
add_block('simulink/Math Operations/Sum',[inner '/balance'],'Inputs','+-', ...
    'OutDataTypeStr','double','SaturateOnIntegerOverflow','off','Position',[125 63 155 100]);
add_block('simulink/Continuous/Integrator',[inner '/position'],'InitialCondition','1','Position',[235 65 270 100]);
add_block('simulink/Math Operations/Product',[inner '/square'],'Inputs','**','Multiplication','Element-wise(.*)', ...
    'OutDataTypeStr','double','SaturateOnIntegerOverflow','off','Position',[330 185 365 230]);
add_block('simulink/Math Operations/Product',[inner '/cube'],'Inputs','**','Multiplication','Element-wise(.*)', ...
    'OutDataTypeStr','double','SaturateOnIntegerOverflow','off','Position',[205 190 240 235]);
add_block('simulink/Sinks/Out1',[inner '/measured'],'Position',[425 195 455 215]);
add_line(inner,'drive/1','balance/1','autorouting','on');
add_line(inner,'balance/1','position/1','autorouting','on');
add_line(inner,'position/1','square/1','autorouting','on');
add_line(inner,'position/1','square/2','autorouting','on');
add_line(inner,'square/1','cube/1','autorouting','on');
add_line(inner,'position/1','cube/2','autorouting','on');
add_line(inner,'cube/1','balance/2','autorouting','on');
add_line(inner,'square/1','measured/1','autorouting','on');
add_block('simulink/Sinks/Out1',[plant '/measurement'],'Position',[390 105 420 125]);
add_line(plant,'force/1','Dynamics/1','autorouting','on');
add_line(plant,'Dynamics/1','measurement/1','autorouting','on');
add_block('simulink/Sinks/Out1',[name '/y'],'Position',[390 105 420 125]);
add_line(name,'u/1','Plant/1','autorouting','on');
add_line(name,'Plant/1','y/1','autorouting','on');
set_param(name,'SimulationCommand','update');
save_system(name,modelPath);
end
