#!/bin/bash

# 查询一个文件有多少行数

# 方式1: 该命令会输出文件的行数以及文件名。
# wc -l test.txt

# 方式2: 该命令会按行号显示文件内容，并输出最后一行的行号，即文件的行数。
#nl test.txt | tail -n 1

# 方式3: 该命令会统计文件中包含空行的行数。
#grep -c "" test.txt

# 方式4:该命令会输出文件的行数。
#sed -n '$=' test.txt

# 遍历文件

# -r 表示禁止反斜杠转义
#while IFS= read -r line;
#do
#  echo "$line"
#done < test.txt

# 替换一行中所有的空行
#echo "   asasdasd  " | sed 's/ //g'

# total: 459
#
# showType --->  illegalReason: 0
# node  ---> reportTargetUseCount： + 3
# device ---> reportTargetDesignCount: + 3
# region: -36
# interfaceName: -39
# monitorModule: -39
#
# 459-36-39-39+6 = 351
#
# monitorType: 39
# interfaceCode: 39
# monitorDesc: 39
# threshold1: 39
# threshold2: 39
# monitorRule: 39
# monitorValue: 0
# alarmLevel: 0

# 去掉无变动或不需要的字段 -> 变更为新增字段
#sed '/showType/d' console.txt > console1.txt
#sed '/node/d' console1.txt > console2.txt
#sed '/device/d' console2.txt > console3.txt
#sed '/region/d' console3.txt > console4.txt
#sed '/interfaceName/d' console4.txt > console5.txt
#sed '/monitorModule/d' console5.txt > console6.txt

# 替换原油字段为新的字段
#sed 's/monitorType/reportType/g;s/interfaceCode/reportTargetCode/g;s/monitorDesc/reportTargetDesc/g;s/threshold1/lowThreshold/g;s/threshold2/highThreshold/g;s/monitorRule/thresholdDesc/g;s/monitorValue/reportValue/g;s/alarmLevel/illegalStatus/g' console.txt > console1.txt
#sed '/monitorModule/d;/interfaceName/d;/region/d' console1.txt > console2.txt

#  \'展示类型\'\, \'showType\'\, \'0\'        ----->        \'异常原因\'\, \'illegalReason\'\, null
#  \'设备\'\, \'device\'\, \'\'              ----->        \'分母\'\, \'reportTargetDesignCount\'\, null
#  \'局点\'\, \'node\'\, \'成都\'             ----->        \'分子\'\, \'reportTargetUseCount\'\, null

# INSERT INTO ops_process_attr (serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (-1, -1, 227, '分母', 'reportTargetDesignCount', null, null, 10301);
# INSERT INTO ops_process_attr (serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (-1, -1, 227, '分子', 'reportTargetUseCount', null, null, 10301);
# INSERT INTO ops_process_attr (serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (-1, -1, 228, '分母', 'reportTargetDesignCount', null, null, 10301);
# INSERT INTO ops_process_attr (serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (-1, -1, 228, '分子', 'reportTargetUseCount', null, null, 10301);
# INSERT INTO ops_process_attr (serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (-1, -1, 229, '分母', 'reportTargetDesignCount', null, null, 10301);
# INSERT INTO ops_process_attr (serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (-1, -1, 229, '分子', 'reportTargetUseCount', null, null, 10301);



# '告警上报指标接口缩写' 'alarmTargetCode'
# '告警上报指标描述定义' 'alarmTargetDesc'
# '异常原因' 'alarmReason'


#sql1="INSERT INTO ops_process_attr (id, serv_id, template_id, proc_id, attr_name, attr_code, attr_value, description, status) VALUES (10000, -1, -1, "
#sql2=", null, null, 10301);"
#
## 定义一个数组
#array=("66",
#  "88",
#  "206",
#  "207",
#  "208",
#  "209",
#  "210",
#  "211",
#  "212",
#  "213",
#  "214",
#  "215",
#  "216",
#  "217",
#  "218",
#  "219",
#  "220",
#  "221",
#  "222",
#  "223",
#  "224",
#  "225",
#  "226",
#  "227",
#  "228",
#  "229",
#  "230",
#  "231",
#  "232",
#  "233",
#  "234",
#  "235",
#  "236",
#  "237",
#  "238",
#  "239",
#  "240",
#  "241",
#  "242",)
#
## 遍历数组并获取每个元素的值
#for item in "${array[@]}"
#do
#    echo "${sql1}"${item} \'异常原因\', \'illegalReason\'"${sql2}" >> console4.txt
#done


index=622
while read -r line;
do
  echo ${line} | sed "s/10000/${index}/g"  >> console5.txt;
  ((index++))
done < console4.txt


#sed 's/monitorType/reportType/g' console6.txt > console7.txt
#sed 's/interfaceCode/reportTargetCode/g' console7.txt > console8.txt
#sed 's/monitorDesc/reportTargetDesc/g' console8.txt > console9.txt
#sed 's/threshold1/lowThreshold/g' console9.txt > console10.txt
#sed 's/threshold2/highThreshold/g' console10.txt > console11.txt
#sed 's/monitorRule/thresholdDesc/g' console11.txt > console12.txt
#sed 's/monitorValue/reportValue/g' console12.txt > console13.txt
#sed 's/alarmLevel/illegalStatus/g' console13.txt > console14.txt

#sed -e '/alarmReason/d;/reportTargetDesignCount/d;/reportTargetUseCount/d;/illegalReason/d' console5.txt > console6.txt