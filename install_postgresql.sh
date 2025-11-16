#!/bin/bash
#
# Скрипт устанавливает и инициализирует кластер СУБД PostgreSQL
# Запускать от имени root
# (c) tankalxat34 - 2025

OPTIONS=("$@")

LOG_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_PATH="/scripts/log/install_postgresql__${LOG_DATE}.log"


logger() {
        local cur_date=$(date +"%Y-%m-%d %H:%M:%S")
        local msg=$1
        echo "\[${cur_date}\] : ${msg}"
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
	mkdir -p "${curdir}/wal_arc_archive"
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
	--timezone=Europe/Moscow \
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
logger "Перезаписываем параметры в postgresql.conf"
# удаляем строки, которые начинаются с этих фраз. перечисление через |
#grep -vE "timezone" /data/pg_data/postgresql.conf > /data/pg_data/postgresql.conf

echo "" > /data/pg_data/postgresql.conf

FILE="/data/pg_data/postgresql.conf"
cat << EOF > "$FILE"
# Настройки install_postgresql.sh

## --- Подключение и аутентификация ---
max_connections = 100

## --- Логирование ---
logging_collector = on
log_directory = '/log/pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 100MB
log_temp_files = 0

## --- Память ---
shared_buffers = 2GB                         # 25% от RAM (для 16+ GB RAM)
effective_cache_size = 7GB                   # 75% от RAM
work_mem = 64MB                              # для сложных сортировок и хешей
maintenance_work_mem = 2GB                   # для VACUUM, CREATE INDEX и т.п.
max_worker_processes = 8
max_parallel_workers = 8
max_parallel_workers_per_gather = 4

## --- WAL и восстановление ---
fsync = on
synchronous_commit = on                      # для ACID-совместимости
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9
wal_compression = on

## --- Архивация WAL ---
archive_mode = off                           # включить при необходимости архивации
archive_command = ''                         # пример: 'cp %p /path/to/archive/%f'

## --- Автоматическое обслуживание ---
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.05
autovacuum_analyze_scale_factor = 0.02
autovacuum_vacuum_cost_limit = 200
autovacuum_vacuum_cost_delay = 20ms

## --- Клиентские параметры ---
default_transaction_isolation = 'read committed'
timezone = 'Europe/Moscow'
lc_messages = 'ru_RU.UTF-8'
lc_monetary = 'ru_RU.UTF-8'
lc_numeric = 'ru_RU.UTF-8'
lc_time = 'ru_RU.UTF-8'
default_text_search_config = 'pg_catalog.russian'

EOF
source "$FILE"


echo
logger "Запускаем кластер СУБД. Лог пишем в /log/pg_log"
sudo -u postgres "${CONF_PREFIX}/bin/pg_ctl" -D /data/pg_data start && echo " кластер запущен"

echo
logger "Проверка соединения"
echo "  Текущее время из БД postgres:"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT now();"

echo
echo "  Установленная версия PostgreSQL:"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT pg_version();"


echo
echo "##################################################"

logger "СУБД PostgreSQL успешно установлена!"
echo
echo "Для применения переменных окружения и путей к"
echo "исполняемым файлам необходимо перезайти на сервер."

