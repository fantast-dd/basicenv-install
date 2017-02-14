#!/bin/bash

function hostadd () {

cat >>/etc/hosts<<EOF
#hogesoft
121.201.15.146    package.hogesoft.com
121.201.15.146    upgrade.hogesoft.com
121.201.15.146    auth.hogesoft.com
121.201.15.146    appstore.hogesoft.com
218.2.102.114     yum.hogesoft.com
EOF
}

function repo () {

appid=`awk -F '=' '/\[auth\]/{a=1}a==1&&$1~/appid/{print $2;exit}' config.ini`
[ -n "$appid" ] || { echo -e "${RED}Error: config.ini未设置appid${BLACK}"; exit 1; }
appkey=`awk -F '=' '/\[auth\]/{a=1}a==1&&$1~/appkey/{print $2;exit}' config.ini`
[ -n "$appkey" ] || { echo -e "${RED}Error: config.ini未设置appkey${BLACK}"; exit 1; }

cat >/etc/yum.repos.d/Hoge.repo<<EOF
[hoge]
name=CentOS-6 - Extras
baseurl=http://yum.hogesoft.com:8100/
failovermethod=priority
enabled=1
keepcache=1
gpgcheck=1
gpgkey=http://yum.hogesoft.com:8100/RPM-GPG-KEY-HOGE
appid=$appid
appkey=$appkey
EOF
yum clean all
yum makecache fast
}

grep -q hogesoft /etc/hosts || hostadd
[ -f /etc/yum.repos.d/Hoge.repo ] || repo
