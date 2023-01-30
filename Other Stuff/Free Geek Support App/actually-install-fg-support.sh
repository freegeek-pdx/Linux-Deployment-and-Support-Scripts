#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell on 05/28/19
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

if [[ "$(uname)" != 'Darwin' ]]; then # Don't run on macOS
    readonly APP_NAME='Free Geek Support'
    readonly APP_COMMENT='Get Tech Support from Free Geek'

    DOWNLOAD_URL='https://apps.freegeek.org/fg-support/download'
    TEST_MODE=false
    FORCE_UPDATE=false
    UNINSTALL=false
    REINSTALL=false


    if [[ -z "${MODE}" ]]; then # MODE can be inherited from calling script. But if it doesn't exist, check for first arg and use that instead.
        MODE="$1"
    fi
    readonly MODE="${MODE,,}" # Make lowercase

    echo "RUNNING INSTALL ${APP_NAME}"


    if [[ "${MODE}" == 'test' || "${MODE}" == 'testing' ]]; then
        if ping -W 2 -c 1 'tools.freegeek.org' &> /dev/null; then
            DOWNLOAD_URL='http://tools.freegeek.org/fg-support/download'
            TEST_MODE=true
            FORCE_UPDATE=true
            REINSTALL=true
            echo 'MODE: INSTALL OR UPDATE TO LATEST *TEST* VERSION'
        else
            echo 'TEST MODE NOT ENABLED - LOCAL FREE GEEK NETWORK IS REQUIRED'
        fi
    elif [[ "$MODE" == 'update' ]]; then
        FORCE_UPDATE=true
        echo 'MODE: FORCE UPDATE TO LATEST LIVE VERSION'
    elif [[ "$MODE" == 'uninstall' ]]; then
        UNINSTALL=true
        echo 'MODE: UNINSTALL'
    elif [[ "$MODE" == 'reinstall' ]]; then
        REINSTALL=true
        echo 'MODE: REINSTALL'
    fi


    readonly DOWNLOAD_URL TEST_MODE FORCE_UPDATE UNINSTALL REINSTALL


    if ! $UNINSTALL && ! ping -W 10 -c 1 'apps.freegeek.org' &> /dev/null; then
        echo -e "\n\nFAILED TO INSTALL ${APP_NAME}: INTERNET IS REQUIRED\n"
        exit 1
    fi

    readonly INSTALL_DIR='/usr/share/fg-support'

    if $UNINSTALL || $REINSTALL; then
        echo -e "\n\nUNINSTALLING ${APP_NAME}...\n"
        sudo rm -rf '/usr/share/applications/fg-support.desktop' '/usr/bin/fg-support' "${INSTALL_DIR}" '/home/'*'/.local/share/applications/fg-support.desktop' '/home/'*'/.local/bin/fg-support' '/home/'*'/.local/fg-support' '/tmp/fg-support.zip'
        echo -e "FINISHED UNINSTALLING ${APP_NAME}"
    fi

    if ! $UNINSTALL; then
        if $FORCE_UPDATE || [[ ! -e "${INSTALL_DIR}/fg-support.sh" || ! -e "${INSTALL_DIR}/launch-fg-support.sh" || ! -e '/usr/share/applications/fg-support.desktop' ]]; then
            echo -e "\n\nINSTALLING ${APP_NAME}...\n"

            for (( download_attempt = 0; download_attempt < 5; download_attempt ++ )); do
                sudo rm -f '/tmp/fg-support.zip'

                if sudo curl --connect-timeout 5 --progress-bar -fL "${DOWNLOAD_URL}/fg-support.zip" -o '/tmp/fg-support.zip' && [[ -e '/tmp/fg-support.zip' ]]; then
                    if downloaded_version="$(sudo unzip -p '/tmp/fg-support.zip' '*/fg-support_version.txt' | head -1)" && [[ -n "${downloaded_version}" ]]; then
                        if $TEST_MODE || [[ "${downloaded_version}" != *'test'* ]]; then
                            sudo rm -rf "${INSTALL_DIR}"
                            sudo mkdir -p "${INSTALL_DIR}"

                            if sudo unzip -jo '/tmp/fg-support.zip' -x '__MACOSX*' '.*' '*/.*' -d "${INSTALL_DIR}" && [[ -e "${INSTALL_DIR}/fg-support.sh" && -e "${INSTALL_DIR}/launch-fg-support.sh" ]]; then
                                sudo chmod +x "${INSTALL_DIR}/"*'.sh'

                                sudo rm -f '/usr/bin/fg-support'
                                sudo ln -s "${INSTALL_DIR}/launch-fg-support.sh" '/usr/bin/fg-support'

                                sudo rm -f '/tmp/fg-support.desktop'
                                cat << FG_SUPPORT_DESKTOP_FILE_EOF > '/tmp/fg-support.desktop'
[Desktop Entry]
Version=1.0
Name=${APP_NAME}
GenericName=${APP_NAME}
Comment=${APP_COMMENT}
Exec=${INSTALL_DIR}/launch-fg-support.sh
Icon=${INSTALL_DIR}/fg-support-icon.png
Terminal=false
Type=Application
Categories=Utility;Application;
FG_SUPPORT_DESKTOP_FILE_EOF

                                sudo rm -f '/usr/share/applications/fg-support.desktop'
                                sudo desktop-file-install --delete-original --dir '/usr/share/applications/' '/tmp/fg-support.desktop'
                                sudo chmod +x '/usr/share/applications/fg-support.desktop'

                                break
                            fi
                        else
                            echo -e "\n\n${APP_NAME} INSTALL ERROR: TEST VERSION DOWNLOADED FROM LIVE URL"
                            break
                        fi
                    else
                        echo -e "\n\n${APP_NAME} INSTALL ERROR: NO VERSION SPECIFIED / BAD ZIP"
                    fi
                fi
            done

            sudo rm -f '/tmp/fg-support.zip'
        else
            echo -e "\n\n${APP_NAME} WAS ALREADY INSTALLED"
        fi

        echo -e "\n\n${APP_NAME} IS INSTALLED\nYOU CAN LAUNCH ${APP_NAME} FROM THE APPS MENU"
    fi
fi
