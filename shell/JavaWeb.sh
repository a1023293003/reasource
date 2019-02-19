#!/bin/bash
# 文件描述:一键安装JDK、Tomcat脚本
# 作者:&随心;

# DEBUG标记参数
_DEBUG=on;
# Tomcat安装路径
tomcat_path=/usr/tomcat;
# Tomcat下载路径
tomcat_url=http://mirrors.advancedhosters.com/apache/tomcat/tomcat-9/v9.0.10/bin/apache-tomcat-9.0.10.tar.gz;
# MySQL root用户密码
root_password=root;
# MySQL RPM下载地址
mysql_url=https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm;

# ============================================
# DEBUG
# ============================================
function DEBUG() {
	[ "$_DEBUG" == "on" ] && $@ || : ;
}

# ============================================
# 创建目录
# ============================================
function make_dir() {
	path=$1;
	rm -rf $path &> /dev/null;
	mkdir $path;
}

# ============================================
# 更新配置
# ============================================
function update_config() {
	config_file=$1;
	pattern=$2;
	new_config=$3;
	sed -i "s/$pattern/$new_config/g" $config_file;
}

# ============================================
# 安装最新版本的JDK
# ============================================
function install_latest_JDK() {
	# 删除所有已安装的java
	rpm -qa | grep java | xargs rpm -e --nodeps;

	# 获取最新版本的OpenJDK全称
	latest_JDK=$(yum search java | grep jdk-devel.x86_64 | tail -1 - | sed 's/ : [a-zA-Z ]*//g');

	# 安装JDK
	yum -y install $latest_JDK;

	# 获取yum安装jdk的路径
	jdk_path=$(which java); # /usr/bin/java
	jdk_path=$(ls -lrt $jdk_path | sed 's/.* -> //g'); #  /usr/bin/java -> /etc/alternatives/java
	#  /etc/alternatives/java -> /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.161-0.b14.el7_4.x86_64/jre/bin/java
	jdk_path=$(ls -lrt $jdk_path | sed 's/.* -> //g' | sed -e 's/\(\/usr\/lib\/jvm\/[^\/]*\)\/.*/\1/g');

	# 配置环境变量
	export JAVA_HOME=$jdk_path;
	export CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar;
	export PATH=$PATH:$JAVA_HOME/bin;
	source /etc/profile;
	echo -e "JDK安装[\e[1;32m成功\e[0m]"
}

# ============================================
# 安装Tomcat
# ============================================
function install_Tomcat() {
	# 关闭服务
	systemctl stop tomcat &> /dev/null;
	# 创建并进入指定目录
	if [[ "$tomcat_path" == "" ]];
		then path=/usr/tomcat;
	else
		path=$tomcat_path;
	fi
	make_dir $path;
	cd $path;

	# 下载tomcat
	yum -y install wget &> /dev/null;
	if [ -n $tomcat_url ];
		then
		wget $tomcat_url;
	else
		echo Tomcat下载[\e[1;31m失败\e[0m]
		return 0;
	fi;

	# 解压更名删除安装包
	file_name=$(echo $tomcat_url | sed 's/.*bin\///g');
	dir_name=$(echo $file_name | sed 's/.tar.gz//g');
	new_dir_name=$(echo $dir_name | sed 's/apache-tomcat-/tomcat/g' | sed 's/\(tomcat[789]\).*/\1/g');
	tar -zxvf $file_name;        DEBUG echo -e "tomcat解压[\e[1;32m成功\e[0m]";
	mv $dir_name $new_dir_name;  DEBUG echo -e "tomcat改名[\e[1;32m成功\e[0m]";
	rm -rf $file_name;           DEBUG echo -e "删除tomcat压缩包[\e[1;32m成功\e[0m]";

	# 修改默认端口
	sed -i 's/8080/80/g' $path/$new_dir_name/conf/server.xml; DEBUG echo -e "修改server.xml[\e[1;32m成功\e[0m]";

	# 设置开机启动
	config_file=/usr/lib/systemd/system/tomcat.service;
	rm -rf $config_file &> /dev/null;
	touch $config_file;
	echo -e "[Unit]\\nDescription=Tomcat\\nAfter=syslog.target network.target remote-fs.target nss-lookup.target\\n\\n[Service]\\nType=oneshot\\nExecStart=$path/$new_dir_name/bin/startup.sh\\nExecStop=$path/$new_dir_name/bin/shutdown.sh\\nExecReload=/bin/kill -s HUP \$MAINPID\\nRemainAfterExit=yes\\n\\n[Install]\\nWantedBy=multi-user.target" 1>$config_file;
	DEBUG echo -e "设置tomcat开机启动[\e[1;32m成功\e[0m]";

	# 开放防火墙端口
	systemctl restart firewalld.service;
	firewall-cmd --zone=public --add-port=80/tcp --permanent &> /dev/null;
	firewall-cmd --reload &> /dev/null;
	DEBUG echo -e "开放80端口[\e[1;32m成功\e[0m]";
	echo -e "Tomcat安装[\e[1;32m成功\e[0m]";
}

# ============================================
# 安装MySQL
# ============================================
function install_MySQL() {
	# 关闭服务
	systemctl stop mysqld;
	# 删除所有已安装的MySQL
	log_file=/var/log/mysqld.log;
	config_file=/etc/my.cnf;
	rpm -qa | grep mysql | xargs rpm -e --nodeps;
	rm -rf $config_file;
	rm -rf $config_file.rpmsave;
	rm -rf $log_file;
	find / -name mysql | xargs rm -rf;
	sleep 2;
	echo -e "卸载完毕已安装MySQL[\e[1;32m成功\e[0m]";

	# 安装软件源
	if [[ "$mysql_url" == "" ]];
		then
		url=https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm;
	else
		url=$mysql_url;
	fi
	rpm_file_name=$(echo $url | sed 's/https:\/\/dev.mysql.com\/get\///g');
	echo rmp_file=$rmp_file;
	wget $url;
	yum -y localinstall $rpm_file_name;
	rm -rf $rpm_file_name;

	# 安装MySQL
	yum -y install mysql-community-server;
	yum clean all;
	systemctl start mysqld;

	# 修改配置文件中datadir路径
	# sed -i 's/^datadir=.*$/datadir=\/opt\/data/g' $config_file;

	# 设置默认关闭密码校验策略
	sed -i '/^validate_password=/d' $config_file;
	echo -e "validate_password=off" >> $config_file;
	sleep 2;
	systemctl restart mysqld;

	# 设置开机启动,并更新设置
	systemctl enable mysqld;
	systemctl daemon-reload;

	# 设置root用户密码
	if [[ "$root_password" == "" ]];
		then root_password=root;
	fi
	password=$(grep 'temporary password' $log_file | sed 's/.* root@localhost: //g');
	mysql -u root -p$password -e "alter user 'root'@'localhost' identified by '$root_password';" -b --connect-expired-password;

	# 开启密码校验
	sed -i '/^validate_password=/d' $config_file;
	systemctl restart mysqld;
	echo -e "MySQL安装[\e[1;32m成功\e[0m]"
}

# ============================================
# 判断输入参数$@中是否包含指定字符串
# ============================================
function contains() {
	target=$1;
	index=0;
	for arg in $@;
	do
		if [ $index -gt 0 ];
			then
			# 参数转换成大写再进行比较
			arg=$(echo $arg | tr [a-z] [A-Z]);
			target=$(echo $target | tr [a-z] [A-Z]);
			if [[ "$arg" == "$target" ]];
			then
				return 1;
			fi;
		fi;
		let index++;
	done;
	return 0;
}



if [[ "$@" == "" ]];
	then
	echo 没有传入参数,默认安装所有软件.
	install_latest_JDK;
	install_Tomcat;
	install_MySQL;
else
	contains JDK $@;
	[ $? -eq 1 ] && echo 安装JDK && install_latest_JDK;
	contains Tomcat $@;
	[ $? -eq 1 ] && echo 安装Tomcat && install_Tomcat;
	contains MySQL $@;
	[ $? -eq 1 ] && echo 安装MySQL && install_MySQL;
fi
