#!/bin/bash

#  变量 NF 表示当前记录中的字段个数
#awk '{print NF}' ../cat.txt

# $NF 对应于当前记录的最后一个字段
#awk '{print $NF}' ../cat.txt

# -F 指定文本分隔符 (本身默认是以空格作为分隔符)------下面例子注意是 $NF
#awk -F'a' '{print $NF}' ../cat.txt

# $0	: 代表当前行(相当于匹配所有)
#awk -F: '{print $0, "---"}' /etc/passwd

# $n	: 代表第n列
#awk -F: '{print $1}' /etc/passwd

#默认空格为分隔符
#awk '{print $1}' /etc/passwd

# 以:为分隔符 统计文件内每行内的行数
#awk -F: '{print NF}' /etc/passwd

# 以:为分隔符 统计文件内每行内的最后一个字段
#awk -F: '{print $NF}' /etc/passwd

# NR : 用来记录行号
#awk -F: '{print NR}' /etc/passwd

# FS	: 指定文本内容分隔符(默认是空格)FS	: 指定文本内容分隔符(默认是空格)
#awk 'BEGIN{FS=":"}{print $NF, $1}' /etc/passwd

# OFS	: 指定打印分隔符(默认空格)
#awk -F: 'BEGIN{OFS=" >>> "}{print $NF, $1, $2, $3}' /etc/passwd

#print	: 打印
#printf	: 格式化打印
#	%s		: 字符串
#	%d		: 数字
#	-		: 左对齐
#	+		: 右对齐
#	15		: 至少占用15字符
#awk -F: 'BEGIN{OFS=" | "}{printf "|%+15s|%-15s|\n", $NF, $1}' /etc/passwd

# awk中匹配有root内容的行
#awk -F: '/root/{print $0}' /etc/passwd
# awk中匹配root开头的行
#awk -F '/^root/{print $0}' /etc/passwd

# 要求打印属组ID大于属主ID的行
#awk -F: '$4 > $3{print $0}' /etc/passwd

# 打印结尾包含bash
#awk -F: '$NF ~ /bash/{print $0}' /etc/passwd
# 打印结尾不包含bash
#awk -F '$NF !~ /bash/{print $0}' /etc/passwd

# 要求打印第三行
#awk -F: 'NR == 3{print $0}' /etc/passwd

#awk -F: '$3 + $4 > 2000 && $3 * $4 > 2000{print $0}' /etc/passwd
#awk -F: '$3 + $4 > 2000 || $3 * $4 > 2000{print $0}' /etc/passwd
#awk -F: '!($3 + $4 > 2000){print $0}' /etc/passwd
#awk -F: '$3 + $4 > 2000{print $0}' /etc/passwd
#awk -F: '$3 * $4 > 2000{print $0}' /etc/passwd
#awk -F: 'NR % 2 == 0{print $0}' /etc/passwd
#awk -F: 'NR % 2 == 1{print $0}' /etc/passwd
#awk -F: '{if($3>$4){print "大于"}else{print "小于或等于"}}' /etc/passwd
#awk -F: '{for(i=10;i>0;i--){print $0}}' /etc/passwd
#awk -F: '{i=1; while(i<10){print $0, i++}}' /etc/passwd
#awk -F: '{if(NR%5==0){print "----------"}print $0}' /etc/passwd
