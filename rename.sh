#!/usr/bin/env bash

# https://imagemagick.org/
# https://0xacab.org/jvoisin/mat2

set -Eeuxo pipefail

for file in *.png *.jpg *.jpeg; do
	if [ -f "$file" ]; then
		tmpname="$RANDOM.png"
		if [[ $(file --mime-type -b $file) != "image/png" ]]; then
			magick convert "$file" "$tmpname"
			rm "$file"
		else
			mv "$file" "$tmpname"
		fi
		mat2 --inplace "$tmpname"
		newname=$(md5sum "$tmpname" | awk '{ print $1".png" }')
		mv "$tmpname" "$newname"
	fi
done
