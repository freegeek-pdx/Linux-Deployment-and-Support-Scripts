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

if ! grep -qF ' boot=casper ' '/proc/cmdline'; then

	# NOTE: Not currently installing "Free Geek Support" app since Tech Support has temporarily been closed, but leaving code in place for possible future use.
	# echo 'VERIFYING FREE GEEK SUPPORT INSTALLATION'
	# if [[ ! -e '/usr/share/applications/fg-support.desktop' ]]; then
	# 	for install_free_geek_support_attempt in {1..5}; do
	# 		echo -e '\n\nPREPARING TO INSTALL FREE GEEK SUPPORT\n'
	# 		curl -m 5 -sfL 'https://apps.freegeek.org/fg-support/download/actually-install-fg-support.sh' | bash

	# 		if [[ -e '/usr/share/applications/fg-support.desktop' ]]; then
	# 			break
	# 		else
	# 			sleep "${install_free_geek_support_attempt}"
	# 		fi
	# 	done
	# fi

	echo 'VERIFYING OEM-CONFIG-GTK INSTALLATION'
	apt-get install --no-install-recommends -qq oem-config-gtk
	rm -f '/usr/share/applications/oem-config-prepare-gtk.desktop' # Remove app menu launcher file so that "oem-config-prepare" is only run via "QA Helper" which also triggers important auto-scripts.

	if [[ ! -f '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py.orig' ]] && grep -qxF '        self.watch = Gdk.Cursor.new(Gdk.CursorType.WATCH)' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py' && grep -qxF '    def do_reboot(self):' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py'; then
		echo 'MITIGATING POSSIBLE UBIQUITY/OEM-CONFIG CRASH'
		# NOTE: This mitigation should already exist in Ubiquity 24.04.3+mint18 and newer: https://github.com/linuxmint/ubiquity/issues/102

		# I don't know the root cause, but sporadically Ubiquity/oem-config can crash on boot with an error: "gdk_cursor_new_for_display: assertion 'GDK_IS_DISPLAY (display)' failed"
		# This error and the traceback back be seen in "/var/log/oem-config.log" when it happens.
		# The line triggering the error is "self.watch = Gdk.Cursor.new(Gdk.CursorType.WATCH)": https://github.com/linuxmint/ubiquity/blob/81f0fdd8af594f99d2217b7351ee0ef76837b9db/ubiquity/frontend/gtk_ui.py#L265
		# but the actual error is happening within the "Gdk.Cursor" constructor which is seemingly failing because of some issue with the display.
		# This error happens during boot when the "oem-config.service" is being started, but seemingly the display isn't ready in some way.
		# If this crash is not caught, then the entire Ubiquity process crashes and the "oem-config.service" is removed from systemd which deletes the "oem" user,
		# and the computer ends up at the login window with no users on the system and no way to recover except for re-installing the OS.
		# Instead of allowing the error to crash the entire Ubiquity process (resulting in an unrecoverable state),
		# immediately reboot the system when the error happens so that the "oem-config.service" is still in place and can run again on the next boot.
		# Since this issue is sporadic and somewhat rare, it is unlikely that it will happen again on the next boot and the end user will be able to proceed through the Ubiquity setup screens.
		# The worst case scenario would be a continuous reboot loop, but that doesn't seem likely as this issue is not that consistent.
		# Having the computer reboot without warning on boot could be startling for the end user, but that result is much better than the computer ending up at the login screen with no users and no way to recover.

		sed -i'.orig' '265s/^        self\.watch = Gdk\.Cursor\.new(Gdk\.CursorType\.WATCH)$/        try:\n            self.watch = Gdk.Cursor.new(Gdk.CursorType.WATCH)\n        except:\n            self.do_reboot()/' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py'

		if ! grep -qxF '            self.watch = Gdk.Cursor.new(Gdk.CursorType.WATCH)' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py' || ! grep -qxF '            self.do_reboot()' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py'; then
			echo 'FAILED TO MITIGATE POSSIBLE UBIQUITY/OEM-CONFIG CRASH'

			if [[ -s '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py.orig' ]]; then
				echo 'UNEXPECTED ERROR MITIGATING POSSIBLE UBIQUITY/OEM-CONFIG CRASH - REVERTING TO ORIGINAL'

				mv -f '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py'{.orig,}
			fi
		fi
	elif grep -qxF '            self.watch = Gdk.Cursor.new(Gdk.CursorType.WATCH)' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py' && grep -qxF '            self.do_reboot()' '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py'; then
		if [[ -f '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py.orig' ]]; then
			echo 'ALREADY MITIGATED POSSIBLE UBIQUITY/OEM-CONFIG CRASH'
		else
			echo 'MAINTAINERS ALREADY MITIGATED POSSIBLE UBIQUITY/OEM-CONFIG CRASH'
		fi
	elif [[ -s '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py' ]]; then
		echo 'UBIQUITY/OEM-CONFIG HAS BEEN UPDATED - CANNOT MITIGATE POSSIBLE UBIQUITY/OEM-CONFIG CRASH (OR IT HAS ALREADY BEEN MITIGATED BY THE MAINTAINERS)'
	elif [[ -s '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py.orig' ]]; then
		echo 'UNEXPECTED ERROR FROM PREVIOUSLY MITIGATING POSSIBLE UBIQUITY/OEM-CONFIG CRASH - REVERTING TO ORIGINAL'

		mv -f '/usr/lib/ubiquity/ubiquity/frontend/gtk_ui.py'{.orig,}
	fi

	echo 'VERIFYING MINT-META-CODECS INSTALLATION'
	apt-get install -qq mint-meta-codecs

	if [[ "$1" != 'qa-complete' ]] && ! pgrep -f '(driver-manager|mintdrivers)' &> /dev/null; then
		echo 'LAUNCHING DRIVER MANAGER'
		nohup driver-manager &> /dev/null & disown # Pre-launch and minimize "Driver Manager" since it can take a while to load so that it's pre-loaded by the time it's activated via QA Helper.

		apt-get install --no-install-recommends -qq xdotool &> /dev/null & # "xdotool" is required to be able to minimize the window since "wmctrl" can't do that (to keep it out of the way until it's activated via QA Helper).

		for (( wait_for_driver_manager_seconds = 0; wait_for_driver_manager_seconds < 30; wait_for_driver_manager_seconds ++ )); do
			sleep 1

			if [[ "$(wmctrl -l)"$'\n' == *$' Driver Manager\n'* ]]; then
				wmctrl -r 'Driver Manager' -e '0,-100,-100,-1,-1' # In Mint 21.1, the "Driver Manager" window will not go all the way to the top right corner if "0,0" are specified, so use "-100,-100" instead to accomodate this behavior (and "wmctrl" will not put the window off screen even if "-100" is actuall too much).
				wmctrl -F -a 'QA Helper' || wmctrl -F -a 'QA Helper  —  Loading'
				break
			fi
		done

		for (( wait_for_xdotool = 0; wait_for_xdotool < 30; wait_for_xdotool ++ )); do
			if xdotool search --name 'Driver Manager' windowminimize &> /dev/null; then
				break
			fi

			sleep 1
		done

		apt-get purge --auto-remove -qq xdotool &> /dev/null
	fi
fi
