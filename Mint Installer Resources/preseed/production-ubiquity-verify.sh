#!/bin/bash

#
# Created by Pico Mitchell
# Last Updated: 01/17/22
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

MODE="$([[ "$(basename -- "$0")" == 'testing-'* ]] && echo 'testing' || echo 'production')"
readonly MODE

xset s noblank
xset s off -dpms # Disable screen sleep

cp -f '/cdrom/preseed/dependencies/org.gnome.Cheese.gschema.xml' '/usr/share/glib-2.0/schemas/' # Install Cheese schemas so Cheese can be run from /cdrom/preseed/dependencies/ (called from QA Helper)
glib-compile-schemas '/usr/share/glib-2.0/schemas/' # Schemas must be compiled after installation

echo -e "#!/bin/bash\n\ncurl -sL -m 5 'http://tools.freegeek.org/qa-helper/log_install_time.php' \\" > '/tmp/post_install_time.sh'

if [[ "${MODE}" == 'testing' ]]; then
    LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -geometry 80x25+0+0 -sb -sl 999999 -e 'echo -e "USE ME FOR DEBUGGING\n\n"; bash' &
fi

while true; do
    if nmcli device status | grep -q ' wifi ' && ! nmcli device status | grep ' FG Reuse\| Free Geek' | grep -q ' connected '; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING ATTEMPT TO CONNECT TO "FG Reuse" OR "Free Geek" WI-FI\n<\n<<'
        
        # Try to connect to "FG Reuse" (which may not always be close enough) for faster Wi-Fi that can also connect to fglan (useful for "toram" network live boots that can continue after being disconnected from Ethernet).
        # If connecting to "FG Reuse" fails, connect to "Free Geek" so we can at least do a good Wi-Fi test.
        (rfkill unblock all; nmcli radio all on; nmcli device wifi connect 'FG Reuse' password '[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]' || nmcli device wifi connect 'Free Geek') | zenity \
            --progress \
            --title 'Connecting to Wi-Fi' \
            --text '\nPlease wait while connecting to Wi-Fi...\n' \
            --width '400' \
            --auto-close \
            --no-cancel \
            --pulsate
        
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED ATTEMPT TO CONNECT TO "FG Reuse" OR "Free Geek" WI-FI\n<\n<<'
    fi
    
    if ! timedatectl status | grep -q 'Time zone: America/Los_Angeles'; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING SET TIME ZONE TO PDT\n<\n<<'

        # Make sure proper time is set so https download works.
        timedatectl set-timezone America/Los_Angeles
        timedatectl set-ntp true

        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED SET TIME ZONE TO PDT\n<\n<<'
    fi
    
    if timedatectl status | grep -q 'System clock synchronized: no'; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING WAIT FOR TIME TO SYNC\n<\n<<'
        
        timedatectl set-ntp false # Turn time syncing off and then
        timedatectl set-ntp true # back on to provoke faster sync attempt
        
        for wait_for_time_sync_seconds in {1..30}; do # Wait up to 30 seconds for time to sync becuase download can stall if time changes in the middle of it.
            sleep 1
            
            echo "${wait_for_time_sync_seconds}" > '/tmp/wait_for_time_sync_seconds.txt' # To get value outside of this Zenity piped sub-shell.

            if timedatectl status | grep -q 'System clock synchronized: yes'; then
                break
            fi
        done | zenity \
            --progress \
            --title 'Syncing Date & Time from Internet' \
            --text '\nPlease wait while syncing date and time from the internet...\n' \
            --width '400' \
            --auto-close \
            --no-cancel \
            --pulsate
        
        echo -e ">>\n>\nVERIFY SCRIPT DEBUG: FINISHED WAIT FOR TIME TO SYNC AFTER $(cat '/tmp/wait_for_time_sync_seconds.txt') SECONDS\n<\n<<"

        rm -f '/tmp/wait_for_time_sync_seconds.txt'
    fi
    
    if timedatectl status | grep -q 'System clock synchronized: yes'; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: TIME IS SYNCED - SETTING SYSTEM TIME TO HWCLOCK\n<\n<<'

        # Update hardware (BIOS) clock with synced system time.
        hwclock --systohc

        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED SETTING SYSTEM TIME TO HWCLOCK\n<\n<<'
    else
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: TIME IS NOT SYNCED\n<\n<<'
    fi
    
    rm -f 'QAHelper-linux-jar.zip'
    rm -f 'QA_Helper.jar'

    echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING "QA Helper" DOWNLOAD\n<\n<<'
    
    for download_qa_helper_attempt in {1..5}; do
        wget -q "http$([[ "${MODE}" == 'testing' ]] && echo '://tools' || echo 's://apps').freegeek.org/qa-helper/download/QAHelper-linux-jar.zip"
        
        if [[ -f 'QAHelper-linux-jar.zip' ]]; then
            unzip -o -j 'QAHelper-linux-jar.zip' 'QA_Helper.jar'
            rm 'QAHelper-linux-jar.zip'
            
            if [[ -f 'QA_Helper.jar' ]]; then
                break
            else
                sleep "${download_qa_helper_attempt}"
            fi
        else
            sleep "${download_qa_helper_attempt}"
        fi
    done | zenity \
        --progress \
        --title 'Downloading QA Helper' \
        --text '\nPlease wait while downloading QA Helper...\n' \
        --width '400' \
        --auto-close \
        --no-cancel \
        --pulsate
    
    echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED "QA Helper" DOWNLOAD\n<\n<<'
    
    if [[ -f 'QA_Helper.jar' ]]; then
        '/cdrom/preseed/dependencies/java-jre/bin/java' -jar 'QA_Helper.jar'

        desktop_environment="$(awk -F '=' '($1 == "Name") { print $2; exit }' '/usr/share/xsessions/'*)" # Can't get desktop environment from DESKTOP_SESSION or XDG_CURRENT_DESKTOP in pre-install environment.
        desktop_environment="${desktop_environment%% (*)}"
        if [[ -n "$desktop_environment" ]]; then
            desktop_environment=" (${desktop_environment})"
        fi

        release_codename="$(lsb_release -cs)"
        if [[ -n "$release_codename" ]]; then
            release_codename=" ${release_codename^}"
        fi
       
        
        while true; do
            # Sort lsblk output by size smallest to largest because we will generally want to install onto the smallest drive.
            lsblk_drive_list="$(lsblk -a -b -d -p -P -x SIZE -o NAME,SIZE,TRAN,ROTA,TYPE | awk -F '"' '($(NF-1) == "disk") && ($4) && (index($6, "ata") || ($6 == "nvme"))')" # Only list DISKs with a SIZE that have a TRANsport type of SATA or ATA or NVMe.
            lsblk_drive_list="${lsblk_drive_list// TYPE=\"disk\"/}" # Get rid of TYPE because we don't need it for display. (Only needed it to properly filter the list.)
            
            install_drives_array=()
            
            if [[ -n "$lsblk_drive_list" ]]; then
                this_drive_id=''
                this_drive_transport=''
                
                for this_drive_list_element in ${lsblk_drive_list}; do
                    this_drive_list_element_key="${this_drive_list_element:0:4}"
                    this_drive_list_element_value="${this_drive_list_element:6:-1}"
                    
                    if [[ "${this_drive_list_element_key}" == 'NAME' ]]; then
                        this_drive_id="${this_drive_list_element_value}"
                        install_drives_array+=( "${this_drive_id}" "${this_drive_id##*/}" )
                    elif [[ "${this_drive_list_element_key}" == 'SIZE' ]]; then
                        install_drives_array+=( "$(( this_drive_list_element_value / 1000 / 1000 / 1000 )) GB" )
                    elif [[ "${this_drive_list_element_key}" == 'TRAN' ]]; then
                        this_drive_transport="$([[ "${this_drive_list_element_value}" == 'nvme' ]] && echo 'NVMe ' || echo "${this_drive_list_element_value^^} ")"
                    elif [[ "${this_drive_list_element_key}" == 'ROTA' ]]; then
                        this_drive_HDD_or_SSD="$([[ "${this_drive_list_element_value}" == '1' ]] && echo 'HDD' || echo 'SSD')"
                        install_drives_array+=( "${this_drive_transport}${this_drive_HDD_or_SSD}" )
                        
                        hdparm_drive_model="$(hdparm -I "${this_drive_id}" | grep 'Model Number:' | xargs | cut -c 15-)" # Use hdparm for model becuase lsblk gets model from sysfs ("/sys/block/<name>/device/model") which is truncated.
                        
                        if [[ -n "${hdparm_drive_model}" ]]; then
                            install_drives_array+=( "${hdparm_drive_model}" )
                        else
                            sysfs_drive_model="$(xargs -a "/sys/block/${this_drive_id##*/}/device/model")"
                            install_drives_array+=( "${sysfs_drive_model:-UNKNOWN Drive Model}" )
                        fi

                        this_drive_id=''
                        this_drive_transport=''
                    fi
                done
            fi
            
            if (( "${#install_drives_array[@]}" >= 5 )); then
                readarray -t install_drive_details_array < <(zenity \
                    --list \
                    --title 'Choose Installation Drive' \
                    --width '530' \
                    --height '250' \
                    --text "\t\t\t\tWhich drive would you like to <b>COMPLETELY ERASE</b>\n\t\t\t\tand <b>INSTALL</b> <i>$(lsb_release -ds)${release_codename}${desktop_environment}</i> onto?<span size='4000'>\n </span>" \
                    --column 'Full ID' \
                    --column 'ID' \
                    --column 'Size' \
                    --column 'Kind' \
                    --column 'Model' \
                    --hide-column 1 \
                    --print-column 'ALL' \
                    --separator '\n' \
                    "${install_drives_array[@]}")
                
                if [[ "${#install_drive_details_array[@]}" == 5 && "${install_drive_details_array[0]}" == '/'* ]]; then
                    debconf-set partman-auto/disk "${install_drive_details_array[0]}"
                    debconf-set grub-installer/bootdev "${install_drive_details_array[0]}"
                    
                    if [[ "$(debconf-get partman-auto/disk)" == "${install_drive_details_array[0]}" && "$(debconf-get grub-installer/bootdev)" == "${install_drive_details_array[0]}" ]]; then
                        if zenity --question --title 'Confirm Installation' --no-wrap --text "Are you sure you want to <b>COMPLETELY ERASE</b> the following\ndrive and <b>INSTALL</b> <i>$(lsb_release -ds)${release_codename}${desktop_environment}</i> onto it?\n\n<tt><small><b>   ID:</b></small></tt> ${install_drive_details_array[1]}\n<tt><small><b> Size:</b></small></tt> ${install_drive_details_array[2]}\n<tt><small><b> Kind:</b></small></tt> ${install_drive_details_array[3]}\n<tt><small><b>Model:</b></small></tt> ${install_drive_details_array[4]}"; then
                            echo "--data-urlencode \"version=$(lsb_release -ds)${release_codename}${desktop_environment}\" --data-urlencode \"drive_type=${install_drive_details_array[3]}\" --data-urlencode \"base_start_time=$(date +%s)\" \\" >> '/tmp/post_install_time.sh'
                            
                            killall xterm 2> /dev/null # Always try to killall xterm because it could have been opened by QA Helper even when not in test mode.
                            killall firefox 2> /dev/null # Always try to killall firefox because it could have been opened by QA Helper.
                            
                            exit 0
                        fi
                    elif ! zenity --question --title 'Failed to Set Installation Drive' --no-wrap --ok-label 'Try Again' --cancel-label 'Reboot' --text '<b>There was an unknown issue setting the installation drive.</b>\n\nIf this happens again, try rebooting back into this installation environment.\n\n<i>If this continues to fail, please inform your manager and Free Geek I.T.</i>'; then
                        reboot
                        exit 32
                    fi
                fi
            else
                zenity --error --title 'No Internal Drives Detected' --no-wrap --text '\n<b>No internal drives were detected for installation.</b>'
            fi

            if cancel_installation_response="$(zenity --question --title 'Cancel Installation?' --no-wrap --ok-label 'Cancel & Shut Down' --cancel-label 'Re-Select Installation Drive' --extra-button 'Cancel & Reboot' --extra-button 'Re-Open QA Helper' --text '\nAre you sure you want to cancel this installation?')"; then
                shutdown now
                exit 1
            elif [[ "${cancel_installation_response}" == 'Cancel & Reboot' ]]; then
                reboot
                exit 1
            elif [[ "${cancel_installation_response}" == 'Re-Open QA Helper' ]]; then
                break
            fi
        done
    else
        if ! failed_download_response="$(zenity --question --title 'Failed to Download QA Helper' --no-wrap --ok-label 'Try Again' --cancel-label 'Reboot' --extra-button 'Shut Down' --text '<b>Failed to download QA Helper.</b>\n\n<u>Internet is required to be able to properly install Linux Mint.</u>\n\nBefore trying again, make sure an Ethernet cable is connected securely.\n\nIf this happens again, reboot into BIOS and make sure this computers date and time is set correctly.\nThen, boot back into this installation environment and try again.\n\n<i>If this continues to fail, please inform your manager and Free Geek I.T.</i>')"; then
            if [[ "${failed_download_response}" == 'Shut Down' ]]; then
                shutdown now
                exit 23
            else
                reboot
                exit 23
            fi
        fi
    fi
done

exit 42 # Should never get here
