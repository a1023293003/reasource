#!/bin/bash
# 文件描述:linux个性化设置
# 作者:&随心;

# ============================================
# 修改Bash提示字符串
# ============================================
function modified_Bash_Prompt() {
	filePath="/root/.bashrc";
	comment="# 修改Bash提示字符串";
	# 删除.bashrc文件中PS1提示字符串配置,-i表示直接修改源文件
	sed -i '/^PS1=/d' $filePath;
	sed -i "/^$comment$/d" $filePath;
	echo -e "\\n$comment\\nPS1=\"\e[1;36m(●'◡'●):\e[1;32m \w \e[0m>\"">>$filePath;
	source $filePath;
}

modified_Bash_Prompt;
