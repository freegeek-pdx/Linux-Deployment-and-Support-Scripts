#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) & Aileen Miller (of Free Geek)
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

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

if [[ -t 1 ]]; then # ONLY use ANSI styling if stdout IS associated with an interactive terminal.
	CLEAR_ANSI='\033[0m' # Clears all ANSI colors and styles.
	# Start ANSI colors with "0;" so they clear all previous styles for convenience in ending bold and underline sections.
	ANSI_RED='\033[0;91m'
	ANSI_GREEN='\033[0;32m'
	ANSI_YELLOW='\033[0;33m'
	ANSI_PURPLE='\033[0;35m'
	ANSI_CYAN='\033[0;36m'
	ANSI_GREY='\033[0;90m'
	# Do NOT start ANSI_BOLD and ANSI_UNDERLINE with "0;" so they can be combined with colors and each other.
	ANSI_BOLD='\033[1m'
	ANSI_UNDERLINE='\033[4m'
	if [[ -z "${DISPLAY}" ]]; then # In non-GUI environment, UNDERLINE is rendered as CYAN, so make it BOLD instead.
		ANSI_UNDERLINE="${ANSI_BOLD}"
	fi
fi
readonly CLEAR_ANSI ANSI_RED ANSI_GREEN ANSI_YELLOW ANSI_PURPLE ANSI_CYAN ANSI_GREY ANSI_BOLD ANSI_UNDERLINE

readonly APP_NAME="${0% (*}" # When called via "bash -c [SCRIPT] [ARGS]", "$0" will be set to "App Name (Version) - [TERMINATOR PROCESS INDEX]" OR "App Name (Version) - CLI Mode".
APP_VERSION="${0#* (}"
readonly APP_VERSION="${APP_VERSION%)*}"

APP_NAME_FOR_FILE_PATHS="${APP_NAME,,}"
readonly APP_NAME_FOR_FILE_PATHS="${APP_NAME_FOR_FILE_PATHS// /-}"

readonly DATE_DISPLAY_FORMAT_STRING='+%a %b %-d, %Y at %-I:%M:%S %p'

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

TERMINATOR_PROCESS_INDEX=''
WAS_LAUNCHED_FROM_GUI_MODE=false
WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE=false
if [[ "$0" != *' - CLI Mode' ]]; then
	WAS_LAUNCHED_FROM_GUI_MODE=true
	TERMINATOR_PROCESS_INDEX="${0#* - }"
elif grep -qF " ${APP_NAME_FOR_FILE_PATHS}-auto-" '/proc/cmdline' && [[ "$(ps -p "$(ps -p "$(ps -p "$PPID" -o 'ppid=' 2> /dev/null | trim_and_squeeze_whitespace)" -o 'ppid=' 2> /dev/null | trim_and_squeeze_whitespace)" -o 'args=' 2> /dev/null)" == *"/terminator --title ${APP_NAME} (Auto "* ]]; then
	# Free Geek's custom Debian-based Live Boot (FG Eraser Live) uses custom boot arguments to be able to specify the mode for FG Eraser to auto-start into after boot, so check for these boot args to determine if was booted into an auto-mode.
	WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE=true
fi
readonly TERMINATOR_PROCESS_INDEX WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE WAS_LAUNCHED_FROM_GUI_MODE

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

desktop_environment=''
if [[ -d '/usr/share/xsessions' ]]; then
	desktop_environment="$(awk -F '=' '($1 == "Name") { print $2; exit }' '/usr/share/xsessions/'*)" # Can't get desktop environment from DESKTOP_SESSION or XDG_CURRENT_DESKTOP in pre-install environment.
	desktop_environment="${desktop_environment%% (*)}"
	if [[ -n "${desktop_environment}" ]]; then
		desktop_environment=" (${desktop_environment})"
	fi
fi

release_codename="$(lsb_release -cs 2> /dev/null)"
if [[ -n "${release_codename}" ]]; then
	release_codename=" ${release_codename^}"
fi

debian_version=''
if [[ -f '/etc/debian_version' ]]; then
	debian_version=" $(< '/etc/debian_version')"
fi

OS_NAME="$(lsb_release -ds 2> /dev/null)${release_codename}${debian_version}${desktop_environment}"
readonly OS_NAME

readonly PRIVATE_STRINGS_PASSWORD_PATH="/usr/share/${APP_NAME_FOR_FILE_PATHS}/${APP_NAME_FOR_FILE_PATHS}-password.txt"
# NO LONGER DOWNLOAD PRIVATE STRINGS PASSWORD SINCE WE *ONLY* WANT TO ALLOW RUNNING ON UP-TO-DATE USBs AND NETBOOT.
# if [[ ! -s "${PRIVATE_STRINGS_PASSWORD_PATH}" ]] && ping -W 2 -c 1 'tools.freegeek.org' &> /dev/null; then # This URL is only available on Free Geek's LOCAL network.
# 	rm -rf "${PRIVATE_STRINGS_PASSWORD_PATH}"
# 	mkdir -p "${PRIVATE_STRINGS_PASSWORD_PATH%/*}"
# 	if ! curl -m 5 -sfL "http://tools.freegeek.org/${APP_NAME_FOR_FILE_PATHS}/${APP_NAME_FOR_FILE_PATHS}-password.txt" -o "${PRIVATE_STRINGS_PASSWORD_PATH}" &> /dev/null || [[ ! -f "${PRIVATE_STRINGS_PASSWORD_PATH}" ]]; then
# 		rm -rf "${PRIVATE_STRINGS_PASSWORD_PATH}"
# 	fi
# fi

if [[ ! -s "${PRIVATE_STRINGS_PASSWORD_PATH}" ]] || \
	! PRIVATE_STRINGS="$(echo 'U2FsdGVkX18+7CvBu1Zw1ZotpyiOjRTtC09DwAMTOvUxF9LnPaz7SAZhftaTP8OIOKgjAfSSAnh8wQLUZY99BhMzK9IWWJgRgbaxEcekpZLVnr8HN91hFx/EeVCZpCswGCH93BMgTMwcDrUqXfI0RL92TiBjS7dv/EM9pl90goxphMxnuyUsS7WnY+OX2rMY/KD2tv9aFBwhi2dBMyoUlPw7fNsrfdsKmvf9N5c0qP/fPWyrJz+mNSlVCftSaySk' | openssl enc -d -aes256 -md sha512 -a -A -pass file:"${PRIVATE_STRINGS_PASSWORD_PATH}" 2> /dev/null)" || \
	[[ -z "${PRIVATE_STRINGS}" ]]; then
	rm -rf "${PRIVATE_STRINGS_PASSWORD_PATH}"

	>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to decrypt private strings. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}"
	return 17 # Use same error code for same error in parent script.
fi

IFS=$'\n' read -rd '' EMAIL_SECRET_KEY SEND_ERROR_EMAIL_TO SEND_ERROR_EMAIL_FROM LOG_ACTION_SECRET_KEY <<< "${PRIVATE_STRINGS}"
readonly PRIVATE_STRINGS EMAIL_SECRET_KEY SEND_ERROR_EMAIL_TO SEND_ERROR_EMAIL_FROM LOG_ACTION_SECRET_KEY

if [[ -z "${EMAIL_SECRET_KEY}" || -z "${SEND_ERROR_EMAIL_TO}" || -z "${SEND_ERROR_EMAIL_FROM}" || -z "${LOG_ACTION_SECRET_KEY}" ]]; then
	rm -rf "${PRIVATE_STRINGS_PASSWORD_PATH}"

	>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to load decrypted private strings. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}"

	return 18 # Use same error code for same error in parent script.
fi

COMPUTER_INFO_FOR_ERROR_EMAIL="$(dmidecode -t 1 2> /dev/null | awk -F '\t|: ' '/^\t/ && ($2 != "UUID") && ($2 != "Wake-up Type") { printf "<b>" $2 ":</b> "; $1 = $2 = ""; print substr($0, 3) }')"
COMPUTER_INFO_FOR_ERROR_EMAIL="${COMPUTER_INFO_FOR_ERROR_EMAIL//$'\n'/<br\/>}"
ETHERNET_MAC="$(nmcli device show 2> /dev/null | awk '(($1 == "GENERAL.TYPE:") && ($2 == "ethernet")) { next_hw_addr_is_ethernet_mac = 1 } (next_hw_addr_is_ethernet_mac && ($1 == "GENERAL.HWADDR:")) { print $2; next_hw_addr_is_ethernet_mac = 0 }' | tr '\n' '+')"
ETHERNET_MAC="${ETHERNET_MAC%+}"
COMPUTER_INFO_FOR_ERROR_EMAIL+="<br/><b>MAC:</b> ${ETHERNET_MAC}"
readonly COMPUTER_INFO_FOR_ERROR_EMAIL ETHERNET_MAC

is_apple_mac="$([[ "${COMPUTER_INFO_FOR_ERROR_EMAIL}" == *' Apple'*'Mac'* ]] && echo 'true' || echo 'false')" # Check if running on Mac to NOT sleep since some don't wake back up after sleep, and I've seen others not unfreeze even when the did sleep (not sure of exact affected models for either issue though).

send_error_email() {
	error_message="$1"
	if [[ -n "${error_message}" ]]; then
		for get_location_attempt in {1..3}; do
			location_info="$(curl -m 3 -sfL 'https://api.freegeek.org/location' 2> /dev/null | head -1)"
			if [[ "${location_info}" == *','* ]]; then
				location_info="${location_info/,/, }"
				break
			elif (( get_location_attempt < 3 )); then
				sleep 3
			fi
		done

		if [[ -z "${location_info}" ]]; then
			location_info='UNKNOWN CITY, UNKNOWN STATE'
		fi

		# Strip any included ANSI styles (left in for convenience) for the email.
		# From: https://superuser.com/questions/380772/removing-ansi-color-codes-from-text-stream#comment2323889_380778
		error_message="$(echo -e "${error_message}" | sed $'s/\033\[[0-9;]*m//g')"

		error_message="${error_message//<br\/>/$'\n'}"
		error_message="${error_message//<br>/$'\n'}"
		error_message="${error_message//&/\&amp;}"
		error_message="${error_message//</\&lt;}"
		error_message="${error_message//>/\&gt;}"
		error_message="${error_message//$'\n'/<br\/>}"
		error_message="${error_message//$'\t'/\&nbsp;\&nbsp;\&nbsp;\&nbsp;}"

		error_message="<b>${APP_NAME} Version:</b> ${APP_VERSION}<br/><b>Location:</b> ${location_info}<br/><br/><b>Tech Initials:</b> ${technician_initials:-N/A}<br/><b>Lot Code:</b> ${lot_code:-N/A}<br/><b>Action Mode:</b> ${action_mode_name:-UNKNOWN}<br/><b>Method:</b> ${method_description:-UNKNOWN}<br/><br/><b>Drive ID:</b> ${erase_drive_id:-UNKNOWN}<br/><b>Size:</b> $(human_readable_size_from_bytes "${erase_drive_size_bytes}")<br/><b>Kind:</b> ${erase_drive_kind:-UNKNOWN}<br/><b>Model:</b> ${erase_drive_model:-UNKNOWN Drive Model}<br/><b>Serial:</b> ${erase_drive_serial:-UNKNOWN Drive Serial}<br/><br/><b>OS:</b> ${OS_NAME:-N/A}<br/>${COMPUTER_INFO_FOR_ERROR_EMAIL}<br/><br/><b>Error Message:</b><br/><span style=\"font-family: monospace;\">${error_message}</span>"

		for send_error_email_attempt in {1..3}; do
			send_error_email_result="$(curl --connect-timeout 5 -sfL 'https://api.freegeek.org/email' \
				--data-urlencode "key=${EMAIL_SECRET_KEY}" \
				--data-urlencode "from_email=${SEND_ERROR_EMAIL_FROM}" \
				--data-urlencode "from_name=${APP_NAME} Error" \
				--data-urlencode "to_email=${SEND_ERROR_EMAIL_TO}" \
				--data-urlencode "subject=${APP_NAME} Error" \
				--data-urlencode "body=${error_message}" 2> /dev/null)"
			send_error_email_exit_code="$?"

			if (( send_error_email_exit_code != 0 )) || [[ "${send_error_email_result}" != *'success' ]]; then
				>&2 echo -e "\n${ANSI_RED}${ANSI_BOLD}send_error_email ERROR:${ANSI_RED} ${send_error_email_result:-SEND ERROR ${send_error_email_exit_code}}$( (( send_error_email_attempt < 3 )) && echo " ${ANSI_YELLOW}${ANSI_BOLD}(TRYING AGAIN IN 3 SECONDS)")${CLEAR_ANSI}"
				if (( send_error_email_attempt < 3 )); then
					sleep 3
				fi
			else
				break
			fi
		done
	fi
}

log_action() {
	trap '' SIGINT # TODO: Does this actually block canceling the command?

	log_action_name="$1"
	log_status="$2"

	sent_log_error_email=false
	while true; do
		log_action_output="$(curl --connect-timeout 5 -sfL "https://eraser.freegeek.org/log_action.php?key=${LOG_ACTION_SECRET_KEY}" \
			--data-urlencode "tech_initials=${technician_initials}" \
			--data-urlencode "lot_code=${lot_code}" \
			--data-urlencode "action=${log_action_name}" \
			--data-urlencode "size=$(human_readable_size_from_bytes "${erase_drive_size_bytes}")" \
			--data-urlencode "kind=${erase_drive_kind:-UNKNOWN}" \
			--data-urlencode "model=${erase_drive_model:-UNKNOWN Drive Model}" \
			--data-urlencode "serial=${erase_drive_serial:-UNKNOWN Drive Serial}" \
			--data-urlencode "method=${method_description:-UNKNOWN}" \
			--data-urlencode "status=${log_status}" \
			--data-urlencode "overall_duration=${overall_duration}" \
			--data-urlencode "health_check_result=${health_check_result}" \
			--data-urlencode "verify_result=${verify_result}" \
			--data-urlencode "short_smart_test_result=NOT Implemented" \
			--data-urlencode "random_data_overwrite_result=${random_data_overwrite_result}" \
			--data-urlencode "ones_overwrite_result=${ones_overwrite_result}" \
			--data-urlencode "zeros_overwrite_result=${zeros_overwrite_result}" \
			--data-urlencode "format_nvm_result=${format_nvm_result}" \
			--data-urlencode "ata_secure_erase_result=${ata_secure_erase_result}" \
			--data-urlencode "scsi_sanitize_result=${scsi_sanitize_result}" \
			--data-urlencode "trim_result=${trim_result}" \
			--data-urlencode "long_smart_test_result=NOT Implemented" \
			--data-urlencode "version=${APP_VERSION}" \
			--data-urlencode "os=${OS_NAME}" \
			--data-urlencode "mac=${ETHERNET_MAC}" 2> /dev/null
		)"
		log_action_exit_code="$?"

		if [[ "${log_action_output}" == 'LOGGED' ]]; then
			break
		else
			if [[ -n "${log_action_output}" ]] && ! $sent_log_error_email && send_error_email "Log Action Error: ${log_action_output}"; then
				sent_log_error_email=true
			fi

			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} ${log_action_output:-LOG ERROR ${log_action_exit_code}}$([[ -z "${log_action_output}" ]] && echo -e " - ${ANSI_YELLOW}${ANSI_BOLD}\"eraser.freegeek.org\" UNREACHABLE${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}MAKE SURE INTERNET IS CONNECTED" || echo -e " - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.") ${ANSI_YELLOW}${ANSI_BOLD}(TRYING AGAIN IN 3 SECONDS)${CLEAR_ANSI}"
			sleep 3
		fi
	done

	trap - SIGINT
}

set_terminator_tab_title() {
	if $WAS_LAUNCHED_FROM_GUI_MODE || $WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE; then
		terminator_process_index_for_tab_title=''
		if $WAS_LAUNCHED_FROM_GUI_MODE && [[ "${TERMINATOR_PROCESS_INDEX}" =~ ^[0123456789]+$ ]]; then
			terminator_process_index_for_tab_title="${TERMINATOR_PROCESS_INDEX}: "
		fi

		echo -en "\e]0;${terminator_process_index_for_tab_title}$1\a" # Set "terminator" tab title: https://stackoverflow.com/a/22548561
	fi
}

technician_initials=''
lot_code=''
force_override_health_checks=false
erase_drive_id=''
action_mode=''
is_verify_mode=false

error_should_not_have_happened=false
overall_start_timestamp=''
overall_duration='NOT Started'
health_check_result='NOT Checked'
previous_health_check_result="${health_check_result}"
random_data_overwrite_result='NOT Performed'
ones_overwrite_result='NOT Performed'
zeros_overwrite_result='NOT Performed'
format_nvm_result='Support NOT Checked'
ata_secure_erase_result='Support NOT Checked'
scsi_sanitize_result='Support NOT Checked'
trim_result='NOT Attempted'
verify_result='NOT Performed'

fg_eraser() {
	set_terminator_tab_title "${APP_NAME}"

	if [[ -t 1 ]]; then # ONLY "clear" and re-display app title if stdout IS associated with an interactive terminal.
		if ! $WAS_LAUNCHED_FROM_GUI_MODE; then
			clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
		fi

		echo -e "\n  ${ANSI_PURPLE}${ANSI_BOLD}${APP_NAME}${CLEAR_ANSI} ${ANSI_GREY}(Version ${APP_VERSION})${CLEAR_ANSI}\n"
	fi

	if [[ "$(uname -o)" != 'GNU/Linux' ]]; then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Only compatible with GNU/Linux.${CLEAR_ANSI}"
		return 11 # Use same error code for same error in parent script.
	fi

	if (( ${EUID:-$(id -u)} != 0 )); then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Must be run as root.${CLEAR_ANSI}"
		return 16 # Use same error code for same error in parent script.
	fi

	specified_drive_full_id=''
	quick_mode=false
	was_launched_from_auto_mode=false
	OPTIND=1
	while getopts ':i:c:fd:evR103TSqA' this_option; do
		case "${this_option}" in
			'i') technician_initials="${OPTARG^^}" ;;
			'c') lot_code="${OPTARG^^}" ;;
			'f') force_override_health_checks=true ;;
			'd')
				specified_drive_full_id="${OPTARG,,}"
				if [[ "${specified_drive_full_id}" != '/dev/sd'* && "${specified_drive_full_id}" != '/dev/nvme'*'n'* && "${specified_drive_full_id}" != '/dev/mmcblk'* ]]; then # Only minimal validation is needed since this will never be called directly by a user and the passed value was already validated.
					>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid drive device ID specified for \"-d\" option.${CLEAR_ANSI}"
					return 21 # Use same error code for same error in parent script.
				fi
				erase_drive_id="${specified_drive_full_id##*/}"
				;;
			'e' | 'v' | 'R' | '1' | '0' | '3' | 'T' | 'S') action_mode="${this_option}" ;;
			'q') quick_mode=true ;;
			'A') was_launched_from_auto_mode=true ;;
			':')
				>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required parameter not specified for \"-${OPTARG}\" option.${CLEAR_ANSI}"
				return 22 # Use same error code for same error in parent script.
				;;
			*)
				>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid \"-${OPTARG}\" option specified.${CLEAR_ANSI}"
				return 23 # Use same error code for same error in parent script.
				;;
		esac
	done

	if [[ -n "${action_mode}" ]]; then
		if [[ "${action_mode}" == 'v' ]]; then
			is_verify_mode=true
		fi

		set_terminator_tab_title "$($is_verify_mode && echo 'Verifying' || echo 'Erasing') \"${erase_drive_id}\""
	fi

	IFS='"' read -r _ erase_drive_full_id _ erase_drive_size_bytes _ erase_drive_transport _ erase_drive_rota _ erase_drive_type _ erase_drive_read_only _ erase_drive_serial _ erase_drive_brand _ erase_drive_model < <(timeout -s SIGKILL 10 lsblk -abdPpo 'NAME,SIZE,TRAN,ROTA,TYPE,RO,SERIAL,VENDOR,MODEL' "${specified_drive_full_id}" 2> /dev/null)

	if [[ "${erase_drive_full_id}" != "${specified_drive_full_id}" || "${erase_drive_type}" != 'disk' ]]; then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive device ID \"${erase_drive_id}\" not found.${CLEAR_ANSI}"
		return 53 # Use same error code for same error in parent script.
	elif (( erase_drive_size_bytes == 0 )); then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive \"${erase_drive_id}\" size is 0 bytes and therefore cannot be verified or erased.${CLEAR_ANSI}"
		return 54 # Use same error code for same error in parent script.
	elif ! $is_verify_mode && (( erase_drive_read_only != 0 )); then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive \"${erase_drive_id}\" is READ ONLY and therefore cannot be erased.${CLEAR_ANSI}"
		return 55 # Use same error code for same error in parent script.
	fi

	boot_device_drive_id="$(findmnt -no 'SOURCE' '/')"
	if [[ "${boot_device_drive_id}" != '/dev/'* ]]; then # When booted into a Live Linux USB, "/" will be a RAM disk instead of the the physical boot device, so also check for specific known USB boot device paths.
		boot_device_drive_id="$(findmnt -no 'SOURCE' '/cdrom')" # For Mint Live USBs
		if [[ "${boot_device_drive_id}" != '/dev/'* ]]; then
			boot_device_drive_id="$(findmnt -no 'SOURCE' '/run/live/medium')" # For Debian Live USBs
		fi
	fi

	if [[ "${boot_device_drive_id}" == '/dev/sd'*[0123456789]* ]]; then
		# The boot device could be a partition like "/dev/sda2", so remove any numbers from the end of the device ID.
		boot_device_drive_id="${boot_device_drive_id%%[0123456789]*}"
	elif [[ "${boot_device_drive_id}" == '/dev/nvme'*'p'* || "${boot_device_drive_id}" == '/dev/mmcblk'*'p'* ]]; then
		# For NVMe drives, "boot_device_drive_id" from "lsblk" will include the namespace and partition, like the "n1" and "p5" suffixes in "/dev/nvme0n1p5".
		# Remove partiton to be able to identify and match the boot device ID below to NOT include it in the list of drives to erase.
		# Also, booting from an eMMC/Memory Card ("/dev/mmcblk#" devices) is possible, so remove the partition (the "p1" in "/dev/mmcblk0p1") suffix just in case.
		boot_device_drive_id="${boot_device_drive_id%%p*}"
	fi

	if [[ "${specified_drive_full_id}" == "${boot_device_drive_id}" ]]; then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive device ID \"${erase_drive_id}\" is the ${ANSI_BOLD}BOOT DEVICE${ANSI_RED} and therefore cannot be verified or erased.${CLEAR_ANSI}"
		return 56 # Use same error code for same error in parent script.
	fi

	erase_drive_brand="$(trim_and_squeeze_whitespace "${erase_drive_brand//_/ }")" # Replace all underscores with spaces (see comments for model below).

	erase_drive_model="${erase_drive_model%\"}" # If somehow the model contained quotes the trailing quote will be included by "read", so remove it.
	erase_drive_model="$(trim_and_squeeze_whitespace "${erase_drive_model//_/ }")" # Replace all underscores with spaces since "lsblk" version 2.34 (which shipped with Mint 20.X) seems to include them where spaces should be, but version 2.37.2 which shipped with Mint 21.X properly has spaces instead of underscore. Even though we're currently installing Mint 21.1 (or newer if I forget to update these comments), still replace them just in case it's still needed for some drive models that I haven't seen in my testing.
	# NOTE: Prior to "lsblk" (part of "erase_util-linux") version 2.33, truncated model names would be retrieved from from sysfs ("/sys/block/<name>/device/model"), so we would manually retrieve the full model name from "hdparm".
	# But, starting with version 2.33, "lsblk" retrieves full model names from "udev": https://github.com/util-linux/util-linux/blob/master/Documentation/releases/v2.33-ReleaseNotes#L394
	# Mint 20 was the first to ship with "lsblk" version 2.34 while Mint 19.3 shipped with version 2.31.1 which still retrieved truncated drive model names.
	# Since we haven't installed Mint 19.3 for multiple years, just use the model name from "lsblk" since it will always be the full model for our usage.

	if [[ -n "${erase_drive_brand}" && ' GENERIC ATA ' != *" ${erase_drive_brand^^} "* ]]; then # TODO: Find and ignore other generic VENDOR strings.
		if [[ -z "${erase_drive_model}" ]]; then
			erase_drive_model="${erase_drive_brand}"
		elif [[ "${erase_drive_model,,}" != *"${erase_drive_brand,,}"* ]]; then
			erase_drive_model="${erase_drive_brand} ${erase_drive_model}"
		fi
	fi

	erase_drive_is_ssd="$( (( erase_drive_rota )) && echo 'false' || echo 'true' )"

	if [[ "${erase_drive_transport}" == 'usb' ]] && smartctl_info_output="$(timeout -s SIGKILL 3 smartctl --json=g -i "${erase_drive_full_id}" 2>&1)"; then # "smartctl" can hang with funky/bad drives, so timeout to not hang forever.
		# NOTE: "smartctl" can retrieve actual drive info from *some* USB adapaters, while "lsblk" will just show the model and serial of the adapter itself.

		smartctl_info_model_name="$(echo "${smartctl_info_output}" | awk -F ' = "' '($1 == "json.model_name") { print $NF }')"
		smartctl_info_model_name="${smartctl_info_model_name%\";}"
		smartctl_info_model_name="${smartctl_info_model_name//\\\"/\"}"
		if [[ -n "${smartctl_info_model_name}" && "${smartctl_info_model_name}" != "${erase_drive_model}" ]]; then
			erase_drive_model="${smartctl_info_model_name}"
		fi

		smartctl_info_serial_number="$(echo "${smartctl_info_output}" | awk -F ' = "' '($1 == "json.serial_number") { print $NF }')"
		smartctl_info_serial_number="${smartctl_info_serial_number%\";}"
		smartctl_info_serial_number="${smartctl_info_serial_number//\\\"/\"}"
		if [[ -n "${smartctl_info_serial_number}" && "${smartctl_info_serial_number}" != "${erase_drive_serial}" ]]; then
			erase_drive_serial="${smartctl_info_serial_number}"
		fi

		if ! $erase_drive_is_ssd && [[ "${smartctl_info_output}" == *$'\njson.rotation_rate = 0;\n'* ]]; then  # "ROTA" from "lsblk" can be INCORRECT from some SSDs in external enclosures, so double-check it with "smartctl" which should be correct.
			erase_drive_is_ssd=true
		fi
	fi

	erase_drive_kind="$($erase_drive_is_ssd && echo 'SSD' || echo 'HDD')"
	if [[ "${erase_drive_transport}" == 'mmc' || "${erase_drive_full_id}" == '/dev/mmcblk'* ]]; then
		mmc_type="$(udevadm info --query 'property' --property 'MMC_TYPE' --value -p "/sys/class/block/${erase_drive_id}" 2> /dev/null)"
		if [[ "${mmc_type}" == 'MMC' || ( -z "${mmc_type}" && "$(udevadm info --query 'symlink' -p "/sys/class/block/${erase_drive_id}" 2> /dev/null)" != *'/by-id/mmc-USD_'* ) ]]; then
			# eMMC should have "MMC_TYPE" of "MMC" rather than "SD".
			# Or, if "MMC_TYPE" doesn't exist (on older versions of "udevadm"?), eMMC should have some UDEV ID starting with other than "USD_" which would indicate an actual Memory Card.
			erase_drive_kind='eMMC'
		else
			erase_drive_kind='Memory Card'
		fi
	elif [[ -n "${erase_drive_transport}" ]]; then
		erase_drive_kind="${erase_drive_transport^^[^e]} ${erase_drive_kind}"
	fi

	check_drive_health() {
		quiet_health_check_mode=false
		if [[ "$1" == '-q' ]]; then # In quiet health check mode, only output errors.
			quiet_health_check_mode=true
		fi

		previous_health_check_result="${health_check_result}"
		check_drive_health_output=''

		hdsentinel_output_path="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-hdsentinel-${erase_drive_id}.xml" # TODO: Randomize this path?
		rm -rf "${hdsentinel_output_path}"
		timeout -s SIGKILL 3 hdsentinel -dev "${erase_drive_full_id}" -xml -r "${hdsentinel_output_path}" &> /dev/null # For some rare drives, "hdsentinel" fails to load, so give it a timeout to not hang for too long if it's not going to load anything anyways.
		if [[ -s "${hdsentinel_output_path}" ]]; then
			declare -a hdsentinel_failed_attributes=()

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_health_percentage="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Health)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_health_percentage}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			else
				hdsentinel_health_percentage="${hdsentinel_health_percentage// %/%}"
			fi

			check_drive_health_output+="\n                ${this_hdsentinel_attribute_color}${ANSI_BOLD}Health:${this_hdsentinel_attribute_color} ${hdsentinel_health_percentage:-N/A}${CLEAR_ANSI}"

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_performance_percentage="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Performance)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_performance_percentage}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			else
				hdsentinel_performance_percentage="${hdsentinel_performance_percentage// %/%}"
			fi

			check_drive_health_output+="\n           ${this_hdsentinel_attribute_color}${ANSI_BOLD}Performance:${this_hdsentinel_attribute_color} ${hdsentinel_performance_percentage:-N/A}${CLEAR_ANSI}"

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_power_on_time="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Power_on_time)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_power_on_time}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			elif [[ "${hdsentinel_power_on_time}" == *' days'* && "${hdsentinel_power_on_time%% *}" -ge 2500 ]]; then
				hdsentinel_failed_attributes+=( 'Power On Time' )
				this_hdsentinel_attribute_color="${ANSI_RED}"
			fi

			check_drive_health_output+="\n         ${this_hdsentinel_attribute_color}${ANSI_BOLD}Power On Time:${this_hdsentinel_attribute_color} ${hdsentinel_power_on_time:-N/A}${CLEAR_ANSI}"

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_estimated_lifetime="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Estimated_remaining_lifetime)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_estimated_lifetime}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			elif [[ "${hdsentinel_estimated_lifetime}" != *' days'* || "${hdsentinel_estimated_lifetime//[^0123456789]/}" -lt 400 ]]; then
				hdsentinel_failed_attributes+=( 'Estimated Lifetime' )
				this_hdsentinel_attribute_color="${ANSI_RED}"
			fi

			check_drive_health_output+="\n    ${this_hdsentinel_attribute_color}${ANSI_BOLD}Estimated Lifetime:${this_hdsentinel_attribute_color} ${hdsentinel_estimated_lifetime:-N/A}${CLEAR_ANSI}"

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_total_written="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Lifetime_writes)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_total_written}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			fi

			check_drive_health_output+="\n         ${this_hdsentinel_attribute_color}${ANSI_BOLD}Total Written:${this_hdsentinel_attribute_color} ${hdsentinel_total_written:-N/A}${CLEAR_ANSI}"

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_description="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Description)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_description}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			elif [[ "${hdsentinel_description}" != *'is PERFECT.'* ]]; then
				hdsentinel_failed_attributes+=( 'Description' )
				this_hdsentinel_attribute_color="${ANSI_RED}"
			fi

			check_drive_health_output+="\n           ${this_hdsentinel_attribute_color}${ANSI_BOLD}Description:${this_hdsentinel_attribute_color} ${hdsentinel_description:-N/A}${CLEAR_ANSI}"

			this_hdsentinel_attribute_color="${CLEAR_ANSI}"
			hdsentinel_tip="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${erase_drive_full_id}']/../Tip)" "${hdsentinel_output_path}" 2> /dev/null | trim_and_squeeze_whitespace)"
			if [[ -z "${hdsentinel_tip}" ]]; then
				this_hdsentinel_attribute_color="${ANSI_YELLOW}"
			elif [[ "${hdsentinel_tip}" != 'No actions needed.' ]]; then
				hdsentinel_failed_attributes+=( 'Tip' )
				this_hdsentinel_attribute_color="${ANSI_RED}"
			fi

			check_drive_health_output+="\n                   ${this_hdsentinel_attribute_color}${ANSI_BOLD}Tip:${this_hdsentinel_attribute_color} ${hdsentinel_tip:-N/A}${CLEAR_ANSI}"

			rm -rf "${hdsentinel_output_path}"

			check_drive_health_output+="\n
    ${ANSI_PURPLE}${ANSI_BOLD}${ANSI_UNDERLINE}Power On Time${ANSI_PURPLE}${ANSI_BOLD} MUST be ${ANSI_UNDERLINE}LESS than 2500 days${ANSI_PURPLE}${ANSI_BOLD}.${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}${ANSI_UNDERLINE}Estimated Lifetime${ANSI_PURPLE}${ANSI_BOLD} MUST be ${ANSI_UNDERLINE}GREATER than 399 days${ANSI_PURPLE}${ANSI_BOLD}.${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}${ANSI_UNDERLINE}Description${ANSI_PURPLE}${ANSI_BOLD} MUST contain ${ANSI_UNDERLINE}is PERFECT${ANSI_PURPLE}${ANSI_BOLD}.${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}${ANSI_UNDERLINE}Tip${ANSI_PURPLE}${ANSI_BOLD} MUST be ${ANSI_UNDERLINE}No actions needed${ANSI_PURPLE}${ANSI_BOLD}.${CLEAR_ANSI}"

			if (( ${#hdsentinel_failed_attributes[@]} > 0 )); then
				printf -v hdsentinel_failed_attributes_display '%s, ' "${hdsentinel_failed_attributes[@]}"
				hdsentinel_failed_attributes_display="${hdsentinel_failed_attributes_display%, }"
				health_check_result="FAILED for ${hdsentinel_failed_attributes_display}"
				check_drive_health_output+="\n\n    ${ANSI_RED}${ANSI_BOLD}\"${erase_drive_id}\" Health Check FAILED for ${hdsentinel_failed_attributes_display}${CLEAR_ANSI}"

				>&2 echo -e "${check_drive_health_output}" # Always output errors even if in quiet health check mode.
				return 1
			elif [[ -n "${hdsentinel_power_on_time}" || -n "${hdsentinel_estimated_lifetime}" || -n "${hdsentinel_description}" || -n "${hdsentinel_tip}" ]]; then
				health_check_result='Passed'
				check_drive_health_output+="\n\n    ${ANSI_GREEN}${ANSI_BOLD}\"${erase_drive_id}\" Health Check Passed${CLEAR_ANSI}"
			else
				health_check_result='UNKNOWN'
				check_drive_health_output+="\n\n    ${ANSI_YELLOW}${ANSI_BOLD}\"${erase_drive_id}\" Health Check UNKNOWN - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
			fi
		else
			health_check_result='UNAVAILABLE'
			rm -rf "${hdsentinel_output_path}"
			check_drive_health_output+="\n    ${ANSI_YELLOW}${ANSI_BOLD}\"${erase_drive_id}\" Health Check UNAVAILABLE - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
		fi

		if ! $quiet_health_check_mode; then
			echo -e "${check_drive_health_output}"
		fi
	}

	min_drive_size_bytes="$($erase_drive_is_ssd && echo '100000000000' || echo '1000000000000')" # 100 GB min size for SSD, 1 TB min size for HDD.
	is_small_drive="$( (( erase_drive_size_bytes < min_drive_size_bytes )) && echo 'true' || echo 'false' )"

	update_erase_drive_summary() {
		if [[ "${health_check_result}" == 'NOT Checked' ]]; then
			check_drive_health -q 2> /dev/null
		fi

		drive_health_color="${ANSI_YELLOW}"
		erase_drive_health_note=''
		if [[ "${health_check_result}" == 'FAILED'* ]]; then
			drive_health_color="${ANSI_RED}"

			if $force_override_health_checks; then
				erase_drive_health_note=" ${ANSI_YELLOW}${ANSI_BOLD}(Health Checks OVERRIDDEN)"
			fi
		elif [[ "${health_check_result}" == 'Passed' ]]; then
			drive_health_color="${ANSI_GREEN}"
		fi

		drive_size_color="$($is_small_drive && echo "${ANSI_YELLOW}" || echo "${CLEAR_ANSI}")"

		erase_drive_summary="
  ${ANSI_BOLD}${ANSI_UNDERLINE}Drive Summary:${CLEAR_ANSI}

    ${ANSI_BOLD}Drive ID:${CLEAR_ANSI} ${erase_drive_id}
      ${drive_health_color}${ANSI_BOLD}Health:${drive_health_color} ${health_check_result}${erase_drive_health_note}${CLEAR_ANSI}
        ${drive_size_color}${ANSI_BOLD}Size:${drive_size_color} $(human_readable_size_from_bytes "${erase_drive_size_bytes}")$($is_small_drive && echo " ${ANSI_BOLD}(BELOW $(human_readable_size_from_bytes "${min_drive_size_bytes}"))")${CLEAR_ANSI}
        ${ANSI_BOLD}Kind:${CLEAR_ANSI} ${erase_drive_kind}
       ${ANSI_BOLD}Model:${CLEAR_ANSI} ${erase_drive_model:-UNKNOWN Drive Model}
      ${ANSI_BOLD}Serial:${CLEAR_ANSI} ${erase_drive_serial:-UNKNOWN Drive Serial}"

		if [[ -n "${action_mode}" ]]; then
			erase_drive_summary="${erase_drive_summary/Drive Summary:/$($is_verify_mode && echo 'Verify' || echo 'Erase') Drive Summary:}"
		fi
	}

	update_erase_drive_summary

	echo -e "${erase_drive_summary}"

	if [[ -z "${action_mode}" ]]; then
		echo -e "

  ${ANSI_BOLD}${ANSI_UNDERLINE}Choose ERASE Mode or VERIFY Mode...${CLEAR_ANSI}"

		while [[ -z "${action_mode}" ]]; do
			echo -en "\n    ${ANSI_CYAN}Type ${ANSI_BOLD}E${ANSI_CYAN} for ${ANSI_UNDERLINE}ERASE Mode${ANSI_CYAN} or ${ANSI_BOLD}V${ANSI_CYAN} for ${ANSI_UNDERLINE}VERIFY Mode${ANSI_CYAN} and Press ${ANSI_BOLD}ENTER${ANSI_CYAN}:${CLEAR_ANSI} "
			read -r action_mode

			action_mode="$(trim_and_squeeze_whitespace "${action_mode,,}")"
			if [[ "${action_mode}" != [ev] ]]; then
				action_mode=''
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Only ${ANSI_BOLD}E${ANSI_RED} or ${ANSI_BOLD}V${ANSI_RED} can be specified. ${ANSI_YELLOW}${ANSI_BOLD}(TRY AGAIN)${CLEAR_ANSI}"
			fi
		done

		if [[ "${action_mode}" == 'v' ]]; then
			is_verify_mode=true
		fi

		set_terminator_tab_title "$($is_verify_mode && echo 'Verifying' || echo 'Erasing') \"${erase_drive_id}\""

		update_erase_drive_summary
	fi

	if [[ -z "${lot_code}" ]]; then
		echo -e "

  ${ANSI_BOLD}${ANSI_UNDERLINE}Lot Code Required...${CLEAR_ANSI}"

		while [[ -z "${lot_code}" ]]; do
			echo -en "\n    ${ANSI_CYAN}Type the ${ANSI_BOLD}Lot Code${ANSI_CYAN} (MUST Be \"FG\" Followed by 8 Digits a Hyphen and 1 Digit, or \"N\" if NO Lot Code) and Press ${ANSI_BOLD}ENTER${ANSI_CYAN}:${CLEAR_ANSI} "
			read -r lot_code

			lot_code="$(trim_and_squeeze_whitespace "${lot_code^^}")"
			if [[ "${lot_code}" =~ ^FG[0123456789]{8}-[123456789]$ || "${lot_code}" =~ ^[0123456789]{8}-[123456789]$ || "${lot_code}" == 'N' || "${lot_code}" == 'NONE' ]]; then
				# Lot Code is "FG" followed by 2 digits for technicial ID, 2 digits for year, 2 digits for month, 2 digits for day, and then a hyphen and a single digit for the lot group in case there are multiple lots in a single day.
				# But, allow "FG" to be omitted and add it if so.

				if [[ "${lot_code}" =~ ^[0123456789]{8}-[123456789]$ ]]; then
					lot_code="FG${lot_code}"
				elif [[ "${lot_code}" == 'N' ]]; then
					lot_code='NONE'
				fi
			else
				lot_code=''
			fi

			if [[ -z "${lot_code}" ]]; then
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Lot Code ${ANSI_BOLD}MUST${ANSI_RED} be \"FG\" followed by 8 digits a hyphen and 1 digit, or \"N\" if NO lot code. ${ANSI_YELLOW}${ANSI_BOLD}(TRY AGAIN)${CLEAR_ANSI}"
			else
				echo -en "\n    ${ANSI_CYAN}${ANSI_BOLD}${ANSI_UNDERLINE}CONFIRM${ANSI_CYAN} the ${ANSI_BOLD}Lot Code${ANSI_CYAN} and Press ${ANSI_BOLD}ENTER${ANSI_CYAN}:${CLEAR_ANSI} "
				read -r confirm_lot_code

				confirm_lot_code="$(trim_and_squeeze_whitespace "${confirm_lot_code^^}")"
				if [[ "${confirm_lot_code}" =~ ^[0123456789]{8}-[123456789]$ ]]; then
					confirm_lot_code="FG${confirm_lot_code}"
				elif [[ "${confirm_lot_code}" == 'N' ]]; then
					confirm_lot_code='NONE'
				fi

				if [[ "${confirm_lot_code}" != "${lot_code}" ]]; then
					lot_code=''
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Did not confirm the lot code. ${ANSI_YELLOW}${ANSI_BOLD}(TRY AGAIN)${CLEAR_ANSI}"
				fi
			fi
		done
	elif [[ "${lot_code}" == 'N' ]]; then
		lot_code='NONE'
	fi

	technician_initials_from_lot_code=''
	if [[ "${lot_code}" =~ ^FG[0123456789]{8}-[123456789]$ ]]; then
		lot_code_technician_id="${lot_code:2:2}"
		case "${lot_code_technician_id}" in
			'00') technician_initials_from_lot_code='NB' ;;
			'15') technician_initials_from_lot_code='KA' ;;
			'20') technician_initials_from_lot_code='BB' ;;
			'65') technician_initials_from_lot_code='RS' ;;
			'98') technician_initials_from_lot_code='PM' ;;
			*) technician_initials_from_lot_code='';;
		esac
	fi

	if ! $is_verify_mode && [[ -n "${technician_initials_from_lot_code}" && -z "${technician_initials}" ]]; then
		# If erasing and the Technician ID within the Lot Code is known, set the initals based on that instead of unnecessarily prompting for initials.
		# If verifying, always prompt for initials since a DIFFERENT technician should be verifying the drives.

		technician_initials="${technician_initials_from_lot_code}"
	fi

	if [[ -z "${technician_initials}" ]]; then
		echo -e "

  ${ANSI_BOLD}${ANSI_UNDERLINE}Technician Initials for Logging Required...${CLEAR_ANSI}"

		while [[ -z "${technician_initials}" ]]; do
			echo -en "\n    ${ANSI_CYAN}Type ${ANSI_BOLD}Your Initials for Logging${ANSI_CYAN} (MUST Be Only 2-4 Letters) and Press ${ANSI_BOLD}ENTER${ANSI_CYAN}:${CLEAR_ANSI} "
			read -r technician_initials

			technician_initials="$(trim_and_squeeze_whitespace "${technician_initials^^}")"
			if [[ ! "${technician_initials}" =~ ^[ABCDEFGHIJKLMNOPQRSTUVWXYZ]{2,4}$ ]]; then
				technician_initials=''
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Your initials for logging ${ANSI_BOLD}MUST${ANSI_RED} be only 2-4 letters. ${ANSI_YELLOW}${ANSI_BOLD}(TRY AGAIN)${CLEAR_ANSI}"
			elif $is_verify_mode && [[ -n "${technician_initials_from_lot_code}" && "${technician_initials_from_lot_code}" == "${technician_initials}" ]]; then
				technician_initials=''
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} You ${ANSI_BOLD}CANNOT${ANSI_RED} verify your own lot. ${ANSI_YELLOW}${ANSI_BOLD}Since you were the one who erased this lot, a different technician must verify it.${CLEAR_ANSI}"
			fi

			if [[ -n "${technician_initials}" ]]; then
				echo -en "\n    ${ANSI_CYAN}${ANSI_BOLD}${ANSI_UNDERLINE}CONFIRM${ANSI_CYAN} ${ANSI_BOLD}Your Initials for Logging${ANSI_CYAN} and Press ${ANSI_BOLD}ENTER${ANSI_CYAN}:${CLEAR_ANSI} "
				read -r confirm_technician_initials

				if [[ "$(trim_and_squeeze_whitespace "${confirm_technician_initials^^}")" != "${technician_initials}" ]]; then
					technician_initials=''
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Did not confirm your initials for logging. ${ANSI_YELLOW}${ANSI_BOLD}(TRY AGAIN)${CLEAR_ANSI}"
				fi
			fi
		done
	fi

	if ! $is_verify_mode && $is_small_drive; then
		>&2 echo -e "
    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} This $($erase_drive_is_ssd && echo 'SSD' || echo 'HDD') Is Below Specified Limit Of $(human_readable_size_from_bytes "${min_drive_size_bytes}")!${CLEAR_ANSI}
    ${ANSI_CYAN}Press ${ANSI_BOLD}CONTROL + C${ANSI_CYAN} within 10 seconds if you want to ${ANSI_UNDERLINE}ABORT${ANSI_CYAN} this erasure before it starts, or press ${ANSI_BOLD}ENTER${ANSI_CYAN} to ${ANSI_UNDERLINE}CONTINUE${ANSI_CYAN}...${CLEAR_ANSI}"
		read -rt 10
	fi

	echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Performing$($is_verify_mode || echo ' Pre-Erase') Health Check on \"${erase_drive_id}\"...${CLEAR_ANSI}"

	if ! check_drive_health; then # "check_drive_health" displays passed/failed output that we want to display.
		update_erase_drive_summary
		if $force_override_health_checks; then
			>&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Health Checks OVERRIDDEN - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
		else
			return 60
		fi
	elif [[ "${previous_health_check_result}" != "${health_check_result}" ]]; then
		update_erase_drive_summary
	fi

	method_description='NOT Determined'

	action_mode_name=''
	case "${action_mode}" in
		'e') action_mode_name='Default Erase' ;;
		'v') action_mode_name='Verify ZEROs' ;;
		'R') action_mode_name='RANDOM Data' ;;
		'1') action_mode_name='ONEs' ;;
		'0') action_mode_name='ZEROs' ;;
		'3') action_mode_name='3 Pass' ;;
		'T') action_mode_name='TRIM' ;;
		'S') action_mode_name='Secure Erase' ;;
		*)
			action_mode_name='INVALID' # TODO: Test
			>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid \"${action_mode:-N/A}\" action mode specified. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}"
			send_error_email "Invalid \"${action_mode:-N/A}\" action mode specified."
			return 203 # Increment error code after unexpected errors in parent script.
			;;
	esac

	OVERWRITE_LAST_TWO_LINES='\033[2K\033[A\033[2K\r\033[A\033[2K\r' # Overwriting lines: https://stackoverflow.com/a/35190285
	if [[ ! -t 1 ]]; then # DO NOT use any invisible control characters if stdout IS NOT associated with an interactive terminal.
		OVERWRITE_LAST_TWO_LINES=''
	fi
	readonly OVERWRITE_LAST_TWO_LINES

	if $is_verify_mode; then
		method_description="${action_mode_name}"

		if $WAS_LAUNCHED_FROM_GUI_MODE && [[ "${TERMINATOR_PROCESS_INDEX}" =~ ^[0123456789]+$ ]]; then
			echo "${TERMINATOR_PROCESS_INDEX}" >> "${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-terminator-process-indexes-launched.txt"
		fi

		echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Logging Starting Verification for \"${erase_drive_id}\" by \"${technician_initials}\" (Lot ${lot_code})...${CLEAR_ANSI}"

		log_action "Starting $($WAS_LAUNCHED_FROM_GUI_MODE && echo 'GUI' || echo 'CLI')$($was_launched_from_auto_mode && echo ' Auto') Verify" 'Starting'

		echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Logged Starting Verification for \"${erase_drive_id}\" by \"${technician_initials}\" (Lot ${lot_code})${CLEAR_ANSI}"

		overall_start_timestamp="$(date '+%s')"
	else
		echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Determining Erasure Method for \"${erase_drive_id}\"...${CLEAR_ANSI}"

		if ! $WAS_LAUNCHED_FROM_GUI_MODE && ! $quick_mode; then
			>&2 echo -e "
    ${ANSI_YELLOW}${ANSI_BOLD}WARNING:${ANSI_YELLOW} All data on \"${erase_drive_id}\" will be ${ANSI_BOLD}COMPLETELY ERASED${ANSI_YELLOW} once this erasure starts in 10 seconds!${CLEAR_ANSI}
    ${ANSI_CYAN}Press ${ANSI_BOLD}CONTROL + C${ANSI_CYAN} within 10 seconds if you want to ${ANSI_UNDERLINE}ABORT${ANSI_CYAN} this erasure before it starts, or press ${ANSI_BOLD}ENTER${ANSI_CYAN} to ${ANSI_UNDERLINE}START NOW${ANSI_CYAN}...${CLEAR_ANSI}"
			read -rt 10
		fi

		supports_format_nvm=false
		supports_ata_secure_erase=false
		supports_scsi_sanitize=false

		# TODO: Need to proof read, verify, and improve styling of all the Secure Erase message with "action_mode" taken into consideration.
		if [[ "${action_mode}" == [R103] ]]; then
			method_description="Only ${action_mode_name} Overwrite"
			echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} CLI Option \"-${action_mode}\" Specified"
		elif ! $erase_drive_is_ssd; then # Never send "ATA Secure Erase" command on an HDD since even if it supports it, it would just perform an overwrite pass which we'll do manually below.
			format_nvm_result='NOT Supported'
			ata_secure_erase_result='NOT Supported'
			scsi_sanitize_result='NOT Supported'

			if [[ "${action_mode}" == 'e' ]]; then
				method_description='3 Pass Overwrite'
				echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind} (Not SSD)"
			else # This would only be "S" or "T" after check for "R", "1", "0", and "e" above.
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} CLI option \"-${action_mode}\" is specified, but ${ANSI_BOLD}CANNOT${ANSI_RED} send ${action_mode_name} command to ${erase_drive_kind}.${CLEAR_ANSI}"
				return 57
			fi
		elif [[ "${action_mode}" == 'T' ]]; then
			method_description='Only Send TRIM Command'
			echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} CLI Option \"-${action_mode}\" Specified & Drive Is ${erase_drive_kind}"
		elif [[ "${action_mode}" == [eS] ]]; then
			if [[ "${erase_drive_full_id}" == '/dev/nvme'* ]]; then
				ata_secure_erase_result='NOT Supported'
				scsi_sanitize_result='NOT Supported'

				if timeout -s SIGKILL 3 nvme id-ctrl -H "${erase_drive_full_id}" | grep -q 'Format NVM Supported$'; then # https://wiki.archlinux.org/title/Solid_state_drive/Memory_cell_clearing#NVMe_drive
					supports_format_nvm=true
					format_nvm_result='Supported, NOT Performed'

					if [[ "${action_mode}" == 'e' ]]; then
						method_description='Send "Format NVM" Command & Single ZEROs Overwrite'
						echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind} & \"Format NVM\" Secure Erase Command Supported"
					else
						method_description='Only Send "Format NVM" Command'
						echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} CLI Option \"-${action_mode}\" Specified & Drive Is ${erase_drive_kind} & \"Format NVM\" Secure Erase Command Supported"
					fi
				else
					format_nvm_result='NOT Supported'

					if [[ "${action_mode}" == 'e' ]]; then
						method_description='3 Pass Overwrite'
						echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind}, ${ANSI_YELLOW}But \"Format NVM\" Secure Erase Command NOT SUPPORTED${CLEAR_ANSI}"
					else
						>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} CLI option \"-${action_mode}\" is specified, but \"Format NVM\" secure erase command is ${ANSI_BOLD}NOT SUPPORTED${ANSI_RED} on \"${erase_drive_id}\".${CLEAR_ANSI}"
						return 58
					fi
				fi
			else
				format_nvm_result='NOT Supported'

				hdparm_info="$(timeout -s SIGKILL 3 hdparm -I "${erase_drive_full_id}" 2>&1)"
				if [[ "${hdparm_info}" == *'SECURITY ERASE UNIT'* ]]; then
					# TODO: Could also check and do ENHANCED Secure Erase, but it seems to get hung more often: [[ "${hdparm_info}" == *'ENHANCED SECURITY ERASE UNIT'* ]]
					# Also, NIST 800-88 says ENHANCED Secure Erase is inconsistent between manufacturers and shouldn't generally be relied on.
					# TODO: SHOW NIST 800-88 SOURCE ON THAT!

					if ! $WAS_LAUNCHED_FROM_GUI_MODE && ! $is_apple_mac && [[ "${hdparm_info}" != *$'\n\tnot\tfrozen\n'* ]]; then # https://wiki.archlinux.org/title/Solid_state_drive/Memory_cell_clearing#Make_sure_the_drive_security_is_not_in_frozen_mode & https://archive.kernel.org/oldwiki/ata.wiki.kernel.org/index.php/ATA_Secure_Erase.html#Step_1_-_Make_sure_the_drive_Security_is_not_frozen:
						if $quick_mode; then
							>&2 echo -e "
    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Sleeping computer NOW to attempt to unfreeze \"${erase_drive_id}\" for \"ATA Secure Erase\" command...${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}This computer will automatically wake itself back up after sleeping, and \"${erase_drive_id}\" should be unfrozen (but sometimes drives cannot be unfrozen just from sleeping).${CLEAR_ANSI}"
						else
							>&2 echo -e "
    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Sleeping computer in 10 seconds to attempt to unfreeze \"${erase_drive_id}\" for \"ATA Secure Erase\" command...${CLEAR_ANSI} ${ANSI_CYAN}(or press ${ANSI_BOLD}ENTER${ANSI_CYAN} to ${ANSI_UNDERLINE}SLEEP NOW${ANSI_CYAN})${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}This computer will automatically wake itself back up after sleeping, and \"${erase_drive_id}\" should be unfrozen (but sometimes drives cannot be unfrozen just from sleeping).${CLEAR_ANSI}"
							read -rt 10
						fi

						rtcwake -m 'mem' -s '1' &> /dev/null # https://www.baeldung.com/linux/auto-suspend-wake (Also, this technique does not interrupt the network connection like "systemctl suspend" does.)

						hdparm_info="$(timeout -s SIGKILL 3 hdparm -I "${erase_drive_full_id}" 2>&1)"
					fi

					if [[ "${hdparm_info}" == *$'\n\t\tenabled\n'* || "${hdparm_info}" == *$'\n\t\tlocked\n'* ]]; then
						# If "ATA Secure Erase" failed on a previous attempt AND removing the password failed, try to remove the password so we can re-attempt: https://tinyapps.org/docs/wipe_drives_hdparm.html
						hdparm_security_unlock_output="$(timeout -s SIGKILL 300 hdparm --user-master 'u' --security-unlock 'freegeek' "${erase_drive_full_id}" 2>&1)"
						hdparm_security_unlock_exit_code="$?"
						hdparm_security_disable_output="$(timeout -s SIGKILL 300 hdparm --user-master 'u' --security-disable 'freegeek' "${erase_drive_full_id}" 2>&1)"
						hdparm_security_disable_exit_code="$?"

						hdparm_info_before_unlock="${hdparm_info}"
						hdparm_info="$(timeout -s SIGKILL 3 hdparm -I "${erase_drive_full_id}" 2>&1)"
					fi

					if [[ "${hdparm_info}" == *$'\n\t\tenabled\n'* || "${hdparm_info}" == *$'\n\t\tlocked\n'* ]]; then
						ata_secure_erase_result='Supported, But Drive LOCKED'
						error_code=80 # NOTE: This is a SECURE ERASE error, not a DRIVE SELECTION error.

						ata_secure_drive_locked_error_message="${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output BEFORE Unlock:${ANSI_RED}
${hdparm_info_before_unlock}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Unlock Exit Code:${ANSI_RED} ${hdparm_security_unlock_exit_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Unlock Output:${ANSI_RED}
${hdparm_security_unlock_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Disable Exit Code:${ANSI_RED} ${hdparm_security_disable_exit_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Disable Output:${ANSI_RED}
${hdparm_security_disable_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output AFTER Unlock:${ANSI_RED}
${hdparm_info}${CLEAR_ANSI}"

						>&2 echo -e "
${ata_secure_drive_locked_error_message}

    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} \"ATA Secure Erase\" command is supported, but \"${erase_drive_id}\" is ${ANSI_BOLD}LOCKED${ANSI_RED}.${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

						send_error_email "\"ATA Secure Erase\" Command ${ata_secure_erase_result}<br/><br/>${ata_secure_drive_locked_error_message}"
						error_should_not_have_happened=true
						return "${error_code}"
					elif [[ "${hdparm_info}" == *$'\n\tnot\tfrozen\n'* ]]; then
						supports_ata_secure_erase=true
						ata_secure_erase_result='Supported, NOT Performed'

						if [[ "${action_mode}" == 'e' ]]; then
							method_description='Send "ATA Secure Erase" Command & Single ZEROs Overwrite'
							echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind} & \"ATA Secure Erase\" Command Supported"
						else
							method_description='Only Send "ATA Secure Erase" Command'
							echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} CLI Option \"-${action_mode}\" Specified & Drive Is ${erase_drive_kind} & \"ATA Secure Erase\" Command Supported"
						fi
					else
						ata_secure_erase_result='Supported, But Drive FROZEN'

						if ! $is_apple_mac; then
							send_error_email "\"ATA Secure Erase\" Command ${ata_secure_erase_result}$([[ "${action_mode}" != 'e' ]] && echo " (\"-${action_mode}\" Specified)")<br/><br/>hdparm Info Output:<br/>${hdparm_info}"
						fi
					fi
				else
					ata_secure_erase_result='NOT Supported'
				fi

				if [[ "${erase_drive_kind}" == 'SAS SSD' ]] && timeout -s SIGKILL 3 sg_opcodes "${erase_drive_full_id}" 2> /dev/null | grep -q 'Sanitize, block erase$'; then
					# TODO: Explain only using sg_opcodes check with may not always be accurate. See NOTES in https://docs.oracle.com/cd/E88353_01/html/E72487/sg-sanitize-8.html
					# TODO: Explain checking for "ATA Secure Erase" FIRST even if SAS SSD (because wiping stations support SAS and show regular SATA drives as SAS even if they can support ATA Secure Erase)
					supports_scsi_sanitize=true
					scsi_sanitize_result='Supported, NOT Performed'

					if ! $supports_ata_secure_erase; then
						if [[ "${action_mode}" == 'e' ]]; then
							method_description='Send "SCSI Sanitize" Command & Single ZEROs Overwrite'
							echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind} & \"SCSI Sanitize\" Command Supported"
						else
							method_description='Only Send "SCSI Sanitize" Command'
							echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} CLI Option \"-${action_mode}\" Specified & Drive Is ${erase_drive_kind} & \"SCSI Sanitize\" Command Supported"
						fi
					fi
				else
					scsi_sanitize_result='NOT Supported'
				fi

				if ! $supports_ata_secure_erase && ! $supports_scsi_sanitize; then
					if [[ "${ata_secure_erase_result}" == *'FROZEN'* ]]; then
						if [[ "${action_mode}" == 'e' ]]; then
							method_description='3 Pass Overwrite'
							echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind} & \"ATA Secure Erase\" Command Supported, ${ANSI_YELLOW}But Drive Is FROZEN${CLEAR_ANSI}"
						else
							error_code=58

							>&2 echo -e "
${ANSI_RED}${ANSI_BOLD}hdparm Info Output:${ANSI_RED}
${hdparm_info}${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} CLI option \"-${action_mode}\" is specified, but \"${erase_drive_id}\" is ${ANSI_BOLD}FROZEN${ANSI_RED} so ${ANSI_BOLD}CANNOT${ANSI_RED} send \"ATA Secure Erase\" command.${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

							error_should_not_have_happened=true
							return "${error_code}"
						fi
					else
						reason_command_names='"ATA Secure Erase" Command'
						error_command_names='"ATA Secure Erase" command is'
						if [[ "${erase_drive_kind}" == 'SAS SSD' ]]; then
							reason_command_names='"ATA Secure Erase" or "SCSI Sanitize" Commands'
							error_command_names='"ATA Secure Erase" or "SCSI Sanitize" commands are'
						fi

						if [[ "${action_mode}" == 'e' ]]; then
							method_description='3 Pass Overwrite'
							echo -e "
    ${ANSI_BOLD}Method:${CLEAR_ANSI} ${method_description}
    ${ANSI_BOLD}Reason:${CLEAR_ANSI} Drive Is ${erase_drive_kind}, ${ANSI_YELLOW}But ${reason_command_names} NOT SUPPORTED${CLEAR_ANSI}"
						else
							>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} CLI option \"-${action_mode}\" is specified, but ${error_command_names} ${ANSI_BOLD}NOT SUPPORTED${ANSI_RED} on \"${erase_drive_id}\".${CLEAR_ANSI}"
							return 59
						fi
					fi
				fi
			fi
		fi

		if [[ "${method_description}" == 'NOT Determined' ]]; then # TODO: Test
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unexpected error occurred determining erasure method. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}"
			send_error_email 'Unexpected error occurred determining erasure method.'
			return 204
		fi

		if $WAS_LAUNCHED_FROM_GUI_MODE && [[ "${TERMINATOR_PROCESS_INDEX}" =~ ^[0123456789]+$ ]]; then
			echo "${TERMINATOR_PROCESS_INDEX}" >> "${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-terminator-process-indexes-launched.txt"
		fi

		echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Logging Starting Erasure for \"${erase_drive_id}\" by \"${technician_initials}\" (Lot ${lot_code})...${CLEAR_ANSI}"

		log_action "Starting $($WAS_LAUNCHED_FROM_GUI_MODE && echo 'GUI' || echo 'CLI')$($was_launched_from_auto_mode && echo ' Auto') Erase $([[ "${action_mode}" != 'e' ]] && echo " (Manual Only ${action_mode_name:-UNKNOWN})")" 'Starting' # "action_mode_name" will be set in "case" statments above in "Determining Erasure Method" section.

		echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Logged Starting Erasure for \"${erase_drive_id}\" by \"${technician_initials}\" (Lot ${lot_code})${CLEAR_ANSI}"

		overall_start_timestamp="$(date '+%s')"

		if $erase_drive_is_ssd && [[ "${action_mode}" == 'T' ]]; then # NOTE: Sending TRIM is ONLY available via CLI "-T" option since it seems to never be supported on any of my test devices so I can't figure out how long it takes or what success looks like, etc.
			start_blkdiscard_trim_timestamp="$(date '+%s')"

			echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Sending TRIM Command to \"${erase_drive_id}\"...${CLEAR_ANSI}

    ${ANSI_BOLD}Start Time:${CLEAR_ANSI} $(date -d "@${start_blkdiscard_trim_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

			# TODO: Test and explain!
			blkdiscard_trim_output="$(blkdiscard -fs "${erase_drive_full_id}" 2>&1)" # https://wiki.archlinux.org/title/Solid_state_drive/Memory_cell_clearing#Common_method_with_blkdiscard
			blkdiscard_trim_exit_code="$?"
			# TODO: What output do I want to hide or show?
			# TODO: How long does this actually take when it's supported?

			sync # I'm not sure whether or not a manual "sync" is helpful or required after TRIM, but do so anyways just in case.

			if (( blkdiscard_trim_exit_code != 0 )) && [[ "${blkdiscard_trim_output}" == *'Operation not supported' ]]; then
				trim_result='NOT Supported'

				if [[ "${action_mode}" == 'e' ]]; then
					>&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} TRIM Command NOT SUPPORTED on \"${erase_drive_id}\" - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
				else
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}TRIM Command NOT SUPPORTED on \"${erase_drive_id}\"${CLEAR_ANSI}"
					return 90
				fi
			else
				end_blkdiscard_trim_timestamp="$(date '+%s')"
				trim_duration="$(human_readable_duration_from_seconds "$(( end_blkdiscard_trim_timestamp - start_blkdiscard_trim_timestamp ))")"

				echo -e "      ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${trim_duration}
      ${ANSI_BOLD}End Time:${CLEAR_ANSI} $(date -d "@${end_blkdiscard_trim_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				if (( blkdiscard_trim_exit_code == 0 )); then
					trim_result="Completed in ${trim_duration}"

					# This force TRIM all blocks may not be secure, and blocks may not even get TRIMed immediately since the command is basically just a request, but doesn't hurt to try when we can't Secure Erase.
					# TODO: Not really sure if this is the correct moment to send this TRIM command.
					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Sent TRIM Command to \"${erase_drive_id}\"${CLEAR_ANSI}"
				else
					trim_result="FAILED (Error ${blkdiscard_trim_exit_code}) After ${trim_duration}"

					>&2 echo -e "\n${ANSI_RED}${ANSI_BOLD}blkdiscard Exit Code:${ANSI_RED} ${blkdiscard_trim_exit_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}blkdiscard Output:${ANSI_RED}\n${blkdiscard_trim_output}${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}TRIM Command FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}"
					return 91
				fi
			fi
		fi

		if [[ "${action_mode}" == [eS] ]]; then
			if $supports_format_nvm; then
				# TODO: Explain this coming before ZEROs ("Format NVM" may not actually be supported so needs to be able fallback to 3 pass, and "Format NVM" is not guarenteed to result in all ZEROs and "ATA Secure Erase" (even NOT Enhanced) may not always result all ZEROs on some drive models even though it's supposed to).
				start_format_nvm_timestamp="$(date '+%s')"

				echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Sending \"Format NVM\" Secure Erase Command to \"${erase_drive_id}\"...${CLEAR_ANSI}

    ${ANSI_BOLD}Start Time:${CLEAR_ANSI} $(date -d "@${start_format_nvm_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				trap '' SIGINT # TODO: Does this actually block canceling the command?

				for send_format_nvm_command_attempt in {1..2}; do
					format_nvm_output="$(nvme format "${erase_drive_full_id}" -s 1 --force 2>&1)" # https://wiki.archlinux.org/title/Solid_state_drive/Memory_cell_clearing#Format_command
					format_nvm_exit_code="$?"

					if ! $WAS_LAUNCHED_FROM_GUI_MODE && ! $is_apple_mac && (( format_nvm_exit_code != 0 && send_format_nvm_command_attempt == 1 )); then # TODO: Explain: https://github.com/linux-nvme/nvme-cli/issues/627#issuecomment-569685237 & https://github.com/linux-nvme/nvme-cli/issues/816#issuecomment-834586681
						if $quick_mode; then
							>&2 echo -e "
    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Sleeping computer NOW to attempt to unfreeze \"${erase_drive_id}\" for \"Format NVM\" command...${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}This computer will automatically wake itself back up after sleeping, and \"${erase_drive_id}\" should be unfrozen (but sometimes drives cannot be unfrozen just from sleeping).${CLEAR_ANSI}"
						else
							>&2 echo -e "
    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Sleeping computer in 10 seconds to attempt to unfreeze \"${erase_drive_id}\" for \"Format NVM\" command...${CLEAR_ANSI} ${ANSI_CYAN}(or press ${ANSI_BOLD}ENTER${ANSI_CYAN} to ${ANSI_UNDERLINE}SLEEP NOW${ANSI_CYAN})${CLEAR_ANSI}
    ${ANSI_PURPLE}${ANSI_BOLD}This computer will automatically wake itself back up after sleeping, and \"${erase_drive_id}\" should be unfrozen (but sometimes drives cannot be unfrozen just from sleeping).${CLEAR_ANSI}"
							read -rt 10
						fi

						rtcwake -m 'mem' -s '1' &> /dev/null # https://www.baeldung.com/linux/auto-suspend-wake (Also, this technique does not interrupt the network connection like "systemctl suspend" does.)

						echo '' # Print empty line so that "Duration" isn't against the sleep message.
					else
						break
					fi
				done

				sync # Manual "sync" should not be required after "Format NVM", but do so anyways just in case.

				trap - SIGINT

				end_format_nvm_timestamp="$(date '+%s')"
				format_nvm_duration="$(human_readable_duration_from_seconds "$(( end_format_nvm_timestamp - start_format_nvm_timestamp ))")"

				echo -e "      ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${format_nvm_duration}
      ${ANSI_BOLD}End Time:${CLEAR_ANSI} $(date -d "@${end_format_nvm_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				if (( format_nvm_exit_code == 0 )); then
					format_nvm_result="Completed in ${format_nvm_duration}"

					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Sent \"Format NVM\" Secure Erase Command to \"${erase_drive_id}\"${CLEAR_ANSI}"
				else
					format_nvm_error_message="${ANSI_RED}${ANSI_BOLD}Send \"Format NVM\" Exit Code:${ANSI_RED} ${format_nvm_exit_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Send \"Format NVM\" Output:${ANSI_RED}
${format_nvm_output}${CLEAR_ANSI}"

					if [[ "${format_nvm_output}" == *'INVALID_OPCODE'* || "${format_nvm_output}" == *'Invalid Command Opcode'* ]]; then # TODO: Explain: https://github.com/linux-nvme/nvme-cli/issues/627#issuecomment-569685237
						format_nvm_result='NOT ACTUALLY Supported' # TODO: Should EVERY error result in NOT ACTUALLY Supported, or should they all just be FAILED since a sleep was always attempted?

						if [[ "${action_mode}" == 'e' ]]; then # Fallback to 3 pass overwrite if Format NVM fails with INVALID_OPCODE error (and running default erase mode).
							>&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}\"Format NVM\" Secure Erase Command NOT ACTUALLY SUPPORTED on \"${erase_drive_id}\" - ${ANSI_UNDERLINE}FALLING BACK TO 3 PASS OVERWRITE${CLEAR_ANSI}"
							supports_format_nvm=false
							send_error_email "\"Format NVM\" Secure Erase Command NOT ACTUALLY SUPPORTED - FALLING BACK TO 3 PASS OVERWRITE<br/><br/>${format_nvm_error_message}"
						else
							error_code=81

							>&2 echo -e "
${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${format_nvm_error_message}

    ${ANSI_RED}${ANSI_BOLD}\"Format NVM\" Secure Erase Command NOT ACTUALLY SUPPORTED on \"${erase_drive_id}\"${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

							send_error_email "Error Code: ${error_code}<br/><br/>${format_nvm_error_message}"
							error_should_not_have_happened=true
							return "${error_code}"
						fi
					else
						format_nvm_result="FAILED (Error ${format_nvm_exit_code}) After ${format_nvm_duration}"
						error_code=82

						>&2 echo -e "
${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${format_nvm_error_message}

    ${ANSI_RED}${ANSI_BOLD}\"Format NVM\" Secure Erase Command FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

						send_error_email "Error Code: ${error_code}<br/><br/>${format_nvm_error_message}"
						error_should_not_have_happened=true
						return "${error_code}"
					fi
				fi
			elif $supports_ata_secure_erase; then
				start_ata_secure_erase_timestamp="$(date '+%s')"

				echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Sending \"ATA Secure Erase\" Command to \"${erase_drive_id}\"...${CLEAR_ANSI}

    ${ANSI_BOLD}Start Time:${CLEAR_ANSI} $(date -d "@${start_ata_secure_erase_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				trap '' SIGINT # TODO: Does this actually block canceling the command?

				set_secure_erase_password_output="$(timeout -s SIGKILL 300 hdparm --user-master 'u' --security-set-pass 'freegeek' "${erase_drive_full_id}" 2>&1)" # https://wiki.archlinux.org/title/Solid_state_drive/Memory_cell_clearing#Enable_security_by_setting_a_user_password & https://archive.kernel.org/oldwiki/ata.wiki.kernel.org/index.php/ATA_Secure_Erase.html#Step_2_-_Enable_security_by_setting_a_user_password:
				set_secure_erase_password_exit_code="$?"

				hdparm_info_after_set_secure_erase_password="$(timeout -s SIGKILL 3 hdparm -I "${erase_drive_full_id}" 2>&1)"
				if (( set_secure_erase_password_exit_code != 0 )) || [[ "${hdparm_info_after_set_secure_erase_password}" == *$'\n\tnot\tenabled\n'* || "${hdparm_info_after_set_secure_erase_password}" == *$'\n\t\tlocked\n'* ]]; then # https://archive.kernel.org/oldwiki/ata.wiki.kernel.org/index.php/ATA_Secure_Erase.html#Step_2b_-_Command_Output_.28should_display_.22enabled.22.29:
					trap - SIGINT

					ata_secure_erase_result="Prepare FAILED (Error ${set_secure_erase_password_exit_code}$( (( set_secure_erase_password_exit_code == 124 || set_secure_erase_password_exit_code == 137 )) && echo ' - TIMEOUT' ))"
					error_code=83

					prepare_ata_secure_erase_error_message="${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Prepare \"ATA Secure Erase\" Exit Code:${ANSI_RED} ${set_secure_erase_password_exit_code}$( (( set_secure_erase_password_exit_code == 124 || set_secure_erase_password_exit_code == 137 )) && echo ' (TIMEOUT)' )${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output BEFORE Prepare:${ANSI_RED}
${hdparm_info}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Prepare \"ATA Secure Erase\" Output:${ANSI_RED}
${set_secure_erase_password_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output AFTER Prepare:${ANSI_RED}
${hdparm_info_after_set_secure_erase_password}${CLEAR_ANSI}"

					>&2 echo -e "
${prepare_ata_secure_erase_error_message}

    ${ANSI_RED}${ANSI_BOLD}FAILED to Prepare \"ATA Secure Erase\" Command on \"${erase_drive_id}\"${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

					send_error_email "${prepare_ata_secure_erase_error_message}"
					error_should_not_have_happened=true
					return "${error_code}"
				fi

				ata_secure_erase_output="$(timeout -s SIGKILL 900 hdparm --user-master 'u' --security-erase 'freegeek' "${erase_drive_full_id}" 2>&1)" # https://wiki.archlinux.org/title/Solid_state_drive/Memory_cell_clearing#Issue_the_ATA_SECURITY_ERASE_UNIT_command & https://archive.kernel.org/oldwiki/ata.wiki.kernel.org/index.php/ATA_Secure_Erase.html#Step_3_-_Issue_the_ATA_Secure_Erase_command:
				ata_secure_erase_exit_code="$?"

				sync # Manual "sync" should not be required after "ATA Secure Erase", but do so anyways just in case.

				end_ata_secure_erase_timestamp="$(date '+%s')"
				ata_secure_erase_duration="$(human_readable_duration_from_seconds "$(( end_ata_secure_erase_timestamp - start_ata_secure_erase_timestamp ))")"

				echo -e "      ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${ata_secure_erase_duration}
      ${ANSI_BOLD}End Time:${CLEAR_ANSI} $(date -d "@${end_ata_secure_erase_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				for get_hdparm_info_attempt in {1..5}; do # NOTE: Saw empty "hdparm -I" output once at this point after running "ATA Secure Erase" on a USB drive, so re-try up to 5 times, waiting a bit between each attempt.
					hdparm_info_after_secure_erase="$(timeout -s SIGKILL 3 hdparm -I "${erase_drive_full_id}" 2>&1)"
					if [[ "${hdparm_info_after_secure_erase}" == *'SECURITY ERASE UNIT'* ]]; then
						break
					elif (( get_hdparm_info_attempt < 5 )); then
						sleep 3
					fi
				done

				if (( ata_secure_erase_exit_code == 0 )) && [[ "${hdparm_info_after_secure_erase}" == *$'\n\tnot\tenabled\n'* && "${hdparm_info_after_secure_erase}" == *$'\n\tnot\tlocked\n'* ]]; then # https://archive.kernel.org/oldwiki/ata.wiki.kernel.org/index.php/ATA_Secure_Erase.html#Step_4_-_The_drive_is_now_erased.21_Verify_security_is_disabled:
					trap - SIGINT

					ata_secure_erase_result="Completed in ${ata_secure_erase_duration}"
					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Sent \"ATA Secure Erase\" Command to \"${erase_drive_id}\"${CLEAR_ANSI}"
				else
					ata_secure_erase_result="FAILED (Error ${ata_secure_erase_exit_code}$( (( ata_secure_erase_exit_code == 124 || ata_secure_erase_exit_code == 137 )) && echo ' - TIMEOUT' )) After ${ata_secure_erase_duration}"
					error_code=84

					# If "ATA Secure Erase" failed somehow, try to remove the password so the drive isn't locked: https://tinyapps.org/docs/wipe_drives_hdparm.html
					hdparm_security_unlock_output="$(timeout -s SIGKILL 300 hdparm --user-master 'u' --security-unlock 'freegeek' "${erase_drive_full_id}" 2>&1)"
					hdparm_security_unlock_exit_code="$?"
					hdparm_security_disable_output="$(timeout -s SIGKILL 300 hdparm --user-master 'u' --security-disable 'freegeek' "${erase_drive_full_id}" 2>&1)"
					hdparm_security_disable_exit_code="$?"

					trap - SIGINT

					send_ata_secure_erase_error_message="${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Send \"ATA Secure Erase\" Exit Code:${ANSI_RED} ${ata_secure_erase_exit_code}$( (( ata_secure_erase_exit_code == 124 || ata_secure_erase_exit_code == 137 )) && echo ' (TIMEOUT)' )${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output BEFORE Prepare:${ANSI_RED}
${hdparm_info}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Prepare \"ATA Secure Erase\" Output:${ANSI_RED}
${set_secure_erase_password_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Send \"ATA Secure Erase\" Output:${ANSI_RED}
${ata_secure_erase_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output BEFORE Unlock:${ANSI_RED}
${hdparm_info_after_secure_erase}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Unlock Exit Code:${ANSI_RED} ${hdparm_security_unlock_exit_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Unlock Output:${ANSI_RED}
${hdparm_security_unlock_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Disable Exit Code:${ANSI_RED} ${hdparm_security_disable_exit_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Security Disable Output:${ANSI_RED}
${hdparm_security_disable_output}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}hdparm Info Output AFTER Unlock:${ANSI_RED}
$(timeout -s SIGKILL 3 hdparm -I "${erase_drive_full_id}" 2>&1)${CLEAR_ANSI}"

					>&2 echo -e "
${send_ata_secure_erase_error_message}

    ${ANSI_RED}${ANSI_BOLD}\"ATA Secure Erase\" Command FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

					send_error_email "${send_ata_secure_erase_error_message}"
					error_should_not_have_happened=true
					return "${error_code}"
				fi
			elif $supports_scsi_sanitize; then
				start_scsi_sanitize_timestamp="$(date '+%s')"

				echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Sending \"SCSI Sanitize\" Command to \"${erase_drive_id}\"...${CLEAR_ANSI}

    ${ANSI_BOLD}Start Time:${CLEAR_ANSI} $(date -d "@${start_scsi_sanitize_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				trap '' SIGINT # TODO: Does this actually block canceling the command?

				scsi_sanitize_output="$(timeout -s SIGKILL 900 sg_sanitize -BQw "${erase_drive_full_id}" 2>&1)"
				scsi_sanitize_exit_code="$?"

				sync # Manual "sync" should not be required after "SCSI Sanitize", but do so anyways just in case.

				trap - SIGINT

				end_scsi_sanitize_timestamp="$(date '+%s')"
				scsi_sanitize_duration="$(human_readable_duration_from_seconds "$(( end_scsi_sanitize_timestamp - start_scsi_sanitize_timestamp ))")"

				echo -e "      ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${scsi_sanitize_duration}
      ${ANSI_BOLD}End Time:${CLEAR_ANSI} $(date -d "@${end_scsi_sanitize_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

				if (( scsi_sanitize_exit_code == 0 )); then # TODO: Check for "Invalid opcode" in output and show an NOT ACTUALLY SUPPORTED error?
					scsi_sanitize_result="Completed in ${scsi_sanitize_duration}"
					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Sent \"SCSI Sanitize\" Command to \"${erase_drive_id}\"${CLEAR_ANSI}"
				else
					scsi_sanitize_result="FAILED (Error ${scsi_sanitize_exit_code}$( (( scsi_sanitize_exit_code == 124 || scsi_sanitize_exit_code == 137 )) && echo ' - TIMEOUT' )) After ${scsi_sanitize_duration}"
					error_code=85

					send_scsi_sanitize_error_message="${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Send \"SCSI Sanitize\" Exit Code:${ANSI_RED} ${scsi_sanitize_exit_code}$( (( scsi_sanitize_exit_code == 124 || scsi_sanitize_exit_code == 137 )) && echo ' (TIMEOUT)' )${CLEAR_ANSI}

${ANSI_RED}${ANSI_BOLD}Send \"SCSI Sanitize\" Output:${ANSI_RED}
${scsi_sanitize_output}${CLEAR_ANSI}"

					>&2 echo -e "
${send_scsi_sanitize_error_message}

    ${ANSI_RED}${ANSI_BOLD}\"SCSI Sanitize\" Command FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

					send_error_email "${send_scsi_sanitize_error_message}"
					error_should_not_have_happened=true
					return "${error_code}"
				fi
			fi
		fi

		run_nwipe_and_display_progress() {
			did_cancel_nwipe=false
			nwipe_duration='NOT Started'

			overwrite_method="$1"

			method_display_name=''
			case "${overwrite_method}" in
				'random') method_display_name='RANDOM Data' ;;
				'one') method_display_name='ONEs' ;;
				'zero') method_display_name='ZEROs' ;;
				*)
					>&2 echo -e "\n\n    ${ANSI_RED}${ANSI_BOLD}run_nwipe_and_display_progress ERROR:${ANSI_RED} INVALID \"${overwrite_method}\" method specified.${CLEAR_ANSI}"
					return 1
					;;
			esac

			start_nwipe_timestamp="$(date '+%s')"

			echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Overwriting ${method_display_name} on \"${erase_drive_id}\"...${CLEAR_ANSI}

    ${ANSI_BOLD}Start Time:${CLEAR_ANSI} $(date -d "@${start_nwipe_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")
       ${ANSI_BOLD}Elapsed:${CLEAR_ANSI} 0 Seconds
      ${ANSI_BOLD}Progress:${CLEAR_ANSI} Initializing..."

			nwipe_log_path="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-nwipe-${overwrite_method}-${erase_drive_id}.txt" # TODO: Randomize this path?
			rm -rf "${nwipe_log_path}"

			nwipe --autonuke --nogui --noblank --method "${overwrite_method}" --verify 'off' -P 'noPDF' -l "${nwipe_log_path}" "${erase_drive_full_id}" &> /dev/null &
			nwipe_pid="$!"

			trap 'if ! $did_cancel_nwipe; then did_cancel_nwipe=true; >&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Canceling, please wait...${CLEAR_ANSI}"; fi' SIGINT # Ignore Control+C while "nwipe" is running in the background so that the signal is passed to the background processes and exit and show an error properly rather than just exiting this script immediately without showing an error.

			sleep 15 # Sleep for 15 seconds to make sure "nwipe" has started after initial launch.

			while kill -s SIGUSR1 "${nwipe_pid}" &> /dev/null; do # https://github.com/martijnvanbrummelen/nwipe/blob/9400ff5219d9a3e97928e496810c722cb7bc887e/man/nwipe.1#L22
				sleep 5 # Sleep for 5 seconds to make sure the signal has provoked nwipe to log the current status.
				if ! $did_cancel_nwipe; then # If canceled, keep waiting for the process to exit (since that can take a moment) so that the final log gets written.
					nwipe_progress_percentage="$(awk '(($3 == "info:") && ($5 ~ /%,$/)) { last_percentage=$5 } END { print substr(last_percentage, 1, (length(last_percentage) - 2)) }' "${nwipe_log_path}")"
					nwipe_progress_percentage="${nwipe_progress_percentage#0}" # Remove any leading zero (from numbers like "01.23").
					nwipe_progress_percentage="${nwipe_progress_percentage%0}" # Remove any trailing zero (from numbers like "12.30").

					echo -e "${OVERWRITE_LAST_TWO_LINES}       ${ANSI_BOLD}Elapsed:${CLEAR_ANSI} $(human_readable_duration_from_seconds "$(( $(date '+%s') - start_nwipe_timestamp ))")
      ${ANSI_BOLD}Progress:${CLEAR_ANSI} ${nwipe_progress_percentage:-0}%"
					sleep 15 # Wait 15 seconds before sending next progress logging signal.
				fi
			done

			sync # Manual "sync" should not be required since "nwipe" sync's periodically, but do so anyways just in case.

			nwipe_success=false # Check nwipe exit status from log file since we can't use exit codes since it's in the background with a progress loop above (and the exit code alone cannot be relied on to detect when user aborts nwipe).
			if ! $did_cancel_nwipe && [[ -f "${nwipe_log_path}" ]] && grep -q 'info: Nwipe successfully completed. See summary table for details.$' "${nwipe_log_path}"; then # https://github.com/PartialVolume/nwipe/blob/9400ff5219d9a3e97928e496810c722cb7bc887e/src/nwipe.c#L938
				nwipe_success=true
			fi

			if $did_cancel_nwipe; then
				echo -en "${OVERWRITE_LAST_TWO_LINES}" # If canceled, need to remove AT LEAST 2 EXTRA lines (from canceling message) to dislay proper final progress. May still leave some stray lines if ENTER was pressed after Control+C, but this is the best we can do.
			fi

			end_nwipe_timestamp="$(date '+%s')"
			nwipe_duration="$(human_readable_duration_from_seconds "$(( end_nwipe_timestamp - start_nwipe_timestamp ))")"

			trap - SIGINT # Allow Control+C after the "nwipe" pass is complete.

			# Manually update progress to 100% IF "nwipe" was successful since the last progress update could have been before it completely finished.
			echo -e "${OVERWRITE_LAST_TWO_LINES}      ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${nwipe_duration}
      ${ANSI_BOLD}Progress:${CLEAR_ANSI} $($nwipe_success && echo '100' || echo "${nwipe_progress_percentage:-0}")%
      ${ANSI_BOLD}End Time:${CLEAR_ANSI} $(date -d "@${end_nwipe_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

			if $nwipe_success; then
				rm -rf "${nwipe_log_path}"
				return 0
			else
				>&2 echo -e "
${ANSI_RED}${ANSI_BOLD}nwipe Log:${ANSI_RED}
$(< "${nwipe_log_path}")${CLEAR_ANSI}"

				rm -rf "${nwipe_log_path}"
				if ! $did_cancel_nwipe; then
					return 1
				else
					return 2
				fi
			fi
		}

		if ! $supports_format_nvm && ! $supports_ata_secure_erase && ! $supports_scsi_sanitize; then # NOTE: "supports_format_nvm", "supports_ata_secure_erase", and "supports_scsi_sanitize" can only be "true" if "action_mode" is empty or set to "S".
			# NOTE: Not using "nwipe --method=dodshort" (zeros pass, ones pass, random data pass) since we do not want to leave random data on the drive so that we can verify it was fully erased.
			# Manually doing RANDOM, ONEs, and ZEROs passes below allows us to selectively do the passes only when necessary, as well as do them in an order that ends with ZEROs so we can QC the drive without having to write ZEROs multiple times.

			if [[ "${action_mode}" == [eR3] ]]; then
				if run_nwipe_and_display_progress 'random'; then
					random_data_overwrite_result="Completed in ${nwipe_duration}"
					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Completed RANDOM Data Overwrite on \"${erase_drive_id}\"${CLEAR_ANSI}"

					if ! check_drive_health -q; then # "check_drive_health -q" ONLY displays failure output.
						update_erase_drive_summary
						if $force_override_health_checks; then
							>&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Health Checks OVERRIDDEN - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
						else
							return 61
						fi
					elif [[ "${previous_health_check_result}" != "${health_check_result}" ]]; then
						update_erase_drive_summary
					fi
				elif $did_cancel_nwipe; then
					random_data_overwrite_result="CANCELED After ${nwipe_duration}"
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}Overwrite RANDOM Data CANCELED on \"${erase_drive_id}\"${CLEAR_ANSI}"
					return 70
				else
					random_data_overwrite_result="FAILED After ${nwipe_duration}"
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}Overwrite RANDOM Data FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}"
					return 71
				fi
			fi

			if [[ "${action_mode}" == [e13] ]]; then
				if run_nwipe_and_display_progress 'one'; then
					ones_overwrite_result="Completed in ${nwipe_duration}"
					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Completed ONEs Overwrite on \"${erase_drive_id}\"${CLEAR_ANSI}"

					if ! check_drive_health -q; then # "check_drive_health -q" ONLY displays failure output.
						update_erase_drive_summary
						if $force_override_health_checks; then
							>&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Health Checks OVERRIDDEN - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
						else
							return 62
						fi
					elif [[ "${previous_health_check_result}" != "${health_check_result}" ]]; then
						update_erase_drive_summary
					fi
				elif $did_cancel_nwipe; then
					ones_overwrite_result="CANCELED After ${nwipe_duration}"
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}Overwrite ONEs CANCELED on \"${erase_drive_id}\"${CLEAR_ANSI}"
					return 72
				else
					ones_overwrite_result="FAILED After ${nwipe_duration}"
					>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}Overwrite ONEs FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}"
					return 73
				fi
			fi
		fi

		# Even if "Format NVM" or "ATA Secure Erase" or "SCSI Sanitize" is successfully performed above, STILL do a single ZEROs pass here because sometimes the ATA Secure Erase command
		# is not actually completely thorough or may not result in all ZEROs (even when NOT using ENHANCED mode on some drive models) and Format NVM may not result in all ZEROs.
		# TODO: Include better explanation and example of why still doing a zeros pass (based on unclear NAID guidelines as well) before/after a secure erase commnd is sent.
		if [[ "${action_mode}" == [e03] ]]; then
			if run_nwipe_and_display_progress 'zero'; then
				zeros_overwrite_result="Completed in ${nwipe_duration}"
				echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Completed ZEROs Overwrite on \"${erase_drive_id}\"${CLEAR_ANSI}"
			elif $did_cancel_nwipe; then
				zeros_overwrite_result="CANCELED After ${nwipe_duration}"
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}Overwrite ZEROs CANCELED on \"${erase_drive_id}\"${CLEAR_ANSI}"
				return 74
			else
				zeros_overwrite_result="FAILED After ${nwipe_duration}"
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}Overwrite ZEROs FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}"
				return 75
			fi
		fi

		echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Performing Post-Erase Health Check on \"${erase_drive_id}\"...${CLEAR_ANSI}"

		if ! check_drive_health; then # "check_drive_health" displays passed/failed output that we want to display.
			update_erase_drive_summary
			if $force_override_health_checks && [[ "${action_mode}" == 'e' ]]; then # Return an error here if doing "action_mode" erasure even if "force_override_health_checks".
				>&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Health Checks OVERRIDDEN - ${ANSI_UNDERLINE}CONTINUING ANYWAY${CLEAR_ANSI}"
			else
				return 63
			fi
		elif [[ "${previous_health_check_result}" != "${health_check_result}" ]]; then
			update_erase_drive_summary
		fi
	fi

	if [[ "${action_mode}" == [ev] ]]; then
		start_badblocks_timestamp="$(date '+%s')"

		echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Verifying All ZEROs on \"${erase_drive_id}\"...${CLEAR_ANSI}

    ${ANSI_BOLD}Start Time:${CLEAR_ANSI} $(date -d "@${start_badblocks_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")
       ${ANSI_BOLD}Elapsed:${CLEAR_ANSI} 0 Seconds
      ${ANSI_BOLD}Progress:${CLEAR_ANSI} Initializing..."

		badblocks_output_path="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-badblocks-${erase_drive_id}.txt" # TODO: Randomize this path?
		badblocks_progress_path="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-badblocks-progress-${erase_drive_id}.txt" # TODO: Randomize this path?
		rm -rf "${badblocks_output_path}" "${badblocks_progress_path}"

		# NOTE: Using "badblocks" here instead of "nwipe --method=verify_zero" since the final "nwipe --method=zero" pass above already ran a verify after zeroing. Now we want to explicity verify with ANOTHER tool to be sure.
		drive_block_size="$(blockdev --getbsz "${erase_drive_full_id}")" # TODO: Is using "blockdev --getbsz" for "-b" block size correct for all drives?
		drive_physical_block_size="$(blockdev --getpbsz "${erase_drive_full_id}")" # TODO: Using "--getbsz" WAS NOT right for a 4TB HDD since it was 512 while "--getpbsz" was 4096
		if (( drive_physical_block_size > drive_block_size )); then # TODO: But, "--getbsz" can be 4096 for other SSDs while "--getpbsz" will be 512, so use whichever is larger.
			drive_block_size="${drive_physical_block_size}"
		fi
		badblocks -e 1 -b "${drive_block_size:-512}" -svt '0x00' -o "${badblocks_output_path}" "${erase_drive_full_id}" &> "${badblocks_progress_path}" &
		badblocks_pid="$!"

		did_cancel_badblocks=false
		trap 'if ! $did_cancel_badblocks; then did_cancel_badblocks=true; >&2 echo -e "\n    ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} Canceling, please wait...${CLEAR_ANSI}"; fi' SIGINT # Ignore Control+C while "badblocks" is running in the background so that the signal is passed to the background processes and exit and show an error properly rather than just exiting this script immediately without showing an error.

		sleep 10

		while ps -p "${badblocks_pid}" &> /dev/null; do
			if ! $did_cancel_badblocks; then
				# TODO: Explain "tr -s '[:cntrl:]' '\n'"
				badblocks_progress_percentage="$(tr -s '[:cntrl:]' '\n' < "${badblocks_progress_path}" | awk '(($1 ~ /%$/)) && ($2 == "done,") { last_percentage=$1 } END { print substr(last_percentage, 1, (length(last_percentage) - 1)) }')"
				badblocks_progress_percentage="${badblocks_progress_percentage%0}" # Remove any trailing zero (from numbers like "12.30").

				echo -e "${OVERWRITE_LAST_TWO_LINES}       ${ANSI_BOLD}Elapsed:${CLEAR_ANSI} $(human_readable_duration_from_seconds "$(( $(date '+%s') - start_badblocks_timestamp ))")
      ${ANSI_BOLD}Progress:${CLEAR_ANSI} ${badblocks_progress_percentage:-0}%"
				sleep 10
			else
				sleep 5
			fi
		done

		trap - SIGINT # Allow Control+C after the "badblocks" pass is complete.

		badblocks_success=false # Check badblocks exit status from progress file since we can't use exit codes since it's in the background with a progress loop above.
		if ! $did_cancel_badblocks && [[ ! -s "${badblocks_output_path}" && -f "${badblocks_progress_path}" ]] && grep -qxF 'Pass completed, 0 bad blocks found. (0/0/0 errors)' "${badblocks_progress_path}"; then
			badblocks_success=true
		fi

		if $did_cancel_badblocks; then
			echo -en "${OVERWRITE_LAST_TWO_LINES}" # If canceled, need to remove AT LEAST 2 EXTRA lines (from canceling message) to dislay proper final progress. May still leave some stray lines if ENTER was pressed after Control+C, but this is the best we can do.
		fi

		end_badblocks_timestamp="$(date '+%s')"
		verify_duration="$(human_readable_duration_from_seconds "$(( end_badblocks_timestamp - start_badblocks_timestamp ))")"

		# Manually update progress to 100% IF "badblocks" was successful since the last progress update could have been before it completely finished.
		echo -e "${OVERWRITE_LAST_TWO_LINES}      ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${verify_duration}
      ${ANSI_BOLD}Progress:${CLEAR_ANSI} $($badblocks_success && echo '100' || echo "${badblocks_progress_percentage:-0}")%
      ${ANSI_BOLD}End Time:${CLEAR_ANSI} $(date -d "@${end_badblocks_timestamp}" "${DATE_DISPLAY_FORMAT_STRING}")"

		if $badblocks_success; then
			rm -rf "${badblocks_output_path}" "${badblocks_progress_path}"

			verify_result="Passed in ${verify_duration}"
			echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Verified All ZEROs on \"${erase_drive_id}\"${CLEAR_ANSI}"

			if ! check_drive_health -q; then # "check_drive_health -q" ONLY displays failure output.
				update_erase_drive_summary
				return 64 # DO NOT check "force_override_health_checks" for this final check since we want to actually exit with an error if it health failed after doing all previous erasures and verifications.
			elif [[ "${previous_health_check_result}" != "${health_check_result}" ]]; then
				update_erase_drive_summary
			fi
		else
			badblock_error_message="${ANSI_RED}${ANSI_BOLD}badblocks Log:${ANSI_RED}
$(tr -s '[:cntrl:]' '\n' < "${badblocks_progress_path}")${CLEAR_ANSI}"

			rm -rf "${badblocks_output_path}" "${badblocks_progress_path}"

			if $did_cancel_badblocks; then
				verify_result="CANCELED After ${verify_duration}"

				>&2 echo -e "
${badblock_error_message}

    ${ANSI_RED}${ANSI_BOLD}Verify All ZEROs CANCELED on \"${erase_drive_id}\"${CLEAR_ANSI}"

				return 100
			else
				verify_result="FAILED After ${verify_duration}"
				error_code=101

				>&2 echo -e "
${ANSI_RED}${ANSI_BOLD}Error Code:${ANSI_RED} ${error_code}${CLEAR_ANSI}

${badblock_error_message}

    ${ANSI_RED}${ANSI_BOLD}Verify All ZEROs FAILED on \"${erase_drive_id}\"${CLEAR_ANSI}

    ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
    ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${error_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}"

				send_error_email "Error Code: ${error_code}<br/><br/>${badblock_error_message}"
				error_should_not_have_happened=true
				return "${error_code}"
			fi
		fi
	fi
}

fg_eraser "$@"
fg_eraser_return_code="$?"

fg_eraser_passed=false
passed_with_health_check_override=false

error_type='UNKNOWN Error'
if (( fg_eraser_return_code == 0 )); then
	fg_eraser_passed=true
elif (( fg_eraser_return_code >= 200 )); then
	error_type='Unexpected Error'
elif (( fg_eraser_return_code >= 100 )); then
	error_type='Verification Failure'
elif (( fg_eraser_return_code >= 90 )); then
	error_type='TRIM Command Failure'
elif (( fg_eraser_return_code >= 80 )); then
	error_type='Secure Erase Command Failure'
elif (( fg_eraser_return_code >= 70 )); then
	error_type='Overwrite Failure'
elif (( fg_eraser_return_code >= 60 )); then
	error_type='Drive Health Failure'

	if $force_override_health_checks && (( fg_eraser_return_code == 63 || fg_eraser_return_code == 64 )); then
		passed_with_health_check_override=true
	fi
elif (( fg_eraser_return_code >= 50 )); then
	error_type='Drive Selection Error'
elif (( fg_eraser_return_code >= 40 )); then
	error_type='Drive Detection Error'
elif (( fg_eraser_return_code >= 30 )); then
	error_type='Required Packages Missing'
elif (( fg_eraser_return_code >= 20 )); then
	error_type='Argument Error'
elif (( fg_eraser_return_code >= 10 )); then
	error_type='Environment Error'
fi

display_action_completed_name='NO Action'
log_action_name='NO Action'
if [[ -n "${action_mode}" ]]; then
	display_action_completed_name='Erasure'
	log_action_name='Erase'
	if [[ "${action_mode}" != 'e' ]]; then
		if $is_verify_mode; then
			display_action_completed_name='Verification'
			log_action_name='Verify'
		else
			log_action_name="Erase (Manual Only ${action_mode_name:-UNKNOWN})" # "action_mode_name" will be set in "case" statments above in "Determining Erasure Method" section.
		fi
	fi
fi
log_action_name="$($WAS_LAUNCHED_FROM_GUI_MODE && echo 'GUI' || echo 'CLI')$($was_launched_from_auto_mode && echo ' Auto') ${log_action_name}"

log_status='Passed'
if ! $fg_eraser_passed; then
	log_status="FAILED (${error_type} ${fg_eraser_return_code})"
	if $passed_with_health_check_override; then
		log_status="Passed With Health Checks OVERRIDDEN / ${log_status}"
	fi
fi

echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Logging ${display_action_completed_name} ${log_status} for \"${erase_drive_id:-UNKNOWN}\" by \"${technician_initials:-N/A}\" (Lot ${lot_code:-N/A})...${CLEAR_ANSI}"

if [[ -z "${overall_start_timestamp}" ]]; then
	log_action_name="DID NOT Start ${log_action_name}"
else
	log_action_name="Finished ${log_action_name}"
	overall_duration="$(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
fi

log_action "${log_action_name}" "${log_status}"

echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Logged ${display_action_completed_name} ${log_status} for \"${erase_drive_id:-UNKNOWN}\" by \"${technician_initials:-N/A}\" (Lot ${lot_code:-N/A})${CLEAR_ANSI}"

if [[ -n "${erase_drive_summary}" ]]; then
	echo -e "\n${erase_drive_summary}
    ${ANSI_BOLD}Duration:${CLEAR_ANSI} ${overall_duration}" # Show drive summary again to inclue OVERALL DURATION, and also since it may have been scrolled out of view and it could be useful to see the full details of the passed or failed drive.
fi

readonly BLOCK='\xE2\x96\x88' # https://www.compart.com/en/unicode/U+2588
if $fg_eraser_passed || $passed_with_health_check_override; then
	passed_color="${ANSI_GREEN}"
	passed_note=''
	if $passed_with_health_check_override; then
		passed_color="${ANSI_YELLOW}"
		passed_note="
  ${ANSI_GREEN}${ANSI_BOLD}${display_action_completed_name} PASSED With Health Checks OVERRIDDEN\n  ${ANSI_RED}${ANSI_BOLD}But, health check still FAILED!${CLEAR_ANSI}
"
	fi

	echo -e "
${passed_color}
  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}   ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK} ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK} ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK} ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK} ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}
${CLEAR_ANSI}${passed_note}"
else
	echo -e "
${ANSI_RED}
  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}  ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK} ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}   ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK} ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK} ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}
  ${BLOCK}${BLOCK}      ${BLOCK}${BLOCK}   ${BLOCK}${BLOCK} ${BLOCK}${BLOCK} ${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}${BLOCK}
${CLEAR_ANSI}"
fi

if $error_should_not_have_happened; then
	echo -e "
  ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} THIS SHOULD NOT HAVE HAPPENED ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
  ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}ERROR ${fg_eraser_return_code}${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}
"
fi

if $WAS_LAUNCHED_FROM_GUI_MODE || $WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE; then
	set_terminator_tab_title "$($fg_eraser_passed && echo 'PASSED' || echo 'FAILED') \"${erase_drive_id:-UNKNOWN}\" ${display_action_completed_name}"

	if $WAS_LAUNCHED_FROM_GUI_MODE; then
		while true; do
			echo -en "\n  ${ANSI_CYAN}Type $($fg_eraser_passed && echo "${ANSI_GREEN}${ANSI_BOLD}P${ANSI_CYAN} or ${ANSI_GREEN}${ANSI_BOLD}PASS" || echo "${ANSI_RED}${ANSI_BOLD}F${ANSI_CYAN} or ${ANSI_RED}${ANSI_BOLD}FAIL")${ANSI_CYAN} and Press ${ANSI_BOLD}ENTER${ANSI_CYAN} to ${ANSI_BOLD}Close This Window${ANSI_CYAN}:${CLEAR_ANSI} "
			read -r confirm_exit
			confirm_exit="$(trim_and_squeeze_whitespace "${confirm_exit,,}")"
			if { $fg_eraser_passed && [[ "${confirm_exit}" == 'p' || "${confirm_exit}" == 'pass' ]]; } ||
				{ ! $fg_eraser_passed && [[ "${confirm_exit}" == 'f' || "${confirm_exit}" == 'fail' ]]; }; then
				break
			fi
		done
	else
		while true; do
			echo -en "\n  ${ANSI_CYAN}Type ${ANSI_BOLD}Q${ANSI_CYAN} to ${ANSI_UNDERLINE}Quit${ANSI_CYAN}, ${ANSI_BOLD}R${ANSI_CYAN} to ${ANSI_UNDERLINE}Reboot${ANSI_CYAN}, or ${ANSI_BOLD}S${ANSI_CYAN} to ${ANSI_UNDERLINE}Shut Down${ANSI_CYAN} and Press ${ANSI_BOLD}ENTER${ANSI_CYAN}:${CLEAR_ANSI} "
			read -r confirm_exit
			confirm_exit="$(trim_and_squeeze_whitespace "${confirm_exit,,}")"
			if [[ "${confirm_exit}" == 'q' || "${confirm_exit}" == 'quit' ]]; then
				break
			elif [[ "${confirm_exit}" == 'r' || "${confirm_exit}" == 'reboot' ]]; then
				systemctl reboot
				break
			elif [[ "${confirm_exit}" == 's' || "${confirm_exit}" == 'shut down' || "${confirm_exit}" == 'shutdown' ]]; then
				systemctl poweroff
				break
			else
				>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Only ${ANSI_BOLD}Q${ANSI_RED}, ${ANSI_BOLD}R${ANSI_RED}, or ${ANSI_BOLD}S${ANSI_RED} can be specified. ${ANSI_YELLOW}${ANSI_BOLD}(TRY AGAIN)${CLEAR_ANSI}"
			fi
		done
	fi
else
	echo ''
fi

exit "${fg_eraser_return_code}"
