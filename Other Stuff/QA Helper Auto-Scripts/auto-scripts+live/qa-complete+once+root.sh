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

echo 'RE-RUNNING FIRST LAUNCH SCRIPTS'
"${BASH_SOURCE[0]%/*}/launch+once+root.sh" 'qa-complete'


echo 'CUSTOMIZING SETTINGS FOR END USER' # https://help.gnome.org/admin/system-admin-guide/stable/dconf-custom-defaults.html.en
cat << DCONF_USER_PROFILE_EOF > '/etc/dconf/profile/user'
user-db:user
system-db:local
DCONF_USER_PROFILE_EOF

mkdir -p '/etc/dconf/db/local.d'

cat << DCONF_LOCAL_CUSTOMIZATIONS_EOF > '/etc/dconf/db/local.d/00-fg-customizations'
# Show trash on desktop
[org/nemo/desktop]
trash-icon-visible=true

# Set panel clock format
[org/cinnamon/desktop/interface]
clock-use-24h=false
clock-show-date=true

# Set screensaver/lock screen clock format
[org/cinnamon/desktop/screensaver]
use-custom-format=true
time-format='%-I:%M:%S %p'
date-format='    %A %B %-d, %Y'
DCONF_LOCAL_CUSTOMIZATIONS_EOF

dconf update
