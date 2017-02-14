#!/bin/bash
# mxu 的运行环境 nginx1.8.1 + (php5.3.29, php5.6.22)

# 判断端口是否被占用
netstat -tpln | grep -q -w 80 && { echo -e "${RED}80端口被占用${BLACK}"; exit 1; }

function install_nginx () {
    pushd .
    cd ./package
    grep -q www /etc/passwd || useradd -M -s /sbin/nologin www
    local CPU_NUM=$(grep -c processor /proc/cpuinfo)
    [ -f nginx-1.8.1.tar.gz ] || wget http://op.hoge.cn/src/nginx-1.8.1.tar.gz
    tar -zx -f nginx-1.8.1.tar.gz
    cd nginx-1.8.1
    ./configure --user=www --group=www --prefix=/m2odata/server/nginx-1.8.1 --with-http_stub_status_module --with-http_sub_module --with-http_ssl_module
    [ "$CPU_NUM" -gt 1 ] && make -j$CPU_NUM || make
    make install
    pushd +1
    popd +1
    \cp ./web/template/fcgi.conf /m2odata/server/nginx-1.8.1/conf/
    \cp ./web/template/nginx.conf /m2odata/server/nginx-1.8.1/conf/
    ln -s /m2odata/server/nginx-1.8.1 /m2odata/server/nginx
    ln -s /m2odata/server/nginx/sbin/nginx /usr/local/bin/nginx
    [ -d /m2odata/server/nginx-1.8.1/conf/conf.d ] || mkdir /m2odata/server/nginx-1.8.1/conf/conf.d
}

# php 5.3.29
function php53 () {
    pushd .
    cd ./package
    [ -f php5.3.29_p1-bin.tar.gz ] || wget http://op.hoge.cn/bin/php5.3.29_p1-bin.tar.gz
    tar -zx -f php5.3.29_p1-bin.tar.gz
    cd php5.3.29-bin
    \cp -r php-5.3.29 /m2odata/server/
    ln -s /m2odata/server/php-5.3.29 /m2odata/server/php
    \cp -f php-fpm /etc/init.d/php-fpm
    chown root:root /etc/rc.d/init.d/php-fpm
    pushd +1
    popd +1
    \cp ./web/template/php53.ini /m2odata/server/php-5.3.29/etc/php.ini
    \cp ./web/template/php-fpm53.conf /m2odata/server/php-5.3.29/etc/php-fpm.conf
}

# php 5.6.22
function php56 () {
    pushd .
    cd ./package
    [ -f php5.6.22-bin.tar.gz ] || wget http://op.hoge.cn/bin/php5.6.22-bin.tar.gz
    tar -zx -f php5.6.22-bin.tar.gz
    cd php5.6.22-bin
    \cp -r php-5.6.22 /m2odata/server/
    ln -s /m2odata/server/php-5.6.22 /m2odata/server/php56
    ln -s /m2odata/server/php56/bin/php /usr/local/bin/php
    \cp -f php-fpm56 /etc/init.d/php-fpm56
    chown root:root /etc/rc.d/init.d/php-fpm56
    pushd +1
    popd +1
    \cp ./web/template/php56.ini /m2odata/server/php-5.6.22/etc/php.ini
    \cp ./web/template/php-fpm56.conf /m2odata/server/php-5.6.22/etc/php-fpm.conf
}

# mysqlclient必须在php53，php56之后执行，因为所需的动态文件库在压缩包里面
function mysqlclient () {
    [ -d /usr/local/mysqllib_php/lib ] || mkdir -p /usr/local/mysqllib_php/lib
    cd ./package
    # php5.3
    if [ ! -f /usr/lib64/libmysqlclient.so.18 ];then
        \cp -f ./php5.3.29-bin/libmysqlclient.so.18.0.0 /usr/local/mysqllib_php/lib/
        ln -f -s /usr/local/mysqllib_php/lib/libmysqlclient.so.18.0.0 /usr/lib64/libmysqlclient.so.18
        chmod 755 /usr/local/mysqllib_php/lib/libmysqlclient.so.18.0.0
    fi
    # php5.6
    if [ ! -f /usr/lib64/libmysqlclient.so.20 ];then
        \cp -f ./php5.6.22-bin/libmysqlclient.so.20.3.0 /usr/local/mysqllib_php/lib/
        ln -f -s /usr/local/mysqllib_php/lib/libmysqlclient.so.20.3.0 /usr/lib64/libmysqlclient.so.20
        chmod 755 /usr/local/mysqllib_php/lib/libmysqlclient.so.20.3.0
    fi

    [ -d /usr/local/lib/ ] || mkdir -p /usr/local/lib/
    if [ ! -f /usr/lib64/libmcrypt.so.4 ];then
        \cp -f ./php5.3.29-bin/libmcrypt.so.4.4.8 /usr/local/lib/
        ln -f -s /usr/local/lib/libmcrypt.so.4.4.8 /usr/lib64/libmcrypt.so.4
        chmod 755 /usr/local/lib/libmcrypt.so.4.4.8
    fi

    if [ ! -f /usr/lib64/libiconv.so.2 ];then
        \cp -f ./php5.3.29-bin/libiconv.so.2.5.1 /usr/local/lib/
        ln -f -s /usr/local/lib/libiconv.so.2.5.1 /usr/lib64/libiconv.so.2
        chmod 755 /usr/local/lib/libiconv.so.2.5.1
    fi
    cd ..
}

# install nginx,php5.3,php5.6,mysqlclient.so
[ -d /m2odata/server/nginx-1.8.1 ] && echo -e "nginx已存在，下面会自启动\n" || install_nginx
[ -d /m2odata/server/php-5.3.29 ] && echo -e "php5.3已存在，下面会自启动\n" || php53
[ -d /m2odata/server/php-5.6.22 ] && echo -e "php5.6已存在，下面会自启动\n" || php56
mysqlclient

# 添加iptables
function add_iptables() {
    local iptables_conf="/etc/sysconfig/iptables"
    grep -w -q 80 $iptables_conf
    if [ $? != 0 ];then
        sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT' $iptables_conf
        /etc/init.d/iptables reload
    fi
}

# 启动 nginx,php5.3,php5.6
echo -e "启动nginx\n"
/m2odata/server/nginx-1.8.1/sbin/nginx
[ -S /dev/shm/php-cgi.sock ] && echo -e "php-fpm已启动\n" || /etc/init.d/php-fpm start
[ -S /dev/shm/php-cgi56.sock ] && echo -e "php-fpm56已启动\n" || /etc/init.d/php-fpm56 start

add_iptables

echo -e "WEB环境部署完成！\n"
