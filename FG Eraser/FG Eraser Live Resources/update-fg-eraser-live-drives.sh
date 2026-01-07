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

echo -e '\nUpdate FG Eraser Live Drives'

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

fg_eraser_live_drives_list=''

while IFS='"' read -r _ this_drive_full_id _ this_drive_size_bytes _ this_drive_transport _ this_drive_type _ this_drive_read_only _ this_drive_brand _ this_drive_model; do
	# Split lines on double quotes (") to easily extract each value out of each "lsblk" line, which will be like: NAME="/dev/sda" SIZE="1234567890" TRAN="usb" TYPE="disk" RO="0" VENDOR="Some Brand" MODEL="Some Model Name"
	# Use "_" to ignore field titles that we don't need. See more about "read" usages with IFS and skipping values at https://mywiki.wooledge.org/BashFAQ/001#Field_splitting.2C_whitespace_trimming.2C_and_other_input_processing
	# NOTE: I don't believe the model name should ever contain double quotes ("), but if somehow it does having it as the last variable set by "read" means any of the remaining double quotes will not be split on and would be included in the value (and no other values could contain double quotes).

	if [[ "${this_drive_type}" == 'disk' && "${this_drive_read_only}" == '0' && -n "${this_drive_size_bytes}" && "${this_drive_size_bytes}" != '0' && "${this_drive_transport}" == 'usb' ]] && (( this_drive_size_bytes > 15000000000 && this_drive_size_bytes < 129000000000 )); then # Only list DISKs with a SIZE between 16GB and 128GB that have a TRANsport type of USB.
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

		fg_eraser_live_drives_list+="${this_drive_full_id}:${this_drive_usb_id}:$(human_readable_size_from_bytes "${this_drive_size_bytes}"):${this_drive_model:-UNKNOWN Drive Model}"$'\n'
	fi
done < <(lsblk -abdPpo 'NAME,SIZE,TRAN,TYPE,RO,VENDOR,MODEL' -x 'NAME')


cubic_project_parent_path="${HOME}/Linux Deployment"
mkdir -p "${cubic_project_parent_path}"

# ALWAYS USE MOST RECENT ISO:

# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
# shellcheck disable=SC2012
latest_cubic_project_path="$(ls -td "${cubic_project_parent_path}/FG Eraser Live"* | head -1)"

if [[ ! -d "${latest_cubic_project_path}" ]]; then
	>&2 echo -e "\n\nERROR: SOURCE FOLDER NOT FOUND AT \"${latest_cubic_project_path}\"\n"
	read -r
	exit 1
fi

# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
# shellcheck disable=SC2012
source_iso_path="$(ls -t "${latest_cubic_project_path}/fg-eraser-live-"*'.iso' | head -1)"


if [[ -n "${fg_eraser_live_drives_list}" ]]; then
	echo -e '\n\nDetected Drives to ERASE and Update to Latest FG Eraser Live:\n'

	disk_index=0
	while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
		if [[ -n "${this_drive_full_id}" ]]; then
			(( disk_index ++ ))
			echo -e "${disk_index}: ${this_drive_full_id##*/} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}"
		fi
	done <<< "${fg_eraser_live_drives_list}"

	if (( detected_usb3_20gbps_connection_count > 0 )); then
		echo -e "\n${detected_usb3_20gbps_connection_count} DRIVES CONNECTED VIA USB USB 3.2 GEN 2x2: 20 GBPS"
	fi

	if (( detected_usb3_10gbps_connection_count > 0 )); then
		echo -e "\n${detected_usb3_10gbps_connection_count} DRIVES CONNECTED VIA USB 3.2 GEN 2: 10 GBPS"
	fi

	if (( detected_usb3_5gbps_connection_count > 0 )); then
		echo -e "\n${detected_usb3_5gbps_connection_count} DRIVES CONNECTED VIA USB 3.2 GEN 1: 5 GBPS"
	fi

	if (( detected_usb2_connection_count > 0 )) || [[ "${fg_eraser_live_drives_list}" == *':USBv2 '* ]]; then
		if (( detected_usb2_connection_count == 0 )); then
			detected_usb2_connection_count='SOME'
		fi

		>&2 echo -e "\n\nERROR: ${detected_usb2_connection_count} DRIVES CONNECTED VIA USB 2.0: 480 MBPS\n"

		read -r
		exit 2
	elif (( detected_usb1_connection_count > 0 )) || [[ "${fg_eraser_live_drives_list}" == *':USBv1 '* ]]; then
		if (( detected_usb1_connection_count == 0 )); then
			detected_usb1_connection_count='SOME'
		fi

		>&2 echo -e "\n\nERROR: ${detected_usb1_connection_count} DRIVES CONNECTED VIA USB 1.1: 12 MBPS\n"

		read -r
		exit 3
	fi

	if [[ -f "${source_iso_path}" ]]; then
		echo -e "\n\nSource ISO Name:\n\n${source_iso_path##*/}"
	else
		>&2 echo -e "\n\nERROR: SOURCE ISO NOT FOUND AT \"${source_iso_path}\"\n"
		read -r
		exit 4
	fi

	echo -e '\n\nPRESS ENTER TO CONTINUE WITH SPECIFIED SOURCE ISO AND LISTED DRIVES\n(PRESS CONTROL-C TO CANCEL)'
	read -r
else
	>&2 echo -e '\nERROR: NO FG ERASER LIVE DRIVES DETECTED\n'
	read -r
	exit 5
fi

sudo -v # Run "sudo -v" with no command to pre-cache the authorization for subsequent commands requiring "sudo" (such as "fdisk" and "umount").

overall_start_timestamp="$(date '+%s')"

update_drive_failed=false

disk_index=0
while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
	if [[ -n "${this_drive_full_id}" ]]; then

		echo -e "\n----------------------------------------"

		(( disk_index ++ ))

		this_drive_id="${this_drive_full_id##*/}"

		echo -e "\nFG Eraser Live Drive ${disk_index}: ${this_drive_id} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}"

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

			echo -e "\n\nUpdating FG Eraser Live Drive ${disk_index} (${this_drive_id})...\n"

			this_drive_block_size="$(sudo blockdev --getbsz "${this_drive_full_id}")"
			blockdev_exit_code="$?"

			if (( blockdev_exit_code == 0 )) && [[ -n "${this_drive_block_size}" ]]; then
				sudo dd if="${source_iso_path}" of="${this_drive_full_id}" bs="${this_drive_block_size}" conv=fsync status=progress
				dd_exit_code="$?"

				if (( dd_exit_code == 0 )); then
					echo -e "\nFinished Updating FG Eraser Live Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"
				else
					update_drive_failed=true

					>&2 echo "  ERROR: DD FAILED WITH EXIT CODE ${dd_exit_code}"
				fi
			else
				update_drive_failed=true

				>&2 echo "  ERROR: BLOCKDEV FAILED WITH EXIT CODE ${blockdev_exit_code}"
			fi
		fi


		if ! $update_drive_failed; then
			echo -e "\n\nVerifying \"filesystem.squashfs\" on FG Eraser Live Drive ${disk_index} (${this_drive_id})..."

			this_drive_verify_start_timestamp="$(date '+%s')"

			this_fg_eraser_live_mount_point="/mnt/FG Eraser Live $(date '+%s')"
			sudo umount "${this_fg_eraser_live_mount_point}" &> /dev/null
			sudo rm -rf "${this_fg_eraser_live_mount_point}"
			sudo mkdir "${this_fg_eraser_live_mount_point}"
			sudo mount -r "${this_drive_full_id}1" "${this_fg_eraser_live_mount_point}"
			mount_fg_eraser_live_exit_code="$?"

			if (( mount_fg_eraser_live_exit_code != 0 )); then
				update_drive_failed=true

				sudo umount "${this_fg_eraser_live_mount_point}"
				sudo rm -rf "${this_fg_eraser_live_mount_point}"

				>&2 echo "  ERROR: MOUNT \"FG Eraser Live\" (${this_drive_full_id}1) FAILED WITH EXIT CODE ${mount_fg_eraser_live_exit_code}"
			else
				squashfs_intended_md5sum="$(awk '($2 == "./live/filesystem.squashfs") { print $1; exit }' "${this_fg_eraser_live_mount_point}/md5sum.txt")"

				squashfs_actual_md5sum="$(md5sum "${this_fg_eraser_live_mount_point}/live/filesystem.squashfs" | awk '{ print $1; exit }')"

				if [[ -n "${squashfs_intended_md5sum}" && "${squashfs_actual_md5sum}" == "${squashfs_intended_md5sum}" ]]; then
					echo -e "\nVerified \"filesystem.squashfs\" on FG Eraser Live Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_verify_start_timestamp ))")"
				else
					update_drive_failed=true

					>&2 echo "  ERROR: SQUASHFS VERIFICATION FAILED (\"${squashfs_actual_md5sum}\" != \"${squashfs_intended_md5sum}\")"

					echo -e "\nFAILED to Verify \"filesystem.squashfs\" on FG Eraser Live Drive ${disk_index} (${this_drive_id} - ${this_drive_usb_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_verify_start_timestamp ))")"
				fi

				sudo umount "${this_fg_eraser_live_mount_point}"
				sudo rm -rf "${this_fg_eraser_live_mount_point}"
			fi
		fi

		if $update_drive_failed; then
			echo -e "\n\nFAILED to Update and Verify FG Eraser Live Drive ${disk_index} (${this_drive_id} - ${this_drive_usb_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"

			break
		else
			echo -e "\n\nFinished Updating and Verifying FG Eraser Live Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"
		fi
	fi
done <<< "${fg_eraser_live_drives_list}"

echo -e "\n----------------------------------------\n"

if ! $update_drive_failed; then
	echo "Finished Updating ${disk_index} FG Eraser Live Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
else
	echo "FAILED Updating FG Eraser Live Drive ${disk_index} in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
fi

read -r
