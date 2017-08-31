#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

if [ "$(cat /etc/os-release | grep "^NAME" | cut -d\" -f2)" == "openSUSE Leap" ]
then
	exec_cmd sudo zypper addrepo -f http://packman.inode.at/suse/openSUSE_Leap_42.3/ packman
	LN

	exec_cmd sudo zypper addrepo -f http://opensuse-guide.org/repo/openSUSE_Leap_42.2/ dvd
	LN

	exec_cmd sudo zypper install ffmpeg lame gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-plugins-ugly-orig-addon gstreamer-plugins-libav libdvdcss2
	LN

	exec_cmd sudo zypper dup --from http://packman.inode.at/suse/openSUSE_Leap_42.2/
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
