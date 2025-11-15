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

echo " 1 - Конфигурация дерева установки с параметрами сборки"
./configure \
	--prefix=$CONF_PREFIX \
	--with-block-compression \
	--with-path-checksum \
	"${OPTIONS[@]}"
echo
echo " 2 - Запускам сборку"
if [ $? -eq 0 ]; then
	make && \
	echo " 3 - Тестирование сборки" && \
	make check
else
	echo "Конфигурация с ошибками, продолжение невозможно"
	exit 2
fi

echo " 4 - Устанавливаем сборку"
make install && echo "Сборка успешно установлена!"

echo "##################################################"
echo " 5 - Меняем владельца в каталоге установки"
chown -R postgres:postgres $CONF_PREFIX && "успешно"

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
	mkdir "${curdir}" && chown -R postgres:postgres $curdir && "  ${curdir} создана."
else
	echo "${curdir} существует"
fi

curdir="/log/pg_log"
if [ -d "${curdir}" ]; then
        mkdir "${curdir}"  && chown -R postgres:postgres $curdir  && "  ${curdir} создана."
else
        echo "${curdir} существует"
fi

curdir="/wal/pg_wal"
if [ -d "${curdir}" ]; then
        mkdir "${curdir}" && chown -R postgres:postgres $curdir && "  ${curdir} создана."
else
        echo "${curdir} существует"
fi

echo
echo " 8 - Инициализируем кластер СУБД в /data/pg_data"
${CONF_PREFIX}/bin/initdb -D /data/pg_data --waldir=/wal/pg_wal && echo " кластер инициализирован"

echo
echo " 9 - Вносим базовые настройки в postgresql.conf"

echo
echo " 9 - Запускаем кластер СУБД. Лог пишем в /log/pg_log"
${CONF_PREFIX}/bin/pg_ctl -D /data/pg_data -l /log/pg_log

