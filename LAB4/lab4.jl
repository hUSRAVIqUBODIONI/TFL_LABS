using DataStructures

# Определяем структуру Token
mutable struct Token
    type::String
    val::Union{String, Int, Nothing}
end

# Определяем структуру Lexer
mutable struct Lexer
    pos::Int
    text::String
    tokens::Vector{Token}
end



# Конструктор для Lexer
function Lexer(text::String)
    return Lexer(1, text, Token[])  # Начальная позиция = 1, текст, пустой вектор токенов
end

# Функция получения текущего символа
function get(lexer::Lexer)
    if lexer.pos <= length(lexer.text)
        return lexer.text[lexer.pos]
    end
    return nothing  # Если конец строки, возвращаем nothing
end

# Функция для лексического анализа
function tokenize(lexer::Lexer)
    while lexer.pos <= length(lexer.text)
        c = get(lexer)  # Получаем текущий символ
        
        # Пропускаем пробелы
        if isspace(c)
            lexer.pos += 1
        # Обрабатываем идентификаторы (буквы)
        elseif isletter(c)
            lexer.pos += 1
            push!(lexer.tokens, Token("CHAR", string(c)))

        # Обрабатываем символы '(' и     (?:) or (?1,2,3,4)
        elseif c == '('
            lexer.pos += 1
            next = get(lexer)
            if next == '?'
                lexer.pos += 1
                next2 = get(lexer)
                if next2 == ':'
                    lexer.pos += 1
                    push!(lexer.tokens, Token("NON_GROUP_OPEN", nothing))
                elseif next2 in '1':'9'
                    lexer.pos += 1
                    push!(lexer.tokens, Token("REF_GROUP_OPEN", Base.parse(Int, string(next2))))
                else
                    error("Неизвестный символ после ? ожидалось ':' или число, получили $next2")
                end    
            else
                push!(lexer.tokens, Token("GROUP_OPEN", nothing)) 
            end 
        elseif c == ')'
            lexer.pos += 1
            push!(lexer.tokens, Token("CLOSE", nothing))
        elseif c == '*'
            lexer.pos += 1
            push!(lexer.tokens, Token("STAR", nothing))
        elseif c == '/'
            lexer.pos += 1
            next = get(lexer)
            if next in '1':'9'
                lexer.pos += 1
                push!(lexer.tokens, Token("REF_STR", Base.parse(Int, string(next))))
            else
                error("Неизвестный символ после / ожидалось число, получили $next")
            end
        elseif c == '|'
            lexer.pos += 1
            push!(lexer.tokens, Token("ALTER", nothing))
        else
        # Если символ не распознан
            error("Неизвестный символ $c")
        end
    end
end

# Структуры для AST (дерева синтаксического разбора)
struct GroupNode 
    id::Int 
    node 
end
struct RefStrNode
    id::Int 
end
struct RefGroupNode 
    id::Int
    in_groups::Vector{Int}
end
struct NonGroup node end
struct StarNode node end
struct CharNode char::String end
struct AlterNode nodes::Vector end
struct UnionNode nodes::Vector end



# Структура парсера
mutable struct Parser
    pos::Int
    tokens::Vector{Token}
    init_group::Vector{Any}
    open_bracket::Vector{Int}
    groups::Int
    max_groups::Int
    ast::OrderedDict{}
    ref_str::OrderedDict{}
    
end

function get(parser::Parser)
    return parser.pos <= length(parser.tokens) ? parser.tokens[parser.pos] : nothing
end

function check(parser::Parser,type)
   token = get(parser)
   isnothing(token) && throw("Неожиданный конец выражения")
   type !== nothing && token.type ≠ type && throw("Ожидается $type, найдено $(token.type)")
   parser.pos +=1
   return token
end

function parse(parser::Parser)
    node = AltParser(parser)
    get(parser) !==nothing  && throw("Лишние символы после корректного выражения")
    
    ParseNodes(parser,node,Set(),false)

    return node
end

function AltParser(parser::Parser)
    nodes = Vector{Any}()
    push!(nodes,UnionParse(parser))
    while get(parser) !==nothing && get(parser).type =="ALTER"
        check(parser,"ALTER")
        isnothing(get(parser)) || get(parser).type ∈ ["ALTER","CLOSE"]  && throw("Неожиданный конец выражения")
        next_node = UnionParse(parser)
        push!(nodes,next_node)
    end

    return length(nodes) == 1 ? nodes[1] : AlterNode(nodes)
end

function UnionParse(parser::Parser)
    nodes = []
    while get(parser) !==nothing && get(parser).type ∉ ["ALTER","CLOSE"]
       push!(nodes, StarParse(parser))
    end
    return length(nodes) == 1 ? nodes[1] : UnionNode(nodes)
end

function StarParse(parser::Parser)
    node = BracketParse(parser)
    while get(parser) !==nothing && get(parser).type == "STAR"
        check(parser,"STAR")
        node = StarNode(node)
    end
    return node
end

function BracketParse(parser::Parser)
    token = get(parser)
    isnothing(token) && throw("Неожиданный конец выражения при ожидании базового выражения")
    if token.type == "GROUP_OPEN"
        check(parser,"GROUP_OPEN")
        parser.groups +=1
        
        parser.groups > parser.max_groups  && throw("Количество групп $(parser.groups) превышает $(parser.max_groups)")
        id = parser.groups
        push!(parser.open_bracket,parser.groups)
        node = AltParser(parser)
        check(parser,"CLOSE")
        pop!(parser.open_bracket)
        parser.ast[id] = node
        return GroupNode(id,node)
    
    elseif token.type =="NON_GROUP_OPEN"
        check(parser,"NON_GROUP_OPEN")
        node = AltParser(parser)
        check(parser,"CLOSE")
        return NonGroup(node)
    
    elseif  token.type == "REF_GROUP_OPEN"
        check(parser,"REF_GROUP_OPEN")
        check(parser,"CLOSE")
        return  RefGroupNode(token.val,copy(parser.open_bracket))

    elseif token.type == "CHAR"
        check(parser,"CHAR")
        return CharNode(token.val)

    elseif token.type == "REF_STR"
        token.val ∈ parser.open_bracket  && throw("группа $(token.val) ещё не дочитана до конца к моменту обращения к ней")
        check(parser,"REF_STR")
        parser.ref_str[token.val] = Base.get(parser.ref_str, token.val, [])
        parser.ref_str[token.val] = vcat(parser.ref_str[token.val],parser.open_bracket)
        return RefStrNode(token.val)
    else
        throw("Некорректный токен: $(token)")
    end
end


function ParseNodes(parser,node,defined_groups,in_alt)
    
    if isa(node,CharNode) || isa(node,RefStrNode)
        return defined_groups

    elseif isa(node,RefGroupNode)
        check_is_init(parser,node)  && throw("Ссылка на группу $(node.id) ещё не дочитана до конца к моменту обращения к ней")
        return defined_groups


    elseif isa(node,GroupNode)
        if in_alt
            push!(parser.init_group,node.id)
        end
        new_defined_groups = ParseNodes(parser,node.node,defined_groups,in_alt)
        push!(new_defined_groups,node.id)
        return new_defined_groups

    elseif isa(node,NonGroup) || isa(node,StarNode)
        return ParseNodes(parser,node.node,defined_groups,in_alt)

    elseif isa(node,UnionNode)

        current_defined = defined_groups
        for child ∈ node.nodes 
            current_defined = ParseNodes(parser,child,current_defined,in_alt)
        end 
        return current_defined  

    elseif isa(node,AlterNode)
        all_sides = Vector()
        for child ∈ node.nodes
            in_alt = true 
            child_sides = ParseNodes(parser,child,defined_groups,in_alt)
            all_sides = all_sides ∪ child_sides
        end
        in_alt = false
        return all_sides
    else
        throw("Неизвестный тип узла AST при проверке ссылок")
    end
end

function check_is_init(parser::Parser,node)

    if isempty(parser.ref_str)
        return false
    end
    for (key,value) in parser.ref_str
        if key ∈ node.in_groups && node.val ∈ value && !empty(value)
            return true
        end
    end
    return false
    
end




mutable struct CFG
    ast::OrderedDict
    init_group::Vector{Any}
    C::Int
    NG::Int
    S::Int
    rules::OrderedDict{}
    N::OrderedDict{}
end

function CreateCFG(cfg::CFG,node,Start)
  
    N = Cfg(cfg,node,nothing)
    cfg.rules[Start] = [[N]]
    
end

function Cfg(cfg::CFG,node,start)
    if isa(node,CharNode) 
        
        Ǹ =  start !==nothing ? start : "CH"*string(cfg.C)
        cfg.C +=1
        if !haskey(cfg.rules, Ǹ)
            cfg.rules[Ǹ] = []  # если нет ключа nt, инициализируем его пустым массивом
        end
        # Добавляем новый элемент (в нашем случае список с одним элементом)
        push!(cfg.rules[Ǹ], [node.char])
        return Ǹ

    elseif isa(node,RefStrNode) 
        str_id = node.id
        if !haskey(cfg.ast,str_id)
            throw("Ссылка на несуществующую строку")
        elseif str_id  ∈ cfg.init_group
            throw("Ссылка на не инициализированную строку")
        end
        if !haskey(cfg.N,str_id)
            cfg.N[str_id] = "RF"*string(str_id)
            # Строим правила для группы ref_id
            sub_Ǹ = Cfg(cfg,cfg.ast[str_id], nothing)
            Ǹ = cfg.N[str_id]
            # sub_nt уже построен выше:
            cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
            push!(cfg.rules[Ǹ], [sub_Ǹ])
        end
        return cfg.N[str_id]

    elseif  isa(node,RefGroupNode)
        str_id = node.id
       
        if !haskey(cfg.N,str_id)
            
            cfg.N[str_id] = "GR"*string(str_id)
            if !haskey(cfg.ast,str_id)
                throw("Ссылка на несуществующую группу")
            end
            # Строим правила для группы ref_id
            sub_Ǹ = Cfg(cfg,cfg.ast[str_id], nothing)
            Ǹ = cfg.N[str_id]
            # sub_nt уже построен выше:
            cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
            push!(cfg.rules[Ǹ], [sub_Ǹ])
        end
        return cfg.N[str_id]

    elseif isa(node,GroupNode)
        Ǹ = Base.get(cfg.N, node.id, nothing)
        if Ǹ === nothing
            Ǹ = "G"*string(node.id)
            cfg.N[node.id] = Ǹ
        end
        sub_Ǹ = Cfg(cfg,node.node, nothing)
        cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
        push!(cfg.rules[Ǹ], [sub_Ǹ])
        return Ǹ

    elseif isa(node,NonGroup) 
        # Генерируем новый нетерминал для незахватывающей группы
        Ǹ =  start !== nothing ? start : "N"*string(cfg.NG)
        cfg.NG +=1
        sub_Ǹ = Cfg(cfg,node.node, nothing)

        cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
        push!(cfg.rules[Ǹ], [sub_Ǹ])
        return Ǹ

    elseif  isa(node,StarNode)
       # Звёздочка: X* означает 0 или более повторений X
            # Создаём нетерминал для звёздочки
        Ǹ =  start !== nothing ? start : "ST"*string(cfg.S)
        cfg.S +=1
        sub_Ǹ = Cfg(cfg,node.node, nothing)
        # R -> ε | R sub_nt
        cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
        push!(cfg.rules[Ǹ], [sub_Ǹ])
        return Ǹ

    elseif isa(node,UnionNode)

        Ǹ =  start !== nothing ? start : "C"*string(cfg.NG+cfg.C)

        cfg.NG+=1
            # Конкатенация: nodes - список узлов
            # Преобразуем каждый узел в нетерминал, потом nt -> seq
            # Если узел терминальный, node_to_cfg вернёт нетерминал с одним правилом
        seq_Ǹs = [Cfg(cfg,ch, nothing) for ch in node.nodes]
        cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
        push!(cfg.rules[Ǹ], [seq_Ǹs])

        return Ǹ

    elseif isa(node,AlterNode)

        Ǹ =  start !== nothing ? start : "A"*string(cfg.NG+cfg.C)

        cfg.NG+=1
            # Альтернатива: для каждой ветви генерируем правило
        for nod ∈ node.nodes
            br_Ǹ = Cfg(cfg,nod, nothing)
            cfg.rules[Ǹ] = Base.get(cfg.rules, Ǹ, [])
            push!(cfg.rules[Ǹ], [br_Ǹ])
        end

        return Ǹ
    else
        throw("Неизвестный тип узла AST при проверке ссылок")
    end
    
end

# Основная функция
function main()
    println("Введите регулярное выражение:")
    text = readline()  # Считывает строку
    lexer = Lexer(text)
    tokenize(lexer)
    println()
    for token in lexer.tokens
        println("$(token.type), $(token.val)")
    end
    println()
    parser = Parser(1,lexer.tokens,Vector(),Vector{Int}(),0,9,OrderedDict(),OrderedDict())
    node = parse(parser)

    
    cfg = CFG(parser.ast,parser.init_group,1,1,1,OrderedDict(),OrderedDict())
    CreateCFG(cfg,node,"S")
    for (nt, rhs_list) in cfg.rules
        for rhs in rhs_list
            rhs_str = isempty(rhs) ? "ε" : join(rhs, " ")
            println("$nt -> $rhs_str")
        end
    end
    println("="^60)
end
main()