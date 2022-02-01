#!/bin/bash

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

if [[ "$(hostname)" == 'cubic' && -f '/usr/bin/setup-mint-live-rescue' ]]; then
    echo -e '\n\nINSTALLING SYSTEM UPDATES\n'

    mintupdate-cli upgrade -ry || exit 1
    mintupdate-cli upgrade -ry || exit 1
    mintupdate-cli upgrade -ry || exit 1



    echo -e '\n\nINSTALLING BASE RESCUE PACKAGES\n'
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
    # REMOVED (Mint 20): denyhosts BECAUSE ITS NOT LONGER AVAILABLE

    # Set wireshark options in advance so we don't have to choose them during installation.
    echo 'wireshark-common wireshark-common/install-setuid boolean true' | debconf-set-selections

    apt install --no-install-recommends -y scalpel syslinux-common grub2-common grub-efi-amd64 mbr syslinux extlinux gnupg dash discover gawk htop less lsof ltrace psmisc screen strace units tcsh vlock moreutils aview mc nano-tiny mg vim wdiff hexedit nvi tweak dvd+rw-tools genisoimage sdparm hdparm blktool parted partimage secure-delete scsitools smartmontools testdisk wodim wipe hddtemp bonnie++ par2 fsarchiver chiark-utils-bin dmidecode lshw pciutils procinfo usbutils sysstat stress lynx links2 w3m arj bzip2 lzma p7zip-full unace unrar-free unzip zip lzop ncompress pax dar gddrescue dump dcfldd mt-st duplicity rdiff rdiff-backup rsnapshot colordiff chrootuid cpio cryptcat directvnc etherwake ftp ifenslave-2.6 ethtool ipcalc minicom gkermit netcat netmask openssl openvpn vpnc strongswan sipcalc socat ssh telnet whois irssi debootstrap cdebootstrap rinse pv manpages acl symlinks bsdmainutils fail2ban iptables knockd vlan netbase rdate ntpdate isc-dhcp-client ppp pppconfig pppoe pppoeconf atm-tools bridge-utils ebtables parprouted br2684ctl cutter iproute2 iproute2-doc iputils-tracepath mtr-tiny tcptraceroute traceroute spinner arpalert arpwatch bmon ethstatus geoip-bin hp-search-mac icmpinfo ifstat iftop ipgrab iptstate iptraf lft nast nbtscan netdiscover nload nsca nstreams saidar scanssh sntop ssldump tcpdump tcpreen tcpreplay tshark crashme dbench doscan dsniff hping3 icmpush medusa netdiag netpipe-tcp nmap ndisc6 ngrep p0f packit python3-scapy xprobe lwatch multitail httping arping dnstracer dnsutils adns-tools fping reiserfsprogs squashfs-tools sshfs sysfsutils udftools xfsdump xfsprogs btrfs-progs cryptsetup dmraid e2fsprogs fuse hfsplus hfsutils jfsutils lsscsi lvm2 mdadm mtools nilfs-tools ntfs-3g exfat-fuse exfat-utils reiser4progs dmsetup zfsutils-linux foremost magicrescue sleuthkit dosfstools mscompress chntpw pptpd pptp-linux cpuid x86info hwinfo tofrodos dc bc rlwrap chkrootkit rkhunter smbclient nfs-common wireless-tools wpasupplicant reaver aide autopsy pwgen rsync ncftp rpm curl wget lftp net-tools expect gpm isc-dhcp-server hostapd build-essential gdb gfortran gnat || exit 1



    echo -e '\n\nINSTALLING MORE CUSTOM PACKAGES\n'
    
    apt install --no-install-recommends -y libfsapfs-utils hfsprogs gsmartcontrol wxhexeditor nvme-cli memtester cheese stress-ng mint-meta-codecs || exit 1



    echo -e '\n\nAUTO-REMOVE AFTER ALL UPDATES AND APT INSTALLATIONS\n'

    apt autoremove -y || exit 1



    echo -e '\n\nINSTALLING FREE GEEK TECH SUPPORT SCRIPTS\n'
    # fg-tstools: https://github.com/scottb0t/techsupporttools
    # The correct latest version is the files in https://github.com/scottb0t/techsupporttools/tree/master/deb
    # BUT NEITHER THE fg-tstools_current.deb NOR fg-tstools_testing.deb FILES CONTAIN THE CORRECT VERSION
    
    rm -rf '/tmp/fg-tstools'
    mkdir '/tmp/fg-tstools'
    cd '/tmp/fg-tstools' || exit 1
    
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/etc/ts_network_backup.cfg' || exit 1
    mv -f 'ts_network_backup.cfg' '/etc/ts_network_backup.cfg' || exit 1
    
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/bin/ts_getid' || exit 1
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/bin/ts_identify_backups' || exit 1
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/bin/ts_network_backup' || exit 1
    chmod +x 'ts_'* || exit 1
    mv -f 'ts_'* '/usr/bin/' || exit 1
    
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/lib/tstools/ts_exclude.txt' || exit 1
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/lib/tstools/ts_functions.sh' || exit 1
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/lib/tstools/ts_network_backup_functions.sh' || exit 1
    chmod +x 'ts_'*'.sh' || exit 1
    rm -rf '/usr/lib/tstools/'
    mkdir '/usr/lib/tstools/'
    mv -f 'ts_'* '/usr/lib/tstools/' || exit 1
    
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/share/doc/fg-tstools/changelog.gz' || exit 1
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/share/doc/fg-tstools/copyright' || exit 1
    wget 'https://raw.githubusercontent.com/scottb0t/techsupporttools/master/deb/usr/share/doc/fg-tstools/ts_exclude.txt' || exit 1
    rm -rf '/usr/share/doc/fg-tstools/'
    mkdir '/usr/share/doc/fg-tstools/'
    mv -f ./* '/usr/share/doc/fg-tstools/' || exit 1
    
    cd '/tmp' || exit 1
    rm -r '/tmp/fg-tstools' || exit 1



    echo -e '\n\nINSTALLING HFS+ RESCUE\n'
    # hfsprescue: https://www.plop.at/en/hfsprescue/download.html
    
    cd '/tmp' || exit 1
    wget "$(curl -m 5 -sL 'https://www.plop.at/en/hfsprescue/download.html' 2> /dev/null | awk -F '=|>' '/precompiled.tar.gz/ { print $2; exit }')" -O 'hfsprescue-latest-precompiled.tar.gz' || exit 1
    tar -xzvf 'hfsprescue-latest-precompiled.tar.gz' || exit 1
    rm 'hfsprescue-latest-precompiled.tar.gz' || exit 1
    mv 'hfsprescue-'*'-precompiled/Linux/hfsprescue_x64' '/usr/bin/hfsprescue' || exit 1
    rm -r 'hfsprescue-'*'-precompiled' || exit 1



    echo -e '\n\nINSTALLING HD SENTINEL\n'
    # hdsentinel: https://www.hdsentinel.com/hard_disk_sentinel_linux.php
    
    cd '/tmp' || exit 1
    wget "$(curl -m 5 -sL 'https://www.hdsentinel.com/hard_disk_sentinel_linux.php' 2> /dev/null | awk -F '"' '/x64.gz/ { print $2; exit }')" -O 'hdsentinel-latest-x64.gz' || exit 1
    gunzip 'hdsentinel-latest-x64.gz' || exit 1
    mv 'hdsentinel-latest-x64' '/usr/bin/hdsentinel' || exit 1
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
    
    
    
    echo -e '\n\nSETTING AUTO RUN SETUP MINT LIVE RESCUE SCRIPT CINNAMON\n'
    # Actual script is copied into squashfs-root by copy resources script
    
    cat << SETUP_MLR_DESKTOP_FILE_EOF > '/tmp/setup-mint-live-rescue.desktop'
[Desktop Entry]
Version=1.0
Name=Setup Mint Live Rescue
GenericName=Setup Mint Live Rescue
Comment=Run Setup Mint Live Rescue Script for Cinnamon
Exec=/usr/bin/setup-mint-live-rescue
Terminal=false
Type=Application
Categories=Utility;Application;
X-GNOME-Autostart-Delay=5
SETUP_MLR_DESKTOP_FILE_EOF

    desktop-file-install --delete-original --dir '/etc/xdg/autostart/' '/tmp/setup-mint-live-rescue.desktop' || exit 1
    chmod +x '/etc/xdg/autostart/setup-mint-live-rescue.desktop' || exit 1
    
    
    
    echo -e '\n\nINCLUDING USB NETWORK ADAPTER MODULES IN INITRAMFS\n'
    # Must be done after system updated or anything that would update initramfs

    # Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
    # shellcheck disable=SC2012
    ls "/lib/modules/$(ls -t '/lib/modules/' | head -1)/kernel/drivers/net/usb" | cut -d '.' -f 1 > '/usr/share/initramfs-tools/modules.d/net-usb-modules'
    orig_initramfs_config="$(cat '/etc/initramfs-tools/initramfs.conf')"
    sed -i 's/COMPRESS=.*/COMPRESS=xz/' '/etc/initramfs-tools/initramfs.conf' || exit 1
    # Use xz compression so the initrd file is as small as possible since it will also be loaded over the network via iPXE.
    # Changing the compression also makes Cubic update the "initrd.lz" extension to "initrd.xz" so that needs to be used in all boot menus.
    update-initramfs -u || exit 1
    rm '/usr/share/initramfs-tools/modules.d/net-usb-modules' || exit 1
    echo "${orig_initramfs_config}" > '/etc/initramfs-tools/initramfs.conf'
    
    
    
    echo -e '\n\nUPDATING /ETC/ISSUE FILE\n'
    
    echo -e "  Mint Live Rescue ($(lsb_release -rs))\n\n  \\l\n" > '/etc/issue'
    
    
    
    echo -e '\n\nSUCCESSFULLY COMPLETED MINT LIVE RESCUE CUBIC TERMINAL COMMANDS'

    rm -f '/'*'.sh'
    rm -f '/root/'*'.sh'
elif [ "$(hostname)" != 'cubic' ]; then
    echo '!!! THIS SCRIPT MUST BE RUN IN CUBIC TERMINAL !!!'
    echo '>>> YOU CAN DRAG-AND-DROP THIS SCRIPT INTO THE CUBIC TERMINAL WINDOW TO COPY AND THEN RUN IT FROM WITHIN THERE <<<'
    read -r
else
    echo 'YOU MUST RUN "copy-mint-live-rescue-resources-to-cubic-project.sh" FROM THE LOCAL OS FIRST'
fi
