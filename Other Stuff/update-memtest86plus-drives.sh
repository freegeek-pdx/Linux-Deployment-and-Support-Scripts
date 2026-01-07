#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# MIT License
#
# Copyright (c) 2025 Free Geek
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

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

echo -e '\nUpdate Memtest86+ Drives'

trim_and_squeeze_whitespace() {
	{ [[ "$#" -eq 0 && ! -t 0 ]] && cat - || printf '%s ' "$@"; } | tr -s '[:space:]' ' ' | sed -E 's/^ | $//g'
	# NOTE 1: Must only read stdin when NO arguments are passed because if this function is called with arguments but is within a block that
	# has another stdin piped or redirected to it, (such as a "while read" loop) the function will detect the stdin from the block and read
	# it instead of the arguments being passed which results in the function reading the wrong input as well as ending the loop prematurely.
	# NOTE 2: When multiple arguments are passed, DO NOT use "$*" since that would join on current "IFS" which may not be default which means
	# space may not be the first character and could instead be some non-whitespace character that would not be properly trimmed and squeezed.
	# Instead, use "printf" to manually join all arguments with a space (which will leave a trailing space, but that will get trimmed anyways).
	# NOTE 3: After "tr -s" there could still be a single leading and/or trailing space, so use "sed" to remove them.
}

human_readable_size_from_bytes() {
	bytes="$1"

	if [[ ! "${bytes}" =~ ^[0123456789]+$ ]]; then
		echo 'INVALID SIZE'
		return 1
	fi

	size_precision='%.1f' # Show sizes with a single decimal of precision.

	if converted_size="$(numfmt --to si --round nearest --format "${size_precision}" "$1" 2> /dev/null)"; then
		converted_size_number="${converted_size%%[^0123456789.]*}" # Remove any trailing non-digits to get size number.
		converted_size_number="${converted_size_number%.0}" # Sizes will always have 1 decimal precision, but not want to display ".0" so remove it from tail if it exists.

		converted_size_suffix="${converted_size##*[0123456789.]}" # Remove any leading digits to get suffix.
		if [[ -z "${converted_size_suffix}" ]]; then # Bytes will have no suffix, so add it if needed.
			converted_size_suffix="Byte$( (( converted_size_number != 1 )) && echo 's' )"
		else
			converted_size_suffix+='B' # All other suffixes will be like "K", "M", "G", etc., so add "B" to make them "KB", "MB", "GB", etc.
		fi

		echo "${converted_size_number} ${converted_size_suffix}" # Original output didn't have space between number and suffix, but include one for style.
	else
		echo 'UNKNOWN SIZE'
	fi
}

human_readable_duration_from_seconds() { # Based On: https://stackoverflow.com/a/39452629
	total_seconds="$1"
	if [[ ! "${total_seconds}" =~ ^[0123456789]+$ ]]; then
		echo 'INVALID Seconds'
		return 1
	fi

	duration_output=''

	display_days="$(( total_seconds / 86400 ))"
	if (( display_days > 0 )); then
		duration_output="${display_days} Day$( (( display_days != 1 )) && echo 's' )"
	fi

	display_hours="$(( (total_seconds % 86400) / 3600 ))"
	if (( display_hours > 0 )); then
		if [[ -n "${duration_output}" ]]; then
			duration_output+=', '
		fi
		duration_output+="${display_hours} Hour$( (( display_hours != 1 )) && echo 's' )"
	fi

	display_minutes="$(( (total_seconds % 3600) / 60 ))"
	if (( display_minutes > 0 )); then
		if [[ -n "${duration_output}" ]]; then
			duration_output+=', '
		fi
		duration_output+="${display_minutes} Minute$( (( display_minutes != 1 )) && echo 's' )"
	fi

	display_seconds="$(( total_seconds % 60 ))"
	if (( display_seconds > 0 )) || [[ -z "${duration_output}" ]]; then
		if [[ -n "${duration_output}" ]]; then
			duration_output+=', '
		fi
		duration_output+="${display_seconds} Second$( (( display_seconds != 1 )) && echo 's' )"
	fi

	echo "${duration_output}"
}


echo -e '\n\nDetected USB Storage Devices:\n'

detected_usb3_20gbps_connection_count=0
detected_usb3_10gbps_connection_count=0
detected_usb3_5gbps_connection_count=0
detected_usb2_connection_count=0
detected_usb1_connection_count=0
output_this_lsusb_bus_section=false
this_lsusb_bus_section=''
while IFS='' read -r this_lsusb_line; do
	if [[ "${this_lsusb_line}" == '/:  Bus '* ]]; then
		if $output_this_lsusb_bus_section; then
			echo "${this_lsusb_bus_section}"
		fi

		this_lsusb_bus_section="${this_lsusb_line}"

		output_this_lsusb_bus_section=false
	elif [[ -n "${this_lsusb_bus_section}" ]]; then
		this_lsusb_bus_section+=$'\n'"${this_lsusb_line}"
		if [[ "${this_lsusb_line}" == *'Class=Mass Storage'* ]]; then
			output_this_lsusb_bus_section=true

			if [[ "${this_lsusb_line}" == *' 20000M' ]]; then
				(( detected_usb3_20gbps_connection_count ++ ))
			elif [[ "${this_lsusb_line}" == *' 10000M' ]]; then
				(( detected_usb3_10gbps_connection_count ++ ))
			elif [[ "${this_lsusb_line}" == *' 5000M' ]]; then
				(( detected_usb3_5gbps_connection_count ++ ))
			elif [[ "${this_lsusb_line}" == *' 480M' ]]; then
				(( detected_usb2_connection_count ++ ))
			elif [[ "${this_lsusb_line}" == *' 12M' || "${this_lsusb_line}" == *' 1.5M' ]]; then
				(( detected_usb1_connection_count ++ ))
			fi
		fi
	fi
done < <(lsusb -tv)

if $output_this_lsusb_bus_section; then
	echo -e "${this_lsusb_bus_section}\n"
fi

memtest86plus_drives_list=''

while IFS='"' read -r _ this_drive_full_id _ this_drive_size_bytes _ this_drive_transport _ this_drive_type _ this_drive_read_only _ this_drive_brand _ this_drive_model; do
	# Split lines on double quotes (") to easily extract each value out of each "lsblk" line, which will be like: NAME="/dev/sda" SIZE="1234567890" TRAN="usb" TYPE="disk" RO="0" VENDOR="Some Brand" MODEL="Some Model Name"
	# Use "_" to ignore field titles that we don't need. See more about "read" usages with IFS and skipping values at https://mywiki.wooledge.org/BashFAQ/001#Field_splitting.2C_whitespace_trimming.2C_and_other_input_processing
	# NOTE: I don't believe the model name should ever contain double quotes ("), but if somehow it does having it as the last variable set by "read" means any of the remaining double quotes will not be split on and would be included in the value (and no other values could contain double quotes).

	if [[ "${this_drive_type}" == 'disk' && "${this_drive_read_only}" == '0' && -n "${this_drive_size_bytes}" && "${this_drive_size_bytes}" != '0' && "${this_drive_transport}" == 'usb' ]] && (( this_drive_size_bytes > 1000000000 && this_drive_size_bytes < 33000000000 )); then # Only list DISKs with a SIZE between 2GB and 32GB that have a TRANsport type of USB.
		this_drive_brand="$(trim_and_squeeze_whitespace "${this_drive_brand//_/ }")" # Replace all underscores with spaces (see comments for model below).

		this_drive_model="${this_drive_model%\"}" # If somehow the model contained quotes the trailing quote will be included by "read", so remove it.
		this_drive_model="${this_drive_model//_/ }" # Replace all underscores with spaces since older "lsblk" (version 2.34 or older) seems to include them where spaces should be.
		this_drive_model="$(trim_and_squeeze_whitespace "${this_drive_model}")"

		if [[ -n "${this_drive_brand}" && ' GENERIC ATA ' != *" ${this_drive_brand^^} "* ]]; then # TODO: Find and ignore other generic VENDOR strings.
			if [[ -z "${this_drive_model}" ]]; then
				this_drive_model="${this_drive_brand}"
			elif [[ "${this_drive_model,,}" != *"${this_drive_brand,,}"* ]]; then
				this_drive_model="${this_drive_brand} ${this_drive_model}"
			fi
		fi

		this_drive_udevadm_info="$(udevadm info "${this_drive_full_id}")"
		this_drive_usb_id="$(echo "${this_drive_udevadm_info}" | awk -F ':|/' '($1 == "P") { print $(NF-12); exit }')"
		this_drive_usb_id="Bus ${this_drive_usb_id/-/ Port }"
		this_drive_usb_version="$(echo "${this_drive_udevadm_info}" | sed -nE '/-usbv.-/ {s/.*-(usbv.)-.*/\1/p;q}')"
		if [[ -n "${this_drive_usb_version}" ]]; then
			this_drive_usb_id="${this_drive_usb_version/usb/USB} ${this_drive_usb_id}"
		else
			this_drive_usb_id="USBv1 ${this_drive_usb_id}"
		fi

		memtest86plus_drives_list+="${this_drive_full_id}:${this_drive_usb_id}:$(human_readable_size_from_bytes "${this_drive_size_bytes}"):${this_drive_model:-UNKNOWN Drive Model}"$'\n'
	fi
done < <(lsblk -abdPpo 'NAME,SIZE,TRAN,TYPE,RO,VENDOR,MODEL' -x 'NAME')


latest_memtest86plus_download_url=''


if [[ -n "${memtest86plus_drives_list}" ]]; then
	echo -e '\n\nDetected Drives to ERASE and Update to Latest Memtest86+:\n'

	disk_index=0
	while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
		if [[ -n "${this_drive_full_id}" ]]; then
			(( disk_index ++ ))
			echo -e "${disk_index}: ${this_drive_full_id##*/} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}"
		fi
	done <<< "${memtest86plus_drives_list}"

	if (( detected_usb3_20gbps_connection_count > 0 )); then
		echo -e "\n${detected_usb3_20gbps_connection_count} DRIVES CONNECTED VIA USB USB 3.2 GEN 2x2: 20 GBPS"
	fi

	if (( detected_usb3_10gbps_connection_count > 0 )); then
		echo -e "\n${detected_usb3_10gbps_connection_count} DRIVES CONNECTED VIA USB 3.2 GEN 2: 10 GBPS"
	fi

	if (( detected_usb3_5gbps_connection_count > 0 )); then
		echo -e "\n${detected_usb3_5gbps_connection_count} DRIVES CONNECTED VIA USB 3.2 GEN 1: 5 GBPS"
	fi

	if (( detected_usb2_connection_count > 0 )) || [[ "${memtest86plus_drives_list}" == *':USBv2 '* ]]; then
		if (( detected_usb2_connection_count == 0 )); then
			detected_usb2_connection_count='SOME'
		fi

		>&2 echo -e "\nWARNING: ${detected_usb2_connection_count} DEVICE CONNECTED VIA USB 2.0: 480 MBPS"
	elif (( detected_usb1_connection_count > 0 )) || [[ "${memtest86plus_drives_list}" == *':USBv1 '* ]]; then
		if (( detected_usb1_connection_count == 0 )); then
			detected_usb1_connection_count='SOME'
		fi

		>&2 echo -e "\n\nERROR: ${detected_usb1_connection_count} DEVICE CONNECTED VIA USB 1.1: 12 MBPS\n"

		read -r
		exit 1
	fi

	latest_memtest86plus_download_url="https://memtest.org$(curl -m 5 -sfL 'https://memtest.org' | awk -F '"' '$2 ~ /\_64.iso\.zip$/ { print $2; exit }')"

	if [[ "${latest_memtest86plus_download_url}" == *'.iso.zip' ]]; then
		echo -e "\n\nLatest Memtest86+ URL:\n\n${latest_memtest86plus_download_url}"
	else
		>&2 echo -e "\n\nERROR: FAILED TO RETRIEVE LATEST MEMTEST86+ DOWNLOAD URL - INTERNET REQUIRED\n"
		read -r
		exit 2
	fi

	echo -e '\n\nPRESS ENTER TO CONTINUE WITH SPECIFIED URL AND LISTED DRIVES\n(PRESS CONTROL-C TO CANCEL)'
	read -r
else
	>&2 echo -e '\nERROR: NO MEMTEST86 DRIVES DETECTED\n'
	read -r
	exit 3
fi

sudo -v # Run "sudo -v" with no command to pre-cache the authorization for subsequent commands requiring "sudo" (such as "dd" and "umount").

echo -e "\n\nDownloading Latest Memtest86+:\n\n${latest_memtest86plus_download_url}"

rm -rf "${TMPDIR}/mt86plus_latest.iso.zip"
curl --connect-timeout 5 --progress-bar -fL "${latest_memtest86plus_download_url}" -o "${TMPDIR}/mt86plus_latest.iso.zip"
memtest86plus_iso_filename="$(unzip -l "${TMPDIR}/mt86plus_latest.iso.zip" | awk '/\.iso$/ { print $NF; exit }')"

if [[ "${memtest86plus_iso_filename}" != *'.iso'* ]]; then
	>&2 echo -e "\n\nERROR: FAILED TO DETERMINE MEMTEST86+ ISO FILENAME - INTERNET REQUIRED\n"
	read -r
	exit 4
fi

rm -rf "${TMPDIR}/${memtest86plus_iso_filename:?}"
unzip -jo "${TMPDIR}/mt86plus_latest.iso.zip" -d "${TMPDIR}"
rm -f "${TMPDIR}/mt86plus_latest.iso.zip"

if [[ ! -f "${TMPDIR}/${memtest86plus_iso_filename}" ]]; then
	>&2 echo -e "\n\nERROR: DOWNLOADING LATEST MEMTEST86+ FAILED - INTERNET REQUIRED\n"
	read -r
	exit 5
fi

overall_start_timestamp="$(date '+%s')"

update_drive_failed=false

disk_index=0
while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
	if [[ -n "${this_drive_full_id}" ]]; then

		echo -e "\n----------------------------------------"

		(( disk_index ++ ))

		this_drive_id="${this_drive_full_id##*/}"

		echo -e "\nMemtest86+ Drive ${disk_index}: ${this_drive_id} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}"

		update_drive_failed=false

		if [[ ! -e "${this_drive_full_id}" ]]; then
			update_drive_failed=true

			>&2 echo -e "\nERROR: DRIVE NO LONGER CONNECTED"

			break
		else
			this_drive_overall_start_timestamp="$(date '+%s')"

			# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric drive IDs.
			# shellcheck disable=SC2011
			ls "${this_drive_full_id}"?* | xargs -n 1 sudo umount -l 2> /dev/null # https://askubuntu.com/a/724484

			echo -e "\n\nUpdating Memtest86+ Drive ${disk_index} (${this_drive_id})...\n"

			this_drive_block_size="$(sudo blockdev --getbsz "${this_drive_full_id}")"
			blockdev_exit_code="$?"

			if (( blockdev_exit_code == 0 )) && [[ -n "${this_drive_block_size}" ]]; then
				sudo dd if="${TMPDIR}/${memtest86plus_iso_filename}" of="${this_drive_full_id}" bs="${this_drive_block_size}" conv=fsync status=progress
				dd_exit_code="$?"

				if (( dd_exit_code == 0 )); then
					echo -e "\nFinished Updating Memtest86+ Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"
				else
					update_drive_failed=true

					>&2 echo "  ERROR: DD FAILED WITH EXIT CODE ${dd_exit_code}"
				fi
			else
				update_drive_failed=true

				>&2 echo "  ERROR: BLOCKDEV FAILED WITH EXIT CODE ${blockdev_exit_code}"
			fi
		fi

		if $update_drive_failed; then
			echo -e "\n\nFAILED to Update Memtest86+ Drive ${disk_index} (${this_drive_id} - ${this_drive_usb_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"

			break
		fi
	fi
done <<< "${memtest86plus_drives_list}"

echo -e "\n----------------------------------------\n"

rm -f "${TMPDIR}/${memtest86plus_iso_filename:?}"

if ! $update_drive_failed; then
	echo "Finished Updating ${disk_index} Memtest86+ Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
else
	echo "FAILED Updating Memtest86+ Drive ${disk_index} in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
fi

read -r
