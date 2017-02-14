#!/bin/bash
# 新直播
# author pdd 2016/10/2

cd ./live

# 判断端口是否被占用
netstat -tpln | grep -q -w 2881 && { echo -e "${RED}Error: 2881端口被占用${BLACK}"; exit 1; }
netstat -tpln | grep -q -w 82 && { echo -e "${RED}Error: 82端口被占用${BLACK}"; exit 1; }
netstat -tpln | grep -q -w 2880 && { echo -e "${RED}Error: 2880端口被占用${BLACK}"; exit 1; }
netstat -tpln | grep -q -w 9935 && { echo -e "${RED}Error: 9935端口被占用${BLACK}"; exit 1; }

rpm -q --quiet hoge_ffmpeg || yum install -y hoge_ffmpeg
rpm -q --quiet supervisor || yum install -y supervisor

function pyrtmp_install () {
    # 判断/storage分区大小是否大于300G，不好判断，分区标识不能确定 
    [ -d /storage/dvr ] || { mkdir -p /storage/dvr; chmod 755 /storage/dvr; chown -R nobody /storage/dvr; }
    [ -d /m2odata/server ] || mkdir -p /m2odata/server
    [ -d /m2odata/log/pyrtmp ] || mkdir -p /m2odata/log/pyrtmp
    wget http://yum.hogesoft.com:8100/pyrtmp-0.0.4.tar.gz -P /m2odata/server
    tar -zx -f /m2odata/server/pyrtmp-0.0.4.tar.gz -C /m2odata/server
    \cp ./template/pyrtmp.conf /m2odata/server/pyrtmp-0.0.4/
    \cp ./template/logging.conf /m2odata/server/pyrtmp-0.0.4/
}

function supervisord_conf () {
\cp /etc/supervisord.conf /etc/supervisord.conf.bak
cat >>/etc/supervisord.conf<<EOF

[program:pyrtmp]
command=sh -c "PYRTMP_CONFIG=/m2odata/server/pyrtmp/pyrtmp.conf /m2odata/server/pyrtmp/manage runserver"
autostart=true
stopsignal=INT
stopwaitsecs=30
log_stdout=true                           ; if true, log program stdout (default true)
log_stderr=true                           ; if true, log program stderr (def false)
logfile=/var/log/supervisor/pyrtmp.log    ; child log path, use NONE for none; default AUTO
logfile_maxbytes=1MB                      ; max # logfile bytes b4 rotation (default 50MB)
logfile_backups=10                        ; # of logfile backups (default 10)
EOF
}

function hoge_tsmanager_install () {
    yum install -y hoge_tsmanager
    \cp ./template/ts_manager.ini /usr/local/Hoge/etc/
    \cp ./template/Hoge_nginx.conf /usr/local/Hoge/conf/nginx.conf
    # 设置直播域名
    livename=`awk -F '=' '/\[stream\]/{a=1}a==1&&$1~/livename/{print $2;exit}' ../config.ini`
    [ -n "$livename" ] && sed -i -r "s/(server_name).*/\1   $livename;/g" /usr/local/Hoge/conf/nginx.conf || echo -e "${YELLOW}Warning: 直播域名未设置${BLACK}"
}

function hoge_nginx_install () {
    #yum install -y hoge_nginx
    # 复制配置文件
    \cp ./template/Hoge_nginx.conf /usr/local/Hoge/conf/nginx.conf
    # 设置直播域名
    livename=`awk -F '=' '/\[stream\]/{a=1}a==1&&$1~/livename/{print $2;exit}' ../config.ini`
    [ -n "$livename" ] && sed -i -r "s/(server_name).*/\1   $livename;/g" /usr/local/Hoge/conf/nginx.conf || echo -e "${YELLOW}Warning: 直播域名未设置${BLACK}"
}

# 设置防火墙
function add_iptables() {
    local iptables_conf="/etc/sysconfig/iptables"
    grep -w -q 9935 $iptables_conf 
    p9935=$?
    [ $p9935 = 0 ] || sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 9935 -j ACCEPT' $iptables_conf
    grep -w -q 2880 $iptables_conf 
    p2880=$?
    [ $p2880 = 0 ] || sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 2880 -j ACCEPT' $iptables_conf
    grep -w -q 82 $iptables_conf
    p82=$?
    [ $p82 = 0 ] || sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 82 -j ACCEPT' $iptables_conf
    grep -w -q 2881 $iptables_conf 
    p2881=$?
    [ $p2881 = 0 ] || sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 2881 -j ACCEPT' $iptables_conf
    if [[ $p9935 != 0 || $p2880 != 0 || $p82 != 0 || $p2881 != 0 ]];then
        /etc/init.d/iptables reload
    fi
}

# 开机启动
function boot_add () {
cat >>/etc/rc.local<<EOF
# stream
/etc/init.d/supervisor start
/usr/local/Hoge/bin/ts_manager_run
/usr/local/Hoge/sbin/nginx
EOF
}

# 安装服务
[ -d /m2odata/server/pyrtmp-0.0.4 ] || pyrtmp_install
grep "\[program:pyrtmp\]" /etc/supervisord.conf || supervisord_conf
rpm -q --quiet hoge_tsmanager || hoge_tsmanager_install
#rpm -q --quiet hoge_nginx || hoge_nginx_install

# 启动服务
cd /m2odata/server/pyrtmp-0.0.4
mkdir -p /m2odata/server/log/pyrtmp
PYRTMP_CONFIG=/m2odata/server/pyrtmp-0.0.4/pyrtmp.conf /m2odata/server/pyrtmp-0.0.4/manage db upgrade
ln -s /m2odata/server/pyrtmp-0.0.4 /m2odata/server/pyrtmp
/etc/init.d/supervisord start
/usr/local/Hoge/sbin/nginx
/usr/local/Hoge/bin/ts_manager_run

# 设置iptables
add_iptables

# 开机启动
grep -q "# stream" /etc/rc.local || boot_add
