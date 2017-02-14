#!/bin/bash

# 定义颜色环境变量
export RED="\\033[31m"
export GREEN="\\033[32m"
export YELLOW="\\033[33m"
export BLACK="\\033[0m"

# 添加yum池
clear
echo -e "${GREEN}添加yum池${BLACK}"
./env/hoge-repo.sh
[ $? = 1 ] && exit 1

clear
while true
do

printf "\n${GREEN}
\t\t============================================== MXU INSTALL ==============================================
\t\t||                                                                                                      ||
\t\t||                                   * * * * 1、系统环境初始化 * *                                      ||
\t\t||                                   * * * * 2、WEB环境部署* * * *                                      ||
\t\t||                                   * * * * 3、MYSQL服务* * * * *                                      ||
\t\t||                                   * * * * 4、直播服务 * * * * *                                      ||
\t\t||                                   * * * * 5、点播服务 * * * * *                                      ||
\t\t||                                   * * * * 6、转码服务 * * * * *                                      ||
\t\t||                                   * * * * 7、收录服务 * * * * *                                      ||
\t\t||                                   * * * * 8、退出安装 * * * * *                                      ||
\t\t||                                                                                                      ||
\t\t=========================================================================================================
${BLACK}\n"

    echo -ne "\t\t"
    read -p "请输入你要选择安装的服务[1-8]: " choice

    case $choice in

        1)
            echo -e "\t\t系统环境初始化\n"
            ./env/env.sh
            ;;
        2)
            echo -e "\t\tWEB环境部署\n"
            ./web/web.sh
            [ $? = 1 ] && exit 1
            ;;
        3)
            echo -e "\t\t安装MYSQL服务\n"
            ./mysql/mysql_installation.sh
            [ $? = 1 ] && exit 1
            ;;
        4)
            echo -e "\t\t安装直播服务\n"
            ./live/pyrtmp.sh
            [ $? = 1 ] && exit 1
            ;;
        5)
            echo -e "\t\t安装点播服务\n"
            ./vod/vod.sh
            [ $? = 1 ] && exit 1
            ;;
        6)
            echo -e "\t\t安装转码服务\n"
            ./transcode/transcode.sh
            [ $? = 1 ] && exit 1
            ;;
        7)
            echo -e "\t\t安装收录服务\n"
            ./record/record.sh
            [ $? = 1 ] && exit 1
            ;;
        8)
            echo -e "\t\t退出安装\n"
            exit
            ;;
        *)
            echo -e "\t\t请输入正确的choice\n"
            ;;
    esac
done
