#!/bin/bash

ScreenName=VlcScreen
LogFile=TESTLOG
FileName=$1

if [[ ! -e ${FileName} ]]; then
	echo "The file ${FileName} does not exist"
	exit
fi

if [[ -e ${LogFile} ]]; then
	rm ${LogFile}
fi

function start_rvlc_screen {
	screen -d -m -S ${ScreenName} sh -c "rvlc $1 > ${LogFile}"
}

function pause_vlc {
	screen -S ${ScreenName} -p 0 -X stuff "pause^M"
}

function get_time {
	screen -S ${ScreenName} -p 0 -X stuff "get_time^M"
	#currentTimestamp=$(cat ${LogFile} | tail -n2 | head -n1 | sed -e 's/\r//' | sed -e 's/^(> )*//')
	currentTimestamp=$(cat ${LogFile} | tail -n2 | head -n1 | sed -e 's/\r//' | sed -e 's/^\(> \)*//')
	currentTimestamp=$(($currentTimestamp + 1))
	echo "${currentTimestamp}"
}

function seek {
	seek_value=$1
	if [ "${seek_value}" -lt "0" ]; then
		seek_value=0
	fi
	echo "Seeking ${seek_value}"
	screen -S ${ScreenName} -p 0 -X stuff "seek ${seek_value}^M"
}

function quit {
	screen -S ${ScreenName} -p 0 -X stuff "quit^M"
}

function kill_screens {
	screen -XS $(screen -ls | grep ${ScreenName} | sed -e 's/^\s*//' | sed -e 's/\..*//') quit
}

function exit_program {
	kill_screens
	stty sane
	exit
}

function cut_part_from_file {
	FROM=$1
	TO=$2

	FROM=$(($FROM - 1))
	TO=$(($TO - 1))

	LENGTH=$(($TO - $FROM))

	mkdir -p parts

	tmp="$RANDOM.mp3"
	while [[ -e $tmp ]]; do
		tmp="$RANDOM.mp3"
	done

	ffmpeg -ss $FROM -i $FileName -t $LENGTH -c copy $tmp

	
	exitstatus=1
	while [[ "$exitstatus" -ne "0" ]]; do
		play $tmp > /dev/null 2> /dev/null &
		TEXT=$(whiptail --inputbox "Was wurde gesagt?" 8 39 "" --title "Example Dialog" 3>&1 1>&2 2>&3)
		exitstatus=$?
	done


	mv $tmp "parts/${TEXT}.mp3"
}

trap exit_program SIGINT
trap exit_program 0

start_rvlc_screen $1

CUT_START=
CUT_END=

while true; do
	read -n1 -p "[q]uit, [p]ause, go [b]ack 10 sec, [B]ack 60s, [f]orward 10s, [F]orward 60s, [c]ut start/end, [k]ancel recording: " input
	echo ""

	if [ "$input" = "p" ]; then 
		pause_vlc
		get_time
	elif [ "$input" = "q" ]; then 
		exit_program

	elif [ "$input" = "f" ]; then 
		CURRENT_TIME=$(get_time)
		SEEK_TIME=$(($CURRENT_TIME + 10))
		seek $SEEK_TIME
	elif [ "$input" = "F" ]; then 
		CURRENT_TIME=$(get_time)
		SEEK_TIME=$(($CURRENT_TIME + 60))
		seek $SEEK_TIME

	elif [ "$input" = "b" ]; then 
		CURRENT_TIME=$(get_time)
		SEEK_TIME=$(($CURRENT_TIME - 10))
		seek $SEEK_TIME
	elif [ "$input" = "B" ]; then 
		CURRENT_TIME=$(get_time)
		SEEK_TIME=$(($CURRENT_TIME - 60))
		seek $SEEK_TIME

	elif [ "$input" = "k" ]; then 
		CUT_START=
		CUT_END=
	elif [ "$input" = "c" ]; then 
		if [[ ! -z ${CUT_START} ]]; then
			pause_vlc
			CUT_END=$(get_time)
			echo "CUT FROM $CUT_START TO $CUT_END"
			cut_part_from_file $CUT_START $CUT_END
			CUT_START=
			CUT_END=
			pause_vlc
		else
			CUT_START=$(get_time)
		fi
	fi
done

exit_program
