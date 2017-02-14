#!/bin/bash
# 二进制安装MYSQL

# 判断端口是否被占用
netstat -tpln | grep -q -w 3306 && { echo -e "${RED}3306端口被占用${BLACK}"; exit 1; }

basedir=/m2odata/server/mysql
datadir=/storage/db
user=mysql
password=`awk -F '=' '/\[mysql\]/{a=1}a==1&&$1~/password/{print $2;exit}' config.ini`
mxu_passwd=`awk -F '=' '/\[mysql\]/{a=1}a==1&&$1~/mxu_passwd/{print $2;exit}' config.ini`
[ -n "$password" ] || { echo -e "${RED}Error: config.ini未设置[mysql] password${BLACK}"; exit 1; }
[ -n "$mxu_passwd" ] || { echo -e "${RED}Error: config.ini未设置[mysql] mxu_passwd${BLACK}"; exit 1; }

# 安装所需包，添加用户名
grep -q $user /etc/passwd || useradd -M -s /sbin/nologin $user
rpm -q --quiet compat-libstdc++-33.x86_64 || yum -y install compat-libstdc++-33.x86_64
rpm -q --quiet libaio.x86_64 || yum -y install libaio.x86_64

# 配置文件
function config () {
    \cp -f ./mysql/template/my.cnf /etc/my.cnf
}

# 安装
function install () {
    cd ./package
    [ -f mysql-5.6.31-linux-glibc2.5-x86_64.tar.gz ] || wget http://op.hoge.cn/bin/mysql-5.6.31-linux-glibc2.5-x86_64.tar.gz
    tar -xz -f mysql-5.6.31-linux-glibc2.5-x86_64.tar.gz
    cp -rf mysql-5.6.31-linux-glibc2.5-x86_64 /m2odata/server/mysql
    chown -R $user:$user $basedir
}

# 数据库初始化
function init_db () {
    # 新建mysql数据目录
    [ -d $datadir ] || { mkdir -p $datadir; chown -R $user:$user $datadir; }
    cd $basedir
    ./scripts/mysql_install_db --user=$user --basedir=$basedir --datadir=$datadir
}

# 开机启动
function self_boot () {
    [ -f /etc/init.d/mysqld ] || { cp support-files/mysql.server /etc/init.d/mysqld; chmod 755 /etc/init.d/mysqld; }
    chkconfig --list mysqld >/dev/null  || { chkconfig --add mysqld; chkconfig mysqld on; }
}

# 添加iptables
function add_iptables() {
    local iptables_conf="/etc/sysconfig/iptables"
    grep -w -q 3306 $iptables_conf
    if [ $? != 0 ];then
        sed -i '/-i lo/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 3306 -j ACCEPT' $iptables_conf
        /etc/init.d/iptables reload
    fi
}

# 安全设置
function security () {
./bin/mysql_secure_installation<<EOF

Y
$password
$password
Y  
Y  
Y  
Y
EOF
}

# 添加mxu用户
function add_mxu () {
$basedir/bin/mysql -uroot -p$password<<EOF
GRANT ALTER, CREATE, INSERT, SELECT, DELETE, UPDATE, DROP, INDEX ON \`mxu_%\`.* TO 'mxu'@'%' identified by "$mxu_passwd";
FLUSH PRIVILEGES;
EOF
}

if [ ! -d /m2odata/server/mysql ];then
    config
    install
    init_db  # 数据库初始化的时候要读取my.cnf里面的参数
    self_boot
    /etc/init.d/mysqld start
    security
    add_mxu
    echo -e "MYSQL安装完成！\n"
else
    echo -e "MYSQL已安装！\n"
    /etc/init.d/mysqld start
fi

add_iptables
