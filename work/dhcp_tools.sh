#!/bin/bash

export LANG="zh_CN.utf8"

cfg_prefix="_CFG"

########################  配置项相关  ########################
# 加载配置项
# $1 : 配置文件路径
# e.g  load_config "test.cfg"
function load_config()
{
    last_tag=""

    while read line
    do
        line=`echo "$line" | awk '{gsub(/^\s+|\s+$/, "");print}'`
        if [ "${line}" == "" ] || [ "${line:0:1}" == "#" ]
        then
            continue
        fi
	
        if [ "${line:0:1}" == '[' ]
        then
            last_tag="${line%%]*}"
            last_tag="${last_tag#*[}"
            continue
        fi

        key=`echo "$line" | cut -d "=" -f 1 | awk '{gsub(/^\s+|\s+$/, "");print}'`
        value=`echo "${line#*=}" | awk '{gsub(/^\s+|\s+$/, "");print}'`

        eval ${cfg_prefix}_${last_tag}_${key}='${value}'
    done < "$1"
}

# 获取配置项
# $1 : [DOMAIN]
# $2 : KEY
function get_cfg_item()
{
    eval echo \$"${cfg_prefix}_${1}_${2}"
}

# 简化版的获取配置项值的函数
# $1 : 配置文件路径
# $2 : 配置项名
# return : 0:取配置值成功   1:取配置值失败    2:配置文件不存在
function get_config_item()
{
	if [ ! -f ${1} ]
	then
		return 2
	fi
	
    item_value=`grep -w "${2}" "${1}" | head -1 | awk -F '=' '{print $2}' | awk '{sub(/^ */, "");sub(/[ \n\r]*$/, "")}1'`
    ret_count=`echo "${item_value}" | wc -l`
    
    if [[ ${ret_count} -eq 0 ]]
    then
        return 1
    fi
    
    echo "${item_value}" | tr -d '"'
    return 0
}

########################  cmdsh 相关  #########################
# cmdsh命令工具
# 子系统进程不存在，打印：
# ! login failed
# ! failed to send version query packet (#-9)
# 子系统连接超过最大数目，打印
# ! login failed
# ! login failed
# 入参说明：
# $1 : cmdsh path
# $2 : ip
# $3 : port
# $4 : cmd
# 返回值:
# 0: 执行成功
# 1: 子系统进程不存在
# 2: 子系统连接超过最大数目
# 3: cmdsh可执行程序不存在
function cmdsh_guard()
{
    cmdsh_path="${1}"
    remote_ip="${2}"
    remote_port="${3}"
    remote_cmd="${4}"

    print_out=$(${cmdsh_path} "${remote_ip}" "${remote_port}" -e "${remote_cmd}")
    ret_code=$?

    echo "${print_out}"

    # cmdsh可执行程序不存在
    if [[ ${ret_code} -eq 127 ]]
    then
        return 3
    fi

    if [ "${print_out}" = "" ]
    then
        return 1
    fi

    # 进程未启动
    not_conn_1=$(echo "${print_out}" | grep -E 'connect to 127.0.0.1.*failed' | wc -l)
    # 超出最大连接数
    not_conn_2=$(echo "${print_out}" | grep '! login failed: ! version query timeout' | wc -l)
    
    # 子系统进程不存在
    if [[ ${not_conn_1} -eq 1 ]]
    then
        return 1
    fi
    
    # 子系统连接超过最大数目
    if [[ ${not_conn_2} -eq 1 ]]
    then
        return 2
    fi

    return 0
}

# 从数据库连接信息中解析出是MySQL还是Oracle
# $1 : dbconn
# 返回值：
# 1: mysql
# 0: oracle
# 9: 未知
function db_type()
{
    if [[ "$1" = mysql* ]]; then
        echo "mysql"
        return 1
    elif [[ "$1" = sqlplus* ]]; then
        echo "oracle"
        return 0
    fi

    return 9
}

# 数据库密码解密，在数据库连接语句中直接使用明文替换掉密文
# $1 : 数据库连接语句（包含密码）
# $2 : 数据库类型
# $3 : 加解密工具路径
# return:
# 0 : 成功
# 1 : 失败
function pass_decrypt()
{
	db_conn="$1"
	db_t="$2"
	crygen_tool_path="$3"
	
	if [ "${db_t}" == "mysql" ]
	then
		ciphertext=$(echo "${db_conn}" | grep -oE '\-p[ ]*[^ ]*' | sed 's/-p//' | sed 's/ //g')
	else
		ciphertext=$(echo "${db_conn}" | grep -oE '/.*@' | cut -c 2- | sed 's/@//')
	fi
	
	if [ "${ciphertext}" == "" ]
	then
		return 1
	fi
	
	plaintext=$(${crygen_tool_path} -a -k cad7ab0e0dd3a490fed77f9e1fadd521 -c ${ciphertext})
	if [ "${plaintext}" == "" ]
	then
		return 1
	fi
	
	if [ "${db_t}" == "mysql" ]
	then
		echo "${db_conn}" | sed "s?-p.*${ciphertext}?-p${plaintext}?"
	else
		echo "${db_conn}" | sed "s?${ciphertext}?${plaintext}?"
	fi
	
	return 0
}

# 数据库登录和连通性校验
# $1 : 数据库连接语句
# 返回值：
# 0: 检验通过，该主机能正常连接数据库
# 1: 检验不通过，该主机不能正常连接数据库
function check_dbconn()
{
    db_login_conn="$1"
    db_t=$(db_type "${db_login_conn}")

    if [ "${db_t}" == "mysql" ]; then
        db_login=$(${db_login_conn} << EOF
select date_format(now(),'%Y%m') as DATE1;
EOF
)
    elif [ "${db_t}" == "oracle" ]; then
        db_login=$(${db_login_conn} << EOF
select to_char(sysdate,'yyyyMM') as DATE1 from dual;
EOF
)
    fi

    sysdate=$(date +"%Y%m")
    if [[ ${db_login} =~ ${sysdate} ]]; then
        return 0
    fi

    return 1
}


########################  对外输出相关  ########################
# $1 : ftp IP地址
# $2 : ftp 端口
# $3 : ftp 账号
# $4 : ftp 密码
# $5 : ftp 上传路径
# $6 : 日志所在本地路径
# $7 : FTP超时时间（秒）
# return code
# 0 : success
# 1 : 登录失败
# 2 : ${ftp_up_path}/ 路径不存在
# 3 : 没有创建文件夹权限
# 4 : 上传文件失败
function ftp_upload()
{
	ftp_ip="${1}"
	ftp_port="${2}"
	ftp_account="${3}"
	ftp_password="${4}"
	ftp_up_path="${5}"
	log_local_path="${6}"
	time_out="${7}"
	now_day=`date +"%Y%m%d"`
	
	# 探测FTP能否登录；探测FTP上是否存在文件夹 ftp_up_path
	ftp_print=`timeout ${time_out} ftp -vinp "${ftp_ip}" "${ftp_port}" << EOF
	user "${ftp_account}" "${ftp_password}"
	cd "${ftp_up_path}"
	bye
EOF`
	error_login=`echo "${ftp_print}" | grep -i "Login incorrect" | wc -l`
	error_cd=`echo "${ftp_print}" | grep -i "Failed to change directory" | wc -l`
	
	if [[ ${error_login} -gt 0 ]]
	then
		echo "${ftp_print}"
		return 1
	fi
	
	if [[ ${error_cd} -gt 0 ]]
	then
		echo "${ftp_print}"
		return 2
	fi
	
	# 探测FTP是否有权限创建目录
	ftp_print=`timeout ${time_out} ftp -vinp "${ftp_ip}" "${ftp_port}" << EOF
	user "${ftp_account}" "${ftp_password}"
	cd "${ftp_up_path}"
	mkdir "${now_day}"
	cd "${now_day}"
	bye
EOF`
	error_cd=`echo "${ftp_print}" | grep -i "Failed to change directory" | wc -l`
	if [[ ${error_cd} -gt 0 ]]
	then
		echo "${ftp_print}"
		return 3
	fi

	ftp_print=`timeout ${time_out} ftp -vinp "${ftp_ip}" "${ftp_port}" << EOF
	user "${ftp_account}" "${ftp_password}"
	cd "${ftp_up_path}"
	cd "${now_day}"
	lcd "${log_local_path}/"
	mput "04_*.txt"
	bye
EOF`
	
	error_put=`echo "${ftp_print}" | grep -i "Transfer complete" | wc -l`
	if [[ ${error_put} -eq 0 ]]
	then
		echo "${ftp_print}"
		return 4
	else
		echo "${ftp_print}"
		return 0
	fi
}


########################  日志记录相关  ########################
# 记录系统日志
# $1 : 日志级别，ERROR/INFO
# $2 : 日志内容
function sys_log()
{
	now=`date +"%Y-%m-%d %H:%M:%S"`
	echo "${now} [${1}] ${2}"
}

# 记录日志
# $1 : 日志级别， ERROR/INFO
# $2 : 角色
# $3 : 巡检项
# $4 : 日志内容
function local_log()
{
	now=`date +"%Y-%m-%d %H:%M:%S"`

	echo "${now} ${1}: [${2}] ${3} ${4}"
}

# 输出采集值
# $1 : 采集值
function daq_value()
{
	echo "daq_value:$1"
}

# 输出采集值
# $1 : 采集值
# $2 : 采集值
function ext_result()
{
	echo "ext_result:molecular=$1;denominator=$2"
}

# 输出采集值
# $1 : 采集值
function multi_daq_value()
{
	echo "multi_daq_value:$1"
}

# 输出巡检结果
# $1 : 结果  0: 正常   其他: 异常
function check_result()
{
	if [[ $1 -eq 0 ]]
	then
		echo "check_result:10601"
	else
		echo "check_result:10602"
		echo "alarm_level:11801"
	fi
}


########################  业务相关  ########################
# 获取日志全称
# $1 : 日志名前缀 如：dhcp
# $2 : log change time，一般60
function get_log_file_name()
{
	minute=`date +"%M"`
	minute=`expr ${minute} / ${2} \* ${2}`
	if [[ ${minute} -eq 0 ]]
	then
		logtime=`date +"%Y%m%d%H"`00
	else
		logtime=`date +"%Y%m%d%H"`${minute}
	fi

	echo "${1}.${logtime}"
}

# 用于获取日志文件行数
# $1 : 文件路径
# return:
# 0:获取成功，打印行数
# 1:文件不存在
function get_file_line()
{
	log_path="$1"

	if [ ! -f ${log_path} ]
	then
		echo "${log_path} not exist!"
        sleep 5
        if [ ! -f ${log_path} ]
        then
            echo "${log_path} not exist!"
            return 1
        fi
	fi

	calc_line_num=`wc -l ${log_path} | awk -F ' ' '{print $1}'`
	echo "${calc_line_num}"
	return 0
}

# 用于获取日志文件大小
# $1 : 文件路径
# return:
# 0:获取成功，打印大小（Byte）
# 1:文件不存在
function get_file_size()
{
	log_path="$1"

	if [ ! -f ${log_path} ]
	then
		echo "${log_path} not exist!"
        sleep 5
        if [ ! -f ${log_path} ]
        then
            echo "${log_path} not exist!"
            return 1
        fi
	fi

	calc_size=`du -b ${log_path} | awk -F ' ' '{print $1}'`
	echo "${calc_size}"
	return 0
}

# 检查文件是否一直在被写， 每秒检测一次，共检测10次，直至发现与上次大小不一致为止。
# $1 : 日志名前缀 如：dhcp
# $2 : log change time，一般60
# $3 : app路径
# return:
# 0:success
# 1:failed
function is_file_growthing()
{
	last_file_size=0

	loop=11
	idx=0
	for ((idx;idx<loop;idx++))
	do
		cur_log_file=`get_log_file_name "${1}" "${2}"`
		cur_log_path=${3}/log/${cur_log_file}

		if [ ! -f ${cur_log_path} ]
		then
			echo "${cur_log_path} not exist!"
            sleep 1
			continue
		fi

		if [[ ${idx} -eq 0 ]]
		then
			last_file_size=`du -b ${cur_log_path} | awk -F ' ' '{print $1}'`
		else
			cur_file_size=`du -b ${cur_log_path} | awk -F ' ' '{print $1}'`
			if [[ ${cur_file_size} -ne ${last_file_size} ]]
			then
				return 0
			fi
		fi

		sleep 1
	done

	echo "${cur_log_path} is not growthing!"
	return 1
}

# 需要过滤掉的累加的日志条数
# $1 : filter_codes     e.g.  101,235,112
# $2 : log_file_path
# $3 : calc_line_num    限制日志前？行
function log_code_filter_count()
{
	filter_codes="$1"
	log_file_path="$2"
	calc_line_num="$3"

	filter_all_count=0

	if [ "${filter_codes}" == "" ]
	then
		echo "0"
		return 1
	fi

	if [ ! -f ${log_file_path} ]
	then
		echo "0"
		return 2
	fi

	filter_codes_arr=(${filter_codes//,/ })

	for filter_code in ${filter_codes_arr[@]}
	do
		if [[ ${filter_code} -eq 0 ]]
		then
			filter_key="ok|${filter_code}|1|"
		else
			filter_key="failed|${filter_code}|1|"
		fi

		if [ "${calc_line_num}" == "" ]
		then
			temp_count=`grep "${filter_key}" "${log_file_path}" | wc -l`
		else
			temp_count=`head -n ${calc_line_num} ${log_file_path} | grep "${filter_key}" | wc -l`
		fi
		filter_all_count=`expr ${temp_count} + ${filter_all_count}`
	done

	echo "${filter_all_count}"
}

# 增量统计日志文件中某个错误码数量（第一次时是整个日志文件全量统计）
# $1 : 日志文件名
# $2 : 锁定前？行
# $3 : 错误码
# $4 : 统计条件 如 " ok|100|"
# $5 : app路径
# $6 : 过滤条件（错误码） ','分割
# $7 : 是否需要更新缓存（0:不需要  1:需要）（默认：需要）
# $8 : 缓存文件后缀
# return: 
# 0:成功
# 1:日志文件不存在
function get_error_num_with_code()
{
	# 上次统计数据缓存在 dhcp_statistics 目录中
	mkdir -p dhcp_statistics

	# 日志文件名 如: dhcp.202111101300
	cur_log_file="${1}"
	cur_log_path=${5}/log/${cur_log_file}

	cur_log_prefix=`echo "${cur_log_file}" | cut -d "." -f 1`
	cur_time=`echo "${cur_log_file}" | cut -d "." -f 2`
	filter_codes="${6}"
	
	need_update_cache="$7"
	need_update_cache=${need_update_cache:=1}

	if [ ! -f ${cur_log_path} ]
	then
		echo "${cur_log_path} not exist!"
        sleep 5
        if [ ! -f ${cur_log_path} ]
        then
            echo "${cur_log_path} not exist!"
            return 1
        fi
	fi

	# 获取当前时间的错误统计量
	cur_result=`head -n "${2}" "${cur_log_path}" | grep -E "${4}" | wc -l`
	cur_filter_count=`log_code_filter_count "${filter_codes}" "${cur_log_path}" "${2}"`
	((cur_result=${cur_result}-${cur_filter_count}))

	# 记录上次该错误码数量的缓存文件
	cache_file_path=dhcp_statistics/${cur_log_prefix}_${3}${8}

	if [ ! -f ${cache_file_path} ]
	then
		# 第一次执行，没有缓存
		echo "${cur_result}"
	else
		last_stat=(`cat ${cache_file_path}`)
		last_time="${last_stat[0]}"
		last_result="${last_stat[1]}"

		if [ "${cur_time}" == "${last_time}" ]
		then
			# 与上次处理的是同一个日志文件
			((inc_result=${cur_result}-${last_result}))
			echo "${inc_result}"
		else
			# 更新日志文件
			last_file_path="${5}/log/${cur_log_prefix}.${last_time}"
			last_result_all=`grep -E "${4}" "${last_file_path}" | wc -l`
			last_filter_count=`log_code_filter_count "${filter_codes}" "${last_file_path}"`

			((inc_result=${last_result_all}-${last_filter_count}+${cur_result}-${last_result}))
			echo "${inc_result}"
		fi
	fi

	# 更新缓存
	if [[ ${need_update_cache} -eq 1 ]]
	then
		echo "${cur_time} ${cur_result}" > ${cache_file_path}
	fi

	return 0
}



########################  其他  ########################
# G g M m K k 转换为字节
# 1k = 1024 byte
# 1m = 1024*1024 byte
# 1g = 1024*1024*1024 byte
function convert_to_byte()
{
	if [[ ${1} == *G ]]
	then
		val=`echo "${1}" | cut -d "G" -f 1`
		((ret=${val}*1024*1024*1024))
	elif [[ ${1} == *g ]]
	then
		val=`echo "${1}" | cut -d "g" -f 1`
		((ret=${val}*1024*1024*1024))
	elif [[ ${1} == *M ]]
	then
		val=`echo "${1}" | cut -d "M" -f 1`
		((ret=${val}*1024*1024))
	elif [[ ${1} == *m ]]
	then
		val=`echo "${1}" | cut -d "m" -f 1`
		((ret=${val}*1024*1024))
	elif [[ ${1} == *K ]]
	then
		val=`echo "${1}" | cut -d "K" -f 1`
		((ret=${val}*1024))
	elif [[ ${1} == *k ]]
	then
		val=`echo "${1}" | cut -d "k" -f 1`
		((ret=${val}*1024))
	else
		ret="${1}"
	fi

	echo "${ret}"
}

# 获取节点所在区域名称
function get_node_area_name_sichuan()
{
	g_hostname=`hostname`
	if [[ ${g_hostname} == *_xq_* ]]
	then
		g_node_name="西区"
	elif [[ ${g_hostname} == *_nq_* ]]
	then
		g_node_name="南区"
	else
		g_node_name="整体"
	fi
	
	echo "${g_node_name}"
}

# a大于b 返回1， 小于返回0， 等于返回2
# 支持负数、小数、整数、正数
function compare()
{
	a=$1
	b=$2
	
	if [[ $a = -* ]]
	then
		if [[ $b = -* ]]
		then
			a_int=${a%.*}
			b_int=${b%.*}
			if [[ $(( $a_int > $b_int )) -eq 1 ]]
			then
				echo 1
				return
			else
				if [[ $(( $a_int == $b_int )) -eq 1 ]]
				then
					a_dec=${a#*.}
					b_dec=${b#*.}
					if [[ $(( $a_dec < $b_dec )) -eq 1 ]]
					then
						echo 1
						return
					else
						if [[ $(( $a_dec == $b_dec )) -eq 1 ]]
						then
							echo 2
							return
						else
							echo 0
							return
						fi
					fi
				else
					echo 0
					return
				fi
			fi
		else
			echo 0
			return
		fi
	else
		if [[ $b = -* ]]
		then
			echo 1
			return
		else
			a_int=${a%.*}
			b_int=${b%.*}
			if [[ $(( $a_int > $b_int )) -eq 1 ]]
			then
				echo 1
				return
			else
				if [[ $(( $a_int == $b_int )) -eq 1 ]]
				then
					a_dec=${a#*.}
					b_dec=${b#*.}
					if [[ $(( $a_dec > $b_dec )) -eq 1 ]]
					then
						echo 1
						return
					else
						if [[ $(( $a_dec == $b_dec )) -eq 1 ]]
						then
							echo 2
							return
						else
							echo 0
							return
						fi
					fi
				else
					echo 0
					return
				fi
			fi
		fi
	fi
	
}