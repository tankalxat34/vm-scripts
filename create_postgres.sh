useradd -m \
	-d /postgres \
	-s /bin/bash \
	-c "Суперпользователь СУБД PostgreSQL"
	-g sudo \
	postgres

usermod -a -G users
