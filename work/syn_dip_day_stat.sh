#!/bin/bash

column_split='#'

queryOracleDb()
{
sql=$1
result=`sqlplus -s $DIP_CONN <<EOF
set heading off feedback off verify off TRIMSPOOL ON trimout on;
set linesize 3000;
set pages 0;
alter session set NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
set COLSEP ${column_split};
${sql}
exit;
EOF`
echo -e "$result" > queryResult
echo $result
}

insertMysqlDb()
{
sql=$1
echo $sql| mysql $OPS_CHK_CONN
}

queryMysqlDb()
{
sql=$1
result=`mysql $OPS_CHK_CONN -e "${sql}" -s -N`
echo -e "$result" > queryResult
echo "$result"
}

getParamValueArr()
{
row=$1
# reuslt="$(echo "${row}" | tr -s ${column_split})"
echo $row
}

synSuccessRate()
{
    sql="select to_char(START_TIME, 'YYYY-MM-DD')  START_TIME,to_char(END_TIME - 1, 'YYYY-MM-DD') END_TIME
            ,OK_NUM,ALL_NUM,SUCCESS_RATE,"\""object"\"" as AREA_NAME
         from DHCP_SUCCESS_RATE_STAT_DAY
        where success_rate_type_code = 4
          and object_type_code = 7 and "\""object"\""='全省' and END_TIME = trunc(sysdate, 'DD');"

result=`queryOracleDb "$sql"`
#echo $result| while IFS= read -r row

while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        integer_part="${arr[4]:0:-1}"
        arr[0]=${arr[0]}" 00:00:00"
        arr[1]=${arr[1]}" 23:59:59"
        insert_stmt="INSERT INTO syn_dip_dhcp_success_rate_stat (stat_type, start_time, end_time, success_num, total_num, stat_value, area_name)
        VALUES (0,'${arr[0]}', '${arr[1]}', ${arr[2]}, ${arr[3]}, ${integer_part},'${arr[5]}');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

traffic()
{
    sql="select to_char(START_TIME, 'YYYY-MM-DD')   START_TIME,
       to_char(END_TIME - 1, 'YYYY-MM-DD') END_TIME,
       TRAFFIC                             SYS_TRAFFIC,
       "\""object"\""
    from DHCP_TRAFFIC_STAT_DAY
    where END_TIME = trunc(sysdate, 'DD')
      and "\""object"\"" = '全省';"

result=`queryOracleDb "$sql"`
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        arr[0]=${arr[0]}" 00:00:00"
        arr[1]=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_dhcp_traffic_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (0,'${arr[0]}', '${arr[1]}', ${arr[2]}, '${arr[3]}');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

abnormalTerminal()
{
    sql="select to_char(a.START_TIME, 'YYYY-MM-DD')   START_TIME,
       to_char(a.END_TIME - 1, 'YYYY-MM-DD') END_TIME,
       count(a.ABNORMAL_BEHAVIOR_TYPE)       ABNORMAL_BEHAVIOR_TYPE,
       b.NAME
    from ABNORMAL_TERMINAL_DAY a
             left join FAULT_DIAGNOSIS_MODEL_INFO b on a.ABNORMAL_BEHAVIOR_TYPE = b.KEYWORDS
    where END_TIME = trunc(sysdate, 'DD')
      and AREA_NAME = '全省'
    group by b.NAME, a.END_TIME, a.START_TIME;"

result=`queryOracleDb "$sql"`
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        arr[0]=${arr[0]}" 00:00:00"
        arr[1]=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_abnormal_terminal_stat (stat_type, start_time, end_time, stat_value, abnormal_type, area_name) VALUES (0,'${arr[0]}', '${arr[1]}', ${arr[2]}, '${arr[3]}', '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}


activeTerminal()
{
    sql="select "\""DATE"\"" STAT_TIME, "\""DATE"\"" END_TIME, NUM ACTIVE_MAC_NUM
    from DAILY_ACTIVE_USER_STAT
    where area_name = '全省'
      and "\""DATE"\"" = to_char(sysdate - 1, 'YYYY-MM-DD');"

result=`queryOracleDb "$sql"`
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        arr[0]=${arr[0]}" 00:00:00"
        arr[1]=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_daily_active_terminal_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (0,'${arr[0]}', '${arr[1]}', ${arr[2]}, '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

onlineTerminal()
{
     sql="select to_char(sysdate - 1, 'YYYY-MM-DD') start_time, to_char(sysdate, 'YYYY-MM-DD') end_time, sum(TRAFFIC)
    from DHCP_ONLINE_AREA
    where AREA_NO = '00'
      and END_TIME between trunc(sysdate - 1, 'DD') and trunc(sysdate, 'DD')
    group by AREA_NAME;"

result=`queryOracleDb "$sql"`
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        arr[0]=${arr[0]}" 00:00:00"
        arr[1]=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_dhcp_online_terminal_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (0,'${arr[0]}', '${arr[1]}', ${arr[2]}, '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult
}

cleanExpiredData() {
  table_name=$1

  sql="select id
from $table_name
where (stat_type = 0 and start_time < date_sub(curdate(), interval 1 month))
   or (stat_type = 1 and start_time < date_sub(
        date_sub(date_sub(curdate(), interval if(dayofweek(curdate()) = 1, 6, dayofweek(curdate()) - 2) day), interval 3
                 month), interval
        weekday(date_sub(date_sub(curdate(), interval if(dayofweek(curdate()) = 1, 6, dayofweek(curdate()) - 2) day),
                         interval 3 month)) day))
   or (stat_type = 2 and start_time < date_sub(date_sub(curdate(), interval day(curdate()) - 1 day), interval 6 month));"

  queryMysqlDb "$sql"

  # 定义数组
  readarray -t expired_ids < queryResult

  if [ ${#expired_ids[@]} -eq 0 ]; then
    echo "${table_name} no expired data"
  else
      for id in "${expired_ids[@]}"; do
          if [[ -n "$id" ]]; then
            echo "the expired id: $id"
            deleteSql="delete from $table_name where id in ($id)"
            echo $deleteSql
            queryMysqlDb "$deleteSql"
          fi
      done
  fi

  rm queryResult
}

synSuccessRate
traffic
activeTerminal
abnormalTerminal
onlineTerminal

rm queryResult

cleanExpiredData "syn_dip_abnormal_terminal_stat"
cleanExpiredData "syn_dip_daily_active_terminal_stat"
cleanExpiredData "syn_dip_dhcp_online_terminal_stat"
cleanExpiredData "syn_dip_dhcp_success_rate_stat"
cleanExpiredData "syn_dip_dhcp_traffic_stat"