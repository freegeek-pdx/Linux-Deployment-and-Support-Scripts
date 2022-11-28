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

if [[ "$(hostname)" == 'cubic' ]]; then
    echo -e '\n\nINSTALLING SYSTEM UPDATES\n'

    mintupdate-cli upgrade -ry || exit 1
    mintupdate-cli upgrade -ry || exit 1
    mintupdate-cli upgrade -ry || exit 1



    echo -e '\n\nINSTALLING MINT-META-CODECS\n'
    
    apt install mint-meta-codecs -y || exit 1



    if [[ -z "$(apt-cache policy google-chrome-stable)" ]]; then 
        echo -e '\n\nDOWNLOADING GOOGLE CHROME INSTALLER\n'

        curl --connect-timeout 5 --progress-bar -L 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' -o '/tmp/install-google_chrome.deb' || exit 1
    fi

    echo -e '\n\nINSTALLING GOOGLE CHROME\n'
    
    sudo apt install --no-install-recommends -y "$([[ -f '/tmp/install-google_chrome.deb' ]] && echo '/tmp/install-google_chrome.deb' || echo 'google-chrome-stable')" || exit 1
    rm -f '/tmp/install-google_chrome.deb' || exit 1



    if [[ -z "$(apt-cache policy zoom)" ]]; then 
        echo -e '\n\nDOWNLOADING ZOOM INSTALLER\n'
    
        curl --connect-timeout 5 --progress-bar -L 'https://zoom.us/client/latest/zoom_amd64.deb' -o '/tmp/install-zoom.deb' || exit 1
    fi

    echo -e '\n\nINSTALLING ZOOM\n'
    
    sudo apt install --no-install-recommends -y "$([[ -f '/tmp/install-zoom.deb' ]] && echo '/tmp/install-zoom.deb' || echo 'zoom')" || exit 1
    rm -f '/tmp/install-zoom.deb' || exit 1



    echo -e '\n\nAUTO-REMOVE AFTER ALL UPDATES AND APT INSTALLATIONS\n'

    apt autoremove -y || exit 1



    echo -e '\n\nINCLUDING USB NETWORK ADAPTER MODULES IN INITRAMFS\n'
    # Must be done after system updated or anything that would update initramfs

    # Suppress ShellCheck suggestion to use "find" instead of "ls" since we need "ls -t" to sort by modification date to easily get a single result of the newest kernel version folder name, and this path will never contain non-alphanumeric characters.
    # shellcheck disable=SC2012
    find "/lib/modules/$(ls -t '/lib/modules/' | head -1)/kernel/drivers/net/usb" -type f -exec basename {} '.ko' \;  > '/usr/share/initramfs-tools/modules.d/network-usb-modules'
    orig_initramfs_config="$(< '/etc/initramfs-tools/initramfs.conf')"
    sed -i 's/COMPRESS=.*/COMPRESS=xz/' '/etc/initramfs-tools/initramfs.conf' || exit 1
    # Use xz compression so the initrd file is as small as possible since it will also be loaded over the network via iPXE.
    # Changing the compression also makes Cubic update the "initrd.lz" extension to "initrd.xz" so that needs to be used in all boot menus.
    update-initramfs -u || exit 1
    rm '/usr/share/initramfs-tools/modules.d/network-usb-modules' || exit 1
    echo "${orig_initramfs_config}" > '/etc/initramfs-tools/initramfs.conf'



    echo -e '\n\nSUCCESSFULLY COMPLETED MINT INSTALLER CUBIC TERMINAL COMMANDS'

    rm -f '/'*'.sh'
    rm -f '/root/'*'.sh'
else
    echo '!!! THIS SCRIPT MUST BE RUN IN CUBIC TERMINAL !!!'
    echo '>>> YOU CAN DRAG-AND-DROP THIS SCRIPT INTO THE CUBIC TERMINAL WINDOW TO COPY AND THEN RUN IT FROM WITHIN THERE <<<'
    read -r
fi
