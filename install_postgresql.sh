#!/bin/bash
#
# Скрипт устанавливает и инициализирует кластер СУБД PostgreSQL
# Запускать от имени root
# (c) tankalxat34 - 2025

OPTIONS=("$@")
LOG_PATH="/scripts/log/postgresql_installation_${date}"

if [ ! whoami -eq "root" ]; then
	echo "Необходимо запускать скрипт от имени root!"
	echo "Введите: sudo install_postgresql.sh"
	exit 2
fi

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
echo "Запускаем установку PostgreSQL"

touch $LOG_PATH

echo " 1 - Конфигурация дерева установки с параметрами сборки"
cd $path_to_sources

echo "  Очищаю предыдущую сборку"
make distclean >> $LOG_PATH 2>&1
echo "  Успешно!"

./configure \
	--prefix=$CONF_PREFIX \
	--with-block-compression \
	--with-path-checksum \
	"${OPTIONS[@]}" >> $LOG_PATH 2>&1
echo "  Успешно!"

echo
echo " 2 - Запускам сборку"
if [ $? -eq 0 ]; then
	echo "  Начинаю новую сборку"
	make >> $LOG_PATH  2>&1
	echo "  Сборка окончена"
	echo "  Тестирую сборку"
	make check >> $LOG_PATH  2>&1
else
	echo "Конфигурация с ошибками, продолжение невозможно"
	exit 2
fi
echo "  Успешно!"

echo " 4 - Устанавливаем сборку"
make install >> $LOG_PATH  2>&1
echo "Сборка успешно установлена!"

echo "##################################################"
echo " 5 - Меняем владельца в каталоге установки"
chown -R postgres:postgres "${CONF_PREFIX}"

echo
echo " 6 - Устанавливаем переменные окружения"
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
echo " 7 - Проверяем наличие папок /data/pg_data, /wal/pg_wal, /log/pg_log"
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
echo " 8 - Инициализируем кластер СУБД в /data/pg_data"
sudo -u postgres "${CONF_PREFIX}/bin/initdb" -k \
	--locale="ru_RU.UTF-8" \
	--encoding="UTF8" \
	-D /data/pg_data \
	--waldir=/wal/pg_wal

if [ ! $? -eq 0 ]; then
	echo "ОШИБКА: Кластер инициализирован с ошибкой. Продолжение невозможно!"
	exit 10
fi

echo "##################################################"
echo " Кластер PostgreSQL инициализирован:"
echo "  PG Data:   /data/pg_data"
echo "  PG Server: ${CONF_PREFIX}"
echo "  WAL files: /wal/pg_wal"
echo "##################################################"

echo
echo " 9 - Вносим базовые настройки в postgresql.conf"

echo
echo " 10 - Запускаем кластер СУБД. Лог пишем в /log/pg_log"
sudo -u postgres "${CONF_PREFIX}/bin/pg_ctl" -D /data/pg_data -l /log/pg_log start && echo " кластер запущен"

echo
echo " 11 - Проверка соединения"
echo "  Текущее время из БД postgres:"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT now();"

echo
echo "  Установленная версия PostgreSQL:"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT pg_version();"

echo
echo "##################################################"
echo "СУБД PostgreSQL успешно установлена. Для "
echo "применения переменных окружения и путей к"
echo "исполняемым файлам необходимо перезайти на сервер."

