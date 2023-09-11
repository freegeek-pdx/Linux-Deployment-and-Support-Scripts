#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell
# Last Updated: 06/23/23
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

if pgrep -u mint systemd &> /dev/null && [[ "$(id -un)" == 'mint' && "${HOME}" == '/home/mint' ]]; then # Only run if fully logged in as "mint" user.
    readonly SETUP_MLR_PID="$$"
    echo -e "\n${SETUP_MLR_PID}: STARTED SETUP MINT LIVE RESCUE AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG


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

        while IFS='' read -r this_network_interface_name; do
            echo -e "${SETUP_MLR_PID}:\tMANUALLY SETTING DNS SERVER FOR \"${this_network_interface_name}\" AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
            nmcli connection modify "${this_network_interface_name}" ipv4.dns '192.168.253.11' # Local Free Geek DNS server IP.
        done < <(nmcli -t -f NAME connection show)
    fi


    # DELETE INSTALL OS LAUNCHERS
    rm -f "${HOME}/Desktop/ubiquity.desktop"
    sudo rm -f '/usr/share/applications/ubiquity.desktop'
    sudo rm -f '/usr/bin/ubiquity'


    if ! xset q &> /dev/null; then
        sleep 1

        for wait_for_X_seconds in {1..5}; do
            if xset q &> /dev/null; then
                break
            else
                sleep 1
            fi
        done
        
        echo -e "${SETUP_MLR_PID}:\tWAITED ${wait_for_X_seconds} SECONDS FOR FOR X AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
    fi

    if xset q &> /dev/null; then
        echo -e "${SETUP_MLR_PID}:\tDISABLING SCREEN BLANKING FOR X (${DISPLAY}) AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
        
        # TURN OFF X SCREEN SLEEPING (just in case, but the following gsettings should handle it all)
        xset s noblank
        xset s off -dpms

        if ! pidof cinnamon &> /dev/null; then
            sleep 1
            
            for wait_for_cinnamon_seconds in {1..5}; do
                if pidof cinnamon &> /dev/null; then
                    break
                else
                    sleep 1
                fi
            done
            
            echo -e "${SETUP_MLR_PID}:\tWAITED ${wait_for_cinnamon_seconds} SECONDS FOR FOR CINNAMON AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
        fi

        if pidof cinnamon &> /dev/null; then
            echo -e "${SETUP_MLR_PID}:\tCUSTOMIZING GSETTINGS FOR CINNAMON AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
            
            # DISABLING NOTIFICATION SOUNDS
            gsettings set org.cinnamon.sounds notification-enabled false

            # TURN OFF ALL CINNAMON SLEEP & LOCK SETTINGS
            gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
            gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0
            
            gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
            gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
            
            gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-ac-action 'nothing'
            gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-battery-action 'nothing'
            
            gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false
            
            gsettings set org.cinnamon.desktop.session idle-delay 0
            
            gsettings set org.cinnamon.desktop.screensaver lock-enabled false
            

            # SET PANEL CLOCK FORMAT
            gsettings set org.cinnamon.desktop.interface clock-use-24h false
            gsettings set org.cinnamon.desktop.interface clock-show-date true
            

            # SET SCREENSAVER CLOCK FORMAT
            gsettings set org.cinnamon.desktop.screensaver use-custom-format true
            gsettings set org.cinnamon.desktop.screensaver time-format '%l:%M:%S %p'
            gsettings set org.cinnamon.desktop.screensaver date-format '    %A %B %e, %Y'
            

            # SET DESKTOP BACKGROUND
            gsettings set org.cinnamon.desktop.background.slideshow slideshow-enabled false
            
            if [[ -f '/usr/share/backgrounds/MintLiveRescue-DesktopPicture.png' ]]; then
                gsettings set org.cinnamon.desktop.background picture-uri 'file:///usr/share/backgrounds/MintLiveRescue-DesktopPicture.png'
                gsettings set org.cinnamon.desktop.background picture-options 'zoom'
            else
                gsettings set org.cinnamon.desktop.background primary-color '#21586C'
                gsettings set org.cinnamon.desktop.background picture-options 'none'
            fi
            

            # OPEN MAXIMIZED ROOT TERMINAL
            sudo -i gnome-terminal --maximize # Open Terminal directly to root (any subsequent Terminals will also be opened as root because of the ".desktop" launcher being edited and "~/.bashrc" is also edited to run "sudo -i" if the Terminal is not already launched as root).
        else
            echo "${SETUP_MLR_PID}: STOPPED SETUP MINT LIVE RESCUE EARLY BECAUSE CINNAMON IS NOT RUNNING AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
            exit 0 # Exit early because Cinnamon is not yet running, this script will be re-launched by "/etc/xdg/autostart/setup-mint-live-rescue.desktop" when X and Cinnamon are both running.
        fi
    elif pidof cinnamon &> /dev/null; then
        echo "${SETUP_MLR_PID}: STOPPED SETUP MINT LIVE RESCUE EARLY BECAUSE ONLY CINNAMON IS RUNNING (AND NOT X) AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
        exit 0 # Exit early because X is not yet running, this script will be re-launched by "/etc/xdg/autostart/setup-mint-live-rescue.desktop" when X and Cinnamon are both running.
    fi
    

    if ! grep -qF ' fg-no-auto-wifi ' '/proc/cmdline'; then # CHECK FOR BOOT OPTION TO NOT AUTOMATICALLY CONNECT TO WI-FI FOR USB BOOT USAGE IN SDA

        # WAIT A BIT BEFORE TRYING TO CONNET TO WI-FI ETC
        sleep 5
        

        # CONNECT TO WI-FI
        if nmcli device status | grep -qF ' wifi ' && ! nmcli device status | grep ' FG Reuse\| Free Geek' | grep -qF ' connected '; then
            echo -e "${SETUP_MLR_PID}:\tCONNECTING TO WI-FI AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG

            # Try to connect to "FG Reuse" (which may not always be close enough) for faster Wi-Fi that can also connect to fglan (useful for "toram" network live boots that can continue after being disconnected from Ethernet).
            # If connecting to "FG Reuse" fails, connect to "Free Geek" so we can at least do a good Wi-Fi test.
            rfkill unblock all &> /dev/null
            nmcli radio all on &> /dev/null
            nmcli device wifi connect 'FG Reuse' password '[SETUP SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]' &> /dev/null || nmcli device wifi connect 'Free Geek' &> /dev/null
        fi
        

        # SET CORRECT TIME
        if ! timedatectl status | grep -qF 'Time zone: America/Los_Angeles'; then
            echo -e "${SETUP_MLR_PID}:\tSETTING TIMEZONE AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG

            # Make sure proper time is set so https download works.
            timedatectl set-timezone America/Los_Angeles &> /dev/null
            timedatectl set-ntp true &> /dev/null
        fi
        
        if timedatectl status | grep -qF 'System clock synchronized: no'; then
            echo -e "${SETUP_MLR_PID}:\tSTARTING WAIT FOR TIME TO SYNC AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
            
            timedatectl set-ntp false &> /dev/null # Turn time syncing off and then
            timedatectl set-ntp true &> /dev/null # back on to provoke faster sync attempt
            
            for wait_for_time_sync_seconds in {1..30}; do # Wait up to 30 seconds for time to sync becuase download can stall if time changes in the middle of it.
                sleep 1
                
                if timedatectl status | grep -qF 'System clock synchronized: yes'; then
                    break
                fi
            done

            echo -e "${SETUP_MLR_PID}:\tFINISHED WAIT FOR TIME TO SYNC AFTER ${wait_for_time_sync_seconds} SECONDS AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
        fi
        
        if timedatectl status | grep -qF 'System clock synchronized: yes'; then
            echo -e "${SETUP_MLR_PID}:\tTIME SYNCED & SETTING BIOS CLOCK AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
            
            # Update hardware (BIOS) clock with synced system time.
            hwclock --systohc &> /dev/null
        fi
        

        # INSTALL QA HELPER (if X and Cinnamon are running)
        if xset q &> /dev/null && pidof cinnamon &> /dev/null && [[ ! -e "${HOME}/Desktop/qa-helper.desktop" ]]; then
            echo -e "${SETUP_MLR_PID}:\tINSTALLING QA HELPER AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
            
            for install_qa_helper_attempt in {1..120}; do # Try for 2 minutes to install QA Helper in case internet isn't ready right away
                curl -m 5 -sfL 'https://apps.freegeek.org/qa-helper/download/actually-install-qa-helper.sh' | bash

                if [[ -e "${HOME}/Desktop/qa-helper.desktop" ]]; then
                    rm -f "${HOME}/.config/autostart/qa-helper.desktop"
                    
                    echo -e "${SETUP_MLR_PID}:\tINSTALLED QA HELPER AFTER ${install_qa_helper_attempt} ATTEMPTS AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
                    
                    break
                else
                    sleep 1
                fi
            done
        fi
    fi
    
    
    echo "${SETUP_MLR_PID}: FINISHED SETUP MINT LIVE RESCUE AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
fi
