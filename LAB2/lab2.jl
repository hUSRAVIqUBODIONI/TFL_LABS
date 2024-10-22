using HTTP
using JSON


alphabet = ("L","R")
sufix_list = Vector{String}(["ε"])
prefix_list = Vector{String}(["ε","L","R"])
array_3d = fill(0, (3,1))
status = true #если false продолжать строить таблицу #true мы всё совпало
filename = ""
current_line = 1
i = 1
itorations = 2



function main()
    global itorations
    fill_table() #Заполняем первоначальную таблицу
    Print_Table()
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
   
    array = fill(0, (pl,len_of_Newtable))
   
    for p_id in 1:pl, s_id in 1:len_of_Newtable
        array[p_id,s_id] = MemberShip(prefix_list[p_id],sufix_list[start_index+s_id])
    end
  
    array_3d = hcat(array_3d,array)
    
end

function fill_table(start_index)
    global array_3d
    sl = length(sufix_list)
    array = fill(0,(8,sl))
    index = 1
  
    for p_id in start_index:start_index+7
        for s_id in 1:sl
        array[index,s_id] = MemberShip(prefix_list[p_id],sufix_list[s_id])
        end
        index +=1
    end
    array_3d = vcat(array_3d,array)
end


function MemberShip(pref, suf)
    # Обрабатываем случай, когда префикс или суффикс равен "ε"
    if pref == "ε" && suf == "ε"
        word = "ε"  # Оба "ε", возвращаем пустую строку
    elseif pref == "ε"
        word = suf  # Возвращаем только суффикс
    elseif suf == "ε"
        word = pref  # Возвращаем только префикс
    else
        word = pref * suf  # Соединяем префикс и суффикс
    end

    # Создаем JSON объект для отправки
    data = JSON.json(Dict("word" => word))

    # Выполняем POST-запрос
    url = "http://localhost:8095/checkWord"  # Убедитесь, что адрес правильный
    response = HTTP.post(url, 
                         body=data, 
                         headers=["Content-Type" => "application/json"])
    
    # Проверяем ответ
    if response.status == 200
        parsed_response = JSON.parse(String(response.body))
        return parsed_response["response"]  # Возвращаем только значение поля "response"
    else
        return false  # Или любое значение по умолчанию в случае ошибки
    end
end


function eqvivolent()
    global i
    pl = length(prefix_list)
    if i!=1
        main_prefixes = prefix_list[1:pl-8]  # Например, первые три элемента
        non_main_prefixes = prefix_list[pl-7:end]  # Остальные элементы
    else
        main_prefixes = ["ε"]
        non_main_prefixes = ["L","R"]
        i+=1
    end
    println("main_prefixes :", (join(main_prefixes," ")))
    println("non_main_prefixes : ",join(non_main_prefixes," "))
    println("suffixes : ",join(sufix_list," "))
    
    flat_array = reduce(vcat, eachrow(array_3d))

    # Объединяем элементы в строку, разделяя пробелом
    table_string = join(flat_array, " ")
    println("table : ",table_string)
    # Создаем JSON объект для отправки
    data = Dict(
        "main_prefixes" => join(main_prefixes," "),
        "non_main_prefixes" => join(non_main_prefixes," "),
        "suffixes" => join(sufix_list," "),
        "table" => table_string
    )

    # Преобразуем в JSON
    json_data = JSON.json(data)

    # Выполняем POST-запрос
    url = "http://localhost:8095/checkTable"  # Замените на ваш URL
    response = HTTP.post(url, 
                         body=json_data, 
                         headers=["Content-Type" => "application/json"])
    
    # Проверяем ответ
    if response.status == 200
        parsed_response = JSON.parse(String(response.body))
        println(parsed_response["response"],"\t",parsed_response["type"])  # Получаем значение из поля "response"
        if parsed_response["response"] == NaN || parsed_response["type"]==false #|| in(parsed_response["response"],sufix_list)
            return 0
        end
        Add_ContPrimer(parsed_response["response"])
        return 1
    else
        println("Ошибка: $(response.status)")
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


