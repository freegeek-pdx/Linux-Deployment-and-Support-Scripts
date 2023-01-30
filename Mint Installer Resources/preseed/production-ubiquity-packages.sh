#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell
# Last Updated: 01/09/23
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

MODE="$([[ "${0##*/}" == 'testing-'* ]] && echo 'testing' || echo 'production')"
readonly MODE

if [[ ! -e '/home/oem/Desktop/qa-helper.desktop' ]]; then
    for install_qa_helper_attempt in {1..5}; do
        echo -e '\n\nPREPARING TO INSTALL QA HELPER\n'
        curl -m 5 -sfL 'https://apps.freegeek.org/qa-helper/download/actually-install-qa-helper.sh' | bash -s -- "${MODE}"
        
        if [[ -e '/home/oem/Desktop/qa-helper.desktop' ]]; then
            break
        else
            sleep "${install_qa_helper_attempt}"
        fi
    done
fi

# NOTE: Not currently installing "Free Geek Support" app since Tech Support has temporarily been closed, but leaving code in place for possible future use.
# if [[ ! -e '/usr/share/applications/fg-support.desktop' ]]; then
#     for install_free_geek_support_attempt in {1..5}
#     do
#         echo -e '\n\nPREPARING TO INSTALL FREE GEEK SUPPORT\n'
#         curl -m 5 -sfL 'https://apps.freegeek.org/fg-support/download/actually-install-fg-support.sh' | bash -s -- "${MODE}"
#
#         if [[ -e '/usr/share/applications/fg-support.desktop' ]]; then
#             break
#         else
#             sleep "${install_free_geek_support_attempt}"
#         fi
#     done
# fi

echo -e '\n\nINSTALLING OEM-CONFIG-GTK:\n'
# Use "--no-install-recommends" since apt in Mint 20 now includes recommendations by default.
# For some reason "oem-config-gtk" recommends "plasma-desktop" which installs "breeze-cursor-theme" along with other breeze theme components.
# Other than just not wanting this extra junk, when "breeze-cursor-theme" is installed, it becomes the default cursor for Java apps for some reason even if it's not the selected system cursor.
apt install --no-install-recommends -y oem-config-gtk

echo -e '\n\nINSTALLING MINT-META-CODECS:\n'
apt install -y mint-meta-codecs

if [[ "${MODE}" == 'production' ]]; then
    echo -e '\n\nSYSTEM UPDATE 1 OF 3:\n'
    mintupdate-cli upgrade -ry

    echo -e '\n\nSYSTEM UPDATE 2 OF 3:\n'
    mintupdate-cli upgrade -ry

    echo -e '\n\nAUTOREMOVE ONCE BEFORE LAST UPDATE CYCLE:\n'
    apt autoremove -y

    echo -e '\n\nSYSTEM UPDATE 3 OF 3:\n'
    mintupdate-cli upgrade -ry

    mintupdate_dryrun_output="$(mintupdate-cli upgrade -rd)"
    if [[ "${mintupdate_dryrun_output}" != 'Error: mint-refresh-cache could not update the cache.'* && "${mintupdate_dryrun_output}" != *"Use 'apt autoremove' to remove them."* && "${mintupdate_dryrun_output}" == *$'\n0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.' ]]; then
        # Automatically mark System Update as Verified in QA Helper if all updates were installed.
        if [[ ! -d '/usr/local/share/build-info' ]]; then
            mkdir '/usr/local/share/build-info' # This folder (and the "qa-helper-log.txt" file) may or may not already exist depending on whether or not anything else was already verified in QA Helper.
        fi
        echo "Task: Updates Verified - $(date '+%m/%d/%Y %T')" >> '/usr/local/share/build-info/qa-helper-log.txt' # If anything was verified in QA Helper, the ubiquity-finish script will have copied this script to this target drive location.
    fi
fi

if ! xinput | grep -qF 'AT Translated'; then # Does not have internal keyboard, so assume it is a Desktop.
    # NVIDIA drivers often cause issues on Laptops, so only auto-install ubuntu-drivers on Desktops.

    ubuntu_drivers_list="$(ubuntu-drivers list)"

    if [[ "${MODE}" == 'testing' ]]; then
        echo -e "\n\n\n\nDEBUG - ubuntu_drivers_list:\n${ubuntu_drivers_list}\n\n"
    fi

    if [[ -n "${ubuntu_drivers_list}" ]]; then
        echo -e '\n\nINSTALLING RECOMMENDED DRIVERS:\n'
        ubuntu-drivers install # Previously would manually detect and install recommended packages for installed drivers to get 32 bit libs for Steam/Unigine, but apt in Mint 20 installs recommendations by default so that is no longer needed.
    fi
fi
