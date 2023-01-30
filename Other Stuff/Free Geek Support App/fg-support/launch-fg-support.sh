#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell on 05/29/19
# For Free Geek
# Last Updated: 01/17/23
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

readonly APP_NAME='Free Geek Support'
readonly APP_COMMENT='Get Tech Support from Free Geek'

if ! pidof -o %PPID -x 'fg-support.sh'; then
    readonly HOME_INSTALL_DIR="${HOME}/.local/fg-support"
    readonly GLOBAL_INSTALL_DIR='/usr/share/fg-support'

    app_icon="$([[ -f "${HOME_INSTALL_DIR}/fg-support-icon.png" ]] && echo "${HOME_INSTALL_DIR}" || echo "${GLOBAL_INSTALL_DIR}")/fg-support-icon.png"
    if [[ ! -f "${app_icon}" ]]; then
        app_icon='/usr/share/icons/Mint-Y/status/128@2x/dialog-question.png'
        if [[ ! -f "${app_icon}" ]]; then app_icon=''; fi
    fi

    # Before each launch, check for updates and install any update into HOME_INSTALL_DIR instead of GLOBAL_INSTALL_DIR since the latter would require sudo,
    # and the former will be for a user which didn't exist as the time of the original install into GLOBAL_INSTALL_DIR during original testing and deployment.
    # The latest version at HOME_INSTALL_DIR will always be launched unless an update has never been installed, in which case the version at GLOBAL_INSTALL_DIR will be run.

    current_version="$(cat "${HOME_INSTALL_DIR}/fg-support_version.txt" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_version.txt" 2> /dev/null)"

    if [[ -n "${current_version}" && "${current_version}" != *'test'* ]]; then
        if ping -W 10 -c 1 'apps.freegeek.org' &> /dev/null; then
            readonly DOWNLOAD_URL='https://apps.freegeek.org/fg-support/download'

            for (( download_newest_version_attempt = 0; download_newest_version_attempt < 5; download_newest_version_attempt ++ )); do
                if newest_version="$(curl -m 5 -sfL "${DOWNLOAD_URL}/latest-version.txt" | head -1)" && [[ -n "${newest_version}" ]]; then
                    break
                fi
            done

            if [[ -n "${newest_version}" && "${newest_version}" != *'test'* && "${newest_version}" != "${current_version}" ]]; then
                for (( download_update_attempt = 0; download_update_attempt < 5; download_update_attempt ++ )); do
                    rm -f '/tmp/fg-support.zip'

                    if curl --connect-timeout 5 --progress-bar -fL "${DOWNLOAD_URL}/fg-support.zip" -o '/tmp/fg-support.zip' && [[ -e '/tmp/fg-support.zip' ]]; then
                        if downloaded_version="$(unzip -p '/tmp/fg-support.zip' '*/fg-support_version.txt' | head -1)" && [[ -n "${downloaded_version}" ]]; then
                            if [[ "${downloaded_version}" == "${newest_version}" ]]; then
                                rm -rf "${HOME_INSTALL_DIR}"
                                mkdir -p "${HOME_INSTALL_DIR}"

                                if unzip -jo '/tmp/fg-support.zip' -x '__MACOSX*' '.*' '*/.*' -d "${HOME_INSTALL_DIR}" && [[ -e "${HOME_INSTALL_DIR}/fg-support.sh" && -e "${HOME_INSTALL_DIR}/launch-fg-support.sh" ]]; then
                                    chmod +x "${HOME_INSTALL_DIR}/"*'.sh'

                                    rm -f "${HOME}/.local/bin/fg-support"
                                    mkdir -p "${HOME}/.local/bin"
                                    ln -s "${HOME_INSTALL_DIR}/launch-fg-support.sh" "${HOME}/.local/bin/fg-support"

                                    rm -f '/tmp/fg-support.desktop'
                                    cat << FG_SUPPORT_DESKTOP_FILE_EOF > '/tmp/fg-support.desktop'
[Desktop Entry]
Version=1.0
Name=${APP_NAME}
GenericName=${APP_NAME}
Comment=${APP_COMMENT}
Exec=${HOME_INSTALL_DIR}/launch-fg-support.sh
Icon=${HOME_INSTALL_DIR}/fg-support-icon.png
Terminal=false
Type=Application
Categories=Utility;Application;
FG_SUPPORT_DESKTOP_FILE_EOF
                                    
                                    rm -f "${HOME}/.local/share/applications/fg-support.desktop"
                                    desktop-file-install --delete-original --dir "${HOME}/.local/share/applications/" '/tmp/fg-support.desktop'
                                    chmod +x "${HOME}/.local/share/applications/fg-support.desktop"

                                    break
                                fi
                            else
                                break
                            fi
                        fi
                    fi
                done | zenity --progress --title "Updating ${APP_NAME}" --window-icon "${app_icon}" --text "\nPlease wait while ${APP_NAME} updates itself...\n" --width '400' --auto-close --no-cancel --pulsate

                rm -f '/tmp/fg-support.zip'
            fi
        fi
    fi

    if ! pidof -o %PPID -x 'fg-support.sh'; then
        if [[ -e "${HOME_INSTALL_DIR}/fg-support.sh" ]]; then # Latest version from auto-updating will always exist in HOME_INSTALL_DIR.
            "${HOME_INSTALL_DIR}/fg-support.sh"
        elif [[ -e "${GLOBAL_INSTALL_DIR}/fg-support.sh" ]]; then
            "${GLOBAL_INSTALL_DIR}/fg-support.sh"
        else
            zenity --error --title "${APP_NAME}  —  Launch Error" --window-icon "${app_icon}" --no-wrap --text "<big><b>Unable to Launch ${APP_NAME}</b>\n\n<i>Visit <b>https://freegeek.org/techsupport</b> if you need assistance with your Free Geek computer.</i></big>"
        fi
    fi
fi

wmctrl -a "${APP_NAME}"
