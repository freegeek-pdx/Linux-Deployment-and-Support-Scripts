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
    sudo apt install --no-install-recommends cubic


    # SETUP CUBIC PROJECT

    os_version='20.3'
    os_codename='Una'
    build_date="$(date '+%y.%m.%d')"

    cubic_project_parent_path="${HOME}/Documents/Free Geek"
    cubic_project_path="${cubic_project_parent_path}/Mint Live Rescue ${os_version} Cinnamon Updated 20${build_date}"
    cubic_project_disk_path="${cubic_project_path}/custom-disk"
    cubic_project_root_path="${cubic_project_path}/custom-root"

    if [[ ! -f "${cubic_project_path}/cubic.conf" ]]; then
        # Create new project template based on these instructions: https://github.com/PJ-Singh-001/Cubic/issues/12#issuecomment-1013804874

        mkdir -p "${cubic_project_path}"

        cubic_conf_version='2022.01-69-release~202201160230~ubuntu20.04.1'
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
iso_file_name = linuxmint-${os_version}-cinnamon-64bit.iso
iso_directory = ${cubic_project_parent_path}
iso_volume_id = Linux Mint ${os_version} Cinnamon 64-bit
iso_release_name = ${os_codename}
iso_disk_name = Linux Mint ${os_version} "${os_codename}" - Release amd64

[Custom]
iso_version_number = 20${build_date}
iso_file_name = mint-live-rescue-${os_version}-cinnamon-64bit-updated-${build_date}.iso
iso_directory = ${cubic_project_path}
iso_volume_id = Mint Live Rescue ${os_version} Cinnamon
iso_release_name = ${os_codename} - Updated 20${build_date}
iso_disk_name = Mint Live Rescue ${os_version} Cinnamon "${os_codename} - Updated 20${build_date}"

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

    until grep -qxF 'is_success_copy = True' "${cubic_project_path}/cubic.conf" && grep -qxF 'is_success_extract = True' "${cubic_project_path}/cubic.conf" && grep -qxF 'casper_directory = casper' "${cubic_project_path}/cubic.conf" && grep -qxF 'squashfs_file_name = filesystem' "${cubic_project_path}/cubic.conf"; do
        echo -e '\n>>> WAITING FOR CUBIC TO EXTRACT ORIGINAL ISO <<<\n>>> CLICK "NEXT" TWICE IN CUBIC <<<\n'
        sleep 5
    done

    custom_rescue_resources_path="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)"
    custom_installer_resources_path="${custom_rescue_resources_path}/../Mint Installer Resources"

    if ! WIFI_PASSWORD="$(cat "${custom_installer_resources_path}/FG Reuse Wi-Fi Password.txt")" || [[ -z "${WIFI_PASSWORD}" ]]; then
        echo 'FAILED TO GET WI-FI PASSWORD'
        exit 1
    fi
    readonly WIFI_PASSWORD

    sudo rm -rf "${cubic_project_root_path}/etc/skel/.local/qa-helper"
    sudo mkdir -p "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre"
    sudo tar -xzf "${custom_installer_resources_path}/dependencies/jlink-jre-"*"_linux-x64.tar.gz" -C "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre" --strip-components '1'
    sudo chmod +x "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre/bin/java" "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre/bin/keytool" "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre/lib/jexec" "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre/lib/jspawnhelper"


    # Make all Terminals and TTYs open directly as root (if needed).
    sudo sed -i 's/^Exec=gnome-terminal/Exec=sudo -i gnome-terminal/' "${cubic_project_root_path}/usr/share/applications/org.gnome.Terminal.desktop" # Make GUI Terminal launch as root.

    if ! grep -q 'sudo -i' "${cubic_project_root_path}/etc/skel/.bashrc"; then
        cat << 'BASHRC_EOF' | sudo tee -a "${cubic_project_root_path}/etc/skel/.bashrc" > /dev/null

# Make all Terminals and TTYs open directly as root (if needed).
if [[ "${EUID:-$(id -u)}" != '0' ]]; then
    sudo -i # This is important for TTYs, but the Terminal .desktop launcher has also been edited to launch as root so this is not always required.
fi
BASHRC_EOF
    fi

    sudo touch "${cubic_project_root_path}/etc/skel/.hushlogin" # Create ".hushlogin" file in home folder skeleton to not show "To run a command as administrator..." note in CLI mode since using "sudo" is no longer no necessary with the previous ".bashrc" addition. (Search ".hushlogin" within "/etc/bash.bashrc" to see why this works and what is prevents.)


    cat << 'BEEP_AS_MINT_FROM_ROOT_EOF' | sudo tee "${cubic_project_root_path}/usr/local/bin/beep" > /dev/null
#!/bin/bash

# Make our own "beep" command which plays ASCII BEL and then also "complete.oga" sound (via "paplay") as "mint" user (instead of as root) to be able to play either (or both) in all scenarios,
# since the actual actual "beep" command as well as "paplay" are unable to run as root for security reasons.
# This technique to make "paplay" work from within a root Terminal comes from: https://unix.stackexchange.com/a/602707

echo -ne '\a' # ASCII BEL
timeout 1.5 sudo -u mint XDG_RUNTIME_DIR="/run/user/$(id -u mint 2> /dev/null || echo '999')" paplay '/usr/share/sounds/freedesktop/stereo/complete.oga' 2> /dev/null # Run "paplay" as "mint" user so it works when called from root.
# Also, timeout after 1.5 seconds in case something causes it to hang longer than the 1 second duration of the audio file.
BEEP_AS_MINT_FROM_ROOT_EOF

    sudo chmod +x "${cubic_project_root_path}/usr/local/bin/beep"


    cat << 'STARTX_AS_MINT_FROM_ROOT_EOF' | sudo tee "${cubic_project_root_path}/usr/local/bin/startx" > /dev/null
#!/bin/bash

# Override "startx" to make sure it always runs at the "mint" user even when called from root.
# This can be done by creating a "startx" script in "/usr/local/bin/" since it will be found before the actual "start" at "/usr/bin/" because of the PATH order.

if ! xset q &> /dev/null; then
    sudo -u mint /usr/bin/startx # Must use the full path to the actual "startx" command so that this one is not called again, which would cause an infinite recursive loop.
else
    echo 'X already running'
    exit 1
fi
STARTX_AS_MINT_FROM_ROOT_EOF

    sudo chmod +x "${cubic_project_root_path}/usr/local/bin/startx"


    sudo cp -f "${custom_rescue_resources_path}/resources-for-cubic-project/setup-mint-live-rescue.sh" "${cubic_project_root_path}/usr/bin/setup-mint-live-rescue"
    # AFTER COPYING SCRIPTS, "setup-mint-live-rescue.sh" NEEDS WI-FI PASSWORD PLACEHOLDER REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
    sudo sed -i "s/'\[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(base64 -d <<< '$(echo -n "${WIFI_PASSWORD}" | base64)')\"/" "${cubic_project_root_path}/usr/bin/setup-mint-live-rescue"

    sudo cp -f "${custom_rescue_resources_path}/resources-for-cubic-project/profile-setup-mint-live-rescue.sh" "${cubic_project_root_path}/etc/profile.d/setup-mint-live-rescue.sh"
    sudo chmod +x "${cubic_project_root_path}/usr/bin/setup-mint-live-rescue" "${cubic_project_root_path}/etc/profile.d/setup-mint-live-rescue.sh"

    sudo cp -f "${custom_rescue_resources_path}/resources-for-cubic-project/MintLiveRescue-DesktopPicture.png" "${cubic_project_root_path}/usr/share/backgrounds/"
    sudo ln -sf "/usr/share/backgrounds/MintLiveRescue-DesktopPicture.png" "${cubic_project_root_path}/usr/share/backgrounds/linuxmint/default_background.jpg"

    sudo rm -f "${cubic_project_root_path}/usr/share/applications/ubiquity.desktop"
    sudo rm -f "${cubic_project_root_path}/usr/bin/ubiquity"

    cp -f "${cubic_project_parent_path}/iPXE for FG/ipxe-usbboot/ipxe-usbBoot"* "${cubic_project_disk_path}/casper/"

    cp -f "${custom_rescue_resources_path}/iso-boot-menus/grub.cfg" "${cubic_project_disk_path}/boot/grub/"
    cp -f "${custom_rescue_resources_path}/iso-boot-menus/isolinux.cfg" "${cubic_project_disk_path}/isolinux/"

    if [[ ! -f "${cubic_project_root_path}/usr/bin/apfs-fuse" ]]; then # Do not bother re-building and installing if this script gets run another time on the same Cubic project
        # apfs-fuse: https://github.com/sgan81/apfs-fuse
        # This is built here instead of within "cubic-terminal-commands-for-mint-live-rescue.sh" so that the build tools don't need to be installed into the image and only the final binary is copied over.
        sudo apt install --no-install-recommends -y fuse libfuse-dev bzip2 libbz2-dev zlib1g-dev cmake g++ git libattr1-dev cmake-curses-gui
        cd '/tmp'
        sudo rm -rf 'apfs-fuse'
        git clone 'https://github.com/sgan81/apfs-fuse.git'
        cd 'apfs-fuse'
        git submodule init
        git submodule update
        mkdir 'build'
        cd 'build'
        cmake -D USE_FUSE3=OFF ..
        make
        sudo cp 'apfs'* "${cubic_project_root_path}/usr/bin"
        cd '../../'
        sudo rm -r 'apfs-fuse'
    fi

    sudo cp -f "${custom_rescue_resources_path}/cubic-terminal-commands-for-mint-live-rescue.sh" "${cubic_project_root_path}/"
    sudo chmod +x "${cubic_project_root_path}/cubic-terminal-commands-for-mint-live-rescue.sh"

    until [[ ! -f "${cubic_project_root_path}/cubic-terminal-commands-for-mint-live-rescue.sh" ]]; do
        echo -e '\n>>> WAITING FOR CUBIC TERMINAL COMMANDS TO COMPLETE <<<\n>>> RUN "/cubic-terminal-commands-for-mint-live-rescue.sh" IN CUBIC TERMINAL <<<\n'
        sleep 5
    done

    until [[ -f "${cubic_project_path}/mint-live-rescue-${os_version}-cinnamon-64bit-updated-${build_date}.iso" ]] && grep -qxF "iso_checksum_file_name = mint-live-rescue-${os_version}-cinnamon-64bit-updated-${build_date}.md5" "${cubic_project_path}/cubic.conf"; do
        echo -e '\n>>> CUBIC TERMINAL COMMANDS COMPLETED <<<\n>>> CLICK "NEXT" 3 TIMES AND THEN CLICK "GENERATE" TO CREATE THE ISO <<<\n'
        sleep 5
    done

    echo -e '\n>>> CUBIC HAS GENERATED THE CUSTOMIZED ISO <<<\n>>> DONE <<<\n'
    nohup xdg-open "${cubic_project_path}" &> /dev/null & disown
else
    echo '!!! THIS SCRIPT MUST BE RUN LOCALLY, NOT IN CUBIC TERMINAL !!!'
fi

read -r
