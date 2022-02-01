#!/bin/bash

#
# Created by Pico Mitchell
# Last Updated: 09/12/21
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

MODE="$([[ "$(basename -- "$0")" == 'testing-'* ]] && echo 'testing' || echo 'production')"
readonly MODE

echo "--data-urlencode \"base_end_time=$(date +%s)\" \\" >> '/tmp/post_install_time.sh'

if [[ -d '/usr/local/share/build-info' && ! -d '/target/usr/local/share/build-info' ]]; then
    cp -rf '/usr/local/share/build-info' '/target/usr/local/share/build-info' # Copy build-info to installed OS in case QA Helper was used during pre-install.
fi

if [[ -e '/tmp/detailed_hostname.txt' ]]; then
    detailed_hostname="$(cat '/tmp/detailed_hostname.txt')"
    echo "${detailed_hostname}" > '/target/etc/hostname'
    sed -i "2s/.*/127.0.0.1\t${detailed_hostname}/" '/target/etc/hosts'
    chroot '/target' hostname -F '/target/etc/hostname'
fi

hostname -F '/target/etc/hostname' # Sync hostnames to silence "sudo unable to resolve host mint" warnings (when sudo is used in QA Helper installer)

for this_mount_point in 'dev' 'dev/pts' 'sys' 'proc' 'run'; do
    # Bind mount /dev /sys /proc for chroot ubuntu-drivers and microcode installations, etc.
    # Bind mounting /run is critical for chroot downloads to work by getting the proper resolv.conf info.
    mount --bind "/${this_mount_point}" "/target/${this_mount_point}"
done

if [[ "${MODE}" == 'testing' ]]; then
    LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -geometry 80x25+0+0 -sb -sl 999999 -e 'echo -e "DEBUG - CLOSE ME TO INSTALL PACKAGES, SYSTEM UPDATES, AND DRIVERS\n\n"; bash'
fi

cp -f "/cdrom/preseed/${MODE}-ubiquity-packages.sh" "/target/${MODE}-ubiquity-packages.sh"

echo "--data-urlencode \"updates_start_time=$(date +%s)\" \\" >> '/tmp/post_install_time.sh'

REBOOT_TIMEOUT="$([[ "${MODE}" == 'testing' ]] && echo '' || echo '-t 30')"
readonly REBOOT_TIMEOUT

desktop_environment="$(awk -F '=' '($1 == "Name") { print $2; exit }' '/target/usr/share/xsessions/'*)" # Can't get desktop environment from DESKTOP_SESSION or XDG_CURRENT_DESKTOP in pre-install environment.
desktop_environment="${desktop_environment%% (*)}"
if [[ -n "$desktop_environment" ]]; then
    desktop_environment=" (${desktop_environment})"
fi

release_codename="$(lsb_release -cs)"
if [[ -n "$release_codename" ]]; then
    release_codename=" ${release_codename^}"
fi

while [[ -e "/target/${MODE}-ubiquity-packages.sh" ]]; do
    LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -fullscreen -title 'Installing Packages, System Updates, and Drivers' -sb -sl 999999 -e "echo -e '\nINSTALLING PACKAGES, SYSTEM UPDATES, AND DRIVERS\n'; chroot '/target' \"/${MODE}-ubiquity-packages.sh\"; rm -f \"/target/${MODE}-ubiquity-packages.sh\"; echo \"--data-urlencode \\\"updates_end_time=\$(date +%s)\\\" \\\\\" >> '/tmp/post_install_time.sh'; echo -e '\n\nDONE INSTALLING PACKAGES, SYSTEM UPDATES, AND DRIVERS\n\n\n\n\n\n\n\n\n\nSUCCESSFULLY INSTALLED $(lsb_release -ds)${release_codename}${desktop_environment}\n\nTHIS COMPUTER WILL REBOOT IN 30 SECONDS\n\n\n\n\n\n\n\n\n\nOR PRESS ENTER TO REBOOT NOW'; read ${REBOOT_TIMEOUT} line"

    if [[ -e "/target/${MODE}-ubiquity-packages.sh" ]]; then
        # Fix any problems if xterm was closed mid-installation.
        if [[ "${MODE}" == 'testing' ]]; then
            LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -fullscreen -title 'Fixing DPKG and APT Before Installing Again' -sb -sl 999999 -e "echo -e '\nFIXING DPKG AND APT BEFORE RE-INSTALLING PACKAGES, SYSTEM UPDATES, AND DRIVERS\n'; killall dpkg 2> /dev/null && echo -e '\n\nKILLED DPKG' || echo -e '\n\nDPKG NOT RUNNING'; killall apt 2> /dev/null && echo -e '\n\nKILLED APT' || echo -e '\n\nAPT NOT RUNNING'; killall apt-get 2> /dev/null && echo -e '\n\nKILLED APT-GET' || echo -e '\n\nAPT-GET NOT RUNNING'; echo -e '\n\nWAITING 5 SECONDS BEFORE REPAIRING DPKG AND APT...'; sleep 5; echo -e '\n\nREPAIRING DPKG:\n'; chroot '/target' dpkg --configure -a; echo -e '\n\nREPAIRING APT:\n'; chroot '/target' apt-get -f install -y; echo -e '\n\nDONE FIXING DPKG AND APT BEFORE RE-INSTALLING PACKAGES, SYSTEM UPDATES, AND DRIVERS'; read -t 3 line"
        else
            killall dpkg 2> /dev/null
            killall apt 2> /dev/null
            killall apt-get 2> /dev/null
            sleep 5 # Seems to be necessary to wait a bit after killing processes and before reparing dpkg and apt-get
            chroot '/target' dpkg --configure -a
            chroot '/target' apt-get -f install -y
        fi
    fi
done

chmod +x '/tmp/post_install_time.sh'
'/tmp/post_install_time.sh' # Run this generated script.

if [[ "${MODE}" == 'testing' ]]; then
    LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -geometry 80x25+0+0 -sb -sl 999999 -e 'echo -e "DEBUG - CLOSE ME TO REBOOT\n\n"; bash'
fi
