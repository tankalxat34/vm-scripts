# создает файловую систему для PostgreSQL
# (c) tankalxat34 - 2025

lsblk

echo "#####################################################"
echo "1 - проверяю наличие каталогов"

echo
echo "Директория /data"
if [ -d "/data" ]; then
	echo "/data существует"
else
	echo "Введите путь к физическому тому:"
	read dev_to_data

	# size_data=$(lsblk | awk -v name="$dev_to_data" '$1 == name {print $4}')

	mkdir /data
	#echo "Директория создана. Размер тома: $size_data"
	echo "Директория создана"
fi


echo "#####################################################"
echo "2 - создаю lvm на каждом из дисков"

echo "2.1 - создаем Physical Volume"

pvcreate $dev_to_data


echo "2.2 - создаем Volume Group"

vgcreate vg_data 	$dev_to_data


echo "2.3 - создаем Logical Volume"

lvcreate -l 100%FREE -n data vg_data


echo "#####################################################"
echo "3 - форматирование ФС на каждом из дисков"

mkfs.ext4 /dev/vg_data/data


echo "#####################################################"
echo "4 - монтирование ФС в соответствующие каталоги"

mount /dev/vg_data/data /data


echo "#####################################################"
echo "5 - фиксация в /etc/fstab"
echo "/dev/vg_data/data	/data	ext4	defaults	0	2" >> /etc/fstab

systemctl daemon-reload
lsblk


