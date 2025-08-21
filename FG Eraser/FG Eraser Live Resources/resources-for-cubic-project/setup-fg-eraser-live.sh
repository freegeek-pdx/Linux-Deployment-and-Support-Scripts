#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell
# Last Updated: 11/13/24
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

if pgrep -u user systemd &> /dev/null && [[ "$(id -un)" == 'user' && "${HOME}" == '/home/user' ]]; then # Only run if fully logged in as "user" user.
	readonly SETUP_PID="$$"
	echo -e "\n${SETUP_PID}: STARTED SETUP FG ERASER LIVE AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG


	# Pre-load the bash history so that SDA technicians can just hit up arrow in a terminal for "fg-eraser" regardless of boot mode.
	echo 'fg-eraser' | sudo tee -a '/root/.bash_history' > /dev/null


	if ! xset q &> /dev/null; then
		sleep 1

		for wait_for_X_seconds in {1..5}; do
			if xset q &> /dev/null; then
				break
			else
				sleep 1
			fi
		done

		echo -e "${SETUP_PID}:\tWAITED ${wait_for_X_seconds} SECONDS FOR FOR X AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
	fi

	if xset q &> /dev/null; then
		echo -e "${SETUP_PID}:\tDISABLING SCREEN BLANKING FOR X (${DISPLAY}) AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

		# TURN OFF X SCREEN SLEEPING
		xset s noblank
		xset s off -dpms

		if ! pidof openbox &> /dev/null; then
			sleep 1

			for wait_for_openbox_seconds in {1..5}; do
				if pidof openbox &> /dev/null; then
					break
				else
					sleep 1
				fi
			done

			echo -e "${SETUP_PID}:\tWAITED ${wait_for_openbox_seconds} SECONDS FOR FOR OPENBOX AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
		fi

		if pidof openbox &> /dev/null; then
			echo -e "${SETUP_PID}:\tPREPARING OPENBOX AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

			# CHECK RESOLUTION AND REDUCE IF HIGH RESOLUTION (RETINA/HiDPI) SCREEN
			while IFS=' x' read -r current_screen_name current_screen_resolution_width current_screen_resolution_height; do
				if (( current_screen_resolution_width > 1920 || current_screen_resolution_height > 1200 )); then
					echo -e "${SETUP_PID}:\tHALVING ${current_screen_resolution_width}x${current_screen_resolution_height} RESOLUTION FOR ${current_screen_name} AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
					xrandr --output "${current_screen_name}" --scale '0.5' # This just halves the resolution, making everything fuzzy (*NOT* HiDPI SCALED), but that's fine we just need text readable instead of tiny.
				fi
			done < <(xrandr | awk -F '[ +]' '($2 == "connected") { resolution = $3; if (resolution == "primary") { resolution = $4 }; print $1, resolution }')

			# SET DESKTOP FOR OPENBOX: http://openbox.org/wiki/Help:Autostart#Making_your_own_autostart
			hsetroot -extend '/usr/share/backgrounds/FGEraserLive-DesktopPicture.png'

			# LAUNCH TINT2 PANEL
			nohup tint2 &> /dev/null & disown


			echo -e "${SETUP_PID}:\tCHECKING FOR FG ERASER KERNEL ARGUMENTS AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

			# CHECK FOR FG ERASER BOOT ARGUMENTS TO AUTOMATICALLY LAUNCH FG ERASER FOR USAGE IN SDA
			if grep -qF ' fg-eraser' '/proc/cmdline'; then
				if grep -qF ' fg-eraser-auto-erase' '/proc/cmdline'; then
					sudo -i nohup terminator --title 'FG Eraser (Auto Erase)' --maximize --command 'fg-eraser -efqd auto' &> /dev/null & disown
				elif grep -qF ' fg-eraser-auto-verify' '/proc/cmdline'; then
					sudo -i nohup terminator --title 'FG Eraser (Auto Verify)' --maximize --command 'fg-eraser -vfd auto' &> /dev/null & disown
				else # If just "fg-eraser" argument is specified (or any other invalid argument starting with "fg-eraser"), open FG Eraser in GUI mode.
					sudo -i nohup fg-eraser &> /dev/null & disown
				fi
			else # IF NO FG ERASER KERNEL ARG, JUST OPEN MAXIMIZED ROOT TERMINAL
				sudo -i nohup terminator --maximize &> /dev/null & disown
			fi
		else
			echo "${SETUP_PID}: STOPPED SETUP FG ERASER LIVE EARLY BECAUSE OPENBOX IS NOT RUNNING AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
			exit 0 # Exit early because Openbox is not yet running, this script will be re-launched by "/etc/xdg/openbox/autostart" when X and Openbox are both running.
		fi
	elif pidof openbox &> /dev/null; then
		echo "${SETUP_PID}: STOPPED SETUP FG ERASER LIVE EARLY BECAUSE ONLY OPENBOX IS RUNNING (AND NOT X) AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
		exit 0 # Exit early because X is not yet running, this script will be re-launched by "/etc/xdg/openbox/autostart" when X and Openbox are both running.
	fi


	# WAIT A BIT BEFORE TRYING TO CONNET TO WI-FI ETC
	sleep 5


	# CONNECT TO WI-FI
	if nmcli device status | grep -qF ' wifi ' && ! nmcli device status | grep ' FG Staff' | grep -qF ' connected '; then
		for wifi_connection_attempt in {1..2}; do # Try 2 times to connect to Wi-Fi just in case it fails the first time for any reason.
			echo -e "${SETUP_PID}:\tCONNECTING TO WI-FI (ATTEMPT ${wifi_connection_attempt} OF 2) AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

			# Try to connect to "FG Staff" for fast Wi-Fi that can also connect to fglan (useful for "toram" network live boots that can continue after being disconnected from Ethernet).
			rfkill unblock all &> /dev/null
			nmcli radio all on &> /dev/null
			nmcli device wifi connect 'FG Staff' password '[PREPARE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]' &> /dev/null

			sleep 1

			if nmcli device status | grep ' FG Staff' | grep -qF ' connected '; then
				break
			fi
		done
	fi


	# SET CORRECT TIME
	if ! timedatectl status | grep -qF 'Time zone: America/Los_Angeles'; then
		echo -e "${SETUP_PID}:\tSETTING TIMEZONE AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

		# Make sure proper time is set so https download works.
		timedatectl set-timezone America/Los_Angeles &> /dev/null
		timedatectl set-ntp true &> /dev/null
	fi

	if timedatectl status | grep -qF 'System clock synchronized: no'; then
		echo -e "${SETUP_PID}:\tSTARTING WAIT FOR TIME TO SYNC AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

		timedatectl set-ntp false &> /dev/null # Turn time syncing off and then
		timedatectl set-ntp true &> /dev/null # back on to provoke faster sync attempt

		for wait_for_time_sync_seconds in {1..30}; do # Wait up to 30 seconds for time to sync becuase download can stall if time changes in the middle of it.
			sleep 1

			if timedatectl status | grep -qF 'System clock synchronized: yes'; then
				break
			fi
		done

		echo -e "${SETUP_PID}:\tFINISHED WAIT FOR TIME TO SYNC AFTER ${wait_for_time_sync_seconds} SECONDS AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
	fi

	if timedatectl status | grep -qF 'System clock synchronized: yes'; then
		echo -e "${SETUP_PID}:\tTIME SYNCED & SETTING BIOS CLOCK AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG

		# Update hardware (BIOS) clock with synced system time.
		hwclock --systohc &> /dev/null
	fi


	echo "${SETUP_PID}: FINISHED SETUP FG ERASER LIVE AT $(date)" | sudo tee -a '/setup-fg-eraser-live.log' > /dev/null # DEBUG
fi
