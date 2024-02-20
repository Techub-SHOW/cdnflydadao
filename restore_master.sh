#!/bin/bash -x

set -o errexit

#判断系统版本
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''
    local packageSupport=''

    if [[ "$release" == "" ]] || [[ "$systemPackage" == "" ]] || [[ "$packageSupport" == "" ]];then

        if [[ -f /etc/redhat-release ]];then
            release="centos"
            systemPackage="yum"
            packageSupport=true

        elif cat /etc/issue | grep -q -E -i "debian";then
            release="debian"
            systemPackage="apt"
            packageSupport=true

        elif cat /etc/issue | grep -q -E -i "ubuntu";then
            release="ubuntu"
            systemPackage="apt"
            packageSupport=true

        elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat";then
            release="centos"
            systemPackage="yum"
            packageSupport=true

        elif cat /proc/version | grep -q -E -i "debian";then
            release="debian"
            systemPackage="apt"
            packageSupport=true

        elif cat /proc/version | grep -q -E -i "ubuntu";then
            release="ubuntu"
            systemPackage="apt"
            packageSupport=true

        elif cat /proc/version | grep -q -E -i "centos|red hat|redhat";then
            release="centos"
            systemPackage="yum"
            packageSupport=true

        else
            release="other"
            systemPackage="other"
            packageSupport=false
        fi
    fi

    echo -e "release=$release\nsystemPackage=$systemPackage\npackageSupport=$packageSupport\n" > /tmp/ezhttp_sys_check_result

    if [[ $checkType == "sysRelease" ]]; then
        if [ "$value" == "$release" ];then
            return 0
        else
            return 1
        fi

    elif [[ $checkType == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ];then
            return 0
        else
            return 1
        fi

    elif [[ $checkType == "packageSupport" ]]; then
        if $packageSupport;then
            return 0
        else
            return 1
        fi
    fi
}


# 停止主控程序
supervisorctl -c /opt/cdnfly/master/conf/supervisord.conf stop all

# 恢复mysql
eval `grep MYSQL_PASS /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_IP /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_PORT /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_DB /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_USER /opt/cdnfly/master/conf/config.py`

mysql -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT -e "drop database $MYSQL_DB;create database $MYSQL_DB;"
gunzip < /root/cdn.sql.gz |  mysql -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT $MYSQL_DB

# 关闭维护模式
mysql -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT $MYSQL_DB -e "update config set value='{\"enable\":0,\"msg\":\"维护中,请稍候重试\"}' where name='maintain' " 

# 启动主控程序
supervisorctl -c /opt/cdnfly/master/conf/supervisord.conf start all


