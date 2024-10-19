alphabet = ("L","R")
sufix_list = Vector{String}(["e"])
prefix_list = Vector{String}(["e","L","R"])
array_3d = fill("-", (3,1))
status = false #если false продолжать строить таблицу #true мы всё совпало
itorations = 2



function main()
    global itorations
    fill_table() #Заполняем первоначальную таблицу
    
        eqvivolent()
        Add_Prefix(itorations,2,"R","L")
        Add_Prefix(itorations,2,"L","R")
        fill_table(length(prefix_list)-3)
        Print_Table()
        itorations +=1
    
end

function Add_Prefix(n, count,first_letter,last_letter)
    global prefix_list
    if n == 0
        return [""]
    end
    
    combinations = String[]
    for combo in Add_Prefix(n - 1, count,first_letter,last_letter)
        if length(combinations) < count
            push!(combinations, first_letter * combo)
           
        end
        if length(combinations) < count
            push!(combinations, last_letter * combo)
         
        end
        if length(combinations) >= count
            break
        end
    end
    prefix_list = union(prefix_list,combinations)
    return combinations
end

function fill_table()
    pl = length(prefix_list)
    sl = length(sufix_list)
    for p_id in 1:pl,s_id in 1:sl
        array_3d[p_id,s_id] = MemberShip(prefix_list[p_id],sufix_list[s_id])
    end
    
end

function fill_table(start_index,len_of_Newtable)
    global array_3d
    pl = length(prefix_list)
    println()
    array = fill("-", (pl,len_of_Newtable))
    println(array)
    for p_id in 1:pl, s_id in 1:len_of_Newtable
        array[p_id,s_id] = MemberShip(prefix_list[p_id],sufix_list[start_index+s_id])
    end
    println(array_3d)
    array_3d = hcat(array_3d,array)
    println(array_3d)
    
end

function fill_table(start_index)
    global array_3d
    sl = length(sufix_list)
    array = fill("-",(4,sl))
    index = 1
  
    for p_id in start_index:start_index+3
        for s_id in 1:sl
        array[index,s_id] = MemberShip(prefix_list[p_id],sufix_list[s_id])
        end
        index +=1
    end
    array_3d = vcat(array_3d,array)
end


function MemberShip(prefix,sufix)
    println("Is ",prefix," and ",sufix," in Lenguage?") 
    name = readline() 
    return name
end




function eqvivolent()
    global status  # Access the global status variable
    Print_Table()  
    println("Is it OK? (Type 'Finish' to confirm)")
    ConPrimer = readline()
    if ConPrimer == "Finish"
        status = true
        return
    else
        Add_ContPrimer(ConPrimer)  # Assuming this function is defined elsewhere
    end
end



function Add_ContPrimer(ConPrimer)
    last_index = length(sufix_list)      #Сохраняем старую длину суффиксов
    for l in 1:length(ConPrimer)
        push!(sufix_list,last(ConPrimer,l))   # Добавляем все суффиксы контр-примера в списаок суффиксов LLRL = L, RL, LRL, LLRL
    end

    fill_table(last_index,length(ConPrimer))
    
end


function Print_Table()
    print("  ")
    for b in sufix_list
        print(b," ")
    end
    println()  # Move to the next line

    # Print the rows
    for (i, a) in enumerate(prefix_list)
        print(a," ")  # Print the element from A
        for (j,_) in enumerate(sufix_list)
            print(array_3d[i,j]," ")
        end
        println()  # Move to the next line
    end
end


main()