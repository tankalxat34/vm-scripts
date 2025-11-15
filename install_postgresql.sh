#!/bin/bash
#
# Скрипт устанавливает и инициализирует кластер СУБД PostgreSQL
# Запускать от имени root
# (c) tankalxat34 - 2025

OPTIONS=("$@")

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

touch /scripts/install_postgresql.log

echo " 1 - Конфигурация дерева установки с параметрами сборки"
cd $path_to_sources

echo "  Очищаю предыдущую сборку"
date && time make distclean >> /scripts/install_postgresql.log 2>&1 && date

./configure \
	--prefix=$CONF_PREFIX \
	--with-block-compression \
	--with-path-checksum \
	"${OPTIONS[@]}" >> /scripts/install_postgresql.log 2>&1
echo "  Успешно!"

echo
echo " 2 - Запускам сборку"
if [ $? -eq 0 ]; then
	echo "  Начинаю новую сборку"
	date && time make && date >> /scripts/install_postgresql.log  2>&1 && date && echo "  Сборка окончена"
	echo "  Тестирую сборку"
	date && time make check && date >> /scripts/install_postgresql.log  2>&1 && date
else
	echo "Конфигурация с ошибками, продолжение невозможно"
	exit 2
fi

echo " 4 - Устанавливаем сборку"
date && time make install >> /scripts/install_postgresql.log  2>&1 && date && echo "Сборка успешно установлена!"

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
	--timezone="Europe/Moscow" \
	-D /data/pg_data \
	--waldir=/wal/pg_wal \
	&& echo " кластер инициализирован"

echo
echo " 9 - Вносим базовые настройки в postgresql.conf"

echo
echo " 10 - Запускаем кластер СУБД. Лог пишем в /log/pg_log"
sudo -u postgres "${CONF_PREFIX}/bin/pg_ctl" -D /data/pg_data -l /log/pg_log && echo " кластер запущен"

echo
echo " 11 - Проверка соединения"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT now();"
sudo -u postgres "${CONF_PREFIX}/bin/psql" -c "SELECT pg_version();"

echo
echo "##################################################"
echo "СУБД PostgreSQL успешно установлена. Для "
echo "применения переменных окружения и путей к"
echo "исполняемым файлам необходимо перезайти на сервер."
