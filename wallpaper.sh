#!/bin/bash
wallpaper=$(/sbin/ls -1 /home/akinhet/Pictures/Wallpapers/ | shuf -n1 | sed -e 's/^/\/home\/akinhet\/Pictures\/Wallpapers\//')
nitrogen --set-zoom-fill --head=0 "$wallpaper"
nitrogen --set-zoom-fill --head=1 "$wallpaper"
