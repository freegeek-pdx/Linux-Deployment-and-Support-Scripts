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

set -ex

cd "${HOME}/Documents/Free Geek/iPXE for FG" || exit 1
sudo rm -f ./*'.efi' ./*'.pxe' ./*'.kpxe' ./*'.lkrn'
sudo rm -rf 'ipxe-netboot/' 'ipxe-usbboot/' 'ipxe/'


# 1) DOWNLOAD iPXE SOURCE: (https://ipxe.org/download)

sudo apt install -y git

git clone 'git://git.ipxe.org/ipxe.git'
cd 'ipxe/src'


# 2) SET BUILD CONFIGURATION OPTIONS: (https://ipxe.org/buildcfg)

# UNCOMMENT IN config/general.h: #define POWEROFF_CMD, #define PARAM_CMD, #define PING_CMD, #define CONSOLE_CMD
sed -i \
	-e 's|//#define POWEROFF_CMD|#define POWEROFF_CMD // ENABLED FOR FREE GEEK|' \
	-e 's|//#define PARAM_CMD|#define PARAM_CMD // ENABLED FOR FREE GEEK|' \
	-e 's|//#define PING_CMD|#define PING_CMD // ENABLED FOR FREE GEEK|' \
	-e 's|//#define CONSOLE_CMD|#define CONSOLE_CMD // ENABLED FOR FREE GEEK|' \
	'config/general.h'
if (( $(grep -cF 'ENABLED FOR FREE GEEK' 'config/general.h') != 4 )); then
	echo -e '\nERROR: FAILED TO ENABLE REQUIRED SETTINGS IN config/general.h'
	read -r
	exit 1
fi

# UNCOMMENT IN config/console.h: #define CONSOLE_FRAMEBUFFER
sed -i 's|//#define	CONSOLE_FRAMEBUFFER|#define	CONSOLE_FRAMEBUFFER // ENABLED FOR FREE GEEK|' 'config/console.h'
if ! grep -qF 'ENABLED FOR FREE GEEK' 'config/console.h'; then
	echo -e '\nERROR: FAILED TO ENABLE REQUIRED SETTINGS IN config/console.h'
	read -r
	exit 1
fi

# UNCOMMENT IN config/settings.h: #define CPUID_SETTINGS
sed -i 's|//#define	CPUID_SETTINGS|#define	CPUID_SETTINGS // ENABLED FOR FREE GEEK|' 'config/settings.h'
if ! grep -qF 'ENABLED FOR FREE GEEK' 'config/settings.h'; then
	echo -e '\nERROR: FAILED TO ENABLE REQUIRED SETTINGS IN config/general.h'
	read -r
	exit 1
fi

# ADD IN config/defaults/pcbios.h: #define MEMMAP_SETTINGS (since it only works on BIOS and will break building EFI if uncommented in config/settings.h)
# I posted a request for memsize support on UEFI, but that has not been acted on as of Jan 2022: https://github.com/ipxe/ipxe/issues/429
sed -i 's|#define	REBOOT_CMD|#define MEMMAP_SETTINGS // ENABLED FOR FREE GEEK\n\n#define	REBOOT_CMD|' 'config/defaults/pcbios.h'
if ! grep -qF 'ENABLED FOR FREE GEEK' 'config/defaults/pcbios.h'; then
	echo -e '\nERROR: FAILED TO ENABLE REQUIRED SETTINGS IN config/defaults/pcbios.h'
	read -r
	exit 1
fi


# 3) CREATE NET AND USB BOOT EMBEDDED SCRIPTS TO LOAD MAIN MENU FILE: (https://ipxe.org/embed)

cat << 'IPXE_NET_BOOT_MENU_EOF' > 'load-menu-netboot.ipxe'
#!ipxe
:load-menu
echo
echo LOADING iPXE MENU - PRESS 'CTRL+C' IF HUNG ON 'CONFIGURING' FOR OVER 10 SECONDS
echo
imgfree ||
dhcp --timeout 10000 || goto dhcp-error
echo
set FG_PXE_SERVER 192.168.2.44
isset ${netX/next-server} && set FG_PXE_SERVER ${netX/next-server} ||
ping --count 1 ${FG_PXE_SERVER} || goto load-error
echo
boot --timeout 5000 tftp://${FG_PXE_SERVER}/boot/menu.ipxe ||
:dhcp-error
echo
echo ERROR CONNECTING iPXE TO THE INTERNET - TRY BOOTING WITH DIFFERENT iPXE VARIANT
echo VISIT http://tools.freegeek.org/ifxe ON ANOTHER COMPUTER TO CHANGE iPXE VARIANT
goto try-again-prompt
:load-error
echo
ifstat || echo IFSTAT FAILED
echo
echo ERROR LOADING iPXE MENU - LOCAL FREE GEEK NETWORK REQUIRED
:try-again-prompt
echo
prompt --key s --timeout 5000 Press 's' for iPXE Shell. Press ANY OTHER KEY or wait 5 seconds to try again... && shell ||
goto load-menu
IPXE_NET_BOOT_MENU_EOF

cat << 'IPXE_USB_BOOT_MENU_EOF' > 'load-menu-usbboot.ipxe'
#!ipxe
:load-menu
echo
echo LOADING iPXE MENU - PRESS 'CTRL+C' IF HUNG ON 'CONFIGURING' FOR OVER 10 SECONDS
echo
imgfree ||
dhcp --timeout 10000 || goto load-error
echo
set FG_PXE_SERVER 192.168.2.44
isset ${netX/next-server} && set FG_PXE_SERVER ${netX/next-server} ||
ping --count 1 ${FG_PXE_SERVER} || goto load-error
echo
boot --timeout 5000 tftp://${FG_PXE_SERVER}/boot/menu.ipxe ||
:load-error
echo
ifstat || echo IFSTAT FAILED
echo
echo ERROR LOADING iPXE MENU - LOCAL FREE GEEK NETWORK REQUIRED
echo
prompt --key s --timeout 5000 Press 's' for iPXE Shell. Press ANY OTHER KEY or wait 5 seconds to try again... && shell ||
goto load-menu
IPXE_USB_BOOT_MENU_EOF


# 4) BUILD iPXE: (https://ipxe.org/appnote/buildtargets)

sudo apt install -y make gcc

mkdir '../../ipxe-netboot' '../../ipxe-usbboot'

# SET GITVERSION TO FG AND CURRENT BUILD DATE
sed -i "s/GITVERSION	= \$(word 5,\$(VERSION_TUPLE))/GITVERSION	= FG$(date '+%y%m%d')/" 'Makefile'
if ! grep -qF "GITVERSION	= FG$(date '+%y%m%d')" 'Makefile'; then
	echo -e '\nERROR: FAILED TO SET FG VERSION IN Makefile'
	read -r
	exit 1
fi

# CHANGE "initialising devices" TO "initializing devices" FOR MY OWN SATISFACTION
sed -i 's/%s initialising devices/%s initializing devices/' 'core/main.c'


# BUILD FOR UEFI (NETWORK): "snponly.efi" uses EFI land drivers initially and only tries to boot from the device iPXE was chained from and also seems to generally load faster than a full "ipxe.efi" build. (See "Drivers" section of Build Targets page.)
build_type_title='UEFI - Net Boot - SNP Only'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-efi/snponly.efi' EMBED='load-menu-netboot.ipxe'
mv 'bin-x86_64-efi/snponly.efi' '../../ipxe-netboot/ipxe-snpOnly.efi'

build_type_title='UEFI - Net Boot - NIC Drivers'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-efi/ipxe.efi' EMBED='load-menu-netboot.ipxe'
mv 'bin-x86_64-efi/ipxe.efi' '../../ipxe-netboot/ipxe-nicDrivers.efi'

# BUILD iPXE FOR USB NOTES:
# "ncm--ecm--axge" as the filename builds with USB Ethernet adapter drivers (for booting via USB Drive with USB Ethernet adapter): https://forum.ipxe.org/showthread.php?tid=5948&pid=19101#pid19101

# BUILD FOR UEFI (USB Boot with Built-In Ethernet):
build_type_title='UEFI - USB Boot - Built-In Ethernet'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-efi/ipxe.efi' EMBED='load-menu-usbboot.ipxe'
mv 'bin-x86_64-efi/ipxe.efi' '../../ipxe-usbboot/ipxe-usbBootWithBuiltInEthernet.efi'

# BUILD FOR UEFI (USB Boot with Ethernet Adapter):
build_type_title='UEFI - USB Boot - Ethernet Adapter'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-efi/ncm--ecm--axge.efi' EMBED='load-menu-usbboot.ipxe'
mv 'bin-x86_64-efi/ncm--ecm--axge.efi' '../../ipxe-usbboot/ipxe-usbBootWithEthernetAdapter.efi'



# BIOS BUILD REQUIRES "liblzma-dev" FOR "lzma.h" (sudo apt install liblzma-dev)
sudo apt install -y liblzma-dev

# BUILD FOR BIOS (NETWORK):
# "undionly.kpxe" can caused http://ipxe.org/040ee119 on some computers so techs can switch to full ipxe on the fly when needed.
build_type_title='Legacy BIOS - Net Boot - UNDI Only'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-pcbios/undionly.kpxe' EMBED='load-menu-netboot.ipxe'
mv 'bin-x86_64-pcbios/undionly.kpxe' '../../ipxe-netboot/ipxe-undiOnly.kpxe'

build_type_title='Legacy BIOS - Net Boot - NIC Drivers'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-pcbios/ipxe.pxe' EMBED='load-menu-netboot.ipxe'
mv 'bin-x86_64-pcbios/ipxe.pxe' '../../ipxe-netboot/ipxe-nicDrivers.pxe'

# BUILD FOR BIOS (USB Boot with Built-In Ethernet):
build_type_title='Legacy BIOS - USB Boot - Built-In Ethernet'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-pcbios/ipxe.lkrn' EMBED='load-menu-usbboot.ipxe'
mv 'bin-x86_64-pcbios/ipxe.lkrn' '../../ipxe-usbboot/ipxe-usbBootWithBuiltInEthernet.lkrn'

# BUILD FOR BIOS (USB Boot with Ethernet Adapter):
build_type_title='Legacy BIOS - USB Boot - Ethernet Adapter'
sed -i "s/%s.* initializing devices/%s (${build_type_title}) initializing devices/" 'core/main.c'
if ! grep -qF "(${build_type_title})" 'core/main.c'; then
	echo -e '\nERROR: FAILED TO SET BUILD TYPE TITLE IN core/main.c'
	read -r
	exit 1
fi
make 'bin-x86_64-pcbios/ncm--ecm--axge.lkrn' EMBED='load-menu-usbboot.ipxe'
mv 'bin-x86_64-pcbios/ncm--ecm--axge.lkrn' '../../ipxe-usbboot/ipxe-usbBootWithEthernetAdapter.lkrn'

echo -e '\nDONE!'
read -r
