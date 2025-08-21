#!ipxe

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

<?php
	# Kernel Arguments: https://www.kernel.org/doc/html/v4.15/admin-guide/kernel-parameters.html
	#
	# To boot Mint 19.1:
	# https://askubuntu.com/questions/1029017/pxe-boot-of-18-04-iso (all fixes except "toram" causes hang on shutdown and reboot)
	# https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1755863
	# https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1755863/comments/14
	# https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1755863/comments/36 (this fix also causes hang on shutdown and reboot)
	#
	# Mint 19.3:
	# Boots properly without any systemd.mask flags, but will still occasionally hangs on reboot and shutdown without them.
	# Reboot and shutdown hangs on "A stop job is running for Read required files in advance" for 3 mins and then just hangs forever.
	# Using all systemd.mask flags from "https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1754777/comments/6" DOES NOT fix this hanging.
	# systemd.mask=dev-hugepages.mount systemd.mask=dev-mqueue.mount systemd.mask=sys-fs-fuse-connections.mount systemd.mask=sys-kernel-config.mount systemd.mask=sys-kernel-debug.mount systemd.mask=tmp.mount
	#
	# Mint 20:
	# Ubuntu 20.04 base finally fixes all the past PXE boot hang on shutdown and reboot issues.
	# (The PXE boot hang fixes should have theoretically been included in Mint 19.3 since it it was apparently based on Ubuntu 18.04.3, but I still experienced the same hanging issue.)
	# Ubuntu 19.10 or newer requires "ip=dhcp" as boot arg: https://bugs.launchpad.net/ubuntu/+source/casper/+bug/1848018
	# Luckily, adding "ip=dhcp" to 19.3 boots seems to not cause any issue.
	#
	# Mint 21:
	# As of Mint 21 (and Ubuntu 21.04), using "ip=dhcp" actually causes the Ethernet connection to not load a DNS server.
	# See comments in the "Mint Installer Resources/preseed/production-ubiquity-verify.sh" for more info about this issue and how it's worked around.

	$pxe_server = $_SERVER['SERVER_ADDR'];

	$distro = ($_POST['distro'] ?: 'mint');
	$version = ($_POST['version'] ?: '21');
	$desktop = ($_POST['desktop'] ?: 'cinnamon');

	$os_folder_name = "$distro-$version-$desktop";

	if ($_POST['initrd']) { // If an initrd filename is specified, always use it.
		$initrd = $_POST['initrd'];
	} else { // Otherwise, try to find the correct initrd file.
		$initrd = 'initrd';

		if (!file_exists("/srv/tftp/$os_folder_name/$initrd")) { // If an initrd file with no extension doesn't exist,
			$kernel_files = scandir("/srv/tftp/$os_folder_name"); // search for and use an initrd file with any extension.
			foreach ($kernel_files as $this_kernel_file) {
				if (strpos($this_kernel_file, 'initrd.') === 0) {
					$initrd = $this_kernel_file;
					break;
				}
			}
		}
	}

	$title = ($_POST['title'] ?: ('Linux ' . ucwords($distro) . ' ' . $version . ' (' . ucwords($desktop) . ')'));

	# Use TFTP for BIOS because HTTP does not always work properly when loading kernel files on BIOS. Keep HTTP for UEFI because it's faster and reliable.
	$tftp_or_http = ($_POST['platform'] == 'efi') ? 'http' : 'tftp';

	$ipxe_initrd_command = "initrd $tftp_or_http://$pxe_server/$os_folder_name/$initrd";

	# "initrd=$initrd" boot parameter is required for iPXE in UEFI
	# Ubuntu 19.10 (Mint 20) or newer requires "ip=dhcp" as boot arg: https://bugs.launchpad.net/ubuntu/+source/casper/+bug/1848018
	# Ubuntu 20.04 (Mint 20) runs fsck on every live boot, added "fsck.mode=skip" so that loading over the network doesn't take a long time checking filesystem.squashfs and the rest of the files: https://askubuntu.com/questions/1237389/ubuntu-20-04-every-boot-makes-a-very-long-filesystem-check
	$ipxe_boot_command = "boot $tftp_or_http://$pxe_server/$os_folder_name/vmlinuz initrd=$initrd boot=casper netboot=nfs ip=dhcp nfsroot=$pxe_server:/srv/nfs/$os_folder_name fsck.mode=skip nosplash";

	if (($distro == 'mint') && (version_compare($version, '21.3') >= 0)) $ipxe_boot_command .= ' username=mint hostname=mint'; # Starting in Mint 21.3, the "username" and "hostname" must be set to "mint" to match previous behavior or else both will just be "linux".

	if ($_POST['preseed']) {
		$ipxe_boot_command .= ' file=/cdrom/preseed/' . $_POST['preseed'] . '.seed';
		if (strpos($_POST['preseed'], 'ubiquity') !== false) $ipxe_boot_command .= ' automatic-ubiquity';
	}

	if ($_POST['extra_args']) $ipxe_boot_command .= ' ' . $_POST['extra_args'];

	if (strpos(($ipxe_boot_command . ' '), ' toram ') !== false) {
?>

echo
<?=$ipxe_initrd_command?>

echo
<?=$ipxe_boot_command?> --

<?php
	} elseif (version_compare($version, '20') >= 0) {
?>

menu Load OS over Network or into RAM?
item --gap
item --gap <?=$title?>

item --gap
item --gap
item --gap LOADING OS OVER NETWORK WILL BOOT FASTER, BUT INSTALL WILL TAKE SLIGHTLY LONGER
item --gap
item --gap LOADING OS INTO RAM WILL TAKE SLIGHTLY LONGER TO BOOT BUT WILL INSTALL FASTER
item --gap ONCE THE OS IS LOADED INTO RAM, YOU CAN DISCONNECT THE ETHERNET CABLE AND USE WI-FI
item --gap IMPORTANT: LOADING OS INTO RAM MAY FREEZE OR NOT BOOT WITHOUT AT LEAST 8 GB OF RAM
item --gap
item --gap
item --key N load-over-network          [N] Load OS over Network...
item --key R chose-load-into-ram        [R] Load OS into RAM...
choose --timeout 5000 network-menu-selection && goto ${network-menu-selection} ||
echo
exit 1

<?php
	} else {
		# The following menus and conditions were only used on Mint 19.X when an Ubuntu 18.04 bug caused loading over network (instead of into RAM) to hang on shutdown or reboot.
		# Even though this else statement will no longer get entered with the current versions of Mint that we boot to, still leaving this code here for possible future reference
		# in case there is ever another future need to show different menus based on different system parameters.

		if ($_POST['memsize']) {
			# memsize will not be available on UEFI. From https://lists.ipxe.org/pipermail/ipxe-devel/2016-January/004560.html
			# MEMMAP_SETTINGS relies on the BIOS e820 memory map and so is not available under UEFI.
			# The equivalent functionality to retrieve the UEFI memory map is not implemented.
			# I posted a request for memsize support on UEFI, but that has not been acted on as of Jan 2022: https://github.com/ipxe/ipxe/issues/429

			$memsize_mb_int = intval(preg_replace('/\D/', '', $_POST['memsize']));

			if ($memsize_mb_int > 7000) {
?>

menu 8 GB of RAM or more detected, loading OS into RAM is recommended.
item --gap
item --gap <?=$title?>

item --gap
item --gap
item --gap PLEASE NOTE: LOADING OS OVER NETWORK MAY HANG ON SHUTDOWN OR REBOOT
item --gap
item --gap
item --key R load-into-ram              [R] Load OS into RAM...
item --key N chose-load-over-network    [N] Load OS over Network...
choose --timeout 5000 toram-menu-selection && goto ${toram-menu-selection} ||
echo
exit 1

<?php
			} else {
?>

menu Less than 8 GB of RAM detected, loading OS over Network is recommended.
item --gap
item --gap <?=$title?>

item --gap
item --gap
item --gap PLEASE NOTE: LOADING OS OVER NETWORK MAY HANG ON SHUTDOWN OR REBOOT
item --gap IMPORTANT: LOADING OS INTO RAM MAY FREEZE OR NOT BOOT WITHOUT AT LEAST 8 GB OF RAM
item --gap
item --gap
item --key N load-over-network          [N] Load OS over Network...
item --key R chose-load-into-ram        [R] Load OS into RAM...
choose --timeout 5000 network-menu-selection && goto ${network-menu-selection} ||
echo
exit 1

<?php
			}
		} else {
?>

menu DOES THIS COMPUTER HAVE AT LEAST 8 GB OF RAM INSTALLED?
item --gap
item --gap <?=$title?>

item --gap
item --gap
item --gap If LESS THAN 8 GB of RAM is installed, load OS over Network instead of into RAM.
item --gap
item --gap IMPORTANT: LOADING OS INTO RAM MAY FREEZE OR NOT BOOT WITHOUT AT LEAST 8 GB OF RAM
item --gap PLEASE NOTE: LOADING OS OVER NETWORK MAY HANG ON SHUTDOWN OR REBOOT
item --gap
item --gap
item --key R chose-load-into-ram        [R] At least 8 GB of RAM is installed, load OS into RAM...
item --key N chose-load-over-network    [N] Less than 8 GB of RAM is installed, load OS over Network...
choose --timeout 15000 load-os-menu-selection && goto ${load-os-menu-selection} ||
echo
exit 1

<?php
		}
	}
?>

:chose-load-over-network
echo
echo CHOSE TO LOAD OS OVER NETWORK
sleep 1

:load-over-network
echo
echo <?=$title?>

echo
<?=$ipxe_initrd_command?>

echo
<?=$ipxe_boot_command?> --


:chose-load-into-ram
echo
echo CHOSE TO LOAD OS INTO RAM
sleep 1

:load-into-ram
echo
echo <?=$title?>

echo
<?=$ipxe_initrd_command?>

echo
<?=$ipxe_boot_command?> toram --
