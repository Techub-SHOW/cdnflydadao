#!/bin/bash

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

# 删除同步时间
echo "删除同步时间任务"
if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
    sed -i '/update.cdnfly.cn/d' /var/spool/cron/crontabs/root
    service cron restart

elif check_sys sysRelease centos; then
    sed -i '/update.cdnfly.cn/d' /var/spool/cron/root
    service crond restart
fi

# 删除es
service elasticsearch stop
es_dir=`cat /etc/elasticsearch/elasticsearch.yml | grep path.data | awk '{print $2}' | tr -s '/'`
if [[ "$es_dir" == "" || "$es_dir" == "/"  ]];then
    echo "无法获取es目录"
else 
   rm -rf ${es_dir}/*
fi

if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
    apt -y remove elasticsearch
    apt -y purge elasticsearch
    rm -rf /etc/elasticsearch/

elif check_sys sysRelease centos; then
    yum remove elasticsearch
    rm -rf /etc/elasticsearch/
fi

# pip模块
rm -rf /opt/venv/

# cdnfly
rm -rf /opt/cdnfly

supervisorctl -c /opt//cdnfly/master/conf/supervisord.conf stop all
sed -i '/cdnfly/d' /etc/rc.local || true
sed -i '/cdnfly/d' /etc/rc.d/rc.local || true
(crontab -l | grep -v /opt/cdnfly/master/sh/monitor_task.sh) | crontab -

echo "卸载完成."