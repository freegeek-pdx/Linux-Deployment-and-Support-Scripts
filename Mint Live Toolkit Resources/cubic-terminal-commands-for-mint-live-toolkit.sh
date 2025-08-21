#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# MIT License
#
# Copyright (c) 2022 Free Geek
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

if [[ "$(hostname)" == 'cubic' && -f '/usr/bin/setup-mint-live-toolkit' ]]; then
	echo -e '\n\nINSTALLING SYSTEM UPDATES\n'

	mintupdate-cli upgrade -ry || exit 1
	mintupdate-cli upgrade -ry || exit 1
	mintupdate-cli upgrade -ry || exit 1



	echo -e '\n\nINSTALLING BASE TOOLKIT PACKAGES\n'
	# From: https://github.com/debian-live/live-images/blob/b42c6f1cb0a0ee6ec81a0d933f2072605396a712/images/rescue/config/package-lists/rescue.list.chroot
	# REPLACED: grub WITH grub2-common AND grub-efi-amd64
	# REPLACED: iproute AND iproute-doc WITH iproute2 AND iproute2-doc
	# REPLACED: zfs-fuse WITH zfsutils-linux
	# REMOVED: mcelog, cpuburn, ifrename, mii-diag, netcat6, atsar, ntop, netselect, hal, hostap-utils, emacs23-nox BECAUSE THEY WERE NO LONGER AVAILABLE
	# REMOVED: samhain BECAUSE IT CAUSES MASSIVE SCROLLING ERROR MESSAGES IN CLI
	# REMOVED: lilo, portsentry, macchanger BECAUSE THEY REQUIRE CONFIG AND ARE NOT NECESSARY
	# REMOVED: mailutils, fwanalog, fwlogwatch, tripwire BECAUSE THEY REQUIRE CONFIG AND/OR REQUIRE postfix WHICH REQUIRES CONFIG AND COULD CAUSE "Postfix Mail Transport Agent" ERROR IN CLI WHEN NO INTERNET
	# REMOVED: clamav clamav-freshclam BECUASE THEY ARE NOT NECESSARY
	# REPLACED (Mint 20): python-scapy WITH python3-scapy
	# REPLACED (Mint 20): btrfs-tools WITH btrfs-progs
	# REMOVED (Mint 20): denyhosts BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 21): hddtemp BECAUSE ITS NO LONGER AVAILABLE
	# REPLACED (Mint 21): ifenslave-2.6 WITH ifenslave
	# REPLACED (Mint 21): exfat-utils WITH exfatprogs
	# REPLACED (Mint 21): fuse WITH fuse3
	# REPLACED (Mint 22): iptraf WITH iptraf-ng
	# REPLACED (Mint 22): netcat WITH netcat-openbsd
	# REMOVED (Mint 22): cryptcat BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 22): cutter BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 22): doscan BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 22): netpipe-tcp BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 22): xprobe BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 22): lwatch BECAUSE ITS NO LONGER AVAILABLE
	# REMOVED (Mint 22): pptpd BECAUSE ITS NO LONGER AVAILABLE

	# Set wireshark options in advance so we don't have to choose them during installation.
	echo 'wireshark-common wireshark-common/install-setuid boolean true' | debconf-set-selections

	apt install --no-install-recommends -y scalpel syslinux-common grub2-common grub-efi-amd64 mbr syslinux extlinux gnupg dash discover gawk htop less lsof ltrace psmisc screen strace units tcsh vlock moreutils aview mc nano-tiny mg vim wdiff hexedit nvi tweak dvd+rw-tools genisoimage sdparm hdparm blktool parted partimage secure-delete scsitools smartmontools testdisk wodim wipe bonnie++ par2 fsarchiver chiark-utils-bin dmidecode lshw pciutils procinfo usbutils sysstat stress lynx links2 w3m arj bzip2 lzma p7zip-full unace unrar-free unzip zip lzop ncompress pax dar gddrescue dump dcfldd mt-st duplicity rdiff rdiff-backup rsnapshot colordiff chrootuid cpio directvnc etherwake ftp ifenslave ethtool ipcalc minicom gkermit netcat-openbsd netmask openssl openvpn vpnc strongswan sipcalc socat ssh telnet whois irssi debootstrap cdebootstrap rinse pv manpages acl symlinks bsdmainutils fail2ban iptables knockd vlan netbase rdate ntpdate isc-dhcp-client ppp pppconfig pppoe pppoeconf atm-tools bridge-utils ebtables parprouted br2684ctl iproute2 iproute2-doc iputils-tracepath mtr-tiny tcptraceroute traceroute spinner arpalert arpwatch bmon ethstatus geoip-bin hp-search-mac icmpinfo ifstat iftop ipgrab iptstate iptraf-ng lft nast nbtscan netdiscover nload nsca nstreams saidar scanssh sntop ssldump tcpdump tcpreen tcpreplay tshark crashme dbench dsniff hping3 icmpush medusa netdiag nmap ndisc6 ngrep p0f packit python3-scapy multitail httping arping dnstracer dnsutils adns-tools fping reiserfsprogs squashfs-tools sshfs sysfsutils udftools xfsdump xfsprogs btrfs-progs cryptsetup dmraid e2fsprogs fuse3 hfsplus hfsutils jfsutils lsscsi lvm2 mdadm mtools nilfs-tools ntfs-3g exfat-fuse exfatprogs reiser4progs dmsetup zfsutils-linux foremost magicrescue sleuthkit dosfstools mscompress chntpw pptp-linux cpuid x86info hwinfo tofrodos dc bc rlwrap chkrootkit rkhunter smbclient nfs-common wireless-tools wpasupplicant reaver aide autopsy pwgen rsync ncftp rpm curl wget lftp net-tools expect gpm isc-dhcp-server hostapd build-essential gdb gfortran gnat || exit 1



	echo -e '\n\nINSTALLING MORE CUSTOM PACKAGES\n'

	apt install --no-install-recommends -y libfsapfs-utils hfsprogs gsmartcontrol wxhexeditor nvme-cli memtester cheese stress-ng mint-meta-codecs || exit 1



	echo -e '\n\nINSTALLING QA HELPER DEPENDENCIES\n'

	apt install -y lsb-release xinput dmidecode util-linux pciutils lshw upower network-manager modemmanager bluez x11-xserver-utils x11-utils acpid cheese webcamoid || exit 1



	echo -e '\n\nINSTALLING FG ERASER DEPENDENCIES\n' # Some are already pre-installed or included above, but list them all anyways.

	apt install --no-install-recommends -y util-linux curl unzip network-manager dmidecode smartmontools libxml2-utils hdparm sg3-utils nvme-cli e2fsprogs mdadm nwipe zenity terminator || exit 1

	min_nwipe_version='0.35' # Make sure "nwipe" version is installed that has fixed this crash issue: https://github.com/martijnvanbrummelen/nwipe/issues/488
	nwipe_version="$(nwipe -V 2> /dev/null | tr -dc '0123456789.')"
	if [[ -z "${nwipe_version}" || ( "${nwipe_version}" != "${min_nwipe_version}" && "$(echo -e "${nwipe_version}\n${min_nwipe_version}" | sort -V)" == *$'\n'"${min_nwipe_version}" ) ]]; then
		apt install --no-install-recommends -y libconfig-dev # NOTE: "libconfig-dev" is required for newer "nwipe" built from source (which will be done by prepare script).

		touch '/needs-latest-nwipe.flag'
		while [[ -f '/needs-latest-nwipe.flag' ]]; do
			echo -e '\n>>> WAITING FOR LATEST NWIPE TO BE INSTALLED BY PREPARE SCRIPT <<<'
			sleep 5
		done

		nwipe_version="$(nwipe -V 2> /dev/null | tr -dc '0123456789.')"
		if [[ -z "${nwipe_version}" || ( "${nwipe_version}" != "${min_nwipe_version}" && "$(echo -e "${nwipe_version}\n${min_nwipe_version}" | sort -V)" == *$'\n'"${min_nwipe_version}" ) ]]; then
			echo -e '\nERROR: FAILED TO INSTALL LATEST NWIPE'
			exit 1
		fi
	fi

	# Make sure "terminator" version has close tab warning: https://github.com/gnome-terminator/terminator/pull/834
	# NOTE: Cannot run "terminator -v" in NON-GUI environment. Also, 2.1.3 is latest release version, BUT latest source build that we ACTUALLY need doesn't yet have version updated and would still show 2.1.3, so instead of checking for a specific version, check the "man" page for the "ask_before_closing" config key that we require.
	if ! zgrep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5.gz' 2> /dev/null && ! grep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5' 2> /dev/null; then # "apt" installed "terminator" will have compressed "man" page, but manually installed (as done below) will be uncompressed.
		touch '/needs-latest-terminator.flag'
		while [[ -f '/needs-latest-terminator.flag' ]]; do
			echo -e '\n>>> WAITING FOR LATEST TERMINATOR TO BE INSTALLED BY PREPARE SCRIPT <<<'
			sleep 5
		done

		if ! zgrep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5.gz' 2> /dev/null && ! grep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5' 2> /dev/null; then # "apt" installed "terminator" will have compressed "man" page, but manually installed (as done below) will be uncompressed.
			echo -e '\nERROR: FAILED TO INSTALL LATEST TERMINATOR'
			exit 1
		fi
	fi



	echo -e '\n\nAUTO-REMOVE AFTER ALL UPDATES AND APT INSTALLATIONS\n'

	apt autoremove -y || exit 1



	echo -e '\n\nINSTALLING FREE GEEK TECH SUPPORT SCRIPTS\n'
	# fg-tstools: https://github.com/scott-morris1/techsupporttools
	# The correct latest version is the files in https://github.com/scott-morris1/techsupporttools/tree/master/deb
	# BUT NEITHER THE fg-tstools_current.deb NOR fg-tstools_testing.deb FILES CONTAIN THE CORRECT VERSION

	github_content_repo_base_url='https://raw.githubusercontent.com/scott-morris1/techsupporttools/master/deb'

	rm -rf '/usr/lib/tstools/' '/usr/share/doc/fg-tstools/'

	# NOTE: curl's "--progress-bar" option does not work when "--parallel" is also specified.
	curl --connect-timeout 5 --parallel -fL --create-dirs --output-dir '/etc' \
		-O "${github_content_repo_base_url}/etc/ts_network_backup.cfg" \
		--next --create-dirs --output-dir '/usr/bin' \
		-O "${github_content_repo_base_url}/usr/bin/ts_getid" \
		-O "${github_content_repo_base_url}/usr/bin/ts_identify_backups" \
		-O "${github_content_repo_base_url}/usr/bin/ts_network_backup" \
		--next --create-dirs --output-dir '/usr/lib/tstools' \
		-O "${github_content_repo_base_url}/usr/lib/tstools/ts_exclude.txt" \
		-O "${github_content_repo_base_url}/usr/lib/tstools/ts_functions.sh" \
		-O "${github_content_repo_base_url}/usr/lib/tstools/ts_network_backup_functions.sh" \
		--next --create-dirs --output-dir '/usr/share/doc/fg-tstools' \
		-O "${github_content_repo_base_url}/usr/share/doc/fg-tstools/changelog.gz" \
		-O "${github_content_repo_base_url}/usr/share/doc/fg-tstools/copyright" \
		-O "${github_content_repo_base_url}/usr/share/doc/fg-tstools/ts_exclude.txt" || exit 1

	chmod +x '/usr/bin/ts_'* '/usr/lib/tstools/ts_'*'.sh' || exit 1



	echo -e '\n\nINSTALLING HFS+ RESCUE\n'
	# hfsprescue: https://www.plop.at/en/hfsprescue/download.html

	curl --connect-timeout 5 --progress-bar -fL "$(curl -m 5 -sfL 'https://www.plop.at/en/hfsprescue/download.html' 2> /dev/null | awk -F '=|>' '/precompiled.tar.gz/ { print $2; exit }')" -o "${TMPDIR}/hfsprescue-latest-precompiled.tar.gz" || exit 1
	tar -xzvf "${TMPDIR}/hfsprescue-latest-precompiled.tar.gz" -C '/usr/bin/' --strip-components '2' --wildcards '*/Linux/hfsprescue_x64' || exit 1
	rm "${TMPDIR}/hfsprescue-latest-precompiled.tar.gz" || exit 1
	mv '/usr/bin/hfsprescue_x64' '/usr/bin/hfsprescue' || exit 1



	echo -e '\n\nINSTALLING HD SENTINEL\n'
	# hdsentinel: https://www.hdsentinel.com/hard_disk_sentinel_linux.php

	curl --connect-timeout 5 --progress-bar -fL "$(curl -m 5 -sfL 'https://www.hdsentinel.com/hard_disk_sentinel_linux.php' 2> /dev/null | awk -F '"' '/x64.zip/ { print $2; exit }')" -o "${TMPDIR}/hdsentinel-latest-x64.zip" || exit 1
	unzip -o "${TMPDIR}/hdsentinel-latest-x64.zip" -d "${TMPDIR}" || exit 1
	rm "${TMPDIR}/hdsentinel-latest-x64.zip" || exit 1
	mv "${TMPDIR}/HDSentinel" '/usr/bin/hdsentinel' || exit 1
	chmod +x '/usr/bin/hdsentinel' || exit 1



	echo -e '\n\nSETTING AUTO LOGIN TO ALL TTYs FOR CLI MODE\n'
	# https://wiki.archlinux.org/index.php/Getty#Automatic_login_to_virtual_console

	for this_tty_number in {1..6}
	do
		mkdir "/etc/systemd/system/getty@tty${this_tty_number}.service.d"
		cat << TTY_OVERRIDE_CONF_EOF > "/etc/systemd/system/getty@tty${this_tty_number}.service.d/override.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin mint --noclear %I $TERM
Type=idle
TTY_OVERRIDE_CONF_EOF
	done



	echo -e '\n\nSETTING AUTO RUN SETUP MINT LIVE TOOLKIT SCRIPT FOR CINNAMON\n'
	# Actual script is copied into squashfs-root by copy resources script

	cat << SETUP_DESKTOP_FILE_EOF > "${TMPDIR}/setup-mint-live-toolkit.desktop"
[Desktop Entry]
Version=1.0
Name=Setup Mint Live Toolkit
GenericName=Setup Mint Live Toolkit
Comment=Run Setup Mint Live Toolkit Script for Cinnamon
Exec=/usr/bin/setup-mint-live-toolkit
Terminal=false
Type=Application
Categories=Utility;Application;
X-GNOME-Autostart-Delay=5
SETUP_DESKTOP_FILE_EOF

	desktop-file-install --delete-original --dir '/etc/xdg/autostart/' "${TMPDIR}/setup-mint-live-toolkit.desktop" || exit 1
	chmod +x '/etc/xdg/autostart/setup-mint-live-toolkit.desktop' || exit 1



	newest_kernel_version="$(find '/usr/lib/modules' -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -rV | head -1)" # DO NOT use "uname -r" in the Cubic Terminal to get the kernel version since it returns the kernel version of the HOST OS rather than the CUSTOM ISO OS that has just been updated and they are not guaranteed to be the same.

	echo -e "\n\nINCLUDING USB NETWORK ADAPTER MODULES IN INITRAMFS (${newest_kernel_version})\n"
	# Must be done after system updated or anything that would update initramfs

	find "/usr/lib/modules/${newest_kernel_version}/kernel/drivers/net/usb" -type f -exec basename {} '.ko' \;  > '/usr/share/initramfs-tools/modules.d/network-usb-modules'
	echo -e "ALL USB NETWORK MODULES: $(paste -sd ',' '/usr/share/initramfs-tools/modules.d/network-usb-modules')\n"

	orig_initramfs_config="$(< '/etc/initramfs-tools/initramfs.conf')"
	sed -i 's/COMPRESS=.*/COMPRESS=xz/' '/etc/initramfs-tools/initramfs.conf' || exit 1
	# Use "xz" compression so the "initrd" file is as small as possible since it will be downloaded in advance over the network via iPXE and decompressed all at once,
	# unlike the "sqaushfs" where we specifically don't want to use "xz" compression (see comments in "prepare-cubic-project-for-mint-live-toolkit.sh" for more info about that).
	# Even though "xz" decompression is slower than "zstd" or other compressions, since the file is relatively small the different decompression speeds are not noticable when booting.
	# Changing the compression also makes Cubic update the "initrd.lz" extension to "initrd.xz" so that needs to be used in all boot menus,
	# but Cubic automatically updates the boot menu files to use the right extensions anyways,
	# and the "ipxe-linux-booter.php" when booting via iPXE will find the "initrd" file with any extension).

	update-initramfs -vu || exit 1 # Create new custom "initrd" file with the added modules.
	rm '/usr/share/initramfs-tools/modules.d/network-usb-modules' || exit 1 # Reset modules and configuration to default
	echo "${orig_initramfs_config}" > '/etc/initramfs-tools/initramfs.conf' # to not affect future updates of installed os.



	echo -e '\n\nUPDATING /ETC/ISSUE FILE\n'

	echo -e "  Mint Live Toolkit ($(lsb_release -rs))\n\n  \\l\n" > '/etc/issue'



	echo -e '\n\nSUCCESSFULLY COMPLETED MINT LIVE TOOLKIT CUBIC TERMINAL COMMANDS'

	rm -f '/'*'.sh' '/root/'*'.sh'
elif [[ "$(hostname)" != 'cubic' ]]; then
	echo '!!! THIS SCRIPT MUST BE RUN IN CUBIC TERMINAL !!!'
	echo '>>> YOU CAN DRAG-AND-DROP THIS SCRIPT INTO THE CUBIC TERMINAL WINDOW TO COPY AND THEN RUN IT FROM WITHIN THERE <<<'
	read -r
else
	echo 'YOU MUST RUN "prepare-cubic-project-for-mint-live-toolkit.sh" FROM THE LOCAL OS FIRST'
fi
