#!/bin/bash
# 安装转码和收录

cd ./record

# 判断端口是否被占用
netstat -tpln | grep -q -w 8089 && { echo -e "${RED}8089端口被占用${BLACK}"; exit 1; }

function install_record () {
    yum install -y hoge_recordserver
	# config
    auth_appid=`awk -F '=' '/\[auth\]/{a=1}a==1&&$1~/appid/{print $2;exit}' ../config.ini`
    [ -n "$auth_appid" ] || { echo -e "${RED}Error: config.ini未设置auth_appid${BLACK}"; exit 1; }
    auth_appkey=`awk -F '=' '/\[auth\]/{a=1}a==1&&$1~/appkey/{print $2;exit}' ../config.ini`
    [ -n "$auth_appkey" ] || { echo -e "${RED}Error: config.ini未设置auth_appkey${BLACK}"; exit 1; }

    \cp -f ./template/recordserver.ini /usr/local/Hoge/etc/
    sed -i -r "s/(auth_appid=).*/\1$auth_appid/g" /usr/local/Hoge/etc/recordserver.ini
    sed -i -r "s/(auth_appkey=).*/\1$auth_appkey/g" /usr/local/Hoge/etc/recordserver.ini
}

function add_iptables () {
    local iptables_conf="/etc/sysconfig/iptables"
    grep -q -w 8089 $iptables_conf
    if [ $? != 0 ];then
        sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 8089 -j ACCEPT' $iptables_conf
        /etc/init.d/iptables reload
    fi
}

rpm -q --quiet hoge_recordserver
if [ $? != 0 ];then
    install_record
    echo -e "收录服务已安装完成！\n"
else
    echo -e "收录服务已安装！\n"
fi

add_iptables

# 启动收录服务
/usr/local/Hoge/bin/recordserver_run
