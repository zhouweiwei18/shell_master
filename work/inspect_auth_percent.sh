#!/bin/bash

export LANG="zh_CN.utf8"

# 本脚本主要用于：分析本地认证日志，计算认证成功率
# 增量计算最近一段时间（上次执行脚本至本次执行脚本时间段）的认证成功率。

DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${DIR}/dhcp_tools.sh


# 巡检项： AUTH 认证成功率
# $1 : 触发方式：0：手动触发(不需要更新缓存)；1：定时触发(需要更新缓存)（默认值：1）
# $2 : log change time，一般60（默认值：60）
# $3 : app路径（默认值：/home/dhcp4/app）
# $4 : 文件大小限制，超限制不检查（Byte）（默认值：2G）
# return:
# 0:success
# 1:failed
function inspect_auth_percent()
{
	# 日志前缀
	log_prefix="auth_server"
	trigger_type="$1"
	trigger_type=${trigger_type:=1}
	log_change_time="${2}"
	log_change_time=${log_change_time:=60}
	aaa_app_path="$3"
	aaa_app_path=${aaa_app_path:=/home/dhcp4/app}
	log_max_size_s="$4"
	log_max_size_s=${log_max_size_s:=2G}
	log_max_size=`convert_to_byte "${log_max_size_s}"`
	
	ok_code="1600"
	ok_cond="^.* ok\|.*\|.*\|.*\|(([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2})|([0-9a-zA-Z]{0,2}1[0-9]{10}[0-9a-zA-Z]{0,2})\|.*"
	all_code="all"
	all_cond="^.*\|.*\|.*\|.*\|(([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2})|([0-9a-zA-Z]{0,2}1[0-9]{10}[0-9a-zA-Z]{0,2})\|.*"

	cur_log_file=`get_log_file_name "${log_prefix}" "${log_change_time}"`
	cur_log_file="auth_server.202208151500"
	cur_log_path=${aaa_app_path}/log/${cur_log_file}
	log_file_size=`get_file_size "${cur_log_path}"`
	log_file_size_ret=$?
	if [[ ${log_file_size_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "AUTH" "inspect_auth_percent execute failed!" "${log_file_size}"
		return 1
	fi

	if [[ ${log_file_size} -gt ${log_max_size} ]]
	then
		check_result 1
		local_log "ERROR" "AUTH" "inspect_auth_percent execute failed!" "${cur_log_path} file is too big. size: ${log_file_size} byte, is bigger than ${log_max_size}."
		return 1
	fi

	# 处理行数
	proc_line=`get_file_line "${cur_log_path}"`
	proc_line_ret=$?

	echo "proc_line : ${proc_line}"

	if [[ ${proc_line_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "AUTH" "inspect_auth_percent execute failed!" "${proc_line}"
		return 1
	fi

	ok_num=`get_error_num_with_code "${cur_log_file}" "${proc_line}" "${ok_code}" "${ok_cond}" "${aaa_app_path}" "" "${trigger_type}"`
	ok_ret=$?
	if [[ ${ok_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "AUTH" "inspect_auth_percent execute failed!" "${ok_num}"
		return 1
	fi

	all_num=`get_error_num_with_code "${cur_log_file}" "${proc_line}" "${all_code}" "${all_cond}" "${aaa_app_path}" "" "${trigger_type}"`
	all_ret=$?
	if [[ ${all_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "AUTH" "inspect_auth_percent execute failed!" "${all_num}"
		return 1
	fi

	if [[ ${all_num} -eq 0 ]]
	then
		cal_ok_percent=0
	else
		((cal_ok_percent=${ok_num}*100/${all_num}))
	fi

	echo "${ok_num}"
	echo "${all_num}"

	daq_value "${cal_ok_percent}%"
	ext_result "${ok_num}" "${all_num}"
	local_log "INFO" "AUTH" "inspect_auth_percent execute succeed." "Auth success percent is ${cal_ok_percent}%"
	
	return 0
}

inspect_auth_percent "" "" "/home/bmreport/work/zhouww" ""
