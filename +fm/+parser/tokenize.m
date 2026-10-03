function tokens = tokenize(text)
%TOKENIZE Strict scalar formula lexer (no MATLAB evaluation).
if isstring(text) && isscalar(text), text = char(text); end
if ~ischar(text) || (~isrow(text) && ~isempty(text))
    error('fm:ExpressionType','Expression must be a character row or scalar string.');
end
if isempty(strtrim(text)), error('fm:EmptyExpression','Expression cannot be empty.'); end
if numel(text)>4096, error('fm:ExpressionLength','Expression exceeds the 4096 character limit.'); end
tokens = struct('kind',{},'value',{},'position',{});
p=1;
while p<=numel(text)
    c=text(p);
    if isspace(c), p=p+1; continue; end
    tail=text(p:end);
    number=regexp(tail,'^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?','match','once');
    if ~isempty(number)
        value=str2double(number);
        if ~isfinite(value), error('fm:NumberRange','Number at position %d must be finite.',p); end
        tokens(end+1)=struct('kind','number','value',value,'position',p); %#ok<AGROW>
        p=p+numel(number); continue;
    end
    identifier=regexp(tail,'^[A-Za-z][A-Za-z0-9_]*','match','once');
    if ~isempty(identifier)
        if ~isvarname(identifier), error('fm:Identifier','Invalid identifier "%s" at position %d.',identifier,p); end
        tokens(end+1)=struct('kind','identifier','value',identifier,'position',p); %#ok<AGROW>
        p=p+numel(identifier); continue;
    end
    if any(c=='+-*/^()')
        tokens(end+1)=struct('kind',c,'value',c,'position',p); %#ok<AGROW>
        p=p+1; continue;
    end
    error('fm:UnsupportedSyntax','Unsupported character "%s" at position %d. Use scalar arithmetic and sin/cos/exp only.',c,p);
end
tokens(end+1)=struct('kind','end','value','','position',numel(text)+1);
end
