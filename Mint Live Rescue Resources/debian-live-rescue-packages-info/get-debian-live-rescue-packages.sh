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

# Final "debian-live" Commit Removing Debian Live Rescue: https://github.com/debian-live/live-images/commit/4c1911124c2ae128312ae6d256c8322d944d258f
debian_live_rescue_package_list="$(curl -m 5 -sL 'https://raw.githubusercontent.com/debian-live/live-images/3de5ad45b9fd2d3a6874bb4757288299a3e3b01a/images/rescue/config/package-lists/rescue.list.chroot')"

if_condition_line_contents=''
packages_to_install=''

IFS=$'\n'
for this_package_list_line in ${debian_live_rescue_package_list}; do
    if [[ "${this_package_list_line}" != '#'* ]]; then
        if [[ -z "${if_condition_line_contents}" || " ${if_condition_line_contents} " == *' amd64 '* ]]; then
            packages_to_install+=" ${this_package_list_line}" # Must concat with spaces instead of line breaks because some lines contain multiple space separated package names.
        fi
    elif [[ "${this_package_list_line}" == '#if '* ]]; then
        if_condition_line_contents="${this_package_list_line}"
    elif [[ "${this_package_list_line}" == '#endif' ]]; then
        if_condition_line_contents=''
    fi
done
unset IFS

echo -e '\nUNSORTED PACKAGES:'
echo "${packages_to_install}"
# UNSORTED PACKAGES OUTPUT: scalpel syslinux-common grub lilo mbr syslinux extlinux gnupg dash discover gawk htop less lsof ltrace psmisc screen strace units tcsh vlock mailutils moreutils aview mc nano-tiny mg vim wdiff hexedit nvi tweak dvd+rw-tools genisoimage sdparm hdparm blktool parted partimage secure-delete scsitools smartmontools testdisk wodim wipe hddtemp bonnie++ par2 dvd+rw-tools fsarchiver chiark-utils-bin dmidecode mcelog cpuburn lshw pciutils procinfo usbutils sysstat stress lynx links2 w3m arj bzip2 lzma p7zip-full unace unrar-free unzip zip lzop ncompress unace pax dar gddrescue dump dcfldd mt-st dar duplicity rdiff rdiff-backup rsnapshot colordiff chrootuid cpio cryptcat directvnc etherwake ftp ifenslave-2.6 ifrename ethtool ipcalc mii-diag minicom gkermit netcat netcat6 netmask openssl openvpn vpnc strongswan sipcalc socat ssh telnet whois irssi debootstrap cdebootstrap rinse pv manpages acl symlinks bsdmainutils denyhosts fail2ban iptables knockd portsentry vlan netbase rdate ntpdate isc-dhcp-client ppp pppconfig pppoe pppoeconf atm-tools bridge-utils ebtables parprouted br2684ctl cutter iproute iproute-doc iputils-tracepath mtr-tiny tcptraceroute traceroute spinner arpalert arpwatch atsar bmon ethstatus geoip-bin hp-search-mac icmpinfo ifstat iftop ipgrab iptstate iptraf lft nast nbtscan netdiscover nload nsca nstreams ntop saidar samhain scanssh sntop ssldump tcpdump tcpreen tcpreplay tshark crashme dbench doscan dsniff hping3 icmpush macchanger medusa netdiag netpipe-tcp nmap ndisc6 ngrep p0f packit python-scapy xprobe fwanalog fwlogwatch lwatch multitail httping arping dnstracer netselect dnsutils adns-tools fping reiserfsprogs squashfs-tools sshfs sysfsutils udftools xfsdump xfsprogs btrfs-tools cryptsetup dmraid e2fsprogs fuse hfsplus hfsutils jfsutils lsscsi lvm2 mdadm mtools nilfs-tools ntfs-3g exfat-fuse exfat-utils reiser4progs dmsetup zfs-fuse foremost magicrescue sleuthkit dosfstools mscompress chntpw pptpd pptp-linux cpuid x86info hwinfo tofrodos hal dc bc rlwrap chkrootkit rkhunter clamav clamav-freshclam smbclient nfs-common wireless-tools wpasupplicant reaver aide tripwire sleuthkit autopsy pwgen rsync ncftp rpm curl wget lftp net-tools expect gpm isc-dhcp-server hostap-utils hostapd emacs23-nox build-essential gdb gfortran gnat

echo -e '\n\nUNIQUE SORTED PACKAGES:'
echo -e "${packages_to_install}" | tr ' ' '\n' | sort -u | tr '\n' ' '
# UNIQUE SORTED PACKAGES OUTPUT: acl adns-tools aide arj arpalert arping arpwatch atm-tools atsar autopsy aview bc blktool bmon bonnie++ br2684ctl bridge-utils bsdmainutils btrfs-tools build-essential bzip2 cdebootstrap chiark-utils-bin chkrootkit chntpw chrootuid clamav clamav-freshclam colordiff cpio cpuburn cpuid crashme cryptcat cryptsetup curl cutter dar dash dbench dc dcfldd debootstrap denyhosts directvnc discover dmidecode dmraid dmsetup dnstracer dnsutils doscan dosfstools dsniff dump duplicity dvd+rw-tools e2fsprogs ebtables emacs23-nox etherwake ethstatus ethtool exfat-fuse exfat-utils expect extlinux fail2ban foremost fping fsarchiver ftp fuse fwanalog fwlogwatch gawk gdb gddrescue genisoimage geoip-bin gfortran gkermit gnat gnupg gpm grub hal hddtemp hdparm hexedit hfsplus hfsutils hostap-utils hostapd hp-search-mac hping3 htop httping hwinfo icmpinfo icmpush ifenslave-2.6 ifrename ifstat iftop ipcalc ipgrab iproute iproute-doc iptables iptraf iptstate iputils-tracepath irssi isc-dhcp-client isc-dhcp-server jfsutils knockd less lft lftp lilo links2 lshw lsof lsscsi ltrace lvm2 lwatch lynx lzma lzop macchanger magicrescue mailutils manpages mbr mc mcelog mdadm medusa mg mii-diag minicom moreutils mscompress mt-st mtools mtr-tiny multitail nano-tiny nast nbtscan ncftp ncompress ndisc6 net-tools netbase netcat netcat6 netdiag netdiscover netmask netpipe-tcp netselect nfs-common ngrep nilfs-tools nload nmap nsca nstreams ntfs-3g ntop ntpdate nvi openssl openvpn p0f p7zip-full packit par2 parprouted parted partimage pax pciutils portsentry ppp pppconfig pppoe pppoeconf pptp-linux pptpd procinfo psmisc pv pwgen python-scapy rdate rdiff rdiff-backup reaver reiser4progs reiserfsprogs rinse rkhunter rlwrap rpm rsnapshot rsync saidar samhain scalpel scanssh screen scsitools sdparm secure-delete sipcalc sleuthkit smartmontools smbclient sntop socat spinner squashfs-tools ssh sshfs ssldump strace stress strongswan symlinks sysfsutils syslinux syslinux-common sysstat tcpdump tcpreen tcpreplay tcptraceroute tcsh telnet testdisk tofrodos traceroute tripwire tshark tweak udftools unace units unrar-free unzip usbutils vim vlan vlock vpnc w3m wdiff wget whois wipe wireless-tools wodim wpasupplicant x86info xfsdump xfsprogs xprobe zfs-fuse zip 

echo -e '\n'
