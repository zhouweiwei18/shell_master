#!/bin/bash

export LANG="zh_CN.utf8"

# 本脚本主要用于：分析协议解析日志，计算分配成功率
# 增量计算最近一段时间（上次执行脚本至本次执行脚本时间段）的分配成功率。

DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${DIR}/dhcp_tools.sh


# 巡检项： DHCP 分配成功率
# $1 : 需要过滤的discover错误码   e.g.  601,701
# $2 : 触发方式：0：手动触发(不需要更新缓存)；1：定时触发(需要更新缓存)（默认值：1）
# $3 : app路径（默认值：/home/dhcp4/app）
# $4 : log change time，一般60（默认值：60）
# $5 : 文件大小限制，超限制不检查（Byte）（默认值：2G）
# return:
# 0:success
# 1:failed
function inspect_alloc_percent()
{
	# 日志前缀
	log_prefix="dhcp"
	log_filter_code="$1"
	trigger_type="$2"
	trigger_type=${trigger_type:=1}
	dhcp_app_path="$3"
	dhcp_app_path=${dhcp_app_path:=/home/dhcp4/app}
	log_change_time="${4}"
	log_change_time=${log_change_time:=60}
	log_max_size_s="$5"
	log_max_size_s=${log_max_size_s:=2G}
	log_max_size=`convert_to_byte "${log_max_size_s}"`
	ok_code="0"
	ok_cond=" ok\|0\|1\|"
	all_code="discover"
	all_cond="(ok|failed)\|[0-9]+\|1\|"

	cur_log_file=`get_log_file_name "${log_prefix}" "${log_change_time}"`
	# 仅测试时使用
	cur_log_file="dhcp.202302271300"
	cur_log_path=${dhcp_app_path}/log/${cur_log_file}

	log_file_size=`get_file_size "${cur_log_path}"`
	log_file_size_ret=$?
	if [[ ${log_file_size_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_alloc_percent execute failed!" "${log_file_size}"
		return 1
	fi

	if [[ ${log_file_size} -gt ${log_max_size} ]]
	then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_alloc_percent execute failed!" "${cur_log_path} file is too big. size: ${log_file_size} byte, is bigger than ${log_max_size}."
		return 1
	fi

	proc_line=`get_file_line "${cur_log_path}"`
	proc_line_ret=$?
	if [[ ${proc_line_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_alloc_percent execute failed!" "${proc_line}"
		return 1
	fi

	ok_num=`get_error_num_with_code "${cur_log_file}" "${proc_line}" "${ok_code}" "${ok_cond}" "${dhcp_app_path}" "" "${trigger_type}"`
	ok_ret=$?
	if [[ ${ok_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_alloc_percent execute failed!" "${ok_num}"
		return 1
	fi

	all_num=`get_error_num_with_code "${cur_log_file}" "${proc_line}" "${all_code}" "${all_cond}" "${dhcp_app_path}" "${log_filter_code}" "${trigger_type}"`
	all_ret=$?
	if [[ ${all_ret} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_alloc_percent execute failed!" "${all_num}"
		return 1
	fi

	if [[ ${all_num} -eq 0 ]]
	then
		cal_ok_percent=0
	else
		((cal_ok_percent=${ok_num}*100/${all_num}))
	fi

	if [[ ${cal_ok_percent} -gt 100 ]]
	then
		cal_ok_percent=100
	fi

	daq_value "${cal_ok_percent}%"
	ext_result "${ok_num}" "${all_num}"
	local_log "INFO" "DHCP" "inspect_alloc_percent execute succeed." "Alloc success percent is ${cal_ok_percent}%"
	
	return 0
}

# $1 : 需要过滤的discover错误码   e.g.  601,701
# $2 : 触发方式：0：手动触发(不需要更新缓存)；1：定时触发(需要更新缓存)（默认值：1）
# $3 : app路径（默认值：/home/dhcp4/app）
# $4 : log change time，一般60（默认值：60）
# $5 : 文件大小限制，超限制不检查（Byte）（默认值：2G）

inspect_alloc_percent "601" "" "/home/bmreport/work/zhouww" "" ""
