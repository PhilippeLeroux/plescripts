#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

if [ "$(cat /etc/os-release | grep "^NAME" | cut -d\" -f2)" == "openSUSE Leap" ]
then
	typeset	version=$(cat /etc/os-release | grep "^VERSION=" | cut -d\" -f2)
	exec_cmd sudo zypper addrepo -f http://packman.inode.at/suse/openSUSE_Leap_$version/ packman
	LN

	exec_cmd sudo zypper install ffmpeg lame gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-plugins-ugly-orig-addon gstreamer-plugins-libav libdvdcss2
	LN

	exec_cmd sudo zypper dup --from http://packman.inode.at/suse/openSUSE_Leap_$version/
	LN
else
	exec_cmd sudo zypper addrepo -f http://packman.inode.at/suse/openSUSE_Tumbleweed/ packman
	LN

	exec_cmd sudo zypper addrepo -f http://opensuse-guide.org/repo/openSUSE_Tumbleweed/ dvd
	LN

	exec_cmd sudo zypper install k3b-codecs ffmpeg lame gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-plugins-ugly-orig-addon gstreamer-plugins-libav libdvdcss2
	LN

	exec_cmd sudo zypper dup --from http://packman.inode.at/suse/openSUSE_Tumbleweed/
	LN
fi

info "Programmes à stopper :"
exec_cmd sudo zypper ps -s
LN
