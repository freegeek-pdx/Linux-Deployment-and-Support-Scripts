#!/bin/bash

#
# Created by Pico Mitchell
# Last Updated: 02/01/22
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

if pgrep -u mint systemd &> /dev/null && [[ ( "${TERM}" == 'linux' || "${TERM}" == 'xterm-256color' ) && "$(id -un)" == 'mint' && "${HOME}" == '/home/mint' ]]; then # Only run if fully logged in as "mint" user with an interactive terminal by checking that TERM is "linux" (on 20.2) or "xterm-256color" (on 20.3).
    this_tty="$(tty | cut -c 6-)"
    this_tty="${this_tty^^}"
    
    echo -e "\nPROFILE FOR ${this_tty}: SETTERM AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
    
    setterm -blank 0 -powersave off -foreground cyan 2> /dev/null
    
    if grep -q ' 3 ' '/proc/cmdline' && [[ "$(tty)" == '/dev/tty1' ]]; then
        echo "PROFILE FOR ${this_tty}: CALLING SETUP MINT LIVE RESCUE BECAUSE IS TTY1 AND BOOTED INTO CLI MODE AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
        
        # Don't need to call /usr/bin/setup-mint-live-rescue when not booted into CLI Mode (Runlevel 3) because it will get called by /etc/xdg/autostart/setup-mint-live-rescue.desktop when Cinnamon is started.
        # And, only need to call /usr/bin/setup-mint-live-rescue for TTY1 because the settings apply to all TTYs.
        
        '/usr/bin/setup-mint-live-rescue' & disown
    else
        echo "PROFILE FOR ${this_tty}: DID NOT CALL SETUP MINT LIVE RESCUE BECAUSE NOT TTY1 OR NOT BOOTED INTO CLI MODE AT $(date)" | sudo tee -a '/setup-mint-live-rescue.log' > /dev/null # DEBUG
    fi
fi
