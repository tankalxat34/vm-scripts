#!/bin/bash

unset PGDATA

rm /etc/profile.d/pgsql.sh
rm -rf /data/pg_data /log/pg_log /wal/pg_wal
rm -rf /usr/local/pgsql 
