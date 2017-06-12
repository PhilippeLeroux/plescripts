#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

exec_cmd sudo zypper addrepo -f http://packman.inode.at/suse/openSUSE_Tumbleweed/ packman
exec_cmd sudo zypper addrepo -f http://opensuse-guide.org/repo/openSUSE_Tumbleweed/ dvd

exec_cmd sudo zypper install k3b-codecs ffmpeg lame gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-plugins-ugly-orig-addon gstreamer-plugins-libav libdvdcss2

exec_cmd sudo zypper dup --from http://packman.inode.at/suse/openSUSE_Tumbleweed/
