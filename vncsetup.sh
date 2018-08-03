#!/bin/bash
#
# VNC Server setup script
# Helps users perform initial VNC Server setup on Linux systems
#
# Copyright (C) 2002-2016 RealVNC Ltd.
# RealVNC and VNC are trademarks of RealVNC Ltd and are protected by trademark
# registrations and/or pending trademark applications in the European Union,
# United States of America and other jurisdictions.
# Protected by UK patent 2481870; US patent 8760366; EU patent 2652951.

function systemcheck {
# check we are being run on a Linux system
OS=`uname -a | awk '{print $1}'`
if [ $OS != "Linux" ]; then echo "This script supports Linux only. Sorry!"; exit 1; fi
# basically is this a chkconfig system (RHEL/CentOS), a systemd system or an init system
# ordering is important as some systems such as CentOS support both systemd and chkconfig for
# compatibility purposes. Therefore we start with the oldest with systemd being final check
	if type initctl list > /dev/null 2>&1; then SYSTEMD=0; INITD=1; CHKCONFIG=0; fi
	if type chkconfig > /dev/null 2>&1; then SYSTEMD=0; INITD=0; CHKCONFIG=1; fi
	if type systemctl > /dev/null 2>&1; then SYSTEMD=1; INITD=0; CHKCONFIG=0; else
           SYSTEMD=0; INITD=0; CHKCONFIG=0; fi 

#	echo "type: systemd: $SYSTEMD chkconfig: $CHKCONFIG init: $INITD"
# on some systems, initctl doesn't exist but it is still init based. Handle this:       
	if [ $SYSTEMD == 0 ] && [ $INITD == 0 ] && [ $CHKCONFIG == 0 ] ; then INITD=1; fi
# we need to work out if we're running on Ubuntu 14.04 as we have a special case for that: 
LSBRELEASE=`lsb_release -r | awk '{print $2}'`
if [ $LSBRELEASE == "14.04" ]  && [ -d /usr/lib/systemd ]; then ubu1404; fi
}


function pressakey {
echo "Press enter to continue..."
read key
}

function ubu1404 {
clear
echo "Ubuntu 14.04 includes a systemd directory (/usr/lib/systemd) which confused the RealVNC Server installer."
echo "Please follow the instructions below to resolve this issue :"
echo "1. Uninstall VNC Server (apt purge realvnc-vnc-server)"
echo "2. Move the /usr/lib/systemd directory (mv /usr/lib/systemd /usr/lib/systemd.old)"
echo "3. reinstall VNC Server"
echo "Rerun this script ($0) once done."
exit
}


function menu {
echo -e "\n\nSelect an option:"
echo "1. License VNC Server and enable cloud connectivity"
echo "2. Set up VNC Server in Service Mode (to remote this computer's actual desktop and login screen)"
echo "3. Set up VNC Server in Virtual Mode daemon (Enterprise only, to create virtual desktops on demand)"
echo "4. Check/set up SELinux"
echo "x. Exit"
read mychoice
case $mychoice  in
1)licensing;; 
2)setupsvc;;
3)setupvirtd;;
4)setupselinux;;
x)exit 0;;
*) echo "select an option from 1 to 4"; menu ;;
esac
}

function setupselinux {
SELINUX=0
if type sestatus > /dev/null 2>&1; then SELINUX=1; fi
if [ "${SELINUX}" = "1" ]; then echo "SELinux present"; /usr/bin/vncinitconfig -register-SELinux; else echo "SELinux not available"; fi
pressakey
clear
menu
}


function licensing {
clear
echo -e "\nYou must have a RealVNC account and an Enterprise, Professional or Home subscription for VNC Connect."
echo -e "Visit https://www.realvnc.com to purchase a subscription or start a free trial.\n"
echo "1. Print current license status"
echo "2. Apply a license key (Enterprise subscription only)"
echo "3. Enable cloud connectivity (Enterprise subscription only)"
echo "4. Sign in to your RealVNC account to activate subscription (Enterprise, Professional or Home) - requires X11 GUI"
echo "5. Main menu"
read mychoice
case $mychoice  in
1) /usr/bin/vnclicense -list; pressakey; licensing;; 
2) echo "Enter license key (available from Deployment page of your RealVNC account for VNC Connect):"; read KEY; /usr/bin/vnclicense -add $KEY; pressakey; licensing;;
3) echo "Enter cloud connectivity token (available from Deployment page of your RealVNC account ):"; read CLOUDTOKEN; /usr/bin/vncserver-x11 -service -joinCloud $CLOUDTOKEN; pressakey; licensing;;
4) echo "Starting licensing wizard"; /usr/bin/vnclicensewiz; pressakey; licensing;;
5) menu ;;
*) echo "Select an option from 1 to 4"; menu ;;
esac
}

function checksvcmode {
	echo "Checking service mode is running..."
	SVCMODERUNNING=`ps -ef | grep vncserver-x11-serviced | grep -v grep | wc -l`
	echo $SVCMODERUNNING
	if [ $SVCMODERUNNING != "1" ]; then echo "Service mode server is NOT running and should be. Please check logs."; else echo "Service mode server is running correctly.";
	fi
	pressakey
}


function setupsvc {
echo "Setting up defaults for VNC Server in Service Mode"
/usr/bin/vncinitconfig -install-defaults
/usr/bin/vncinitconfig -pam
/usr/bin/vncinitconfig -service-daemon
clear
echo -e "Start VNC Server in Service Mode at system boot (y/n)?"
read svcbootenable
case $svcbootenable in
y) if [ $SYSTEMD == 1 ]; then systemctl enable vncserver-x11-serviced.service; fi
        if [ $CHKCONFIG == 1 ]; then chkconfig --add vncserver-x11-serviced; fi
        if [ $INITD == 1 ]; then update-rc.d vncserver-x11-serviced defaults; fi
	pressakey
;; 
*) echo "systemd config unchanged";;
esac
echo -e "Start VNC Server in Service Mode NOW (y/n)?"
read svcstartnow
case $svcstartnow in
[yY]|[yY][eE][sS]) if [ $SYSTEMD == 1 ]; then systemctl start vncserver-x11-serviced.service; fi
        if [ $INITD == 1 ]; then /etc/init.d/vncserver-x11-serviced start; checksvcmode; fi;;
*) echo "Not starting VNC Server in Service Mode at this time";;
esac
pressakey
menu
}

function setupvirtd {
echo "Setting up defaults for VNC Server in Virtual Mode daemon"
/usr/bin/vncinitconfig -install-defaults 
/usr/bin/vncinitconfig -pam 
/usr/bin/vncinitconfig -virtual-daemon
clear 
echo -e "Start VNC Server in Virtual Mode daemon at system boot (y/n)?"
read vmdbootenable
case $vmdbootenable in
[yY]|[yY][eE][sS]) if [ $SYSTEMD == 1 ]; then systemctl enable vncserver-virtuald.service; fi 
	if [ $CHKCONFIG == 1 ]; then chkconfig --add vncserver-virtuald; fi 
	if [ $INITD == 1 ]; then $update-rc.d vncserver-virtuald defaults; fi 
	;;
*) echo "startup config unchanged";;
esac
echo -e "Start VNC Server in Virtual Mode daemon NOW (y/n)?"
read vmdstartnow
case $vmdstartnow in
[yY]|[yY][eE][sS]) if [ $SYSTEMD == 1 ]; then systemctl start vncserver-virtuald.service; fi 
	if [ $INITD == 1 ]; then /etc/init.d/vncserver-virtuald start; echo "Connect to this computer on port 5999";fi;; 
*) echo "Not starting VNC Server in Virtual Mode daemon at this time";;
esac
clear
menu
}


if [ `id -u` -ne 0 ]; then echo "Please run as root (or using sudo)"; exit; fi
clear
systemcheck
echo "This script is designed to help you set up and license VNC Server on Linux systems."
echo "Please subsequently refer to https://www.realvnc.com/docs/index.html for documentation."
menu
