#!/bin/bash
debug="0"
#################  脚本配置  ######################
config_path="./config.json"
#jq路径
jq_path="./jq_x86"
# 变动前的公网IP.....保存位置
ip_file="./ip.txt"
# 域名信息...........保存位置
domain_file="./result.json"
# ddns运行日志
log_file="./dnspod.log"
#本机ip地址
new_ip=""
#旧ip地址
old_ip=""
#记录ID
record_id=""
#记录线路ID
record_line_id=""
#记录数组
record_num=""

login_id=""
login_token=""
domain_id=""
sub_domain=""
record_type=""

#################  脚本函数  ######################
jx_config() {
	login_id=$(${jq_path} -fG ${config_path} "login_id")
	login_token=$(${jq_path} -fG ${config_path} "login_token")
	domain_id=$(${jq_path} -fG ${config_path} "domain_id")
	sub_domain=$(${jq_path} -fG ${config_path} "sub_domain")
	record_type=$(${jq_path} -fG ${config_path} "record_type")
	# 判断为空
	if [ ! $login_id ]; then
		log "没有获取到用户ID，请检查配置..."
		exit 1
	fi
	if [ ! $login_token ]; then
		log "没有获取到用户token，请检查配置..."
		exit 1
	fi
	if [ ! $domain_id ]; then
		log "没有获取到域名ID，请检查配置..."
		exit 1
	fi
	if [ ! $sub_domain ]; then
		log "没有获取到主机记录，请检查配置..."
		exit 1
	fi
	if [ ! $record_type ]; then
		log "没有获取到记录类型，请检查配置..."
		exit 1
	fi

}
check_jagou() {
	jg=$(uname -a | awk -F " " '{print $(NF-1)}')
	# 路由器的架构
	if [ $jg == "mips" ]; then
		jq_path="./jq_mipsle"
	elif [ $jg == "aarch64" ]; then
		jq_path="./jq_aarch64"
	fi
}
#日志函数
log() {
	#获取当前时间
	get_time=$(date '+%Y-%m-%d %H:%M:%S')
	if [ "$1" ]; then
		if [ $debug == "1" ]; then
			echo -e "[${get_time}] -- $1"
		else
			echo -e "[${get_time}] -- $1" >>$log_file
		fi
	fi
}
#判断jq是否存在
check_jq() {
	if [ ! -f $jq_path ]; then
		echo "jq文件不存在，请检查!!!"
		exit 1
	fi
}
#获取本机IP
get_ip() {
	log "正在获取本机IP..."
	if [ $record_type == "A" ]; then
		new_ip=$(curl -s http://v4.ipv6-test.com/api/myip.php)
		log 本机ip为${new_ip}
	elif [ $record_type == "AAAA" ]; then
		new_ip=$(curl -s http://v6.ipv6-test.com/api/myip.php)
		log 本机ip为${new_ip}
	else
		log "ip类型有错误请检查，填A或者AAAA,A代表ipv4,AAAA代表ipv6!"
		exit 1
	fi
}
#获取局域网ip---192.168.1.........(这个函数只针对我自己的jdc路由器)
get_openwrt_local_ipv4() {
	# ifc=$(ifconfig | grep "inet addr:192.168.1")
	# ipt=$(echo $ifc | awk -F: '{print $2}')
	# new_ip=$(echo $ipt | awk '{print $1}')
	new_ip="192.168.1.2"
}
#检查ip是否改变
check_ip_change() {
	log "正在检查IP..."
	if [ -f $ip_file ]; then
		old_ip=$(cat $ip_file)
		if [ "$new_ip" == "$old_ip" ]; then
			echo "IP没有改变"
			log "IP没有改变"
			exit 0
		fi
	fi
}
get_domain_info() {
	log "正在获取域名信息..."

	curl -s -X POST 'https://dnsapi.cn/Record.List' -d 'login_token='${login_id}','${login_token}'&format=json&domain_id='${domain_id}'' >${domain_file}
	# cp ${domain_file} a
	domain_info=$(cat ${domain_file})
	code=$(${jq_path} -fG "${domain_file}" "status.code")
	if [ ${code} -ne 1 ]; then
		echo "状态码不等于1,获取域名信息失败,请检查!!!"
		echo -e "${domain_info}"
		exit 1
	fi
}
get_record_num() {

	total=$(${jq_path} -fG "${domain_file}" "info.record_total")

	for ((i = 0; i < total; i++)); do
		r_type=$(${jq_path} -fG "${domain_file}" "records."${i}".type")
		if [ $r_type != "NS" ]; then
			r_type_name=$(${jq_path} -fG "${domain_file}" "records."${i}".name")
			if [ $r_type_name == $sub_domain ]; then
				record_num=${i}
				# echo "record_num${record_num}"
			fi
		fi
	done
}

get_record_info() {
	log "正在获取记录信息..."
	#记录ID
	record_id=$(${jq_path} -fG "${domain_file}" "records.${record_num}.id")
	# echo ${record_num}
	# echo "records_id$record_id"
	#记录线路ID
	record_line_id=$(${jq_path} -fG "${domain_file}" "records.${record_num}.line_id")
}

update_dns() {
	log "正在更新dns记录..."
	# echo $login_id
	# echo $login_token
	# echo $domain_id
	# echo $record_id
	# echo $sub_domain
	# echo $new_ip
	# echo $record_type
	# echo ${record_line_id}
	res=$(curl -s -X POST https://dnsapi.cn/Record.Modify -d 'login_token='${login_id}','${login_token}'&format=json&domain_id='${domain_id}'&record_id='${record_id}'&sub_domain='${sub_domain}'&value='${new_ip}'&record_type='${record_type}'&record_line_id='${record_line_id}'')
	echo -e ${res} >./res.json
	res_code=$(${jq_path} -fG "./res.json" "status.code")
	if [ ${res_code} -ne 1 ]; then
		echo "状态码不等于1,更新记录失败,请检查!!!"
		log "状态码不等于1,更新记录失败,请检查!!!"
		echo -e "${res}"
		log -e "${res}"

		rm ./res.json
		exit 1
	else
		echo "${new_ip}" >${ip_file}
		log "dns记录更新成功..."
		rm ./res.json
	fi

}
main() {
	echo "#############################" >>${log_file}
	log "ddns脚本运行..."
	# 首先检查架构
	check_jagou
	# 检查jq文件
	check_jq
	# 获取config信息
	jx_config
	#获取本机IP地址
	# get_ip
	get_openwrt_local_ipv4
	# 判断是否成功获取到IP
	if [ "$new_ip" == "" ]; then
		echo "没有获取到IP地址.请检查网络..."
		log "没有获取到IP地址.请检查网络..."
		exit 1
	fi
	# 检查IP是否变化
	check_ip_change
	#获取域名信息信息
	if [ ! -f $domain_file ]; then
		get_domain_info
	fi
	get_record_num
	#获取记录信息
	get_record_info
	# 更新记录
	update_dns
}
###################  脚本运行流程  ###################
main
