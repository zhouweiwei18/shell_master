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

getParamValueArr()
{
row=$1
# reuslt="$(echo "${row}" | tr -s ${column_split})"
echo $row
}

synSuccessRate()
{

  sql="select START_TIME,
       add_months(trunc(sysdate, 'MM'), 0) - 1 as last_day_of_last_month,
       "\""object"\"",
       OK_NUM,
       ALL_NUM,
       SUCCESS_RATE
from DHCP_SUCCESS_RATE_STAT_MONTH
where "\""object"\"" = '全省'
  and OBJECT_TYPE_CODE = 7
  and SUCCESS_RATE_TYPE_CODE = 4
  and to_char(END_TIME, 'YYYY-MM') = to_char(sysdate, 'YYYY-MM');"

result=`queryOracleDb "$sql"`
# echo $result| while IFS= read -r row
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        integer_part="${arr[7]:0:-1}"
        start=${arr[0]}" 00:00:00"
        end=${arr[2]}" 23:59:59"
        insert_stmt="INSERT INTO syn_dip_dhcp_success_rate_stat (stat_type, start_time, end_time, success_num, total_num, stat_value, area_name)
        VALUES (2,'${start}', '${end}', ${arr[5]}, ${arr[6]}, ${integer_part},'${arr[4]}');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

traffic()
{
    sql="select START_TIME, add_months(trunc(sysdate, 'MM'), 0) - 1 as last_day_of_last_month, "\""object"\"", TRAFFIC
from DHCP_TRAFFIC_STAT_MONTH
where "\""object"\"" = '全省'
  and OBJECT_TYPE_CODE = 7
  and to_char(END_TIME, 'YYYY-MM') = to_char(sysdate, 'YYYY-MM');"

result=`queryOracleDb "$sql"`
# echo $result| while IFS= read -r row
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        start=${arr[0]}" 00:00:00"
        end=${arr[2]}" 23:59:59"
        insert_stmt="insert into syn_dip_dhcp_traffic_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (2,'${start}', '${end}', ${arr[5]}, '${arr[4]}');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}


abnormalTerminal()
{
    sql="select substr(START_TIME, 0, 7) MONTH_DATE, sum(ABNORMAL_BEHAVIOR_TYPE) MON_DISCOVER_OK_NUM, a.NAME,trunc(sysdate - interval '1' month, 'MONTH')                                   first_day,
       trunc(last_day(sysdate - interval '1' month), 'DD')                         as last_day
from ( select to_char(a.START_TIME, 'YYYY-MM-DD')   START_TIME,
              to_char(a.END_TIME - 1, 'YYYY-MM-DD') END_TIME,
              count(a.ABNORMAL_BEHAVIOR_TYPE)       ABNORMAL_BEHAVIOR_TYPE,
              b.NAME
       from ABNORMAL_TERMINAL_DAY a
                left join FAULT_DIAGNOSIS_MODEL_INFO b on a.ABNORMAL_BEHAVIOR_TYPE = b.KEYWORDS
       where AREA_NAME = '全省'
       group by b.NAME, a.END_TIME, a.START_TIME ) a
where a.START_TIME like to_char(sysdate - interval '1' month, 'YYYY-MM') || '%'
group by substr(START_TIME, 0, 7), a.NAME;"

result=`queryOracleDb "$sql"`
# echo $result| while IFS= read -r row
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        start=${arr[3]}" 00:00:00"
        end=${arr[5]}" 23:59:59"
        insert_stmt="insert into syn_dip_abnormal_terminal_stat (stat_type, start_time, end_time, stat_value, abnormal_type, area_name) VALUES (2,'${start}', '${end}', ${arr[1]}, '${arr[2]}', '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

activeTerminal()
{
    sql="select trunc(add_months(sysdate, -1), 'MM')    as first_day_of_last_month,
       add_months(trunc(sysdate, 'MM'), 0) - 1 as last_day_of_last_month,
       NUM
from MONTHLY_ACTIVE_USER_STAT
where AREA_NAME = '全省'
  and "\""DATE"\"" = to_char(sysdate - interval '1' month, 'YYYY-MM');"

result=`queryOracleDb "$sql"`
# echo $result| while IFS= read -r row
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        start=${arr[0]}" 00:00:00"
        end=${arr[2]}" 23:59:59"
        insert_stmt="insert into syn_dip_daily_active_terminal_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (2,'${start}', '${end}', ${arr[4]}, '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

onlineTerminal()
{
    sql="select substr(START_TIME, 0, 7)                               MONTH_DATE,
       sum(TRAFFIC)                                           MON_TRAFFIC,
       trunc(sysdate - interval '1' month, 'MONTH')           first_day,
       trunc(last_day(sysdate - interval '1' month), 'DD') as last_day
from ( select to_char(START_TIME, 'YYYY-MM-DD') START_TIME, to_char(END_TIME - 1, 'YYYY-MM-DD') END_TIME, TRAFFIC
       from DHCP_ONLINE_AREA
       where AREA_NO = '00' ) a
where a.START_TIME like to_char(sysdate - interval '1' month, 'YYYY-MM') || '%'
group by substr(START_TIME, 0, 7);"
result=`queryOracleDb "$sql"`
# echo $result| while IFS= read -r row
while read row
do
    # 在这里处理你的行数据
    echo ${row}
    if [[ "$row" != "" ]]; then
        rowResult=`getParamValueArr "$row"`
        # read -a arr <<< "${rowResult}"
        arr1=`echo "$rowResult"|awk -F "${column_split}" '{for(i=1; i<=NF; i++) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); print $i}}'`
        read -a arr <<< $arr1
        start=${arr[2]}" 00:00:00"
        end=${arr[3]}" 23:59:59"
        insert_stmt="insert into syn_dip_dhcp_online_terminal_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (2,'${start}', '${end}', ${arr[1]}, '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult
}

synSuccessRate
traffic
activeTerminal
abnormalTerminal
onlineTerminal