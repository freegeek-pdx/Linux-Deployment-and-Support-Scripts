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

# THIS SCRIPT MUST BE RUN *INTERACTIVELY* IN A TERMINAL
# In Linux Mint, double-click the file and choose "Run in Terminal".
# If the Terminal window closes itself, that means an error happened causing the script to exit prematurely.
# When everything is successful, the Terminal window will stay open until you close it manually or hit the Enter key.

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

echo -e '\nPREPARE CUBIC PROJECT FOR MINT LIVE TOOLKIT\n'

if [[ "$(hostname)" == 'cubic' ]]; then
	>&2 echo 'ERROR: THIS SCRIPT MUST BE RUN LOCALLY, NOT IN CUBIC TERMINAL'
	read -r
	exit 1
fi

os_version="$1"
version_suffix="$2"

if [[ -z "${os_version}" && -z "${version_suffix}" ]]; then
	read -rp 'OS Version: ' os_version
	read -rp 'Version Suffix (can be blank): ' version_suffix
fi

if [[ -z "${os_version}" ]]; then
	>&2 echo -e '\nERROR: MUST SPECIFY OS VERSION'
	read -r
	exit 2
fi

version_suffix="${version_suffix,,}"
if [[ -n "${version_suffix}" && "${version_suffix}" != '-'* ]]; then
	version_suffix="-${version_suffix}"
fi

os_codename="$(curl -m 5 -sfL 'https://www.linuxmint.com/download_all.php' | xmllint --html --xpath "string(//td[text()='${os_version}']/following-sibling::td[1])" - 2> /dev/null)"

if [[ -z "${os_codename}" ]]; then
	if [[ "${version_suffix}" == '-beta' ]]; then
		read -rp 'OS Codename for BETA: ' os_codename
	else
		>&2 echo -e "\nERROR: FAILED TO RETRIEVE CODENAME FOR OS VERSION ${os_version} (INTERNET & \"libxml2-utils\" REQUIRED)"
		read -r
		exit 3
	fi
fi

release_notes_url="http://www.linuxmint.com/rel_${os_codename,,}_cinnamon.php"
if [[ "$(echo -e "21.3\n${os_version}" | sort -V)" == $'21.3\n'* ]]; then
	release_notes_url="https://www.linuxmint.com/rel_${os_codename,,}.php" # This is the new release note URL format starting with Mint 21.3.
fi

if ! curl -m 5 -sfL "${release_notes_url}" | grep -qF "Mint ${os_version} \"${os_codename}\""; then
	>&2 echo -e "\nERROR: FAILED TO VERIFY RELEASE NOTES URL FOR CODENAME \"${os_codename}\" OF OS VERSION ${os_version} (INTERNET REQUIRED)"
	read -r
	exit 4
fi

echo "
OS Version: ${os_version}
OS Codename: ${os_codename}
Version Suffix: ${version_suffix:-N/A}"

cubic_project_parent_path="${HOME}/Linux Deployment"
mkdir -p "${cubic_project_parent_path}"

source_iso_name="linuxmint-${os_version}-cinnamon-64bit${version_suffix}.iso"

if [[ -f "${cubic_project_parent_path}/Linux ISOs/${source_iso_name}" ]]; then
	echo -e "\nPRESS ENTER TO CONTINUE WITH ISO PATH \"${cubic_project_parent_path}/Linux ISOs/${source_iso_name}\" (OR PRESS CONTROL-C TO CANCEL)"
	read -r
else
	>&2 echo -e "\nERROR: SOURCE ISO NOT FOUND AT \"${cubic_project_parent_path}/Linux ISOs/${source_iso_name}\""
	read -r
	exit 5
fi

build_date="$(date '+%y.%m.%d')"

cubic_project_path="${cubic_project_parent_path}/Mint Live Toolkit ${os_version} Cinnamon${version_suffix//-/ } Updated 20${build_date}"

if [[ -d "${cubic_project_path}" ]]; then
	echo -e "PROJECT PATH ALREADY EXISTS: ${cubic_project_path}\nPRESS ENTER TO DELETE AND RE-CREATE IT (OR PRESS CONTROL-C TO CANCEL)"
	read -r

	sudo rm -rf "${cubic_project_path}"
fi

set -ex


# INSTALL/UPDATE CUBIC
# https://launchpad.net/cubic
# https://github.com/PJ-Singh-001/Cubic

if ! apt-cache policy | grep -qF 'cubic-wizard-release'; then
	echo -e '\n>>> ADDING CUBIC REPOSITORY <<<\n'
	sudo apt-add-repository universe
	sudo apt-add-repository ppa:cubic-wizard/release
fi

echo -e "\n>>> $(command -v cubic &> /dev/null && echo 'UPDATING' || echo 'INSTALLING') CUBIC <<<\n"
sudo apt update || echo 'APT UPDATE ERROR - CONTINUING ANYWAY'
sudo apt install --no-install-recommends cubic || echo 'CUBIC UPDATE ERROR - CONTINUING ANYWAY'


# PREPARE CUBIC PROJECT

cubic_project_disk_path="${cubic_project_path}/custom-disk"
cubic_project_root_path="${cubic_project_path}/custom-root"

updated_iso_name="mint-live-toolkit-${os_version}-cinnamon-64bit${version_suffix}-updated-${build_date}.iso"

if [[ ! -f "${cubic_project_path}/cubic.conf" ]]; then
	# Create new project template based on these instructions: https://github.com/PJ-Singh-001/Cubic/issues/12#issuecomment-1013804874

	mkdir -p "${cubic_project_path}"

	cubic_conf_version='2024.09-89-release~202409062212~ubuntu24.04.1'
	# IMPORTANT: This cubic_conf_version should be set to a version of Cubic that is known the be compatible with the following "cubic.conf" format.
	# The currently installed Cubic version can be retrieved with "dpkg-query --show cubic" (or by copy-and-pasting it from a new "cubic.conf" file made by Cubic).
	# If the "cubic.conf" format is ever changed in the future, having this previous Cubic version listed in the "cubic.conf" file will let Cubic know that it needs to be migrated (and will show a screen like this: https://github.com/PJ-Singh-001/Cubic/wiki/Migrate-Page).
	# If this happens, and a future version of Cubic needs to migrate this "cubic.conf" format, this script should be updated with the new format and a new compatible Cubic version so that migration is not necessary for each new project.
	# Reference: https://github.com/PJ-Singh-001/Cubic/issues/12#issuecomment-1015001654

	current_timestamp="$(date '+%F %H:%M')"

	# MAKE SURE THAT ALL THE FOLLOWING VALUES ARE CORRECT FOR EACH NEW VERSION OF MINT
	cat << CUBIC_CONF_EOF > "${cubic_project_path}/cubic.conf"
[Project]
cubic_version = ${cubic_conf_version}
create_date = ${current_timestamp}
modify_date = ${current_timestamp}
directory = ${cubic_project_path}

[Original]
iso_file_name = ${source_iso_name}
iso_directory = ${cubic_project_parent_path}/Linux ISOs
iso_volume_id = Linux Mint ${os_version} Cinnamon 64-bit
iso_release_name = ${os_codename}
iso_disk_name = Linux Mint ${os_version} "${os_codename}" - Release amd64

[Custom]
iso_version_number = 20${build_date}
iso_file_name = ${updated_iso_name}
iso_directory = ${cubic_project_path}
iso_volume_id = Mint Live Toolkit ${os_version}
iso_release_name = ${os_codename} - Updated 20${build_date}
iso_disk_name = Mint Live Toolkit ${os_version} Cinnamon${version_suffix//-/ } "${os_codename} - Updated 20${build_date}"

[Options]
update_os_release = False
boot_configurations = boot/grub/grub.cfg, boot/grub/loopback.cfg, isolinux/isolinux.cfg
compression = zstd
CUBIC_CONF_EOF
	# IMPORTANT NOTES ABOUT COMPRESSION ALGORITHM:
	# DO NOT use "xz" compression even though it creates the smallest "squashfs" (and ISO) because it actually slows down loading the live OS.
	# DO NOT use "lzma" compression because it is deprecated and also cannot be loaded by the kernel for the "squashfs".
	# "zstd" or any faster/larger compressions all load the live OS quickly, which can be up to about a minute faster than when using "xz" compression!
	# The live OS loading speed difference between "zstd" and other faster/larger compressions seems to very negligible and pretty equally fast in real world usage.
	# Here are some good benchmarks of the decompression speed of different compressions for the "squashfs" file: https://github.com/AgentD/squashfs-tools-ng/blob/master/doc/benchmark.txt
	# Even though there are actual speed differences between the "zstd" and other faster/larger compressions, in real world usage they are all pretty equally fast
	# because other factors such as running from a USB or via netboot (or other hardware factors) will be the bottleneck rather than just the raw decompression speed.
	# For some more context, portions of the "squashfs" file are decompressed on-demand as the live OS loads and runs rather than being decompressed all at once,
	# which is is why the decompression speed is so important for the live OS loading and running preformance.
	# So, using "zstd" since it has the best balance of smaller image size with fast live OS loading speed.

	# AND DON'T FORGET TO ALWAYS MAKE SURE THAT THIS RELEASE URL IS ALSO CORRECT FOR EACH NEW VERSION OF MINT
	mkdir -p "${cubic_project_disk_path}/.disk"
	echo "${release_notes_url}" > "${cubic_project_disk_path}/.disk/release_notes_url"
fi

nohup cubic --log "${cubic_project_path}" &> /dev/null & disown

while [[ "$(wmctrl -l)"$'\n' != *$' cubic\n'* ]]; do
	sleep 1
done

wmctrl -r 'cubic' -e '0,-100,-100,-1,-1' # The "Cubic" window will not go all the way to the top right corner if "0,0" are specified, so use "-100,-100" instead to accomodate this behavior (and "wmctrl" will not put the window off screen even if "-100" is actuall too much).

sleep 5

# Suppress ShellCheck suggestion to use find instead of ls to better handle non-alphanumeric filenames since this will only ever be alphanumeric filenames.
# shellcheck disable=SC2012
until cubic_log_path="$(ls -t "${cubic_project_path}/cubic."*'.log' | head -1)" && [[ -f "${cubic_log_path}" ]]; do
	sleep 1
done

until grep -qF 'Entered virtual environment' "${cubic_log_path}"; do
	echo -e '\n>>> WAITING FOR CUBIC TO EXTRACT ORIGINAL ISO <<<\n>>> CLICK "NEXT" TWICE IN CUBIC <<<\n'
	sleep 5
done

custom_toolkit_resources_path="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
custom_installer_resources_path="${custom_toolkit_resources_path}/../Mint Installer Resources"

if ! WIFI_PASSWORD="$(< "${custom_installer_resources_path}/Wi-Fi Password.txt")" || [[ -z "${WIFI_PASSWORD}" ]]; then
	>&2 echo -e '\nERROR: FAILED TO GET WI-FI PASSWORD\n'
	read -r
	exit 6
fi
readonly WIFI_PASSWORD

if [[ "$(echo -e "21.3\n${os_version}" | sort -V)" != $'21.3\n'* ]]; then # THE FOLLOWING FILES NO LONGER NEED TO BE COPIED ON MINT 21.3 AND NEWER SINCE THEY ALREADY EXIST.
	# NOTE: Manually copy the ISO "initrd" and "vmlinuz" files to full OS "/boot" folder so that running "update-initramfs -u" in "cubic-terminal-commands-for-mint-live-toolkit.sh" will always work when customizing the "initrd" to add USB network adapter drivers for USB live boots to be able to load internet with USB network adapters.
	# If the "initrd" file is not copied manually, and there was no kernel update when system updates were run in "cubic-terminal-commands-for-mint-live-toolkit.sh" (which would really only happen when when building a new custom ISO for a new version that has just come out), then "update-initramfs -u" will fail to create new customized "initrd" file since the file will not be found (the 2 output lines will be "Available versions:" [with no versions listed] and "Nothing to do, exiting.")..
	# And, the matching "vmlinuz" file must be copied the full OS "/boot" folder for "Cubic" to be able to choose the customized kernel files (to be copied back to the ISO) rather than only listing the original kernel files from the ISO (https://github.com/PJ-Singh-001/Cubic/issues/140#issuecomment-1344646802).
	# But, if a kernel update was done during system updated in "cubic-terminal-commands-for-mint-live-toolkit.sh" then "update-initramfs -u" would work properly either way and manually copying these files is not necessary (but doesn't hurt). So, always do copy these files just to be sure the kernel customization will all always work.
	sudo cp "${cubic_project_disk_path}/casper/initrd.lz" "${cubic_project_root_path}/boot/$(readlink "${cubic_project_root_path}/boot/initrd.img" || find "${cubic_project_root_path}/boot" -mindepth 1 -maxdepth 1 -name 'config-*' -exec basename {} \; | sort -rV | head -1 | sed 's/^config-/initrd.img-/')" # Prior to Mint 20.0, the symlinks in "/boot/" will not exist to easily know the correct latest version filename to copy/rename the files to, so instead fallback on using version of the newest "config" file.
	sudo cp "${cubic_project_disk_path}/casper/vmlinuz" "${cubic_project_root_path}/boot/$(readlink "${cubic_project_root_path}/boot/vmlinuz" || find "${cubic_project_root_path}/boot" -mindepth 1 -maxdepth 1 -name 'config-*' -exec basename {} \; | sort -rV | head -1 | sed 's/^config-/vmlinuz-/')"
fi

sudo rm -rf "${cubic_project_root_path}/etc/skel/.local/qa-helper"
sudo mkdir -p "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre"
sudo tar -xzf "${custom_installer_resources_path}/dependencies/jlink-jre-"*"_linux-x64.tar.gz" -C "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre" --strip-components '1'
sudo chmod +x "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre/bin/"{java,keytool} "${cubic_project_root_path}/etc/skel/.local/qa-helper/java-jre/lib/"{jexec,jspawnhelper}

if [[ -d "${custom_installer_resources_path}/dependencies/geekbench" ]]; then
	sudo rm -rf "${cubic_project_root_path}/usr/share/geekbench"
	sudo cp -r "${custom_installer_resources_path}/dependencies/geekbench" "${cubic_project_root_path}/usr/share/geekbench"
	sudo chmod +x "${cubic_project_root_path}/usr/share/geekbench/geekbench"{6,_x86_64,_avx2}
	sudo ln -sf '/usr/share/geekbench/geekbench6' "${cubic_project_root_path}/usr/bin/geekbench"
fi

# Make all Terminals and TTYs open directly as root (if needed).
sudo sed -i 's/^Exec=gnome-terminal/Exec=sudo -i gnome-terminal/' "${cubic_project_root_path}/usr/share/applications/org.gnome.Terminal.desktop" # Make GUI Terminal launch as root.

if ! grep -qxF $'\tsudo -i' "${cubic_project_root_path}/etc/skel/.bashrc"; then
	cat << 'BASHRC_EOF' | sudo tee -a "${cubic_project_root_path}/etc/skel/.bashrc" > /dev/null

# Make all Terminals and TTYs open directly as root (if needed).
if [[ "${EUID:-$(id -u)}" != '0' ]]; then
	sudo -i
fi
BASHRC_EOF
fi

sudo touch "${cubic_project_root_path}/etc/skel/.hushlogin" # Create ".hushlogin" file in home folder skeleton to not show "To run a command as administrator..." note in CLI mode since using "sudo" is no longer no necessary with the previous ".bashrc" addition. (Search ".hushlogin" within "/etc/bash.bashrc" to see why this works and what is prevents.)


cat << 'INSTALL_OR_LAUNCH_QA_HELPER_EOF' | sudo tee "${cubic_project_root_path}/usr/local/bin/qa-helper" > /dev/null
#!/bin/bash

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

if [[ ! -e '/home/mint/Desktop/qa-helper.desktop' ]]; then
	echo -e 'PREPARING TO INSTALL QA HELPER (INTERNET IS REQUIRED)\n'
	for install_qa_helper_attempt in {1..5}; do
		actually_install_script_contents="$(curl -m 5 -sfL 'https://apps.freegeek.org/qa-helper/download/actually-install-qa-helper.sh')"
		if [[ "${actually_install_script_contents}" == *'qa-helper'* ]]; then
			echo "${actually_install_script_contents}" | bash -s -- "$1"
			break
		else
			echo 'FAILED TO DOWNLOAD ACTUAL QA HELPER INSTALLER (INTERNET IS REQUIRED)'
			if (( install_qa_helper_attempt < 5 )); then
				echo 'ATTEMPING DOWNLOAD AGAIN...'
				sleep "${install_qa_helper_attempt}"
			fi
		fi
	done
fi

if [[ -e '/home/mint/.local/bin/qa-helper' ]]; then
	/home/mint/.local/bin/qa-helper
fi
INSTALL_OR_LAUNCH_QA_HELPER_EOF

sudo chmod +x "${cubic_project_root_path}/usr/local/bin/qa-helper"
sudo ln -sf '/usr/local/bin/qa-helper' "${cubic_project_root_path}/usr/local/bin/qahelper"
sudo ln -sf '/usr/local/bin/qa-helper' "${cubic_project_root_path}/usr/local/bin/helper"


cat << 'LAUNCH_FG_ERASER_EOF' | sudo tee "${cubic_project_root_path}/usr/local/bin/fg-eraser" > /dev/null
#!/bin/bash

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

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

readonly APP_NAME='FG Eraser'

APP_NAME_FOR_FILE_PATHS="${APP_NAME,,}"
readonly APP_NAME_FOR_FILE_PATHS="${APP_NAME_FOR_FILE_PATHS// /-}"

readonly EM_DASH=$'\xE2\x80\x94' # https://www.compart.com/en/unicode/U+2014
readonly ELLIPSIS=$'\xE2\x80\xA6' # https://www.compart.com/en/unicode/U+2026
readonly EMOJI_COUNTERCLOCKWISE_ARROWS=$'\xF0\x9F\x94\x84' # https://www.compart.com/en/unicode/U+1F504

if [[ -t 0 ]]; then
	if [[ -t 1 ]]; then # ONLY "clear" if stdout IS associated with an interactive terminal.
		clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
	fi

	echo -e "\n  ${ANSI_PURPLE}${ANSI_BOLD}${APP_NAME}${CLEAR_ANSI}${CLEAR_ANSI}\n\n\n  ${ANSI_BOLD}${ANSI_UNDERLINE}Downloading ${APP_NAME}...${CLEAR_ANSI}"
fi

function can_launch_zenity() {
	apt_info_for_zenity="$(apt-cache policy zenity 2> /dev/null)"
	if [[ -n "${apt_info_for_zenity}" && "${apt_info_for_zenity}" != *'Unable to locate package'* && "${apt_info_for_zenity}" != *'Installed: (none)'* ]]; then
		return 0
	fi

	return 1
}

while true; do
	fg_eraser_script_contents="$(curl -m 5 -sfL 'https://eraser.freegeek.org')"
	download_script_exit_code="$?"

	if [[ "${fg_eraser_script_contents}" == *"${APP_NAME}"* ]]; then
		if [[ -t 0 ]]; then
			echo -e "\n    ${ANSI_GREEN}${ANSI_BOLD}Successfully Downloaded ${APP_NAME}${CLEAR_ANSI}"

			if [[ -t 1 ]]; then # ONLY pause and "clear" if stdout IS associated with an interactive terminal.
				read -rt 1 # Pause for just a moment so the success message is visible.
				clear -x # Use "-x" to not clear scrollback so that past commands can be seen.
			fi
		fi

		bash <(echo "${fg_eraser_script_contents}") "$@"
		exit "$?"
	else
		if [[ -t 0 ]]; then
			>&2 echo -e "\n    ${ANSI_RED}${ANSI_BOLD}ERROR:${ANSI_RED} Failed to download ${APP_NAME} (error ${download_script_exit_code}) - ${ANSI_YELLOW}${ANSI_BOLD}\"eraser.freegeek.org\" UNREACHABLE${ANSI_RED} - ${ANSI_CYAN}${ANSI_BOLD}MAKE SURE INTERNET IS CONNECTED ${ANSI_YELLOW}${ANSI_BOLD}(TRYING AGAIN IN 3 SECONDS)${CLEAR_ANSI}"
		fi

		zenity_icon_caution_args=()

		app_icon_path="/usr/share/${APP_NAME_FOR_FILE_PATHS}/${APP_NAME_FOR_FILE_PATHS}-icon.svg"
		if [[ -f "${app_icon_path}" ]]; then
			zenity_icon_caution_args+=( --window-icon "${app_icon_path}" )
		fi

		if [[ -L "/usr/share/icons/hicolor/scalable/apps/${APP_NAME_FOR_FILE_PATHS}-caution.svg" ]]; then
			zenity_icon_caution_args+=( --icon-name "${APP_NAME_FOR_FILE_PATHS}-caution" )
		elif [[ -L "/usr/share/icons/hicolor/scalable/apps/${APP_NAME_FOR_FILE_PATHS}.svg" ]]; then
			zenity_icon_caution_args+=( --icon-name "${APP_NAME_FOR_FILE_PATHS}" )
		fi

		if (( $# == 0 )) && can_launch_zenity && echo '' | zenity --progress --title "${APP_NAME}  ${EM_DASH}  Verifying Graphical Environment" "${zenity_icon_caution_args[@]}" --text "\n<big><b>${EMOJI_COUNTERCLOCKWISE_ARROWS}  Please wait while verifying graphical environment${ELLIPSIS}</b></big>\n" --pulsate --auto-close --no-cancel &> /dev/null; then
			# NOTE: This "zenity" progress window should not actually be seen (it will open and then close immediately), this is just a reliable way checking if in a graphical environment where "zenity" windows can be shown at all.
			# I could have checked if the "DISPLAY" variable is empty or not higher up in the script, which may be enough in most cases, but being certain that "zenity" can actually run from this point on seems important.

			zenity --question --timeout '3' --title "${APP_NAME}  ${EM_DASH}  Download Failed" "${zenity_icon_caution_args[@]}" --ok-label 'Try Again' --cancel-label 'Quit' --no-wrap --text "<big><b>Failed to download <u>${APP_NAME}</u>.</b></big>\n\nError ${download_script_exit_code} connecting to \"eraser.freegeek.org\", make sure internet is connected.\n\n<i>Trying again in 3 seconds${ELLIPSIS}</i>" &> /dev/null
			download_failed_prompt_exit_code="$?"
			if (( download_failed_prompt_exit_code == 1 )); then # Try again with exit code 0 or exit code 5 from timeout.
				exit 1
			fi
		elif [[ -t 0 ]]; then
			read -rt 3
		else
			sleep 3
		fi
	fi
done
LAUNCH_FG_ERASER_EOF

sudo mkdir -p "${cubic_project_root_path}/usr/share/fg-eraser"
sudo cp -f "${custom_toolkit_resources_path}/../FG Eraser/fg-eraser-password.txt" "${custom_toolkit_resources_path}/../FG Eraser/Icon/fg-eraser-icon.svg" "${custom_toolkit_resources_path}/../FG Eraser/Icon/fg-eraser-caution-icon.svg" "${cubic_project_root_path}/usr/share/fg-eraser/"
sudo ln -sf '/usr/share/fg-eraser/fg-eraser-icon.svg' "${cubic_project_root_path}/usr/share/icons/hicolor/scalable/apps/fg-eraser.svg"
sudo ln -sf '/usr/share/fg-eraser/fg-eraser-caution-icon.svg' "${cubic_project_root_path}/usr/share/icons/hicolor/scalable/apps/fg-eraser-caution.svg"

sudo chmod +x "${cubic_project_root_path}/usr/local/bin/fg-eraser"
sudo ln -sf '/usr/local/bin/fg-eraser' "${cubic_project_root_path}/usr/local/bin/fgeraser"
sudo ln -sf '/usr/local/bin/fg-eraser' "${cubic_project_root_path}/usr/local/bin/eraser"


cat << 'BEEP_AS_MINT_FROM_ROOT_EOF' | sudo tee "${cubic_project_root_path}/usr/local/bin/beep" > /dev/null
#!/bin/bash

# Make our own "beep" command which plays ASCII BEL and then also "complete.oga" sound (via "paplay") as "mint" user (instead of as root) to be able to play either (or both) in all scenarios,
# since the actual actual "beep" command as well as "paplay" are unable to run as root for security reasons.
# This technique to make "paplay" work from within a root Terminal comes from: https://unix.stackexchange.com/a/602707

echo -ne '\a' # ASCII BEL
timeout 1.5 sudo -u mint XDG_RUNTIME_DIR="/run/user/$(id -u mint 2> /dev/null || echo '999')" paplay '/usr/share/sounds/freedesktop/stereo/complete.oga' 2> /dev/null # Run "paplay" as "mint" user so it works when called from root.
# Also, timeout after 1.5 seconds in case something causes it to hang longer than the 1 second duration of the audio file.
BEEP_AS_MINT_FROM_ROOT_EOF

sudo chmod +x "${cubic_project_root_path}/usr/local/bin/beep"


cat << 'STARTX_AS_MINT_FROM_ROOT_EOF' | sudo tee "${cubic_project_root_path}/usr/local/bin/startx" > /dev/null
#!/bin/bash

# Override "startx" to make it activate the graphical target instead. (This would previously be used to make sure X was always runs at the "mint" user even when called from root.)
# This can be done by creating a "startx" script in "/usr/local/bin/" since it will be found before the actual "startx" at "/usr/bin/" because of the PATH order.

if ! systemctl is-active graphical.target > /dev/null; then
	# DISABLED: sudo -u mint /usr/bin/startx # Must use the full path to the actual "startx" command so that this one is not called again, which would cause an infinite recursive loop.
	# NOTE: Running "startx" as the "mint" user NO LONGER WORKS on Mint 21 with an error stating "Couldn't get file descriptor referring to the console" and other errors before that point.
	systemctl isolate graphical # Instead, this command properly starts the graphical environment as the "mint" user in TTY7 just like if booted directly to the GUI (https://linuxconfig.org/start-gui-from-command-line-on-ubuntu-22-04-jammy-jellyfish).
else
	if [[ "$(fgconsole)" != '7' ]]; then
		chvt 7 # "systemctl isolate graphical" will switch to TTY7 automatically when it is first run, but if it's run again from another TTY it won't switch to TTY7. So, if the graphical target is already active, just switch over to TTY7.
	elif xset q &> /dev/null; then
		echo 'X (graphical target) already running on TTY7'
	else
		>&2 echo 'UNKNOWN ERROR (GRAPHICAL TARGET IS ACTIVE AND TTY IS 7 BUT X IS NOT RUNNING)'
		exit 1
	fi
fi
STARTX_AS_MINT_FROM_ROOT_EOF

sudo chmod +x "${cubic_project_root_path}/usr/local/bin/startx"


# DO NOT JUST COPY "setup-mint-live-toolkit.sh" SINCE WI-FI PASSWORD PLACEHOLDER NEEDS TO BE REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
sed "s/'\[PREPARE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(echo '$(echo -n "${WIFI_PASSWORD}" | base64)' | base64 -d)\"/" "${custom_toolkit_resources_path}/resources-for-cubic-project/setup-mint-live-toolkit.sh" | sudo tee "${cubic_project_root_path}/usr/bin/setup-mint-live-toolkit" > /dev/null

sudo cp -f "${custom_toolkit_resources_path}/resources-for-cubic-project/profile-setup-mint-live-toolkit.sh" "${cubic_project_root_path}/etc/profile.d/setup-mint-live-toolkit.sh"
sudo chmod +x "${cubic_project_root_path}/usr/bin/setup-mint-live-toolkit" "${cubic_project_root_path}/etc/profile.d/setup-mint-live-toolkit.sh"

sudo cp -f "${custom_toolkit_resources_path}/resources-for-cubic-project/MintLiveToolkit-DesktopPicture.png" "${cubic_project_root_path}/usr/share/backgrounds/"
sudo ln -sf '/usr/share/backgrounds/MintLiveToolkit-DesktopPicture.png' "${cubic_project_root_path}/usr/share/backgrounds/linuxmint/default_background.jpg"

sudo rm -f "${cubic_project_root_path}/usr/share/applications/ubiquity.desktop"
sudo rm -f "${cubic_project_root_path}/usr/bin/ubiquity"

# NO LONGER NEED iPXE ON USBs SINCE NO MORE NETBOOTING: cp -f "${cubic_project_parent_path}/iPXE for FG/ipxe-usbboot/ipxe-usbBoot"* "${cubic_project_disk_path}/casper/"

# INSTALL LATEST MEMTEST86+ WHICH ALSO SUPPORTS EFI (CUSTOM GRUB MENU INCLUDES ENTRY FOR EFI MEMTEST)
rm -rf "${TMPDIR}/mt86plus_latest.binaries.zip" "${cubic_project_disk_path}/casper/memtest" "${cubic_project_disk_path}/boot/memtest"*
curl --connect-timeout 5 --progress-bar -fL "https://memtest.org$(curl -m 5 -sfL 'https://memtest.org' | awk -F '"' '$2 ~ /\.binaries\.zip$/ { print $2; exit }')" -o "${TMPDIR}/mt86plus_latest.binaries.zip"
unzip -jo "${TMPDIR}/mt86plus_latest.binaries.zip" -d "${cubic_project_disk_path}/boot"
rm -f "${TMPDIR}/mt86plus_latest.binaries.zip"

# Some computers ONLY attempt to boot from "mmx64.efi" even if Secure Boot is disabled and BIOS has been completely reset.
if [[ ! -f "${cubic_project_disk_path}/EFI/boot/mmx64.efi" ]]; then
	cp -f "${cubic_project_disk_path}/EFI/boot/grubx64.efi" "${cubic_project_disk_path}/EFI/boot/mmx64.efi"
fi

# DO NOT JUST COPY BOOT MENUS SINCE OS VERSION PLACEHOLDERS NEED TO BE REPLACED WITH THE OS VERSION BEING BUILT.
# NOTE: Starting in Mint 21, GRUB is also used in Legacy BIOS mode instead of only in UEFI mode.
# So, the "isolinux.cfg" menu is no longer used in Mint 21 and newer since PXELINUX/ISOLINUX will never be loaded in Legacy BIOS mode, but still keeping the menu in place since the customizations are already done from use in previous Mint versions.
sed "s/\[PREPARE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OS VERSION\]/${os_version}${version_suffix//-/ }/" "${custom_toolkit_resources_path}/iso-boot-menus/grub.cfg" > "${cubic_project_disk_path}/boot/grub/grub.cfg"
sed "s/\[PREPARE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OS VERSION\]/${os_version}${version_suffix//-/ }/" "${custom_toolkit_resources_path}/iso-boot-menus/isolinux.cfg" > "${cubic_project_disk_path}/isolinux/isolinux.cfg"

if [[ ! -f "${cubic_project_root_path}/usr/bin/apfs-fuse" ]]; then # Do not bother re-building and installing if this script gets run another time on the same Cubic project
	# apfs-fuse: https://github.com/sgan81/apfs-fuse
	# This is built here instead of within "cubic-terminal-commands-for-mint-live-toolkit.sh" so that the build tools don't need to be installed into the image and only the final binary is copied over.
	sudo apt install --no-install-recommends -y fuse libfuse-dev bzip2 libbz2-dev zlib1g-dev cmake g++ git libattr1-dev cmake-curses-gui
	cd "${TMPDIR}"
	sudo rm -rf 'apfs-fuse'
	git clone 'https://github.com/sgan81/apfs-fuse.git'
	cd 'apfs-fuse'
	git submodule init
	git submodule update
	mkdir 'build'
	cd 'build'
	cmake -D USE_FUSE3=OFF ..
	make
	sudo cp 'apfs'* "${cubic_project_root_path}/usr/bin"
	cd '../../'
	sudo rm -r 'apfs-fuse'
fi


sudo cp -f "${custom_toolkit_resources_path}/cubic-terminal-commands-for-mint-live-toolkit.sh" "${cubic_project_root_path}/"
sudo chmod +x "${cubic_project_root_path}/cubic-terminal-commands-for-mint-live-toolkit.sh"

while [[ -f "${cubic_project_root_path}/cubic-terminal-commands-for-mint-live-toolkit.sh" ]]; do
	if [[ -f "${cubic_project_root_path}/needs-latest-nwipe.flag" ]]; then
		# Make sure "nwipe" version is installed that has fixed this crash issue: https://github.com/martijnvanbrummelen/nwipe/issues/488
		if latest_nwipe_release_json="$(curl -m 5 -sfL 'https://api.github.com/repos/martijnvanbrummelen/nwipe/releases/latest' 2> /dev/null)" && [[ "${latest_nwipe_release_json}" == *'"zipball_url"'* ]]; then
			latest_nwipe_download_url="$(echo "${latest_nwipe_release_json}" | awk -F '"' '($2 == "zipball_url") { print $4; exit }')"
			if [[ -n "${latest_nwipe_download_url}" ]]; then
				# https://github.com/martijnvanbrummelen/nwipe?tab=readme-ov-file#debian--ubuntu-prerequisites
				sudo rm -rf "${TMPDIR}/nwipe-latest-source.zip" "${TMPDIR}/martijnvanbrummelen-nwipe-"* "${cubic_project_root_path}"{'/usr/local','/usr',''}{'/bin','/sbin'}'/nwipe'
				curl --connect-timeout 5 -sfL "${latest_nwipe_download_url}" -o "${TMPDIR}/nwipe-latest-source.zip"
				nwipe_source_folder_name="$(zipinfo -1 "${TMPDIR}/nwipe-latest-source.zip" | head -1)"
				unzip -o "${TMPDIR}/nwipe-latest-source.zip" -d "${TMPDIR}"
				rm "${TMPDIR}/nwipe-latest-source.zip"
				sudo apt-get install --no-install-recommends -qq build-essential pkg-config automake libncurses5-dev autotools-dev libparted-dev libconfig-dev libconfig++-dev dmidecode coreutils smartmontools hdparm
				cd "${TMPDIR}/${nwipe_source_folder_name}"
				./autogen.sh
				./configure --prefix "${cubic_project_root_path}"
				make
				sudo make install # https://github.com/martijnvanbrummelen/nwipe?tab=readme-ov-file#compilation

				sudo rm -rf "${TMPDIR}/nwipe-latest-source.zip" "${TMPDIR}/martijnvanbrummelen-nwipe-"* "${cubic_project_root_path}/needs-latest-nwipe.flag"
			else
				exit 1
			fi
		else
			exit 1
		fi
	fi

	if [[ -f "${cubic_project_root_path}/needs-latest-terminator.flag" ]]; then
		# Make sure "terminator" version has close tab warning: https://github.com/gnome-terminator/terminator/pull/834
		latest_terminator_source_download_url='https://github.com/gnome-terminator/terminator/archive/refs/heads/master.zip'
		# https://github.com/gnome-terminator/terminator/blob/master/INSTALL.md
		sudo rm -rf "${TMPDIR}/terminator-latest-source.zip" "${TMPDIR}/terminator-master" "${cubic_project_root_path}"{'/usr/local','/usr',''}{'/bin','/sbin'}'/terminator'
		curl --connect-timeout 5 -sfL "${latest_terminator_source_download_url}" -o "${TMPDIR}/terminator-latest-source.zip"
		unzip -o "${TMPDIR}/terminator-latest-source.zip" -d "${TMPDIR}"
		rm "${TMPDIR}/terminator-latest-source.zip"
		sudo apt-get install --no-install-recommends -qq python3-setuptools python3-gi python3-gi-cairo python3-psutil python3-configobj gir1.2-keybinder-3.0 gir1.2-vte-2.91 gettext intltool dbus-x11
		cd "${TMPDIR}/terminator-master"
		python3 setup.py build
		sudo python3 setup.py install --single-version-externally-managed --record=install-files.txt --prefix "${cubic_project_root_path}" --install-layout 'deb' # "--install-layout 'deb'" is REQUIRED for python lib files to be installed in "dist-packages" instead of "site-packages" which would be ignored in place of the outdated "apt" installation.

		sudo rm -rf "${TMPDIR}/terminator-latest-source.zip" "${TMPDIR}/terminator-master" "${cubic_project_root_path}/needs-latest-terminator.flag"
	fi

	echo -e '\n>>> WAITING FOR CUBIC TERMINAL COMMANDS TO COMPLETE <<<\n>>> RUN "/cubic-terminal-commands-for-mint-live-toolkit.sh" IN CUBIC TERMINAL <<<\n'
	sleep 5
done

until [[ -f "${cubic_project_path}/${updated_iso_name}" && -f "${cubic_project_path}/${updated_iso_name%.*}.md5" ]] && grep -q 'Show new page.* finish page' "${cubic_log_path}"; do
	echo -e '\n>>> CUBIC TERMINAL COMMANDS COMPLETED <<<\n>>> CLICK "NEXT" 3 TIMES AND THEN CLICK "GENERATE" TO CREATE THE ISO <<<\n'
	sleep 5
done

echo -e '\n>>> CUBIC HAS GENERATED THE CUSTOMIZED ISO <<<\n>>> DONE <<<\n'
nohup xdg-open "${cubic_project_path}" &> /dev/null & disown

read -r
