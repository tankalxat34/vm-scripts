umount /data
umount /log
umount /wal
umount /backup

rm -rf /data /log /wal /backup

lvremove /dev/vg_data/data
lvremove /dev/vg_log/log
lvremove /dev/vg_wal/wal
lvremove /dev/vg_backup/backup

vgremove vg_data
vgremove vg_log
vgremove vg_wal
vgremove vg_backup

if [ -d "/etc/fstab.d.bak" ]; then
	mkdir /etc/fstab.d.bak
fi

cat /etc/fstab > /etc/fstab.d.bak/fstab
cat /etc/fstab | grep -vE "/dev/vg_data/data|/dev/vg_log/log|/dev/vg_wal|/dev/vg_wal/wal|/dev/vg_backup/backup" > /etc/fstab
