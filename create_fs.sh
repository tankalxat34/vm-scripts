# создает файловую систему для PostgreSQL
# (c) tankalxat34 - 2025

echo "#####################################################"
echo "1 - проверяю наличие каталогов"

echo
echo "Директория /data"
if [ -d "/data" ]; then
	echo "/data существует"
else
	echo "Введите размер тома:"
	read size_data

	echo "Введите путь к физическому тому:"
	read dev_to_data

	mkdir /data
	echo "/data создан"
fi

echo
echo "Директория /log"
if [ -d "/log" ]; then
        echo "/log существует"
else
        echo "Введите размер тома:"
        read size_log

	echo "Введите путь к физическому тому:"
        read dev_to_log

        mkdir /log
        echo "/log создан"
fi

echo
echo "Директория /wal"
if [ -d "/wal" ]; then
        echo "/wal существует"
else
        echo "Введите размер тома:"
        read size_wal

	echo "Введите путь к физическому тому:"
        read dev_to_wal

        mkdir /wal
        echo "/wal создан"
fi

echo
echo "Директория /backup"
if [ -d "/backup" ]; then
        echo "/backup существует"
else
        echo "Введите размер тома:"
        read size_backup

	echo "Введите путь к физическому тому:"
        read dev_to_backup

        mkdir /backup
        echo "/backup создан"
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
vgcreate vg_log		$dev_to_log
vgcreate vg_wal 	$dev_to_wal
vgcreate vg_backup 	$dev_to_backup

echo "2.3 - создаем Logical Volume"
lvcreate -L $size_data	 -n data vg_data
lvcreate -L $size_log 	 -n log  vg_log
lvcreate -L $size_wal 	 -n wal  vg_wal
lvcreate -L $size_backup -n backup vg_backup

echo "#####################################################"
echo "3 - форматирование ФС на каждом из дисков"

mkfs.ext4 /dev/vg_data/data
mkfs.ext4 /dev/vg_log/log
mkfs.ext4 /dev/vg_wal/wal
mkfs.ext4 /dev/vg_backup/backup

echo "#####################################################"
echo "4 - монтирование ФС в соответствующие каталоги"

mount /dev/vg_data/data /data
mount /dev/vg_log/log  /log
mount /dev/vg_wal/wal   /wal
mount /dev/vg_backup/backup /backup

echo "#####################################################"
echo "5 - фиксация в /etc/fstab"

echo "### create_fs.sh ###"
echo "/dev/vg_data/data	/data	ext4	defaults	0	2" >> /etc/fstab
echo "/dev/vg_log/log  /log   ext4    defaults        0       2" >> /etc/fstab
echo "/dev/vg_wal/wal  /wal   ext4    defaults        0       2" >> /etc/fstab
echo "/dev/vg_backup/backup  /backup   ext4    defaults        0       2" >> /etc/fstab

echo "### Скрипт отработал успешно"
lsblk


