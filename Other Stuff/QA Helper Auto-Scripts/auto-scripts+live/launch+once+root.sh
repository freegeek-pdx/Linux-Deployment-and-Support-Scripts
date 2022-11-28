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

if ! grep -qF ' boot=casper ' '/proc/cmdline'; then

    # NOTE: Not currently installing "Free Geek Support" app since Tech Support has temporarily been closed, but leaving code in place for possible future use.
    # echo 'VERIFYING FREE GEEK SUPPORT INSTALLATION'
    # if [[ ! -e '/usr/share/applications/fg-support.desktop' ]]; then
    #     for install_free_geek_support_attempt in {1..5}; do
    #         echo -e '\n\nPREPARING TO INSTALL FREE GEEK SUPPORT\n'
    #         curl -m 5 -sL 'https://apps.freegeek.org/fg-support/download/actually-install-fg-support.sh' | bash
    #
    #         if [[ -e '/usr/share/applications/fg-support.desktop' ]]; then
    #             break
    #         else
    #             sleep "${install_free_geek_support_attempt}"
    #         fi
    #     done
    # fi

    echo 'VERIFYING OEM-CONFIG-GTK INSTALLATION'
    apt-get install --no-install-recommends -qq oem-config-gtk

    echo 'VERIFYING MINT-META-CODECS INSTALLATION'
    apt-get install -qq mint-meta-codecs

    if [[ "$1" != 'qa-complete' ]] && ! pgrep -f '(driver-manager|mintdrivers)' &> /dev/null; then
        echo 'LAUNCHING DRIVER MANAGER'
        nohup driver-manager &> /dev/null & disown # Pre-launch and minimize "Driver Manager" since it can take a while to load so that it's pre-loaded by the time it's activated via QA Helper.
        
        apt-get install --no-install-recommends -qq xdotool &> /dev/null & # "xdotool" is required to be able to minimize the window since "wmctrl" can't do that (to keep it out of the way until it's activated via QA Helper).

        for (( wait_for_driver_manager_seconds = 0; wait_for_driver_manager_seconds < 30; wait_for_driver_manager_seconds ++ )); do
            sleep 1

            if [[ "$(wmctrl -l)"$'\n' == *$' Driver Manager\n'* ]]; then
                wmctrl -r 'Driver Manager' -e '0,0,0,-1,-1'
                wmctrl -F -a 'QA Helper' || wmctrl -F -a 'QA Helper  —  Loading'
                break
            fi
        done

        for (( wait_for_xdotool = 0; wait_for_xdotool < 30; wait_for_xdotool ++ )); do
            if xdotool search --name 'Driver Manager' windowminimize &> /dev/null; then
                break
            fi

            sleep 1
        done

        apt-get purge --auto-remove -qq xdotool &> /dev/null
    fi
fi
