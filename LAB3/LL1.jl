using DataStructures

# Структура для представления правил грамматики
mutable struct Grammar
    P::OrderedDict{String, OrderedSet{Vector{String}}}  # Используем OrderedDict для сохранения порядка
    N::OrderedSet{String}  # Множество нетерминалов
    T::OrderedSet{String} 
    parse_table::OrderedDict{String, OrderedDict{String,OrderedSet{Vector{String}}}}
    Firsts::OrderedDict{String, OrderedSet{String}}
    Follow::OrderedDict{String, OrderedSet{String}}
end



function Grammar()
    return Grammar(
        OrderedDict(),
        Set(),
        Set(),
        OrderedDict(),
        OrderedDict(),
        OrderedDict(),
    )
end



function eliminate_left_recursion(g::Grammar,grammar)
   
    for (N, Δ) in grammar
        push!(g.N,N)
        left_recursive = []
        non_recursive = []
        g.P[N] = OrderedSet()
        g.Firsts[N] = OrderedSet()
        g.Follow[N] = OrderedSet()

        # Split productions into left-recursive and non-recursive
        for δ ∈ Δ
            if string(δ[1]) == N
                push!(left_recursive,δ[begin+1:end])
            else
                push!(non_recursive,δ)
            end
        end
        
        if !isempty(left_recursive)
            # Create a new non-terminal
            Ǹ = N * "'"
            push!(g.N,Ǹ)
            g.P[Ǹ] = OrderedSet()
            g.Firsts[Ǹ] = OrderedSet()
            g.Follow[Ǹ] = OrderedSet()
            for prod in non_recursive
                a = [prod*" "*Ǹ]
                push!(g.P[N],split(a[1]))
            end
            for prod in left_recursive
                a = [prod*" "*Ǹ]
                push!(g.P[Ǹ],split(a[1]))
            end
            push!(g.P[Ǹ],["ε"])
        else
            for δ in Δ
                push!(g.P[N],split(δ))
             end
        end
    end
end


function eliminate_right_factoring(g::Grammar)
    grammar = copy(g.P)
    empty!(g.P)
    for (N, Δ) ∈ grammar
        common_prefix = OrderedDict()
        for δ ∈ Δ  
            first_symbol = δ[1]  
            if !haskey(common_prefix,first_symbol)
                common_prefix[first_symbol] = OrderedSet{Vector{String}}()
            end
            push!(common_prefix[first_symbol],δ)
        end
        for (prefix,Δ) ∈ common_prefix
            
            if length(Δ) >1
                Ǹ = N *"`"
                if !haskey(g.P,N)
                    g.P[N] =  OrderedSet{Vector{String}}()
                end
                push!(g.P[N],split(prefix *" "*" "* Ǹ))
                if !haskey(g.P,Ǹ)
                    g.P[Ǹ] = OrderedSet{Vector{String}}()
                end
                for δ in Δ
                    push!(g.P[Ǹ],δ[2:end])
                end
            else
                if !haskey(g.P,N)
                    g.P[N] =  OrderedSet{Vector{String}}()
                end

                g.P[N] = g.P[N] ∪ Δ
            end

        end
    end

end


function find_first(g::Grammar)
   
    # Вспомогательная функция для получения First для символа
    function get_first(symbol)
        if !isuppercase(symbol[1])  # Если символ - терминал
            return OrderedSet([symbol])  # Возвращаем терминал как Set
        end
        return g.Firsts[symbol]  # Для нетерминала возвращаем его множество First
    end
    # Инициализация множества First для каждого правила продукции
    for (N, Δ) ∈ g.P, δ ∈ Δ
        if !isuppercase(δ[1][1]) # Если первый символ - терминал  
            push!(g.Firsts[N], δ[1])  # Добавляем терминал в First(T)
        end
    end
    changed = true
    while changed
        changed = false
        for (N, Δ) ∈ reverse(collect(g.P)), δ ∈ Δ
            cop = copy(g.Firsts[N])
            for symbol in δ   
                first_set_symbol = get_first(symbol)
                
                g.Firsts[N] = setdiff(g.Firsts[N] ∪ first_set_symbol, OrderedSet(["ε"]))  # Обновляем First(T)
                if "ε" ∉ first_set_symbol  # Если первый символ не ε, то прерываем
                    break
                end
            end
            if all(symbol -> in("ε", get_first(symbol)), δ)
                push!(g.Firsts[N], "ε")  # Если все символы приводят к ε, добавляем ε в First(T)
            end
            if g.Firsts[N] != cop
                changed = true
            else
                changed = false
            end   
        end
    end
end


function find_follow(g::Grammar)
    g.Follow["E"] = g.Follow["E"] ∪  ["%"]
   
    function get_follow(T,δ,Nδ,changed)
        for N ∈ Nδ
            index = findfirst(c -> c == N, δ)
            cop = copy(g.Follow[N])
            if index != length(δ)    
                γ = δ[index+1]
                if γ == "ε"
                g.Follow[N] =g.Follow[N] ∪ g.Follow[T]
                elseif γ ∈ g.T  
                    g.Follow[N] = g.Follow[N] ∪ OrderedSet([γ])
                else        
                    g.Follow[N] = setdiff(g.Follow[N] ∪ g.Firsts[γ], ["ε"])  # Обновляем First(T)
                    if "ε" in  g.Firsts[γ]             
                        g.Follow[N]= g.Follow[N] ∪ g.Follow[T]
                    end
                end
            else
                g.Follow[N] = g.Follow[N] ∪ g.Follow[T]
            end
            changed = cop != g.Follow[N]  
        end
        return changed
    end

    changed = true
    while changed
        for (A, Δ) ∈ (g.P), δ ∈ Δ 
            Nδ = OrderedSet()
            for symbol ∈ δ
                if symbol ∈ g.N
                    push!(Nδ,symbol)
                elseif !isuppercase(symbol[1])
                    push!(g.T,symbol)
                end
            end
            changed = get_follow(A,δ,Nδ,changed) 
        end
    end
end


function create_parser_table(g::Grammar)
    g.T = g.T ∪ ["%"]
    for N ∈ g.N
        g.parse_table[N] =  Dict(T => OrderedSet() for T in g.T)
    end    
    # Fill the parsing table
    for (N, Δ) ∈ g.P, δ in Δ
        symbol = δ[1]
        if symbol ∈ g.T && symbol≠ "ε"
            if  isempty(g.parse_table[N][symbol])
                push!(g.parse_table[N][symbol],δ)
            end
        elseif symbol ∈ g.N
            for FT ∈ g.Firsts[symbol]
                if FT ∈ g.T && FT ≠ "ε" && isempty(g.parse_table[N][FT])  
                    push!(g.parse_table[N][FT],δ)   
                end
            end
        else
            for T ∈ g.Follow[N]
                if T ∈ g.T && T ≠ "ε"
                    # Only add the rule if it isn't already added for the terminal
                    if isempty(g.parse_table[N][T])                      
                        push!(g.parse_table[N][T],δ)
                    end
                end
            end
        end
    end
end

function parse_word(g::Grammar,input_string)
    stack = Stack{String}()
    push!(stack,first(g.N))
    input_string = split(input_string)
    while !isempty(stack) && !isempty(input_string)
        top = pop!(stack)
        if top ∈ g.N
            if input_string[1] ∈ g.T && !isempty(g.parse_table[top][input_string[1]])
                for Δ ∈ g.parse_table[top][input_string[1]]
                    A =  reverse(Δ)
                    for  δ ∈ A
                        if δ ∈ g.N || (δ != input_string[1] && δ != "ε")
                            push!(stack,δ)
                        elseif δ == input_string[1]
                            popfirst!(input_string)
                        end
                    end
                end
            else
                println("Error: Non-termianl ",top," don't handle termianl: ",input_string[1])
                return false
            end
        else
            if top != input_string[1]
                println("Error: expected terminal: ",top," got terminal: ",input_string[1])
                return false
            else
                popfirst!(input_string)
            end
        
        end
    end
    return true
end






function main()
    g = Grammar()
    grammar = OrderedDict(
    "E" => ["E + T" , "T"],
    "T" => ["T * F", "F"],
    "F" => ["n", "( E )"]
    )
    eliminate_left_recursion(g,grammar)
    eliminate_right_factoring(g)
    find_first(g)
    for A ∈ g.N
        println(g.Firsts[A],A)
    end
  
    println()
    find_follow(g)
    for A ∈ g.N
        println(g.Follow[A],A)
    end
   
    create_parser_table(g)
 
    for (key, inner_dict) in g.parse_table
        println("Key: $key")
        for (inner_key, inner_set) in inner_dict
            println("  Inner Key: $inner_key => Set: $inner_set")
        end
    end
    println()
    
    input_string = "n  * ( n + n )"
    println()
    println(parse_word(g,input_string))
    
end
main()