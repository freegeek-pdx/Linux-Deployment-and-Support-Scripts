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

# THIS SCRIPT MUST BE RUN *INTERACTIVELY* IN A TERMINAL
# In Linux Mint, double-click the file and choose "Run in Terminal".
# If the Terminal window closes itself, that means an error happened causing the script to exit prematurely.
# When everything is successful, the Terminal window will stay open until you close it manually or hit the Enter key.

echo -e '\nSETUP MINT INSTALLER CUBIC PROJECT\n'

if [[ "$(hostname)" == 'cubic' ]]; then
    >&2 echo 'ERROR: THIS SCRIPT MUST BE RUN LOCALLY, NOT IN CUBIC TERMINAL'
    read -r
    exit 1
fi

os_version="$1"
version_suffix="$2"

if [[ -z "${os_version}" && -z "${version_suffix}" ]]; then
    read -rp 'OS Version: ' os_version
    read -rp 'Version Suffix (can be blank): ' version_suffix
fi

if [[ -z "${os_version}" ]]; then
    >&2 echo -e '\nERROR: MUST SPECIFY OS VERSION'
    read -r
    exit 2
fi

os_codename="$(curl -m 5 -sfL 'https://www.linuxmint.com/download_all.php' | xmllint --html --xpath "//td[text()='${os_version}']/following-sibling::td[1]/text()" - 2> /dev/null)"

if [[ -z "${os_codename}" ]]; then
    >&2 echo -e "\nERROR: FAILED TO RETRIEVE CODENAME FOR OS VERSION ${os_version} (INTERNET & \"libxml2-utils\" REQUIRED)"
    read -r
    exit 3
fi

release_notes_url="http://www.linuxmint.com/rel_${os_codename,,}_cinnamon.php"

if ! curl -m 5 -sfL "${release_notes_url}" | grep -q "Mint ${os_version} \"${os_codename}\""; then
    >&2 echo -e "\nERROR: FAILED TO VERIFY RELEASE NOTES URL FOR CODENAME \"${os_codename}\" OF OS VERSION ${os_version} (INTERNET REQUIRED)"
    read -r
    exit 4
fi

echo "
OS Version: ${os_version}
OS Codename: ${os_codename}
Version Suffix: ${version_suffix:-N/A}"

cubic_project_parent_path="${HOME}/Documents/Free Geek"
source_iso_name="linuxmint-${os_version}-cinnamon-64bit${version_suffix}.iso"

if [[ -f "${cubic_project_parent_path}/${source_iso_name}" ]]; then
    echo -e "\nPRESS ENTER TO CONTINUE WITH ISO PATH \"${cubic_project_parent_path}/${source_iso_name}\" (OR PRESS CONTROL-C TO CANCEL)"
    read -r
else
    >&2 echo -e "\nERROR: SOURCE ISO NOT FOUND AT \"${cubic_project_parent_path}/${source_iso_name}\""
    read -r
    exit 5
fi

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

echo -e "\n>>> $(command -v cubic &> /dev/null && echo 'UPDATING' || echo 'INSTALLING') CUBIC <<<\n"
sudo apt install --no-install-recommends cubic || echo 'UPDATE ERROR - CONTINUING ANYWAY'


# SETUP CUBIC PROJECT

build_date="$(date '+%y.%m.%d')"

cubic_project_path="${cubic_project_parent_path}/Linux Mint ${os_version} Cinnamon${version_suffix//-/ } Updated 20${build_date}"
cubic_project_disk_path="${cubic_project_path}/custom-disk"
cubic_project_root_path="${cubic_project_path}/custom-root"

if [[ ! -f "${cubic_project_path}/cubic.conf" ]]; then
    # Create new project template based on these instructions: https://github.com/PJ-Singh-001/Cubic/issues/12#issuecomment-1013804874

    mkdir -p "${cubic_project_path}"

    cubic_conf_version='2022.12-74-release~202212012321~ubuntu22.04.1'
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
iso_file_name = ${source_iso_name}
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
squashfs_directory = 
squashfs_file_name = 
casper_directory = 
iso_checksum = 
iso_checksum_file_name = 

[Options]
update_os_release = 
boot_configurations = boot/grub/grub.cfg, boot/grub/loopback.cfg, isolinux/isolinux.cfg
compression = zstd
CUBIC_CONF_EOF
    # IMPORTANT NOTES ABOUT COMPRESSION ALGORITHM:
    # DO NOT use "xz" compression even though it creates the smallest "squashfs" (and ISO) because it actually slows down loading the live OS.
    # DO NOT use "lzma" compression because it is deprecated and also cannot be loaded by the kernel for the "squashfs".
    # "zstd" or any faster/larger compressions all load the live OS quickly, which can be up to about a minute faster than when using "xz" compression!
    # The live OS loading speed difference between "zstd" and other faster/larger compressions seems to very negligible and pretty equally fast in real world usage.
    # Here are some good benchmarks of the decompression speed of different compressions for the "squashfs" file: https://github.com/AgentD/squashfs-tools-ng/blob/master/doc/benchmark.txt
    # Even though there are actual speed differences between the "zstd" and other faster/larger compressions, in real world usage they are all pretty equally fast
    # because other factors such as running from a USB or via netboot (or other hardware factors) will be the bottleneck rather than just the raw decompression speed.
    # For some more context, portions of the "squashfs" file are decompressed on-demand as the live OS loads and runs rather than being decompressed all at once,
    # which is is why the decompression speed is so important for the live OS loading and running preformance.
    # So, using "zstd" since it has the best balance of smaller image size with fast live OS loading speed.

    # AND DON'T FORGET TO ALWAYS MAKE SURE THAT THIS RELEASE URL IS ALSO CORRECT FOR EACH NEW VERSION OF MINT
    mkdir -p "${cubic_project_disk_path}/.disk"
    echo "${release_notes_url}" > "${cubic_project_disk_path}/.disk/release_notes_url"
fi

nohup cubic "${cubic_project_path}" &> /dev/null & disown

while [[ "$(wmctrl -l)"$'\n' != *$' cubic\n'* ]]; do
    sleep 1
done

wmctrl -r 'cubic' -e '0,-100,-100,-1,-1' # The "Cubic" window will not go all the way to the top right corner if "0,0" are specified, so use "-100,-100" instead to accomodate this behavior (and "wmctrl" will not put the window off screen even if "-100" is actuall too much).

until grep -qxF 'is_success_copy = True' "${cubic_project_path}/cubic.conf" && grep -qxF 'is_success_extract = True' "${cubic_project_path}/cubic.conf" && grep -qxF 'casper_directory = casper' "${cubic_project_path}/cubic.conf" && grep -qxF 'squashfs_file_name = filesystem' "${cubic_project_path}/cubic.conf"; do
    echo -e '\n>>> WAITING FOR CUBIC TO EXTRACT ORIGINAL ISO <<<\n>>> CLICK "NEXT" TWICE IN CUBIC <<<\n'
    sleep 5
done

custom_installer_resources_path="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"

if ! WIFI_PASSWORD="$(< "${custom_installer_resources_path}/FG Reuse Wi-Fi Password.txt")" || [[ -z "${WIFI_PASSWORD}" ]]; then
    >&2 echo -e '\nERROR: FAILED TO GET WI-FI PASSWORD\n'
    read -r
    exit 6
fi
readonly WIFI_PASSWORD

# NOTE: Manually copy the ISO "initrd" and "vmlinuz" files to full OS "/boot" folder so that running "update-initramfs -u" in "cubic-terminal-commands-for-mint-installer.sh" will always work when customizing the "initrd" to add USB network adapter drivers for USB live boots to be able to load internet with USB network adapters.
# If the "initrd" file is not copied manually, and there was no kernel update when system updates were run in "cubic-terminal-commands-for-mint-installer.sh" (which would really only happen when when building a new custom ISO for a new version that has just come out), then "update-initramfs -u" will fail to create new customized "initrd" file since the file will not be found (the 2 output lines will be "Available versions:" [with no versions listed] and "Nothing to do, exiting.").
# And, the matching "vmlinuz" file must be copied the full OS "/boot" folder for "Cubic" to be able to choose the customized kernel files (to be copied back to the ISO) rather than only listing the original kernel files from the ISO (https://github.com/PJ-Singh-001/Cubic/issues/140#issuecomment-1344646802).
# But, if a kernel update was done during system updated in "cubic-terminal-commands-for-mint-installer.sh" then "update-initramfs -u" would work properly either way and manually copying these files is not necessary (but doesn't hurt). So, always do copy these files just to be sure the kernel customization will all always work.
sudo cp "${cubic_project_disk_path}/casper/initrd.lz" "${cubic_project_root_path}/boot/$(readlink "${cubic_project_root_path}/boot/initrd.img" || find "${cubic_project_root_path}/boot" -mindepth 1 -maxdepth 1 -name 'config-*' -exec basename {} \; | sort -rV | head -1 | sed 's/^config-/initrd.img-/')" # Prior to Mint 20.0, the symlinks in "/boot/" will not exist to easily know the correct latest version filename to copy/rename the files to, so instead fallback on using version of the newest "config" file.
sudo cp "${cubic_project_disk_path}/casper/vmlinuz" "${cubic_project_root_path}/boot/$(readlink "${cubic_project_root_path}/boot/vmlinuz" || find "${cubic_project_root_path}/boot" -mindepth 1 -maxdepth 1 -name 'config-*' -exec basename {} \; | sort -rV | head -1 | sed 's/^config-/vmlinuz-/')"

cp -f "${custom_installer_resources_path}/preseed/"* "${cubic_project_disk_path}/preseed/"
# AFTER COPYING SCRIPTS, "production-ubiquity-verify.sh" NEEDS WI-FI PASSWORD PLACEHOLDER REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
sed -i "s/'\[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(echo '$(echo -n "${WIFI_PASSWORD}" | base64)' | base64 -d)\"/" "${cubic_project_disk_path}/preseed/production-ubiquity-verify.sh"

rm -rf "${cubic_project_disk_path}/preseed/dependencies"
cp -rf "${custom_installer_resources_path}/dependencies" "${cubic_project_disk_path}/preseed/dependencies"
rm -rf "${cubic_project_disk_path}/preseed/dependencies/java-jre"
mkdir "${cubic_project_disk_path}/preseed/dependencies/java-jre"
tar -xzf "${cubic_project_disk_path}/preseed/dependencies/jlink-jre-"*"_linux-x64.tar.gz" -C "${cubic_project_disk_path}/preseed/dependencies/java-jre" --strip-components '1'
rm -f "${cubic_project_disk_path}/preseed/dependencies/jlink-jre-"*"_linux-x64.tar.gz"
chmod +x "${cubic_project_disk_path}/preseed/"*'.sh' "${cubic_project_disk_path}/preseed/dependencies/"{xterm,stress-ng,cheese} "${cubic_project_disk_path}/preseed/dependencies/geekbench/geekbench"{5,_x86_64} "${cubic_project_disk_path}/preseed/dependencies/java-jre/bin/"{java,keytool} "${cubic_project_disk_path}/preseed/dependencies/java-jre/lib/"{jexec,jspawnhelper}

cp -f "${cubic_project_parent_path}/iPXE for FG/ipxe-usbboot/ipxe-usbBoot"* "${cubic_project_disk_path}/casper/"

# DO NOT JUST COPY BOOT MENUS SINCE OS VERSION PLACEHOLDER NEED TO BE REPLACED WITH THE OS VERSION BEING BUILT.
# NOTE: Starting in Mint 21, GRUB is also used in Legacy BIOS mode instead of only in UEFI mode.
# So, the "isolinux.cfg" menu is no longer used in Mint 21 and newer since PXELINUX/ISOLINUX will never be loaded in Legacy BIOS mode, but still keeping the menu in place since the customizations are already done from use in previous Mint versions.
sed "s/\[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OS VERSION\]/${os_version}${version_suffix//-/ }/" "${custom_installer_resources_path}/iso-boot-menus/grub.cfg" > "${cubic_project_disk_path}/boot/grub/grub.cfg"
sed "s/\[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OS VERSION\]/${os_version}${version_suffix//-/ }/" "${custom_installer_resources_path}/iso-boot-menus/isolinux.cfg" > "${cubic_project_disk_path}/isolinux/isolinux.cfg"

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

read -r
