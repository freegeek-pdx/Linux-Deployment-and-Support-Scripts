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

# SET THIS SCRIPT TO RUN EVERY 5 MINUTES BY ADDING THE FOLLOWING LINE TO SUDO CRONTAB:
# */5 * * * * /srv/tftp/boot/ipxe-variants/reset-default-ipxe-variants.sh 2>&1 | logger -t reset-default-ipxe-variants

cd '/srv/tftp/boot/ipxe-variants/' || exit 1

declare -A default_ipxe_filenames_for_platforms=(
	[BIOS]='ipxe-undiOnly.kpxe'
	[UEFI]='ipxe-snpOnly.efi'
)

for this_platform in "${!default_ipxe_filenames_for_platforms[@]}"; do
	this_ipxe_default_filename_for_platform="${default_ipxe_filenames_for_platforms[${this_platform}]}"
	
	install_ipxe_path="../ipxe.$([[ "${this_platform}" == 'UEFI' ]] && echo 'efi' || echo 'pxe')"
	
	if [[ -f "JUST-SET-${this_platform}-IPXE-TO-ALTERNATE" ]]; then
		if rm "JUST-SET-${this_platform}-IPXE-TO-ALTERNATE"; then
			echo "DELETED 'JUST-SET-${this_platform}-IPXE-TO-ALTERNATE' FLAG AND SKIPPING ONE RESET CYCLE"
		else
			echo "!!! ERROR: FAILED TO DELETE 'JUST-SET-${this_platform}-IPXE-TO-ALTERNATE' FLAG"
		fi
	elif ! cmp -s "${this_ipxe_default_filename_for_platform}" "${install_ipxe_path}"; then
		if cp "${this_ipxe_default_filename_for_platform}" "${install_ipxe_path}"; then
			echo "RESET ${this_platform} iPXE TO '${this_ipxe_default_filename_for_platform}'"
		else
			echo "!!! ERROR: FAILED TO RESET ${this_platform} iPXE TO '${this_ipxe_default_filename_for_platform}'"
		fi
	else
		echo "${this_platform} iPXE ALREADY SET TO '${this_ipxe_default_filename_for_platform}'"
	fi
	
	# Make sure php script can always overwrite the installed iPXE files.
	chown 'www-data' "${install_ipxe_path}"
	chgrp 'www-data' "${install_ipxe_path}"
done
