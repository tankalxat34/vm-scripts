#!/bin/bash

# создает файловую систему для PostgreSQL
# (c) tankalxat34 - 2025

lsblk

echo "#####################################################"
echo "1 - проверяю наличие каталогов"

echo

dirname="/data"
echo "Директория $dirname"
if [ -d "$dirname" ]; then
	echo "$dirname существует"
else
	echo "Введите путь к физическому тому:"
        read dev_to_data

        mkdir $dirname
        echo "Директория $dirname создана"
fi
        
dirname="/log"
echo "Директория $dirname"
if [ -d "$dirname" ]; then
        echo "$dirname существует"
else
        echo "Введите путь к физическому тому:"
        read dev_to_log

        mkdir $dirname
        echo "Директория $dirname создана"
fi

dirname="/wal"
echo "Директория $dirname"
if [ -d "$dirname" ]; then
        echo "$dirname существует"
else
        echo "Введите путь к физическому тому:"
        read dev_to_wal

        mkdir $dirname
        echo "Директория $dirname создана"
fi

dirname="/backup"
echo "Директория $dirname"
if [ -d "$dirname" ]; then
        echo "$dirname существует"
else
        echo "Введите путь к физическому тому:"
        read dev_to_backup

        mkdir $dirname
        echo "Директория $dirname создана"
fi



echo "#####################################################"
echo "2 - создаю lvm на каждом из дисков"

echo "2.1 - создаем Physical Volume"

pvcreate $dev_to_data
pvcreate $dev_to_log
pvcreate $dev_to_wal
pvcreate $dev_to_backup

echo "2.2 - создаем Volume Group"

vgcreate vg_data 	$dev_to_data
vgcreate vg_log 	$dev_to_log
vgcreate vg_wal 	$dev_to_wal
vgcreate vg_backup 	$dev_to_backup

echo "2.3 - создаем Logical Volume"

lvcreate -l 100%FREE -n data vg_data
lvcreate -l 100%FREE -n log vg_log
lvcreate -l 100%FREE -n wal vg_wal
lvcreate -l 100%FREE -n backup vg_backup


echo "#####################################################"
echo "3 - форматирование ФС на каждом из дисков"

mkfs.ext4 /dev/vg_data/data
mkfs.ext4 /dev/vg_log/log
mkfs.ext4 /dev/vg_wal/wal
mkfs.ext4 /dev/vg_backup/backup

echo "#####################################################"
echo "4 - монтирование ФС в соответствующие каталоги"

mount /dev/vg_data/data /data
mount /dev/vg_log/log /log
mount /dev/vg_wal/wal /wal
mount /dev/vg_backup/backup /backup


echo "#####################################################"
echo "5 - фиксация в /etc/fstab"

echo "/dev/vg_data/data	/data	ext4	defaults	0	2" >> /etc/fstab
echo "/dev/vg_log/log /log	ext4	defaults	0	2" >> /etc/fstab
echo "/dev/vg_wal/wal /wal	ext4	defaults	0	2" >> /etc/fstab
echo "/dev/vg_backup/backup /backup	ext4	defaults	0	2" >> /etc/fstab

systemctl daemon-reload
lsblk


