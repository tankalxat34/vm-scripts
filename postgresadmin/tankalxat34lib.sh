#/bin/bash
# ------------------------------------------------
# Название: tankalxat34lib.sh
# Автор:    tankalxat34
# Версия:   0.1.0
# Описание: Общая библиотека для скриптов postgresadmin на https://github.com/tankalxat34
# ------------------------------------------------

LOG_STATUS_OK="[OK]"
LOG_STATUS_ERROR="[ERROR]"

ask () {
    local PROMPT=$1
    local DEFVAL=$2

    read $@ -p "${PROMPT} (${DEFVAL}):" $cin
    cin={$cin;-$DEFVAL}
    echo $cin
}

logmsg () {
    local date=$(date '%(%Y-%m-%d %H:%M:%S)T\n')
    local status=$1
    local msg=$2

    echo -e "${date} %-3s ${status} %-3s : %-3s ${msg}"
}
