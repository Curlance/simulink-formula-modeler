function app = launch(varargin)
% Launch the local formula/Simulink tool. launch('off') is for UI tests.
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root,'app'));
app = FormulaModelerApp(varargin{:});
if nargout == 0
    setappdata(app.Figure,'FormulaModelerApp',app);
    clear app;
end
end
