#!/bin/bash

useradd -m \
	-d /postgres \
	-s /bin/bash \
	-c "Суперпользователь СУБД PostgreSQL" \
	postgres

usermod -a -G users postgres

#echo "Задайте пароль для postgres:"
#passwd postgres
