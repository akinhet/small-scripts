#!/usr/bin/env bash

# https://imagemagick.org/
# https://0xacab.org/jvoisin/mat2

set -Eeuo pipefail

for file in *.png *.jpg *.jpeg; do
	if [ -f "$file" ]; then
		newname=$(echo $RANDOM | sha256sum | awk '{print $1}')
		if [ $(file --mime-type -b image.png) != "image/png" ]; then
			magick convert "$file" "$newname.png"
			rm "$file"
		else
			mv "$file" $newname.png
		fi
		mat2 --inplace $newname.png
	fi
done
