#!/bin/bash
#
# Скрипт устанавливает и инициализирует кластер СУБД PostgreSQL
# Запускать от имени root
# (c) tankalxat34 - 2025

OPTIONS=("$@")

LOG_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_PATH="/postgres/install_postgresql__${LOG_DATE}.log"


logger() {
        local cur_date=$(date +"%Y-%m-%d %H:%M:%S")
        local msg=$1
        echo "[${cur_date}] : ${msg}"
}

has_option() {
    local search="$1"
    for opt in "${OPTIONS[@]}"; do
        if [[ "$opt" == "$search" ]]; then
            return 0  # Опция найдена
        fi
    done
    return 1  # Опция не найдена
}

logger "Проверка параметров запуска скрипта"
if [ "$(whoami)" != "root" ]; then
        echo "Необходимо запускать скрипт от имени root!"
        echo "Введите: sudo install_postgresql.sh"
        exit 2
fi

mkdir /scripts/log >> /dev/null 2>&1
touch "${LOG_PATH}"

echo "##################################################"
echo " Введите путь распакованным исходникам PostgreSQL:"
read path_to_sources

read -p " Введите опцию prefix (/usr/local/pgsql):" CONF_PREFIX
CONF_PREFIX=${CONF_PREFIX:-/usr/local/pgsql}

echo

cd $path_to_sources
echo $(pwd)

if [ ! -e  "configure" ]; then
        echo "Отсутсвует файл configure в расположении: $path_to_sources"
        exit 1
fi
if [ ! -e  "Makefile" ]; then
        echo "Отсутсвует файл Makefile в расположении: $path_to_sources"
        exit 1
fi


echo

echo "##################################################"
logger "Запускаем установку PostgreSQL"
make install >> "${LOG_PATH}"  2>&1
logger "Сборка успешно установлена!"

echo "##################################################"

logger "Устанавливаем переменные окружения"
export PATH="${CONF_PREFIX}/bin":$PATH
export PGDATA=/data/pg_data

FILE="/etc/profile.d/pgsql.sh"
cat << EOF > "$FILE"
#!/bin/bash

# Добавляем каталог PostgreSQL в PATH
export PATH=${CONF_PREFIX}/bin:\$PATH

# Устанавливаем переменную PGDATA
export PGDATA=/data/pg_data
EOF

source "$FILE"

echo "##################################################"
logger "Проверяем наличие папок /data/pg_data, /wal/pg_wal, /log/pg_log"
curdir="/data/pg_data"
if [ -d "${curdir}" ]; then
        echo "${curdir} существует"
else
        mkdir "${curdir}" && chown -R postgres:postgres "${curdir}" && echo "  ${curdir} создана."
fi

curdir="/log/pg_log"
if [ -d "${curdir}" ]; then
        echo "${curdir} существует"
else
        mkdir "${curdir}" && chown -R postgres:postgres "${curdir}" && echo "  ${curdir} создана."
fi


curdir="/wal/pg_wal"
if [ -d "${curdir}" ]; then
        echo "${curdir} существует"
else
        mkdir "${curdir}" && chown -R postgres:postgres "${curdir}" && echo "  ${curdir} создана."
fi


echo
logger "Инициализируем кластер СУБД в /data/pg_data"
echo "  Меняем владельца root -> postgres"
chown -R postgres:postgres "${CONF_PREFIX}"
chown -R postgres:postgres /data/pg_data
chown -R postgres:postgres /wal/pg_wal
chown -R postgres:postgres /log/pg_log

echo "  Устанавливаем права 700 "
chmod 700 "${CONF_PREFIX}"
chmod 700 /data/pg_data
chmod 700 /wal/pg_wal
chmod 700 /log/pg_log

logger "Запуск initdb"
sudo -u postgres "${CONF_PREFIX}/bin/initdb" -k \
        --locale-provider=icu \
        --icu-locale=ru-RU \
        --encoding=UTF8 \
        -D /data/pg_data \
        --waldir=/wal/pg_wal

if [ ! $? -eq 0 ]; then
        logger "ОШИБКА: Кластер не был инициализирован из-за ошибки. Продолжение невозможно!"
        exit 10
fi

logger "Успешно!"

echo "##################################################"
logger " Кластер PostgreSQL инициализирован"
echo " Пути установки:"
echo "  PG Data:   /data/pg_data"
echo "  WAL files: /wal/pg_wal"
echo "  PG Server: ${CONF_PREFIX}"
echo "  PG Utils:  ${CONF_PREFIX}/bin"
echo "##################################################"

echo
logger "Вносим базовые настройки в postgresql.conf"
logger "Делаем бекап postgresql.conf"
cp /data/pg_data/postgresql.conf /data/pg_data/postgresql.conf.bak
chown postgres:postgres /data/pg_data/postgresql.conf.bak
logger "Перезаписываем параметры в postgresql.conf"
# удаляем строки, которые начинаются с этих фраз. перечисление через |
#grep -vE "timezone" /data/pg_data/postgresql.conf > /data/pg_data/postgresql.conf

echo "" > /data/pg_data/postgresql.conf

echo "# Настройки install_postgresql.sh" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- Подключение и аутентификация ---" >> /data/pg_data/postgresql.conf
echo "max_connections = 100" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- Логирование ---" >> /data/pg_data/postgresql.conf
echo "logging_collector = on" >> /data/pg_data/postgresql.conf
echo "log_directory = '/log/pg_log'" >> /data/pg_data/postgresql.conf
echo "log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'" >> /data/pg_data/postgresql.conf
echo "log_truncate_on_rotation = on" >> /data/pg_data/postgresql.conf
echo "log_rotation_age = 1d" >> /data/pg_data/postgresql.conf
echo "log_rotation_size = 100MB" >> /data/pg_data/postgresql.conf
echo "log_temp_files = 0" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- Память ---" >> /data/pg_data/postgresql.conf
echo "shared_buffers = 2GB                         # 25% от RAM (для 16+ GB RAM)" >> /data/pg_data/postgresql.conf
echo "effective_cache_size = 7GB                   # 75% от RAM" >> /data/pg_data/postgresql.conf
echo "work_mem = 64MB                              # для сложных сортировок и хешей" >> /data/pg_data/postgresql.conf
echo "maintenance_work_mem = 2GB                   # для VACUUM, CREATE INDEX и т.п." >> /data/pg_data/postgresql.conf
echo "max_worker_processes = 8" >> /data/pg_data/postgresql.conf
echo "max_parallel_workers = 8" >> /data/pg_data/postgresql.conf
echo "max_parallel_workers_per_gather = 4" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- WAL и восстановление ---" >> /data/pg_data/postgresql.conf
echo "fsync = on" >> /data/pg_data/postgresql.conf
echo "synchronous_commit = on                      # для ACID-совместимости" >> /data/pg_data/postgresql.conf
echo "min_wal_size = 1GB" >> /data/pg_data/postgresql.conf
echo "max_wal_size = 4GB" >> /data/pg_data/postgresql.conf
echo "checkpoint_completion_target = 0.9" >> /data/pg_data/postgresql.conf
echo "wal_compression = on" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- Архивация WAL ---" >> /data/pg_data/postgresql.conf
echo "archive_mode = off                           # включить при необходимости архивации" >> /data/pg_data/postgresql.conf
echo "archive_command = ''                         # пример: 'cp %p /path/to/archive/%f'" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- Автоматическое обслуживание ---" >> /data/pg_data/postgresql.conf
echo "autovacuum = on" >> /data/pg_data/postgresql.conf
echo "autovacuum_max_workers = 3" >> /data/pg_data/postgresql.conf
echo "autovacuum_naptime = 1min" >> /data/pg_data/postgresql.conf
echo "autovacuum_vacuum_threshold = 50" >> /data/pg_data/postgresql.conf
echo "autovacuum_analyze_threshold = 50" >> /data/pg_data/postgresql.conf
echo "autovacuum_vacuum_scale_factor = 0.05" >> /data/pg_data/postgresql.conf
echo "autovacuum_analyze_scale_factor = 0.02" >> /data/pg_data/postgresql.conf
echo "autovacuum_vacuum_cost_limit = 200" >> /data/pg_data/postgresql.conf
echo "autovacuum_vacuum_cost_delay = 20ms" >> /data/pg_data/postgresql.conf
echo "" >> /data/pg_data/postgresql.conf
echo "## --- Клиентские параметры ---" >> /data/pg_data/postgresql.conf
echo "default_transaction_isolation = 'read committed'" >> /data/pg_data/postgresql.conf
echo "timezone = 'Europe/Moscow'" >> /data/pg_data/postgresql.conf
#echo "#lc_messages = 'ru_RU.UTF-8'" >> /data/pg_data/postgresql.conf
#echo "#lc_monetary = 'ru_RU.UTF-8'" >> /data/pg_data/postgresql.conf
#echo "#lc_numeric = 'ru_RU.UTF-8'" >> /data/pg_data/postgresql.conf
#echo "#lc_time = 'ru_RU.UTF-8'" >> /data/pg_data/postgresql.conf
echo "default_text_search_config = 'pg_catalog.russian'" >> /data/pg_data/postgresql.conf

echo
logger "Запускаем кластер СУБД. Лог пишем в /log/pg_log"
sudo -u postgres "${CONF_PREFIX}/bin/pg_ctl" -D /data/pg_data start && echo " кластер запущен"

echo
logger "Проверка соединения"
echo "  Текущее время из БД postgres:"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT now();"

echo
echo "  Установленная версия PostgreSQL:"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT version();"


echo
echo "##################################################"

logger "СУБД PostgreSQL успешно установлена!"
echo
echo "Для применения переменных окружения и путей к"
echo "исполняемым файлам необходимо перезайти на сервер."
