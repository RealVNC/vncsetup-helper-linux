#!/bin/bash
#
# VNC Server setup script
# Helps users perform initial VNC Server setup on Linux systems
#
# Copyright (C) 2002-2020 RealVNC Ltd.
# RealVNC and VNC are trademarks of RealVNC Ltd and are protected by trademark
# registrations and/or pending trademark applications in the European Union,
# United States of America and other jurisdictions.
# Protected by UK patent 2481870; US patent 8760366; EU patent 2652951.

function pressakey {
	while true; do
		printf "Press enter to continue..."
		read -r "key"
		case "$key" in
			*)
				break
			;;
		esac
	done
	return 0
}

function systemcheck {
	# check we are being run on a Linux system
	OS="$(uname -a | awk '{print $1}')"
	if [ "$OS" != "Linux" ]; then echo "This script supports Linux only. Sorry!"; exit 1; fi
	# basically is this a chkconfig system (RHEL/CentOS), a systemd system or an init system
	# ordering is important as some systems such as CentOS support both systemd and chkconfig for
	# compatibility purposes. Therefore we start with the oldest with systemd being final check
	if type initctl list > /dev/null 2>&1; then SYSTEMD=0; INITD=1; CHKCONFIG=0; fi
	if type chkconfig > /dev/null 2>&1; then SYSTEMD=0; INITD=0; CHKCONFIG=1; fi
	if type systemctl > /dev/null 2>&1; then SYSTEMD=1; INITD=0; CHKCONFIG=0;
	else SYSTEMD=0; INITD=0; CHKCONFIG=0; fi
	
	# on some systems, initctl doesn't exist but it is still init based. Handle this:
	if [ $SYSTEMD == 0 ] && [ $INITD == 0 ] && [ $CHKCONFIG == 0 ] ; then INITD=1; fi
	# we need to work out if we're running on Ubuntu 14.04 as we have a special case for that:
	LSBRELEASE=`lsb_release -r | awk '{print $2}'`
	if [ $LSBRELEASE == "14.04" ]  && [ -d /usr/lib/systemd ]; then ubu1404; fi
}

function ubu1404 {
	echo "Ubuntu 14.04 includes a systemd directory (/usr/lib/systemd) which confused the RealVNC Server installer."
	echo "Please follow the instructions below to resolve this issue:"
	echo "1. Uninstall VNC Server (sudo apt purge realvnc-vnc-server)"
	echo "2. Move the /usr/lib/systemd directory (sudo mv /usr/lib/systemd /usr/lib/systemd.old)"
	echo "3. Re-install VNC Server"
	echo "Rerun this script ($0) once done."
	exit
}

function disablewayland {
	gdmconf=""
	if [ -f "/etc/gdm3/custom.conf" ]; then gdmconf="/etc/gdm3/custom.conf"; fi
	if [ -f "/etc/gdm/custom.conf" ]; then gdmconf="/etc/gdm/custom.conf"; fi
	
	if [ -n "$gdmconf" ]; then
		if [ "$(grep -c "^#.*WaylandEnable=false" "$gdmconf")" -gt 0 ]; then
			printf "\\nWould you like to disable Wayland? This is required to view the login screen. (y/n)\\n"
			read "waylanddisable"
			case "$waylanddisable" in
				[yY]|[yY][eE][sS])
					cp -a "$gdmconf" "$gdmconf.bak"
					sed -i 's/^#.*WaylandEnable=.*/WaylandEnable=false/' "$gdmconf"
					printf "\\nWayland disabled. Please reboot computer for this change to take effect.\\n\\n"
				;;
				*) printf "\\nWayland config unchanged\\n\\n";;
			esac
		fi
	fi
}

function menu {
	printf "\\nThe following options are available:\\n\\n"
	echo "1. License VNC Server and enable cloud connectivity"
	echo "2. Set up VNC Server in Service Mode (to remote this computer's actual desktop and login screen)"
	echo "3. Set up VNC Server in Virtual Mode daemon (Enterprise only, to create virtual desktops on demand)"
	echo "4. Check/set up SELinux for compatibility with VNC Server"
	printf "\\nx. Exit\\n"
	printf "\\nChoose an option:    "
	read "mychoice"
	case "$mychoice" in
	1)licensing;;
	2)setupsvc;;
	3)setupvirtd;;
	4)setupselinux;;
	x)clear; exit 0;;
	*) echo "select an option from 1 to 4"; clear; menu ;;
	esac
}

function setupselinux {
	echo ""
	SELINUX=0
	if type sestatus > /dev/null 2>&1; then SELINUX=1; fi
	if [ "$SELINUX" = "1" ]; then echo "SELinux present"; /usr/bin/vncinitconfig -register-SELinux; else echo "SELinux not available"; fi
	echo ""
	pressakey
	clear
	menu
}

function setupfirewall {
	svrmode="$1"
	echo ""
	
	printf "\\nWould you like to add an exception to the firewall? (y/n)\\n"
	read "firewallexception"
	case "$firewallexception" in
			[yY]|[yY][eE][sS])
			if type firewall-cmd > /dev/null 2>&1; then
				if [ "$svrmode" = "svc" ]; then
					firewall-cmd --zone=public --permanent --add-service=vncserver-x11-serviced
					firewall-cmd --reload
				elif [ "$svrmode" = "virtd" ]; then
					firewall-cmd --zone=public --permanent --add-service=vncserver-virtuald
					firewall-cmd --reload
				fi
			elif type ufw > /dev/null 2>&1; then
				if [ "$svrmode" = "svc" ]; then
					ufw allow 5900
				elif [ "$svrmode" = "virtd" ]; then
					ufw allow 5999
				fi
			fi
	;;
	*) printf "\\nFirewall unchanged\\n\\n";;
	esac
	echo ""
	pressakey
	clear
	menu
}

function licensing {
	clear
	printf "\\nYou must have a RealVNC account and an Enterprise, Professional or Home subscription for VNC Connect."
	printf "\\nVisit https://www.realvnc.com to purchase a subscription or start a free trial.\\n"
	printf "\\nThe following options are available:\\n\\n"
	echo "1. Print current license status"
	echo "2. Sign in to your RealVNC account to activate subscription (Enterprise, Professional or Home) - requires X11 GUI"
	echo "3. Apply a license key (Enterprise only)"
	echo "4. Enable cloud connectivity using a cloud token (Enterprise only)"
	printf "\\nx. Main menu\\n"
	printf "\\nChoose an option:    "
	read "mychoice"
	case "$mychoice" in
	1) echo ""; /usr/bin/vnclicense -list; echo ""; pressakey; licensing;;
	2) printf "\\nStarting licensing wizard\\n"; /usr/bin/vnclicensewiz; echo ""; pressakey; licensing;;
	3) printf "\\nEnter license key (available from Deployment page of your RealVNC account for VNC Connect):\\n"; read "KEY"; /usr/bin/vnclicense -add "$KEY"; echo ""; pressakey; licensing;;
	4) printf "\\nEnter cloud connectivity token (available from Deployment page of your RealVNC account):\\n"; read "CLOUDTOKEN"; /usr/bin/vncserver-x11 -service -joinCloud "$CLOUDTOKEN"; echo ""; pressakey; licensing;;
	e) menu ;;
	*) echo "Select an option from 1 to 4"; clear; menu;;
	esac
}

function checksvcmode {
	printf "\\nChecking service mode is running...\\n"
	SVCMODERUNNING="$(ps -ef | grep vncserver-x11-serviced | grep -v grep | wc -l)"
	if [ "$SVCMODERUNNING" -ne 1 ]; then printf "\\nService mode server is NOT running and should be. Please check logs.\\n"; else printf "\\nService mode server is running correctly.\\n";
	fi
	printf "\\nConnect to this computer via the cloud, or on port 5900\\n\\n";
}

function checkvmdmode {
	printf "\\nChecking virtual mode daemon is running...\\n"
	VMDMODERUNNING="$(ps -ef | grep vncserver-virtuald | grep -v grep | wc -l)"
	if [ "$VMDMODERUNNING" -ne 1 ]; then printf "\\nVirtual mode daemon is NOT running and should be. Please check logs.\\n"; else printf "\\nVirtual mode daemon is running correctly.\\n";
	fi
	printf "\\nConnect to this computer on port 5999\\n\\n";
}

function setupsvc {
	printf "\\nSetting up defaults for VNC Server in Service Mode\\n"
	/usr/bin/vncinitconfig -install-defaults >/dev/null 2>&1
	/usr/bin/vncinitconfig -pam >/dev/null 2>&1
	/usr/bin/vncinitconfig -service-daemon >/dev/null 2>&1
	printf "\\nStart VNC Server in Service Mode at system boot (y/n)?\\n"
	read "svcbootenable"
	case "$svcbootenable" in
		[yY]|[yY][eE][sS])
			if [ "$SYSTEMD" -eq 1 ]; then systemctl enable vncserver-x11-serviced.service >/dev/null 2>&1; fi
			if [ "$CHKCONFIG" -eq 1 ]; then chkconfig --add vncserver-x11-serviced >/dev/null 2>&1; fi
			if [ "$INITD" -eq 1 ]; then update-rc.d vncserver-x11-serviced defaults >/dev/null 2>&1; fi
		;;
		*) printf "\\nsystemd config unchanged";;
	esac
	printf "\\nStart VNC Server in Service Mode NOW (y/n)?\\n"
	read "svcstartnow"
	case "$svcstartnow" in
		[yY]|[yY][eE][sS])
			if [ "$SYSTEMD" -eq 1 ]; then systemctl start vncserver-x11-serviced.service >/dev/null 2>&1; checksvcmode; fi
			if [ "$INITD" -eq 1 ]; then /etc/init.d/vncserver-x11-serviced start >/dev/null 2>&1; checksvcmode; fi
		;;
		*) printf "\\nNot starting VNC Server in Service Mode at this time\\n";;
	esac
	setupfirewall "svc"
	disablewayland
	pressakey
	clear
	menu
}

function setupvirtd {
	printf "\\nSetting up defaults for VNC Server in Virtual Mode daemon\\n"
	/usr/bin/vncinitconfig -install-defaults >/dev/null 2>&1
	/usr/bin/vncinitconfig -pam >/dev/null 2>&1
	/usr/bin/vncinitconfig -virtual-daemon >/dev/null 2>&1
	printf "\\nStart VNC Server in Virtual Mode daemon at system boot (y/n)?\\n"
	read "vmdbootenable"
	case "$vmdbootenable" in
		[yY]|[yY][eE][sS])
			if [ "$SYSTEMD" -eq 1 ]; then systemctl enable vncserver-virtuald.service >/dev/null 2>&1; fi
			if [ "$CHKCONFIG" -eq 1 ]; then chkconfig --add vncserver-virtuald >/dev/null 2>&1; fi
			if [ "$INITD" -eq 1 ]; then update-rc.d vncserver-virtuald defaults >/dev/null 2>&1; fi
		;;
		*) printf "\\nStartup config unchanged";;
	esac
	printf "\\nStart VNC Server in Virtual Mode daemon NOW (y/n)?\\n"
	read "vmdstartnow"
	case "$vmdstartnow" in
		[yY]|[yY][eE][sS])
			if [ "$SYSTEMD" -eq 1 ]; then systemctl start vncserver-virtuald.service >/dev/null 2>&1; checkvmdmode; fi
			if [ "$INITD" -eq 1 ]; then /etc/init.d/vncserver-virtuald start >/dev/null 2>&1; checkvmdmode; fi
		;;
		*) printf "\\nNot starting VNC Server in Virtual Mode daemon at this time\\n\\n";;
	esac
	setupfirewall "virtd"
	pressakey
	clear
	menu
}

if [ "$(id -u)" -ne 0 ]; then echo "Please run as root (or using sudo)"; exit; fi
clear
systemcheck
echo "This script is designed to help you set up and license VNC Server on Linux systems."
echo "Please subsequently refer to https://help.realvnc.com for documentation."
menu
