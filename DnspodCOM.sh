#!/bin/bash
BuildTime=20200624
# 专家模式开关
# 注意： 只有当你了解整个DnspodDDNS工作流程，并且有一定的动手能力，希望对DnspodDDNS脚本的更多参数进行
#       深度定制时，你可以打开这个开关，会提供更多可以设置的选项，但如果你不懂、超级小白，请不要
#       打开这个开关！因打开专家模式后配置失误发生的问题，作者不负任何责任！
#       如需打开专家模式，请将脚本文件中的 Switch_Dnspod_ExpertMode 变量值设置为1，即可打开
#       专家模式，如需关闭，请将此值设置为0！
Switch_Dnspod_ExpertMode=0

# ===================================================================================
#
# 下面的代码均为程序的核心代码，不要改动任何地方的代码，直接运行脚本即可使用！
#
# ===================================================================================

# Shell环境初始化
# 字体颜色定义
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"
# 消息提示定义
Msg_Info="${Font_Blue}[Info] ${Font_Suffix}"
Msg_Warning="${Font_Yellow}[Warning] ${Font_Suffix}"
Msg_Error="${Font_Red}[Error] ${Font_Suffix}"
Msg_Success="${Font_Green}[Success] ${Font_Suffix}"
Msg_Fail="${Font_Red}[Failed] ${Font_Suffix}"

# Shell脚本信息显示
echo -e "${Font_Green}
#=========================================================
# DnspodDDNS 工具 (Dnspod国际版云解析修改工具)
#
# Build:    $BuildTime
# 支持平台: CentOS/Debian/Ubuntu
# 作者:     Small_5 (部分代码来源于iLemonrain的AliDDNS)
#=========================================================

${Font_suffix}"

# 检查Root权限，并配置开关
function_Check_Root(){
	if [ "`id -u`" != 0 ];then
		Switch_env_is_root=0
		Config_configdir="$(cd ~;echo $PWD)/OneKeyDnspod"
	else
		Switch_env_is_root=1
		Config_configdir="/etc/OneKeyDnspod"
	fi
}

function_Check_Enviroment(){
	command -v curl >/dev/null 2>&1 && Switch_env_curl_exist=1 || Switch_env_curl_exist=0
	command -v nslookup >/dev/null 2>&1 && Switch_env_nslookup_exist=1 || Switch_env_nslookup_exist=0
	command -v jq >/dev/null 2>&1 && Switch_env_jq_exist=1 || Switch_env_jq_exist=0
	if [ -f "/etc/redhat-release" ];then
		Switch_env_system_release=centos
	elif [ -f "/etc/lsb-release" ];then
		Switch_env_system_release=ubuntu
	elif [ -f "/etc/debian_version" ];then
		Switch_env_system_release=debian
	fi
}

function_Install_Enviroment(){
	if [ "$Switch_env_curl_exist" = 0 ] || [ "$Switch_env_nslookup_exist" = 0 ] || [ "$Switch_env_jq_exist" = 0 ];then
		echo -e "${Msg_Warning}未检查到必需组件或者组件不完整，正在尝试安装……"
		if [ "$Switch_env_is_root" = 1 ];then
			if [ "$Switch_env_system_release" = centos ];then
				echo -e "${Msg_Info}检测到系统分支：CentOS"
				echo -e "${Msg_Info}正在安装必需组件……"
				yum install curl bind-utils jq -y
			elif [ "$Switch_env_system_release" = ubuntu ];then
				echo -e "${Msg_Info}检测到系统分支：Ubuntu"
				echo -e "${Msg_Info}正在安装必需组件……"
				apt-get install curl dnsutils jq -y
			elif [ "$Switch_env_system_release" = debian ];then
				echo -e "${Msg_Info}检测到系统分支：Debian"
				echo -e "${Msg_Info}正在安装必需组件……"
				apt-get install curl dnsutils jq -y
			else
				echo -e "${Msg_Warning}系统分支未知，取消环境安装，建议手动安装环境！"
				exit 1
			fi
		elif command -v sudo >/dev/null 2>&1;then
			echo -e "${Msg_Warning}检测到当前脚本并非以root权限启动，正在尝试通过sudo命令安装……"
			if [ "$Switch_env_system_release" = centos ];then
				echo -e "${Msg_Info}检测到系统分支：CentOS"
				echo -e "${Msg_Info}正在安装必需组件 (使用sudo)……"
				sudo yum install curl bind-utils jq -y
			elif [ "$Switch_env_system_release" = ubuntu ];then
				echo -e "${Msg_Info}检测到系统分支：Ubuntu"
				echo -e "${Msg_Info}正在安装必需组件 (使用sudo)……"
				sudo apt-get install curl dnsutils jq -y
			elif [ "$Switch_env_system_release" = debian ];then
				echo -e "${Msg_Info}检测到系统分支：Debian"
				echo -e "${Msg_Info}正在安装必需组件 (使用sudo)……"
				sudo apt-get install curl dnsutils jq -y
			else
				echo -e "${Msg_Warning}系统分支未知，取消环境安装，建议手动安装环境！"
				exit 1
			fi
		else
			echo -e "${Msg_Error}系统缺少必需环境，并且无法自动安装，建议手动安装！"
			exit 1
		fi
		if ! command -v curl >/dev/null 2>&1;then
			echo -e "${Msg_Error}curl组件安装失败！会影响到程序运行！建议手动安装！"
			exit 1
		fi
		if ! command -v nslookup >/dev/null 2>&1;then
			echo -e "${Msg_Error}nslookup组件安装失败！会影响到程序运行！建议手动安装！"
			exit 1
		fi
		if ! command -v jq >/dev/null 2>&1;then
			echo -e "${Msg_Error}jq组件安装失败！会影响到程序运行！建议手动安装！"
			exit 1
		fi
	fi
}

# 判断是否有已存在的配置文件 (是否已经配置过环境)
function_Dnspod_CheckConfig(){
	if [ -f $Config_configdir/config-com.cfg ];then
		echo -e "${Msg_Info}检测到存在的配置，自动读取现有配置\n       如果你不需要，请通过菜单中的清理环境选项进行清除"
		# 读取配置文件
		__Domain=`sed '/^Domain=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		__ID=`sed '/^ID=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		__KEY=`sed '/^KEY=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		__TYPE=`sed '/^TYPE=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		__Local_IP_BIN=`sed '/^Local_IP=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		__DNS=`sed '/^DNS=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		retry_count=`sed '/^retry_count=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		retry_seconds=`sed '/^retry_seconds=/!d;s/.*=//' $Config_configdir/config-com.cfg | sed 's/\"//g'`
		if [ -z "$__Domain" ] || [ -z "$__ID" ] || [ -z "$__KEY" ] || [ -z "$__TYPE" ] || [ -z "$__Local_IP_BIN" ] || [ -z "$__DNS" ] || [ -z "$retry_count" ] || [ -z "$retry_seconds" ];then
			echo -e "${Msg_Error}配置文件有误，请检查配置文件，或者建议清理环境后重新配置 !"
			exit 1
		fi
		# 从 $__Domain 分离主机和域名
		[ "${__Domain:0:2}" = "@." ] && __Domain="${__Domain/./}" # 主域名处理
		[ "$__Domain" = "${__Domain/@/}" ] && __Domain="${__Domain/./@}" # 未找到分隔符，兼容常用域名格式
		__HOST="${__Domain%%@*}"
		__DOMAIN="${__Domain#*@}"
		[ -z "$__HOST" -o "$__HOST" = "$__DOMAIN" ] && __HOST=@
		Switch_Dnspod_Config_Exist=1
	else
		Switch_Dnspod_Config_Exist=0
	fi
}

function_Dnspod_SetConfig(){
	# Domain
	echo -e "\n${Msg_Info}请输入域名 (比如 www.example.com)，如果需要更新主域名，请输入@，例如@.example.com"
	read -p "(此项必须填写，查看帮助请输入h):" __Domain
	while [ -z "$__Domain" -o "$__Domain" = h ];do
		[ "$__Domain" = h ] && function_document_Dnspod_Domain
		[ -z "$__Domain" ] && echo -e "${Msg_Error}此项不可为空，请重新填写"
		echo -e "${Msg_Info}请输入域名 (比如 www.example.com)，如果需要更新主域名，请输入@，例如@.example.com"
		read -p "(此项必须填写，查看帮助请输入h):" __Domain
	done
	# ID
	echo -e "\n${Msg_Info}请输入Dnspod 账号"
	read -p "(此项必须填写，查看帮助请输入h):" __ID
	while [ -z "$__ID" -o "$__ID" = h ];do
		[ "$__ID" = h ] && function_document_Dnspod_ID
		[ -z "$__ID" ] && echo -e "${Msg_Error}此项不可为空，请重新填写"
		echo -e "${Msg_Info}请输入Dnspod 账号"
		read -p "(此项必须填写，查看帮助请输入h):" __ID
	done
	# KEY
	echo -e "\n${Msg_Info}请输入Dnspod 密码"
	read -p "(此项必须填写，查看帮助请输入h):" __KEY
	while [ -z "$__KEY" -o "$__KEY" = h ];do
		[ "$__KEY" = h ] && function_document_Dnspod_KEY
		[ -z "$__KEY" ] && echo -e "${Msg_Error}此项不可为空，请重新填写"
		echo -e "${Msg_Info}请输入Dnspod 密码"
		read -p "(此项必须填写，查看帮助请输入h):" __KEY
	done
	# TYPE
	echo -e "\n${Msg_Info}请输入域名类型(A/AAAA)："
	read -p "(默认为A，查看帮助请输入h):" __TYPE
	while [ -n "$__TYPE" ] && [ "$__TYPE" != A -a "$__TYPE" != AAAA ];do
		[ "$__TYPE" = h ] && function_document_Dnspod_TYPE
		[ "$__TYPE" != h ] && echo -e "${Msg_Error}填写错误，请重新填写"
		echo -e "${Msg_Info}请输入域名类型(A/AAAA)："
		read -p "(默认为A，查看帮助请输入h):" __TYPE
	done
	[ -z "$__TYPE" ] && echo -e "${Msg_Info}检测到输入空值，设置类型为：A" && __TYPE=A
	# Local_IP
	if [ "$Switch_Dnspod_ExpertMode" = 1 ];then
		echo -e "\n${Msg_Info}请输入获取本机IP使用的命令"
		read -p "(查看帮助请输入h):" __Local_IP_BIN
		while [ "$__Local_IP_BIN" = h ];do
			function_document_Dnspod_LocalIP
			echo -e "${Msg_Info}请输入获取本机IP使用的命令"
			read -p "(查看帮助请输入h):" __Local_IP_BIN
		done
		if [ -z "$__Local_IP_BIN" ];then
			if [ "$__TYPE" = A ];then
				__Local_IP_BIN=A
			else
				__Local_IP_BIN=B
			fi
			echo -e "${Msg_Info}检测到输入空值，设置为默认命令"
		fi
	else
		if [ "$__TYPE" = A ];then
			__Local_IP_BIN=A
		else
			__Local_IP_BIN=B
		fi
	fi
	case "$__Local_IP_BIN" in
		A)
		__Local_IP_BIN="curl -s https://pv.sohu.com/cityjson";;
		B)
		__Local_IP_BIN="curl -s6 https://ipv6-test.com/api/myip.php";;
	esac
	# DNS
	if [ "$Switch_Dnspod_ExpertMode" = 1 ];then
		echo -e "\n${Msg_Info}请输入解析使用的DNS服务器"
		read -p "(查看帮助请输入h):" __DNS
		while [ "$__DNS" = h ];do
			function_document_Dnspod_DNS
			echo -e "${Msg_Info}请输入解析使用的DNS服务器"
			read -p "(查看帮助请输入h):" __DNS
		done
		[ -z "$__DNS" ] && echo -e "${Msg_Info}检测到输入空值，设置默认DNS服务器为：8.8.8.8" && __DNS="8.8.8.8"
	else
		__DNS="8.8.8.8"
	fi
	# 重试次数
	if [ "$Switch_Dnspod_ExpertMode" = 1 ];then
		echo -e "\n${Msg_Info}错误重试次数(0为无限重试，默认为2，不推荐设置为0)"
		read -p "(请输入错误重试次数):" retry_count
		[ -z "$retry_count" ] && echo -e "${Msg_Info}检测到输入空值，设置为2" && retry_count=2
	else
		retry_count=2
	fi
	# 重试间隔
	if [ "$Switch_Dnspod_ExpertMode" = 1 ];then
		echo -e "\n${Msg_Info}错误重试间隔时间(默认5秒)"
		read -p "(请输入错误重试间隔时间):" retry_seconds
		[ -z "$retry_seconds" ] && echo -e "${Msg_Info}检测到输入空值，设置为5" && retry_seconds=5
	else
		retry_seconds=5
	fi
}

function_Dnspod_WriteConfig(){
	# 写入配置文件
	echo -e "\n${Msg_Info}正在写入配置文件……"
	mkdir -p $Config_configdir
	cat>$Config_configdir/config-com.cfg<<EOF
Domain="$__Domain"
ID="$__ID"
KEY="$__KEY"
TYPE="$__TYPE"
Local_IP="$__Local_IP_BIN"
DNS="$__DNS"
retry_count="$retry_count"
retry_seconds="$retry_seconds"
EOF
}

function_ServerChan_Configure(){
	echo -e "\n${Msg_Info}请输入ServerChan SCKEY："
	read -p "(此项必须填写):" ServerChan_SCKEY
	while [ -z "${ServerChan_SCKEY}" ];do
		echo -e "${Msg_Error}此项不可为空，请重新填写"
		echo -e "${Msg_Info}请输入ServerChan SCKEY："
		read -p "(此项必须填写):" ServerChan_SCKEY
	done
	echo -e "\n${Msg_Info}请输入服务器名称：请使用中文/英文，不要使用除了英文下划线以外任何符号"
	read -p "(此项必须填写，便于识别):" ServerChan_ServerFriendlyName
	while [ -z "${ServerChan_ServerFriendlyName}" ];do
		echo -e "${Msg_Error}此项不可为空，请重新填写"
		echo -e "${Msg_Info}请输入服务器名称：请使用中文/英文，不要使用除了英文下划线以外任何符号"
		read -p "(此项必须填写，便于识别):" ServerChan_ServerFriendlyName
	done
}

function_ServerChan_WriteConfig(){
	# 写入配置文件
	echo -e "\n${Msg_Info}正在写入配置文件……"
	mkdir -p $Config_configdir
	cat>$Config_configdir/config-ServerChan-com.cfg<<EOF
ServerChan_ServerFriendlyName="${ServerChan_ServerFriendlyName}"
ServerChan_SCKEY="${ServerChan_SCKEY}"
EOF
}

# 帮助文档
function_document_Dnspod_Domain(){
	echo -e "${Msg_Info}${Font_Green}Domain 说明
这个参数设置你的DDNS域名，当需要更新主域名IP的时候，使用例如@.example.com${Font_Suffix}"
}

function_document_Dnspod_ID(){
	echo -e "${Msg_Info}${Font_Green}Dnspod 账号 说明
这个参数决定修改DDNS记录所需要用到的Dnspod 账号。
国际版暂时不支持直接使用API ID和API Token。
${Font_Red}注意：请不要泄露你的账号/密码给任何人！
为了账号安全，请不要随意分享账号/密码(包括请求帮助时候的截图)！${Font_Suffix}"
}

function_document_Dnspod_KEY(){
	echo -e "${Msg_Info}${Font_Green}Dnspod 密码 说明
这个参数决定修改DDNS记录所需要用到的Dnspod 密码。
国际版暂时不支持直接使用API ID和API Token。
${Font_Red}注意：请不要泄露你的账号/密码给任何人！
为了账号安全，请不要随意分享账号/密码(包括请求帮助时候的截图)！${Font_Suffix}"
}

function_document_Dnspod_TYPE(){
	echo -e "${Msg_Info}${Font_Green}TYPE 说明
这个参数决定你要的域名使用A记录还是AAAA记录
A记录为IPv4,AAAA记录为IPv6${Font_Suffix}"
}

function_document_Dnspod_LocalIP(){
	echo -e "${Msg_Info}${Font_Green}LocalIP 说明
这个参数决定如何获取到本机的IP地址。
出于稳定性考虑，当使用A记录时默认使用curl -s https://pv.sohu.com/cityjson作为获取IP的方式，
当使用AAAA记录时默认使用curl -s6 https://ipv6-test.com/api/myip.php作为获取IP的方式，
你也可以指定自己喜欢的获取IP方式。输入格式为需要执行的命令。
请不要在命令中带双引号！解析配置文件时候会过滤掉！${Font_Suffix}"
}

function_document_Dnspod_DNS(){
	echo -e "${Msg_Info}${Font_Green}DNS 说明
这个参数决定如何获取到DDNS域名当前的解析记录。
会使用nslookup命令查询，此参数控制使用哪个DNS服务器进行解析。
默认使用8.8.8.8进行查询${Font_Suffix}"
}

# 获取本机IP
function_Dnspod_GetLocalIP(){
	echo -e "${Msg_Info}正在获取本机IP……"
	if [ -z "$__Local_IP_BIN" ];then
		echo -e "${Msg_Error}本机IP参数为空或无效！"
		echo -e "${Msg_Fail}程序运行出现致命错误，正在退出……"
		exit 1
	fi
	local __CNT=0
	while ! __Local_IP=`$__Local_IP_BIN`;do
		__ERR=$?
		echo -e "${Msg_Error}未能获取本机IP！cURL 错误代码: [$__ERR]"
		__CNT=$(( $__CNT + 1 ))
		[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && echo -e "${Msg_Warning}第$retry_count次重新获取IP失败，程序退出……" && exit 1
		echo -e "${Msg_Warning}获取IP失败 - 在$retry_seconds秒后进行第$__CNT次重试"
		sleep $retry_seconds
	done
	if [ "$__TYPE" = A ];then
		__Local_IP=`echo $__Local_IP | grep -m 1 -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"`
	else
		__Local_IP=`echo $__Local_IP | grep -m 1 -o "\(\([0-9A-Fa-f]\{1,4\}:\)\{1,\}\)\(\([0-9A-Fa-f]\{1,4\}\)\{0,1\}\)\(\(:[0-9A-Fa-f]\{1,4\}\)\{1,\}\)"`
	fi
	if [ -z "$__Local_IP" ];then
		echo -e "${Msg_Error}获取本机IP失败！正在退出……"
		exit 1
	fi
	echo -e "${Msg_Info}本机IP：$__Local_IP"
}

function_Dnspod_DomainIP(){
	echo -e "${Msg_Info}正在获取 $([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN 的IP……"
	__DomainIP=`nslookup -query=$__TYPE $([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN $__DNS`
	if [ "$?" = 1 ];then
		local __CNT=0
		while [ -z "$__DomainIP" ];do
			__CNT=$(( $__CNT + 1 ))
			[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && echo -e "${Msg_Warning}第$retry_count次重新获取域名IP失败，程序退出……" && exit 1
			echo -e "${Msg_Warning}获取IP失败 - 在$retry_seconds秒后进行第$__CNT次重试"
			sleep $retry_seconds
			__DomainIP=`nslookup -query=$__TYPE $([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN $__DNS`
		done
	fi
	echo -e "${Msg_Info}域名类型：$__TYPE"
	echo -e "${Msg_Info}nslookup检测结果:"
	# 如果执行成功，分离出结果中的IP地址
	__DomainIP=`echo "$__DomainIP" | grep -v '#' | grep 'Address:' | tail -n1 | awk '{print $NF}'`
	if [ -z "$__DomainIP" ];then
		echo -e "${Msg_Info}解析结果：$([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN -> (结果为空)"
		echo -e "${Msg_Info}$([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN 未检测到任何有效的解析记录，可能是DNS记录不存在或尚未生效"
		return
	fi
	# 进行判断，如果本次获取的新IP和旧IP相同，结束程序运行
	if [ "$__Local_IP" = "$__DomainIP" ];then
		echo -e "${Msg_Info}当前IP ($__Local_IP) 与 $([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN ($__DomainIP) 的IP相同"
		echo -e "${Msg_Success}未发生任何变动，无需进行改动，正在退出……"
		exit 0
	fi
	echo -e "${Msg_Info}当前IP ($__Local_IP) 与 $([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN ($__DomainIP) 的IP不同，需要更新(可能已更新尚未生效)"
}

# 用于Dnspod API的通信函数
dnspod_transfer(){
	local __CNT=0
	case "$1" in
		0)
		__A="$__CMDBASE 'login_email=$__ID&login_password=$__KEY&format=json' $__URLBASE/Auth";;
		1)
		__A="$__CMDBASE '$__POST' $__URLBASE/Record.List";;
		2)
		__A="$__CMDBASE '$__POST1' $__URLBASE/Record.Create";;
		3)
		__A="$__CMDBASE '$__POST1&record_id=$__RECID&ttl=$__TTL' $__URLBASE/Record.Modify";;
	esac

	while ! __TMP=`eval $__A 2>&1`;do
		echo -e "${Msg_Error}cURL 错误信息: [$__TMP]"
		__CNT=$(( $__CNT + 1 ))
		[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && echo -e "${Msg_Warning}第$retry_count次重试失败，程序退出……" && exit 1
		echo -e "${Msg_Warning}传输失败 - 在$retry_seconds秒后进行第$__CNT次重试"
		sleep $retry_seconds
	done
	__ERR=`echo $__TMP | jq -r .status.code`
	[ $__ERR = 1 ] && return 0
	[ $__ERR = 10 ] && [ $1 = 1 ] && return 0
	__TMP=`echo $__TMP | jq -r .status.message`
	echo -e "${Msg_Error}Dnspod错误信息: [$__TMP]"
	[ "$__TMP" = "User is not exists" -o "$__TMP" = "Email address invalid" ] && echo -e "${Msg_Error}无效账号！"
	[ "$__TMP" = "Login fail, please check login info" ] && echo -e "${Msg_Error}无效密码！"
	[ "$__TMP" = "Domain name invalid, please input tld domain" ] && echo -e "${Msg_Error}无效域名！"
	exit 1
}

# 添加解析记录
add_domain(){
	dnspod_transfer 2
	echo -e "${Msg_Success}添加解析记录成功: [$([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN],[IP:$__Local_IP]"
}

# 修改解析记录
update_domain(){
	dnspod_transfer 3
	echo -e "${Msg_Success}修改解析记录成功: [$([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN],[IP:$__Local_IP],[TTL:$__TTL]"
}

# 如果你有动手能力，可以尝试定制ServerChan推送的消息内容
function_ServerChan_SuccessMsgPush(){
	ServerChan_ServerFriendlyName=`sed '/^ServerChan_ServerFriendlyName=/!d;s/.*=//' $Config_configdir/config-ServerChan-com.cfg | sed 's/\"//g'`
	ServerChan_SCKEY=`sed '/^ServerChan_SCKEY=/!d;s/.*=//' $Config_configdir/config-ServerChan-com.cfg | sed 's/\"//g'`
	if [ -n "$ServerChan_ServerFriendlyName" ] && [ -n "$ServerChan_SCKEY" ];then
		echo -e "${Msg_Info}检测到ServerChan配置，正在推送消息到ServerChan平台……"
		ServerChan_Text="服务器IP发生变动_Dnspod(国际版)"
		ServerChan_Content="服务器：${ServerChan_ServerFriendlyName}，新的IP为：$__Local_IP，请注意服务器状态"
		while ! __TMP=`curl -Ss -d "&desp=${ServerChan_Content}" https://sc.ftqq.com/$ServerChan_SCKEY.send?text=$ServerChan_Text 2>&1`;do
			echo -e "${Msg_Error}ServerChan 推送失败 (cURL 错误信息: [$__TMP])"
			__CNT=$(( $__CNT + 1 ))
			[ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && echo -e "${Msg_Warning}第$retry_count次重试失败，程序退出……" && exit 1
			echo -e "${Msg_Warning}传输失败 - 在$retry_seconds秒后进行第$__CNT次重试"
			sleep $retry_seconds
		done
		echo -e "$([ "$(echo $__TMP | jq -r .errno)" = 0 ] && echo ${Msg_Success} || echo ${Msg_Error})ServerChan返回信息:[`echo $__TMP | jq -r .errmsg | sed 's/^\w\|\s\w/\U&/g'`]"
	fi
}

# 获取域名解析记录
describe_domain(){
	__CMDBASE="curl -Ss -d"
	__URLBASE="https://api.dnspod.com"
	ret=0
	dnspod_transfer 0
	__TOKEN=`echo $__TMP | jq -r .user_token`
	__POST="user_token=$__TOKEN&format=json&domain=$__DOMAIN&sub_domain=$__HOST"
	__POST1="$__POST&value=$__Local_IP&record_type=$__TYPE&record_line=default"
	dnspod_transfer 1
	if [ "$__TYPE" = A ];then
		__TMP=`echo $__TMP | jq -r '.records[] | select(.type == "A") | select(.line == "Default")' 2>/dev/null`
	elif [ "$__TYPE" = AAAA ];then
		__TMP=`echo $__TMP | jq -r '.records[] | select(.type == "AAAA") | select(.line == "Default")' 2>/dev/null`
	fi
	echo -e "${Msg_Info}Dnspod API检测结果:"
	if [ -z "$__TMP" ];then
		echo -e "${Msg_Info}解析记录不存在: [$([ "$__HOST" = @ ] || echo $__HOST.)$__DOMAIN]"
		ret=1
	else
		__RECIP=`echo $__TMP | jq -r .value`
		if [ "$__RECIP" != "$__Local_IP" ];then
			__RECID=`echo $__TMP | jq -r .id`
			__TTL=`echo $__TMP | jq -r .ttl`
			echo -e "${Msg_Info}解析记录需要更新: [解析记录IP:$__RECIP] [本地IP:$__Local_IP]"
			ret=2
		fi
	fi
	if [ $ret = 1 ];then
		sleep 3
		add_domain
	elif [ $ret = 2 ];then
		sleep 3
		update_domain
		[ -f $Config_configdir/config-ServerChan-com.cfg ] && function_ServerChan_SuccessMsgPush
	else
		echo -e "${Msg_Success}解析记录不需要更新: [解析记录IP:$__RECIP] [本地IP:$__Local_IP]"
	fi
}

Entrance_Dnspod_Configure_And_Run(){
	function_Check_Root
	function_Check_Enviroment
	function_Install_Enviroment
	function_Dnspod_SetConfig
	function_Dnspod_WriteConfig
	function_Dnspod_CheckConfig
	function_Dnspod_GetLocalIP
	function_Dnspod_DomainIP
	describe_domain
	exit 0
}

Entrance_Dnspod_RunOnly(){
	function_Check_Root
	function_Dnspod_CheckConfig
	[ "$Switch_Dnspod_Config_Exist" = 0 ] && echo -e "${Msg_Error} 未检测到任何有效配置，请先不带参数运行程序以进行配置！" && exit 1
	function_Check_Enviroment
	function_Install_Enviroment
	function_Dnspod_GetLocalIP
	function_Dnspod_DomainIP
	describe_domain
	exit 0
}

Entrance_Dnspod_ConfigureOnly(){
	function_Check_Root
	function_Check_Enviroment
	function_Install_Enviroment
	function_Dnspod_SetConfig
	function_Dnspod_WriteConfig
	echo -e "${Msg_Success}配置文件写入完成"
	exit 0
}

Entrance_ServerChan_Config(){
	function_Check_Root
	function_Check_Enviroment
	function_ServerChan_Configure
	function_ServerChan_WriteConfig
	echo -e "${Msg_Success}配置文件写入完成，重新执行脚本即可激活ServerChan功能"
	exit 0
}

Entrance_Global_CleanEnv(){
	echo -e "${Msg_Info}正在清理环境……"
	rm -f /etc/OneKeyDnspod/config-com.cfg
	rm -f ~/OneKeyDnspod/config-com.cfg
	rm -f /etc/OneKeyDnspod/config-ServerChan-com.cfg
	rm -f ~/OneKeyDnspod/config-ServerChan-com.cfg
	echo -e "${Msg_Success}环境清理完成，重新执行脚本以开始配置"
	exit 0
}

Entrance_ServerChan_CleanEnv(){
	echo -e "${Msg_Info}正在清理ServerChan配置……"
	rm -f /etc/OneKeyDnspod/config-ServerChan-com.cfg
	rm -f ~/OneKeyDnspod/config-ServerChan-com.cfg
	echo -e "${Msg_Success}ServerChan配置清理完成，重新执行脚本以开始配置"
	exit 0
}
Entrance_Version(){
	echo -e "
# DnspodDDNS 工具 (Dnspod国际版云解析修改工具)
#
# Build:     ${BuildTime}
# 支持平台:  CentOS/Debian/Ubuntu
# 作者:      Small_5 (部分代码来源于iLemonrain的AliDDNS)
"
	exit 0
}

case "$1" in
	run)
		Entrance_Dnspod_RunOnly;;
	config)
		Entrance_Dnspod_ConfigureOnly;;
	clean)
		Entrance_Global_CleanEnv;;
	clean_chan)
		Entrance_ServerChan_CleanEnv;;
	version)
		Entrance_Version;;
	*)
		echo -e "${Font_Blue} DnspodDDNS 工具 (Dnspod国际版云解析修改工具)${Font_Suffix}

使用方法 (Usage)：
$0 run             配置并运行工具 (如果已有配置将会直接运行)
$0 config          仅配置工具
$0 clean           清理配置文件及运行环境
$0 clean_chan      清理ServerChan配置文件
$0 version         显示版本信息

";;
esac

echo -e "${Msg_Info}选择你要使用的功能: "
echo -e " 1. 配置并运行 DnspodDDNS(国际版) \n 2. 仅配置 DnspodDDNS(国际版) \n 3. 仅运行 DnspodDDNS(国际版) \n 4. 配置ServerChan微信推送 \n 5. 清理环境 \n 6. 清理ServerChan配置文件 \n 0. 退出 \n"
read -p "输入数字以选择:" Function

if [ "${Function}" = 1 ];then
	Entrance_Dnspod_Configure_And_Run
elif [ "${Function}" = 2 ];then
	Entrance_Dnspod_ConfigureOnly
elif [ "${Function}" = 3 ];then
	Entrance_Dnspod_RunOnly
elif [ "${Function}" = 4 ];then
	Entrance_ServerChan_Config
elif [ "${Function}" = 5 ];then
	Entrance_Global_CleanEnv
elif [ "${Function}" = 6 ];then
	Entrance_ServerChan_CleanEnv
else
	exit 0
fi
