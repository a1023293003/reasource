#!/bin/bash
# 文件描述:CentOS7下Python2升级到Python3不严谨版本
# 作者:&随心;

# 环境安装
yum install -y wget
yum install -y gcc
# 下载Python3
wget https://www.python.org/ftp/python/3.8.0/Python-3.8.0a1.tgz
# 解压编译安装Python3
tar -zxvf Python-3.8.0a1.tgz
cd Python-3.8.0a1
./configure
make
make install
# 备份Python2软连接
mv /usr/bin/python /usr/bin/python.bak
# 修改默认使用Python3
ln -s /usr/local/bin/python3 /usr/bin/python
# yum和pip默认使用Python2
files=(
    "/usr/bin/yum"
    "/usr/bin/pip"
    "/usr/libexec/urlgrabber-ext-down");
for file in ${files[@]};
do
    echo ===================================$file
    sed -ir 's/\(\/usr\/bin\/python\).*/\12/g' $file
done
# 删除Python3下载和解压文件
cd ~
rm -rf Python-3.8.0a1*


