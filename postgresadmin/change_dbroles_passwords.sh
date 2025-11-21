#/bin/bash
# ------------------------------------------------
# Название: change_dbroles_passwords.sh
# Автор:    tankalxat34
# Версия:   0.1.0
# Описание: Скрипт меняет пароли указанным пользователям СУБД на указанных серверах
# ------------------------------------------------

echo "# ------------------------------------------------"
echo "!!! Перед продолжением убедиться, что пароль учетки postgres задан в ~/.pgpass !!!"
echo "# ------------------------------------------------"
echo ""

if [ -e "./tankalxat34lib.sh" ]; then
  source tankalxat34lib.sh
  logmsg "OK" "Импортирована библиотека tankalxat34lib"
else
  echo "Библиотека tankalxat34lib не найдена"
  exit 1
fi

read -p "Введите через пробел роли пользователей:" -a ROLNAMES
read -p "Введите через пробел имена или ip-адреса серверов СУБД:" -a SERVERS

STR_SERVERS=$(printf "%s_" "${SERVERS[@]}" | sed 's/_$//')
TARGETDIR=~/passwds

if test -d${TARGETDIR}; then rm -rf ${TARGETDIR}; fi
mkdir ${TARGETDIR} > /dev/null 2>&1

for usename in "${ROLNAMES[@]}"; do
  passwd=$(tr -dc 'A-Za-z0-9#@#$%^&*()_+-' </dev/urandom | head -c 16)
  arcpasswd=$(tr -dc 'A-Za-z0-9#@#$%^&*()_+-' </dev/urandom | head -c 25)

  echo "${usename} : ${passwd} :${arcpasswd}"
  for server in "${SERVERS[@]}"; do
    psql -x -h $server -c "select rolname from pg_roles where rolname='${usename}';" && \
      psql -h $server -c "ALTER ROLE ${usename} PASSWORD '${passwd}' ;" && \
      psql -x -h $server -c "select rolname from pg_roles where rolname='${usename}';" && \
        logmsg "OK" "${server} учетная запись ${usename} - установлен пароль на ${passwd}"
  done

  filename="${TARGETDIR}/${usename}_${STR_SERVERS}.txt"
  touch $filename
  echo -e "Сервера СУБД: ${SERVERS[@]}\n\n" >> $filename
  echo -e "  Пользователь СУБД:${usename}"  >> $filename
  echo -e "  Пароль: ${passwd}"             >> $filename
  echo -e "  Пароль к архиву: ${arcpasswd}" >> $filename
  zip -j -P "${arcpasswd}" "$TARGETDIR/${usename}_${STR_SERVERS}.zip" $filename
done
