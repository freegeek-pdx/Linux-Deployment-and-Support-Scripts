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

# THIS SCRIPT MUST BE RUN ON THE NETBOOT SERVER AFTER THE ISO HAS BEEN UPLOADED TO THE CORRECT LOCATION
# The entire latest version of the "Mint Installer Resources" folder must also be uploaded to the netboot server along with this script.
# This script should then be run from within the "Mint Installer Resources" folder that has been uploaded to the netboot server.

set -ex

os_version="$1"
version_suffix="$2"
desktop="${3:-cinnamon}"

if [[ -z "${os_version}" ]]; then
    >&2 echo -e '\nERROR: MUST SPECIFY OS VERSION AS FIRST ARGUMENT\n'
    exit 1
fi

only_update_scripts="$([[ "$4" == 'scripts' ]] && echo 'true' || echo 'false')"

if ! $only_update_scripts; then # Also allow optional args to be omitted when only updating scripts.
    if [[ "${version_suffix}" == 'scripts' ]]; then
        only_update_scripts=true
        version_suffix=''
    fi

    if [[ "${desktop}" == 'scripts' ]]; then
        only_update_scripts=true
        desktop='cinnamon'
    fi
fi


# ALWAYS USE MOST RECENT ISO FOR THE SPECIFIED VERSION:
# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
# shellcheck disable=SC2012
source_iso_path="$(ls -t "/srv/setup-resources/images/linuxmint-${os_version}-${desktop}-64bit${version_suffix}"*'.iso' | head -1)"

# UNCOMMENT TO OVERRIDE WITH SPECIFIC ISO:
# source_iso_path="/srv/setup-resources/images/linuxmint-${os_version}-${desktop}-64bit${version_suffix}.iso"
# source_iso_path="/srv/setup-resources/images/linuxmint-${os_version}-${desktop}-64bit${version_suffix}-updated-YY.MM.DD.iso"

if [[ -f "${source_iso_path}" ]]; then
    echo -e "\nPRESS ENTER TO CONTINUE WITH ISO PATH \"${source_iso_path}\" (OR PRESS CONTROL-C TO CANCEL)"
    read -r
else
    >&2 echo -e "\nERROR: SOURCE ISO NOT FOUND AT \"${source_iso_path:-/srv/setup-resources/images/linuxmint-${os_version}-${desktop}-64bit${version_suffix}*.iso}\"\n"
    exit 2
fi

custom_installer_resources_path="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"

custom_installer_preseed_path="${custom_installer_resources_path}/preseed"
custom_installer_dependencies_path="${custom_installer_resources_path}/dependencies"

tmp_mount_path="/srv/setup-resources/mountpoint-mint-${os_version}-${desktop}${version_suffix}"

output_tftp_path="/srv/tftp/mint-${os_version}-${desktop}${version_suffix}"
output_nfs_path="/srv/nfs/mint-${os_version}-${desktop}${version_suffix}"

if ! $only_update_scripts; then
    if [[ -d "${output_nfs_path}.old" || -d "${output_tftp_path}.old" ]]; then sudo rm -rf "${output_nfs_path}.old" "${output_tftp_path}.old"; fi
    if [[ -d "${output_nfs_path}" ]]; then mv "${output_nfs_path}" "${output_nfs_path}.old"; fi
    if [[ -d "${output_tftp_path}" ]]; then mv "${output_tftp_path}" "${output_tftp_path}.old"; fi

    if [[ -d "${tmp_mount_path}/boot" ]]; then sudo umount "${tmp_mount_path}"; fi

    rm -rf "${tmp_mount_path}"
    mkdir -p "${tmp_mount_path}"
    sudo mount "${source_iso_path}" "${tmp_mount_path}"

    mkdir -p "${output_tftp_path}"
    cp "${tmp_mount_path}/casper/initrd"* "${tmp_mount_path}/casper/vmlinuz" "${output_tftp_path}/"

    time rsync --progress -aHv "${tmp_mount_path}/" "${output_nfs_path}"

    sudo umount "${tmp_mount_path}"
    rm -rf "${tmp_mount_path}"
fi

chmod u+w "${output_nfs_path}" "${output_nfs_path}/preseed"

if [[ "${desktop}" == 'cinnamon' ]]; then
    if ! WIFI_PASSWORD="$(< "${custom_installer_resources_path}/FG Reuse Wi-Fi Password.txt")" || [[ -z "${WIFI_PASSWORD}" ]]; then
        echo -e '\nERROR: FAILED TO GET WI-FI PASSWORD\n'
        exit 3
    fi
    readonly WIFI_PASSWORD

    cp -f "${custom_installer_preseed_path}/production-ubiquity"* "${output_nfs_path}/preseed/"
    # AFTER COPYING SCRIPTS, "production-ubiquity-verify.sh" NEEDS WI-FI PASSWORD PLACEHOLDER REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
    sed -i "s/'\[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(echo '$(echo -n "${WIFI_PASSWORD}" | base64)' | base64 -d)\"/" "${output_nfs_path}/preseed/production-ubiquity-verify.sh"

    cp -f "${output_nfs_path}/preseed/production-ubiquity.seed" "${output_nfs_path}/preseed/testing-ubiquity.seed"
    sed -i 's|preseed/production-|preseed/testing-|' "${output_nfs_path}/preseed/testing-ubiquity.seed"
    cp -f "${output_nfs_path}/preseed/production-ubiquity-verify.sh" "${output_nfs_path}/preseed/testing-ubiquity-verify.sh"
    cp -f "${output_nfs_path}/preseed/production-ubiquity-finish.sh" "${output_nfs_path}/preseed/testing-ubiquity-finish.sh"
    cp -f "${output_nfs_path}/preseed/production-ubiquity-packages.sh" "${output_nfs_path}/preseed/testing-ubiquity-packages.sh"
fi

cp -f "${custom_installer_preseed_path}/production-liveboot"* "${output_nfs_path}/preseed/"

cp -f "${output_nfs_path}/preseed/production-liveboot.seed" "${output_nfs_path}/preseed/testing-liveboot.seed"
sed -i 's|preseed/production-|preseed/testing-|' "${output_nfs_path}/preseed/testing-liveboot.seed"
cp -f "${output_nfs_path}/preseed/production-liveboot-finish.sh" "${output_nfs_path}/preseed/testing-liveboot-finish.sh"

chown :adm "${output_nfs_path}/preseed/"*
chmod g+w "${output_nfs_path}/preseed/"*
chmod +x "${output_nfs_path}/preseed/"*'.sh'

sudo rm -rf "${output_nfs_path}/preseed/dependencies"
cp -r "${custom_installer_dependencies_path}" "${output_nfs_path}/preseed/dependencies"
rm -rf "${output_nfs_path}/preseed/dependencies/java-jre"
mkdir "${output_nfs_path}/preseed/dependencies/java-jre"
tar -xzf "${output_nfs_path}/preseed/dependencies/jlink-jre-"*"_linux-x64.tar.gz" -C "${output_nfs_path}/preseed/dependencies/java-jre" --strip-components '1'
rm -f "${output_nfs_path}/preseed/dependencies/jlink-jre-"*"_linux-x64.tar.gz"
chmod +x "${output_nfs_path}/preseed/dependencies/"{xterm,stress-ng,cheese} "${output_nfs_path}/preseed/dependencies/geekbench/geekbench"{6,_x86_64,_avx2} "${output_nfs_path}/preseed/dependencies/java-jre/bin/"{java,keytool} "${output_nfs_path}/preseed/dependencies/java-jre/lib/"{jexec,jspawnhelper}

echo -e "\nDONE SETTING UP MINT ${os_version} INSTALLER FOR NETBOOT: ${source_iso_path}\n"
