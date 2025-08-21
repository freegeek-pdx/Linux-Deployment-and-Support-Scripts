#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

if [[ "$(hostname)" == 'cubic' && -f '/usr/bin/setup-fg-eraser-live' ]]; then
	echo -e '\n\nINSTALLING FG ERASER PACKAGES\n'

	apt install --no-install-recommends -y util-linux curl unzip network-manager dmidecode smartmontools libxml2-utils hdparm sg3-utils nvme-cli e2fsprogs mdadm nwipe terminator || exit 1


	if ! apt-cache policy zenity | grep -qF 'Candidate: 3.'; then # DO NOT want to install Zenity 4 on Debian 13 because GTK 4 theme looks bad (doesn't match openbox theme, huge buttons, bad contrast with tables). So must manually download and install older ".deb" since only Zenity 4 is in the repositories for Debian 13.
		echo -e '\n\nDOWNLOADING ZENITY 3\n'

		zenity_download_directory_url='http://http.us.debian.org/debian/pool/main/z/zenity'
		zenity_download_directory_contents="$(curl -m 5 -sfL "${zenity_download_directory_url}" 2> /dev/null || exit 1)"

		curl --connect-timeout 5 --progress-bar -fL "${zenity_download_directory_url}/$(echo "${zenity_download_directory_contents}" | xmllint --html --xpath 'string((//a[starts-with(@href,"zenity-common_3") and contains(@href,"all.deb")])[last()]/@href)' - 2> /dev/null || exit 1)" -o '/tmp/install-zenity_common_3.deb' || exit 1
		curl --connect-timeout 5 --progress-bar -fL "${zenity_download_directory_url}/$(echo "${zenity_download_directory_contents}" | xmllint --html --xpath 'string((//a[starts-with(@href,"zenity_3") and contains(@href,"amd64.deb")])[last()]/@href)' - 2> /dev/null || exit 1)" -o '/tmp/install-zenity_3.deb' || exit 1
	fi

	echo -e '\n\nINSTALLING ZENITY 3\n'

	apt install --no-install-recommends -y "$([[ -f '/tmp/install-zenity_common_3.deb' ]] && echo '/tmp/install-zenity_common_3.deb' || echo 'zenity-common')" "$([[ -f '/tmp/install-zenity_3.deb' ]] && echo '/tmp/install-zenity_3.deb' || echo 'zenity')" || exit 1
	rm -f '/tmp/install-zenity_common_3.deb' '/tmp/install-zenity_3.deb' || exit 1

	if ! apt-cache policy zenity | grep -FB 1 'Installed: 3.' || ! apt-cache policy zenity-common | grep -FB 1 'Installed: 3.'; then
		apt-cache policy zenity zenity-common

		echo -e '\nERROR: FAILED TO INSTALL ZENITY 3'
		exit 1
	fi


	min_nwipe_version='0.35' # Make sure "nwipe" version is installed that has fixed this crash issue: https://github.com/martijnvanbrummelen/nwipe/issues/488
	nwipe_version="$(nwipe -V 2> /dev/null | tr -dc '0123456789.')"
	if [[ -z "${nwipe_version}" || ( "${nwipe_version}" != "${min_nwipe_version}" && "$(echo -e "${nwipe_version}\n${min_nwipe_version}" | sort -V)" == *$'\n'"${min_nwipe_version}" ) ]]; then
		apt install --no-install-recommends -y libconfig-dev # NOTE: "libconfig-dev" is required for newer "nwipe" built from source (which will be done by prepare script).

		touch '/needs-latest-nwipe.flag'
		while [[ -f '/needs-latest-nwipe.flag' ]]; do
			echo -e '\n>>> WAITING FOR LATEST NWIPE TO BE INSTALLED BY PREPARE SCRIPT <<<'
			sleep 5
		done

		nwipe_version="$(nwipe -V 2> /dev/null | tr -dc '0123456789.')"
		if [[ -z "${nwipe_version}" || ( "${nwipe_version}" != "${min_nwipe_version}" && "$(echo -e "${nwipe_version}\n${min_nwipe_version}" | sort -V)" == *$'\n'"${min_nwipe_version}" ) ]]; then
			echo -e '\nERROR: FAILED TO INSTALL LATEST NWIPE'
			exit 1
		fi
	fi


	# Make sure "terminator" version has close tab warning: https://github.com/gnome-terminator/terminator/pull/834
	# NOTE: Cannot run "terminator -v" in NON-GUI environment. Also, 2.1.3 is latest release version, BUT latest source build that we ACTUALLY need doesn't yet have version updated and would still show 2.1.3, so instead of checking for a specific version, check the "man" page for the "ask_before_closing" config key that we require.
	if ! zgrep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5.gz' 2> /dev/null && ! grep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5' 2> /dev/null; then # "apt" installed "terminator" will have compressed "man" page, but manually installed (as done below) will be uncompressed.
		touch '/needs-latest-terminator.flag'
		while [[ -f '/needs-latest-terminator.flag' ]]; do
			echo -e '\n>>> WAITING FOR LATEST TERMINATOR TO BE INSTALLED BY PREPARE SCRIPT <<<'
			sleep 5
		done

		if ! zgrep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5.gz' 2> /dev/null && ! grep -qF 'ask_before_closing' {'/usr/local','/usr',''}'/share/man/man5/terminator_config.5' 2> /dev/null; then # "apt" installed "terminator" will have compressed "man" page, but manually installed (as done below) will be uncompressed.
			echo -e '\nERROR: FAILED TO INSTALL LATEST TERMINATOR'
			exit 1
		fi
	fi



	echo -e '\n\nINSTALLING OPENBOX GUI\n'

	apt install --no-install-recommends -y xorg openbox tint2 hsetroot rfkill dbus-x11 gir1.2-notify-0.7 systemd-timesyncd || exit 1
	# "tint2" is to include a dock/panel bar in "openbox".
	# "hsetroot" and "rfkill" are used by "setup-fg-eraser-live" script.
	# "dbus-x11" solves Terminator "Unable to connect to DBUS Server, proceeding as standalone" and allows Terminator to be able to open new tabs: https://askubuntu.com/a/1006361
	# "gir1.2-notify-0.7" solves Terminator "ActivityWatch plugin unavailable as we cannot import Notify" error: https://stackoverflow.com/a/48030462
	# "systemd-timesyncd" allows time sync to work (which is done in "setup-fg-eraser-live" script)



	echo -e '\n\nAUTO-REMOVE AFTER ALL APT INSTALLATIONS\n'

	apt autoremove -y || exit 1



	echo -e '\n\nINSTALLING HD SENTINEL\n'
	# hdsentinel: https://www.hdsentinel.com/hard_disk_sentinel_linux.php

	curl --connect-timeout 5 --progress-bar -fL "$(curl -m 5 -sfL 'https://www.hdsentinel.com/hard_disk_sentinel_linux.php' 2> /dev/null | awk -F '"' '/x64.zip/ { print $2; exit }')" -o "${TMPDIR}/hdsentinel-latest-x64.zip" || exit 1
	unzip -o "${TMPDIR}/hdsentinel-latest-x64.zip" -d "${TMPDIR}" || exit 1
	rm "${TMPDIR}/hdsentinel-latest-x64.zip" || exit 1
	mv "${TMPDIR}/HDSentinel" '/usr/bin/hdsentinel' || exit 1
	chmod +x '/usr/bin/hdsentinel' || exit 1



	echo -e '\n\nCONFIGURING TERMINATOR\n'

	sed -i 's/^Exec=terminator/Exec=sudo -i terminator --maximize/' '/usr/share/applications/terminator.desktop' # Make GUI launcher always open maximized root terminal.

	mkdir -p '/etc/xdg/terminator'
	echo '[global_config]
  ask_before_closing = always
[profiles]
  [[default]]
    scrollback_infinite = True' > '/etc/xdg/terminator/config'




	echo -e '\n\nSETTING UP OPENBOX\n'
	cat << 'OPENBOX_AUTOSTART_EOF' > '/etc/xdg/openbox/autostart' # http://openbox.org/wiki/Help:Autostart
/usr/bin/setup-fg-eraser-live &
OPENBOX_AUTOSTART_EOF

	sed -i 's|<number>4</number>|<number>1</number>|' '/etc/xdg/openbox/rc.xml' # Set default number of desktops from 4 to 1.

	cat << 'OPENBOX_MENU_EOF' > '/etc/xdg/openbox/menu.xml' # http://openbox.org/wiki/Help:Menus
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://openbox.org/ file:///usr/share/openbox/menu.xsd">
  <menu id="root-menu" label="Openbox">
    <item label="FG Eraser"><action name="Execute"><execute>sudo -i fg-eraser</execute></action></item>
    <item label="Terminal"><action name="Execute"><execute>sudo -i terminator --maximize</execute></action></item>
    <separator />
    <item label="Reboot or Shut Down"><action name="Execute"><execute>power-prompt</execute></action></item>
  </menu>
</openbox_menu>
OPENBOX_MENU_EOF



	echo -e '\n\nSETTING TINT2 THEME\n'
	cat << 'TINT2_THEME_EOF' > '/etc/xdg/tint2/tint2rc' # https://gitlab.com/o9000/tint2/blob/master/doc/tint2.md (this is a customized version of "/usr/share/tint2/horizontal-light-opaque.tint2rc")
#---- Generated by tint2conf f101 ----
# See https://gitlab.com/o9000/tint2/wikis/Configure for 
# full documentation of the configuration options.
#-------------------------------------
# Gradients
#-------------------------------------
# Backgrounds
# Background 1: Panel
rounded = 0
border_width = 1
border_sides = TBLR
background_color = #eeeeee 100
border_color = #bbbbbb 100
background_color_hover = #eeeeee 100
border_color_hover = #bbbbbb 100
background_color_pressed = #eeeeee 100
border_color_pressed = #bbbbbb 100

# Background 2: Default task, Iconified task
rounded = 5
border_width = 1
border_sides = TBLR
background_color = #eeeeee 100
border_color = #eeeeee 100
background_color_hover = #eeeeee 100
border_color_hover = #cccccc 100
background_color_pressed = #cccccc 100
border_color_pressed = #cccccc 100

# Background 3: Active task
rounded = 5
border_width = 1
border_sides = TBLR
background_color = #dddddd 100
border_color = #999999 100
background_color_hover = #eeeeee 100
border_color_hover = #aaaaaa 100
background_color_pressed = #cccccc 100
border_color_pressed = #999999 100

# Background 4: Urgent task
rounded = 5
border_width = 1
border_sides = TBLR
background_color = #aa4400 100
border_color = #aa7733 100
background_color_hover = #aa4400 100
border_color_hover = #aa7733 100
background_color_pressed = #aa4400 100
border_color_pressed = #aa7733 100

# Background 5: Tooltip
rounded = 2
border_width = 1
border_sides = TBLR
background_color = #ffffaa 100
border_color = #999999 100
background_color_hover = #ffffaa 100
border_color_hover = #999999 100
background_color_pressed = #ffffaa 100
border_color_pressed = #999999 100

# Background 6: Inactive desktop name
rounded = 2
border_width = 1
border_sides = TBLR
background_color = #eeeeee 100
border_color = #cccccc 100
background_color_hover = #eeeeee 100
border_color_hover = #cccccc 100
background_color_pressed = #eeeeee 100
border_color_pressed = #cccccc 100

# Background 7: Active desktop name
rounded = 2
border_width = 1
border_sides = TBLR
background_color = #dddddd 100
border_color = #999999 100
background_color_hover = #dddddd 100
border_color_hover = #999999 100
background_color_pressed = #dddddd 100
border_color_pressed = #999999 100

# Background 8: Systray
rounded = 3
border_width = 0
border_sides = TBLR
background_color = #dddddd 100
border_color = #cccccc 100
background_color_hover = #dddddd 100
border_color_hover = #cccccc 100
background_color_pressed = #dddddd 100
border_color_pressed = #cccccc 100

#-------------------------------------
# Panel
panel_items = LTCB
panel_size = 100% 32
panel_margin = 0 0
panel_padding = 4 2 4
panel_background_id = 1
wm_menu = 1
panel_dock = 0
panel_position = bottom center horizontal
panel_layer = normal
panel_monitor = all
panel_shrink = 0
autohide = 0
autohide_show_timeout = 0
autohide_hide_timeout = 0.5
autohide_height = 2
strut_policy = follow_size
panel_window_name = tint2
disable_transparency = 0
mouse_effects = 1
font_shadow = 0
mouse_hover_icon_asb = 100 0 10
mouse_pressed_icon_asb = 100 0 0

#-------------------------------------
# Taskbar
taskbar_mode = single_desktop
taskbar_hide_if_empty = 0
taskbar_padding = 0 0 2
taskbar_background_id = 0
taskbar_active_background_id = 0
taskbar_name = 0
taskbar_hide_inactive_tasks = 0
taskbar_hide_different_monitor = 0
taskbar_hide_different_desktop = 0
taskbar_always_show_all_desktop_tasks = 0
taskbar_name_padding = 6 3
taskbar_name_background_id = 6
taskbar_name_active_background_id = 7
taskbar_name_font = sans bold 9
taskbar_name_font_color = #222222 100
taskbar_name_active_font_color = #222222 100
taskbar_distribute_size = 1
taskbar_sort_order = none
task_align = left

#-------------------------------------
# Task
task_text = 1
task_icon = 1
task_centered = 1
urgent_nb_of_blink = 100000
task_maximum_size = 140 35
task_padding = 4 3 4
task_font = sans 8
task_tooltip = 1
task_font_color = #222222 100
task_icon_asb = 100 0 0
task_background_id = 2
task_active_background_id = 3
task_urgent_background_id = 4
task_iconified_background_id = 2
mouse_left = toggle_iconify
mouse_middle = none
mouse_right = close
mouse_scroll_up = prev_task
mouse_scroll_down = next_task

#-------------------------------------
# System tray (notification area)
systray_padding = 4 0 2
systray_background_id = 8
systray_sort = ascending
systray_icon_size = 22
systray_icon_asb = 100 0 0
systray_monitor = 1
systray_name_filter = 

#-------------------------------------
# Launcher
launcher_padding = 10 0 15
launcher_background_id = 0
launcher_icon_background_id = 0
launcher_icon_size = 22
launcher_icon_asb = 100 0 0
launcher_icon_theme_override = 0
startup_notifications = 1
launcher_tooltip = 1
launcher_item_app = power-prompt.desktop
launcher_item_app = terminator.desktop
launcher_item_app = fg-eraser.desktop

#-------------------------------------
# Clock
time1_format = %-I:%M:%S %p
time2_format = %a %B %-d, %Y
time1_font = sans bold 8
time1_timezone = 
time2_timezone = 
time2_font = sans 7
clock_font_color = #222222 100
clock_padding = 10 0
clock_background_id = 0
clock_tooltip = 
clock_tooltip_timezone = 
clock_lclick_command = 
clock_rclick_command = orage
clock_mclick_command = 
clock_uwheel_command = 
clock_dwheel_command = 

#-------------------------------------
# Battery
battery_tooltip = 1
battery_low_status = 10
battery_low_cmd = 
battery_full_cmd = 
bat1_font = sans 8
bat2_font = sans 6
battery_font_color = #222222 100
bat1_format = 
bat2_format = 
battery_padding = 10 0
battery_background_id = 0
battery_hide = 101
battery_lclick_command = 
battery_rclick_command = 
battery_mclick_command = 
battery_uwheel_command = 
battery_dwheel_command = 
ac_connected_cmd = 
ac_disconnected_cmd = 

#-------------------------------------
# Tooltip
tooltip_show_timeout = 0.5
tooltip_hide_timeout = 0.1
tooltip_padding = 2 2
tooltip_background_id = 5
tooltip_font_color = #222222 100
tooltip_font = sans 9
TINT2_THEME_EOF



	newest_kernel_version="$(find '/usr/lib/modules' -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -rV | head -1)" # DO NOT use "uname -r" in the Cubic Terminal to get the kernel version since it returns the kernel version of the HOST OS rather than the CUSTOM ISO OS that has just been updated and they are not guaranteed to be the same.

	echo -e "\n\nINCLUDING USB NETWORK ADAPTER MODULES IN INITRAMFS (${newest_kernel_version})\n"
	# Must be done after system updated or anything that would update initramfs

	find "/usr/lib/modules/${newest_kernel_version}/kernel/drivers/net/usb" -type f -exec basename {} '.ko' \;  > '/usr/share/initramfs-tools/modules.d/network-usb-modules'
	echo -e "ALL USB NETWORK MODULES: $(paste -sd ',' '/usr/share/initramfs-tools/modules.d/network-usb-modules')\n"

	orig_initramfs_config="$(< '/etc/initramfs-tools/initramfs.conf')"
	sed -i 's/COMPRESS=.*/COMPRESS=xz/' '/etc/initramfs-tools/initramfs.conf' || exit 1
	# Use "xz" compression so the "initrd" file is as small as possible since it will be downloaded in advance over the network via iPXE and decompressed all at once,
	# unlike the "sqaushfs" where we specifically don't want to use "xz" compression (see comments in "prepare-cubic-project-for-fg-eraser-live.sh" for more info about that).
	# Even though "xz" decompression is slower than "zstd" or other compressions, since the file is relatively small the different decompression speeds are not noticable when booting.
	# Changing the compression also makes Cubic update the "initrd.lz" extension to "initrd.xz" so that needs to be used in all boot menus,
	# but Cubic automatically updates the boot menu files to use the right extensions anyways,
	# and the "ipxe-linux-booter.php" when booting via iPXE will find the "initrd" file with any extension).

	update-initramfs -vu || exit 1 # Create new custom "initrd" file with the added modules.
	rm '/usr/share/initramfs-tools/modules.d/network-usb-modules' || exit 1 # Reset modules and configuration to default
	echo "${orig_initramfs_config}" > '/etc/initramfs-tools/initramfs.conf' # to not affect future updates of installed os.



	echo -e '\n\nDISABLING UNNECESSARY SERVICES TO SPEED UP BOOT AND SHUTDOWN\n'
	systemctl disable NetworkManager-wait-online # https://mike42.me/blog/how-to-boot-debian-in-4-seconds (but we want "systemd-timesyncd" so that "setup-fg-eraser-live" script can make sure time is synced)
	systemctl disable cups cups-browsed # Don't need printing (seen CUPS sometimes hang a bit on shutdown): https://unix.stackexchange.com/a/480124
	systemctl disable bluetooth exim4 # Don't need bluetooth or email services (just removing extra things that aren't necessary).


	echo -e '\n\nUPDATING /ETC/ISSUE FILE\n'

	echo -e "  FG Eraser Live\n\n  \\l\n" > '/etc/issue'



	echo -e '\n\nSUCCESSFULLY COMPLETED FG ERASER LIVE CUBIC TERMINAL COMMANDS'

	rm -f '/'*'.sh' '/root/'*'.sh'
elif [[ "$(hostname)" != 'cubic' ]]; then
	echo '!!! THIS SCRIPT MUST BE RUN IN CUBIC TERMINAL !!!'
	echo '>>> YOU CAN DRAG-AND-DROP THIS SCRIPT INTO THE CUBIC TERMINAL WINDOW TO COPY AND THEN RUN IT FROM WITHIN THERE <<<'
	read -r
else
	echo 'YOU MUST RUN "prepare-cubic-project-for-fg-eraser-live.sh" FROM THE LOCAL OS FIRST'
fi
