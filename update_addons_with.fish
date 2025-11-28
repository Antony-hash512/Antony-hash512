#!/usr/bin/env fish

# Проверка на VENV
if not set -q VIRTUAL_ENV
    echo "❌ Ошибка: Виртуальное окружение не активировано!"
    exit 1
end

echo "Запускаю обновление с ротацией бэкапов (макс 10)..."

for dir in custom_nodes/*/
    # Пропускаем, если это не git-репозиторий
    if not test -d "$dir/.git"
        continue
    end

    set node_name (basename $dir)

    # 1. Получаем имя текущей ветки
    set current_branch (git -C $dir rev-parse --abbrev-ref HEAD)

    # 2. Создаем бэкап-ветку
    set rnd (random 100 999)
    set timestamp (date +%Y-%m-%d_%H-%M)
    set backup_branch "backup_"$timestamp"_"$rnd

    git -C $dir branch $backup_branch

    # 3. Пытаемся обновить
    set output (git -C $dir pull 2>&1)
    set git_status $status

    if test $git_status -ne 0
        echo -e "\n\n❌ ОШИБКА ($node_name):"
        echo $output
    else if string match -q "*Already up to date*" $output
        # Если обновлений нет — удаляем пустую бэкап-ветку сразу
        git -C $dir branch -D $backup_branch > /dev/null 2>&1
        echo -n "."
    else
        echo -e "\n\n🚀 ОБНОВЛЕНО: $node_name"
        echo "   Бэкап сохранен: $backup_branch"
        echo $output
        
        # Обновляем зависимости, если нужно
        if test -f "$dir/requirements.txt"
             echo "   Проверка зависимостей..."
             uv pip install -r "$dir/requirements.txt"
        end
    end

    # --- БЛОК ОЧИСТКИ СТАРЫХ БЭКАПОВ (Ротация) ---
    # Получаем список веток, начинающихся на backup_, сортируем (старые первыми)
    set all_backups (git -C $dir branch --list "backup_*" --format="%(refname:short)" | sort)
    set count (count $all_backups)

    # Если бэкапов больше 10
    if test $count -gt 10
        # Вычисляем, сколько старых удалить
        set to_delete_count (math $count - 10)
        
        # Берем самые старые из начала списка
        set branches_to_delete $all_backups[1..$to_delete_count]
        
        for b in $branches_to_delete
            git -C $dir branch -D $b > /dev/null 2>&1
        end
        # Если было обновление и мы чистили, сообщим об этом (опционально)
        if not string match -q "*Already up to date*" $output
            echo "   🧹 Удалено старых бэкапов: $to_delete_count"
        end
    end
end

echo -e "\n\nГотово!"
