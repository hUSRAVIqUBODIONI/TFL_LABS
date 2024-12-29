using DataStructures

# Структура для представления правил грамматики
mutable struct Grammar
    P::OrderedDict{String, OrderedSet{Vector{String}}}  # Используем OrderedDict для сохранения порядка
    N::OrderedSet{String}  # Множество нетерминалов
    T::OrderedSet{String} 
    parse_table::OrderedDict{String, OrderedDict{String, OrderedSet{Vector{String}}}}
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


function parse_grammar(grammar_str::String)
    # Initialize an empty dictionary for the grammar
    grammar_dict = OrderedDict{String, Vector{String}}()

    # Split the grammar into individual rules based on newlines
    rules = split(grammar_str, "\n")

    # Process each rule
    for rule in rules
        # Skip empty lines (if any)
        if isempty(rule)
            continue
        end
        
        # Split the rule into left-hand side (non-terminal) and right-hand side (productions)
        lhs_rhs = split(rule, "->")
        if length(lhs_rhs) != 2
            continue  # skip invalid rules
        end
        
        lhs = strip(lhs_rhs[1])  # Non-terminal symbol (e.g., "S")
        rhs = strip(lhs_rhs[2])  # Productions (e.g., "S X0 | G0 X2")
        
        # Split the right-hand side by the "|" symbol to handle multiple productions
        productions = split(rhs, "|")
        
        # Trim spaces from each production and store it in the dictionary
        if haskey(grammar_dict, lhs)
            push!(grammar_dict[lhs], [strip(p) for p in productions])
        else
            grammar_dict[lhs] = [strip(p) for p in productions]
        end
    end

    return grammar_dict
end

function eliminate_left_recursion(g::Grammar,grammar)
    for (N, Δ) in grammar
        push!(g.N,N)
        left_recursive = []
        non_recursive = []
        g.P[N] = OrderedSet()
        g.Firsts[N] = OrderedSet()
        g.Follow[N] = OrderedSet()
        g.parse_table[N] = OrderedDict()
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
            g.parse_table[Ǹ] = OrderedDict()
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
                g.parse_table[Ǹ] = OrderedDict()
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
    return result
end

function First_k(grammar::Grammar)
    changed = true
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
    push!(g.Follow[first(g.N)],"%")
    function get_follow(g::Grammar,beta)
        result = OrderedSet(["ε"])
        if isempty(beta)
            return result
        end
        for symbol ∈ beta
            new_result = OrderedSet()
            for prefix ∈ result
                combined_prefix = (prefix == "ε") ? "" : prefix
                get!(g.Firsts, symbol, OrderedSet())
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


function look_k(g::Grammar,N,δ)
    first_k_of_δ = find_first(g,δ)
    follow = OrderedSet()
    for prefix in first_k_of_δ
        prefix == "ε" ? (follow = follow ∪ g.Follow[N]) : push!(follow, prefix)
    end
    if N =="A"
        println("\t",N,follow)
    end
    return follow
end





function create_parser_table(g::Grammar)
    g.T = g.T ∪ ["%"]
    
    for (N,Δ) ∈ g.P, δ ∈ Δ
        look_k_δ = look_k(g,N,δ)
        if length(look_k_δ) >0
            for w ∈ look_k_δ
                push!(get!(g.parse_table[N], w, OrderedSet()),δ)
            end
        end
    end
end





function parse_word(g::Grammar,input_string)
    stack = Stack{String}()
    push!(stack,first(g.N))
    input_string = split(input_string*" %")
    while !isempty(stack)
        top = pop!(stack)
        cur_input = join(input_string[1:g.k])
      
        
        if top ∉ g.N
            if !isempty(input_string) && top == input_string[1]
                println("Терминал $(top) совпал с символом из входной строки $(input_string)")
                popfirst!(input_string)
                println("Входная строка = $(input_string) Стек = $(stack)")
            else
                println("Error: Терминал $(top) несовпал с символом из входной строки $(input_string)")
                return false
            end
        else
            rule_found = false
            for i ∈ length(cur_input):-1:1
                # Get the possible productions from the parse table
                
                possible_productions = get(g.parse_table[top], cur_input[1:i], [])
                
                if !isempty(possible_productions)
                    chosen_production = possible_productions[1]  # LL(1) → take the first production
                    println("Применяем правило: $(top) -> $(chosen_production)")
                    
                    if chosen_production != ["ε"]
                        # Extend the stack with the reversed production
                        for element in reverse(chosen_production)
                            push!(stack, element)
                        end
                    end
                    rule_found = true
                    break
                end
            end
            
            # If no rule was found, log the error
            if !rule_found
                println("ERROR: нет правила для ($top, '$cur_input').")
                return false
            end

        end
    end
    if input_string != ["%"]
        println("Error: стек пуст, но во входе осталось $(input_string)")
        return false
    end
    return true
end


function main()
    g = Grammar(2)
   
            
 

    grammar_str = """
    S -> P2 W1 | L3 T1
    A -> b
    C_9 -> ε
    W1 -> P2 P2 | A Z2
    B2 -> L3 P2
    P2 -> a
    Z2 -> P2 P2
    T1 -> L3 P2 |  A B2
    L3 -> b
    """
   

    #=           k=2
    grammar_str = """
    S -> G0 X0 | G1 X2
    G1 -> e
    G2 -> b
    X1 -> G2 S
    G3 -> p
    G4 -> s
    G0 -> a
    X0 -> S X1
    X2 -> G3 G4
    """

    grammar_str = """    
    S -> P_2 W1
    S -> L_3 T1
    A -> b
    C_9 -> ε
    W1 -> P_2 P_2
    W1 -> A Z2
    B2 -> L_3 P_2
    P_2 -> a
    Z2 -> P_2 P_2
    T1 -> L_3 P_2
    T1 -> A B2
    L_3 -> b
     

 
    grammar_str = """ k =1 
    S -> S + T | T
    T -> T * F | F
    F -> ( S ) | n
    """
  =#   

    input_string = "a b a a"
    grammar =  parse_grammar(grammar_str)
    eliminate_left_recursion(g,grammar)
    println("\tAfter eliminating left recursion")
    for (inner_key, inner_set) in g.P
        println(" Key: $inner_key => $inner_set")
    end
    println()
    println("\tAfter eliminating right factoring")
    eliminate_right_factoring(g)
    for (inner_key, inner_set) in g.P
        println(" Key: $inner_key => $inner_set")
    end
    println()
    g.Firsts["ε"] = OrderedSet{String}(["ε"])
   
    First_k(g)
    println("\t First_",g.k," sets")
    for A ∈ g.N
        println(g.Firsts[A],A)
    end
  
    
    println()
    println("\t Follow_",g.k," sets")
    find_follow(g)
    for A ∈ g.N
        println(g.Follow[A],A)
    end
   
    println()
    create_parser_table(g)
    
 

    for (key, inner_dict) in g.parse_table
        println("Non-terminal: $key")
        for (inner_key, productions) in inner_dict
            println("  Terminal: $inner_key => Productions: $productions")
        end
    end
    
    println()
    
    
    
    
    println(parse_word(g,input_string))
    
   
end
main()