#!/bin/bash

export LANG="zh_CN.utf8"

# 本脚本主要用于：采集协议解析日志最近一段时间（增量统计）指定错误码日志量（多个错误码使用,分割）
# 输出每个错误码在协议解析日志文件中出现总次数，统计时间为上次执行脚本至本次执行脚本时间段

DIR="$(cd "$(dirname "$0")" && pwd)"
. ${DIR}/dhcp_tools.sh

# 巡检项： DHCP 错误码数量统计
# $1 : 错误码      e.g.  512,517,518,602
# $2 : 环比百分比-阈值
# $3 : 触发方式：0：手动触发(不需要更新缓存)；1：定时触发(需要更新缓存)（默认值：1）
# $4 : log change time，一般60（默认值：60）
# $5 : app路径（默认值：/home/dhcp4/app）
# $6 : 文件大小限制，超限制不检查（Byte）（默认值：2G）
function inspect_err_code_num() {
	# 上次统计数据缓存在 dhcp_statistics 目录中
	mkdir -p dhcp_statistics

	err_codes=(${1//,/ })
	ths_inc_percent="$2"
	trigger_type="$3"
	trigger_type=${trigger_type:=1}
	log_change_time="${4}"
	log_change_time=${log_change_time:=60}
	dhcp_app_path="$5"
	dhcp_app_path=${dhcp_app_path:=/home/dhcp4/app}
	log_max_size_s="$6"
	log_max_size_s=${log_max_size_s:=2G}
	log_max_size=$(convert_to_byte "${log_max_size_s}")

	# 错误码总数
	err_codes_count=0
	log_prefix="dhcp"

	cur_log_file=$(get_log_file_name "${log_prefix}" "${log_change_time}")
	cur_log_path=${dhcp_app_path}/log/${cur_log_file}

	log_file_size=$(get_file_size "${cur_log_path}")
	log_file_size_ret=$?
	if [[ ${log_file_size_ret} -eq 1 ]]; then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_err_code_num execute failed!" "${log_file_size}"
		return 1
	fi

	if [[ ${log_file_size} -gt ${log_max_size} ]]; then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_err_code_num execute failed!" "${cur_log_path} file is too big. size: ${log_file_size} byte, is bigger than ${log_max_size}."
		return 1
	fi

	proc_line=$(get_file_line "${cur_log_path}")
	proc_line_ret=$?
	if [[ ${proc_line_ret} -eq 1 ]]; then
		check_result 1
		local_log "ERROR" "DHCP" "inspect_err_code_num execute failed!" "${proc_line}"
		return 1
	fi

	alarm_flag=0
	err_code_count_flag=0
	molecular=""
	denominator=""

	for err_code in ${err_codes[@]}; do
		err_cond=" failed\|${err_code}\|"
		err_num=$(get_error_num_with_code "${cur_log_file}" "${proc_line}" "${err_code}" "${err_cond}" "${dhcp_app_path}" "" "${trigger_type}" "_growth_any_alarm")
		err_codes_count=$err_num
		inspect_cache_file_path=dhcp_statistics/inspect_errcode_${err_code}_any_growth
		if [ -f "${inspect_cache_file_path}" ]; then
			last_err_codes_count=$(cat ${inspect_cache_file_path})
			last_err_codes_count=${last_err_codes_count:=0}
		else
			last_err_codes_count=0
		fi
		if [ $last_err_codes_count == "0" ]; then
			if [ -f "${inspect_cache_file_path}" ] && [ "$err_codes_count" != "0" ]; then
				alarm_flag=1
				err_code_count_flag=$err_codes_count
			fi
		else
			ratio=$(awk -v new=$err_codes_count -v old=$last_err_codes_count 'BEGIN{printf "%.2f",(new-old)/old*100}')
			ratio=${ratio#-}
			if [ $(echo "$ratio >= $ths_inc_percent" | bc) -eq 1 ]; then
				alarm_flag=1
				err_code_count_flag=$err_codes_count
				molecular=$(($err_codes_count - $last_err_codes_count))
			  denominator=$last_err_codes_count
			fi
		fi
		# 更新缓存
		if [[ ${trigger_type} -eq 1 ]]; then
			echo "${err_codes_count}" >${inspect_cache_file_path}
		fi
	done

	if [[ $alarm_flag -eq 1 ]]; then
		check_result 1
	else
		check_result 0
	fi
	daq_value "${err_code_count_flag}"
	ext_result "$molecular" "$denominator"
	local_log "INFO" "DHCP" "inspect_err_code_num execute succeed." "Error code  count is ${err_code_count_flag}."

	return 0
}

inspect_err_code_num "$1" "$2" "$3" "$4" "$5" "$6"