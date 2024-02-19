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
supervisorctl -c /opt/cdnfly/master/conf/supervisord.conf stop cc_auto_switch node_monitor site_res_count site_sync task


eval `grep MYSQL_PASS /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_IP /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_PORT /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_DB /opt/cdnfly/master/conf/config.py`
eval `grep MYSQL_USER /opt/cdnfly/master/conf/config.py`

echo -e "\033[0;32m开始备份MySQL...\033[0m"
mysqldump -e --single-transaction --no-tablespaces --default-character-set=utf8 --skip-add-locks -R -f --max_allowed_packet=16777216 --net_buffer_length=16384  -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT $MYSQL_DB --ignore-table=$MYSQL_DB.node_monitor_log > /root/cdn.sql
echo -e "\033[0;32m第一部分MySQL备份完成。\033[0m"
mysqldump -d -e --single-transaction --no-tablespaces --default-character-set=utf8 --skip-add-locks -R -f --max_allowed_packet=16777216 --net_buffer_length=16384 -h$MYSQL_IP -u$MYSQL_USER -p$MYSQL_PASS -P$MYSQL_PORT $MYSQL_DB node_monitor_log >> /root/cdn.sql
echo -e "\033[0;32m第二部分MySQL备份完成。\033[0m"
rm -f /root/cdn.sql.gz
gzip /root/cdn.sql
echo -e "\033[0;32mMySQL备份成功。\033[0m"

# 恢复进程
supervisorctl -c /opt/cdnfly/master/conf/supervisord.conf start cc_auto_switch node_monitor site_res_count site_sync task
