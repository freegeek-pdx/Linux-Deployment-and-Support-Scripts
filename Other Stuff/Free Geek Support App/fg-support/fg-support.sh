#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell on 05/28/19
# For Free Geek
# Last Updated: 01/23/23
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

if ! pidof -o %PPID -x 'fg-support.sh'; then
    readonly HOME_INSTALL_DIR="${HOME}/.local/fg-support"
    readonly GLOBAL_INSTALL_DIR='/usr/share/fg-support'

    rm -f '/tmp/fg-support_teamviewer-progress-terminal-pid.txt'

    if ping -W 2 -c 1 'www.freegeek.org' &> /dev/null; then
        fg_website_content="$(curl --connect-timeout 5 -sfL 'https://www.freegeek.org/search/node')" # Use this specific URL to load fast since there won't be any actual page content, just the necessary header and footer.
        tech_support_hours="$(echo "${fg_website_content}" | awk -F '>|<' 'after_tech_support { if ($2 != "/p" && $3 != "") { print $3; exit } } inside_footer { if ($2 ~ "/span") { exit } else if ($3 ~ "Tech Support") { after_tech_support = 1 } } /class="additional-footer"/ { inside_footer = 1 }' | tr -s '[:space:]' ' ' | sed -E 's/^ | $//g')" # After "tr -s" there could still be a single leading and/or trailing space, so use "sed" to remove them.
        website_announcement="$(echo "${fg_website_content}" | awk -F '>|<' 'inside_announcement_block { if ($2 ~ "/div") { exit } else if ($3 != "") { print $3 } } /id="block-globalannouncement"/ { inside_announcement_block = 1 }' | tr -s '[:space:]')" # Do not trim and squeeze all whitespace to single spaces like above since we want to preserve existing lines, but just want to remove multiple sequential spaces and line breaks.
        website_announcement="${website_announcement//. /.$'\n'}" # Put each sentence on its own line so that long announcements don't make the window too wide.
    fi

    if [[ -z "${fg_website_content}" ]]; then
        # Only use saved Tech Support hours if unable to load website content (since don't want to use default or previously saved Tech Support hours if none were listed in the current website contents).
        tech_support_hours="$(cat "${HOME_INSTALL_DIR}/fg-support_tech-support-hours.txt" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_tech-support-hours.txt" 2> /dev/null)"
    fi

    if [[ "${tech_support_hours}" != *[0-9]* ]]; then
        # Reject "tech_support_hours" scraped from the website if it does not contain any numbers. (Because specific hours are NOT currently listed in the footer during COVID-19 public closure.)
        tech_support_hours=''
    fi

    mkdir -p "${HOME_INSTALL_DIR}" 2> /dev/null
    echo "${tech_support_hours}" > "${HOME_INSTALL_DIR}/fg-support_tech-support-hours.txt" # Even if this file gets written with empty contents, we want it to exist so that default hours are not shown when not connected to the internet if no specific hours were last retrieved from the internet.

    app_icon="$([[ -f "${HOME_INSTALL_DIR}/fg-support-icon.png" ]] && echo "${HOME_INSTALL_DIR}" || echo "${GLOBAL_INSTALL_DIR}")/fg-support-icon.png"
    if [[ ! -f "${app_icon}" ]]; then
        app_icon='/usr/share/icons/Mint-Y/status/128@2x/dialog-question.png'
        if [[ ! -f "${app_icon}" ]]; then app_icon=''; fi
    fi

    main_text="$(cat "${HOME_INSTALL_DIR}/fg-support_main.pango" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_main.pango" 2> /dev/null)"
    if [[ -z "${main_text}" ]]; then
        main_text="<big><b>Visit the Free Geek Tech Support Website if you need assistance with your Free Geek computer.</b><!-- ANNOUNCEMENT PLACEHOLDER -->\n\n<i>${APP_NAME} ERROR: MISSING MAIN TEXT CONTENT</i></big>"
    elif [[ -n "${tech_support_hours}" ]]; then
        main_text="${main_text/For current Tech Support hours, click the \"Visit Free Geek Tech Support Website\" button below, or call (503) 232-9350./Tech Support Hours: ${tech_support_hours}}"
    fi

    if [[ -n "${website_announcement}" ]]; then
        main_text="${main_text/<!-- ANNOUNCEMENT PLACEHOLDER -->/<b>\\n\\n${website_announcement}<\/b>}"
    fi

    while true; do
        if ! main_response="$(zenity --question --title "${APP_NAME}" --window-icon "${app_icon}" --no-wrap --ok-label 'Visit Free Geek Tech Support Website' --cancel-label 'Close' --extra-button "Uninstall ${APP_NAME}" --extra-button 'Learn More About Screen Sharing' --text "${main_text}")"; then
            if [[ "${main_response}" == 'Uninstall'* ]]; then
                uninstall_text="$(cat "${HOME_INSTALL_DIR}/fg-support_uninstall.pango" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_uninstall.pango" 2> /dev/null)"
                if [[ -z "${uninstall_text}" ]]; then
                    uninstall_text="<big><b>Are you sure you want to uninstall ${APP_NAME}?</b>\n\n<i>${APP_NAME} ERROR: MISSING UNINSTALL TEXT CONTENT</i></big>"
                fi

                if zenity --question --title "${APP_NAME}  —  Uninstall" --window-icon "${app_icon}" --no-wrap --text "${uninstall_text}"; then
                    if pkexec rm -rf '/usr/share/applications/fg-support.desktop' '/usr/bin/fg-support' "${GLOBAL_INSTALL_DIR}" '/home/'*'/.local/share/applications/fg-support.desktop' '/home/'*'/.local/bin/fg-support' '/home/'*'/.local/fg-support' '/tmp/fg-support.zip' 2> /dev/null; then
                        break
                    fi
                fi
            elif [[ "${main_response}" == *'Screen Sharing'* ]]; then
                while true; do
                    screen_sharing_text="$(cat "${HOME_INSTALL_DIR}/fg-support_screen-sharing.pango" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_screen-sharing.pango" 2> /dev/null)"
                    if [[ -z "${screen_sharing_text}" ]]; then
                        screen_sharing_text="<big><b>To learn more about TeamViewer, click the \"Visit TeamViewer Website\" button below.</b>\n\n<i>${APP_NAME} ERROR: MISSING ABOUT SCREEN SHARING TEXT CONTENT</i></big>"
                    fi

                    if command -v teamviewer &> /dev/null; then
                        screen_sharing_extra_buttons=( --extra-button 'Launch TeamViewer for Screen Sharing' --extra-button 'UNINSTALL TeamViewer' )
                    else
                        screen_sharing_extra_buttons=( --extra-button 'Install TeamViewer for Screen Sharing' )
                    fi

                    if ! screen_sharing_response="$(zenity --question --title "${APP_NAME}  —  About Screen Sharing" --window-icon "${app_icon}" --no-wrap --ok-label 'Visit TeamViewer Website' --cancel-label 'Go Back' "${screen_sharing_extra_buttons[@]}" --text "${screen_sharing_text}")"; then
                        chose_teamviewer_install="$([[ "${screen_sharing_response}" == 'Install TeamViewer for Screen Sharing' ]] && echo 'true' || echo 'false')"
                        chose_teamviewer_uninstall="$([[ "${screen_sharing_response}" == 'UNINSTALL TeamViewer' ]] && echo 'true' || echo 'false')"

                        if $chose_teamviewer_install || $chose_teamviewer_uninstall; then
                            apt_is_running=false

                            while IFS='' read -r this_apt_process; do
                                if [[ "${this_apt_process}" == *'apt-get'* || "${this_apt_process}" == *'/bin/apt'* || "${this_apt_process}" == *'/apt/methods/'* ]] || [[ "${this_apt_process}" == *'/mintUpdate/'* && "${this_apt_process}" != *'/mintUpdate/mintUpdate.py' ]]; then
                                    apt_is_running=true
                                    break
                                fi
                            done < <(pgrep -fa '(apt|mintUpdate)' 2> /dev/null)

                            if $apt_is_running; then
                                zenity --warning --title "${APP_NAME}  —  Another Installation is Running" --window-icon "${app_icon}" --no-wrap --text "<big><b>Another installation process (such as \"apt\" or \"mintUpdate\") is currently running. <i>This process may be running in the background.</i></b></big>\n\n<i>This other installation process could interrupt the TeamViewer $($chose_teamviewer_uninstall && echo 'un')installation or the TeamViewer $($chose_teamviewer_uninstall && echo 'un')installation may interrupt the other installation process.</i>\n\nPlease try again after the other installation process has finished."
                            elif $chose_teamviewer_install; then
                                if ping -W 2 -c 1 'download.teamviewer.com' &> /dev/null; then
                                    confirm_teamviewer_text="$(cat "${HOME_INSTALL_DIR}/fg-support_confirm-teamviewer.pango" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_confirm-teamviewer.pango" 2> /dev/null)"
                                    if [[ -z "${confirm_teamviewer_text}" ]]; then
                                        confirm_teamviewer_text="<big><b>Are you sure you want to install TeamViewer for Screen Sharing?</b>\n\n<i>${APP_NAME} ERROR: MISSING CONFIRM TEAMVIEWER TEXT CONTENT</i></big>"
                                    fi

                                    if zenity --question --title "${APP_NAME}  —  Confirm TeamViewer Installation" --window-icon "${app_icon}" --no-wrap --text "${confirm_teamviewer_text}"; then
                                        rm -f '/tmp/fg-support_teamviewer.deb' '/tmp/fg-support_teamviewer-progress-terminal-pid.txt'
                                        gnome-terminal --window-with-profile-internal-id '0' --title "${APP_NAME}  —  TeamViewer Installation Progress" --hide-menubar --geometry '80x25+0+0' -x bash -c '
echo "$$" > "/tmp/fg-support_teamviewer-progress-terminal-pid.txt"

echo -e "\nSTARTING TEAMVIEWER INSTALLATION\n\nDOWNLOADING TEAMVIEWER INSTALLER:"
curl --connect-timeout 5 --progress-bar -fL "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" -o "/tmp/fg-support_teamviewer.deb"

echo -e "\n\nINSTALLING TEAMVIEWER (ADMIN PASSWORD REQUIRED):"
pkexec apt install --no-install-recommends -y "/tmp/fg-support_teamviewer.deb" && echo -e "\n\nFINISHED INSTALLING TEAMVIEWER" || echo -e "\n\nFAILED TO INSTALL TEAMVIEWER: ADMIN PASSWORD REQUIRED"
rm -f "/tmp/fg-support_teamviewer.deb" "/tmp/fg-support_teamviewer-progress-terminal-pid.txt"

echo -e "\n\nPRESS ENTER TO CLOSE THIS WINDOW"
read -r
wmctrl -F -a "TeamViewer License Agreement" || wmctrl -F -a "TeamViewer" || wmctrl -a "Free Geek Support"
' &> /dev/null

                                        wait_for_teamviewer_progress_terminal_pid=''

                                        for (( get_terminal_pid_attempt = 0; get_terminal_pid_attempt < 5; get_terminal_pid_attempt ++ )); do
                                            if wait_for_teamviewer_progress_terminal_pid="$(cat '/tmp/fg-support_teamviewer-progress-terminal-pid.txt' 2> /dev/null)" && [[ -n "${wait_for_teamviewer_progress_terminal_pid}" ]]; then
                                                break
                                            fi

                                            sleep 1
                                        done

                                        if [[ -n "${wait_for_teamviewer_progress_terminal_pid}" ]]; then
                                            while ps -p "${wait_for_teamviewer_progress_terminal_pid}" &> /dev/null && [[ -f '/tmp/fg-support_teamviewer-progress-terminal-pid.txt' ]]; do
                                                sleep 1
                                            done | zenity --progress --title "${APP_NAME}  —  Installing TeamViewer" --window-icon "${app_icon}" --text "\n<big><b>Please wait while TeamViewer is being installed...</b></big>\n\n<i>You can monitor progress in the Terminal window in the top left corner of the screen.</i>\n" --width '500' --auto-close --no-cancel --pulsate
                                        fi

                                        rm -f '/tmp/fg-support_teamviewer.deb' '/tmp/fg-support_teamviewer-progress-terminal-pid.txt'

                                        if command -v teamviewer &> /dev/null; then
                                            while true; do
                                                teamviewer_sucess_extra_button=()
                                                if [[ ! -f "${HOME}/Desktop/com.teamviewer.TeamViewer.desktop" ]]; then
                                                    teamviewer_sucess_extra_button=( --extra-button 'Add TeamViewer to Desktop' )
                                                fi

                                                if teamviewer_sucess_response="$(zenity --question --title "${APP_NAME}  —  Successfully Installed TeamViewer" --window-icon "${app_icon}" --no-wrap "${teamviewer_sucess_extra_button[@]}" --text '<big><b>TeamViewer Installation Successful</b></big>\n\nWould you like to launch TeamViewer for Screen Sharing right now?')"; then
                                                    nohup teamviewer &> /dev/null & disown
                                                    break
                                                else
                                                    if [[ "${teamviewer_sucess_response}" == 'Add TeamViewer to Desktop' ]]; then
                                                        desktop-file-install --dir "${HOME}/Desktop/" '/usr/share/applications/com.teamviewer.TeamViewer.desktop'
                                                        chmod +x "${HOME}/Desktop/com.teamviewer.TeamViewer.desktop"
                                                    else
                                                        break
                                                    fi
                                                fi
                                            done
                                        else
                                            zenity --warning --title "${APP_NAME}  —  Failed to Install TeamViewer" --window-icon "${app_icon}" --no-wrap --text "<big><b>TeamViewer Installation Failed</b></big>$(ps -p "${wait_for_teamviewer_progress_terminal_pid}" &> /dev/null && echo -e '\n\n<i>Check the Terminal window in the top left corner of the screen for details.</i>')\n\nPlease try again."
                                        fi

                                        if [[ -n "${wait_for_teamviewer_progress_terminal_pid}" ]]; then
                                            kill "${wait_for_teamviewer_progress_terminal_pid}" &> /dev/null
                                        fi

                                        break
                                    fi
                                else
                                    zenity --warning --title "${APP_NAME}  —  Internet Required" --window-icon "${app_icon}" --no-wrap --text '<big><b>Internet Is Required to Install TeamViewer</b></big>\n\nPlease try again when you are connected to the internet.'
                                fi
                            else
                                uninstall_teamviewer_text="$(cat "${HOME_INSTALL_DIR}/fg-support_uninstall-teamviewer.pango" 2> /dev/null || cat "${GLOBAL_INSTALL_DIR}/fg-support_uninstall-teamviewer.pango" 2> /dev/null)"
                                if [[ -z "${uninstall_teamviewer_text}" ]]; then
                                    uninstall_teamviewer_text="<big><b>Are you sure you want to UNINSTALL TeamViewer for Screen Sharing?</b>\n\n<i>${APP_NAME} ERROR: MISSING UNINSTALL TEAMVIEWER TEXT CONTENT</i></big>"
                                fi

                                if zenity --question --title "${APP_NAME}  —  Confirm TeamViewer Uninstallation" --window-icon "${app_icon}" --no-wrap --text "${uninstall_teamviewer_text}"
                                then
                                    rm -f '/tmp/fg-support_teamviewer-progress-terminal-pid.txt'

                                    # Suppress ShellCheck warning that variables don't expand in single quotes since that is intended.
                                    # shellcheck disable=SC2016
                                    gnome-terminal --window-with-profile-internal-id '0' --title "${APP_NAME}  —  TeamViewer Uninstallation Progress" --hide-menubar --geometry '80x25+0+0' -x bash -c '
echo "$$" > "/tmp/fg-support_teamviewer-progress-terminal-pid.txt"

echo -e "\nUNINSTALLING TEAMVIEWER (ADMIN PASSWORD REQUIRED):"
sleep 1
pkexec apt purge --auto-remove -y teamviewer && ( rm -f "${HOME}/Desktop/com.teamviewer.TeamViewer.desktop"; echo -e "\n\nFINISHED UNINSTALLING TEAMVIEWER" ) || echo -e "\n\nFAILED TO UNINSTALL TEAMVIEWER: ADMIN PASSWORD REQUIRED"
rm -f "/tmp/fg-support_teamviewer-progress-terminal-pid.txt"

echo -e "\n\nPRESS ENTER TO CLOSE THIS WINDOW"
read -r
wmctrl -a "Free Geek Support"
' &> /dev/null

                                    wait_for_teamviewer_progress_terminal_pid=''

                                    for (( get_terminal_pid_attempt = 0; get_terminal_pid_attempt < 5; get_terminal_pid_attempt ++ )); do
                                        if wait_for_teamviewer_progress_terminal_pid="$(cat '/tmp/fg-support_teamviewer-progress-terminal-pid.txt' 2> /dev/null)" && [[ -n "${wait_for_teamviewer_progress_terminal_pid}" ]]; then
                                            break
                                        fi

                                        sleep 1
                                    done

                                    if [[ -n "${wait_for_teamviewer_progress_terminal_pid}" ]]; then
                                        while ps -p "${wait_for_teamviewer_progress_terminal_pid}" &> /dev/null && [[ -f '/tmp/fg-support_teamviewer-progress-terminal-pid.txt' ]]; do
                                            sleep 1
                                        done | zenity --progress --title "${APP_NAME}  —  Uninstalling TeamViewer" --window-icon "${app_icon}" --text '\n<big><b>Please wait while TeamViewer is being uninstalled...</b></big>\n\n<i>You can monitor progress in the Terminal window in the top left corner of the screen.</i>\n' --width '500' --auto-close --no-cancel --pulsate
                                    fi

                                    rm -f '/tmp/fg-support_teamviewer-progress-terminal-pid.txt'

                                    if command -v teamviewer &> /dev/null; then
                                        zenity --warning --title "${APP_NAME}  —  Failed to Uninstall TeamViewer" --window-icon "${app_icon}" --no-wrap --text "<big><b>TeamViewer Uninstallation Failed</b></big>$(ps -p "${wait_for_teamviewer_progress_terminal_pid}" &> /dev/null && echo -e '\n\n<i>Check the Terminal window in the top left corner of the screen for details.</i>')\n\nPlease try again."
                                    else
                                        zenity --info --title "${APP_NAME}  —  Successfully Uninstalled TeamViewer" --window-icon "${app_icon}" --no-wrap --text '\n<big><b>TeamViewer Uninstallation Successful</b></big>'
                                    fi

                                    if [[ -n "${wait_for_teamviewer_progress_terminal_pid}" ]]; then
                                        kill "${wait_for_teamviewer_progress_terminal_pid}" &> /dev/null
                                    fi

                                    break
                                fi
                            fi
                        elif [[ "${screen_sharing_response}" == 'Launch TeamViewer for Screen Sharing' ]]; then
                            nohup teamviewer &> /dev/null & disown
                            wmctrl -a 'TeamViewer'
                        else
                            break
                        fi
                    else
                        nohup xdg-open 'https://www.teamviewer.com/documents/' &> /dev/null & disown
                    fi
                done
            else
                break
            fi
        else
            nohup xdg-open 'https://www.freegeek.org/computer-adoption/tech-support' &> /dev/null & disown
        fi
    done
else
    wmctrl -a "${APP_NAME}"
fi
