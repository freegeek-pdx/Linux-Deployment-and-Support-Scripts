#!/bin/bash

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

if ! grep -q 'boot=casper' '/proc/cmdline'; then
    echo 'VERIFYING FREE GEEK SUPPORT INSTALLATION'
    if [[ ! -e '/usr/share/applications/fg-support.desktop' ]]; then
        for install_free_geek_support_attempt in {1..5}; do
            echo -e '\n\nPREPARING TO INSTALL FREE GEEK SUPPORT\n'
            curl -m 5 -sL 'https://apps.freegeek.org/fg-support/download/actually-install-fg-support.sh' | bash
            
            if [[ -e '/usr/share/applications/fg-support.desktop' ]]; then
                break
            else
                sleep "${install_free_geek_support_attempt}"
            fi
        done
    fi

    echo 'VERIFYING OEM-CONFIG-GTK INSTALLATION'
    apt-get install --no-install-recommends -qq oem-config-gtk

    echo 'VERIFYING MINT-META-CODECS INSTALLATION'
    apt-get install -qq mint-meta-codecs
fi
