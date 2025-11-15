#!/bin/bash

useradd -m \
	-d /postgres \
	-s /bin/bash \
	-c "Суперпользователь СУБД PostgreSQL" \
	-g sudo \
	postgres

usermod -a -G users

echo "Задайте пароль для postgres:"
passwd postgres
