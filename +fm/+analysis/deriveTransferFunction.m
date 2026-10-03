function result = deriveTransferFunction(spec)
%DERIVETRANSFERFUNCTION Numeric channel transfer functions for zero initial state.
result = fm.analysis.extractStateSpace(spec);
if exist('ss','file') ~= 2 || exist('tf','file') ~= 2
    error('fm:analysis:ToolboxUnavailable','Control System Toolbox ss/tf execution is required for transfer functions.');
end
try
    model = ss(result.A,result.B,result.C,result.D);
    model.StateName = result.stateNames;
    model.InputName = result.inputNames;
    model.OutputName = result.outputNames;
    result.system = tf(model);
catch cause
    problem = MException('fm:analysis:ToolboxExecutionFailed', ...
        'Control System Toolbox could not construct the transfer function: %s',cause.message);
    problem = addCause(problem,cause);
    throw(problem);
end
result.conditions = ['连续时间线性时不变系统，参数采用有限实数值。' ...
    '传递函数采用零初始条件（zero initial conditions），x(0)=0；不包含指定初值的自由响应。' ...
    '未执行零极点约消。'];
ny = numel(result.outputNames); nu = numel(result.inputNames);
prototype = struct('outputName','','inputName','','numerator',[],'denominator',[]);
result.channels = repmat(prototype,ny,nu);
result.numerator = cell(ny,nu); result.denominator = cell(ny,nu);
texts = cell(1,ny*nu); tex = cell(1,ny*nu); k = 0;
for iy = 1:ny
    for iu = 1:nu
        [num,den] = tfdata(result.system(iy,iu),'v');
        result.numerator{iy,iu} = num;
        result.denominator{iy,iu} = den;
        result.channels(iy,iu) = struct('outputName',result.outputNames{iy}, ...
            'inputName',result.inputNames{iu},'numerator',num,'denominator',den);
        k = k+1;
        texts{k} = sprintf('G[%s <- %s](s) = (%s)/(%s)', ...
            result.outputNames{iy},result.inputNames{iu},polynomial(num,false),polynomial(den,false));
        tex{k} = sprintf('G_{%s\\leftarrow %s}(s)=\\frac{%s}{%s}', ...
            identifier(result.outputNames{iy}),identifier(result.inputNames{iu}), ...
            polynomial(num,true),polynomial(den,true));
    end
end
result.text = sprintf(['%s\n状态顺序：%s\n输入顺序：%s\n输出顺序：%s\n' ...
    '状态空间：dx/dt=A*x+B*u，y=C*x+D*u\nA=%s\nB=%s\nC=%s\nD=%s\n' ...
    '推导依据：G(s)=C*(s*I-A)^(-1)*B+D\n%s'], ...
    result.conditions,strjoin(result.stateNames,', '),strjoin(result.inputNames,', '), ...
    strjoin(result.outputNames,', '),mat2str(result.A,12),mat2str(result.B,12), ...
    mat2str(result.C,12),mat2str(result.D,12),strjoin(texts,newline));
result.latex = sprintf('\\text{Zero initial conditions: }x(0)=0.\n\\begin{aligned}\n%s\n\\end{aligned}', ...
    strjoin(tex,sprintf(' \\\\\n')));
end

function text = identifier(name)
text = ['\mathrm{' strrep(name,'_','\_') '}'];
end

function text = polynomial(coefficients,isLatex)
text = '';
for j = 1:numel(coefficients)
    value = coefficients(j); power = numel(coefficients)-j;
    if value == 0, continue; end
    if isempty(text)
        if value < 0, text = '-'; end
    elseif value < 0
        text = [text ' - ']; %#ok<AGROW>
    else
        text = [text ' + ']; %#ok<AGROW>
    end
    magnitude = abs(value);
    if power == 0 || magnitude ~= 1
        token = sprintf('%.17g',magnitude);
        if isLatex
            token = regexprep(token,'e([+-]?\d+)','\\times 10^{$1}');
        end
        text = [text token]; %#ok<AGROW>
        if power > 0 && ~isLatex, text = [text '*']; end %#ok<AGROW>
    end
    if power > 0
        text = [text 's']; %#ok<AGROW>
        if power > 1
            if isLatex
                text = [text sprintf('^{%d}',power)]; %#ok<AGROW>
            else
                text = [text sprintf('^%d',power)]; %#ok<AGROW>
            end
        end
    end
end
if isempty(text), text = '0'; end
end
