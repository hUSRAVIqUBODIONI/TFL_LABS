Алфовит Языка состоит из {L,R}

1.Первноначально создается таблица с префиксами {e,L,R} и суффиксами {e}.

2.Если получили контр-пример то в список суффиксов добавляем контр-пример со всеми его суффиксами: Напирмер LLR - контр-пример {e,R,LR,LLR} список суффиксов

3. Заполняем основную таблицу с суффиксами контр-примера (Membership(prefix,suffix))

4. Проверяем таблицу на полноту

5. Берем все префиксы в главной части таблицы, добавляя к ним "R" "L" получаем дополнение для префиксов. Если они уникальны то добавляем их в расширенную часть

6. Заполняем таблицу из новых префиксов. Проверяем условие полноты

7. Отправляем таблицу для проверки на эквивалентность 

8. Если эквиваленты то выводим таблицу, а если нет то переходим к пункту 2

В папках скриншоты конфигурации Мата и вывод программы


Добавил функцию MembershipList который принимает массив слов отправляет на МАТ. В качестве ответа ожидает массив 0 и 1. Где 0 если слова не входит в язык, иначе 1.
Так как в Julia относительно других языках Python C++ и тд (незнаю для всех ли. проверил вручную) медленно работает подключения и отправка данных на сервер через HTTP, то решил сначала собрать все слова и отправить через один POST запрос.



