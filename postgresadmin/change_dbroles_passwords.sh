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

if [ -d ./tankalxat34lib.sh ]; then
  ./tankalxat34lib.sh
  echo "Импортирована библиотека tankalxat34lib"
else
  echo "Библиотека tankalxat34lib не найдена"
  exit 1
fi

STR_SERVERS=$(printf "%s_" "${SERVERS[@]}" | sed 's/_$//')
TARGETDIR=~/passwds

if test -d${TARGETDIR}; then rm -rf ${TARGETDIR}; fi
mkdir ${TARGETDIR} > /dev/null 2>&1

for usename in "${ROLNAMES[@]}"; do
  passwd=$(tr -dc 'A-Za-z0-9#@#$%^&*()_+-' </dev/urandom | head -c 16)
  arcpasswd=$(tr -dc 'A-Za-z0-9#@#$%^&*()_+-' </dev/urandom | head -c 25)

  echo "${usename} : ${passwd} :${arcpasswd}"
  for server in "${SERVERS[@]}"; do
    psql -x -h $server -c"select rolname,rolpasssetat from pg_roles where rolname='${usename}';" && \
      psql -h $server -c "ALTERROLE ${usename} PASSWORD '${passwd}' ;" && \
      psql -x -h $server -c"select rolname,rolpasssetat from pg_roles where rolname='${usename}';" && \
        echo "${server} учетная запись ${usename} - обновлен пароль на ${passwd}"
  done

  filename="${TARGETDIR}/${usename}_${STR_SERVERS}.txt"
  touch $filename
  echo -e "Сервера СУБД: ${SERVERS[@]}\n\n" >> $filename
  echo -e "  Пользователь СУБД:${usename}"  >> $filename
  echo -e "  Пароль: ${passwd}"             >> $filename
  echo -e "  Пароль к архиву: ${arcpasswd}" >> $filename
  zip -j -P "${arcpasswd}""$TARGETDIR/${usename}_${STR_SERVERS}.zip" $filename
done
