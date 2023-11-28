#!/bin/bash

function get_endtime()
{
	cur_sec=$(date +%s)
	off_sec=$((${cur_sec}${1}))

	t_year=$(date -d @${off_sec} +%Y)
	t_month=$(date -d @${off_sec} +%m)
	t_day=$(date -d @${off_sec} +%d)
	t_hour=$(date -d @${off_sec} +%H)
	t_minute=$(date -d @${off_sec} +%_M)

	offset=$((${t_minute}%5))
	t_new_minute=$((${t_minute}-${offset}))

	if [[ ${#t_new_minute} -eq 1 ]]
	then
		t_new_minute=0${t_new_minute}
	fi

	echo "${t_year}-${t_month}-${t_day} ${t_hour}:${t_new_minute}:00"
}

get_endtime