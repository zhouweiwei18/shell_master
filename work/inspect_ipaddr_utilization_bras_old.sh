#!/bin/bash

export LANG="zh_CN.utf8"
export NLS_LANG="SIMPLIFIED CHINESE_CHINA.AL32UTF8"

# 本脚本主要用于：Bras地址利用率
# Bras地址利用率 =（当前bras地址使用量/bras已配置地址数）*100%
# 

DIR="$( cd "$( dirname "$0" )" && pwd )"
. ${DIR}/dhcp_tools.sh

# 巡检项：Bras地址利用率
# $1 : 数据库连接语句
#      mysql  : mysql -udbuser -ppassword== -h 10.21.17.87 -P3306 -D DBNAME
#      oracle : sqlplus -S dbuser/password@DBNAME
# $2 : 加解密工具路径（默认值：/home/dhcp4/tools/EncryptionTool/crygen）
# $3 : app路径（默认值: /home/dhcp4/app）

function ipaddr_utilization_bras()
{
	db_conn_cmd="$1"
	crygen_path="$2"
	crygen_path=${crygen_path:=/home/dhcp4/tools/EncryptionTool/crygen}
	dhcp_app_path="$3"
	dhcp_app_path=${dhcp_app_path:=/home/dhcp4/app}
	tmp_file="./data.txt"
	error_file='./error.txt'
	read_file='./read_file'
	
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
	
	if [ "${db_tp}" == "oracle" ]
	then
		sql_cmd="SELECT device1.devicename||'|'||table2.NAME||'|'||cast( nvl(to_char(TRUNC((( device1.usednum / decode(device1.totalnum,0,1,device1.totalnum)) * 100 ),2 ),'FM999999999999990.00'),'0.00' ) as number(15,2))||'%'||';' FROM DMS_IPUSED_STAT_DEVICE device1, MD_AREA table2 WHERE device1.stattype = 1 AND table2.AREANO = device1.AREANO;"
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
		sql_cmd="SELECT CONCAT(CONCAT_WS('|',device1.devicename,table2.NAME,ROUND((device1.usednum / (case device1.totalnum when '0' then '1' else device1.totalnum end)*100), 2)),'%;') from dms_ipused_stat_device device1, md_area table2 where device1.stattype = 1 AND table2.AREANO = device1.AREANO;"
		$(${plain_db_conn_cmd} << EOF >${read_file} 2>${error_file}
${sql_cmd}
EOF
)
		# mysql 执行失败返回值是1
		ret_code=$?
	
		$(sed -e '/CONCAT_WS/d'  ${read_file}  > ${tmp_file})
		rm ${read_file}
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
	max=0
	line_tmp=""

	while read line
	do
		percent_tmp=${line##*|}
		percent_tmp=${percent_tmp%%%*}
		if [[ $percent_tmp = .* ]]
		then
			percent_tmp="0${percent_tmp}"
			tmp_l=${line%|*}
			line="${tmp_l}|${percent_tmp}%;"
		fi
		
		#if [[ `expr ${max} \< ${percent_tmp}` -eq 1 ]]
		if [[ $(compare ${max} ${percent_tmp}) -eq 0 ]]
		then
			max=${percent_tmp}
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
	daq_value "${max}%"
	local_log "INFO" "DB_CONNECT" "inspect_db_connection execute succeed." "sql: ${sql_cmd}"
	rm ${tmp_file}
	rm ${error_file}
	return 0
}

ipaddr_utilization_bras "mysql -h10.21.17.145 -P23306 -udhcp4_dev -phDJ8D/V2JntDIDUsD0kAgA== -DLCDMP4_SEPE_DEV" "/home/bmreport/work/zhouww/tools/crygen" ""

