function d = dynamicMatrices(block, workspace)
%DYNAMICMATRICES Numeric SISO continuous realizations; never minimalize states.
type=get_param(block,'BlockType');
switch type
    case 'StateSpace'
        d.A=read('A'); d.B=read('B'); d.C=read('C'); d.D=read('D');
        n=size(d.A,1);
        if n<1 || size(d.A,2)~=n || ~isequal(size(d.B),[n 1]) || ~isequal(size(d.C),[1 n]) || ~isscalar(d.D)
            error('fm:UnsupportedDynamics','%s：State-Space 目前要求非空方阵 A、n×1 B、1×n C、标量 D（单输入单输出）。',block);
        end
        x=read('InitialCondition');
        if isscalar(x),x=repmat(x,n,1);end
        if ~isvector(x)||numel(x)~=n,error('fm:UnsupportedDynamics','%s：初始状态数量必须等于 %d。',block,n);end
        d.initial=x(:);
    case 'TransferFcn'
        num=read('Numerator'); den=read('Denominator');
        if isempty(num)||isempty(den)||~isrow(num)||~isrow(den)||den(1)==0||numel(num)>numel(den)
            error('fm:UnsupportedDynamics','%s：需要非空 SISO 行向量系数、非零分母首项及 proper 传递函数。',block);
        end
        n=numel(den)-1; num=[zeros(1,numel(den)-numel(num)) num]/den(1); den=den/den(1);
        d.D=num(1);
        if n==0
            d.A=zeros(0);d.B=zeros(0,1);d.C=zeros(1,0);
        else
            d.A=[-den(2:end); eye(n-1) zeros(n-1,1)]; d.B=[1;zeros(n-1,1)];
            d.C=num(2:end)-d.D*den(2:end);
        end
        % R2022a Transfer Fcn has no IC parameter and fixes all states to zero.
        % Model-level initial-state restoration is rejected by the extractor.
        d.initial=zeros(n,1);
    otherwise
        error('fm:UnsupportedDynamics','%s：不支持的动态模块。',block);
end
if any(~isfinite([d.A(:);d.B(:);d.C(:);d.D(:);d.initial(:)]))
    error('fm:UnsupportedDynamics','%s：动态矩阵计算溢出。',block);
end
    function value=read(key)
        value=fm.simulink.parseNumericParameter(get_param(block,key),workspace,block,key);
    end
end
