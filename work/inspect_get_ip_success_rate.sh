#!/bin/bash

export LANG="zh_CN.utf8"
export NLS_LANG="SIMPLIFIED CHINESE_CHINA.AL32UTF8"

# 本脚本主要用于：计算地市开机成功率
# 地市开机成功率 =上线成功数/( 上线成功数+上线失败数)*100%
# 

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

# 巡检项：地市开机成功率
# $1 : 数据库连接语句
#      mysql  : mysql -udbuser -ppassword== -h 10.21.17.87 -P3306 -D DBNAME
#      oracle : sqlplus -S dbuser/password@DBNAME
# $2 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen）
# $3 : app路径（默认值: /home/dhcp4/app）
# $4 : 偏移秒数  如：+60 向后偏移60秒    -60 向前偏移60秒   （默认值：-30）
function get_ip_success_rate()
{
	db_conn_cmd="$1"
	crygen_path="$2"
	crygen_path=${crygen_path:=/home/dhcp4/tools/EncryptionTool/crygen}
	dhcp_app_path="$3"
	dhcp_app_path=${dhcp_app_path:=/home/dhcp4/app}
    sec_offset="$4"
	sec_offset=${sec_offset:=-30}
	tmp_file="./tmp.txt"
	error_file='./error.txt'
	mysql_tmp_file='./mysql.tmp'
	
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
		sql_cmd="SELECT '|' || AREA_NAME || '|' || ONLINE_OK || '|' || ONLINE_ALL || '|' || SUCCESS_RATE || ';' FROM DHCP_ONLINE_RATE_STAT_AREA WHERE END_TIME = TO_DATE('${endtime}','yyyy-MM-dd HH24:mi:ss') AND AREA_NO != '00';"
		# 执行sql语句
		$(${plain_db_conn_cmd} << EOF >${tmp_file} 2>${error_file}
set echo off
set pages 0
set feed off
set linesize 3000
${sql_cmd}
EOF
)
	else
		sql_cmd="SELECT CONCAT('|',CONCAT_WS('|',AREA_NAME, ONLINE_OK, ONLINE_ALL,SUCCESS_RATE),';') FROM DHCP_ONLINE_RATE_STAT_AREA WHERE END_TIME = DATE_FORMAT('2023-04-23 11:35:00','%Y-%m-%d %T') AND AREA_NO != '00';"
		$(${plain_db_conn_cmd} << EOF >${mysql_tmp_file} 2>${error_file}
${sql_cmd}
EOF
)
		# mysql 执行失败返回值是1
		ret_code=$?
		
		$(sed -e '/CONCAT_WS/d'  ${mysql_tmp_file}  > ${tmp_file})
		rm ${mysql_tmp_file}
	fi
	
	db_exec=$(cat ${tmp_file})
	db_exec="${db_exec}$(cat ${error_file})"

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
		#oracledata_tmp=${db_exec##*---}
        #oracledata=${oracledata_tmp%%SQL*}
        #exec_out=`echo "$oracledata" | tr -d " \t\n"`
	else
		# mysql方式判断错误、解析数据
		if [[ ${ret_code} -ne 0 ]]
		then
			check_result 1
			local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "sql: ${sql_cmd}    output: ${db_exec}"
			return 1
		fi
		#exec_out=`echo "${db_exec}" | grep -iv TOTAL`
	fi
	
	i=10
	min=100
	line_tmp=""

	# 记录分子分母
	molecular=""
	denominator=""

	while read line
	do
		percent_tmp=${line##*|}
		percent_tmp=${percent_tmp%%%*}
		if [[ $(compare ${min} ${percent_tmp}) -eq 1 ]]
		then
			min=${percent_tmp}
			molecular=$(echo ${line} | awk -F'|' '{print $3}')
			denominator=$(echo ${line} | awk -F'|' '{print $4}')
		fi
		if [[ $i -eq 0 ]]
		then
			multi_daq_value "${line_tmp}"
			line_tmp="${line}"
			i=9
		else	
			((i--))
			line_tmp="${line_tmp}${line}"
		fi
	done < ${tmp_file}
	if [[ $i -ne 10 ]] || [[ $i -ne 0 ]]
	then
		multi_daq_value "${line_tmp}"
	fi
	daq_value "${min}%"
	ext_result "$molecular" "$denominator"
	local_log "INFO" "DB_CONNECT" "inspect_db_connection execute succeed." "sql: ${sql_cmd}"
	echo "====================start cat tmp_file===================="
	cat ${tmp_file}
	echo "====================end cat tmp_file===================="
	rm ${tmp_file}
	rm ${error_file}
	return 0
}


# $1 : mysql -h10.21.41.161 -P3306 -uaisddi -pROsLS4xDodk3ess+vjRCVg== -DAIDIP_DIP_1952
# $2 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen）: /home/bmreport/work/zhouww/tools/crygen
# $3 : app路径（默认值: /home/dhcp4/app）
# $4 : 偏移秒数  如：+60 向后偏移60秒    -60 向前偏移60秒   （默认值：-30）
get_ip_success_rate "mysql -h10.21.41.161 -P3306 -uaisddi -pROsLS4xDodk3ess+vjRCVg== -DAIDIP_DIP_1952" "/home/bmreport/work/zhouww/tools/crygen" "" ""

#get_ip_success_rate "sqlplus -S AIDIP_DIP_194P2/eqwjOGOP/Z/BW3Lois6prQ==@10.21.41.162:1521/LCDMP2" "/home/bmreport/work/zhouww/tools/crygen" "" ""

