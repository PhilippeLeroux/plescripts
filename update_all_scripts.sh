#/bin/sh

find ~/plescripts/ -name "*.sh" |\
		xargs sed -i "s!plelib_banner!plelib_banner!g"

