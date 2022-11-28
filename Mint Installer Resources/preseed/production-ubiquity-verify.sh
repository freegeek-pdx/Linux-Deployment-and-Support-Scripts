#!/bin/bash

#
# Created by Pico Mitchell
# Last Updated: 11/28/22
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

MODE="$([[ "${0##*/}" == 'testing-'* ]] && echo 'testing' || echo 'production')"
readonly MODE

xset s noblank
xset s off -dpms # Disable screen sleep.

mv -f '/usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service'{,.disabled}
# NOTE: On Mint 21 the screensaver is starting after 15 mins and CANNOT be disabled using any "gsettings" commands (run as any user),
# so instead disable the DBus ScreenSaver service by renaming the file to end in ".disabled" so it will never be run (found the DBus service path from https://forums.linuxmint.com/viewtopic.php?p=1321395#p1321395).
# Renaming/moving/deleting the "/usr/bin/cinnamon-screensaver" command would also work (https://askubuntu.com/questions/356992/how-do-i-disable-the-cinnamon-2-lock-screen/548475#548475),
# but that causes the DBus ScreenSaver service to still run by "dbus-daemon" when the system has been idle for 15 mins, and just exit with a failure since the command cannot be found.
# Disabling the DBus service in this way seems a little more elegant, but I couldn't figure out how to actually disable the service through some DBus command like the way you can disable "systemctl" services.

if grep -qF ' ip=dhcp ' '/proc/cmdline'; then
    # NOTE: When PXE/net booting Mint 21 (but not USB booting), the primary Ethernet connection DOES NOT load a DNS server, so any network calls using URLs fail (such as to download QA Helper).
    # The exact issue is described here, but without a solution: https://serverfault.com/questions/1104238/no-dns-on-pxe-booted-linux-live-system-with-networkmanager
    # (Using the kernel args mentioned in the above post to set a DNS server doesn't work, and every other possible kernel arg I could find for specifying DNS servers also didn't work.)
    # Interestingly, I was not able to find any other mention of this issue in all my Googling even though that post mentions running into the issue on Debian and through
    # testing I found that the issue started with Ubuntu 21.04 (Mint 19.X was based on Ubuntu 20.04 and Mint 20.X is based on Ubuntu 22.04), so it must affect many systems.
    # I also found that this issue seems to be tied to using the "ip=dhcp" kernel argument since when I added that argument on a USB boot the same DNS issue occurred.
    # But, the "ip=dhcp" kernel argument is required for PXE/net booting to be able to download the filesystem over NFS as of Ubuntu 19.10 (https://bugs.launchpad.net/ubuntu/+source/casper/+bug/1848018).
    # So, since "ip=dhcp" is required when PXE/net booting, this DNS issue must be worked around to be able to properly load the network on Mint 21.
    # Interestingly, any subsequent connections (such as Wi-Fi) load a DNS server just fine, and turning Ethernet off and back on also allows it to properly load DNS.
    # But, when running over the network, disabling the network even for a moment can at best cause the system to hang for a couple minutes and at worst can cause it to hang indefinitely, so that is not a feasible workaround.
    # Instead, we will directly specify a DNS server once the system has fully booted, which makes the nework immediate start working.
    # Below, the local Free Geek DNS server is assigned for every available network connection on the system (just to be completely thorough since setting DNS for any inactive connnections doesn't hurt).
    # It would also be possible to use "resolvectl dns" to set the DNS server, but since I'm getting the interface names from "nmcli", I'll continue using "nmcli" to set the DNS server.

    IFS=$'\n'
    for this_network_interface_name in $(nmcli -t -f NAME connection show); do
        echo -e ">>\n>\nVERIFY SCRIPT DEBUG: MANUALLY SETTING DNS SERVER FOR \"${this_network_interface_name}\"\n<\n<<"
        nmcli connection modify "${this_network_interface_name}" ipv4.dns '192.168.253.11' # Local Free Geek DNS server IP.
    done
    unset IFS
fi


cp -f '/cdrom/preseed/dependencies/org.gnome.Cheese.gschema.xml' '/usr/share/glib-2.0/schemas/' # Install Cheese schemas so Cheese can be run from /cdrom/preseed/dependencies/ (called from QA Helper)
glib-compile-schemas '/usr/share/glib-2.0/schemas/' # Schemas must be compiled after installation

echo -e "#!/bin/bash\n\ncurl -sL -m 5 'http://tools.freegeek.org/qa-helper/log_install_time.php' \\" > '/tmp/post_install_time.sh'

if [[ "${MODE}" == 'testing' ]]; then
    LD_LIBRARY_PATH='/cdrom/preseed/dependencies/' '/cdrom/preseed/dependencies/xterm' -geometry 80x25+0+0 -sb -sl 999999 -e 'echo -e "USE ME FOR DEBUGGING\n\n"; bash' &
fi

while true; do
    if nmcli device status | grep -qF ' wifi ' && ! nmcli device status | grep ' FG Reuse\| Free Geek' | grep -qF ' connected '; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING ATTEMPT TO CONNECT TO "FG Reuse" OR "Free Geek" WI-FI\n<\n<<'
        
        # Try to connect to "FG Reuse" (which may not always be close enough) for faster Wi-Fi that can also connect to fglan (useful for "toram" network live boots that can continue after being disconnected from Ethernet).
        # If connecting to "FG Reuse" fails, connect to "Free Geek" so we can at least do a good Wi-Fi test.
        {
            rfkill unblock all
            nmcli radio all on
            nmcli device wifi connect 'FG Reuse' password '[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]' || nmcli device wifi connect 'Free Geek'
        } | zenity \
            --progress \
            --title 'Connecting to Wi-Fi' \
            --text '\nPlease wait while connecting to Wi-Fi...\n' \
            --width '400' \
            --auto-close \
            --no-cancel \
            --pulsate
        
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED ATTEMPT TO CONNECT TO "FG Reuse" OR "Free Geek" WI-FI\n<\n<<'
    fi
    
    if ! timedatectl status | grep -qF 'Time zone: America/Los_Angeles'; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING SET TIME ZONE TO PDT\n<\n<<'

        # Make sure proper time is set so https download works.
        timedatectl set-timezone America/Los_Angeles
        timedatectl set-ntp true

        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: FINISHED SET TIME ZONE TO PDT\n<\n<<'
    fi
    
    if timedatectl status | grep -qF 'System clock synchronized: no'; then
        echo -e '>>\n>\nVERIFY SCRIPT DEBUG: STARTING WAIT FOR TIME TO SYNC\n<\n<<'
        
        {
            timedatectl set-ntp false # Turn time syncing off and then
            timedatectl set-ntp true # back on to provoke faster sync attempt
            
            for wait_for_time_sync_seconds in {1..30}; do # Wait up to 30 seconds for time to sync becuase download can stall if time changes in the middle of it.
                sleep 1
                
                echo "${wait_for_time_sync_seconds}" > '/tmp/wait_for_time_sync_seconds.txt' # To get value outside of this Zenity piped sub-shell.

                if timedatectl status | grep -qF 'System clock synchronized: yes'; then
                    break
                fi
            done
        } | zenity \
            --progress \
            --title 'Syncing Date & Time from Internet' \
            --text '\nPlease wait while syncing date and time from the internet...\n' \
            --width '400' \
            --auto-close \
            --no-cancel \
            --pulsate
        
        echo -e ">>\n>\nVERIFY SCRIPT DEBUG: FINISHED WAIT FOR TIME TO SYNC AFTER $(< '/tmp/wait_for_time_sync_seconds.txt') SECONDS\n<\n<<"

        rm -f '/tmp/wait_for_time_sync_seconds.txt'
    fi
    
    if timedatectl status | grep -qF 'System clock synchronized: yes'; then
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
        curl --connect-timeout 5 -sLO "http$([[ "${MODE}" == 'testing' ]] && echo '://tools' || echo 's://apps').freegeek.org/qa-helper/download/QAHelper-linux-jar.zip"

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
                        
                        hdparm_drive_model="$(hdparm -I "${this_drive_id}" | grep -F 'Model Number:' | xargs | cut -c 15-)" # Use hdparm for model because lsblk gets model from sysfs ("/sys/block/<name>/device/model") which is truncated.
                        
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
