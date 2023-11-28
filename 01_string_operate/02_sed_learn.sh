#!/bin/bash

# sed命令学习
# 命令格式：sed [-hnV][-e<script>][-f<script文件>][文本文件]

# -e<script>或--expression=<script> 以选项中指定的script来处理输入的文本文件。
# -f<script文件>或--file=<script文件> 以选项中指定的script文件来处理输入的文本文件。
# -h或--help 显示帮助。
# -n或--quiet或--silent 仅显示script处理后的结果。
# -V或--version 显示版本信息。

# a ：新增， a 的后面可以接字串，而这些字串会在新的一行出现(目前的下一行)～
# c ：取代， c 的后面可以接字串，这些字串可以取代 n1,n2 之间的行！
# d ：删除，因为是删除啊，所以 d 后面通常不接任何东东；
# i ：插入， i 的后面可以接字串，而这些字串会在新的一行出现(目前的上一行)；
# p ：打印，亦即将某个选择的数据印出。通常 p 会与参数 sed -n 一起运行～
# s ：取代，可以直接进行取代的工作哩！通常这个 s 的动作可以搭配正则表达式！例如 1,20s/old/new/g 就是啦！

# 在文本中指定行新插入一行文本
#sed -e 4a\newline test.txt

# 将 test.txt 的内容列出并且列印行号，同时，请将第 2~5 行删除！
# 此处的-e可以省略
# nl test.txt
#nl test.txt | sed -e '2,5d'
#nl test.txt | sed -e '2d'
#nl test.txt | sed -e '3,$d'
#nl test.txt | sed -e '2a drink tea'
#nl test.txt | sed -e '2i drink tea'

#nl test.txt | sed -e '2a drink tea...\
#drink beer?'

#nl test.txt | sed -e '2,5c No 2-5 number'

#nl test.txt | sed -n '5,7p'

# 查找包含oo的行，并打印
#nl test.txt | sed -n '/oo/p'

# 删除所有包含 oo 的行，其他行输出
#nl test.txt | sed -e '/oo/d'

# 搜索找到 oo 对应的行，执行后面花括号中的一组命令，每个命令之间用分号分隔，这里把 oo 替换为 kk，再输出这行
#nl test.txt | sed -n '/oo/{s/oo/kk/;p;q}'

# 将文件中每行第一次出现的 oo 用字符串 kk 替换，然后将该文件内容输出到标准输出
# sed -e 's/oo/kk/' test.txt

# g 标识符表示全局查找替换，使 sed 对文件中所有符合的字符串都被替换，修改后内容会到标准输出，不会修改原文件
#sed -e 's/oo/kk/g' test.txt

# 选项 i 使 sed 修改文件
#sed -i 's/oo/jj/g' test.txt

# 批量操作当前目录下以 test 开头的文件
#sed -i 's/oo/kk/' ./test*

#echo "eth0 Link encap:Ethernet HWaddr 00:90:CC:A6:34:84
#inet addr:192.168.1.100 Bcast:192.168.1.255 Mask:255.255.255.0
#inet6 addr: fe80::290:ccff:fea6:3484/64 Scope:Link
#UP BROADCAST RUNNING MULTICAST MTU:1500 Metric:1" | grep 'inet addr' | sed 's/^.*addr://g' | sed 's/Bcast.*$//g'

#nl test.txt | sed -e '4,$d' -e 's/HELLO/HHHHHH/'

#sed -i 's/\.$/\!/g' test.txt

#sed -i '$a # This is a test'  test.txt
#cat regular_express.txt