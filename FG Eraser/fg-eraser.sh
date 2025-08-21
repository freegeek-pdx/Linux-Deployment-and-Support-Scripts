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

if true; then # Wrap entire script in "if true" block so that if there is a incomplete "curl" download of the script that the shell throws an error instead of executing an incomplete download.
	readonly APP_NAME='FG Eraser'
	readonly APP_VERSION='2025.8.19-1'

	# shellcheck disable=SC2292
	if [ -t 1 ]; then # ONLY use ANSI styling if stdout IS associated with an interactive terminal.
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
		if [ -z "${DISPLAY}" ]; then # In non-GUI environment, UNDERLINE is rendered as CYAN, so make it BOLD instead.
			ANSI_UNDERLINE="${ANSI_BOLD}"
		fi
	fi
	readonly CLEAR_ANSI ANSI_RED ANSI_GREEN ANSI_YELLOW ANSI_PURPLE ANSI_CYAN ANSI_GREY ANSI_BOLD ANSI_UNDERLINE

	readonly APP_DISPLAY_TITLE="\n  ${ANSI_PURPLE}${ANSI_BOLD}${APP_NAME}${CLEAR_ANSI} ${ANSI_GREY}(Version ${APP_VERSION})${CLEAR_ANSI}"

	# Suppress ShellCheck warning to use "[[" over "[" conditions since these first 3 conditions intentionally use "[" instead of "[[" so that they do not get bypassed with a "not found" error in any shell, such as strict POSIX shells like "dash".
	# shellcheck disable=SC2292
	if [ -n "${ZSH_VERSION}" ]; then
		>&2 printf "%b\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} %s${CLEAR_ANSI}\n\n" "${APP_DISPLAY_TITLE}" 'Not compatible with "zsh" and must be run in "bash" instead.'
		exit 10
	elif [ -z "${BASH_VERSION}" ]; then
		>&2 printf "%b\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} %s${CLEAR_ANSI}\n\n" "${APP_DISPLAY_TITLE}" 'Not compatible with this shell and must be run in "bash" instead.'
		exit 10 # Use same error code for all "not bash" errors.
	elif [ "${BASH}" != '/bin/bash' ] && [ "${BASH}" != '/usr/bin/bash' ]; then
		>&2 printf "%b\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} %s${CLEAR_ANSI}\n\n" "${APP_DISPLAY_TITLE}" 'Not compatible with "sh" and must be run in "bash" instead.'
		exit 10 # Use same error code for all "not bash" errors.
	elif [[ "$(uname -o)" != 'GNU/Linux' ]] || ! command -v apt-cache &> /dev/null || ! command -v apt-get &> /dev/null; then
		>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Only compatible with GNU/Linux distributions which include \"apt\".${CLEAR_ANSI}\n"
		exit 11
	fi

	APP_NAME_FOR_FILE_PATHS="${APP_NAME,,}"
	readonly APP_NAME_FOR_FILE_PATHS="${APP_NAME_FOR_FILE_PATHS// /-}"

	readonly EM_DASH=$'\xE2\x80\x94' # https://www.compart.com/en/unicode/U+2014
	readonly ELLIPSIS=$'\xE2\x80\xA6' # https://www.compart.com/en/unicode/U+2026
	readonly EMOJI_COUNTERCLOCKWISE_ARROWS=$'\xF0\x9F\x94\x84' # https://www.compart.com/en/unicode/U+1F504

	TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

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

	can_launch_zenity() {
		if $IS_GUI_MODE; then
			apt_info_for_zenity="$(apt-cache policy zenity 2> /dev/null)"

			if [[ -n "${apt_info_for_zenity}" && "${apt_info_for_zenity}" != *'Unable to locate package'* && "${apt_info_for_zenity}" != *'Installed: (none)'* ]]; then
				return 0
			fi
		fi

		return 1
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

		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to decrypt private strings. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"

		if can_launch_zenity; then
			zenity --warning --title "${APP_NAME}  ${EM_DASH}  Decrypt Private Strings Error" "${zenity_icon_caution_args[@]}" --no-wrap --text '<big><b>Failed to decrypt private strings.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>' &> /dev/null
		fi

		exit 17
	fi

	IFS=$'\n' read -rd '' EMAIL_SECRET_KEY SEND_ERROR_EMAIL_TO SEND_ERROR_EMAIL_FROM _ <<< "${PRIVATE_STRINGS}"
	readonly PRIVATE_STRINGS EMAIL_SECRET_KEY SEND_ERROR_EMAIL_TO SEND_ERROR_EMAIL_FROM

	if [[ -z "${EMAIL_SECRET_KEY}" || -z "${SEND_ERROR_EMAIL_TO}" || -z "${SEND_ERROR_EMAIL_FROM}" ]]; then
		rm -rf "${PRIVATE_STRINGS_PASSWORD_PATH}"

		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to load decrypted private strings. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"

		if can_launch_zenity; then
			zenity --warning --title "${APP_NAME}  ${EM_DASH}  Load Private Strings Error" "${zenity_icon_caution_args[@]}" --no-wrap --text '<big><b>Failed to load decrypted private strings.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>' &> /dev/null
		fi

		exit 18
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

			error_message="<b>${APP_NAME} Version:</b> ${APP_VERSION}<br/><b>Location:</b> ${location_info}<br/><b>Tech Initials:</b> ${technician_initials:-N/A}<br/><b>Lot Code:</b> ${lot_code:-N/A}<br/><br/><b>OS:</b> ${OS_NAME:-N/A}<br/>${COMPUTER_INFO_FOR_ERROR_EMAIL}<br/><br/><b>Error Message:</b><br/><span style=\"font-family: monospace;\">${error_message}</span>"

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

	technician_initials=''
	lot_code=''
	force_override_health_checks=false
	cli_list_mode=false
	cli_list_auto_reload_mode=false
	cli_action_mode=''
	cli_quick_mode=false
	declare -a cli_action_mode_override_notices=()
	cli_specified_drive_id=''
	cli_specified_drive_full_id=''
	cli_auto_mode=false
	WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE=false
	OPTIND=1
	while getopts ':VhEi:c:flLd:evR103TSq' this_option; do # TODO: Add "-D" option to enable DEBUG output?
		case "${this_option}" in
			'V')
				echo "${APP_VERSION}"
				exit 0
				;;
			'h')
				if [[ -t 1 ]]; then # ONLY "clear" if stdout IS associated with an interactive terminal.
					clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
				fi

				echo -e "${APP_DISPLAY_TITLE}

  Run with ${ANSI_BOLD}NO OPTIONS${CLEAR_ANSI} to launch ${ANSI_UNDERLINE}GUI mode${CLEAR_ANSI}.

  ${ANSI_BOLD}-i [TECHNICIAN INITIALS]${CLEAR_ANSI}
    Specify the technician initials for logging. If this is not specified, it will be prompted in the GUI or on the command line.
    This option is IGNORED when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified, but WORKS for both CLI mode (when ${ANSI_BOLD}-d${CLEAR_ANSI} is specified), or in GUI mode.

  ${ANSI_BOLD}-c [LOT CODE]${CLEAR_ANSI}
    Specify the lot code which is \"FG\" followed by 8 digits a hyphen and 1 digit, or \"N\" if no lot code. If this is not specified, it will be prompted in the GUI or on the command line.
    This option is IGNORED when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified, but WORKS for both CLI mode (when ${ANSI_BOLD}-d${CLEAR_ANSI} is specified), or in GUI mode.

  ${ANSI_BOLD}-f${CLEAR_ANSI}
    Force override health check failures and erase or verify anyway.
    IMPORTANT: Even if the specified erasure or verification succeeds, the final result will ALWAYS be a FAILURE because of the health check failure.
    This option is IGNORED when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified, but WORKS for both CLI mode (when ${ANSI_BOLD}-d${CLEAR_ANSI} is specified), or in GUI mode.

  ${ANSI_BOLD}-l${CLEAR_ANSI}
    Output a list of all detected drives on the command line (without GUI).
    This option is OVERRIDES ${ANSI_BOLD}-d${CLEAR_ANSI}.

  ${ANSI_BOLD}-L${CLEAR_ANSI}
    Output a list of all detected drives on the command line (without GUI) AND continuously reload the list every 10 seconds.
    This option is OVERRIDES ${ANSI_BOLD}-l${CLEAR_ANSI} and ${ANSI_BOLD}-d${CLEAR_ANSI}.

  ${ANSI_BOLD}-d [DEVICE ID (or \"auto\")]${CLEAR_ANSI}
    Specify a DEVICE ID such as ${ANSI_UNDERLINE}/dev/sdX${CLEAR_ANSI} or ${ANSI_UNDERLINE}sdX${CLEAR_ANSI} with ${ANSI_BOLD}-d${CLEAR_ANSI} to run in CLI mode.
    Supports SATA, SAS, NVMe, USB, or eMMC/Memory Card drive device identifiers.
    When specifying an NVMe drive, the namespace must be included, such as ${ANSI_UNDERLINE}/dev/nvmeXnY${CLEAR_ANSI} (and not only ${ANSI_UNDERLINE}/dev/nvmeX${CLEAR_ANSI}).
    Or, specify \"auto\" instead of a DEVICE ID to run in AUTOMATIC DRIVE SELECTION MODE to auto-select the device identifier when there is ONLY ONE DRIVE (if none or multiple drives are detected, then exit with an error).
    This option is IGNORED when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified.

  ${ANSI_BOLD}-e${CLEAR_ANSI}
    When ${ANSI_BOLD}-d${CLEAR_ANSI} is specified to run in CLI mode, specify ${ANSI_BOLD}-e${CLEAR_ANSI} to ERASE (best method determined dynamically) and then VERIFY, this is what is done when \"Ready to Erase\" is chosen in GUI mode.
    If ${ANSI_BOLD}-d${CLEAR_ANSI} is specified without ${ANSI_BOLD}-e${CLEAR_ANSI}, ${ANSI_BOLD}-v${CLEAR_ANSI}, or any SPECIFIC ERASURE ACTION then the mode will be prompted on the command line.
    This option is MUTUALLY EXCLUSIVE with ${ANSI_BOLD}-v${CLEAR_ANSI} and with the SPECIFIC ERASURE ACTIONS listed below, the last one specified takes precedence.
    This option is IGNORED when ${ANSI_BOLD}-d${CLEAR_ANSI} is not specified (you'll always be prompted to choose to Erase or Verify when running in GUI mode) or when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified.

  ${ANSI_BOLD}-v${CLEAR_ANSI}
    When ${ANSI_BOLD}-d${CLEAR_ANSI} is specified to run in CLI mode, specify ${ANSI_BOLD}-v${CLEAR_ANSI} to VERIFY ONLY (and not ERASE), this is what is done when \"Ready to Verify\" is chosen in GUI mode.
    If ${ANSI_BOLD}-d${CLEAR_ANSI} is specified without ${ANSI_BOLD}-e${CLEAR_ANSI}, ${ANSI_BOLD}-v${CLEAR_ANSI}, or any SPECIFIC ERASURE ACTION then the mode will be prompted on the command line.
    This option is MUTUALLY EXCLUSIVE with ${ANSI_BOLD}-e${CLEAR_ANSI} and with the SPECIFIC ERASURE ACTIONS listed below, the last one specified takes precedence.
    This option is IGNORED when ${ANSI_BOLD}-d${CLEAR_ANSI} is not specified (you'll always be prompted to choose to Erase or Verify when running in GUI mode) or when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified.

  ${ANSI_BOLD}-R | -1 | -0 | -3 | -T | -S${CLEAR_ANSI}
    ONLY perform a SPECIFIC ERASURE ACTION:
      ${ANSI_BOLD}-R${CLEAR_ANSI}: Overwrite RANDOM Data
      ${ANSI_BOLD}-1${CLEAR_ANSI}: Overwrite ONEs
      ${ANSI_BOLD}-0${CLEAR_ANSI}: Overwrite ZEROs
      ${ANSI_BOLD}-3${CLEAR_ANSI}: 3 Pass Overwrite (RANDOM Data, ONEs, ZEROs)
      ${ANSI_BOLD}-T${CLEAR_ANSI}: Send TRIM Command (If SSD & Supported)
      ${ANSI_BOLD}-S${CLEAR_ANSI}: Send Secure Erase Command (If SSD & Supports \"ATA Secure Erase\", \"SCSI Sanitize\", or \"Format NVM\")
    These options WILL NOT VERIFY after the erasure is performed (like ${ANSI_BOLD}-e${CLEAR_ANSI} does).
    These options are MUTUALLY EXCLUSIVE with each other and with ${ANSI_BOLD}-e${CLEAR_ANSI} and ${ANSI_BOLD}-v${CLEAR_ANSI}, the last one specified takes precedence.
    These options are IGNORED when ${ANSI_BOLD}-d${CLEAR_ANSI} is not specified (running in GUI mode) or when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified.
    IMPORTANT: These options are for ADVANCED USAGE ONLY, for normal usage only ${ANSI_BOLD}-e${CLEAR_ANSI} or ${ANSI_BOLD}-v${CLEAR_ANSI} should be specified, or omitted for the mode to be prompted on the command line.

  ${ANSI_BOLD}-q${CLEAR_ANSI}
    When ${ANSI_BOLD}-d${CLEAR_ANSI} is specified to run in CLI mode and an erasure is specified (using ${ANSI_BOLD}-e${CLEAR_ANSI} or any SPECIFIC ERASURE ACTION), there is a 10 second chance to cancel before the erase starts.
    Specify ${ANSI_BOLD}-q${CLEAR_ANSI} to ${ANSI_UNDERLINE}quickly${CLEAR_ANSI} start the erasure ${ANSI_BOLD}without the 10 second delay${CLEAR_ANSI}.
    Also, if the computer needs to sleep to unfreeze a drive for a Secure Erase command, specifying ${ANSI_BOLD}-q${CLEAR_ANSI} will also sleep immediately without a 10 second delay.
    This option is IGNORED when ${ANSI_BOLD}-d${CLEAR_ANSI} is not specified or when ${ANSI_BOLD}-l${CLEAR_ANSI} or ${ANSI_BOLD}-L${CLEAR_ANSI} is specified.

  ${ANSI_BOLD}-V${CLEAR_ANSI}
    Output version.

  ${ANSI_BOLD}-h${CLEAR_ANSI}
    Output this help information.

  ${ANSI_BOLD}${ANSI_UNDERLINE}Exit Error Code Types:${CLEAR_ANSI}
    ${ANSI_BOLD}1X${CLEAR_ANSI}: Environment Error
    ${ANSI_BOLD}2X${CLEAR_ANSI}: Argument Error
    ${ANSI_BOLD}3X${CLEAR_ANSI}: Required Packages Missing
    ${ANSI_BOLD}4X${CLEAR_ANSI}: Drive Detection Error
    ${ANSI_BOLD}5X${CLEAR_ANSI}: Drive Selection Error
    ${ANSI_BOLD}6X${CLEAR_ANSI}: Drive Health Failure
    ${ANSI_BOLD}7X${CLEAR_ANSI}: Overwrite Failure
    ${ANSI_BOLD}8X${CLEAR_ANSI}: Secure Erase Command Failure
    ${ANSI_BOLD}9X${CLEAR_ANSI}: TRIM Command Failure
    ${ANSI_BOLD}10X${CLEAR_ANSI}: Verification Failure
    ${ANSI_BOLD}20X${CLEAR_ANSI}: Unexpected Error
" | less -FR
				exit 0
				;;
			'E')
				>&2 echo -e "${APP_DISPLAY_TITLE}\n\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Sending Debug Email...${CLEAR_ANSI}"

				if send_error_email $'DEBUG EMAIL\n\nScreen Info:\n'"$(xrandr)"; then
					echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Sent Debug Email${CLEAR_ANSI}"
				fi

				echo ''

				exit 0
				;;
			'i')
				technician_initials="$(trim_and_squeeze_whitespace "${OPTARG^^}")"
				if [[ ! "${technician_initials}" =~ ^[ABCDEFGHIJKLMNOPQRSTUVWXYZ]{2,4}$ ]]; then
					technician_initials=''
				fi

				if [[ -z "${technician_initials}" ]]; then
					>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid TECHNICIAN INITIALS specified (MUST be only 2-4 letters).${CLEAR_ANSI}\n"
					exit 20
				fi
				;;
			'c')
				lot_code="$(trim_and_squeeze_whitespace "${OPTARG^^}")"
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
					>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid LOT CODE specified (MUST be \"FG\" followed by 8 digits a hyphen and 1 digit, or \"N\" if NO lot code).${CLEAR_ANSI}\n"
					exit 21
				fi
				;;
			'f') force_override_health_checks=true ;;
			'l') cli_list_mode=true ;;
			'L')
				cli_list_mode=true
				cli_list_auto_reload_mode=true
				;;
			'd')
				cli_specified_drive_full_id="$(trim_and_squeeze_whitespace "${OPTARG,,}")"
				if [[ "${cli_specified_drive_full_id}" == 'auto' ]]; then
					cli_auto_mode=true
					cli_specified_drive_full_id=''

					if grep -qF " ${APP_NAME_FOR_FILE_PATHS}-auto-" '/proc/cmdline' && [[ "$(ps -p "$(ps -p "$PPID" -o 'ppid=' 2> /dev/null | trim_and_squeeze_whitespace)" -o 'args=' 2> /dev/null)" == *"/terminator --title ${APP_NAME} (Auto "* ]]; then
						# Free Geek's custom Debian-based Live Boot (FG Eraser Live) uses custom boot arguments to be able to specify the mode for FG Eraser to auto-start into after boot, so check for these boot args to determine if was booted into an auto-mode.
						WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE=true
						echo -en "\e]0;${APP_NAME}\a" # Set "terminator" tab title: https://stackoverflow.com/a/22548561
					fi
				elif [[ "${cli_specified_drive_full_id}" == '/dev/sd'* || "${cli_specified_drive_full_id}" == 'sd'* ||
					"${cli_specified_drive_full_id}" == '/dev/nvme'* || "${cli_specified_drive_full_id}" == 'nvme'* ||
					"${cli_specified_drive_full_id}" == '/dev/mmcblk'* || "${cli_specified_drive_full_id}" == 'mmcblk'* ]]; then
					cli_specified_drive_id="${cli_specified_drive_full_id##*/}"
					cli_specified_drive_full_id="/dev/${cli_specified_drive_id}"
					cli_auto_mode=false

					if [[ "${cli_specified_drive_full_id}" == '/dev/sd'*[0123456789]* || "${cli_specified_drive_full_id}" == '/dev/nvme'*'p'* || "${cli_specified_drive_full_id}" == '/dev/mmcblk'*'p'* ]]; then
						>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} The drive device ID specified for \"-d\" option MUST ONLY be a whole device ID and NOT a partition.${CLEAR_ANSI}\n"
						exit 50
					elif [[ "${cli_specified_drive_full_id}" == '/dev/nvme'* && "${cli_specified_drive_full_id}" != '/dev/nvme'*'n'* ]]; then
						>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} When specifying an NVMe drive, the namespace must be included, such as \"/dev/nvmeXnY\" (and not only \"/dev/nvmeX\").${CLEAR_ANSI}\n"
						exit 51
					fi
				else
					>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid drive device ID specified for \"-d\" option (must only be SATA, SAS, NVMe, USB, or eMMC/Memory Card drive device identifier).${CLEAR_ANSI}\n"
					exit 22
				fi
				;;
			'e' | 'v' | 'R' | '1' | '0' | '3' | 'T' | 'S')
				if [[ -n "${cli_action_mode}" ]]; then
					cli_action_mode_override_notices+=( "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-${cli_action_mode}\" is OVERRIDDEN by \"-${this_option}\" which is specified after.${CLEAR_ANSI}" )
				fi

				cli_action_mode="${this_option}"
				;;
			'q') cli_quick_mode=true ;;
			':')
				>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required parameter not specified for \"-${OPTARG}\" option.${CLEAR_ANSI}\n"
				exit 23
				;;
			*)
				>&2 echo -e "${APP_DISPLAY_TITLE}\n\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Invalid \"-${OPTARG}\" option specified.${CLEAR_ANSI}\n"
				exit 24
				;;
		esac
	done
	readonly WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE

	if [[ "${COMPUTER_INFO_FOR_ERROR_EMAIL}" == *' Apple'*'iMac'* || "${COMPUTER_INFO_FOR_ERROR_EMAIL}" == *' Apple'*'Mac'*'mini'* ]]; then
		# Check if running on iMac or Mac mini, since they could have Fusion Drives where we want to override failed drives on to be able to always erase both rather than only erasing one and having the tech not notice.
		force_override_health_checks=true
	fi

	if [[ -t 1 ]]; then # ONLY "clear" if stdout IS associated with an interactive terminal.
		clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
	fi

	echo -e "${APP_DISPLAY_TITLE}"

	declare -a zenity_icon_args=()
	declare -a zenity_icon_caution_args=()

	IS_GUI_MODE=true
	if $cli_list_mode || $cli_auto_mode || [[ -n "${cli_specified_drive_full_id}" ]]; then
		IS_GUI_MODE=false

		if [[ ! -t 0 ]]; then # Do not allow running if stdin file descriptor is NOT associated with a terminal when in CLI mode (ie. the script being piped to "bash" like "curl eraser.freegeek.org | bash -s -- [ARGS]") because that would not allow "read" pauses to work since it would continue without user interaction.
			>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Cannot run via shell redirection in CLI mode.${CLEAR_ANSI}\n\n  ${ANSI_PURPLE}${ANSI_BOLD}NOTE:${ANSI_PURPLE} Use \"bash <(curl eraser.freegeek.org) [ARGS]\" to run this script in CLI mode.${CLEAR_ANSI}\n"
			exit 12
		fi
	else
		app_icon_path="/usr/share/${APP_NAME_FOR_FILE_PATHS}/${APP_NAME_FOR_FILE_PATHS}-icon.svg"
		if [[ -f "${app_icon_path}" ]] && ! grep -qxF '<svg width="256" height="256" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">' "${app_icon_path}"; then
			rm -rf "${app_icon_path}"
		fi
		if [[ ! -f "${app_icon_path}" && -w "${app_icon_path%/*}" ]]; then
			# The following SVG image is based on "Pencil" from Twemoji (https://github.com/twitter/twemoji) by Twitter (https://twitter.com) licensed under CC-BY 4.0 (https://github.com/twitter/twemoji/blob/master/LICENSE-GRAPHICS)
			# NOTE: This image was created in Pixelmator Pro at 1024x1024 for the best alignment precision of the eraser line and then adjusted down to 256x256 since Zenity does not seem to display images larger than 512x512.

			mkdir -p "${app_icon_path%/*}"
			echo '<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
    <linearGradient id="linearGradient1" x1="210" y1="989" x2="1024" y2="989" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#ea596e" stop-opacity="1"/>
        <stop offset="0.151748" stop-color="#ea596e" stop-opacity="1"/>
        <stop offset="1" stop-color="#ea596e" stop-opacity="0"/>
    </linearGradient>
    <path id="Rectangle" fill="url(#linearGradient1)" fill-rule="evenodd" stroke="none" d="M 210 1016 L 1024 1016 L 1024 962 L 210 962 Z"/>
    <path id="Path" fill="#d99e82" stroke="none" d="M 1001.870239 68.323547 C 983.466675 128.085327 953.372375 240.668457 935.736877 283.534241 C 921.486206 318.122681 908.174194 352.881775 891.818665 369.265808 C 875.463135 385.621338 847.644409 384.341309 830.862183 367.615967 C 830.862183 367.615967 760.632874 319.971558 735.459595 288.455139 C 703.943115 263.367126 656.24176 192.967102 656.24176 192.967102 C 639.459595 176.184875 638.179565 148.394653 654.535095 132.010681 C 670.919128 115.65509 705.678223 102.343079 740.295105 88.092468 C 783.132446 70.456909 895.743958 40.419617 955.505737 21.959106 C 965.717346 18.8302 1004.999146 58.112 1001.870239 68.323547 Z"/>
    <path id="path1" fill="#ea596e" stroke="none" d="M 388.067535 873.016846 C 420.807098 840.277344 420.807098 787.228394 388.067535 754.488892 L 269.539551 635.932495 C 236.799988 603.221313 183.694229 603.221313 151.011551 635.932495 L 32.455112 754.488892 C -0.256 787.228394 -0.256 840.277344 32.455112 873.016846 L 150.983109 991.544922 C 183.694229 1024.284424 236.771561 1024.284424 269.511108 991.544922 L 388.067535 873.016846 Z"/>
    <path id="path2" fill="#ffcc4d" stroke="none" d="M 891.818665 369.265808 L 773.205322 250.652466 L 654.791138 132.181335 L 210.261337 576.682678 L 447.345795 813.738647 L 891.818665 369.265808 Z"/>
    <path id="path3" fill="#292f33" stroke="none" d="M 912.440857 35.185791 C 912.440857 35.185791 989.496826 -7.167969 1010.318237 13.65332 C 1031.139526 34.474731 988.558289 111.360046 988.558289 111.360046 C 988.558289 111.360046 915.569763 109.99469 912.440857 35.185791 Z"/>
    <path id="path4" fill="#ccd6dd" stroke="none" d="M 62.094223 724.849731 L 299.17865 961.934265 L 447.317322 813.767151 L 210.261337 576.682678 Z"/>
    <path id="path5" fill="#99aab5" stroke="none" d="M 91.73333 695.239136 L 328.789337 932.295166 L 358.428436 902.656006 L 121.372452 665.599976 Z M 150.983109 635.903931 L 388.067535 872.988464 L 417.706665 843.349365 L 180.622223 606.293335 Z"/>
</svg>' > "${app_icon_path}"
	fi

		if [[ -f "${app_icon_path}" ]]; then
			zenity_icon_args+=( --window-icon "${app_icon_path}" )
			zenity_icon_caution_args+=( --window-icon "${app_icon_path}" )

			app_icon_theme_path="/usr/share/icons/hicolor/scalable/apps/${APP_NAME_FOR_FILE_PATHS}.svg"
			if [[ ! -L "${app_icon_theme_path}" ]]; then
				rm -rf "${app_icon_theme_path}"
				ln -sf "${app_icon_path}" "${app_icon_theme_path}"
				gtk-update-icon-cache -qf '/usr/share/icons/hicolor' &> /dev/null # https://askubuntu.com/a/884758 # TODO: Test this command from https://github.com/gnome-terminator/terminator/blob/master/INSTALL.md#source-install
			fi

			if [[ -L "${app_icon_theme_path}" ]]; then
				zenity_icon_args+=( --icon-name "${APP_NAME_FOR_FILE_PATHS}" ) # https://askubuntu.com/a/1002818
			fi
		fi

		app_caution_icon_path="/usr/share/${APP_NAME_FOR_FILE_PATHS}/${APP_NAME_FOR_FILE_PATHS}-caution-icon.svg"
		if [[ -f "${app_caution_icon_path}" ]] && ! grep -qxF '<svg width="256" height="256" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">' "${app_caution_icon_path}"; then
			rm -rf "${app_caution_icon_path}"
		fi
		if [[ ! -f "${app_caution_icon_path}" && -w "${app_caution_icon_path%/*}" ]]; then
			# The following SVG image is based on "Pencil" combined with "Warning" from Twemoji (https://github.com/twitter/twemoji) by Twitter (https://twitter.com) licensed under CC-BY 4.0 (https://github.com/twitter/twemoji/blob/master/LICENSE-GRAPHICS)
			# NOTE: This image was created in Pixelmator Pro at 1024x1024 for the best alignment precision of the eraser line and then adjusted down to 256x256 since Zenity does not seem to display images larger than 512x512.

			mkdir -p "${app_caution_icon_path%/*}"
			echo '<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
    <linearGradient id="linearGradient1" x1="605.748633" y1="1002.27275" x2="1015.921778" y2="1002.27275" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#ea596e" stop-opacity="1"/>
        <stop offset="0.151748" stop-color="#ea596e" stop-opacity="1"/>
        <stop offset="1" stop-color="#ea596e" stop-opacity="0"/>
    </linearGradient>
    <path id="Rectangle" fill="url(#linearGradient1)" fill-rule="evenodd" stroke="none" d="M 605.748657 1015.877991 L 1015.921814 1015.877991 L 1015.921814 988.66748 L 605.748657 988.66748 Z"/>
    <path id="Path" fill="#d99e82" stroke="none" d="M 1004.77063 538.345581 C 995.497131 568.459351 980.332642 625.189819 971.446167 646.789795 C 964.265259 664.218872 957.557373 681.733887 949.315857 689.989746 C 941.07428 698.231323 927.056519 697.586304 918.599976 689.158447 C 918.599976 689.158447 883.211548 665.150513 870.526794 649.269409 C 854.645691 636.627686 830.60907 601.153198 830.60907 601.153198 C 822.152527 592.696655 821.507568 578.693237 829.749084 570.437378 C 838.004944 562.195801 855.52002 555.487915 872.963379 548.307007 C 894.549011 539.420532 951.293823 524.28479 981.407654 514.982544 C 986.553223 513.405884 1006.34729 533.199951 1004.77063 538.345581 Z"/>
    <path id="path1" fill="#ea596e" stroke="none" d="M 695.476563 943.829041 C 711.973938 927.331665 711.973938 900.600403 695.476563 884.103027 L 635.750488 824.362671 C 619.253113 807.879578 592.493225 807.879578 576.024475 824.362671 L 516.284058 884.103027 C 499.801025 900.600403 499.801025 927.331665 516.284058 943.829041 L 576.010132 1003.555115 C 592.493225 1020.05249 619.23877 1020.05249 635.736206 1003.555115 L 695.476563 943.829041 Z"/>
    <path id="path2" fill="#ffcc4d" stroke="none" d="M 949.315857 689.989746 L 889.546814 630.220703 L 829.878113 570.523315 L 605.88031 794.506775 L 725.346741 913.958862 L 949.315857 689.989746 Z"/>
    <path id="path3" fill="#292f33" stroke="none" d="M 959.707336 521.647461 C 959.707336 521.647461 998.535706 500.305481 1009.027588 510.797302 C 1019.519409 521.289185 998.062744 560.031494 998.062744 560.031494 C 998.062744 560.031494 961.283997 559.343506 959.707336 521.647461 Z"/>
    <path id="path4" fill="#ccd6dd" stroke="none" d="M 531.219177 869.167908 L 650.685608 988.634338 L 725.332397 913.973206 L 605.88031 794.506775 Z"/>
    <path id="path5" fill="#99aab5" stroke="none" d="M 546.154297 854.247192 L 665.606384 973.69928 L 680.541443 958.76416 L 561.089355 839.312073 Z M 576.010132 824.348267 L 695.476563 943.814758 L 710.411682 928.879639 L 590.945251 809.42749 Z"/>
    <path id="path6" fill="#ffcc4d" stroke="none" d="M 48.807358 666.085449 C 13.419241 666.085449 -2.180731 640.380005 14.110866 608.96875 L 313.987671 31.558472 C 330.298492 0.147217 356.983673 0.147217 373.294464 31.558472 L 673.171265 608.987976 C 689.501282 640.380005 673.88208 666.085449 638.494019 666.085449 L 48.807358 666.085449 Z"/>
    <path id="path7" fill="#231f20" stroke="none" d="M 297.21579 549.911743 C 297.21579 524.302429 318.060547 503.457642 343.689117 503.457642 C 369.298401 503.457642 390.143219 524.302429 390.143219 549.911743 C 390.143219 575.540283 369.279205 596.38501 343.689117 596.38501 C 318.060547 596.38501 297.21579 575.540283 297.21579 549.911743 Z M 300.789185 198.470459 C 300.789185 173.456726 319.251709 157.972046 343.669891 157.972046 C 367.511719 157.972046 386.569794 174.052307 386.569794 198.470459 L 386.569794 427.820801 C 386.569794 452.238953 367.511719 468.319214 343.669891 468.319214 C 319.251709 468.319214 300.789185 452.815369 300.789185 427.820801 L 300.789185 198.470459 Z"/>
</svg>' > "${app_caution_icon_path}"
		fi

		if [[ -f "${app_caution_icon_path}" ]]; then
			app_caution_icon_theme_path="/usr/share/icons/hicolor/scalable/apps/${APP_NAME_FOR_FILE_PATHS}-caution.svg"
			if [[ ! -L "${app_caution_icon_theme_path}" ]]; then
				rm -rf "${app_caution_icon_theme_path}"
				ln -sf "${app_caution_icon_path}" "${app_caution_icon_theme_path}"
				gtk-update-icon-cache -qf '/usr/share/icons/hicolor' &> /dev/null # https://askubuntu.com/a/884758 # TODO: Test this command from https://github.com/gnome-terminator/terminator/blob/master/INSTALL.md#source-install
			fi

			if [[ -L "${app_caution_icon_theme_path}" ]]; then
				zenity_icon_caution_args+=( --icon-name "${APP_NAME_FOR_FILE_PATHS}-caution" ) # https://askubuntu.com/a/1002818
			elif [[ -f "${app_icon_path}" ]]; then
				zenity_icon_caution_args=( "${zenity_icon_args[@]}" )
			fi
		elif [[ -f "${app_icon_path}" ]]; then
			zenity_icon_caution_args=( "${zenity_icon_args[@]}" )
		fi
	fi
	readonly IS_GUI_MODE

	if grep -qF 'FG Eraser Live' /etc/issue && [[ "$(< '/etc/debian_version')" != '13.0' ]]; then
		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} FG Eraser Live is OUTDATED. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"
		send_error_email 'FG Eraser Live is OUTDATED.'

		if $WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE; then
			read -r
		elif $IS_GUI_MODE && can_launch_zenity; then
			zenity --warning --title "${APP_NAME}  ${EM_DASH}  FG Eraser Live Outdated" "${zenity_icon_caution_args[@]}" --no-wrap --text "<big><b>FG Eraser Live is OUTDATED.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>" &> /dev/null
		fi

		exit 205
	fi

	check_and_exit_if_other_instances_running() {
		if ! $cli_list_mode; then
			if $IS_GUI_MODE; then
				if pgrep -f "zenity .+ --title ${APP_NAME} .+" &> /dev/null; then
					# Since this script can be launched in a variety of ways (curled and piped to bash, run locally directly in a Terminal, or launched via icon on the desktop) it would be difficult to detect if an instance is already running in every possible way that wouldn't get false positives from the newly launched instance itself,
					# so instead check for any Zenity window that is open with "APP_NAME" in the title, since some window should be open continuously until an erase or verify process is started (which will be caught separately below).
					>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Only once instance can be run at a time, and another instance is already running.${CLEAR_ANSI}\n"
					# NOTE: DO NOT open a Zenity prompt for this since that would then be detected as another instance and could interrupt the instance that was already running if/when this check is done again in that instance.

					exit 13
				elif pgrep -f "^bash -c .+ ${APP_NAME} .+ /dev/.+ --$" &> /dev/null; then
					>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Cannot start new erasures or verifications until all current processes are finished.${CLEAR_ANSI}\n"

					if can_launch_zenity; then
						zenity --warning --title "${APP_NAME}  ${EM_DASH}  Already Erasing or Verifying Drives" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Cannot start new erasures or verifications until all current processes are finished.</b></big>' &> /dev/null
					fi

					exit 14
				fi
			elif [[ -n "${cli_specified_drive_full_id}" ]] && pgrep -f "^bash -c .+ ${APP_NAME} .+ ${cli_specified_drive_full_id} .*--$" &> /dev/null; then
				>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} An erasure or verification is already running for \"${cli_specified_drive_id}\".${CLEAR_ANSI}\n"

				exit 15
			fi
		fi
	}

	check_and_exit_if_other_instances_running

	if (( ${EUID:-$(id -u)} != 0 )); then
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Must be run as root.${CLEAR_ANSI}\n"

		if can_launch_zenity; then
			zenity --warning --title "${APP_NAME}  ${EM_DASH}  Must Be Run as Root" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Must be run as root.</b></big>' &> /dev/null
		fi

		exit 16
	fi

	actual_eraser_script() {
		cat << 'ACTUAL_ERASER_SCRIPT_EOF'
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
ACTUAL_ERASER_SCRIPT_EOF
	}

	declare -a required_packages=(
		'util-linux' # For "findmnt", "lsblk", and "blkdiscard"
		'curl'
		'unzip'
		'network-manager' # For "nmcli"
		'dmidecode'
		'smartmontools' # For "smartctl"
		'libxml2-utils' # For "xmllint"
		'hdparm'
		'sg3-utils' # For "sg_opcodes" (and "sg_sanitize" used by actual erasing script, not this selection GUI)
		'nvme-cli' # For "nvme"
		'hdsentinel' # Will be checked and installed manually since not available through "apt"
	)

	if ! $cli_list_mode; then
		required_packages+=(
			'e2fsprogs' # For "badblocks" (used by actual erasing script, not this selection GUI)
			'mdadm'
		)

		if $IS_GUI_MODE || [[ "${cli_action_mode}" != 'v' ]]; then
			required_packages+=(
				'nwipe' # (used by actual erasing script, not this selection GUI)
			)
		fi
	fi

	if $IS_GUI_MODE; then
		required_packages+=(
			'terminator'
			'zenity'
		)
	fi

	hdsentinel_needs_install=false
	declare -a required_packages_needing_install=()
	for this_required_package in "${required_packages[@]}"; do
		if [[ "${this_required_package}" == 'hdsentinel' ]]; then
			if [[ ! -f '/usr/bin/hdsentinel' || ! -x '/usr/bin/hdsentinel' ]]; then
				hdsentinel_needs_install=true
			fi
		else
			apt_info_for_this_required_package="$(apt-cache policy "${this_required_package}")"
			if [[ -z "${apt_info_for_this_required_package}" || "${apt_info_for_this_required_package}" == *'Unable to locate package'* ]]; then
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Required \"${this_required_package}\" package NOT FOUND. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"
				send_error_email "Required \"${this_required_package}\" package NOT FOUND."

				if can_launch_zenity; then
					zenity --warning --title "${APP_NAME}  ${EM_DASH}  Required Package Not Found" "${zenity_icon_caution_args[@]}" --no-wrap --text "<big><b>Required \"${this_required_package}\" package NOT FOUND.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>" &> /dev/null
				fi

				exit 30
			elif [[ "${apt_info_for_this_required_package}" == *'Installed: (none)'* ]]; then
				if [[ "${this_required_package}" == 'zenity' ]]; then
					echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Installing Required \"zenity\" Package...${CLEAR_ANSI}\n"
					apt-get update 2> /dev/null
					apt-get install --no-install-recommends -qq "${this_required_package}" # Just install "zenity" right away without any GUI since we can't show a GUI without "zenity".
					if [[ "$(apt-cache policy "${this_required_package}")" == *'Installed: (none)'* ]]; then
						>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to install the required \"zenity\" package.${CLEAR_ANSI}\n\n    ${ANSI_PURPLE}${ANSI_BOLD}NOTE:${ANSI_PURPLE} Manually run \"apt install zenity\" and then run this script again.${CLEAR_ANSI}\n"
						exit 31
					else
						echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Installing Required \"zenity\" Package${CLEAR_ANSI}"
					fi
				else
					required_packages_needing_install+=( "${this_required_package}" )
				fi
			fi
		fi
	done

	if $IS_GUI_MODE && ! echo '' | zenity --progress --title "${APP_NAME}  ${EM_DASH}  Verifying Graphical Environment" "${zenity_icon_args[@]}" --text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Please wait while verifying graphical environment${ELLIPSIS}</b></big>\n" --pulsate --auto-close --no-cancel &> /dev/null; then
		# NOTE: This "zenity" progress window should not actually be seen (it will open and then close immediately), this is just a reliable way checking if in a graphical environment where "zenity" windows can be shown at all.
		# I could have checked if the "DISPLAY" variable is empty or not higher up in the script, which may be enough in most cases, but being certain that "zenity" can actually run from this point on seems important.
		>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Cannot run in GUI mode when OS is not in graphical environment.${CLEAR_ANSI}\n\n  ${ANSI_PURPLE}${ANSI_BOLD}NOTE:${ANSI_PURPLE} See \"-h\" for CLI mode usage (use \"-l\" to list drives, use \"-d [DEVICE ID]\" to erase or verify a drive).${CLEAR_ANSI}\n"
		exit 19
	fi

	check_and_exit_if_other_instances_running

	if $hdsentinel_needs_install || (( ${#required_packages_needing_install[@]} > 0 )); then
		printf -v required_packages_needing_install_display '%s, ' "${required_packages_needing_install[@]}"
		required_packages_needing_install_display="${required_packages_needing_install_display%, }"
		if $hdsentinel_needs_install; then
			if [[ -n "${required_packages_needing_install_display}" ]]; then
				required_packages_needing_install_display+=', '
			fi
			required_packages_needing_install_display+='hdsentinel'
		fi

		install_required_packages() {
			if (( ${#required_packages_needing_install[@]} > 0 )); then
				apt-get update 2> /dev/null
				apt-get install --no-install-recommends -qq "${required_packages_needing_install[@]}"
			fi

			if $hdsentinel_needs_install; then
				rm -rf "${TMPDIR}/hdsentinel-latest-x64.zip" "${TMPDIR}/HDSentinel" {'/usr/local','/usr',''}{'/bin','/sbin'}'/hdsentinel' && \
				curl --connect-timeout 5 -sfL "$(curl -m 5 -sfL 'https://www.hdsentinel.com/hard_disk_sentinel_linux.php' 2> /dev/null | awk -F '"' '/x64.zip/ { print $2; exit }')" -o "${TMPDIR}/hdsentinel-latest-x64.zip" && \
				unzip -o "${TMPDIR}/hdsentinel-latest-x64.zip" -d "${TMPDIR}" && \
				rm "${TMPDIR}/hdsentinel-latest-x64.zip" && \
				mv "${TMPDIR}/HDSentinel" '/usr/bin/hdsentinel' && \
				chmod +x '/usr/bin/hdsentinel'
			fi
		}

		echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Installing Required Packages: ${required_packages_needing_install_display}...${CLEAR_ANSI}"

		if $IS_GUI_MODE; then
			install_required_packages | zenity \
					--progress \
					--title "${APP_NAME}  ${EM_DASH}  Installing Required Packages" \
					"${zenity_icon_args[@]}" \
					--text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Please wait while installing required packages${ELLIPSIS}</b></big>\n\n${required_packages_needing_install_display}\n" \
					--width '600' \
					--pulsate \
					--auto-close \
					--no-cancel &> /dev/null
		else
			echo ''
			install_required_packages
		fi
	fi

	declare -a required_packages_missing=()
	for this_required_package in "${required_packages[@]}"; do
		if [[ "${this_required_package}" == 'hdsentinel' ]]; then
			if [[ ! -f '/usr/bin/hdsentinel' || ! -x '/usr/bin/hdsentinel' ]]; then
				required_packages_missing+=( 'hdsentinel' )
			fi
		elif [[ "$(apt-cache policy "${this_required_package}")" == *'Installed: (none)'* ]]; then
			required_packages_missing+=( "${this_required_package}" )
		fi
	done

	if (( ${#required_packages_missing[@]} > 0 )); then
		printf -v required_packages_missing_display '%s, ' "${required_packages_missing[@]}"
		required_packages_missing_display="${required_packages_missing_display%, }"

		>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Missing required packages (and failed to auto-install): ${required_packages_missing_display}${CLEAR_ANSI}\n"

		if $IS_GUI_MODE; then
			zenity --warning --title "${APP_NAME}  ${EM_DASH}  Missing Required Packages" "${zenity_icon_caution_args[@]}" --no-wrap --text "<big><b>Missing required packages (and failed to auto-install):</b></big>\n\n${required_packages_missing_display}" &> /dev/null
		fi

		exit 32
	elif $hdsentinel_needs_install || (( ${#required_packages_needing_install[@]} > 0 )); then
		echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Installing Required Packages: ${required_packages_needing_install_display}${CLEAR_ANSI}"
	fi

	check_and_exit_if_other_instances_running

	if [[ " ${required_packages[*]} " == *' nwipe '* ]]; then
		min_nwipe_version='0.35' # Require at least "nwipe" verion 0.35 to avoid this crash issue: https://github.com/martijnvanbrummelen/nwipe/issues/488
		nwipe_version="$(nwipe -V 2> /dev/null | tr -dc '0123456789.')"
		if [[ -z "${nwipe_version}" || ( "${nwipe_version}" != "${min_nwipe_version}" && "$(echo -e "${nwipe_version}\n${min_nwipe_version}" | sort -V)" == *$'\n'"${min_nwipe_version}" ) ]]; then
			download_and_build_latest_nwipe() ( # Use subshell function so that cd's only apply to subshell.
				if latest_nwipe_release_json="$(curl -m 5 -sfL 'https://api.github.com/repos/martijnvanbrummelen/nwipe/releases/latest' 2> /dev/null)" && [[ "${latest_nwipe_release_json}" == *'"zipball_url"'* ]]; then
					latest_nwipe_download_url="$(echo "${latest_nwipe_release_json}" | awk -F '"' '($2 == "zipball_url") { print $4; exit }')"
					if [[ -n "${latest_nwipe_download_url}" ]]; then
						apt-get update 2> /dev/null # This may "fail" in a live boot even though it worked, so run it outside of the && chain below.
						# https://github.com/martijnvanbrummelen/nwipe?tab=readme-ov-file#debian--ubuntu-prerequisites
						rm -rf "${TMPDIR}/nwipe-latest-source.zip" "${TMPDIR}/martijnvanbrummelen-nwipe-"* {'/usr/local','/usr',''}{'/bin','/sbin'}'/nwipe' && \
						curl --connect-timeout 5 -sfL "${latest_nwipe_download_url}" -o "${TMPDIR}/nwipe-latest-source.zip" && \
						nwipe_source_folder_name="$(zipinfo -1 "${TMPDIR}/nwipe-latest-source.zip" | head -1)" && \
						unzip -o "${TMPDIR}/nwipe-latest-source.zip" -d "${TMPDIR}" && \
						rm "${TMPDIR}/nwipe-latest-source.zip" && \
						apt-get install --no-install-recommends -qq build-essential pkg-config automake libncurses5-dev autotools-dev libparted-dev libconfig-dev libconfig++-dev dmidecode coreutils smartmontools hdparm && \
						cd "${TMPDIR}/${nwipe_source_folder_name}" && \
						./autogen.sh && \
						./configure && \
						make && \
						make install # https://github.com/martijnvanbrummelen/nwipe?tab=readme-ov-file#compilation

						rm -rf "${TMPDIR}/nwipe-latest-source.zip" "${TMPDIR}/martijnvanbrummelen-nwipe-"*
					fi
				fi
			)

			echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Downloading and Building Latest \"nwipe\"...${CLEAR_ANSI}\n"

			if $IS_GUI_MODE; then
				download_and_build_latest_nwipe & # If the output is piped to Zenity, the install can fail for some reason.
				download_and_build_latest_nwipe_pid="$!" # Wanted to use "wait | zenity --progress ..." but Zenity doesn't seem to work with "wait" and just closed immediately.
				while ps -p "${download_and_build_latest_nwipe_pid}" &> /dev/null; do sleep 3; done | zenity \
					--progress \
					--title "${APP_NAME}  ${EM_DASH}  Downloading and Building Latest \"nwipe\"" \
					"${zenity_icon_args[@]}" \
					--text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Please wait while downloading and building latest <u>nwipe</u>${ELLIPSIS}</b></big>\n" \
					--width '600' \
					--pulsate \
					--auto-close \
					--no-cancel &> /dev/null
			else
				download_and_build_latest_nwipe
			fi

			nwipe_version="$(nwipe -V 2> /dev/null | tr -dc '0123456789.')"
			if [[ -z "${nwipe_version}" || ( "${nwipe_version}" != "${min_nwipe_version}" && "$(echo -e "${nwipe_version}\n${min_nwipe_version}" | sort -V)" == *$'\n'"${min_nwipe_version}" ) ]]; then
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to download or build latest \"nwipe\".${CLEAR_ANSI}\n"

				if $IS_GUI_MODE; then
					zenity --warning --title "${APP_NAME}  ${EM_DASH}  Outdated \"nwipe\"" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Failed to download or build latest <u>nwipe</u>.</b></big>' &> /dev/null
				fi

				exit 33
			else
				echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Downloaded and Built Latest \"nwipe\"${CLEAR_ANSI}"
			fi
		fi
	fi

	check_and_exit_if_other_instances_running

	if [[ " ${required_packages[*]} " == *' terminator '* ]]; then
		# Build the latest "terminator" to include this close tab warning: https://github.com/gnome-terminator/terminator/pull/834
		min_terminator_version='2.1.3' # NOTE: 2.1.3 is latest release version, BUT latest source build that we ACTUALLY need doesn't yet have version updated and would still show 2.1.3, so instead of ONLY checking for a specific version, ALSO check the "man" page for the "ask_before_closing" config key that we require.
		terminator_version="$(terminator -v 2> /dev/null | tr -dc '0123456789.')"
		if [[ -z "${terminator_version}" || ( "${terminator_version}" != "${min_terminator_version}" && "$(echo -e "${terminator_version}\n${min_terminator_version}" | sort -V)" == *$'\n'"${min_terminator_version}" ) ]] ||
			{ ! zgrep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5.gz' 2> /dev/null && ! grep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5' 2> /dev/null; }; then # "apt" installed "terminator" will have compressed "man" page, but manually installed (as done below) will be uncompressed.
			download_and_build_latest_terminator() ( # Use subshell function so that cd's only apply to subshell.
				latest_terminator_source_download_url='https://github.com/gnome-terminator/terminator/archive/refs/heads/master.zip'
				apt-get update 2> /dev/null # This may "fail" in a live boot even though it worked, so run it outside of the && chain below.
				# https://github.com/gnome-terminator/terminator/blob/master/INSTALL.md
				rm -rf "${TMPDIR}/terminator-latest-source.zip" "${TMPDIR}/terminator-master" {'/usr/local','/usr',''}{'/bin','/sbin'}'/terminator' && \
				curl --connect-timeout 5 -sfL "${latest_terminator_source_download_url}" -o "${TMPDIR}/terminator-latest-source.zip" && \
				unzip -o "${TMPDIR}/terminator-latest-source.zip" -d "${TMPDIR}" && \
				rm "${TMPDIR}/terminator-latest-source.zip" && \
				apt-get install --no-install-recommends -qq python3-setuptools python3-gi python3-gi-cairo python3-psutil python3-configobj gir1.2-keybinder-3.0 gir1.2-vte-2.91 gettext intltool dbus-x11 && \
				cd "${TMPDIR}/terminator-master" && \
				python3 setup.py build 2> /dev/null && \
				python3 setup.py install --single-version-externally-managed --record=install-files.txt 2> /dev/null

				rm -rf "${TMPDIR}/terminator-latest-source.zip" "${TMPDIR}/terminator-master"
			)

			echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Downloading and Building Latest \"terminator\"...${CLEAR_ANSI}"

			if $IS_GUI_MODE; then
				download_and_build_latest_terminator | zenity \
					--progress \
					--title "${APP_NAME}  ${EM_DASH}  Downloading and Building Latest \"terminator\"" \
					"${zenity_icon_args[@]}" \
					--text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Please wait while downloading and building latest <u>terminator</u>${ELLIPSIS}</b></big>\n" \
					--width '600' \
					--pulsate \
					--auto-close \
					--no-cancel &> /dev/null
			else
				echo ''
				download_and_build_latest_terminator
			fi

			terminator_version="$(terminator -v 2> /dev/null | tr -dc '0123456789.')"
			if [[ -z "${terminator_version}" || ( "${terminator_version}" != "${min_terminator_version}" && "$(echo -e "${terminator_version}\n${min_terminator_version}" | sort -V)" == *$'\n'"${min_terminator_version}" ) ]] ||
				{ ! zgrep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5.gz' 2> /dev/null && ! grep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5' 2> /dev/null; } then # "apt" installed "terminator" will have compressed "man" page, but manually installed (as done below) will be uncompressed.
				>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to download or build latest \"terminator\".${CLEAR_ANSI}\n"

				if $IS_GUI_MODE; then
					zenity --warning --title "${APP_NAME}  ${EM_DASH}  Outdated \"terminator\"" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Failed to download or build latest <u>terminator</u>.</b></big>' &> /dev/null
				fi

				exit 34
			else
				echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Downloaded and Built Latest \"terminator\"${CLEAR_ANSI}"
			fi
		fi
	fi

	rm -rf "${HOME}/.config/terminator" # Delete any USER config for "terminator" to only use the GLOBAL config set below.
	if [[ ! -f '/etc/xdg/terminator/config' ]]; then
		mkdir -p '/etc/xdg/terminator'
		echo '[global_config]
  ask_before_closing = always
[profiles]
  [[default]]
    scrollback_infinite = True' > '/etc/xdg/terminator/config'
	fi

	check_and_exit_if_other_instances_running

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

	if $IS_GUI_MODE || $cli_list_mode || $cli_auto_mode; then
		if [[ -t 1 ]]; then # ONLY "clear" and re-display app title if stdout IS associated with an interactive terminal.
			clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
			echo -e "${APP_DISPLAY_TITLE}"
		fi

		if $IS_GUI_MODE; then
			if $cli_quick_mode; then
				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-q\" is IGNORED without \"-d\" option specified.${CLEAR_ANSI}"
			fi

			if [[ -n "${cli_action_mode}" ]]; then
				for this_cli_action_mode_override_notice in "${cli_action_mode_override_notices[@]}"; do
					>&2 echo -e "${this_cli_action_mode_override_notice}"
				done

				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-${cli_action_mode}\" is IGNORED without \"-d\" option specified, will prompt to verify or erase in GUI and default erase method will be used.${CLEAR_ANSI}"
			fi

			echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Running in GUI mode...${CLEAR_ANSI}\n"
		elif $cli_list_mode; then
			if [[ -n "${technician_initials}" ]]; then
				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-i\" is IGNORED when \"-l\" or \"-L\" (CLI list output) is specified.${CLEAR_ANSI}"
			fi

			if [[ -n "${lot_code}" ]]; then
				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-c\" is IGNORED when \"-l\" or \"-L\" (CLI list output) is specified.${CLEAR_ANSI}"
			fi

			if $cli_auto_mode || [[ -n "${cli_specified_drive_full_id}" ]]; then
				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-d\" is IGNORED when \"-l\" or \"-L\" (CLI list output) is specified.${CLEAR_ANSI}"
			fi

			if $force_override_health_checks; then
				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-f\" is IGNORED when \"-l\" or \"-L\" (CLI list output) is specified.${CLEAR_ANSI}"
				force_override_health_checks=false
			fi

			if $cli_quick_mode; then
				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-q\" is IGNORED when \"-l\" or \"-L\" (CLI list output) is specified.${CLEAR_ANSI}"
			fi

			if [[ -n "${cli_action_mode}" ]]; then
				for this_cli_action_mode_override_notice in "${cli_action_mode_override_notices[@]}"; do
					>&2 echo -e "${this_cli_action_mode_override_notice}"
				done

				>&2 echo -e "\n  ${ANSI_YELLOW}${ANSI_BOLD}NOTICE:${ANSI_YELLOW} CLI option \"-${cli_action_mode}\" is IGNORED when \"-l\" or \"-L\" (CLI list output) is specified.${CLEAR_ANSI}"
			fi
		elif $cli_auto_mode; then
			echo -e "\n\n  ${ANSI_CYAN}${ANSI_BOLD}Running in ${ANSI_UNDERLINE}AUTOMATIC DRIVE SELECTION MODE${ANSI_CYAN}${ANSI_BOLD}...${CLEAR_ANSI}"
		fi

		readonly LSBLK_DISKS_LATEST_OUTPUT_PATH="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-lsblk-disks-latest.txt"
		readonly LSBLK_DISKS_LOADED_OUTPUT_PATH="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-lsblk-disks-loaded.txt"
		readonly HDSENTINEL_OUTPUT_PATH_PREFIX="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-hdsentinel-"
		readonly SMARTCTL_OUTPUT_PATH_PREFIX="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-smartctl-"
		readonly NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-nvme_id_ctrl-"
		readonly HDPARM_OUTPUT_PATH_PREFIX="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-hdparm-"
		readonly SG_OPCODES_OUTPUT_PATH_PREFIX="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-sg_opcodes-"

		declare -a did_sleep_to_unfreeze_drives_array=()
		cli_auto_mode_drive_full_id=''

		is_erase_mode=false
		is_verify_mode=false

		readonly LINE='\xE2\x94\x80' # https://www.compart.com/en/unicode/U+2500

		rm -rf "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" "${HDSENTINEL_OUTPUT_PATH_PREFIX}"* "${SMARTCTL_OUTPUT_PATH_PREFIX}"* "${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}"* "${HDPARM_OUTPUT_PATH_PREFIX}"* "${SG_OPCODES_OUTPUT_PATH_PREFIX}"*

		if $IS_GUI_MODE; then
			{
				touch "${LSBLK_DISKS_LATEST_OUTPUT_PATH}"
				while [[ -f "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" ]]; do
					while read -r mounted_device_id _; do
						if [[ "${mounted_device_id}" == '/dev/sd'* || "${mounted_device_id}" == '/dev/nvme'* || "${mounted_device_id}" == '/dev/mmcblk'* ]]; then
							mounted_device_id_parent="${mounted_device_id}"
							if [[ "${mounted_device_id_parent}" == '/dev/sd'*[0123456789]* ]]; then
								mounted_device_id_parent="${mounted_device_id_parent%%[0123456789]*}"
							elif [[ "${mounted_device_id_parent}" == '/dev/nvme'*'p'* || "${mounted_device_id_parent}" == '/dev/mmcblk'*'p'* ]]; then
								mounted_device_id_parent="${mounted_device_id_parent%%p*}"
							fi

							if [[ "${mounted_device_id_parent}" != "${boot_device_drive_id}" ]]; then
								while IFS='' read -r this_mount_point; do # "findmnt" could output multiple mount points separated by newlines for any given device ID.
									# >&2 echo "DEBUG: Unmounting \"${this_mount_point}\" (of \"${mounted_device_id}\")" # DEBUG
									umount -f "${this_mount_point}"
								done < <(findmnt -no 'TARGET' "${mounted_device_id}") # NOTE: NOT getting mount point from "/proc/mounts" since it's hard to parse if there is a space in the mount point path.
							# else
							# 	>&2 echo "DEBUG: NOT Unmounting \"${mounted_device_id}\" BECAUSE child of boot device \"${boot_device_drive_id}\"" # DEBUG
							fi
						fi
					done < '/proc/mounts'

					while read -r raid_device_id _; do
						if [[ "${raid_device_id}" == 'md'* ]]; then
							# >&2 echo "DEBUG: Stopping RAID device \"${raid_device_id}\"" # DEBUG
							mdadm -S "/dev/${raid_device_id}" &> /dev/null # TODO: Explain (for keeping things tidy and maybe also to keep device listings in order?)
						fi
					done < '/proc/mdstat'

					if [[ -s "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" ]]; then
						timeout -s SIGKILL 10 lsblk -abdPpo 'NAME,SIZE,TRAN,ROTA,TYPE,RO,SERIAL,VENDOR,MODEL' -x 'NAME' | grep ' TYPE="disk" ' > "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" 2> /dev/null

						if ! cmp -s "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" "${LSBLK_DISKS_LOADED_OUTPUT_PATH}"; then
							pkill -SIGUSR2 -f "zenity .+ --title ${APP_NAME} \(Version ${APP_VERSION}\) .+ --text .+ reload automatically when drive changes are detected${ELLIPSIS}"
						fi
					fi

					sleep 3
				done
			} &
		fi

		load_drive_info() {
			timeout -s SIGKILL 10 lsblk -abdPpo 'NAME,SIZE,TRAN,ROTA,TYPE,RO,SERIAL,VENDOR,MODEL' -x 'NAME' | grep ' TYPE="disk" ' > "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" 2> /dev/null

			rm -rf "${HDSENTINEL_OUTPUT_PATH_PREFIX}"* "${SMARTCTL_OUTPUT_PATH_PREFIX}"* "${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}"* "${HDPARM_OUTPUT_PATH_PREFIX}"* "${SG_OPCODES_OUTPUT_PATH_PREFIX}"*

			this_drive_index=0
			lsblk_drive_count="$(wc -l "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" | awk '{ print $1; exit }')"

			if (( lsblk_drive_count > 0 )); then
				# The following loop DUPLICATES some code that is done below, but it's better to put ALL of the commands that could hang with funky/bad drives and need a timeout here
				# so that progress is shown during the delay, and then only the files are read rather loading the commands outside this progress function than hanging when no progress is shown.

				while IFS='"' read -r _ this_drive_full_id _ this_drive_size_bytes _ this_drive_transport _ this_drive_rota _; do
					if $IS_GUI_MODE; then
						(( this_drive_index ++ ))

						if (( this_drive_index == 1 )); then
							echo 'pulsate:false'
						fi

						progress_percentage="$(echo "(${this_drive_index} / ${lsblk_drive_count}) * 100" | bc -l)" # Output completion percentage for "zenity --progress"

						if [[ "${progress_percentage}" == '100.0'* ]]; then # DO NOT want progress window to close (which will happen when "100" is outputted) until final iteration is actually done, so change number to 99.999...
							progress_percentage="${progress_percentage#1}"
							progress_percentage="${progress_percentage//0/9}"
						fi

						echo "${progress_percentage}"
					fi

					if [[ -n "${this_drive_size_bytes}" && "${this_drive_full_id}" == '/dev/sd'* || "${this_drive_full_id}" == '/dev/nvme'*'n'* || "${this_drive_full_id}" == '/dev/mmcblk'* ]]; then
						this_drive_id="${this_drive_full_id##*/}"

						timeout -s SIGKILL 3 hdsentinel -dev "${this_drive_full_id}" -xml -r "${HDSENTINEL_OUTPUT_PATH_PREFIX}${this_drive_id}.xml" &> /dev/null
						# NOTE: Loading "hdsentinel" INDIVIDUALLY for each drive it more reliable because if one drive is bad/flakey and causes "hdsentinel" to hang then only that drive doesn't show health data rather than no health data getting loaded for any drives.


						smartctl_output_path_for_this_drive="${SMARTCTL_OUTPUT_PATH_PREFIX}${this_drive_id}.json"
						if [[ "${this_drive_transport}" == 'usb' ]]; then
							timeout -s SIGKILL 3 smartctl --json=g -i "${this_drive_full_id}" > "${smartctl_output_path_for_this_drive}" 2> /dev/null
						fi

						if [[ "${this_drive_full_id}" == '/dev/nvme'* ]]; then
							timeout -s SIGKILL 3 nvme id-ctrl -H "${this_drive_full_id}" > "${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}${this_drive_id}.txt" 2> /dev/null
						else
							this_drive_is_ssd="$( (( this_drive_rota )) && echo 'false' || echo 'true' )"

							# "ROTA" from "lsblk" can be INCORRECT from some SSDs in external enclosures, so double-check it with "smartctl" which should be correct.
							if ! $this_drive_is_ssd && [[ "${this_drive_transport}" == 'usb' && -s "${smartctl_output_path_for_this_drive}" ]] && grep -qxF 'json.rotation_rate = 0;' "${smartctl_output_path_for_this_drive}"; then
								this_drive_is_ssd=true
							fi

							if $this_drive_is_ssd; then
								hdparm_output_path_for_this_drive="${HDPARM_OUTPUT_PATH_PREFIX}${this_drive_id}.txt"
								timeout -s SIGKILL 3 hdparm -I "${this_drive_full_id}" > "${hdparm_output_path_for_this_drive}" 2> /dev/null

								if [[ "${this_drive_transport}" == 'sas' ]] && ! grep -qF 'SECURITY ERASE UNIT' "${hdparm_output_path_for_this_drive}"; then
									timeout -s SIGKILL 3 sg_opcodes "${this_drive_full_id}" > "${SG_OPCODES_OUTPUT_PATH_PREFIX}${this_drive_id}.txt" 2> /dev/null
								fi
							fi
						fi
					fi
				done < "${LSBLK_DISKS_LOADED_OUTPUT_PATH}"
			fi
		}

		while true; do
			check_and_exit_if_other_instances_running

			# $IS_GUI_MODE && declare -p did_sleep_to_unfreeze_drives_array # DEBUG

			if $IS_GUI_MODE; then
				load_drive_info | zenity \
					--progress \
					--title "${APP_NAME} (Version ${APP_VERSION})  ${EM_DASH}  Loading Drive Info" \
					"${zenity_icon_args[@]}" \
					--text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Please wait while loading drive info${ELLIPSIS}</b></big>\n" \
					--width '600' \
					--pulsate \
					--auto-close \
					--no-cancel &> /dev/null
			else
				echo -e "\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Loading Drive Info...${CLEAR_ANSI}"
				load_drive_info
			fi

			drives_list_index=0
			detected_failed_health_drives=false
			declare -a drives_array=()
			declare -a frozen_drives_array=()

			declare -a nvme_character_devices=()
			declare -a nvme_drives_with_multiple_namespaces=()

			while IFS='"' read -r _ this_drive_full_id _ this_drive_size_bytes _ this_drive_transport _ this_drive_rota _ _ _ this_drive_read_only _ this_drive_serial _ this_drive_brand _ this_drive_model; do
				# Split lines on double quotes (") to easily extract each value out of each "lsblk" line, which will be like: NAME="/dev/sda" SIZE="1234567890" TRAN="sata" ROTA="0" TYPE="disk" RO="0" SERIAL="ABC123" VENDOR="Some Brand" MODEL="Some Model Name"
				# Use "_" to ignore field titles that we don't need. See more about "read" usages with IFS and skipping values at https://mywiki.wooledge.org/BashFAQ/001#Field_splitting.2C_whitespace_trimming.2C_and_other_input_processing
				# NOTE: I don't believe the model name should ever contain double quotes ("), but if somehow it does having it as the last variable set by "read" means any of the remaining double quotes will not be split on and would be included in the value (and no other values could contain double quotes).

				if [[ -n "${this_drive_size_bytes}" && "${this_drive_full_id}" == '/dev/sd'* || "${this_drive_full_id}" == '/dev/nvme'*'n'* || "${this_drive_full_id}" == '/dev/mmcblk'* ]]; then
					this_drive_id="${this_drive_full_id##*/}"

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

					this_drive_is_ssd="$( (( this_drive_rota )) && echo 'false' || echo 'true' )"

					smartctl_output_path_for_this_drive="${SMARTCTL_OUTPUT_PATH_PREFIX}${this_drive_id}.json"

					if [[ "${this_drive_transport}" == 'usb' && -s "${smartctl_output_path_for_this_drive}" ]]; then
						# NOTE: "smartctl" can retrieve actual drive info from *some* USB adapaters, while "lsblk" will just show the model and serial of the adapter itself.

						smartctl_info_model_name="$(awk -F ' = "' '($1 == "json.model_name") { print $NF }' "${smartctl_output_path_for_this_drive}")"
						smartctl_info_model_name="${smartctl_info_model_name%\";}"
						smartctl_info_model_name="${smartctl_info_model_name//\\\"/\"}"
						if [[ -n "${smartctl_info_model_name}" && "${smartctl_info_model_name}" != "${this_drive_model}" ]]; then
							this_drive_model="${smartctl_info_model_name}"
						fi

						smartctl_info_serial_number="$(awk -F ' = "' '($1 == "json.serial_number") { print $NF }' "${smartctl_output_path_for_this_drive}")"
						smartctl_info_serial_number="${smartctl_info_serial_number%\";}"
						smartctl_info_serial_number="${smartctl_info_serial_number//\\\"/\"}"
						if [[ -n "${smartctl_info_serial_number}" && "${smartctl_info_serial_number}" != "${this_drive_serial}" ]]; then
							this_drive_serial="${smartctl_info_serial_number}"
						fi

						# "ROTA" from "lsblk" can be INCORRECT from some SSDs in external enclosures, so double-check it with "smartctl" which should be correct.
						if ! $this_drive_is_ssd && grep -qxF 'json.rotation_rate = 0;' "${smartctl_output_path_for_this_drive}"; then
							this_drive_is_ssd=true
						fi
					fi

					rm -rf "${smartctl_output_path_for_this_drive}"

					if [[ "${this_drive_full_id}" == '/dev/nvme'*'n'* ]]; then
						# For NVMe drives, "this_drive_full_id" from "lsblk" will include the namespace, like the "n1" suffix in "/dev/nvme0n1".
						# But HD Sentinel will list the NVMe character device without the namespace, so remove it to be able to select the device from the HD Sentinel output.
						this_drive_full_id_without_nvme_namespace_included="${this_drive_full_id%n*}"

						# ALSO, check for any NVMe drives that contain MULTIPLE namespaces, which we don't want to send out for reuse since that would be weird/confusing for our customers.
						if [[ "${this_drive_model}" != 'APPLE SSD AP'* ]]; then # TODO: Explain Apple NVMe exception.
							if [[ " ${nvme_character_devices[*]} " != *" ${this_drive_full_id_without_nvme_namespace_included} "* ]]; then
								nvme_character_devices+=( "${this_drive_full_id_without_nvme_namespace_included}" )
							elif [[ " ${nvme_drives_with_multiple_namespaces[*]} " != *" ${this_drive_full_id_without_nvme_namespace_included} "* ]]; then
								nvme_drives_with_multiple_namespaces+=( "${this_drive_full_id_without_nvme_namespace_included}" )
							fi
						fi
					fi

					this_drive_kind="$($this_drive_is_ssd && echo 'SSD' || echo 'HDD')"
					if [[ "${this_drive_transport}" == 'mmc' || "${this_drive_full_id}" == '/dev/mmcblk'* ]]; then
						mmc_type="$(udevadm info --query 'property' --property 'MMC_TYPE' --value -p "/sys/class/block/${this_drive_id}" 2> /dev/null)"
						if [[ "${mmc_type}" == 'MMC' || ( -z "${mmc_type}" && "$(udevadm info --query 'symlink' -p "/sys/class/block/${this_drive_id}" 2> /dev/null)" != *'/by-id/mmc-USD_'* ) ]]; then
							# eMMC should have "MMC_TYPE" of "MMC" rather than "SD".
							# Or, if "MMC_TYPE" doesn't exist (on older versions of "udevadm"?), eMMC should have some UDEV ID starting with other than "USD_" which would indicate an actual Memory Card.
							this_drive_kind='eMMC'
						else
							this_drive_kind='Memory Card'
						fi
					elif [[ -n "${this_drive_transport}" ]]; then
						this_drive_kind="${this_drive_transport^^[^e]} ${this_drive_kind}"
					fi

					this_drive_health='UNKNOWN'
					declare -a hdsentinel_failed_attributes=()

					hdsentinel_output_path_for_this_drive="${HDSENTINEL_OUTPUT_PATH_PREFIX}${this_drive_id}.xml"

					if [[ -s "${hdsentinel_output_path_for_this_drive}" ]]; then
						hdsentinel_power_on_time="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Power_on_time)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
						if [[ -n "${hdsentinel_power_on_time}" && "${hdsentinel_power_on_time}" == *' days'* && "${hdsentinel_power_on_time%% *}" -ge 2500 ]]; then
							hdsentinel_failed_attributes+=( 'Power On Time' )
						fi

						hdsentinel_estimated_lifetime="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Estimated_remaining_lifetime)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
						if [[ -n "${hdsentinel_estimated_lifetime}" && ( "${hdsentinel_estimated_lifetime}" != *' days'* || "${hdsentinel_estimated_lifetime//[^0123456789]/}" -lt 400 ) ]]; then
							hdsentinel_failed_attributes+=( 'Estimated Lifetime' )
						fi

						hdsentinel_description="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Description)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
						if [[ -n "${hdsentinel_description}" && "${hdsentinel_description}" != *'is PERFECT.'* ]]; then
							hdsentinel_failed_attributes+=( 'Description' )
						fi

						hdsentinel_tip="$(xmllint --xpath "string(//Hard_Disk_Device[text()='${this_drive_full_id}']/../Tip)" "${hdsentinel_output_path_for_this_drive}" 2> /dev/null)"
						if [[ -n "${hdsentinel_tip}" && "${hdsentinel_tip}" != 'No actions needed.' ]]; then
							hdsentinel_failed_attributes+=( 'Tip' )
						fi

						if (( ${#hdsentinel_failed_attributes[@]} == 0 )); then
							if [[ -n "${hdsentinel_power_on_time}" || -n "${hdsentinel_estimated_lifetime}" || -n "${hdsentinel_description}" || -n "${hdsentinel_tip}" ]]; then
								this_drive_health='Pass'
							fi
						else
							this_drive_health='FAIL'
							detected_failed_health_drives=true
						fi
					fi

					rm -rf "${hdsentinel_output_path_for_this_drive}"

					note='Ready to Verify or Erase'
					if $is_verify_mode; then
						note='Ready to Verify'
					elif $is_erase_mode; then
						note='Ready to Erase'
					fi

					if [[ "${this_drive_full_id}" == "${boot_device_drive_id}" ]]; then
						note='Boot Drive'
					elif (( this_drive_size_bytes == 0 )); then
						note='0 Byte Drive'
					elif (( this_drive_read_only != 0 )); then
						note='Read Only Drive'
					elif [[ "${this_drive_health}" == 'FAIL' ]]; then
						printf -v hdsentinel_failed_attributes_display '%s, ' "${hdsentinel_failed_attributes[@]}"
						failed_health_note="Health Check Failed for ${hdsentinel_failed_attributes_display%, }"

						if $force_override_health_checks; then
							note+=" - OVERRIDDEN ${failed_health_note}"
						else
							note="${failed_health_note}"
						fi
					fi

					if $cli_list_mode || [[ "${note}" == 'Ready '* ]]; then # Only show Secure Erase compatibility if drive can be erased, or if in CLI list mode.
						if [[ "${this_drive_full_id}" == '/dev/nvme'* ]]; then
							nvme_id_ctrl_info_output_path_for_this_drive="${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}${this_drive_id}.txt"

							if [[ -s "${nvme_id_ctrl_info_output_path_for_this_drive}" ]] && grep -q 'Format NVM Supported$' "${nvme_id_ctrl_info_output_path_for_this_drive}"; then
								# TODO: Explain FAKE frozen check to force sleep once for each NVMe drive: https://github.com/linux-nvme/nvme-cli/issues/627#issuecomment-569685237 & https://github.com/linux-nvme/nvme-cli/issues/816#issuecomment-834586681
								if ! $is_erase_mode || $is_apple_mac || [[ " ${did_sleep_to_unfreeze_drives_array[*]} " == *" ${this_drive_full_id} "* ]]; then # TODO: Test adding more drive that need to be unfrozen
									note+=' ("Format NVM" Supported)'
								else
									note='FROZEN (Must Sleep and Wake to Unfreeze for "Format NVM")'
									frozen_drives_array+=( "${this_drive_full_id}" )
								fi
							fi

							rm -rf "${nvme_id_ctrl_info_output_path_for_this_drive}"
						elif $this_drive_is_ssd; then
							hdparm_output_path_for_this_drive="${HDPARM_OUTPUT_PATH_PREFIX}${this_drive_id}.txt"
							sg_opcodes_output_path_for_this_drive="${SG_OPCODES_OUTPUT_PATH_PREFIX}${this_drive_id}.txt"

							if [[ -s "${hdparm_output_path_for_this_drive}" ]] && grep -qF 'SECURITY ERASE UNIT' "${hdparm_output_path_for_this_drive}"; then
								if $is_erase_mode && ! grep -qxF $'\tnot\tfrozen' "${hdparm_output_path_for_this_drive}"; then # https://archive.kernel.org/oldwiki/ata.wiki.kernel.org/index.php/ATA_Secure_Erase.html#Step_1_-_Make_sure_the_drive_Security_is_not_frozen:
									if $is_apple_mac || [[ " ${did_sleep_to_unfreeze_drives_array[*]} " == *" ${this_drive_full_id} "* ]]; then # TODO: Test adding more drive that need to be unfrozen
										note+=' (CANNOT Unfreeze for "ATA Secure Erase")'
									else
										note='FROZEN (Must Sleep and Wake to Unfreeze for "ATA Secure Erase")'
										frozen_drives_array+=( "${this_drive_full_id}" )
									fi
								else
									note+=' ("ATA Secure Erase" Supported)' # NOTE: Never runnning ENHANCED Secure Erase, so not checking for it: $(grep -qF 'ENHANCED SECURITY ERASE UNIT' "${hdparm_output_path_for_this_drive}" && echo 'Enhanced ')
								fi
							elif [[ "${this_drive_transport}" == 'sas' && -s "${sg_opcodes_output_path_for_this_drive}" ]] && grep -q 'Sanitize, block erase$' "${sg_opcodes_output_path_for_this_drive}"; then
								# TODO: Explain only using sg_opcodes check with may not always be accurate. See NOTES in https://docs.oracle.com/cd/E88353_01/html/E72487/sg-sanitize-8.html
								# TODO: Explain checking for "ATA Secure Erase" FIRST even if SAS SSD (because wiping stations support SAS and show regular SATA drives as SAS even if they can support ATA Secure Erase)
								note+=' ("SCSI Sanitize" Supported)'
							fi

							rm -rf "${hdparm_output_path_for_this_drive}" "${sg_opcodes_output_path_for_this_drive}"
						fi
					fi

					if $cli_list_mode || { [[ "${this_drive_full_id}" != "${boot_device_drive_id}" ]] && (( this_drive_size_bytes != 0 )); }; then # Do not show boot drive or 0 byte drives (which can appear from some USB hubs when no drive is actually connected) in GUI, only show them in CLI list mode for debugging and completeness.
						(( drives_list_index ++ ))

						min_drive_size_bytes="$($this_drive_is_ssd && echo '100000000000' || echo '1000000000000')" # 100 GB min size for SSD, 1 TB min size for HDD.
						is_small_drive="$( (( this_drive_size_bytes < min_drive_size_bytes )) && echo 'true' || echo 'false' )"

						if $IS_GUI_MODE; then
							drives_array+=(
								"$([[ "${note}" == 'Ready '* ]] && echo 'TRUE' || echo 'FALSE')"
								"${this_drive_full_id}"
								"${drives_list_index}"
								"${this_drive_id}"
								"${this_drive_health}"
								"$(human_readable_size_from_bytes "${this_drive_size_bytes}")$($is_small_drive && echo " (BELOW $(human_readable_size_from_bytes "${min_drive_size_bytes}"))")"
								"${this_drive_kind}"
								"${this_drive_model:-UNKNOWN Drive Model}"
								"${this_drive_serial:-UNKNOWN Drive Serial}"
								"${note}"
							)
						else
							if (( drives_list_index > 1 )); then
								echo -e "\n  ${LINE}${LINE}${LINE}${LINE}${LINE}${LINE}${LINE}${LINE}${LINE}${LINE}${LINE}"
							fi

							drive_health_color="${ANSI_GREEN}"
							if [[ "${this_drive_health}" == 'FAIL' ]]; then
								drive_health_color="${ANSI_RED}"
							elif [[ "${this_drive_health}" == 'UNKNOWN' ]]; then
								drive_health_color="${ANSI_YELLOW}"
							fi

							drive_size_color="$($is_small_drive && echo "${ANSI_YELLOW}" || echo "${CLEAR_ANSI}")"

							note_color="${CLEAR_ANSI}"
							if [[ "${note}" == 'Ready '* ]]; then
								cli_auto_mode_drive_full_id="${this_drive_full_id}" # This will only be used when there is only 1 drive.

								if [[ "${note}" == *'OVERRIDDEN Health Check Failed'* ]]; then
									note_color="${ANSI_YELLOW}"
								fi
							elif [[ "${note}" == 'Health Check Failed'* ]]; then
								note_color="${ANSI_RED}"
							elif [[ "${note}" == 'Boot Drive'* || "${note}" == '0 Byte Drive'* || "${note}" == 'Read Only Drive'* ]]; then
								note_color="${ANSI_YELLOW}"
							fi

							echo -e "
    ${ANSI_BOLD}Drive ID:${CLEAR_ANSI} ${this_drive_id}
      ${drive_health_color}${ANSI_BOLD}Health:${drive_health_color} ${this_drive_health}${CLEAR_ANSI}
        ${drive_size_color}${ANSI_BOLD}Size:${drive_size_color} $(human_readable_size_from_bytes "${this_drive_size_bytes}")$($is_small_drive && echo " ${ANSI_BOLD}(BELOW $(human_readable_size_from_bytes "${min_drive_size_bytes}"))")${CLEAR_ANSI}
        ${ANSI_BOLD}Kind:${CLEAR_ANSI} ${this_drive_kind}
       ${ANSI_BOLD}Model:${CLEAR_ANSI} ${this_drive_model:-UNKNOWN Drive Model}
      ${ANSI_BOLD}Serial:${CLEAR_ANSI} ${this_drive_serial:-UNKNOWN Drive Serial}
        ${note_color}${ANSI_BOLD}Note:${note_color} ${note}${CLEAR_ANSI}"
						fi
					fi
				fi
			done < "${LSBLK_DISKS_LOADED_OUTPUT_PATH}"

			if ! $IS_GUI_MODE; then
				echo -e ''
			fi

			nvme_drives_with_multiple_namespaces_count="${#nvme_drives_with_multiple_namespaces[@]}"
			if (( nvme_drives_with_multiple_namespaces_count > 0 )); then
				printf -v nvme_drives_with_multiple_namespaces_display '%s, ' "${nvme_drives_with_multiple_namespaces[@]}"
				nvme_drives_with_multiple_namespaces_display="${nvme_drives_with_multiple_namespaces_display%, }"
				nvme_drives_with_multiple_namespaces_display="${nvme_drives_with_multiple_namespaces_display//\/dev\//}"

				>&2 echo -e "
  ${ANSI_RED}${ANSI_BOLD}!!!${ANSI_YELLOW}${ANSI_BOLD} NVMe DETECTED WITH MULTIPLE NAMESPACES ${ANSI_RED}${ANSI_BOLD}!!!${CLEAR_ANSI}
  ${ANSI_RED}${ANSI_BOLD}The following ${nvme_drives_with_multiple_namespaces_count} NVMe drive$( (( nvme_drives_with_multiple_namespaces_count > 1 )) && echo 's' ) ${ANSI_UNDERLINE}$( (( nvme_drives_with_multiple_namespaces_count > 1 )) && echo 'HAVE' || echo 'HAS' ) MULTIPLE NAMESPACES${ANSI_RED}${ANSI_BOLD}:${ANSI_RED} ${nvme_drives_with_multiple_namespaces_display}${CLEAR_ANSI}
  ${ANSI_PURPLE}${ANSI_BOLD}NVMe drives with multiple namespaces CANNOT be sent to reuse.${CLEAR_ANSI}
  ${ANSI_CYAN}${ANSI_BOLD}IMPORTANT: Please write ${ANSI_UNDERLINE}NS ERROR${ANSI_CYAN}${ANSI_BOLD} on a piece of tape stuck to this drive or device and then place it in the box marked ${ANSI_UNDERLINE}${APP_NAME} ISSUES${ANSI_CYAN}${ANSI_BOLD} and ${ANSI_UNDERLINE}inform Free Geek I.T.${ANSI_CYAN}${ANSI_BOLD} for further research.${CLEAR_ANSI}
"

				send_error_email "Detected NVMe With Multiple Namespaces: ${nvme_drives_with_multiple_namespaces_display}"

				if $IS_GUI_MODE; then
					if ! zenity --question --title "${APP_NAME}  ${EM_DASH}  NVMe Detected With Multiple Namespaces" "${zenity_icon_caution_args[@]}" --ok-label 'Reload' --cancel-label 'Quit' --no-wrap --text "<big><b>The following ${nvme_drives_with_multiple_namespaces_count} NVMe drive$( (( nvme_drives_with_multiple_namespaces_count > 1 )) && echo 's' ) <u>$( (( nvme_drives_with_multiple_namespaces_count > 1 )) && echo 'HAVE' || echo 'HAS' ) MULTIPLE NAMESPACES</u>: <i>${nvme_drives_with_multiple_namespaces_display}</i></b></big>\n\nNVMe drives with multiple namespaces CANNOT be sent to reuse.\n\n<i>Please write <u>NS ERROR</u> on a piece of tape stuck to this drive or device and then place\nit in the box marked <u>${APP_NAME} ISSUES</u> and <u>inform Free Geek I.T.</u> for further research.</i>" &> /dev/null; then
						exit 41
					fi
				else
					echo ''
					exit 42
				fi
			elif ! $IS_GUI_MODE; then
				live_boot_auto_mode_exit_menu() {
					if $WAS_LAUNCHED_FROM_LIVE_BOOT_AUTO_MODE; then
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
				}

				if (( drives_list_index == 0 )); then
					echo -e "    ${ANSI_YELLOW}${ANSI_BOLD}No Drives Detected${CLEAR_ANSI}\n"

					if $cli_auto_mode; then
						>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} No drive detected, can only proceed with ${ANSI_BOLD}AUTOMATIC DRIVE SELECTION MODE${ANSI_RED} when ${ANSI_UNDERLINE}ONE DRIVE${ANSI_RED} is detected.${CLEAR_ANSI}\n"
						live_boot_auto_mode_exit_menu
						exit 40 # TODO: Should this be an different exit code when auto-mode is enabled?
					elif ! $cli_list_auto_reload_mode; then
						echo ''
						exit 40
					fi
				fi

				if $cli_list_mode; then
					echo ''

					if $cli_list_auto_reload_mode; then
						echo -e "  ${ANSI_PURPLE}${ANSI_BOLD}Running in ${ANSI_BOLD}AUTOMATIC LIST RELOAD MODE${ANSI_PURPLE}${ANSI_BOLD}, will reload in 10 seconds...${CLEAR_ANSI}\n  ${ANSI_CYAN}Press ${ANSI_BOLD}CONTROL + C${ANSI_CYAN} to ${ANSI_UNDERLINE}EXIT${ANSI_CYAN}, or press ${ANSI_BOLD}ENTER${ANSI_CYAN} to ${ANSI_UNDERLINE}RELOAD NOW${ANSI_CYAN}...${CLEAR_ANSI}"
						read -rt 10

						if [[ -t 1 ]]; then # ONLY "clear" and re-display app title if stdout IS associated with an interactive terminal.
							clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
							echo -e "${APP_DISPLAY_TITLE}"
						fi
					else
						exit 0
					fi
				elif (( drives_list_index > 1 )); then
					>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} ${drives_list_index} drives detected, can only proceed with ${ANSI_BOLD}AUTOMATIC DRIVE SELECTION MODE${ANSI_RED} when ${ANSI_UNDERLINE}ONE DRIVE${ANSI_RED} is detected.${CLEAR_ANSI}\n"
					live_boot_auto_mode_exit_menu
					exit 25 # TODO: Should this be an Argument Error or a Drive Detection Error or a Drive Selection Error?
				elif [[ -z "${cli_auto_mode_drive_full_id}" ]]; then
					>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} No healthy drive detected, can only proceed with ${ANSI_BOLD}AUTOMATIC DRIVE SELECTION MODE${ANSI_RED} when ${ANSI_UNDERLINE}ONE HEALTHY DRIVE${ANSI_RED} is detected.${CLEAR_ANSI}\n"
					live_boot_auto_mode_exit_menu
					exit 26 # TODO: Should this be an Argument Error or a Drive Detection Error or a Drive Selection Error?
				else
					cli_specified_drive_full_id="${cli_auto_mode_drive_full_id}"

					>&2 echo -e "\n  ${ANSI_PURPLE}${ANSI_BOLD}Setting \"${cli_specified_drive_full_id}\" for ${ANSI_BOLD}AUTOMATIC DRIVE SELECTION MODE${ANSI_PURPLE}${ANSI_BOLD}...${CLEAR_ANSI}"

					check_and_exit_if_other_instances_running

					if ! $cli_quick_mode; then
						read -rt 3 # Sleep a bit to show the drive list and auto-mode selection before clearing screen for actual erasure.
					fi

					break
				fi
			else
				check_and_exit_if_other_instances_running

				drives_array_count="${#drives_array[@]}"
				frozen_drives_array_count="${#frozen_drives_array[@]}"

				if (( drives_array_count > 0 && (drives_array_count % 10) == 0 )); then
					detected_drives_count="$(( drives_array_count / 10 ))"

					declare -a zenity_base_list_options=(
						--list
						"${zenity_icon_args[@]}"
						--width '1200'
						--height '600'
						--column 'Full ID'
						--column '#'
						--column 'ID'
						--column 'Health'
						--column 'Size'
						--column 'Kind'
						--column 'Model'
						--column 'Serial'
						--column 'Note'
						--print-column 'ALL'
						--separator '\n'
					)

					declare -a zenity_select_drives_list_options=(
						--column "$($is_verify_mode && echo 'Verify' || echo 'Erase')"
						--cancel-label 'Quit'
						"${zenity_base_list_options[@]}"
					)

					if ! $is_erase_mode && ! $is_verify_mode; then
						zenity_select_drives_list_options+=(
							--title "${APP_NAME} (Version ${APP_VERSION})  ${EM_DASH}  Detecting Drives"
							--text "<big><b>Number of Drives Detected:</b> ${detected_drives_count}</big>\n\nThis window will reload automatically when drive changes are detected${ELLIPSIS}\n\n<i>Choose <b>Ready to Verify</b> or <b>Ready to Erase</b> when all expected drives are detected.</i><span size='4000'>\n </span>"
							--ok-label 'Ready to Verify'
							--extra-button 'Ready to Erase'
							--hide-column '1,2'
						)
					else
						rm -rf "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" "${HDSENTINEL_OUTPUT_PATH_PREFIX}"* "${SMARTCTL_OUTPUT_PATH_PREFIX}"* "${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}"* "${HDPARM_OUTPUT_PATH_PREFIX}"* "${SG_OPCODES_OUTPUT_PATH_PREFIX}"*

						while [[ -z "${lot_code}" ]]; do
							if lot_code_confirmed="$(zenity --forms \
								--title "${APP_NAME}  ${EM_DASH}  Enter Lot Code" \
								"${zenity_icon_args[@]}" \
								--text 'Lot Code MUST Be \"FG\" Followed\nby 8 Digits a Hyphen and 1 Digit,\nor "N" if NO Lot Code' \
								--add-entry 'Lot Code:' \
								--add-entry 'Confirm Lot Code:' \
								--separator $'\n' \
								--ok-label 'Submit' \
								--cancel-label 'Quit' 2> /dev/null)"; then
								IFS=$'\n' read -rd '' lot_code confirm_lot_code <<< "${lot_code_confirmed}"

								lot_code="$(trim_and_squeeze_whitespace "${lot_code^^}")"
								confirm_lot_code="$(trim_and_squeeze_whitespace "${confirm_lot_code^^}")"
								if [[ "${lot_code}" =~ ^FG[0123456789]{8}-[123456789]$ || "${lot_code}" =~ ^[0123456789]{8}-[123456789]$ || "${lot_code}" == 'N' || "${lot_code}" == 'NONE' ]]; then
									# Lot Code is "FG" followed by 2 digits for technicial ID, 2 digits for year, 2 digits for month, 2 digits for day, and then a hyphen and a single digit for the lot group in case there are multiple lots in a single day.
									# But, allow "FG" to be omitted and add it if so.

									if [[ "${lot_code}" =~ ^[0123456789]{8}-[123456789]$ ]]; then
										lot_code="FG${lot_code}"
									elif [[ "${lot_code}" == 'N' ]]; then
										lot_code='NONE'
									fi

									if [[ "${confirm_lot_code}" =~ ^[0123456789]{8}-[123456789]$ ]]; then
										confirm_lot_code="FG${confirm_lot_code}"
									elif [[ "${confirm_lot_code}" == 'N' ]]; then
										confirm_lot_code='NONE'
									fi
								else
									lot_code=''
								fi

								if [[ -z "${lot_code}" ]]; then
									zenity --warning --title "${APP_NAME}  ${EM_DASH}  Invalid Lot Code" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Lot code MUST be \"FG\" followed by 8 digits a hyphen and 1 digit, or \"N\" if NO lot code.</b></big>' &> /dev/null
								elif [[ "${confirm_lot_code}" != "${lot_code}" ]]; then
									lot_code=''
									zenity --warning --title "${APP_NAME}  ${EM_DASH}  Did Not Confirm Lot Code" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Did not confirm lot code.</b></big>' &> /dev/null
								fi
							else
								exit 21 # Use same exit code for "Invalid LOT CODE" error when "-c" is passed via CLI.
							fi
						done

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

						if $is_erase_mode && [[ -n "${technician_initials_from_lot_code}" && -z "${technician_initials}" ]]; then
							# If erasing and the Technician ID within the Lot Code is known, set the initals based on that instead of unnecessarily prompting for initials.
							# If verifying, always prompt for initials since a DIFFERENT technician should be verifying the drives.

							technician_initials="${technician_initials_from_lot_code}"
						fi

						while [[ -z "${technician_initials}" ]]; do
							if technician_initials_confirmed="$(zenity --forms \
								--title "${APP_NAME}  ${EM_DASH}  Enter Your Initials" \
								"${zenity_icon_args[@]}" \
								--text 'Technician Initials for Logging\nMUST Be Only 2-4 Letters' \
								--add-entry 'Your Initials:' \
								--add-entry 'Confirm Initials:' \
								--separator $'\n' \
								--ok-label 'Submit' \
								--cancel-label 'Quit' 2> /dev/null)"; then
								IFS=$'\n' read -rd '' technician_initials confirm_technician_initials <<< "${technician_initials_confirmed}"
								technician_initials="$(trim_and_squeeze_whitespace "${technician_initials^^}")"

								if [[ ! "${technician_initials}" =~ ^[ABCDEFGHIJKLMNOPQRSTUVWXYZ]{2,4}$ ]]; then
									technician_initials=''
									zenity --warning --title "${APP_NAME}  ${EM_DASH}  Invalid Technician Initials for Logging" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Your initials for logging MUST be only 2-4 letters.</b></big>' &> /dev/null
								elif $is_verify_mode && [[ -n "${technician_initials_from_lot_code}" && "${technician_initials_from_lot_code}" == "${technician_initials}" ]]; then
									technician_initials=''
									zenity --warning --title "${APP_NAME}  ${EM_DASH}  Cannot Verify Own Lot" "${zenity_icon_caution_args[@]}" --no-wrap --text '<big><b>You CANNOT verify your own lot.</b></big>\n\nSince you were the one who erased this lot, a different technician must verify it.' &> /dev/null
								elif [[ "$(trim_and_squeeze_whitespace "${confirm_technician_initials^^}")" != "${technician_initials}" ]]; then
									technician_initials=''
									zenity --warning --title "${APP_NAME}  ${EM_DASH}  Did Not Confirm Initials for Logging" "${zenity_icon_caution_args[@]}" --no-wrap --text '\n<big><b>Did not confirm your initials for logging.</b></big>' &> /dev/null
								fi
							else
								exit 20 # Use same exit code for "Invalid TECHNICIAN INITIALS" error when "-i" is passed via CLI.
							fi
						done

						if $is_verify_mode; then
							zenity_select_drives_list_options+=(
								--checklist
								--title "${APP_NAME}  ${EM_DASH}  Choose Drives to VERIFY"
								--text "<big><b>Which of the ${detected_drives_count} detected drive$( (( detected_drives_count > 1 )) && echo 's' ) would you like to <u>VERIFY</u>?</b></big>\n\n<b>Technician Initials:</b> <u>${technician_initials}</u>\n<b>Lot Code:</b> <u>${lot_code}</u>\n<i>(Quit and Re-Launch if the Technician Initials Are NOT Yours or if the Lot Code Is NOT Correct)</i><span size='4000'>\n </span>"
								--ok-label "Verify Selected Drives${ELLIPSIS}"
								--hide-column '2'
							)
						elif (( frozen_drives_array_count > 0 )); then
							zenity_select_drives_list_options+=(
								--title "${APP_NAME}  ${EM_DASH}  Sleep to Unfreeze Drives"
								--text "<big><b>To be able to erase any drives, you must first sleep to unfreeze drives.</b></big>\n\n<b>Technician Initials:</b> <u>${technician_initials}</u>\n<b>Lot Code:</b> <u>${lot_code}</u>\n<i>(Quit and Re-Launch if the Technician Initials Are NOT Yours or if the Lot Code Is NOT Correct)</i><span size='4000'>\n </span>"
								--ok-label "Sleep (to Unfreeze Drives)${ELLIPSIS}"
								--hide-column '1,2'
							)
						else
							zenity_select_drives_list_options+=(
								--checklist
								--title "${APP_NAME}  ${EM_DASH}  Choose Drives to COMPLETELY ERASE"
								--text "<big><b>Which of the ${detected_drives_count} detected drive$( (( detected_drives_count > 1 )) && echo 's' ) would you like to <u>COMPLETELY ERASE</u>?</b></big>\n\n<b>Technician Initials:</b> <u>${technician_initials}</u>\n<b>Lot Code:</b> <u>${lot_code}</u>\n<i>(Quit and Re-Launch if the Technician Initials Are NOT Yours or if the Lot Code Is NOT Correct)</i><span size='4000'>\n </span>"
								--ok-label "Erase Selected Drives${ELLIPSIS}"
								--hide-column '2'
							)
						fi

						if $is_verify_mode || (( frozen_drives_array_count == 0 )); then
							if $detected_failed_health_drives || $force_override_health_checks; then
								zenity_select_drives_list_options+=(
									--extra-button "$($force_override_health_checks && echo 'DO NOT' || echo 'Force') Override Health Checks"
								)
							fi
						fi
					fi

					zenity_select_drives_list_options+=(
						--extra-button 'Reload'
					)

					selected_drives="$(zenity "${zenity_select_drives_list_options[@]}" "${drives_array[@]}" 2> /dev/null)"
					select_drives_exit_code="$?"

					check_and_exit_if_other_instances_running

					if [[ "${selected_drives}" != 'Reload' ]] && (( select_drives_exit_code != 140 )); then # Reload instead of quit with exit code 140 from SIGUSR2 (reload for drive changes detected).
						if [[ "${selected_drives}" == 'Force Override Health Checks' ]]; then
							if zenity --question --title "${APP_NAME}  ${EM_DASH}  Confirm Force Override Health Checks" "${zenity_icon_caution_args[@]}" --ok-label 'Confirm & Reload' --cancel-label 'Cancel & Reload' --no-wrap --text "<big><b>Are you sure you would you like to FORCE OVERRIDE health checks?</b></big>\n\nOverriding health checks will allow you to $($is_verify_mode && echo 'verify' || echo 'erase') drives with failed health,\nbut this should only be used for special cases such as vintage tech or devices sent to bulk sales.\n\nDrives with failed health SHOULD NOT be sent to normal production stocks for refurbishment." &> /dev/null; then
								force_override_health_checks=true
							fi
						elif [[ "${selected_drives}" == 'DO NOT Override Health Checks' ]]; then
							force_override_health_checks=false
						elif [[ "${selected_drives}" == 'Ready to Erase' ]]; then
							is_erase_mode=true
						elif (( select_drives_exit_code == 0 )); then
							if ! $is_erase_mode && ! $is_verify_mode; then
								is_verify_mode=true
							elif (( frozen_drives_array_count > 0 )); then
								zenity --question --timeout '10' --title "${APP_NAME}  ${EM_DASH}  Confirm Sleep to Unfreeze Drives" "${zenity_icon_args[@]}" --ok-label 'Sleep Now' --cancel-label 'Cancel & Reload' --no-wrap --text "<big><b>Sleeping computer in 10 seconds to attempt to unfreeze drives for \"ATA Secure Erase\" and \"Format NVM\" commands${ELLIPSIS}</b></big>\n\nThis computer will automatically wake itself back up after sleeping, and drives should be unfrozen (but sometimes drives cannot be unfrozen just from sleeping)." &> /dev/null
								sleep_to_unfreeze_exit_code="$?"

								if (( sleep_to_unfreeze_exit_code != 1 )); then # Sleep instead of reload with exit code 5 from timeout.
									rtcwake -m 'mem' -s '1' &> /dev/null # https://www.baeldung.com/linux/auto-suspend-wake (Also, this technique does not interrupt the network connection like "systemctl suspend" does.)
									did_sleep_to_unfreeze_drives_array+=( "${frozen_drives_array[@]}" )
								fi
							elif [[ -n "${selected_drives}" ]]; then
								declare -a selected_drives_array=()
								readarray -t selected_drives_array <<< "${selected_drives}"

								selected_drives_array_count="${#selected_drives_array[@]}"
								if (( selected_drives_array_count > 0 && (selected_drives_array_count % 9) == 0 )); then
									declare -a confirm_selected_drives_array=()
									declare -a skipping_failed_health_drives=()
									for (( start_index = 0; start_index < ${#selected_drives_array[@]}; start_index += 9 )); do
										this_selected_drive_health="${selected_drives_array[start_index + 3]}"
										this_selected_drive_id="${selected_drives_array[start_index + 2]}"
										if $force_override_health_checks || [[ "${this_selected_drive_health}" != 'FAIL' ]]; then
											confirm_selected_drives_array+=(
												"${selected_drives_array[start_index]}"
												"${selected_drives_array[start_index + 1]}"
												"${this_selected_drive_id}"
												"${this_selected_drive_health}"
												"${selected_drives_array[start_index + 4]}"
												"${selected_drives_array[start_index + 5]}"
												"${selected_drives_array[start_index + 6]}"
												"${selected_drives_array[start_index + 7]}"
												"${selected_drives_array[start_index + 8]}"
											)
										else
											skipping_failed_health_drives+=( "${this_selected_drive_id}" )
										fi
									done

									skipping_failed_health_drives_count="${#skipping_failed_health_drives[@]}"
									printf -v skipping_failed_health_drives_display '%s, ' "${skipping_failed_health_drives[@]}"
									skipping_failed_health_drives_display="${skipping_failed_health_drives_display%, }"

									confirm_selected_drives_array_count="${#confirm_selected_drives_array[@]}"
									if (( confirm_selected_drives_array_count > 0 && (confirm_selected_drives_array_count % 9) == 0 )); then
										selected_drives_count="$(( confirm_selected_drives_array_count / 9 ))"
										confirm_selected_drives_text="<big><b>Are you sure you would you like to <u>$($is_verify_mode && echo 'VERIFY' || echo 'COMPLETELY ERASE')</u> the following ${selected_drives_count} drive$( (( selected_drives_count > 1 )) && echo 's' )?</b></big>"
										if (( skipping_failed_health_drives_count > 0 )); then
											confirm_selected_drives_text="<b>NOTICE:</b> The following ${skipping_failed_health_drives_count} selected drive$( (( skipping_failed_health_drives_count > 1 )) && echo 's' ) <u>FAILED health check</u> and will be <u>SKIPPED</u>: <i>${skipping_failed_health_drives_display}</i>\n\n${confirm_selected_drives_text}"
										fi

										declare -a zenity_confirm_drives_list_options=(
											--title "${APP_NAME}  ${EM_DASH}  Confirm Selected Drives to $($is_verify_mode && echo 'VERIFY' || echo 'COMPLETELY ERASE')"
											--text "${confirm_selected_drives_text}\n\n<b>Technician Initials:</b> <u>${technician_initials}</u>\n<b>Lot Code:</b> <u>${lot_code}</u>\n<i>(Quit and Re-Launch if the Technician Initials Are NOT Yours or if the Lot Code Is NOT Correct)</i><span size='4000'>\n </span>"
											--ok-label "Confirm $($is_verify_mode && echo 'Verify' || echo 'Erase') Selected Drives"
											--cancel-label 'Cancel & Reload'
											--hide-column 1
											"${zenity_base_list_options[@]}"
										)

										if zenity "${zenity_confirm_drives_list_options[@]}" "${confirm_selected_drives_array[@]}" &> /dev/null; then
											check_and_exit_if_other_instances_running

											terminator_process_indexes_launched_path="${TMPDIR}/${APP_NAME_FOR_FILE_PATHS}-terminator-process-indexes-launched.txt"
											rm -rf "${terminator_process_indexes_launched_path}" # This file is appended to by each launched Terminator process, so make sure it is cleared before each new batch is launched.

											terminator_process_index=1
											for (( start_index = 0; start_index < ${#confirm_selected_drives_array[@]}; start_index += 9 )); do
												nohup terminator --title "${APP_NAME}" --maximize --new-tab --command "bash -c $(LC_CTYPE=C; printf '%q' "$(actual_eraser_script)") $(LC_CTYPE=C; printf '%q' "${APP_NAME} (${APP_VERSION}) - ${terminator_process_index}") -d $(LC_CTYPE=C; printf '%q' "${confirm_selected_drives_array[start_index]}") -$($is_verify_mode && echo 'v' || echo 'e')$($force_override_health_checks && echo 'f')$([[ -n "${technician_initials}" ]] && echo "i $(LC_CTYPE=C; printf '%q' "${technician_initials}")")$([[ -n "${lot_code}" ]] && echo " -c $(LC_CTYPE=C; printf '%q' "${lot_code}")") --" &> /dev/null & disown # NOTE: End command with " --" so there is always a space after the specified device ID to be able to easily "pgrep" an exact match of the device ID (which would now always be the case anyways because at least either "-e" or "-v" will always be specified) and also the entire command line up to that consistent end of line.
												# TODO: Explain using "--command" with crazy quoting instead of "--execute" which would be simpler syntax (because it fails after the first execution for some reason).
												# NOTE: MUST set "LC_CTYPE=C" to properly escape multi-byte characters into their UTF-8 octal-byte escaped notation instead of into other multi-byte characters in some other encoding that may not render properly. (And since it is only set within a command substitution subshell is only affects this single "printf '%q'" statement.)

												sleep 1 # Always sleep 1 second before opening progress window so that the Terminator window/tab opening doesn't steal focus.
												for (( sleep_seconds = 0; sleep_seconds < 25; sleep_seconds ++ )); do # Wait for up to 25 seconds for the launched process index to get logged to the "terminator_process_indexes_launched_path" file.
													if grep -qxF "${terminator_process_index}" "${terminator_process_indexes_launched_path}"; then
														break
													else
														sleep 1
													fi
												done | zenity \
													--progress \
													--title "${APP_NAME}  ${EM_DASH}  Launching $($is_verify_mode && echo 'Verify' || echo 'Erase') Processes" \
													"${zenity_icon_args[@]}" \
													--text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Launching $($is_verify_mode && echo 'Verify' || echo 'Erase') Process ${terminator_process_index} of ${selected_drives_count}: ${confirm_selected_drives_array[start_index]##*/}</b></big>\n" \
													--width '600' \
													--pulsate \
													--auto-close \
													--no-cancel &> /dev/null

												(( terminator_process_index ++ ))
											done

											terminator_processes_launched_count="$(sort -un "${terminator_process_indexes_launched_path}" | wc -l | awk '{ print $1; exit }')"
											terminator_process_indexes_launched_list=$(sort -un "${terminator_process_indexes_launched_path}" | tr '\n' ',')
											terminator_process_indexes_launched_list="${terminator_process_indexes_launched_list%,}"
											rm -rf "${terminator_process_indexes_launched_path}"

											if (( terminator_processes_launched_count != selected_drives_count )); then
												send_error_email "Only ${terminator_processes_launched_count} of ${selected_drives_count} $($is_verify_mode && echo 'verify' || echo 'erase') processes were launched: ${terminator_process_indexes_launched_list}"
												zenity --warning --title "${APP_NAME}  ${EM_DASH}  Unexpected Error Launching $($is_verify_mode && echo 'Verify' || echo 'Erase') Processes" "${zenity_icon_caution_args[@]}" --no-wrap --text "<big><b>Unexpected error occurred launching ${selected_drives_count} $($is_verify_mode && echo 'verify' || echo 'erase') processes.</b></big>\n\n<b>Only ${terminator_processes_launched_count} of ${selected_drives_count} $($is_verify_mode && echo 'verify' || echo 'erase') processes were launched: ${terminator_process_indexes_launched_list}</b>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>" &> /dev/null
												exit 206
											fi

											exit 0 # Always QUIT after launching erasures/verifications since can't start new ones until those finish.
										fi
									elif (( skipping_failed_health_drives_count > 0 )); then
										if ! zenity --question --title "${APP_NAME}  ${EM_DASH}  Only FAILED Drives Selected" "${zenity_icon_caution_args[@]}" --ok-label 'Reload' --cancel-label 'Quit' --no-wrap --text "<big><b>All of the drives that you have selected have <u>FAILED health check</u> and cannot be $($is_verify_mode && echo 'verified' || echo 'erased'):</b></big>\n\n${skipping_failed_health_drives_display}" &> /dev/null; then
											exit 52
										fi
									else
										>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unexpected error occurred confirming drive selection. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"
										send_error_email 'Unexpected error occurred confirming drive selection.'
										zenity --warning --title "${APP_NAME}  ${EM_DASH}  Unexpected Error Confirming Drive Selection" "${zenity_icon_caution_args[@]}" --no-wrap --text '<big><b>Unexpected error occurred confirming drive selection.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>' &> /dev/null
										exit 202
									fi
								else
									>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unexpected error occurred selecting drives. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"
									send_error_email 'Unexpected error occurred selecting drives.'
									zenity --warning --title "${APP_NAME}  ${EM_DASH}  Unexpected Error Selecting Drives" "${zenity_icon_caution_args[@]}" --no-wrap --text '<big><b>Unexpected error occurred selecting drives.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>' &> /dev/null
									exit 201
								fi
							elif ! zenity --question --title "${APP_NAME}  ${EM_DASH}  No Drives Selected" "${zenity_icon_caution_args[@]}" --ok-label 'Reload' --cancel-label 'Quit' --no-wrap --text "\n<big><b>No drives were selected to $($is_verify_mode && echo 'verify' || echo 'erase').</b></big>" &> /dev/null; then
								exit 22 # Use same exit code for "Invalid drive device ID specified" error when "-d" is passed via CLI.
							fi
						else
							rm -rf "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" "${HDSENTINEL_OUTPUT_PATH_PREFIX}"* "${SMARTCTL_OUTPUT_PATH_PREFIX}"* "${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}"* "${HDPARM_OUTPUT_PATH_PREFIX}"* "${SG_OPCODES_OUTPUT_PATH_PREFIX}"*
							exit 0
						fi
					fi
				else
					zenity --question --title "${APP_NAME} (Version ${APP_VERSION})  ${EM_DASH}  No Drives Detected" "${zenity_icon_args[@]}" --ok-label 'Reload' --cancel-label 'Quit' --no-wrap --text "<big><b>No drives were detected to erase or verify.</b></big>\n\nWill reload automatically when drive changes are detected${ELLIPSIS}" &> /dev/null
					no_drives_detected_exit_code="$?"

					if (( no_drives_detected_exit_code == 1 )); then # Reload instead of quit with exit code 140 from SIGUSR2 (reload for drive changes detected).
						rm -rf "${LSBLK_DISKS_LATEST_OUTPUT_PATH}" "${LSBLK_DISKS_LOADED_OUTPUT_PATH}" "${HDSENTINEL_OUTPUT_PATH_PREFIX}"* "${SMARTCTL_OUTPUT_PATH_PREFIX}"* "${NVME_ID_CTRL_INFO_OUTPUT_PATH_PREFIX}"* "${HDPARM_OUTPUT_PATH_PREFIX}"* "${SG_OPCODES_OUTPUT_PATH_PREFIX}"*
						exit 40
					fi
				fi
			fi
		done
	fi

	if ! $IS_GUI_MODE && ! $cli_list_mode && [[ -n "${cli_specified_drive_full_id}" ]]; then
		if [[ -t 1 ]]; then # ONLY "clear" and re-display app title if stdout IS associated with an interactive terminal.
			clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
			echo -e "${APP_DISPLAY_TITLE}"
		fi

		for this_cli_action_mode_override_notice in "${cli_action_mode_override_notices[@]}"; do
			>&2 echo -e "${this_cli_action_mode_override_notice}"
		done

		IFS='"' read -r _ detected_drive_id _ detected_drive_size_bytes _ detected_drive_type _ detected_drive_read_only _ < <(timeout -s SIGKILL 10 lsblk -abdPpo 'NAME,SIZE,TYPE,RO' "${cli_specified_drive_full_id}" 2> /dev/null)

		if [[ "${detected_drive_id}" != "${cli_specified_drive_full_id}" || "${detected_drive_type}" != 'disk' ]]; then
			>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive device ID \"${cli_specified_drive_id}\" not found.${CLEAR_ANSI}\n"
			exit 53
		elif (( detected_drive_size_bytes == 0 )); then
			>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive \"${cli_specified_drive_id}\" size is 0 bytes and therefore cannot be verified or erased.${CLEAR_ANSI}\n"
			exit 54
		elif $is_erase_mode && (( detected_drive_read_only != 0 )); then
			>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive \"${cli_specified_drive_id}\" is READ ONLY and therefore cannot be erased.${CLEAR_ANSI}\n"
			exit 55
		elif [[ "${cli_specified_drive_full_id}" == "${boot_device_drive_id}" ]]; then
			>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Specified drive device ID \"${cli_specified_drive_id}\" is the ${ANSI_BOLD}BOOT DEVICE${ANSI_RED} and therefore cannot be verified or erased.${CLEAR_ANSI}\n"
			exit 56
		fi

		while read -r mounted_device_id _; do
			if [[ "${mounted_device_id}" == "${cli_specified_drive_full_id}"* ]]; then
				mounted_device_id_parent="${mounted_device_id}"
				if [[ "${mounted_device_id_parent}" == '/dev/sd'*[0123456789]* ]]; then
					mounted_device_id_parent="${mounted_device_id_parent%%[0123456789]*}"
				elif [[ "${mounted_device_id_parent}" == '/dev/nvme'*'p'* || "${mounted_device_id_parent}" == '/dev/mmcblk'*'p'* ]]; then
					mounted_device_id_parent="${mounted_device_id_parent%%p*}"
				fi

				if [[ "${mounted_device_id_parent}" == "${cli_specified_drive_full_id}" ]]; then
					while IFS='' read -r this_mount_point; do # "findmnt" could output multiple mount points separated by newlines for any given device ID.
						# DEBUG >&2 echo "DEBUG: Unmounting \"${this_mount_point}\" (of \"${mounted_device_id}\")" # DEBUG
						umount -f "${this_mount_point}"
					done < <(findmnt -no 'TARGET' "${mounted_device_id}") # NOTE: NOT getting mount point from "/proc/mounts" since it's hard to parse if there is a space in the mount point path.
				fi
			fi
		done < '/proc/mounts'

		while read -r raid_device_id _; do
			if [[ "${raid_device_id}" == 'md'* ]]; then
				# DEBUG >&2 echo "DEBUG: Stopping RAID device \"${raid_device_id}\"" # DEBUG
				mdadm -S "/dev/${raid_device_id}" &> /dev/null # TODO: Explain (for keeping things tidy and maybe also to keep device listings in order?)
			fi
		done < '/proc/mdstat'

		declare -a actual_erase_script_options=( '-d' "${cli_specified_drive_full_id}" )

		if [[ -n "${technician_initials}" ]]; then
			actual_erase_script_options+=( '-i' "${technician_initials}" )
		fi

		if [[ -n "${lot_code}" ]]; then
			actual_erase_script_options+=( '-c' "${lot_code}" )
		fi

		if $force_override_health_checks; then
			actual_erase_script_options+=( '-f' )
		fi

		if $cli_quick_mode; then
			actual_erase_script_options+=( '-q' )
		fi

		if [[ -n "${cli_action_mode}" ]]; then
			actual_erase_script_options+=( "-${cli_action_mode}" )
		fi

		if $cli_auto_mode; then
			actual_erase_script_options+=( '-A' )
		fi

		check_and_exit_if_other_instances_running

		if (( ${#cli_action_mode_override_notices[@]} > 0 )); then
			sleep 3 # Sleep a bit to show any CLI action mode override notices before clearing screen for actual erasure.
		fi

		bash -c "$(actual_eraser_script)" "${APP_NAME} (${APP_VERSION}) - CLI Mode" "${actual_erase_script_options[@]}" -- # NOTE: End command with "--" so there is always a space after the specified device ID to be able to easily "pgrep" an exact match.
		exit "$?"
	fi

	>&2 echo -e "\n  ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Unexpected error occurred. - ${ANSI_YELLOW}${ANSI_BOLD}THIS SHOULD NOT HAVE HAPPENED${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}PLEASE INFORM FREE GEEK I.T.${CLEAR_ANSI}\n"

	send_error_email 'Unexpected error occurred.'

	if can_launch_zenity; then
		zenity --warning --title "${APP_NAME}  ${EM_DASH}  Unexpected Error" "${zenity_icon_caution_args[@]}" --no-wrap --text '<big><b>Unexpected error occurred.</b></big>\n\n<i>THIS SHOULD NOT HAVE HAPPENED - PLEASE INFORM FREE GEEK I.T.</i>' &> /dev/null
	fi

	exit 200 # Should never get here, so exit as an error.
fi
