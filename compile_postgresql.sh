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

logger "1 - Конфигурация дерева установки с параметрами сборки"
cd $path_to_sources

logger "Очищаю предыдущую сборку"
make distclean >> "${LOG_PATH}" 2>&1
logger "Успешно!"

logger "Создание конфигурации для новой сборки"
./configure \
	--prefix=$CONF_PREFIX \
	--with-block-compression \
	--with-path-checksum \
	"${OPTIONS[@]}" >> "${LOG_PATH}" 2>&1
logger "Успешно!"

echo
logger "2 - Запускам сборку"
if [ $? -eq 0 ]; then
	logger "Начинаю новую сборку"
	make >> "${LOG_PATH}"  2>&1
	logger "Сборка окончена"
	logger "Тестирую сборку"
	make check >> "${LOG_PATH}"  2>&1
else
	logger "Конфигурация с ошибками, продолжение невозможно"
	exit 2
fi
logger "Успешно!"

echo "##################################################"
echo " Сборка PostgreSQL успешно осуществлена!"
echo " Для ее установки запустите скрипт install_postgresql.sh"
