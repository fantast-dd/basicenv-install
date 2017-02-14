#!/bin/bash

cd ./vod

# 判断端口是否被占用
netstat -tpln | grep -q -w 83 && { echo -e "${RED}83端口被占用${BLACK}"; exit 1; }

function install() {
    grep -q www /etc/passwd || useradd -M -s /sbin/nologin www
    yum install -y m2o_vod_nginx
    \cp ./template/m2o_vod_nginx.conf /usr/local/m2o_vod_nginx/conf/
    [ -d /usr/local/m2o_vod_nginx/conf/conf.d ] || mkdir /usr/local/m2o_vod_nginx/conf/conf.d
    \cp ./template/vod.conf /usr/local/m2o_vod_nginx/conf/conf.d/
    [ -d /usr/local/m2o_vod_nginx/db ] || { mkdir /usr/local/m2o_vod_nginx/db; chown www:www /usr/local/m2o_vod_nginx/db; }
    [ -d /storage/vod/mp4 ] || { mkdir -p /storage/vod/mp4; chown 777 /storage/vod/mp4; }
    [ -d /storage/vod/uploads ] || { mkdir -p /storage/vod/uploads; chown 777 /storage/vod/uploads; }
}

function add_iptables() {
    local iptables_conf="/etc/sysconfig/iptables"
    grep -w -q 83 $iptables_conf
    if [ $? != 0 ];then
        sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 83 -j ACCEPT' $iptables_conf
        /etc/init.d/iptables reload
    fi
}

rpm -q --quiet m2o_vod_nginx
if [ $? != 0 ];then
    install
    add_iptables
    echo -e "点播服务安装成功！\n"
else
    echo -e "点播服务已安装！\n"
fi

/usr/local/m2o_vod_nginx/sbin/nginx -c /usr/local/m2o_vod_nginx/conf/m2o_vod_nginx.conf
