<?php

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

$ipxe_variants_for_platforms = [
	'BIOS' => [
		'default' => 'ipxe-undiOnly.kpxe',
		'alternate' => 'ipxe-nicDrivers.pxe'
	],
	'UEFI' => [
		'default' => 'ipxe-snpOnly.efi',
		'alternate' => 'ipxe-nicDrivers.efi'
	]
];

if ($_GET['variant']) {
	$ipxe_install_path = '/srv/tftp/boot/';
	$ipxe_variants_path = $ipxe_install_path . 'ipxe-variants/';
	
	$platform = 'BIOS';
	
	if ((strtoupper($_GET['platform']) == 'UEFI') || (strtoupper($_GET['platform']) == 'EFI')) {
		$platform = 'UEFI';
	}
	
	if ($ipxe_variants_for_platforms[$platform][$_GET['variant']]) {
		$copied_ipxe = copy($ipxe_variants_path . $ipxe_variants_for_platforms[$platform][$_GET['variant']], $ipxe_install_path . 'ipxe.' . (($platform == 'UEFI') ? 'efi' : 'pxe'));
		
		if ($copied_ipxe) {
			if (($_GET['variant'] == 'default')) {
				unlink($ipxe_variants_path . 'JUST-SET-' . $platform . '-IPXE-TO-ALTERNATE');
			} else {
				touch($ipxe_variants_path . 'JUST-SET-' . $platform . '-IPXE-TO-ALTERNATE');
			}
		}
		
		echo ($copied_ipxe ? 'SUCCESSFULLY' : 'FAILED TO') . ' SET ' . strtoupper($_GET['variant']) . ' iPXE VARIANT FOR ' . $platform;
	} else {
		echo 'INVALID iPXE VARIANT SPECIFIED';
	}
} else {
	echo 'NO iPXE VARIANT SPECIFIED';
}

?>
