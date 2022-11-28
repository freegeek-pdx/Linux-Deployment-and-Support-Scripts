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

# THIS SCRIPT MUST BE RUN *INTERACTIVELY* IN A TERMINAL
# In Linux Mint, double-click the file and choose "Run in Terminal".
# If the Terminal window closes itself, that means an error happened causing the script to exit prematurely.
# When everything is successful, the Terminal window will stay open until you close it manually or hit the Enter key.

if [[ "$(hostname)" != 'cubic' ]]; then
    set -ex

    # INSTALL/UPDATE CUBIC
    # https://launchpad.net/cubic
    # https://github.com/PJ-Singh-001/Cubic

    if ! apt-cache policy | grep -qF 'cubic-wizard-release'; then
        echo -e '\n>>> ADDING CUBIC REPOSITORY <<<\n'
        sudo apt-add-repository universe
        sudo apt-add-repository ppa:cubic-wizard/release
        sudo apt update
    fi

    echo -e "\n>>> $(which cubic &> /dev/null && echo 'UPDATING' || echo 'INSTALLING') CUBIC <<<\n"
    sudo apt install --no-install-recommends cubic || echo 'UPDATE ERROR - CONTINUING ANYWAY'


    # SETUP CUBIC PROJECT

    os_version='21'
    os_codename='Vanessa'
    version_suffix=''
    build_date="$(date '+%y.%m.%d')"

    cubic_project_parent_path="${HOME}/Documents/Free Geek"
    cubic_project_path="${cubic_project_parent_path}/Linux Mint ${os_version} Cinnamon${version_suffix//-/ } Updated 20${build_date}"
    cubic_project_disk_path="${cubic_project_path}/custom-disk"
    cubic_project_root_path="${cubic_project_path}/custom-root"

    if [[ ! -f "${cubic_project_path}/cubic.conf" ]]; then
        # Create new project template based on these instructions: https://github.com/PJ-Singh-001/Cubic/issues/12#issuecomment-1013804874

        mkdir -p "${cubic_project_path}"

        cubic_conf_version='2022.06-72-release~202206302224~ubuntu22.04.1'
        # IMPORTANT: This cubic_conf_version should be set to a version of Cubic that is known the be compatible with the following "cubic.conf" format.
        # The currently installed Cubic version can be retrieved with "dpkg-query --show cubic" (or by copy-and-pasting it from a new "cubic.conf" file made by Cubic).
        # If the "cubic.conf" format is ever changed in the future, having this previous Cubic version listed in the "cubic.conf" file will let Cubic know that it needs to be migrated (and will show a screen like this: https://github.com/PJ-Singh-001/Cubic/wiki/Migrate-Page).
        # If this happens, and a future version of Cubic needs to migrate this "cubic.conf" format, this script should be updated with the new format and a new compatible Cubic version so that migration is not necessary for each new project.
        # Reference: https://github.com/PJ-Singh-001/Cubic/issues/12#issuecomment-1015001654

        current_timestamp="$(date '+%F %H:%M')"

        # MAKE SURE THAT ALL THE FOLLOWING VALUES ARE CORRECT FOR EACH NEW VERSION OF MINT
        cat << CUBIC_CONF_EOF > "${cubic_project_path}/cubic.conf"
[Project]
cubic_version = ${cubic_conf_version}
create_date = ${current_timestamp}
modify_date = ${current_timestamp}
directory = ${cubic_project_path}

[Original]
iso_file_name = linuxmint-${os_version}-cinnamon-64bit${version_suffix}.iso
iso_directory = ${cubic_project_parent_path}
iso_volume_id = Linux Mint ${os_version} Cinnamon 64-bit
iso_release_name = ${os_codename}
iso_disk_name = Linux Mint ${os_version} "${os_codename}" - Release amd64

[Custom]
iso_version_number = 20${build_date}
iso_file_name = linuxmint-${os_version}-cinnamon-64bit${version_suffix}-updated-${build_date}.iso
iso_directory = ${cubic_project_path}
iso_volume_id = Linux Mint ${os_version} Cinnamon 64-bit
iso_release_name = ${os_codename} - Updated 20${build_date}
iso_disk_name = Linux Mint ${os_version} Cinnamon 64-bit${version_suffix//-/ } "${os_codename} - Updated 20${build_date}"

[Status]
is_success_copy = False
is_success_extract = False
iso_template = 
casper_directory = 
squashfs_file_name = 
iso_checksum = 
iso_checksum_file_name = 

[Options]
update_os_release = False
boot_configurations = boot/grub/grub.cfg,boot/grub/loopback.cfg,isolinux/isolinux.cfg
compression = xz
CUBIC_CONF_EOF

        # AND DON'T FORGET TO ALWAYS MAKE SURE THAT THIS RELEASE URL IS ALSO CORRECT FOR EACH NEW VERSION OF MINT
        mkdir -p "${cubic_project_disk_path}/.disk"
        echo "http://www.linuxmint.com/rel_${os_codename,,}_cinnamon.php" > "${cubic_project_disk_path}/.disk/release_notes_url"
    fi

    nohup cubic "${cubic_project_path}" &> /dev/null & disown

    while [[ "$(wmctrl -l)"$'\n' != *$' cubic\n'* ]]; do
        sleep 1
    done
    
    wmctrl -r 'cubic' -e '0,0,0,-1,-1'

    until grep -qxF 'is_success_copy = True' "${cubic_project_path}/cubic.conf" && grep -qxF 'is_success_extract = True' "${cubic_project_path}/cubic.conf" && grep -qxF 'casper_directory = casper' "${cubic_project_path}/cubic.conf" && grep -qxF 'squashfs_file_name = filesystem' "${cubic_project_path}/cubic.conf"; do
        echo -e '\n>>> WAITING FOR CUBIC TO EXTRACT ORIGINAL ISO <<<\n>>> CLICK "NEXT" TWICE IN CUBIC <<<\n'
        sleep 5
    done

    custom_installer_resources_path="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"

    if ! WIFI_PASSWORD="$(< "${custom_installer_resources_path}/FG Reuse Wi-Fi Password.txt")" || [[ -z "${WIFI_PASSWORD}" ]]; then
        echo 'FAILED TO GET WI-FI PASSWORD'
        exit 1
    fi
    readonly WIFI_PASSWORD

    cp -f "${custom_installer_resources_path}/preseed/"* "${cubic_project_disk_path}/preseed/"
    # AFTER COPYING SCRIPTS, "production-ubiquity-verify.sh" NEEDS WI-FI PASSWORD PLACEHOLDER REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
    sed -i "s/'\[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(echo '$(echo -n "${WIFI_PASSWORD}" | base64)' | base64 -d)\"/" "${cubic_project_disk_path}/preseed/production-ubiquity-verify.sh"

    rm -rf "${cubic_project_disk_path}/preseed/dependencies"
    cp -rf "${custom_installer_resources_path}/dependencies" "${cubic_project_disk_path}/preseed/dependencies"
    rm -rf "${cubic_project_disk_path}/preseed/dependencies/java-jre"
    mkdir "${cubic_project_disk_path}/preseed/dependencies/java-jre"
    tar -xzf "${cubic_project_disk_path}/preseed/dependencies/jlink-jre-"*"_linux-x64.tar.gz" -C "${cubic_project_disk_path}/preseed/dependencies/java-jre" --strip-components '1'
    rm -f "${cubic_project_disk_path}/preseed/dependencies/jlink-jre-"*"_linux-x64.tar.gz"
    chmod +x "${cubic_project_disk_path}/preseed/"*'.sh' "${cubic_project_disk_path}/preseed/dependencies/xterm" "${cubic_project_disk_path}/preseed/dependencies/stress-ng" "${cubic_project_disk_path}/preseed/dependencies/cheese" "${cubic_project_disk_path}/preseed/dependencies/java-jre/bin/java" "${cubic_project_disk_path}/preseed/dependencies/java-jre/bin/keytool" "${cubic_project_disk_path}/preseed/dependencies/java-jre/lib/jexec" "${cubic_project_disk_path}/preseed/dependencies/java-jre/lib/jspawnhelper"

    cp -f "${cubic_project_parent_path}/iPXE for FG/ipxe-usbboot/ipxe-usbBoot"* "${cubic_project_disk_path}/casper/"

    cp -f "${custom_installer_resources_path}/iso-boot-menus/grub.cfg" "${cubic_project_disk_path}/boot/grub/"
    cp -f "${custom_installer_resources_path}/iso-boot-menus/isolinux.cfg" "${cubic_project_disk_path}/isolinux/"

    sudo cp -f "${custom_installer_resources_path}/cubic-terminal-commands-for-mint-installer.sh" "${cubic_project_root_path}/"
    sudo chmod +x "${cubic_project_root_path}/cubic-terminal-commands-for-mint-installer.sh"

    until [[ ! -f "${cubic_project_root_path}/cubic-terminal-commands-for-mint-installer.sh" ]]; do
        echo -e '\n>>> WAITING FOR CUBIC TERMINAL COMMANDS TO COMPLETE <<<\n>>> RUN "/cubic-terminal-commands-for-mint-installer.sh" IN CUBIC TERMINAL <<<\n'
        sleep 5
    done

    until [[ -f "${cubic_project_path}/linuxmint-${os_version}-cinnamon-64bit${version_suffix}-updated-${build_date}.iso" ]] && grep -qxF "iso_checksum_file_name = linuxmint-${os_version}-cinnamon-64bit${version_suffix}-updated-${build_date}.md5" "${cubic_project_path}/cubic.conf"; do
        echo -e '\n>>> CUBIC TERMINAL COMMANDS COMPLETED <<<\n>>> CLICK "NEXT" 3 TIMES AND THEN CLICK "GENERATE" TO CREATE THE ISO <<<\n'
        sleep 5
    done

    echo -e '\n>>> CUBIC HAS GENERATED THE CUSTOMIZED ISO <<<\n>>> DONE <<<\n'
    nohup xdg-open "${cubic_project_path}" &> /dev/null & disown
else
    echo '!!! THIS SCRIPT MUST BE RUN LOCALLY, NOT IN CUBIC TERMINAL !!!'
fi

read -r
