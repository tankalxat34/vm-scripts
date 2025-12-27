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

POSTGRES_CONFIG=/data/pg_data/postgresql.auto.conf

echo
logger "Вносим базовые настройки в ${POSTGRES_CONFIG}"
logger "Делаем бекап ${POSTGRES_CONFIG}"
cp $POSTGRES_CONFIG $POSTGRES_CONFIG.bak
chown postgres:postgres $POSTGRES_CONFIG.bak
logger "Перезаписываем параметры в ${POSTGRES_CONFIG}"
# удаляем строки, которые начинаются с этих фраз. перечисление через |
#grep -vE "timezone" $POSTGRES_CONFIG > $POSTGRES_CONFIG

echo "" > $POSTGRES_CONFIG

echo "# Настройки install_postgresql.sh" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- Подключение и аутентификация ---" >> $POSTGRES_CONFIG
echo "max_connections = 100" >> $POSTGRES_CONFIG
echo "listen_addresses = '0.0.0.0'" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- Логирование ---" >> $POSTGRES_CONFIG
echo "logging_collector = on" >> $POSTGRES_CONFIG
echo "log_directory = '/log/pg_log'" >> $POSTGRES_CONFIG
echo "log_filename = '$(hostname -s)-%Y-%m-%d_%H%M%S.log'" >> $POSTGRES_CONFIG
echo "log_truncate_on_rotation = on" >> $POSTGRES_CONFIG
echo "log_rotation_age = 1d" >> $POSTGRES_CONFIG
echo "log_rotation_size = 100MB" >> $POSTGRES_CONFIG
echo "log_temp_files = 0" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- Память ---" >> $POSTGRES_CONFIG
echo "shared_buffers = 2GB                         # 25% от RAM (для 16+ GB RAM)" >> $POSTGRES_CONFIG
echo "effective_cache_size = 7GB                   # 75% от RAM" >> $POSTGRES_CONFIG
echo "work_mem = 128MB                              # для сложных сортировок и хешей" >> $POSTGRES_CONFIG
echo "maintenance_work_mem = 2GB                   # для VACUUM, CREATE INDEX и т.п." >> $POSTGRES_CONFIG
echo "max_worker_processes = 8" >> $POSTGRES_CONFIG
echo "max_parallel_workers = 8" >> $POSTGRES_CONFIG
echo "max_parallel_workers_per_gather = 4" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- WAL и восстановление ---" >> $POSTGRES_CONFIG
echo "fsync = on" >> $POSTGRES_CONFIG
echo "synchronous_commit = on                      # для ACID-совместимости" >> $POSTGRES_CONFIG
echo "min_wal_size = 1GB" >> $POSTGRES_CONFIG
echo "max_wal_size = 4GB" >> $POSTGRES_CONFIG
echo "checkpoint_completion_target = 0.9" >> $POSTGRES_CONFIG
echo "wal_compression = on" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- Архивация WAL ---" >> $POSTGRES_CONFIG
echo "archive_mode = off                           # включить при необходимости архивации" >> $POSTGRES_CONFIG
echo "archive_command = ''                         # пример: 'cp %p /path/to/archive/%f'" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- Автоматическое обслуживание ---" >> $POSTGRES_CONFIG
echo "autovacuum = on" >> $POSTGRES_CONFIG
echo "autovacuum_max_workers = 3" >> $POSTGRES_CONFIG
echo "autovacuum_naptime = 1min" >> $POSTGRES_CONFIG
echo "autovacuum_vacuum_threshold = 50" >> $POSTGRES_CONFIG
echo "autovacuum_analyze_threshold = 50" >> $POSTGRES_CONFIG
echo "autovacuum_vacuum_scale_factor = 0.05" >> $POSTGRES_CONFIG
echo "autovacuum_analyze_scale_factor = 0.02" >> $POSTGRES_CONFIG
echo "autovacuum_vacuum_cost_limit = 200" >> $POSTGRES_CONFIG
echo "autovacuum_vacuum_cost_delay = 20ms" >> $POSTGRES_CONFIG
echo "" >> $POSTGRES_CONFIG
echo "## --- Клиентские параметры ---" >> $POSTGRES_CONFIG
echo "default_transaction_isolation = 'read committed'" >> $POSTGRES_CONFIG
echo "timezone = 'Europe/Moscow'" >> $POSTGRES_CONFIG
#echo "#lc_messages = 'ru_RU.UTF-8'" >> $POSTGRES_CONFIG
#echo "#lc_monetary = 'ru_RU.UTF-8'" >> $POSTGRES_CONFIG
#echo "#lc_numeric = 'ru_RU.UTF-8'" >> $POSTGRES_CONFIG
#echo "#lc_time = 'ru_RU.UTF-8'" >> $POSTGRES_CONFIG
echo "default_text_search_config = 'pg_catalog.russian'" >> $POSTGRES_CONFIG

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
