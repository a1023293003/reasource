#!/bin/bash
# 文件描述:transmission-daemon安装脚本
# 作者:&随心;

# 常量定义
config_path="/etc/transmission-daemon";
config_file="$config_path/settings.json";

# 配置定义
declare -A config
config["peer-port"]=51432;
config["rpc-port"]=9527;
config["rpc-enabled"]=true;
config["rpc-whitelist-enabled"]=false;
config["rpc-authentication-required"]=true;

# 变量定义
rpc_username="";
rpc_password="";
download_dir="/td/downloads";

# 变量名和变量输入提示信息数组。
var_name_array=(
    "rpc_username" 
    "rpc_password" 
    "download_dir");
var_msg_array=(
    "请输入管理员账号(必填)" 
    "请输入管理员密码(必填)" 
    "请输入文件下载目录(默认为[/td/downloads])");

# ============================================
# 参数录入
# ============================================
function input() {
    local name_array=($1);
    local msg_array=($2);
    for i in "${!name_array[@]}";
    do
        name=${name_array[$i]};
        message=${msg_array[$i]};
        value=`eval echo '$'"$name"`;
        
        is_first=true;
        origin_value=$value;
        # is_first和while实现do-while的效果
        while [ $is_first = true ] || [ "$value" = "" ]
        do
            read -p "$message : " value;
            is_first=false;
            if [ "$origin_value" != "" ] && [ "$value" = "" ]; then
                value=$origin_value;
                break;
            fi
        done;
        
        eval $name=$value;
    done
}

# ============================================
# 初始化系统环境
# ============================================
function init() {
    yum install -y wget;
    yum remove -y transmission transmission-daemon;
    td_config_file=$1;
    rm -rf $td_config_file;
    td_download_dir=$2;
    mkdir -p $td_download_dir;
}

# ============================================
# 修改配置文件属性
# ============================================
function modifyConfigField() {
    local key=$1;
    local value=$2;
    local path=$3;
    # 转移特殊字符'/'
    value=`echo $value | sed 's#\/#\\\/#g'`;
    if [ ! -n "`echo $value | sed -r 's/^[\+-]*[0-9]+(\.[0-9]+)*$//g'`" ] || 
       [ ! -n "`echo $value | sed -r 's/^[Tt][Rr][Uu][Ee]$//g'`" ] || 
       [ ! -n "`echo $value | sed -r 's/^[Ff][Aa][Ll][Ss][Ee]$//g'`" ]; then
        echo "\"$key\":$value";
        sed -i -r "s/^( *\"$key\" *: *).+$/\1$value,/g" $path;
    else
        echo "\"$key\":\"$value\"";
        sed -i -r "s/^( *\"$key\" *: *).+$/\1\"$value\",/g" $path;
    fi
}

# ============================================
# 修改配置文件
# ============================================
function modifyConfig() {
    while [ ! -f "$config_file" ]; do sleep 1s; done;
    # 修改默认配置文件
    rm -rf $config_path/$config_file;
    wget -P $config_path -O "$config_file" https://raw.githubusercontent.com/a1023293003/reasource/master/config/transmission-daemon-settings.json;
    
    for key in ${!config[@]}
    do
        modifyConfigField $key ${config[$key]} $config_file;
    done
    modifyConfigField "rpc-username" $rpc_username $config_file;
    modifyConfigField "rpc-password" $rpc_password $config_file;
    modifyConfigField "download-dir" $download_dir $config_file;
}

# ============================================
# 修改服务脚本文件
# ============================================
function modifyService() {
    local path=`echo $1 | sed 's#\/#\\\/#g'`;
    sed -i -r "s/^ExecStart=.+$/ExecStart=\/usr\/bin\/transmission-daemon -g $path -f --log-error/g" /usr/lib/systemd/system/transmission-daemon.service;
    sed -i -r "s/^ExecReload=.+$/ExecReload=\/usr\/bin\/killall transmission-daemon/g" /usr/lib/systemd/system/transmission-daemon.service;
    systemctl daemon-reload;
}

# ============================================
# 修改文件/文件夹操作权限
# ============================================
function chmodFiles() {
    chmod 777 $1;
    chmod 777 $1/*;
    chmod 777 $2;
}

# ============================================
# 修改防火墙配置
# ============================================
function modifyFirewall() {
    systemctl restart firewalld;
    firewall-cmd --zone=public --permanent --add-port=${config["rpc-port"]}/tcp;
    firewall-cmd --zone=public --permanent --add-port=${config["peer-port"]}/tcp;
    firewall-cmd --zone=public --permanent --add-port=${config["peer-port"]}/udp;
    systemctl restart firewalld;
    firewall-cmd --list-all;
}


input "${var_name_array[*]}" "${var_msg_array[*]}";
    
echo "管理员账号   : [$rpc_username]";
echo "管理员密码   : [$rpc_password]";
echo "文件下载目录 : [$download_dir]";

init $config_file $download_dir;

yum install -y transmission transmission-daemon;
transmission-daemon -g $config_path;
killall transmission-daemon;

modifyConfig;
modifyService $config_path;
chmodFiles $config_path $download_dir;
modifyFirewall;

systemctl start transmission-daemon;
systemctl status transmission-daemon;