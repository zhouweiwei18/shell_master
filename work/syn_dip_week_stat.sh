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
echo "$result"
}

queryMysqlDb()
{
sql=$1
result=`mysql $OPS_CHK_CONN -e "${sql}" -s -N`
echo -e "$result" > queryResult
echo "$result"
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
    sql="select sum(success_num)                                                       as success_num,
       sum(total_num)                                                                  as total_num,
       cast(sum(success_num) / sum(total_num) * 100 as decimal(36, 2))                 as stat_value,
       date_sub(current_date, interval dayofweek(current_date) + 5 day) as week_start_date,
       date_sub(curdate(), interval weekday(curdate()) + 1 day)                        as week_end_date
from syn_dip_dhcp_success_rate_stat
where stat_type = 0
  and date(str_to_date(START_TIME, '%Y-%m-%d')) >=
      date_sub(current_date, interval dayofweek(current_date) + 5 day)
  and date(str_to_date(START_TIME, '%Y-%m-%d')) < date_sub(curdate(), interval weekday(curdate()) + 1 day);"

result=`queryMysqlDb "$sql"`
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
        end=${arr[4]}" 23:59:59"
        insert_stmt="INSERT INTO syn_dip_dhcp_success_rate_stat (stat_type, start_time, end_time, success_num, total_num, stat_value, area_name)
        VALUES (1,'${start}', '${end}', ${arr[0]}, ${arr[1]}, ${arr[2]},'全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult
}

traffic()
{
    sql="select date_sub(current_date, interval dayofweek(current_date) + 5 day) as week_start_date,
       date_sub(curdate(), interval weekday(curdate()) + 1 day)                        as week_end_date,
       sum(stat_value)                                                                 as stat_value
from syn_dip_dhcp_traffic_stat
where stat_type = 0
  and date(str_to_date(START_TIME, '%Y-%m-%d')) >=
      date_sub(current_date, interval dayofweek(current_date) + 5 day)
  and date(str_to_date(START_TIME, '%Y-%m-%d')) < date_sub(curdate(), interval weekday(curdate()) + 1 day);"

result=`queryMysqlDb "$sql"`
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
        end=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_dhcp_traffic_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (1,'${start}', '${end}', ${arr[2]}, '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}

abnormalTerminal()
{
    sql="select date_sub(current_date, interval dayofweek(current_date) + 5 day) as week_start_date,
       date_sub(curdate(), interval weekday(curdate()) + 1 day)                        as week_end_date,
       sum(stat_value)                                                                 as stat_value,
       abnormal_type                                                                   as abnormal_type
from syn_dip_abnormal_terminal_stat
where stat_type = 0
  and date(str_to_date(START_TIME, '%Y-%m-%d')) >=
      date_sub(current_date, interval dayofweek(current_date) + 5 day)
  and date(str_to_date(START_TIME, '%Y-%m-%d')) < date_sub(curdate(), interval weekday(curdate()) + 1 day)
group by abnormal_type;"

result=`queryMysqlDb "$sql"`
#echo -e "$result" > tmp1
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
        end=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_abnormal_terminal_stat (stat_type, start_time, end_time, stat_value, abnormal_type, area_name) VALUES (1,'${start}', '${end}', ${arr[2]}, '${arr[3]}', '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}


activeTerminal()
{
    sql="select date_sub(current_date, interval dayofweek(current_date) + 5 day) as week_start_date,
       date_sub(curdate(), interval weekday(curdate()) + 1 day)                        as week_end_date,
       sum(stat_value)                                                                 as stat_value
from syn_dip_daily_active_terminal_stat
where stat_type = 0
  and date(str_to_date(START_TIME, '%Y-%m-%d')) >=
      date_sub(current_date, interval dayofweek(current_date) + 5 day)
  and date(str_to_date(START_TIME, '%Y-%m-%d')) < date_sub(curdate(), interval weekday(curdate()) + 1 day);"

result=`queryMysqlDb "$sql"`
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
        end=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_daily_active_terminal_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (1,'${start}', '${end}', ${arr[2]}, '全省');"
        echo ${insert_stmt}
        insertMysqlDb "$insert_stmt"
    fi
done < queryResult

}


onlineTerminal()
{
     sql="select date_sub(current_date, interval dayofweek(current_date) + 5 day) as week_start_date,
       date_sub(curdate(), interval weekday(curdate()) + 1 day)                        as week_end_date,
       sum(stat_value)                                                                 as stat_value
from syn_dip_dhcp_online_terminal_stat
where stat_type = 0
  and date(str_to_date(START_TIME, '%Y-%m-%d')) >=
      date_sub(current_date, interval dayofweek(current_date) + 5 day)
  and date(str_to_date(START_TIME, '%Y-%m-%d')) < date_sub(curdate(), interval weekday(curdate()) + 1 day);"

result=`queryMysqlDb "$sql"`
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
        end=${arr[1]}" 23:59:59"
        insert_stmt="insert into syn_dip_dhcp_online_terminal_stat (stat_type, start_time, end_time, stat_value, area_name) VALUES (1,'${start}', '${end}', ${arr[2]}, '全省');"
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