using DataStructures

# Структура для представления правил грамматики
mutable struct Grammar
    P::OrderedDict{String, OrderedSet{Vector{String}}}  # Используем OrderedDict для сохранения порядка
    N::OrderedSet{String}  # Множество нетерминалов
    T::OrderedSet{String} 
    parse_table::OrderedDict{String, OrderedDict{String,OrderedSet{Vector{String}}}}
    Firsts::OrderedDict{String, OrderedSet{String}}
    Follow::OrderedDict{String, OrderedSet{String}}
    k::Int
end



function Grammar(k::Int)
    return Grammar(
        OrderedDict(),
        Set(),
        Set(),
        OrderedDict(),
        OrderedDict(),
        OrderedDict(),
        k,
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
            if length(δ) ==0
                first_symbol = "ε"
            else
                first_symbol = δ[1]  
            end       
            if !haskey(common_prefix,first_symbol)
                common_prefix[first_symbol] = OrderedSet{Vector{String}}()
            end
            push!(common_prefix[first_symbol],δ)
        end
        for (prefix,Δ) ∈ common_prefix
            
            if length(Δ) >1
                Ǹ = N *"`"
                g.Firsts[Ǹ] = OrderedSet()
                g.Follow[Ǹ] = OrderedSet()
                push!(g.N,Ǹ)
                if !haskey(g.P,N)
                    g.P[N] =  OrderedSet{Vector{String}}()
                   
                end
                push!(g.P[N],split(prefix *" "* Ǹ))
                if !haskey(g.P,Ǹ)
                    g.P[Ǹ] = OrderedSet{Vector{String}}()
                end
                for δ in Δ
                    if length(δ) ==1
                        push!(g.P[Ǹ],["ε"])
                    else
                        push!(g.P[Ǹ],δ[2:end])
                    end
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

function First_k(grammar::Grammar)
    changed = true
    function find_first(grammar::Grammar,Δ)
        prefixes = Set(["ε"])

        for a ∈ Δ
            new_prefixes = OrderedSet()
            if a == "ε"
                new_prefixes = new_prefixes ∪ prefixes
                
                prefixes = new_prefixes
                break
            end
            if a ∉ grammar.N
                push!(grammar.T,a)
                grammar.Firsts[a] = Base.get(grammar.Firsts, a, OrderedSet{String}([a]))
                expansions = OrderedSet(a)
            else
                expansions = grammar.Firsts[a]
                println("|||||\t",expansions)
            end
            if !isempty(expansions)
                for prefix ∈ prefixes
                    combined_prefix = (prefix == "ε") ? "" : prefix
                    if length(combined_prefix) >=grammar.k
                        push!(new_prefixes, combined_prefix[1:grammar.k])
                        continue
                    end
                    for expansion in expansions
                        if expansion == "ε"
                            # Не добавляем ничего, продолжаем
                            push!(new_prefixes, isempty(combined_prefix) ? "ε" : combined_prefix)
                        else
                            combined = combined_prefix * expansion
                          
                            println("\t----",combined)
                            push!(new_prefixes,(length(combined) >= grammar.k ? combined[1:grammar.k] : combined))
                        end
                    end
                end
            else
                new_prefixes = OrderedSet()
            end
            prefixes = new_prefixes
            if all(length(prefix) >= grammar.k for prefix in prefixes)
                break
            end
           
            
        end
        result =  OrderedSet(p for p in prefixes if length(p) <= grammar.k || p == "ε")
        println("res: ",result)
        return result
    end
    
    while changed
        changed = false
        for N ∈ grammar.N, Δ ∈ grammar.P[N] 
            first_k = find_first(grammar,Δ)
            for δ ∈ first_k
                if δ ∉ grammar.Firsts[N]
                    push!(grammar.Firsts[N],δ)
                    changed = true
                end
            end
        end
    
    end
end



function find_follow(g::Grammar)
    changed = true
    push!(g.Follow["S"],"%")
    function get_follow(g::Grammar,beta)
        result = OrderedSet(["ε"])
        if isempty(beta)
            return result
        end
        for symbol ∈ beta
            new_result = OrderedSet()
            for prefix ∈ result
                combined_prefix = (prefix == "ε") ? "" : prefix
                for s ∈ g.Firsts[symbol]
                    if s == "ε"
                        push!(new_result, isempty(combined_prefix) ? "ε" : combined_prefix)
                    else
                        combined = combined_prefix*s
                        push!(new_result,(length(combined) >= g.k ? combined[1:g.k] : combined))
                    end
                end
            end
            result = new_result
        end
        if all("ε" ∈ g.Firsts[symbol] for symbol in beta)
            push!(result,"ε")
        end
        result =  OrderedSet(p for p in result if length(p) <= g.k || p == "ε")
        return result
    end
    
    while changed
        changed = false
        for (N, Δ) ∈ g.P,δ ∈ Δ
            for (i, B) in enumerate(δ) 
                if B ∈ g.N
                    beta = δ[i + 1:end]
                    first_beta = get_follow(g,beta)
                    before = length(g.Follow[B])
    
                        # Add FIRST_k(beta) without 'ε'
                    for fb in first_beta
                        if fb != "ε"
                            push!(g.Follow[B], fb[1:min(g.k, end)])
                        end
                    end
    
                        # If FIRST(beta) contains 'ε' or beta is empty, add FOLLOW(A)
                    if "ε" in first_beta || isempty(beta)
                        for fN in g.Follow[N]
                            push!(g.Follow[B], fN[1:min(g.k, end)])
                        end
                    end
    
                    after = length(g.Follow[B])
                    if after > before
                        changed = true
                    end
                end
            end
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
        if length(δ) ==0
            break
        end
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
    if !isempty(stack) || !isempty(input_string)
    return true
    end
end

function main()
    g = Grammar(2)
   
  
    grammar = OrderedDict(
        "S" => ["H0 S" , "a"],
        "H0" => ["H2 H1"],
        "H1" => ["b"],
        "H2" => ["H3 S"],
        "H3" => ["a"]
        )
     #=

    
    OrderedSet{String}(["%", "b"])S
    OrderedSet{String}(["a", "aa"])H0
    OrderedSet{String}(["a", "aa"])H1
    OrderedSet{String}(["b"])H2
    OrderedSet{String}(["a", "aa"])H3

    grammar = OrderedDict(
        "E" => ["E + T" , "T"],
        "T" => ["T * F", " F "],
        "F" => ["( E )", " n "]
        )

     =#
    eliminate_left_recursion(g,grammar)
    
    for (inner_key, inner_set) in g.P
        println(" Key: $inner_key => $inner_set")
    end
    println()
    println()
    eliminate_right_factoring(g)
    for (inner_key, inner_set) in g.P
        println(" Key: $inner_key => $inner_set")
    end
    println()
    g.Firsts["ε"] = OrderedSet{String}(["ε"])
   
    First_k(g)

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
    
    #input_string = "a a a a a a a a a a a a a a a c c c c c d d"
    input_string ="n + ( n * ( n + n) )"
    println()
    println(parse_word(g,input_string))
   
end
main()