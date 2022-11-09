#!/bin/bash
#
# Issue an alarm using at and aplay
# Usage:
# 	AL [@] delay [message timeout]]
#	where @ denotes absolute time
#	If not absolute time:
#	   delay is in minutes
#       timeout is in seconds
#
# Defaults to 15 minutes delay: "ALARM"
# Message defaults to "ALARM"

PREFIX="now + "
SUFFIX=" minutes"
DELAY=15
MSG='ALARM'
TO=20
SOUND="/path/to/sound"

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
  echo "AL - Issue an alarm"
  echo "     AL [delay (in minutes) [message [timeout (in seconds)]]]"
  echo "   or"
  echo "     AL @ time [message [timeout (in seconds)]]"
  echo "   defaults: delay=15 message=\"ALARM\" timeout=20"
  exit
fi

if [ "$1" == "@" ]
then
  PREFIX=""
  SUFFIX=""
  shift
fi

if [ "$1"x != "x" ]
then
  DELAY=$1
  if [ "$2"x != "x" ]
  then
    MSG="$2"
    if [ "$3"x != "x" ]
    then
      TO=$3
    fi
  fi
fi

echo "notify-send $MSG '$TO s';aplay '$SOUND' -d $TO;" | at $PREFIX$DELAY$SUFFIX

if [ "$PREFIX"x != "x" ]
then
    echo "Alarm \""$MSG"\" in $PREFIX$DELAY$SUFFIX using timeout $TO seconds"
else
    echo "Alarm \""$MSG"\" at $DELAY using timeout $TO seconds"
fi
