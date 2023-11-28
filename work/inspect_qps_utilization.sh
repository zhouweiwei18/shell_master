#!/bin/bash

export LANG="zh_CN.utf8"

# 本脚本主要用于：计算QPS利用率(平台)
# QPS利用率(平台) = （当前访问QPS/最大承载QPS）*100%
# 其中 最大承载QPS 可配
#      当前访问QPS 从界面获取（系统负载统计->统计表格->全部）

DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${DIR}/dhcp_tools.sh

# 根据当前时间 获取endtime
# $1 : 偏移秒数  如：+60 向后偏移60秒    -60 向前偏移60秒
function get_endtime()
{
	cur_sec=$(date +%s)
	off_sec=$((${cur_sec}${1}))
	
	t_year=$(date -d @${off_sec} +%Y)
	t_month=$(date -d @${off_sec} +%m)
	t_day=$(date -d @${off_sec} +%d)
	t_hour=$(date -d @${off_sec} +%H)
	t_minute=$(date -d @${off_sec} +%_M)
	
	offset=$((${t_minute}%5))
	t_new_minute=$((${t_minute}-${offset}))
	
	if [[ ${#t_new_minute} -eq 1 ]]
	then
		t_new_minute=0${t_new_minute}
	fi
	
	echo "${t_year}-${t_month}-${t_day} ${t_hour}:${t_new_minute}:00"
}

# 巡检项：QPS利用率(平台)
# $1 : 数据库连接语句
#      mysql  : mysql -udbuser -ppassword== -h 10.21.17.87 -P3306 -D DBNAME
#      oracle : sqlplus dbuser/password==@DBNAME
# $2 : 最大承载QPS
# $3 : 中心IP
# $4 : 偏移秒数  如：+60 向后偏移60秒    -60 向前偏移60秒   （默认值：-30）
# $5 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen）
# $6 : app路径（默认值: /home/dhcp4/app）
function inspect_qps_utilization()
{
	db_conn_cmd="$1"
	max_qps="$2"
	center_ip="$3"
	sec_offset="$4"
	sec_offset=${sec_offset:=-30}
	crygen_path="$5"
	crygen_path=${crygen_path:=/home/dhcp4/tools/EncryptionTool/crygen}
	dhcp_app_path="$6"
	dhcp_app_path=${dhcp_app_path:=/home/dhcp4/app}
	
	cur_month=$(date +%m)
	
	if [ -f "${dhcp_app_path}/bin/shstartexec.env" ]
	then
	. ${dhcp_app_path}/bin/shstartexec.env
	fi
	
	db_tp=$(db_type "${db_conn_cmd}")
	
	if [ "${db_tp}" != "mysql" ] && [ "${db_tp}" != "oracle" ]
	then
		check_result 1
		local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "Parse database connect command failed!"
		return 1
	fi
	
	plain_db_conn_cmd=$(pass_decrypt "${db_conn_cmd//\'/}" "${db_tp}" "${crygen_path}")
	ret_code=$?
	
	if [[ ${ret_code} -eq 1 ]] || [ "${plain_db_conn_cmd}" == "" ]
	then
		check_result 1
		local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "Parse database connect command failed!"
		return 1
	fi
	
	check_dbconn "${plain_db_conn_cmd}"
	ret_code=$?
	
	if [[ ${ret_code} -eq 1 ]]
	then
		check_result 1
		local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "Cannot connect to specified database!"
		return 1
	fi
	
	endtime=$(get_endtime ${sec_offset})
	
	if [ "${db_tp}" == "oracle" ]
	then
		sql_cmd="SELECT SUM(TOTAL) FROM D_DHCPPKT_STAT${cur_month} WHERE VTYPE = 0 AND PKTTYPE = 999 AND SOFTWAREID IN (SELECT SOFTWAREID FROM D_SOFTWARE_INSTANCE_V dsi, D_MACHINE_INFO dmi WHERE dsi.STATUS != 1 AND dmi.STATUS != 1 AND dsi.MACHINEID = dmi.MACHINEID AND dsi.SOFTWARETYPEID = 1000003 AND dmi.CENTERID = (SELECT CENTERID FROM D_SERVICE_CENTER WHERE STATUS = 0 AND IPADDRESS = '${center_ip}')) AND ENDTIME = TO_DATE('${endtime}','YYYY-MM-DD HH24:MI:SS') GROUP BY ENDTIME ;"
	else
		sql_cmd="select sum(TOTAL) from d_dhcppkt_stat11 where vtype = 0 and pkttype = 999 and softwareid in ( select softwareid from d_software_instance_v dsi, d_machine_info dmi where dsi.status != 1 and dmi.status != 1 and dsi.machineid = dmi.machineid and dsi.softwaretypeid = 1000003 and dmi.centerid = ( select centerid from d_service_center where status = 0 and ipaddress = '1.1.1.1' ) ) and endtime = date_format('2023-11-12 14:20:00', '%Y-%m-%d %T') group by endtime;"
	fi
	
	# 执行sql语句
	db_exec=$(${plain_db_conn_cmd} << EOF
${sql_cmd}
EOF
)

	# mysql 执行失败返回值是1
	ret_code=$?

	if [ "${db_exec}" == "" ]
	then
		check_result 1
		local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "sql: ${sql_cmd}"
		return 1
	fi
	
	if [ "${db_tp}" == "oracle" ]
	then
		# oracle方式判断错误、解析数据
		err=`echo "${db_exec}" | grep -E "^ORA-[0-9]{5}.*" | wc -l`
		if [[ ${err} -ne 0 ]]
		then
			check_result 1
			local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "sql: ${sql_cmd}    output: ${db_exec}"
			return 1
		fi
		oracledata_tmp=${db_exec##*---}
        oracledata=${oracledata_tmp%%SQL*}
        exec_out=`echo "$oracledata" | tr -d " \t\n"`
	else
		# mysql方式判断错误、解析数据
		if [[ ${ret_code} -ne 0 ]]
		then
			check_result 1
			local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "sql: ${sql_cmd}    output: ${db_exec}"
			return 1
		fi
		exec_out=`echo "${db_exec}" | grep -iv TOTAL`
	fi
    
    echo "${exec_out}" | [ -z "`sed -n '/^[0-9][0-9]*$/p'`" ] && (check_result 1 ; local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "sql: ${sql_cmd}    output: ${db_exec}" ; return 1)
	
	# exec_out 是5分钟的统计量，需要除以300计算每秒统计量
	out_rate=$((${exec_out}*100/300/${max_qps}))
	daq_value "${out_rate}%"
	ext_result "${exec_out}" "$((300 * ${max_qps}))"
	local_log "INFO" "DB_CONNECT" "inspect_db_connection execute succeed." "sql: ${sql_cmd}    output: ${db_exec}"
	return 0
}

# $1 : mysql -h10.21.17.145 -P23306 -udhcp4_dev -phDJ8D/V2JntDIDUsD0kAgA== -DLCDMP4_SEPE_DEV
# $2 : 最大承载QPS : 90
# $3 : 中心IP: 1.1.1.1
# $4 : 偏移秒数  如：+60 向后偏移60秒    -60 向前偏移60秒   （默认值：-30）
# $5 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen） : /home/bmreport/work/zhouww/tools/crygen
# $6 : app路径（默认值: /home/dhcp4/app）

#inspect_qps_utilization "$1" "$2" "$3" "$4" "$5" "$6"

inspect_qps_utilization "mysql -h10.21.17.145 -P23306 -udhcp4_dev -phDJ8D/V2JntDIDUsD0kAgA== -DLCDMP4_SEPE_DEV" "90" "1.1.1.1" "" "/home/bmreport/work/zhouww/tools/crygen" ""
get_endtime

# 此shell SQL语句没做调整, 仅家里环境为表名小写

