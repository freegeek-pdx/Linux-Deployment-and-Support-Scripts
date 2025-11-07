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

echo -e '\nUpdate FG Install Drives'

os_version="${1:-22.2}"
version_suffix="${2,,}"

if [[ -z "${os_version}" ]]; then
	>&2 echo -e '\n\nERROR: MUST SPECIFY OS VERSION AS FIRST ARGUMENT\n'
	read -r
	exit 1
fi

if [[ -n "${version_suffix}" && "${version_suffix}" != '-'* ]]; then
	version_suffix="-${version_suffix}"
fi

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

detected_usb2_connection=false
detected_usb1_connection=false
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

			if [[ "${this_lsusb_line}" == *' 480M' ]]; then
				detected_usb2_connection=true
			elif [[ "${this_lsusb_line}" == *' 12M' ]]; then
				detected_usb1_connection=true
			fi
		fi
	fi
done < <(lsusb -tv)

if $output_this_lsusb_bus_section; then
	echo -e "${this_lsusb_bus_section}\n"
fi

fg_install_drives_list=''

while IFS='"' read -r _ this_drive_full_id _ this_drive_size_bytes _ this_drive_transport _ this_drive_type _ this_drive_read_only _ this_drive_brand _ this_drive_model; do
	# Split lines on double quotes (") to easily extract each value out of each "lsblk" line, which will be like: NAME="/dev/sda" SIZE="1234567890" TRAN="usb" TYPE="disk" RO="0" VENDOR="Some Brand" MODEL="Some Model Name"
	# Use "_" to ignore field titles that we don't need. See more about "read" usages with IFS and skipping values at https://mywiki.wooledge.org/BashFAQ/001#Field_splitting.2C_whitespace_trimming.2C_and_other_input_processing
	# NOTE: I don't believe the model name should ever contain double quotes ("), but if somehow it does having it as the last variable set by "read" means any of the remaining double quotes will not be split on and would be included in the value (and no other values could contain double quotes).

	if [[ "${this_drive_type}" == 'disk' && "${this_drive_read_only}" == '0' && -n "${this_drive_size_bytes}" && "${this_drive_size_bytes}" != '0' && "${this_drive_transport}" == 'usb' ]] && (( this_drive_size_bytes > 15000000000 && this_drive_size_bytes < 513000000000 )); then # Only list DISKs with a SIZE between 16GB and 512GB that have a TRANsport type of USB.
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

		fg_install_drives_list+="${this_drive_full_id}:${this_drive_usb_id}:$(human_readable_size_from_bytes "${this_drive_size_bytes}"):${this_drive_model:-UNKNOWN Drive Model}"$'\n'
	fi
done < <(lsblk -abdPpo 'NAME,SIZE,TRAN,TYPE,RO,VENDOR,MODEL' -x 'NAME')


cubic_project_parent_path="${HOME}/Linux Deployment"
mkdir -p "${cubic_project_parent_path}"

# ALWAYS USE MOST RECENT CUBIC PROJECT FOR THE SPECIFIED VERSION:

# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
# shellcheck disable=SC2012
latest_cubic_project_path="$(ls -td "${cubic_project_parent_path}/Linux Mint ${os_version} Cinnamon${version_suffix//-/ } Updated 20"* | head -1)"
latest_cubic_project_custom_disk_path="${latest_cubic_project_path}/custom-disk" # Could locate and then mount the latest ISO that Cubic created, but faster and simpler to just use the project files which don't get deleted.

# NOTE: Rather than starting by cloning the bootable Linux ISO (via "dd"), this script will create an EFI boot partition (named "FG BOOT") and manually copy the bootable Linux installer contents into an "ext4" partition (named "FG Linux").
# The "FG BOOT" partition will be filled with the EFI boot files from the bootable Linux installer, and Legacy BIOS compatiblity will also be manually added to GRUB
# (the bootable Linux installer uses ISOLINUX for Legacy BIOS boot, but being able to use a single GRUB menu is nicer for either Legacy BIOS or UEFI is nicer).
# I originally experimented with versions of the script which started by cloning the ISO and then adding partitions to be able to also boot Windows, and while I got that to work on a majority of computers,
# I had to work around different issues on various computers where the WinPE EFI file would fail to load via GRUB or would load and then BSOD,
# or on some computers the drive was not detected as bootable at all and the GRUB boot menu could only be loaded by navigating to the GRUB EFI file manually.
# I found ways around each of these issue, but one fix would interfere with another an I couldn't come up with one solution that worked on all computer.
# Once I learned and understood more about how hacky the bootable "ISOhybrid" format is to begin with (https://superuser.com/a/1527373 & https://github.com/pbatard/rufus/wiki/FAQ#why-doesnt-rufus-recommend-dd-mode-over-iso-mode-for-isohybrid-images-surely-dd-is-better),
# I started experimenting with different ways to make a bootable USB basically from scratch rather than starting with cloning the bootable ISO.
# That is what this script does now and it seems to be completely compatible with all computers that have been tested, and is a much simpler setup than all the very specific stuff
# I had to do with partition order and partition type signatures to be able to also boot Windows when starting with the bootable Linux ISO.
# The other downside of starting by cloning the bootable Linux ISO that the current method doesn't have is that if I wanted to only update Linux I would have to erase the whole drive and lose the Windows files even if I didn't have to update them.
# With this current setup, Linux and Windows can updated independently once the drive has been formatted by this script.


if [[ -n "${fg_install_drives_list}" ]]; then
	echo -e '\n\nDetected Drives to Update to Latest FG Install:\n'

	disk_index=0
	while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
		if [[ -n "${this_drive_full_id}" ]]; then
			(( disk_index ++ ))
			echo -e "${disk_index}: ${this_drive_full_id##*/} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}"
		fi
	done <<< "${fg_install_drives_list}"

	if $detected_usb2_connection || [[ "${fg_install_drives_list}" == *':USBv2 '* ]]; then
		>&2 echo -e '\n\nERROR: SOME DEVICE CONNECTED AT USB 2.0 SPEED\n'

		read -r
		exit 2
	elif $detected_usb1_connection || [[ "${fg_install_drives_list}" == *':USBv1 '* ]]; then
		>&2 echo -e '\n\nERROR: SOME DEVICE CONNECTED AT USB 1.0 SPEED\n'

		read -r
		exit 3
	fi

	if [[ ! -d "${latest_cubic_project_custom_disk_path}" ]]; then
		>&2 echo -e "\n\nERROR: SOURCE FOLDER NOT FOUND AT \"${latest_cubic_project_path}\"\n"
		read -r
		exit 4
	fi

	source_cubic_project_folder_name="${latest_cubic_project_path##*/}"

	if [[ -d "${latest_cubic_project_custom_disk_path}" ]]; then
		echo -e "\n\nSource Cubic Project Folder Name:\n\n${source_cubic_project_folder_name}"
	else
		>&2 echo -e "\n\nERROR: SOURCE CUBIC PROJECT CUSTOM DISK FOLDER NOT FOUND AT \"${latest_cubic_project_path}\"\n"
		read -r
		exit 5
	fi

	echo -e '\n\nPRESS ENTER TO CONTINUE WITH SPECIFIED SOURCE CUBIC PROJECT AND LISTED DRIVES\n(PRESS CONTROL-C TO CANCEL)'
	read -r
else
	>&2 echo -e '\nERROR: NO FG INSTALL DRIVES DETECTED\n'
	read -r
	exit 6
fi

sudo -v # Run "sudo -v" with no command to pre-cache the authorization for subsequent commands requiring "sudo" (such as "dd" and "umount").

disk_index=0
some_disk_info_failed=false
while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
	if [[ -n "${this_drive_full_id}" ]]; then
		(( disk_index ++ ))
		echo -e "\n\n${disk_index}: ${this_drive_full_id##*/} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}\n"

		echo 'Drive Health:'
		if ! sudo hdsentinel -dev "${this_drive_full_id}" | awk '/^HDD/,/^$/'; then
			some_disk_info_failed=true
		fi

		echo 'Drive Format:'
		if ! sudo fdisk -l "${this_drive_full_id}"; then
			some_disk_info_failed=true
		fi
	fi
done <<< "${fg_install_drives_list}"

if $some_disk_info_failed; then
	>&2 echo -e '\n\nERROR: FAILED TO LOAD INFO FOR SOME DRIVE ABOVE\n'
	read -r
	exit 7
fi

format_drive_ids=''
echo -en '\n\nDo any FG Install drives need to be formatted before being updated? [y/N] '
read -r confirm_format_drives
if [[ "${confirm_format_drives}" =~ ^[Yy] ]]; then
	echo -en '\nEnter space-separated Drive IDs (or Indexes) to Format and Partition (or Enter "ALL" to Format All Drives): '
	read -r format_drive_ids
	format_drive_ids="${format_drive_ids,,}"
fi

overall_start_timestamp="$(date '+%s')"

did_reformat_some_drive=false

update_drive_failed=false

disk_index=0
while IFS=':' read -r this_drive_full_id this_drive_usb_id this_human_readable_size this_drive_model; do
	if [[ -n "${this_drive_full_id}" ]]; then

		echo -e "\n----------------------------------------"

		(( disk_index ++ ))

		this_drive_id="${this_drive_full_id##*/}"

		echo -e "\nFG Install Drive ${disk_index}: ${this_drive_id} - ${this_human_readable_size} (${this_drive_model}) - ${this_drive_usb_id}"

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

			did_reformat_this_drive=false
			if [[ " ${format_drive_ids} " == *' all '* || " ${format_drive_ids} " == *" ${disk_index} "* || " ${format_drive_ids} " == *" ${this_drive_id} "* || " ${format_drive_ids} " == *" ${this_drive_full_id} "* ]]; then
				echo -e "\n\nFormatting FG Install Drive ${disk_index} (${this_drive_id})...\n"

				this_drive_format_start_timestamp="$(date '+%s')"

				sudo wipefs -fa "${this_drive_full_id}"
				wipefs_exit_code="$?"

				if (( wipefs_exit_code != 0 )); then
					update_drive_failed=true

					>&2 echo "  ERROR: WIPEFS FAILED WITH EXIT CODE ${wipefs_exit_code}"
				fi

				if ! $update_drive_failed; then
					this_drive_block_size="$(sudo blockdev --getbsz "${this_drive_full_id}")"
					blockdev_exit_code="$?"

					if (( blockdev_exit_code == 0 )) && [[ -n "${this_drive_block_size}" ]]; then
						sudo dd if=/dev/zero of="${this_drive_full_id}" bs="${this_drive_block_size}" count=1 conv=fsync status=progress # Also overwrite first block to try to fully delete partition table
						# since partition type signatures seems to be left behind by "wipefs" (as seen in the warnings that "fdisk" shows when adding new signatures).
						# But, "fdisk" is still showing that partition signatures still exist even after overwriting first block. What's up with that?

						zero_first_block_exit_code="$?"

						if (( zero_first_block_exit_code != 0 )); then
							update_drive_failed=true

							>&2 echo "  ERROR: ZEROING FIRST BLOCK FAILED WITH EXIT CODE ${zero_first_block_exit_code}"
						fi
					else
						update_drive_failed=true

						>&2 echo "  ERROR: BLOCKDEV FAILED WITH EXIT CODE ${blockdev_exit_code}"
					fi
				fi

				if ! $update_drive_failed; then
					fdisk_commands_array=(
						# Create "FG BOOT" Partition
						'n' # Add a new partition.
						'p' # Specify "primary" partition type.
						'1' # Specify parition number to create.
						'' # Specify default partition first sector.
						'+25M' # Specify desired "+size" for last sector.
						't' # Set partition type (DO NOT need to specify partition number because there is only one so far).
						'EF' # Specify EFI partition type.
						'a' # Set bootable "active" partition flag.

						# Create "FG Linux" Partition
						'n'
						'p'
						'2'
						''
						'+8G' # DO NOT need to specify partition type  "fdisk" defaults to Linux (83) partition type like we want for this "ext4" partition anyways.

						# Create "FG WINDOWS" Partition
						'n'
						'p'
						'3'
						''
						'+2G'
						't'
						'3' # Specify parition number to set type.
						'0c' # Specify FAT32 partition type.

						# Create"FG Install" Partition
						'n'
						'p' # DO NOT specify partition number "4" next because "fdisk" chooses it by default since MBR can only contain 4 primary partitions.
						''
						'' # Specify default partition last sector to fill the rest of the drive.
						't'
						'4'
						'07' # Specify NTFS partition type.

						'w' # Write specified partition to drive.
					)

					printf '%s\n' "${fdisk_commands_array[@]}" | sudo fdisk "${this_drive_full_id}" -w always -W always # Set both "-w" and "-W" to "always" to clear any previous partition type signatures since they would not be cleared by default when in non-interactive mode.
					fdisk_exit_code="$?"

					if (( fdisk_exit_code != 0 )); then
						update_drive_failed=true

						>&2 echo "  ERROR: FDISK FAILED WITH EXIT CODE ${fdisk_exit_code}"
					fi

					sleep 1 # Have seen errors formatting partitions when not sleeping for a second after creating partitions.
				fi

				if ! $update_drive_failed; then
					sudo mkfs.vfat -F 16 "${this_drive_full_id}1" -n 'FG BOOT'
					format_fg_boot_partition_exit_code="$?"

					if (( format_fg_boot_partition_exit_code != 0 )); then
						update_drive_failed=true

						>&2 echo "  ERROR: FORMAT \"FG BOOT\" PARTITION FAILED WITH EXIT CODE ${format_fg_boot_partition_exit_code}"
					fi
				fi

				if ! $update_drive_failed; then
					sudo mkfs.ext4 "${this_drive_full_id}2" -L 'FG Linux'
					format_fg_linux_partition_exit_code="$?"

					if (( format_fg_linux_partition_exit_code != 0 )); then
						update_drive_failed=true

						>&2 echo "  ERROR: FORMAT \"FG Linux\" PARTITION FAILED WITH EXIT CODE ${format_fg_linux_partition_exit_code}"
					fi
				fi

				if ! $update_drive_failed; then
					sudo mkfs.vfat -F 32 "${this_drive_full_id}3" -n 'FG WINDOWS'
					format_fg_windows_partition_exit_code="$?"

					if (( format_fg_windows_partition_exit_code != 0 )); then
						update_drive_failed=true

						>&2 echo "  ERROR: FORMAT \"FG WINDOWS\" PARTITION FAILED WITH EXIT CODE ${format_fg_windows_partition_exit_code}"
					fi
				fi

				if ! $update_drive_failed; then
					sudo mkfs.ntfs "${this_drive_full_id}4" -fL 'FG Install'
					format_fg_install_partition_exit_code="$?"

					if (( format_fg_install_partition_exit_code != 0 )); then
						update_drive_failed=true

						>&2 echo "  ERROR: FORMAT \"FG Install\" PARTITION FAILED WITH EXIT CODE ${format_fg_install_partition_exit_code}"
					fi
				fi

				if ! $update_drive_failed; then
					did_reformat_this_drive=true
					did_reformat_some_drive=true

					echo -e "\nFinished Formatting FG Install Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_format_start_timestamp ))")"
				fi
			fi
		fi

		if $update_drive_failed; then
			echo -e "\n\nFAILED to Format FG Install Drive ${disk_index} (${this_drive_id} - ${this_drive_usb_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"

			break
		else
			echo -e "\n\nUpdating \"FG BOOT\" Partition for FG Install Drive ${disk_index} (${this_drive_id})...\n"

			this_drive_update_fg_boot_start_timestamp="$(date '+%s')"

			this_fg_boot_mount_point="/mnt/FG BOOT $(date '+%s')"
			sudo umount "${this_fg_boot_mount_point}" &> /dev/null
			sudo rm -rf "${this_fg_boot_mount_point}" 
			sudo mkdir "${this_fg_boot_mount_point}"
			sudo mount "${this_drive_full_id}1" "${this_fg_boot_mount_point}"
			mount_fg_boot_exit_code="$?"

			if (( mount_fg_boot_exit_code != 0 )); then
				update_drive_failed=true

				sudo umount "${this_fg_boot_mount_point}"
				sudo rm -rf "${this_fg_boot_mount_point}"

				>&2 echo "  ERROR: MOUNT \"FG BOOT\" (${this_drive_full_id}1) FAILED WITH EXIT CODE ${mount_fg_boot_exit_code}"
			else
				if ! $did_reformat_this_drive; then
					sudo rm -rf "${this_fg_boot_mount_point}/"*
				fi

				echo -e "Copying EFI Boot Files and GRUB Menu From Linux Installer..."
				sudo mkdir "${this_fg_boot_mount_point}/"{EFI,boot}
				sudo cp -rf "${latest_cubic_project_custom_disk_path}/EFI/boot" "${this_fg_boot_mount_point}/EFI"
				sudo cp -rf "${latest_cubic_project_custom_disk_path}/boot/grub" "${this_fg_boot_mount_point}/boot"

				fg_install_drive_resources_path="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/fg-install-drive-resources"
				if [[ -d "${fg_install_drive_resources_path}" ]]; then
					echo -e "Setting Label and Icon for Mac Boot..."
					sudo cp -f "${fg_install_drive_resources_path}/mac-disk_label" "${this_fg_boot_mount_point}/EFI/boot/.disk_label" # These ".disk_label" files were created using "bless" on macOS as shown here: https://superuser.com/a/1540915
					sudo cp -f "${fg_install_drive_resources_path}/mac-disk_label_2x" "${this_fg_boot_mount_point}/EFI/boot/.disk_label_2x" # These labels say "Install Linux Mint" (Windows is intentionally excluded from the label since it can't be licensed on Macs).
					sudo cp -f "${fg_install_drive_resources_path}/mac-VolumeIcon.icns" "${this_fg_boot_mount_point}/.VolumeIcon.icns" # This is a white-bordered circle version of the Free Geek logo (the same custom icon that the Mac Test Boot uses).
				fi

				echo -e "Adding Legacy BIOS Boot Support to GRUB..."
				sudo grub-install --target 'i386-pc' --boot-directory "${this_fg_boot_mount_point}/boot" "${this_drive_full_id}" # Also add Legacy BIOS boot support via GRUB (rather than SYSLINUX/ISOLINUX so that a single boot menu can be used): https://wiki.archlinux.org/title/GRUB#Installation_2
				grub_install_legacy_bios_exit_code="$?"

				if (( grub_install_legacy_bios_exit_code != 0 )); then
					update_drive_failed=true

					>&2 echo "  ERROR: GRUB-INSTALL LEGACY BIOS FAILED WITH EXIT CODE ${grub_install_legacy_bios_exit_code}"
				fi

				sudo umount "${this_fg_boot_mount_point}"
				sudo rm -rf "${this_fg_boot_mount_point}"

				echo -e "\nFinished Updating \"FG BOOT\" Partition for FG Install Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_update_fg_boot_start_timestamp ))")"


				echo -e "\n\nUpdating \"FG Linux\" Partition for FG Install Drive ${disk_index} (${this_drive_id})...\n"

				this_drive_update_fg_linux_start_timestamp="$(date '+%s')"

				this_fg_linux_mount_point="/mnt/FG Linux $(date '+%s')"
				sudo umount "${this_fg_linux_mount_point}" &> /dev/null
				sudo rm -rf "${this_fg_linux_mount_point}"
				sudo mkdir "${this_fg_linux_mount_point}"
				sudo mount "${this_drive_full_id}2" "${this_fg_linux_mount_point}"
				mount_fg_linux_exit_code="$?"

				if (( mount_fg_linux_exit_code != 0 )); then
					update_drive_failed=true

					sudo umount "${this_fg_linux_mount_point}"
					sudo rm -rf "${this_fg_linux_mount_point}"

					>&2 echo "  ERROR: MOUNT \"FG Linux\" (${this_drive_full_id}2) FAILED WITH EXIT CODE ${mount_fg_linux_exit_code}"
				else
					if ! $did_reformat_this_drive; then
						sudo rm -rf "${this_fg_linux_mount_point}/"*
					fi

					sudo rsync --info 'progress2' -aH "${latest_cubic_project_custom_disk_path}/" "${this_fg_linux_mount_point}"
					rsync_exit_code="$?"

					if (( rsync_exit_code != 0 )); then
						update_drive_failed=true

						>&2 echo "  ERROR: RSYNC FAILED WITH EXIT CODE ${rsync_exit_code}"
					else
						sudo rm -rf "${this_fg_linux_mount_point}/"{EFI,isolinux,boot/grub} # Not not need boot files or GRUB menu in this partition since it is not directly bootable and all necessary boot files are in the bootable "FG BOOT" partition.
					fi

					echo -e "\nFinished Updating \"FG Linux\" Partition for FG Install Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_update_fg_linux_start_timestamp ))")"


					echo -e "\n\nVerifying \"filesystem.squashfs\" on \"FG Linux\" Partition for FG Install Drive ${disk_index} (${this_drive_id})..."

					this_drive_verify_start_timestamp="$(date '+%s')"

					squashfs_intended_md5sum="$(awk '($2 == "./casper/filesystem.squashfs") { print $1; exit }' "${this_fg_linux_mount_point}/md5sum.txt")"

					squashfs_actual_md5sum="$(md5sum "${this_fg_linux_mount_point}/casper/filesystem.squashfs" | awk '{ print $1; exit }')"

					if [[ -n "${squashfs_intended_md5sum}" && "${squashfs_actual_md5sum}" == "${squashfs_intended_md5sum}" ]]; then
						echo -e "\nVerified \"filesystem.squashfs\" on \"FG Linux\" Partition for FG Install Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_verify_start_timestamp ))")"
					else
						update_drive_failed=true

						>&2 echo "  ERROR: SQUASHFS VERIFICATION FAILED (\"${squashfs_actual_md5sum}\" != \"${squashfs_intended_md5sum}\")"

						echo -e "\nFAILED to Verify \"filesystem.squashfs\" on \"FG Linux\" Partition for FG Install Drive ${disk_index} (${this_drive_id} - ${this_drive_usb_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_verify_start_timestamp ))")"
					fi

					sudo umount "${this_fg_linux_mount_point}"
					sudo rm -rf "${this_fg_linux_mount_point}"

					this_fg_install_mount_point="/mnt/FG Install $(date '+%s')"
					sudo umount "${this_fg_install_mount_point}" &> /dev/null
					sudo rm -rf "${this_fg_install_mount_point}"
					sudo mkdir "${this_fg_install_mount_point}"
					sudo mount "${this_drive_full_id}4" "${this_fg_install_mount_point}"
					mount_fg_install_exit_code="$?"

					if (( mount_fg_install_exit_code != 0 )); then
						update_drive_failed=true

						sudo umount "${this_fg_install_mount_point}"
						sudo rm -rf "${this_fg_install_mount_point}"

						>&2 echo "  ERROR: MOUNT \"FG Install\" (${this_drive_full_id}4) FAILED WITH EXIT CODE ${mount_fg_install_exit_code}"
					else
						if ! $did_reformat_this_drive; then
							sudo rm -rf "${this_fg_install_mount_point}/linux-mint-"*'.txt'
						fi

						date '+%Y%m%d' | sudo tee "${this_fg_install_mount_point}/linux-mint-$($update_drive_failed && echo 'ERROR' || echo 'updated').txt" > /dev/null

						sudo umount "${this_fg_install_mount_point}"
						sudo rm -rf "${this_fg_install_mount_point}"
					fi
				fi
			fi
		fi

		if $update_drive_failed; then
			echo -e "\n\nFAILED to Update FG Install Drive ${disk_index} (${this_drive_id} - ${this_drive_usb_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"

			break
		else
			echo -e "\n\nFinished Updating FG Install Drive ${disk_index} (${this_drive_id}) in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_drive_overall_start_timestamp ))")"
		fi
	fi
done <<< "${fg_install_drives_list}"

echo -e "\n----------------------------------------\n"

if ! $update_drive_failed; then
	echo "Finished Updating Linux Mint ${os_version}${version_suffix//-/ } on ${disk_index} FG Install Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"

	if $did_reformat_some_drive; then
		echo -e '\nNOW, REBOOT INTO WINDOWS AND LAUNCH "Run Update Windows on FG Install Drives.cmd"\nTO RE-ADD WINDOWS INSTALLER TO RE-FORMATTED DRIVES'
	fi
else
	echo "FAILED Updating Linux Mint ${os_version}${version_suffix//-/ } on FG Install Drive ${disk_index} in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
fi

read -r
