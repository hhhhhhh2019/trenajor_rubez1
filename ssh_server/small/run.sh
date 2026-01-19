#!/bin/sh

mountpoint -q merged && umount merged
mount -t overlay overlay -o index=off,lowerdir=root,upperdir=overlay,workdir=work merged

echo $$ > /sys/fs/cgroup/jail/leaf/cgroup.procs

exec env -i unshare \
	--ipc --mount --uts --cgroup --pid \
	--fork --kill-child \
	--map-users 0:100000:65536 --map-groups 0:100000:65536 -r \
	-R ./merged /init
