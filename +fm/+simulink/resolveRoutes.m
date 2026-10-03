function routes = resolveRoutes(blocks, types, model)
%RESOLVEROUTES Resolve local/scoped/global tags without updating the model.
% Overlapping scopes are deliberately rejected, not guessed or shadowed.
gotos=blocks(strcmp(types,'Goto')); froms=blocks(strcmp(types,'From'));
vis=blocks(strcmp(types,'GotoTagVisibility'));
scopes=cell(size(gotos)); tags=cell(size(gotos)); modes=cell(size(gotos));
for k=1:numel(gotos)
    b=gotos{k}; tags{k}=get_param(b,'GotoTag'); modes{k}=get_param(b,'TagVisibility');
    parent=get_param(b,'Parent');
    switch modes{k}
        case 'local', scopes{k}=parent;
        case 'global', scopes{k}=model;
        case 'scoped'
            candidates={};
            for j=1:numel(vis)
                vparent=get_param(vis{j},'Parent');
                if strcmp(tags{k},get_param(vis{j},'GotoTag')) && within(parent,vparent), candidates{end+1}=vparent; end %#ok<AGROW>
            end
            if isempty(candidates),error('fm:RoutingScope','%s：scoped tag %s 缺少上级 Goto Tag Visibility。',b,tags{k});end
            lens=cellfun(@numel,candidates); nearest=candidates(lens==max(lens));
            if numel(nearest)~=1,error('fm:AmbiguousRouting','%s：tag %s 存在重复的作用域声明。',b,tags{k});end
            scopes{k}=nearest{1};
    end
end
for k=1:numel(gotos)
    for j=k+1:numel(gotos)
        if ~strcmp(tags{k},tags{j}),continue;end
        if strcmp(modes{k},'local'), overlap=visible(j,scopes{k});
        elseif strcmp(modes{j},'local'),overlap=visible(k,scopes{j});
        else,overlap=within(scopes{k},scopes{j})||within(scopes{j},scopes{k});end
        if overlap,error('fm:AmbiguousRouting','tag %s 的可见范围重叠：%s；%s。请使用无歧义的路由。',tags{k},gotos{k},gotos{j});end
    end
end
routes=containers.Map('KeyType','char','ValueType','char');
for k=1:numel(froms)
    b=froms{k}; tag=get_param(b,'GotoTag'); parent=get_param(b,'Parent'); candidates=[];
    for j=1:numel(gotos),if strcmp(tags{j},tag)&&visible(j,parent),candidates(end+1)=j;end,end %#ok<AGROW>
    if isempty(candidates),error('fm:UnresolvedRouting','%s：找不到当前作用域中 tag %s 对应的 Goto。',b,tag);end
    if numel(candidates)~=1,error('fm:AmbiguousRouting','%s：tag %s 匹配多个 Goto。',b,tag);end
    routes(b)=gotos{candidates};
end
    function yes=visible(index,parent)
        if strcmp(modes{index},'local'),yes=strcmp(parent,scopes{index});
        else,yes=within(parent,scopes{index});end
    end
end
function yes=within(parent,scope)
yes=strcmp(parent,scope)||startsWith(parent,[scope '/']);
end
