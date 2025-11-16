#!/bin/bash
#
# Скрипт устанавливает и инициализирует кластер СУБД PostgreSQL
# Запускать от имени root
# (c) tankalxat34 - 2025

OPTIONS=("$@")

LOG_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_PATH="/scripts/log/install_postgresql__${LOG_DATE}.log"


logger() {
	local cur_date=$(date +"%Y-%m-%d_%H-%M-%S")
	local msg=$1
	echo "${cur_date} : ${msg}"
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
logger "5 - Устанавливаем переменные окружения"
export PATH="${CONF_PREFIX}":$PATH
export PGDATA=/data/pg_data

FILE="/etc/profile.d/pgsql.sh"
cat << EOF > "$FILE"
#!/bin/bash

# Добавляем каталог PostgreSQL в PATH
export PATH=${CONF_PREFIX}:\$PATH

# Устанавливаем переменную PGDATA
export PGDATA=/data/pg_data
EOF

source "$FILE"

echo "##################################################"
logger "6 - Проверяем наличие папок /data/pg_data, /wal/pg_wal, /log/pg_log"
curdir="/data/pg_data/"
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
logger "7 - Инициализируем кластер СУБД в /data/pg_data"
echo "  Меняем владельца"
chown -R postgres:postgres "${CONF_PREFIX}"
chown -R postgres:postgres /data/pg_data
chown -R postgres:postgres /wal/pg_wal
chown -R postgres:postgres /log/pg_log

chmod 700 /data/pg_data
chmod 700 /wal/pg_wal
chmod 700 /log/pg_log

sudo -u postgres "${CONF_PREFIX}/bin/initdb" -k \
	--locale-provider=icu \
	--icu-locale="ru_RU.UTF-8" \
	--encoding="UTF8" \
	-D /data/pg_data \
	--waldir=/wal/pg_wal

if [ ! $? -eq 0 ]; then
	logger "ОШИБКА: Кластер не был инициализирован из-за ошибки. Продолжение невозможно!"
	exit 10
fi

echo "##################################################"
logger " Кластер PostgreSQL инициализирован"
echo " Пути установки:"
echo "  PG Data:   /data/pg_data"
echo "  WAL files: /wal/pg_wal"
echo "  PG Server: ${CONF_PREFIX}"
echo "  PG Utils: ${CONF_PREFIX}/bin"
echo "##################################################"

echo
logger "8 - Вносим базовые настройки в postgresql.conf"

echo
logger "9 - Запускаем кластер СУБД. Лог пишем в /log/pg_log"
sudo -u postgres "${CONF_PREFIX}/bin/pg_ctl" -D /data/pg_data -l /log/pg_log start && echo " кластер запущен"

echo
logger "10 - Проверка соединения"
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

