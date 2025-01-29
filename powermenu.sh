#!/bin/bash

choice=$(echo -e "Shutdown\nReboot\nLock\nSuspend\nLogout\nQuit" | dmenu -g 1 -i -p "Powermenu:")

case $choice in
	"Shutdown")
		if [[ "$(echo -e "No\nYes" | dmenu -i -p "${choice}?")" == "Yes" ]]; then
			systemctl poweroff
		fi
		;;
	"Reboot")
		if [[ "$(echo -e "No\nYes" | dmenu -i -p "${choice}?")" == "Yes" ]]; then
			systemctl reboot
		fi
		;;
	"Lock")
		slock &
		;;
	"Suspend")
		if [[ "$(echo -e "No\nYes" | dmenu -i -p "${choice}?")" == "Yes" ]]; then
			systemctl suspend
		fi
		;;
	"Logout")
		if [[ "$(echo -e "No\nYes" | dmenu -i -p "${choice}?")" == "Yes" ]]; then
			loginctl kill-user 1000
		fi
		;;
	"Quit")
		exit 0
		;;
	*)
		exit 0
		;;
esac
