set -e

# mount --bind ./namespaces ./namespaces
# mount --make-private ./namespaces
# touch ./namespaces/mnt

mkdir /sys/fs/cgroup/jail
echo "+cpu +memory +pids" > /sys/fs/cgroup/jail/cgroup.subtree_control
echo $((512*1024*1024)) > /sys/fs/cgroup/jail/memory.max
echo 1024 > /sys/fs/cgroup/jail/pids.max
echo 20000 > /sys/fs/cgroup/jail/cpu.max

mkdir /sys/fs/cgroup/jail/leaf

# NAMESPACE="rubez"
# VETH0="veth0"
# VETH1="veth1"
# IP_VETH0="192.168.100.11/24"
# IP_VETH1="192.168.100.12/24"
#
# ip netns add $NAMESPACE
# ip link add $VETH0 type veth peer name $VETH1
# ip link set $VETH1 netns $NAMESPACE
# ip addr add $IP_VETH0 dev $VETH0
# ip netns exec $NAMESPACE ip addr add $IP_VETH1 dev $VETH1
# ip link set $VETH0 up
# ip netns exec $NAMESPACE ip link set $VETH1 up
