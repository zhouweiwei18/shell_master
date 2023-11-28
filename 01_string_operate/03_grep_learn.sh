#!/bin/bash

# grep [options] pattern [files]
# 常用选项：：
#
# -i：忽略大小写进行匹配。
# -v：反向查找，只打印不匹配的行。
# -n：显示匹配行的行号。
# -r：递归查找子目录中的文件。
# -l：只打印匹配的文件名。
# -c：只打印匹配的行数。

# 在标准输入中查找字符串 "world"，并只打印匹配的行数
#grep -c world test.txt

# 查找前缀有"learn.sh"的文件包含"awk"字符串的文件
#grep awk *learn.sh

# 查找指定目录/etc/acpi 及其子目录（如果存在子目录的话）下所有文件中包含字符串"grep"的文件，并打印出该字符串所在行的内容
#grep -r grep /Users/weiweizhou/Documents/project/github_repository/shell_master/

# 反向查询 查找前缀有"learn.sh"的文件不包含"awk"字符串的文件
#grep -v awk *learn.sh




