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

# 删除geoip
echo "删除geoip"
rm -rf /opt/geoip/

# 删除python模块
echo "删除/opt/venv"
rm -rf /opt/venv/

# 卸载openresty
echo "删除openresty"
ps aux | grep [n]ginx | awk '{print $2}' | xargs kill -9
chattr -R -i /usr/local/openresty/
rm -rf /usr/local/openresty
rm -rf /data/nginx/cache/
rm -f /usr/local/lib/libaiwendb.*

# 卸载redis
echo "删除redis"
ps aux | grep [r]edis | awk '{print $2}' | xargs kill -9
rm -rf /usr/local/redis/

# 卸载filebeat
echo "删除filebeat"
supervisorctl -c /opt/cdnfly/agent/conf/supervisord.conf stop filebeat
rm -rf /etc/filebeat/
rpm -e filebeat-7.10.0-1.x86_64 || true


# 卸载syslog
echo "删除syslog配置"
rm -f /etc/rsyslog.d/cdnfly.conf
rm -rf /var/log/cdnfly/
service rsyslog restart || true

# 卸载cdnfly
echo "删除cdnfly"
supervisorctl -c /opt/cdnfly/agent/conf/supervisord.conf stop all
cd /opt
rm -rf cdnfly-agent-*
rm -rf cdnfly_data/
rm -rf .config-bak
rm -rf cdnfly global_black_ip_list global_white_ip_list last_scan_cache last_scan_cache2 redis_pipe
ps aux | grep '[/]opt/cdnfly/agent/conf/supervisord.conf' | awk '{print $2}' | xargs kill -9
sed -i '/\/usr\/local\/openresty\/nginx\/sbin\/nginx/d' /etc/rc.local /etc/rc.d/rc.local
sed -i '/\/opt\/cdnfly\/agent\/conf\/supervisord.conf/d' /etc/rc.local /etc/rc.d/rc.local

iptables -F
ipset destroy cdnfly
ipset destroy cdnfly_black
ipset destroy cdnfly_white

echo "卸载完成."
