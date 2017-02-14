#!/bin/bash

# 安装必要的包
yum -y install epel-release dstat wget pcre-devel ntp vim-enhanced gcc gcc-c++ gcc-gfortran flex bison autoconf automake make bzip2 bzip2-devel.x86_64 ncurses ncurses-devel.x86_64 libjpeg.x86_64 libjpeg-devel libjpeg-turbo.x86_64 libjpeg-turbo-devel.x86_64 libpng.x86_64 libpng-devel libtiff.x86_64 libtiff-devel freetype.x86_64 freetype-devel pam-devel.x86_64 curl.x86_64 curl-devel.x86_64 libcurl-devel.x86_64 zlib zlib-devel.x86_64 glibc glibc-devel.x86_64 glib2.x86_64 glib2-devel.x86_64 gettext-devel.x86_64 libtool libxml2.x86_64 libxml2-devel.x86_64 e2fsprogs e2fsprogs-devel.x86_64 krb5 krb5-devel.x86_64 libidn.x86_64 libidn-devel.x86_64 openssl openssl-devel.x86_64 sysstat libcurl-devel libtidy-devel unzip

# 更新所有包
yum update -y

# 修改主机名
function edit_hostname () {
    name=`awk -F '=' '/\[system\]/{a=1}a==1&&$1~/hostname/{print $2;exit}' config.ini`
    [ -n "$name" ] || echo -e "${YELLOW}Warning: config.ini未设置hostname${BLACK}"
    current_name=`hostname`
    [ "$name" = "$current_name" ] || sed -r -i "s/^(HOSTNAME=).*/\1$name/" /etc/sysconfig/network
}

# 修改内核参数
function edit_sysctl () {
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat >>/etc/sysctl.conf<<EOF

# hogesoft add
# IPv6 disabled
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1

# add - time-wait
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 20000

#close rfc1323 timestamps
net.ipv4.tcp_timestamps = 0

# max open files
fs.file-max =6553560
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096

net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_buckets = 65536
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_syn_retries = 3
EOF
}

# 修改文件描述符
function edit_ulimit () {
    sed -i /soft/s/*/#*/  /etc/security/limits.d/90-nproc.conf
    local limits_conf="/etc/security/limits.conf"
    grep -q "\* soft nofile 65535" $limits_conf || echo "* soft nofile 65535" >> $limits_conf
    grep -q "\* hard nofile 65535" $limits_conf || echo "* hard nofile 65535" >> $limits_conf
}

# 关闭selinux
function edit_selinux () {
    status=`getenforce`
    [ "$status" = "Disabled" ] || sed -r -i "s/^(SELINUX=).*/\1disabled/" /etc/selinux/config
}

# ntpdate加入计划任务
function add_ntpdate () {
    grep -q "ntpdate" /var/spool/cron/root || echo "1 * * * * /usr/sbin/ntpdate pool.ntp.org" >>/var/spool/cron/root
}

function add_hosts () {
    local dbip=`awk -F '=' '/\[mysql\]/{a=1}a==1&&$1~/dbip/{print $2;exit}' config.ini`
    [ -n "$dbip" ] || echo -e "${YELLOW}Warning: config.ini未设置dbip${BLACK}"
    grep -q "$dbip" /etc/hosts || echo -e "$dbip\tdb.mxu" >>/etc/hosts
}

# 新建相关目录，如果目录存在则chmod，不存在则新建目录并chmod
function add_dirs() {
    [ -d /m2odata ] || mkdir /m2odata && chmod 755 /m2odata
    [ -d /m2odata/server ] || mkdir /m2odata/server && chmod 755 /m2odata/server
    [ -d /m2odata/log ] || mkdir /m2odata/log && chmod 777 /m2odata/log
    [ -d /m2odata/tmp ] || mkdir /m2odata/tmp && chmod 777 /m2odata/tmp
    [ -d /m2odata/www ] || mkdir /m2odata/www && chmod 755 /m2odata/www
    [ -d /m2odata/sh ] || mkdir /m2odata/sh && chmod 755 /m2odata/sh
}

# 执行
edit_hostname
grep -q "# hogesoft add" /etc/sysctl.conf || { edit_sysctl; sysctl -p; }
edit_ulimit
edit_selinux
add_ntpdate
add_hosts
add_dirs

echo -e "\n环境初始化完成！\n"

while true
do
    read -p "是否重启主机[Y/n]" reboot_choice
    case $reboot_choice in 

        [yY])
            reboot
            ;;
        [nN])
            exit
            ;;
        *)
            echo -e "\t请输入正确的choice\n"
            ;;
    esac
done
