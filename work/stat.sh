#!/bin/bash

project_path=$(
  cd $(dirname $0)
  pwd
)
cd ~

# 定义bash_profile文件路径
bash_profile_path=~/.bash_profile

# 判断bash_profile文件是否存在
if [[ -e "$bash_profile_path" ]]; then
  # 如果存在，则执行source命令
  source "$bash_profile_path"
fi

cd $project_path

# export TZ=Asia/Shanghai
#export NLS_LANG='SIMPLIFIED CHINESE_CHINA.AL32UTF8'
export NLS_LANG='SIMPLIFIED CHINESE_CHINA.ZHS16GBK'

# DIP数据库环境信息
DIP_ORACLE_USER="AIDIP_DIP_194P2"
DIP_ORACLE_PASS="aisddi123"
DIP_ORACLE_HOST="10.21.41.162"
DIP_ORACLE_PORT="1521"
DIP_ORACLE_SID="LCDMP2"

# 巡检数据库环境配置
OPS_CHK_DB_UID=dhcp4_dev
OPS_CHK_DB_PWD=DHCP_product666
OPS_CHK_DB_IP=10.21.17.145
OPS_CHK_DB_PORT=23306
OPS_CHK_DB_NAME=PATROL_OPS

syn_log_file=$project_path"/syn_dip_data.log"

# 构建连接字符串
export DIP_CONN="${DIP_ORACLE_USER}/${DIP_ORACLE_PASS}@${DIP_ORACLE_HOST}:${DIP_ORACLE_PORT}/${DIP_ORACLE_SID}"
export OPS_CHK_CONN="-h${OPS_CHK_DB_IP} -P${OPS_CHK_DB_PORT} -u${OPS_CHK_DB_UID} -p${OPS_CHK_DB_PWD} ${OPS_CHK_DB_NAME}"

# 获取今天是一周的第几天（1代表星期一）和一个月的第几天
DAY_OF_WEEK=$(date '+%u')
DAY_OF_MONTH=$(date '+%d')

echo $(date)' start syn dip data' >>${syn_log_file}

# 不论何时，每天都会执行的daily script
echo "-----------------------开始日报表数据同步-----------------------"
echo $(date)' start syn daily data' >>${syn_log_file}

./syn_dip_day_stat.sh

echo $(date)' end syn daily data' >>${syn_log_file}

echo "$DAY_OF_WEEK"
echo "$DAY_OF_MONTH"
echo "$(date)"

if [ "$DAY_OF_WEEK" -eq 1 ]; then
  echo "-----------------------开始周报表数据同步-----------------------"
  echo $(date)' start syn weekly data' >>${syn_log_file}
  ./syn_dip_week_stat.sh
  echo $(date)' end syn weekly data' >>${syn_log_file}
fi

# 如果今天是每月的第一天，则运行monthly script
if [ "$DAY_OF_MONTH" -eq 01 ]; then
  echo "-----------------------开始月报表数据同步-----------------------"
  echo $(date)' start syn monthly data' >>${syn_log_file}
  ./syn_dip_month_stat.sh
  echo $(date)' end syn monthly data' >>${syn_log_file}
fi

unset NLS_LANG
# unset TZ
unset DIP_CONN
unset OPS_CHK_CONN

echo $(date)' end syn dip data' >>${syn_log_file}
