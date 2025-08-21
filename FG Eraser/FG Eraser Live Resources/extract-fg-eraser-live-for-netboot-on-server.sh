#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# MIT License
#
# Copyright (c) 2024 Free Geek
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

set -ex

# ALWAYS USE MOST RECENT ISO:
# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
# shellcheck disable=SC2012
source_iso_path="$(ls -t "/srv/setup-resources/images/fg-eraser-live-updated-"*'.iso' | head -1)"

# UNCOMMENT TO OVERRIDE WITH SPECIFIC ISO:
# source_iso_path="/srv/setup-resources/images/fg-eraser-live-updated-YY.MM.DD.iso"

if [[ -f "${source_iso_path}" ]]; then
	echo -e "\nPRESS ENTER TO CONTINUE WITH ISO PATH \"${source_iso_path}\" (OR PRESS CONTROL-C TO CANCEL)"
	read -r
else
	>&2 echo -e "\nERROR: SOURCE ISO NOT FOUND AT \"${source_iso_path:-/srv/setup-resources/images/fg-eraser-live-updated-*.iso}\"\n"
	exit 1
fi

output_tftp_path='/srv/tftp/fg-eraser-live'
tmp_mount_path='/srv/setup-resources/mountpoint-fg-eraser-live'

if [[ -d "${output_tftp_path}.old" ]]; then sudo rm -rf "${output_tftp_path}.old"; fi
if [[ -d "${output_tftp_path}" ]]; then mv "${output_tftp_path}" "${output_tftp_path}.old"; fi

if [[ -d "${tmp_mount_path}/boot" ]]; then sudo umount "${tmp_mount_path}"; fi

rm -rf "${tmp_mount_path}"
mkdir -p "${tmp_mount_path}"
sudo mount "${source_iso_path}" "${tmp_mount_path}"

time rsync --progress -aHv --min-size '1mb' --no-links "${tmp_mount_path}/live/" "${output_tftp_path}"

sudo umount "${tmp_mount_path}"
rm -rf "${tmp_mount_path}"

echo -e "\nDONE EXTRACTING FG ERASER LIVE FOR NETBOOT: ${source_iso_path}\n"
