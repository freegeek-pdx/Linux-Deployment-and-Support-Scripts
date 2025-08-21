#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell
# Last Updated: 07/21/25
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

MODE="$([[ "${0##*/}" == 'testing-'* ]] && echo 'testing' || echo 'production')"
readonly MODE

xset s noblank
xset s off -dpms # Disable screen sleep.

# CHECK RESOLUTION AND REDUCE IF HIGH RESOLUTION (RETINA/HiDPI) SCREEN
while IFS=' x' read -r current_screen_name current_screen_resolution_width current_screen_resolution_height; do
	if (( current_screen_resolution_width > 1920 || current_screen_resolution_height > 1200 )); then
		echo -e ">>\n>\nHALVING ${current_screen_resolution_width}x${current_screen_resolution_height} RESOLUTION FOR ${current_screen_name}\n<\n<<"
		xrandr --output "${current_screen_name}" --scale '0.5' # This just halves the resolution, making everything fuzzy (*NOT* HiDPI SCALED), but that's fine we just need text readable instead of tiny.
	fi
done < <(xrandr | awk -F '[ +]' '($2 == "connected") { resolution = $3; if (resolution == "primary") { resolution = $4 }; print $1, resolution }')

mv -f '/usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service'{,.disabled}
# NOTE: On Mint 21 the screensaver is starting after 15 mins and CANNOT be disabled using any "gsettings" commands (run as any user),
# so instead disable the DBus ScreenSaver service by renaming the file to end in ".disabled" so it will never be run (found the DBus service path from https://forums.linuxmint.com/viewtopic.php?p=1321395#p1321395).
# Renaming/moving/deleting the "/usr/bin/cinnamon-screensaver" command would also work (https://askubuntu.com/questions/356992/how-do-i-disable-the-cinnamon-2-lock-screen/548475#548475),
# but that causes the DBus ScreenSaver service to still run by "dbus-daemon" when the system has been idle for 15 mins, and just exit with a failure since the command cannot be found.
# Disabling the DBus service in this way seems a little more elegant, but I couldn't figure out how to actually disable the service through some DBus command like the way you can disable "systemctl" services.

if grep -qF ' ip=dhcp ' '/proc/cmdline'; then
	# NOTE: When PXE/net booting Mint 21 (but not USB booting), the primary Ethernet connection DOES NOT load a DNS server, so any network calls using URLs fail (such as to download QA Helper).
	# The exact issue is described here, but without a solution: https://serverfault.com/questions/1104238/no-dns-on-pxe-booted-linux-live-system-with-networkmanager
	# (Using the kernel args mentioned in the above post to set a DNS server doesn't work, and every other possible kernel arg I could find for specifying DNS servers also didn't work.)
	# Interestingly, I was not able to find any other mention of this issue in all my Googling even though that post mentions running into the issue on Debian and through
	# testing I found that the issue started with Ubuntu 21.04 (Mint 19.X was based on Ubuntu 20.04 and Mint 20.X is based on Ubuntu 22.04), so it must affect many systems.
	# I also found that this issue seems to be tied to using the "ip=dhcp" kernel argument since when I added that argument on a USB boot the same DNS issue occurred.
	# But, the "ip=dhcp" kernel argument is required for PXE/net booting to be able to download the filesystem over NFS as of Ubuntu 19.10 (https://bugs.launchpad.net/ubuntu/+source/casper/+bug/1848018).
	# So, since "ip=dhcp" is required when PXE/net booting, this DNS issue must be worked around to be able to properly load the network on Mint 21.
	# Interestingly, any subsequent connections (such as Wi-Fi) load a DNS server just fine, and turning Ethernet off and back on also allows it to properly load DNS.
	# But, when running over the network, disabling the network even for a moment can at best cause the system to hang for a couple minutes and at worst can cause it to hang indefinitely, so that is not a feasible workaround.
	# Instead, we will directly specify a DNS server once the system has fully booted, which makes the nework immediate start working.
	# Below, the local Free Geek DNS server is assigned for every available network connection on the system (just to be completely thorough since setting DNS for any inactive connnections doesn't hurt).
	# It would also be possible to use "resolvectl dns" to set the DNS server, but since I'm getting the interface names from "nmcli", I'll continue using "nmcli" to set the DNS server.

	while IFS='' read -r this_network_interface_name; do
		echo -e ">>\n>\nVERIFY SCRIPT DEBUG: MANUALLY SETTING DNS SERVER FOR \"${this_network_interface_name}\"\n<\n<<"
		nmcli connection modify "${this_network_interface_name}" ipv4.dns '192.168.253.11' # Local Free Geek DNS server IP.
	done < <(nmcli -t -f NAME connection show)
fi


echo -e "#!/bin/bash\n\ncurl -m 5 -sfL 'http://tools.freegeek.org/qa-helper/log_install_time.php' \\" > '/tmp/post_install_time.sh'

if [[ "${MODE}" == 'testing' && -f '/cdrom/preseed/dependencies/xterm' && -x '/cdrom/preseed/dependencies/xterm' ]]; then
	LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -geometry 80x25+0+0 -sb -sl 999999 -rightbar -e 'echo -e "USE ME FOR DEBUGGING\n\n"; bash' &
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

	size_precision='%.1f' # Show sizes with a single decimal of precision...
	if (( bytes >= 1000000000 && bytes < 1000000000000 )); then # ...unless the size is in the GBs range, then just show whole numbers.
		size_precision='%.0f'
	fi

	if converted_size="$(numfmt --to si --round nearest --format "${size_precision}" "$1" 2> /dev/null)"; then
		converted_size_number="${converted_size%%[^0123456789.]*}" # Remove any trailing non-digits to get size number.
		converted_size_number="${converted_size_number%.0}" # Non-GB sizes will always have 1 decimal precision, but not want to display ".0" so remove it from tail if it exists.

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

while true; do
	if nmcli device status | grep -qF ' wifi ' && ! nmcli device status | grep ' FG Staff' | grep -qF ' connected '; then
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING ATTEMPT TO CONNECT TO "FG Staff" WI-FI\n<\n<<'

		# Try to connect to "FG Staff" for fast Wi-Fi that can also connect to fglan (useful for "toram" network live boots that can continue after being disconnected from Ethernet).
		{
			for wifi_connection_attempt in {1..2}; do # Try 2 times to connect to Wi-Fi just in case it fails the first time for any reason.
				rfkill unblock all
				nmcli radio all on
				nmcli device wifi connect 'FG Staff' password '[PREPARE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]'

				sleep 1

				echo "${wifi_connection_attempt}" > '/tmp/wifi_connection_attempt.txt' # To get value outside of this Zenity piped sub-shell.

				if nmcli device status | grep ' FG Staff' | grep -qF ' connected '; then
					break
				fi
			done
		} | zenity \
			--progress \
			--title 'Connecting to Wi-Fi' \
			--text '\n<big><b>Please wait while connecting to Wi-Fi...</b></big>\n' \
			--width '450' \
			--auto-close \
			--no-cancel \
			--pulsate

		echo -e ">>\n>\nVERIFY SCRIPT DEBUG: FINISHED CONNECT TO \"FG Staff\" WI-FI AFTER $(< '/tmp/wifi_connection_attempt.txt') ATTEMPTS\n<\n<<"

		rm -f '/tmp/wifi_connection_attempt.txt'
	fi

	if ! timedatectl status | grep -qF 'Time zone: America/Los_Angeles'; then
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING SET TIME ZONE TO PDT\n<\n<<'

		# Make sure proper time is set so https download works.
		timedatectl set-timezone America/Los_Angeles
		timedatectl set-ntp true

		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED SET TIME ZONE TO PDT\n<\n<<'
	fi

	if timedatectl status | grep -qF 'System clock synchronized: no'; then
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING WAIT FOR TIME TO SYNC\n<\n<<'

		{
			timedatectl set-ntp false # Turn time syncing off and then
			timedatectl set-ntp true # back on to provoke faster sync attempt

			for wait_for_time_sync_seconds in {1..30}; do # Wait up to 30 seconds for time to sync becuase download can stall if time changes in the middle of it.
				sleep 1

				echo "${wait_for_time_sync_seconds}" > '/tmp/wait_for_time_sync_seconds.txt' # To get value outside of this Zenity piped sub-shell.

				if timedatectl status | grep -qF 'System clock synchronized: yes'; then
					break
				fi
			done
		} | zenity \
			--progress \
			--title 'Syncing Date & Time From Internet' \
			--text '\n<big><b>Please wait while syncing date and time from the internet...</b></big>\n' \
			--width '450' \
			--auto-close \
			--no-cancel \
			--pulsate

		echo -e ">>\n>\nVERIFY SCRIPT DEBUG: FINISHED WAIT FOR TIME TO SYNC AFTER $(< '/tmp/wait_for_time_sync_seconds.txt') SECONDS\n<\n<<"

		rm -f '/tmp/wait_for_time_sync_seconds.txt'
	fi

	if timedatectl status | grep -qF 'System clock synchronized: yes'; then
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: TIME IS SYNCED - SETTING SYSTEM TIME TO HWCLOCK\n<\n<<'

		# Update hardware (BIOS) clock with synced system time.
		hwclock --systohc

		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED SETTING SYSTEM TIME TO HWCLOCK\n<\n<<'
	else
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: TIME IS NOT SYNCED\n<\n<<'
	fi

	echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING "QA Helper" DOWNLOAD\n<\n<<'

	rm -f 'QAHelper-linux-jar.zip' 'QA_Helper.jar'

	if ( # See comments below "zenity" command about why this is loop and pipe to "zenity" is in a SUBSHELL.
		for download_qa_helper_attempt in {1..6}; do
			# Occasionally the first download attempt in the pre-install environment goes very slow or hangs for some reason. But, the next attempt will work properly and quickly.
			# So, to accommodate this possible flakiness while still finishing quickly whether or not the first download is slow, timeout after 5 seconds.
			# BUT, also CONTINUE/resume previously timed out downloads (by specifying "-C -" and NOT deleting the ".zip" when timed out).
			# This way, any timed out downloads are not a total waste of time and the download should finish within 2 attempts, but 6 attempts will be made to be extra safe.
			# (The "curl" builtin "--retry" option cannot be used for this scenario since it DOES NOT honor the "-C -" option and will delete and start over the download on each re-attempt.)

			if (( download_qa_helper_attempt > 1 )) && [[ "$(wmctrl -l 2> /dev/null)"$'\n' != *$' Downloading QA Helper\n'* ]]; then
				# If "zenity --progress" is manually canceled, the loop would continue in the background (see comments below "zenity" command for more info).
				# So, check if the progress window has been closed and break the loop if so.
				# But, must NOT check right when loop starts since it takes a moment for the progress window to open (which could be after this check would be done on the first iteration).
				# NOTE: When the "zenity" window is *closed* (not canceled), "wmctrl -l" will output the expected window list which will not include the "zenity" progress window and break the loop.
				# BUT, when "zenity" is *canceled* (which exits this subshell), "wmctrl -l" may error and return nothing, which will still properly result in the test failing and breaking the loop.
				break
			fi

			curl -m 5 -C - -sfLO "http$([[ "${MODE}" == 'testing' ]] && echo '://tools' || echo 's://apps').freegeek.org/qa-helper/download/QAHelper-linux-jar.zip"
			curl_exit_code="$?"

			if [[ -f 'QAHelper-linux-jar.zip' ]]; then
				if (( curl_exit_code == 0 )); then
					unzip -jqo 'QAHelper-linux-jar.zip' 'QA_Helper.jar' # NOTE: Must specify "-q" since if the "zenity" window is *closed* "curl" could finish successfully and this "unzip" command could still be run, but the pipe will be broken and any command that tries to send to stdout will fail with a broken pipe error. This issue is avoided by not having "unzip" ever send anything to stdout.
					rm 'QAHelper-linux-jar.zip'

					if [[ -f 'QA_Helper.jar' ]]; then
						break
					fi
				elif (( curl_exit_code != 28 )); then # If timed out ("curl" exit code "28"), DO NOT delete the incomplete ".zip" since it will be resumed by "curl" since "-C -" is specified.
					rm -f 'QAHelper-linux-jar.zip'
				fi
			fi

			if (( download_qa_helper_attempt > 1 )) && [[ "$(wmctrl -l 2> /dev/null)"$'\n' != *$' Downloading QA Helper\n'* ]]; then
				# Since "zenity --progress" could be canceled at any point in this loop body, we must also check if the progress window is closed at the end to be able to break before sleeping.
				# And also still don't check on the first iteration since if "curl" failed very quickly (such as when internet is not available), the progress window may still not be open yet.
				break
			fi

			if (( download_qa_helper_attempt < 6 )); then # Don't sleep after final attempt.
				sleep "${download_qa_helper_attempt}"
			fi
		done | zenity \
			--progress \
			--title 'Downloading QA Helper' \
			--text '\n<big><b>Please wait while downloading QA Helper...</b></big>\n\nIf download is taking too long, press "Cancel" and then "Try Again".\n' \
			--width '450' \
			--pulsate \
			--auto-close \
			--auto-kill
			# DO NOT set "--no-cancel" for this "zenity --progress" so that the download can be stopped early it's hanging and the technican doesn't want to wait for all the re-attempts to complete.
			# "--auto-kill" is set so that if the progress is canceled, the script doesn't just continue hanging on the stalled out "curl" command.
			# BUT, for "--auto-kill" to NOT terminate the WHOLE script, the entire loop and pipe to "zenity" MUST be in a SUBSHELL (in parenthesis) so that only the subshell is terminated rather than the whole parent script.
			# When cancel is pressed, the subshell will exit immediately with a non-zero exit code and the script will continue, BUT the loop continue and child processes of the subshell (ie. "curl", "sleep", etc) could still be running in the background when that happens.
			# So, a "loop-canceled" flag file will be set and "curl" and "sleep" will be manually killed in the "else" statement below when the subshell exits with a non-zero exit code (ie. when "zenity --progress" is canceled)
			# so that the processes will stop and the loop can check for the flag to break when canceled instead of continuing in the backgroud.
	); then
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED "QA Helper" DOWNLOAD\n<\n<<'
	elif [[ -f 'QA_Helper.jar' ]]; then # When the "zenity" window is *closed* (not canceled), the subshell is not exited immediately and loop will continue (until it is manually broken by checking if the "zenity" window is no longer open).
		# If the "zenity" window is closed when "curl" is running and "curl" finishes successfully, the ".jar" could successfully be unzipped.
		# BUT, since the "zenity" window was closed, "zenity" will end with a non-zero exit code of 1, which makes the primary success condition not get hit.
		# So, check if the ".jar" exists on failure and still consider it a success even though it finished with the progress window closed and a non-zero exit code.

		while pgrep -f '^unzip .*QA_Helper\.jar$' &> /dev/null; do # BUT ALSO, if *canceled* at the perfect time when "curl" finished but "unzip" may still be running in the background, wait for it to finish since the download actually finished properly.
			echo -e '>>\n>\nVERIFY SCRIPT DEBUG: WAITING FOR UNZIP TO FINISH AFTER CANCELING "QA Helper" DOWNLOAD (BUT DOWNLOAD ALREADY FINISHED)\n<\n<<'
			sleep 1
		done

		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED "QA Helper" DOWNLOAD (WITH PROGRESS WINDOW CLOSED)\n<\n<<'
	else
		pkill -f '^curl .*/QAHelper-linux-jar\.zip$' || pkill -f '^unzip .*QA_Helper\.jar$' || killall sleep
		rm -f 'QAHelper-linux-jar.zip' 'QA_Helper.jar'
		echo -e '>>\n>\nVERIFY SCRIPT DEBUG: CANCELED "QA Helper" DOWNLOAD\n<\n<<'
	fi

	if [[ -f 'QA_Helper.jar' && -f '/cdrom/preseed/dependencies/java-jre/bin/java' && -x '/cdrom/preseed/dependencies/java-jre/bin/java' ]] && '/cdrom/preseed/dependencies/java-jre/bin/java' -jar 'QA_Helper.jar'; then # Only continue if the "QA_Helper.jar" file was valid and able to be lauched by "java -jar".
		desktop_environment="$(awk -F '=' '($1 == "Name") { print $2; exit }' '/usr/share/xsessions/'*)" # Can't get desktop environment from DESKTOP_SESSION or XDG_CURRENT_DESKTOP in pre-install environment.
		desktop_environment="${desktop_environment%% (*)}"
		if [[ -n "${desktop_environment}" ]]; then
			desktop_environment=" (${desktop_environment})"
		fi

		release_codename="$(lsb_release -cs 2> /dev/null)"
		if [[ -n "${release_codename}" ]]; then
			release_codename=" ${release_codename^}"
		fi


		while true; do
			declare -a install_drives_array=()

			while IFS='"' read -r _ this_drive_full_id _ this_drive_size_bytes _ this_drive_transport _ this_drive_rota _ this_drive_type _ this_drive_removable _ this_drive_read_only _ this_drive_brand _ this_drive_model; do
				# Split lines on double quotes (") to easily extract each value out of each "lsblk" line, which will be like: NAME="/dev/sda" SIZE="1234567890" TRAN="sata" ROTA="0" TYPE="disk" RM="0" RO="0" VENDOR="Some Brand" MODEL="Some Model Name"
				# Use "_" to ignore field titles that we don't need. See more about "read" usages with IFS and skipping values at https://mywiki.wooledge.org/BashFAQ/001#Field_splitting.2C_whitespace_trimming.2C_and_other_input_processing
				# NOTE: I don't believe the model name should ever contain double quotes ("), but if somehow it does having it as the last variable set by "read" means any of the remaining double quotes will not be split on and would be included in the value (and no other values could contain double quotes).

				if [[ "${this_drive_type}" == 'disk' && "${this_drive_removable}" == '0' && "${this_drive_read_only}" == '0' && -n "${this_drive_size_bytes}" && "${this_drive_size_bytes}" != '0' && ( "${this_drive_transport}" == *'ata' || "${this_drive_transport}" == 'nvme' || "${this_drive_transport}" == 'mmc' ) ]]; then # Only list DISKs with a SIZE that have a TRANsport type of SATA or ATA or NVMe or MMC (for eMMC embedded Memory Cards, which is confirmed below).
					this_drive_id="${this_drive_full_id##*/}"

					mmc_is_embedded=false
					if [[ "${this_drive_transport}" == 'mmc' ]]; then
						mmc_type="$(udevadm info --query 'property' --property 'MMC_TYPE' --value -p "/sys/class/block/${this_drive_id}" 2> /dev/null)"
						if [[ "${mmc_type}" == 'MMC' || ( -z "${mmc_type}" && "$(udevadm info --query 'symlink' -p "/sys/class/block/${this_drive_id}" 2> /dev/null)" != *'/by-id/mmc-USD_'* )]]; then
							# Only show eMMC which should have "MMC_TYPE" of "MMC" rather than "SD" (regular Memory Cards can still show as non-removable from "lsblk" though).
							# Or, if "MMC_TYPE" doesn't exist (on older versions of "udevadm"?), eMMC should have some UDEV ID starting with other than "USD_" which would indicate an actual Memory Card.
							mmc_is_embedded=true
						fi
					fi

					if [[ "${this_drive_transport}" != 'mmc' ]] || $mmc_is_embedded; then
						this_drive_brand="$(trim_and_squeeze_whitespace "${this_drive_brand//_/ }")" # Replace all underscores with spaces (see comments for model below).

						this_drive_model="${this_drive_model%\"}" # If somehow the model contained quotes the trailing quote will be included by "read", so remove it.
						this_drive_model="${this_drive_model//_/ }" # Replace all underscores with spaces since "lsblk" version 2.34 (which shipped with Mint 20.X) seems to include them where spaces should be, but version 2.37.2 which shipped with Mint 21.X properly has spaces instead of underscore. Even though we're currently installing Mint 21.1 (or newer if I forget to update these comments), still replace them just in case it's still needed for some drive models that I haven't seen in my testing.
						this_drive_model="$(trim_and_squeeze_whitespace "${this_drive_model}")"
						# NOTE: Prior to "lsblk" (part of "util-linux") version 2.33, truncated model names would be retrieved from from sysfs ("/sys/block/<name>/device/model"), so we would manually retrieve the full model name from "hdparm".
						# But, starting with version 2.33, "lsblk" retrieves full model names from "udev": https://github.com/util-linux/util-linux/blob/master/Documentation/releases/v2.33-ReleaseNotes#L394
						# Mint 20 was the first to ship with "lsblk" version 2.34 while Mint 19.3 shipped with version 2.31.1 which still retrieved truncated drive model names.
						# Since we haven't installed Mint 19.3 for multiple years, just use the model name from "lsblk" since it will always be the full model for our usage.

						if [[ -n "${this_drive_brand}" && ' GENERIC ATA ' != *" ${this_drive_brand^^} "* ]]; then # TODO: Find and ignore other generic VENDOR strings.
							if [[ -z "${this_drive_model}" ]]; then
								this_drive_model="${this_drive_brand}"
							elif [[ "${this_drive_model,,}" != *"${this_drive_brand,,}"* ]]; then
								this_drive_model="${this_drive_brand} ${this_drive_model}"
							fi
						fi

						this_drive_health='UNKNOWN'
						if [[ -f '/cdrom/preseed/dependencies/hdsentinel' && -x '/cdrom/preseed/dependencies/hdsentinel' && -f '/cdrom/preseed/dependencies/xmllint' && -x '/cdrom/preseed/dependencies/xmllint' ]]; then
							hdsentinel_output_path_for_this_drive="/tmp/hdsentinel-${this_drive_id}.xml"
							timeout -s SIGKILL 3 '/cdrom/preseed/dependencies/hdsentinel' -dev "${this_drive_full_id}" -xml -r "${hdsentinel_output_path_for_this_drive}" &> /dev/null
							# NOTE: Loading "hdsentinel" INDIVIDUALLY for each drive it more reliable because if one drive is bad/flakey and causes "hdsentinel" to hang then only that drive doesn't show health data rather than no health data getting loaded for any drives.

							declare -a hdsentinel_failed_attributes=()

							if [[ -s "${hdsentinel_output_path_for_this_drive}" ]]; then
								hdsentinel_power_on_time="$('/cdrom/preseed/dependencies/xmllint' --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Power_on_time)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
								if [[ -n "${hdsentinel_power_on_time}" && "${hdsentinel_power_on_time}" == *' days'* && "${hdsentinel_power_on_time%% *}" -ge 2500 ]]; then
									hdsentinel_failed_attributes+=( 'Power On Time' )
								fi

								hdsentinel_estimated_lifetime="$('/cdrom/preseed/dependencies/xmllint' --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Estimated_remaining_lifetime)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
								if [[ -n "${hdsentinel_estimated_lifetime}" && ( "${hdsentinel_estimated_lifetime}" != *' days'* || "${hdsentinel_estimated_lifetime//[^0123456789]/}" -lt 400 ) ]]; then
									hdsentinel_failed_attributes+=( 'Estimated Lifetime' )
								fi

								hdsentinel_description="$('/cdrom/preseed/dependencies/xmllint' --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Description)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
								if [[ -n "${hdsentinel_description}" && "${hdsentinel_description}" != *'is PERFECT.'* ]]; then
									hdsentinel_failed_attributes+=( 'Description' )
								fi

								hdsentinel_tip="$('/cdrom/preseed/dependencies/xmllint' --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Tip)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
								if [[ -n "${hdsentinel_tip}" && "${hdsentinel_tip}" != 'No actions needed.' ]]; then
									hdsentinel_failed_attributes+=( 'Tip' )
								fi

								if (( ${#hdsentinel_failed_attributes[@]} == 0 )); then
									if [[ -n "${hdsentinel_power_on_time}" || -n "${hdsentinel_estimated_lifetime}" || -n "${hdsentinel_description}" || -n "${hdsentinel_tip}" ]]; then
										this_drive_health='Pass'
									fi
								else
									printf -v hdsentinel_failed_attributes_display '%s, ' "${hdsentinel_failed_attributes[@]}"
									this_drive_health="FAIL (${hdsentinel_failed_attributes_display%, })"
								fi
							fi

							rm -rf "${hdsentinel_output_path_for_this_drive}"
						fi

						if [[ "${this_drive_transport}" == 'mmc' ]]; then
							this_drive_transport='emmc' # Only internal embedded MMC drives will be detected based on conditions above, so display them as "eMMC".
						fi
						
						install_drives_array+=(
							"${this_drive_full_id}"
							"${this_drive_id}"
							"${this_drive_health}"
							"$(human_readable_size_from_bytes "${this_drive_size_bytes}")"
							"${this_drive_transport^^[^e]} $( (( this_drive_rota )) && echo 'HDD' || echo 'SSD' )"
							"${this_drive_model:-UNKNOWN Drive Model}"
						)
					fi
				fi
			done < <(lsblk -abdPpo 'NAME,SIZE,TRAN,ROTA,TYPE,RM,RO,VENDOR,MODEL' -x 'SIZE') # Sort "lsblk" output by size smallest to largest because we will generally want to install onto the smallest drive.

			if (( "${#install_drives_array[@]}" >= 6 )); then
				readarray -t install_drive_details_array < <(zenity \
					--list \
					--title 'Choose Installation Drive' \
					--width '530' \
					--height '250' \
					--text "<big><b>\t\tWhich drive would you like to <u>COMPLETELY ERASE</u>\t\t\n\t\tand <u>INSTALL</u> <i>$(lsb_release -ds 2> /dev/null)${release_codename}${desktop_environment}</i> onto?\t\t</b></big><span size='4000'>\n </span>" \
					--column 'Full ID' \
					--column 'ID' \
					--column 'Health' \
					--column 'Size' \
					--column 'Kind' \
					--column 'Model' \
					--hide-column 1 \
					--print-column 'ALL' \
					--separator '\n' \
					"${install_drives_array[@]}")

				if [[ "${#install_drive_details_array[@]}" == 6 && "${install_drive_details_array[0]}" == '/'* ]]; then
					allow_install_on_selected_drive=false

					if [[ "${install_drive_details_array[2]}" != 'FAIL'* ]]; then
						allow_install_on_selected_drive=true
					elif ! drive_health_failed_dialog_response="$(zenity --question --title 'Selected Drive Failed Health Check' --no-wrap --ok-label 'Cancel Installation' --cancel-label 'Cancel & Shut Down' --extra-button 'Install Anyway' --text "<big><b>Selected Drive <u>Failed Health Check</u></b></big>\n\n<tt><small><b>    ID:</b></small></tt> ${install_drive_details_array[1]}\n<tt><small><b>Health:</b></small></tt> ${install_drive_details_array[2]}\n<tt><small><b>  Size:</b></small></tt> ${install_drive_details_array[3]}\n<tt><small><b>  Kind:</b></small></tt> ${install_drive_details_array[4]}\n<tt><small><b> Model:</b></small></tt> ${install_drive_details_array[5]}")"; then
						if [[ "${drive_health_failed_dialog_response}" == 'Install Anyway' ]]; then
							allow_install_on_selected_drive=true
						else
							systemctl poweroff
							exit 1
						fi
					fi

					if $allow_install_on_selected_drive; then
						debconf-set partman-auto/disk "${install_drive_details_array[0]}"
						debconf-set grub-installer/bootdev "${install_drive_details_array[0]}"

						if [[ "$(debconf-get partman-auto/disk)" == "${install_drive_details_array[0]}" && "$(debconf-get grub-installer/bootdev)" == "${install_drive_details_array[0]}" ]]; then
							if zenity --question --title 'Confirm Installation' --no-wrap --text "<big><b>Are you sure you want to <u>COMPLETELY ERASE</u> the following\ndrive and <u>INSTALL</u> <i>$(lsb_release -ds 2> /dev/null)${release_codename}${desktop_environment}</i> onto it?</b></big>\n\n<tt><small><b>    ID:</b></small></tt> ${install_drive_details_array[1]}\n<tt><small><b>Health:</b></small></tt> ${install_drive_details_array[2]}\n<tt><small><b>  Size:</b></small></tt> ${install_drive_details_array[3]}\n<tt><small><b>  Kind:</b></small></tt> ${install_drive_details_array[4]}\n<tt><small><b> Model:</b></small></tt> ${install_drive_details_array[5]}"; then
								echo "--data-urlencode \"version=$(lsb_release -ds 2> /dev/null)${release_codename}${desktop_environment}\" --data-urlencode \"drive_type=${install_drive_details_array[3]}\" --data-urlencode \"base_start_time=$(date +%s)\" \\" >> '/tmp/post_install_time.sh'

								killall java xterm firefox 2> /dev/null # Always try to killall "java" to close Keyboard Test and also killall "xterm" and "firefox" because they could have been opened by QA Helper even when not in test mode.

								exit 0
							fi
						elif ! zenity --question --title 'Failed to Set Installation Drive' --no-wrap --ok-label 'Try Again' --cancel-label 'Reboot' --text '<big><b>There was an unknown issue setting the installation drive.</b></big>\n\nIf this happens again, try rebooting back into this installation environment.\n\n<i>If this continues to fail, please inform your manager and Free Geek I.T.</i>'; then
							systemctl reboot
							exit 32
						fi
					fi
				fi
			else
				zenity --error --title 'No Internal Drives Detected' --no-wrap --text '\n<big><b>No internal drives were detected for installation.</b></big>'
			fi

			if cancel_installation_response="$(zenity --question --title 'Cancel Installation?' --no-wrap --ok-label 'Cancel & Shut Down' --cancel-label 'Re-Select Installation Drive' --extra-button 'Cancel & Reboot' --extra-button 'Re-Open QA Helper' --text '\n<big><b>Are you sure you want to cancel this installation?</b></big>')"; then
				systemctl poweroff
				exit 1
			elif [[ "${cancel_installation_response}" == 'Cancel & Reboot' ]]; then
				systemctl reboot
				exit 1
			elif [[ "${cancel_installation_response}" == 'Re-Open QA Helper' ]]; then
				break
			fi
		done
	else
		if ! failed_download_response="$(zenity --question --title 'Failed to Download QA Helper' --no-wrap --ok-label 'Try Again' --cancel-label 'Reboot' --extra-button 'Shut Down' --text '<big><b>Failed to download QA Helper.</b></big>\n\n<u>Internet is required to be able to properly install Linux Mint.</u>\n\nBefore trying again, make sure an Ethernet cable is connected securely.\n\nIf this happens again, reboot into BIOS and make sure this computers date and time is set correctly.\nThen, boot back into this installation environment and try again.\n\n<i>If this continues to fail, please inform your manager and Free Geek I.T.</i>')"; then
			if [[ "${failed_download_response}" == 'Shut Down' ]]; then
				systemctl poweroff
				exit 23
			else
				systemctl reboot
				exit 23
			fi
		fi
	fi
done

exit 42 # Should never get here
