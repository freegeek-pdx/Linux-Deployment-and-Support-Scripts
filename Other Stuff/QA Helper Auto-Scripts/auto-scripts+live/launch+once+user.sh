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

if [[ ! -f "${HOME}/.linuxmint/mintwelcome/norun.flag" ]]; then
    echo 'CLOSING WELCOME SCREEN'
    wmctrl -c 'Welcome'
    mkdir -p "${HOME}/.linuxmint/mintwelcome"
    touch "${HOME}/.linuxmint/mintwelcome/norun.flag"
fi


if [[ "$(gsettings get com.linuxmint.updates show-welcome-page)" != 'false' ]]; then
    echo 'PREVENTING UPDATE MANAGER FROM OPENING AUTOMATICALLY'
    # https://github.com/linuxmint/mintupdate/commit/82453c34788e25a6781133988966200f9c13042d
    killall mintUpdate 2> /dev/null # Running process name has capitol "U" (must be quit even if window hasn't opened yet because it is running with status bar item).
    gsettings set com.linuxmint.updates show-welcome-page false
    nohup /usr/lib/linuxmint/mintUpdate/mintUpdate.py &> /dev/null & disown # Re-launch without showing window (using "mintupdate" launcher executable will show window).
fi


if ! crontab -l 2> /dev/null | grep -qF 'launch-qa-helper'; then
    echo 'ADDING QA HELPER TO USER CRON JOBS TO LAUNCH EVERY 30 MINUTES'
    # Suppress ShellCheck warning that "DESKTOP_SESSION" and "XDG_CURRENT_DESKTOP" are referenced but not assigned since they will actually be assigned by the environment when this script is run on Linux.
    # shellcheck disable=SC2154
    echo -e "$(crontab -l 2> /dev/null)\n*/30 * * * * DISPLAY='${DISPLAY}' DESKTOP_SESSION='${DESKTOP_SESSION}' XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP}' ${HOME}/.local/qa-helper/launch-qa-helper no-focus 2>&1 | logger -t launch-qa-helper" | crontab -
fi


echo 'TURNING ON WI-FI'
nmcli radio all on


echo 'ENABLING TOUCHPAD TAP-TO-CLICK'
gsettings set org.cinnamon.desktop.peripherals.touchpad tap-to-click true


echo 'TURNING OFF ALL SLEEP & LOCK SETTINGS'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0

gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-battery-action 'nothing'

gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false

gsettings set org.cinnamon.desktop.session idle-delay 0

gsettings set org.cinnamon.desktop.screensaver lock-enabled false


echo 'RANDOMIZING DESKTOP BACKGROUNDS'
gsettings set org.cinnamon.desktop.background.slideshow slideshow-enabled true
gsettings set org.cinnamon.desktop.background.slideshow image-source "xml://$(find '/usr/share/cinnamon-background-properties/' -maxdepth 1 -name '*.xml' ! -name 'linuxmint.xml' | shuf -n1)"
gsettings set org.cinnamon.desktop.background.slideshow delay 10
gsettings set org.cinnamon.desktop.background.slideshow random-order true
if ! crontab -l 2> /dev/null | grep -qF 'random-slideshow-image-source'; then
    echo -e "$(crontab -l 2> /dev/null)\n15 * * * * DISPLAY='${DISPLAY}' gsettings set org.cinnamon.desktop.background.slideshow image-source \"xml://\$(find '/usr/share/cinnamon-background-properties/' -maxdepth 1 -name '*.xml' ! -name 'linuxmint.xml' | shuf -n1)\" 2>&1 | logger -t random-slideshow-image-source" | crontab -
fi


echo 'SETTING PANEL CLOCK FORMAT'
gsettings set org.cinnamon.desktop.interface clock-use-24h false
gsettings set org.cinnamon.desktop.interface clock-show-date true


echo 'SETTING SCREENSAVER CLOCK FORMAT'
gsettings set org.cinnamon.desktop.screensaver use-custom-format true
gsettings set org.cinnamon.desktop.screensaver time-format '%l:%M:%S %p'
gsettings set org.cinnamon.desktop.screensaver date-format '    %A %B %e, %Y'


if [[ -f '/usr/share/applications/google-chrome.desktop' ]]; then
    echo 'CONFIGURING GOOGLE CHROME TO BYPASS FIRST RUN PROMPTS'

    if [[ ! -d "${HOME}/.config/google-chrome/Default/" ]]; then
        mkdir -p "${HOME}/.config/google-chrome/Default"
    fi

    # Create "~/.config/google-chrome/First Run" file so that Google Chrome does not prompt to be default browser or to send usage stats on first launch.
    touch "${HOME}/.config/google-chrome/First Run"

    # Create "~/.config/google-chrome/Default/Preferences" JSON file with "browser.has_seen_welcome_page" value set to "true" to not show the welcome page, and the
    # "browser.default_browser_infobar_last_declined" timestamp set far in the future so the toolbar prompt to set Chrome as the default browser is never displayed.
    echo '{"browser":{"has_seen_welcome_page":true,"default_browser_infobar_last_declined":"99999999999999999"}}' > "${HOME}/.config/google-chrome/Default/Preferences"

    # Create Google Chrome launcher for OEM user which does not prompt for Keyring password: https://ubuntuforums.org/showthread.php?t=2377036&p=13708937#post13708937
    rm -f "${HOME}/.local/share/applications/google-chrome.desktop"
    desktop-file-install --dir "${HOME}/.local/share/applications/" '/usr/share/applications/google-chrome.desktop'
    sed -i 's|^Exec=/usr/bin/google-chrome-stable |Exec=/usr/bin/google-chrome-stable --password-store=basic |; s|^Exec=/usr/bin/google-chrome-stable$|Exec=/usr/bin/google-chrome-stable --password-store=basic|' "${HOME}/.local/share/applications/google-chrome.desktop"
    chmod +x "${HOME}/.local/share/applications/google-chrome.desktop"
fi


if [[ ! -f "${HOME}/.config/autostart/lock_screen_slideshow.desktop" ]]; then
    echo 'ENABLING RANDOM SLIDESHOW SCREENSAVER'
    if [[ ! -d "${HOME}/.config/autostart" ]]; then
        mkdir "${HOME}/.config/autostart"
    fi

    echo -e "[Desktop Entry]\nType=Application\nExec=${HOME}/.local/qa-helper/auto-scripts/lock_screen_slideshow.sh\nX-GNOME-Autostart-enabled=true\nNoDisplay=false\nHidden=false\nName=lock_screen_slideshow.desktop\nComment=Start a background slideshow on screensaver activation\nX-GNOME-Autostart-Delay=30" > '/tmp/lock_screen_slideshow.desktop'
    desktop-file-install --delete-original --dir "${HOME}/.config/autostart/" '/tmp/lock_screen_slideshow.desktop'
    chmod +x "${HOME}/.config/autostart/lock_screen_slideshow.desktop"

    nohup "${HOME}/.local/qa-helper/auto-scripts/lock_screen_slideshow.sh" &> /dev/null & disown # nohup is needed to disconnect the process from the terminal so it can keep running after the terminal is closed.
fi


if [[ ! -d "${HOME}/Pictures/Free Geek Promo Pics" ]]; then
    echo 'DOWNLOADING FREE GEEK IMAGES FOR SLIDESHOW SCREENSAVER'
    rm -f '/tmp/qa-helper_free-geek_promo-pics.zip'
    curl --connect-timeout 5 --progress-bar -fL "http$(ping 'tools.freegeek.org' -W 2 -c 1 &> /dev/null && echo '://tools' || echo 's://apps').freegeek.org/qa-helper/download/resources/linux/free-geek_promo-pics.zip" -o '/tmp/qa-helper_free-geek_promo-pics.zip'
    unzip -qo '/tmp/qa-helper_free-geek_promo-pics.zip' -x '__MACOSX*' '.*' '*/.*' -d "${HOME}/Pictures"
    rm -f '/tmp/qa-helper_free-geek_promo-pics.zip'
fi


echo 'CONNECTING TO FREE GEEK WI-FI'
nmcli device wifi connect 'Free Geek'
