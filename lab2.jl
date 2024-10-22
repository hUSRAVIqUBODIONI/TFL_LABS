alphabet = ("L","R")
sufix_list = Vector{String}(["e"])
prefix_list = Vector{String}(["e","L","R"])
array_3d = fill("-", (3,1))
status = true #если false продолжать строить таблицу #true мы всё совпало
filename = ""
current_line = 1
itorations = 2



function main()
    global itorations, filename
    filename = readline()
    fill_table() #Заполняем первоначальную таблицу

    while status
        if eqvivolent() ==0
            return
        end
        Add_Prefix(itorations,2,"R","L")
        Add_Prefix(itorations,2,"L","R")
        itorations +=1
        Add_Prefix(itorations,2,"R","L")
        Add_Prefix(itorations,2,"L","R")
        itorations +=1
        fill_table(length(prefix_list)-7)
        Print_Table()
        end
    
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
   
    array = fill("-", (pl,len_of_Newtable))
   
    for p_id in 1:pl, s_id in 1:len_of_Newtable
        array[p_id,s_id] = MemberShip(prefix_list[p_id],sufix_list[start_index+s_id])
    end
  
    array_3d = hcat(array_3d,array)
   
    
end

function fill_table(start_index)
    global array_3d
    sl = length(sufix_list)
    array = fill("-",(8,sl))
    index = 1
  
    for p_id in start_index:start_index+7
        for s_id in 1:sl
        array[index,s_id] = MemberShip(prefix_list[p_id],sufix_list[s_id])
        end
        index +=1
    end
    array_3d = vcat(array_3d,array)
end


function MemberShip(prefix,sufix)
    global current_line
    result = read_file()
    current_line+=1
    return result
end




function eqvivolent()
    global status,current_line  # Access the global status variable
    ConPrimer = read_file()
    current_line +=1
    if ConPrimer == "Finish"
        status = true
        return 0
    else
        println(ConPrimer)
        Print_Table()
        Add_ContPrimer(ConPrimer)  # Assuming this function is defined elsewhere

        return 1
    end
end



function Add_ContPrimer(ConPrimer)
    last_index = length(sufix_list)      #Сохраняем старую длину суффиксов
    for l in 1:length(ConPrimer)
       a = last(ConPrimer,l)
        if (!in(a,sufix_list))
            push!(sufix_list,a)  # Добавляем все суффиксы контр-примера в списаок суффиксов LLRL = L, RL, LRL, LLRL
        end
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

function read_file()
    open(filename, "r") do file
        lines = readlines(file)  # читаем все строки в массив
        if current_line <= length(lines)
            return lines[current_line]
        end
    end
end


main()


