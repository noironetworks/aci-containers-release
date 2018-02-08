#!/bin/bash

ID=`id -u`
if [ "$ID" -ne 0 ]
then
  echo "You must be root to run this command"
  exit 1
fi

host=$(cat /var/vcap/instance/name)_$(cat /var/vcap/instance/id)
time_stamp=`date +'%y%m%d-%H%M%S'`
report_name="report-${host}_${time_stamp}"
report_dir="/tmp/${report_name}"
report_file="${report_dir}.tar.gz"

exec 3>&1
prn() { echo "$@" 1>&3 ; }

prn "Creating host report: $report_file"
prn "  Collecting host info ..."
mkdir $report_dir
cd $report_dir
  exec 1>stdout 2>stderr

  date > date-start
  hostname > vm-name
  echo $host > hostname
  uname -a > uname
  uptime > uptime
  dmesg > dmesg
  dmidecode > dmidecode || true
  lspci > lspci  || true

  ulimit -a > ulimit
  cat /proc/meminfo > meminfo
  cat /proc/cpuinfo > cpuinfo
  free > free
  ps auxww > ps
  top -b -n3 > top
  cat /proc/mounts > mount
  fdisk -l > fdisk
  df > df
  lsmod > lsmod
  sysctl -a > sysctl
  chkconfig --list > chkconfig 2>&1
  service --status-all > service-status-all 2>&1

cd $report_dir
mkdir etc
  prn "  Collecting system config files"
  cd etc
  cp /etc/*release .
  cp /etc/sysctl.conf .

  prn "  Collecting package info (this can take some time) ..."
  rpm -qa > rpm-qa
  rpm -Va > rpm-Va || true
  dpkg -l > dpkg-l

cd $report_dir
mkdir -p var/vcap/jobs
  prn "  Collecting job config files"
  cd var/vcap/jobs
  for i in aci-cf-controller aci-cf-host-agent agent-ovs openvswitch-switch network-setup
  do
    if [ -d /var/vcap/jobs/$i/config ]; then
      mkdir $i
      cp -r /var/vcap/jobs/$i/config $i/
    fi
  done

cd $report_dir
prn "  Collecting network info ..."
mkdir network
  cd network
  ip link > ip-link
  ip address > ip-address
  ip route > ip-route
  ip netns > ip-netns
  cat /proc/net/igmp > igmp
  ifconfig > ifconfig
  netstat -tlpn > netstat-tlpn
  netstat -s > netstat-s
  lldpctl > lldpctl || true
  lldpctl -f keyvalue > lldpctl-kv || true
  iptables -S > iptables-S
  iptables -S -t nat > iptables-S-t-nat

if [ -d /var/vcap/jobs/agent-ovs ]; then
  prn "  Collecting opflex info ..."
  cd $report_dir
  mkdir opflex
    cd opflex
    ping -c 3 -w 5 10.0.0.30 1>ping-10.0.0.30 2>&1
    cp -r /var/vcap/data/agent-ovs data
    AGENT_PKG_DIR=/var/vcap/packages/agent-ovs
    OVS_PKG_DIR=/var/vcap/packages/openvswitch
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$AGENT_PKG_DIR/usr/lib:$AGENT_PKG_DIR/usr/lib/x86_64-linux-gnu:$OVS_PKG_DIR/usr/lib
    export PATH=$PATH:$AGENT_PKG_DIR/usr/bin:$OVS_PKG_DIR/usr/bin:$OVS_PKG_DIR/usr/sbin
    gbp_inspect -fpr -t dump -q DmtreeRoot > dmtree-root
    ovs-vsctl show > ovs-show
    ovs-ofctl dump-ports-desc br-int > ovs-br-int-ports
    ovs-ofctl dump-ports br-int > ovs-br-int-ports-stats
    ovs-ofctl -OOpenFlow13 dump-flows br-int > ovs-br-int-flows
    ovs-ofctl dump-ports-desc br-access > ovs-br-access-ports
    ovs-ofctl dump-ports br-access > ovs-br-access-ports-stats
    ovs-ofctl -OOpenFlow13 dump-flows br-access > ovs-br-access-flows
    ovs-dpctl show > ovs-ports-dp
    ovs-appctl dpif/tnl/igmp-dump br-int 8472 > ovs-igmp
fi

prn "  Collecting log data (this can take some time) ..."
cd $report_dir
mkdir -p var/vcap/log
  date > var/vcap/log/date-reports
  cp -r /var/vcap/sys/log var/vcap/

prn "  Creating tar file ..."
cd $report_dir
  date > date-end
  cd ..
  tar -czf $report_file `basename $report_dir`

cd /tmp
exec 2>&1
rm -rf "$report_dir"
prn "Created report: $report_file"
