#!/bin/bash

export LANG="zh_CN.utf8"

# 本脚本主要用于：计算 系统在线用户的指标

DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${DIR}/dhcp_tools.sh


# 巡检项：系统在线用户的指标
# $1 : 数据库连接语句
#      mysql  : mysql -udbuser -ppassword== -h 10.21.17.87 -P3306 -D DBNAME
#      oracle : sqlplus dbuser/password==@DBNAME
# $2 : 阈值
# $3 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen）
# $4 : app路径（默认值: /home/dhcp4/app）
function inspect_online_user_num()
{
	db_conn_cmd="$1"
	max_online_num="$2"
	max_online_num=${max_online_num:=50}
	crygen_path="$3"
	crygen_path=${crygen_path:=/home/dhcp4/tools/EncryptionTool/crygen}
	dhcp_app_path="$4"
	dhcp_app_path=${dhcp_app_path:=/home/dhcp4/app}
	
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

	if [ "${db_tp}" == "oracle" ]
	then
		sql_cmd="SELECT  STATTIME || '|' || TO_CHAR(SUM(USEDNUM)) || ';' FROM DMS_IPUSED_STAT_AREA WHERE AREANO = '00' AND STATTYPE = 1 GROUP BY STATTIME;"
	  db_exec=$(${plain_db_conn_cmd} << EOF
set echo off
set pages 0
set feed off
set linesize 3000
${sql_cmd}
EOF
)
	else
		sql_cmd="select concat(concat_ws('|', stattime, sum(usednum)), ';') as exec_result from dms_ipused_stat_area where areano = '00' and stattype = 1;"
		# 执行sql语句
	db_exec=$(${plain_db_conn_cmd} << EOF
${sql_cmd}
EOF
)
  db_exec=$(echo ${db_exec} | sed 's/exec_result //g')
	fi

#  echo "result is:${db_exec}"

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

    db_exec=${db_exec%?}
#		time=$(echo ${db_exec} | awk -F'|' '{print $1}')
		value=$(echo ${db_exec} | awk -F'|' '{print $2}')
#		echo "the corresponding time is : ${time}"
		daq_value "${value}"
	else
		# mysql方式判断错误、解析数据
		if [[ ${ret_code} -ne 0 ]]
		then
			check_result 1
			local_log "ERROR" "DB_CONNECT" "inspect_db_connection execute failed!" "sql: ${sql_cmd}    output: ${db_exec}"
			return 1
		fi
		db_exec=${db_exec%?}
#		time=$(echo ${db_exec} | awk -F'|' '{print $1}')
		value=$(echo ${db_exec} | awk -F'|' '{print $2}')
#		echo "the corresponding time is : ${time}"
		daq_value "${value}"
	fi

	local_log "INFO" "DB_CONNECT" "inspect_db_connection execute succeed." "sql: ${sql_cmd}    output: ${db_exec}"
	return 0
}

# 巡检项：系统在线用户的指标
# $1 : mysql -h10.21.17.145 -P23306 -udhcp4_dev -phDJ8D/V2JntDIDUsD0kAgA== -DLCDMP4_SEPE_DEV
# $2 : 阈值: 1000
# $3 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen）: /home/bmreport/work/zhouww/tools/crygen
# $4 : app路径（默认值: /home/dhcp4/app）

# mysql 语法
inspect_online_user_num "mysql -h10.21.17.145 -P23306 -udhcp4_dev -phDJ8D/V2JntDIDUsD0kAgA== -DLCDMP4_SEPE_DEV" "1000" "/home/bmreport/work/zhouww/tools/crygen" ""

# oracle 语法
#sqlplus -S DHCP4_DEV1/0YD9AcIU0KvFE+fdADbTSA==@10.21.17.145:1521/LCDMP3
#inspect_online_user_num "sqlplus -S DHCP4_DEV1/0YD9AcIU0KvFE+fdADbTSA==@10.21.17.145:1521/LCDMP3" "1000" "/home/bmreport/work/zhouww/tools/crygen" ""
