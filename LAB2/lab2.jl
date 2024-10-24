using HTTP
using JSON


mutable struct Table
    main_prefix::Vector{String}
    non_main_prefix::Vector{String}
    suffix::Vector{String}
    array::Matrix{Int64}
    alphabet::Vector{String}
    contrs::Vector{String}
end

function Table()
    return Table(Vector{String}(["ε"]),Vector{String}(["L","R"]),Vector{String}(["ε"]),fill(0,(3,1)),Vector{String}(["L","R"]),Vector{String}([]))
end

function main()
    t = Table()
    fill_table(t)
    while true
        if !Equivalent(t)
            PrintTable(t)
            return 0
        end
        Polnota(t) 
        Fill_table_prefix(t,Add_Prefix(t))
        Polnota(t)
    end
end

function Add_Prefix(t::Table)
    new_prefix =[]
    for i in t.main_prefix
        for j in t.alphabet 
            if i == "ε"
                word = j
            else
                word = i*j
            end
            if word ∉ t.main_prefix && word ∉ t.non_main_prefix
                push!(new_prefix,word)
            end
        end
    end
    return new_prefix
end



function fill_table(t::Table)
    for i in 1:1
        t.array[i,1] = MemberShip(t.main_prefix[i],t.suffix[1])
    end
    for i in 1:2
        t.array[i+1,1] = MemberShip(t.non_main_prefix[i],t.suffix[1])
    end
end

function Fill_table_prefix(t::Table,new_prefixes)
    sl = length(t.suffix)
    npl = length(new_prefixes)
    temp = fill(0,(npl,sl))
    for i in 1:npl, j in 1:sl 
        temp[i,j] = MemberShip(new_prefixes[i],t.suffix[j])
    end
    t.non_main_prefix = union(t.non_main_prefix,new_prefixes)
    t.array = vcat(t.array,temp) 
end

function PrintTable(t::Table)
    lmp=length(t.main_prefix)
    lnp=length(t.non_main_prefix)
    ls = length(t.suffix)
    print("  ")
    for b in t.suffix
        print(b," ")
    end
    println()  # Move to the next line
    for i in 1:lmp
        print(t.main_prefix[i]," ")
        for j in 1:ls
            print(t.array[i,j]," ")
        end
        println()
    end
    for i in 1:lnp
        print(t.non_main_prefix[i]," ")
        for j in 1:ls
            print(t.array[i+lmp,j]," ")
        end
        println()
    end
end

function Polnota(t::Table)
    lmp =length(t.main_prefix)
    lnp = length(t.non_main_prefix)
    fordel =[]
    check =0
    for i in lmp+1:lnp+lmp
        e = true
        for j in 1:lmp+check
            if (t.array[i,:] == t.array[j,:])
               
                e = false
                break
            end
        end
        if e
            push!(fordel,i-lmp)
            t.array = insert_row(t.array,i,lmp+check+1)
            check+=1
        end
    end
    for (i,v) in pairs(fordel)
        push!(t.main_prefix,t.non_main_prefix[v-(i-1)])
        deleteat!(t.non_main_prefix,v-(i-1))
    end
end

function insert_row(t, i, insert_position)
    # Сохраняем строку, которую нужно вставить и преобразуем в матрицу
    row_to_insert = t[i, :]
    # Вставляем строку на указанную позицию
    t = vcat(t[1:insert_position-1, :], row_to_insert', t[insert_position:end, :])
    t = vcat(t[1:i, :], t[i+2:end, :])
    return t
end

function Contrprimer(t::Table,start_suffix,contr)
    println(contr)
    for l in 1:length(contr)
       a = last(contr,l)
        if (!in(a,t.suffix))
            push!(t.suffix,a)  # Добавляем все суффиксы контр-примера в списаок суффиксов LLRL = L, RL, LRL, LLR
        end
    end 
    fill_table(t,start_suffix)
end

function fill_table(t::Table,start_suffix)
    lmp = length(t.main_prefix)  
    lnp = length(t.non_main_prefix)
    ls = length(t.suffix)
    temp = fill(0,(lmp+lnp,ls-start_suffix+1))
    
    for i in 1:lmp
        index =1
        for j in start_suffix:ls
        temp[i,index] =  MemberShip(t.main_prefix[i],t.suffix[j])
        index +=1
        end
    end
    for i in 1:lnp
        index =1
        for j in start_suffix:ls
        temp[lmp+i,index] =  MemberShip(t.non_main_prefix[i],t.suffix[j])
        index +=1
        end
    end
    t.array = hcat(t.array,temp)
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
        if parsed_response["response"]
            return 1
        else
            return 0 
        end
    end
end

function Equivalent(t::Table)
    # Объединяем элементы в строку, разделяя пробелом
    table_string = join(t.array', " ")
    # Создаем JSON объект для отправки
    data = Dict(
        "main_prefixes" => join(t.main_prefix," "),
        "non_main_prefixes" => join(t.non_main_prefix," "),
        "suffixes" => join(t.suffix," "),
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
        if isnothing(parsed_response["response"])
            println("Finish!!!")
            return false
        elseif in(parsed_response["response"],t.contrs)
            
            return true
        else
            push!(t.contrs,parsed_response["response"])
            Contrprimer(t,length(t.suffix)+1,parsed_response["response"])
            return true
        end
    else
        println("Ошибка: $(response.status)")
    end
end
main()