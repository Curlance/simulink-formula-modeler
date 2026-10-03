function result = extractStateSpace(spec)
%EXTRACTSTATESPACE Prove affine structure and extract a numeric continuous LTI model.
% Input is the validated schemaVersion=1 spec from fm.core.validateSpec.
required = {'schemaVersion','stateNames','inputNames','outputNames', ...
    'derivatives','outputExpressions','parameters'};
if ~isstruct(spec) || ~isscalar(spec) || ~all(isfield(spec,required)) || spec.schemaVersion ~= 1
    error('fm:analysis:InvalidSpec','Pass a schemaVersion=1 validated specification.');
end
nx = numel(spec.stateNames); nu = numel(spec.inputNames); ny = numel(spec.outputNames);
if nu == 0
    error('fm:analysis:NoInputs','Input-output analysis requires at least one declared input. Equation export remains available.');
end
names = [spec.stateNames spec.inputNames];
rows = zeros(nx+ny,nx+nu);
nodes = [spec.derivatives spec.outputExpressions];
labels = [strcat('der(',spec.stateNames,')') spec.outputNames];
for k = 1:numel(nodes)
    [offset, coefficients] = affine(nodes{k},names,spec.parameters,labels{k});
    if offset ~= 0
        error('fm:analysis:AffineOffset','Expression %s has nonzero constant offset %.17g; shift the operating point explicitly.',labels{k},offset);
    end
    rows(k,:) = coefficients;
end
result = struct('A',rows(1:nx,1:nx),'B',rows(1:nx,nx+1:end), ...
    'C',rows(nx+1:end,1:nx),'D',rows(nx+1:end,nx+1:end), ...
    'stateNames',{spec.stateNames},'inputNames',{spec.inputNames}, ...
    'outputNames',{spec.outputNames});
end

function [c,v] = affine(node,names,parameters,label)
c = 0; v = zeros(1,numel(names));
switch node.kind
    case 'number'
        c = node.value;
    case 'symbol'
        index = find(strcmp(names,node.value),1);
        if ~isempty(index)
            v(index) = 1;
        elseif isfield(parameters,node.value)
            c = parameters.(node.value);
        else
            error('fm:analysis:UnknownSymbol','Unknown symbol %s in %s; time-varying coefficients are unsupported.',node.value,label);
        end
    case 'unary'
        [c,v] = affine(node.args{1},names,parameters,label);
        switch node.value
            case '-'
                c = -c; v = -v;
            case '+'
            otherwise
                error('fm:analysis:UnsupportedOperation','Unsupported unary operation in %s.',label);
        end
    case 'binary'
        [a,av] = affine(node.args{1},names,parameters,label);
        [b,bv] = affine(node.args{2},names,parameters,label);
        aConstant = ~any(av); bConstant = ~any(bv);
        switch node.value
            case '+'
                c = a+b; v = av+bv;
            case '-'
                c = a-b; v = av-bv;
            case '*'
                if ~aConstant && ~bConstant
                    nonlinear(label,'product of two state/input-dependent expressions');
                end
                c = a*b; v = av*b + bv*a;
            case '/'
                if ~bConstant
                    nonlinear(label,'state/input-dependent denominator');
                end
                if b == 0
                    error('fm:analysis:DivisionByZero','Division by zero in %s after numerical parameter substitution.',label);
                end
                c = a/b; v = av/b;
            case '^'
                if ~bConstant
                    nonlinear(label,'state/input-dependent exponent');
                end
                if aConstant
                    if a == 0 && b < 0
                        error('fm:analysis:DivisionByZero','Zero raised to a negative power in %s.',label);
                    end
                    c = a^b;
                elseif b == 1
                    c = a; v = av;
                elseif b == 0
                    c = 1;
                else
                    nonlinear(label,'nonlinear power of a state/input-dependent expression');
                end
            otherwise
                error('fm:analysis:UnsupportedOperation','Unsupported binary operation in %s.',label);
        end
    case 'call'
        [a,av] = affine(node.args{1},names,parameters,label);
        if any(av)
            nonlinear(label,['function ' node.value ' applied to a state/input-dependent expression']);
        end
        switch node.value
            case 'sin'
                c = sin(a);
            case 'cos'
                c = cos(a);
            case 'exp'
                c = exp(a);
            otherwise
                error('fm:analysis:UnsupportedOperation','Unsupported function %s in %s.',node.value,label);
        end
    otherwise
        error('fm:analysis:UnsupportedOperation','Unsupported AST kind in %s.',label);
end
if ~isnumeric(c) || ~isscalar(c) || ~isreal(c) || ~isfinite(c) || ~isreal(v) || any(~isfinite(v))
    error('fm:analysis:NonfiniteResult','Expression %s produces a nonfinite or complex value/coefficient.',label);
end
c = double(c); v = double(v);
end

function nonlinear(label,reason)
error('fm:analysis:Nonlinear','Cannot establish an LTI expression for %s: %s. No linearization was performed.',label,reason);
end
