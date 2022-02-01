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

echo 'CREATING LATEST JLINK JRE FOR QA HELPER ON LINUX'

temp_folder_path="/tmp/qa-helper-jlink-jre"

rm -rf "${temp_folder_path}"
mkdir -p "${temp_folder_path}"

jdk_download_url="$(curl -m 5 -sL "https://jdk.java.net$(curl -m 5 -sL 'https://jdk.java.net' | awk -F '"' '($3 == ">Ready for use: <a href=") { print $4; exit }')" | awk -F '"' '/_linux-x64_bin.tar.gz"/ { print $2; exit }')"
jdk_archive_filename="$(basename "${jdk_download_url}")"
echo -e "\nDOWNLOADING \"${jdk_download_url}\"..."
curl --connect-timeout 5 --progress-bar -L "${jdk_download_url}" -o "${temp_folder_path}/${jdk_archive_filename}" || exit 1

echo -e "\nUNARCHIVING \"${jdk_archive_filename}\"..."
tar -xzf "${temp_folder_path}/${jdk_archive_filename}" -C "${temp_folder_path}" || exit 1
rm -f "${temp_folder_path}/${jdk_archive_filename}"

cd "${temp_folder_path}" || exit 1

jdk_version="$(echo "${jdk_archive_filename}" | awk -F 'openjdk-|_linux' '{ print $2; exit }')"
echo -e "\nCREATING JLINK JRE ${jdk_version}..."
"jdk-${jdk_version}/bin/jlink" --add-modules 'java.base,java.desktop,java.logging' --strip-debug --no-man-pages --no-header-files --compress '2' --output 'java-jre'
# java.datatransfer, java.prefs, and java.xml are included automatically with java.desktop
rm -rf "jdk-${jdk_version}"

jlink_jre_filename="jlink-jre-${jdk_version}_linux-x64.tar.gz"
echo -e "\nARCHIVING JLINK JRE ${jlink_jre_filename}..."
tar -czvf "${jlink_jre_filename}" 'java-jre'
rm -rf 'java-jre'

echo -e "\nMOVING \"${jlink_jre_filename}\" INTO MINT INSTALLER DEPENDENCIES..."
mint_installer_resources_path="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)/../Mint Installer Resources"
rm -r "${mint_installer_resources_path}/dependencies/${jlink_jre_filename}"
mv -f "${jlink_jre_filename}" "${mint_installer_resources_path}/dependencies/"
nohup xdg-open "${mint_installer_resources_path}/dependencies/" &> /dev/null & disown

echo -e "\nDONE CREATING JLINK JRE ${jdk_version} FOR QA HELPER ON LINUX\n"
rm -rf "${temp_folder_path}"

read -r
