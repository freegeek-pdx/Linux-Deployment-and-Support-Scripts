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

$ipxe_install_path = '/srv/tftp/boot/';
$ipxe_variants_path = $ipxe_install_path . 'ipxe-variants/';

$installed_ipxe_variants = [];

foreach ($ipxe_variants_for_platforms as $platform => $platform_variants) {
	$installed_ipxe_for_platform_path = $ipxe_install_path . 'ipxe.' . (($platform == 'UEFI') ? 'efi' : 'pxe');
	
	$installed_ipxe_is_default = compareFiles($installed_ipxe_for_platform_path, $ipxe_variants_path . $platform_variants['default']);
	$installed_ipxe_is_alternate = compareFiles($installed_ipxe_for_platform_path, $ipxe_variants_path . $platform_variants['alternate']);
	
	$installed_ipxe_variants[$platform] = [
		'installed_variant' => ($installed_ipxe_is_default ?
			'default' : ($installed_ipxe_is_alternate ?
				'alternate' :
				'UNKNOWN'
			)
		)
	];
	
	if (!$installed_ipxe_is_default) {
		$next_ipxe_reset_time = ceil(time() / 300) * 300;
		if (file_exists($ipxe_variants_path . 'JUST-SET-' . $platform . '-IPXE-TO-ALTERNATE')) {
			$next_ipxe_reset_time += 300;
		}
		
		$installed_ipxe_variants[$platform]['installed_until'] = $next_ipxe_reset_time;
	}
}

echo json_encode($installed_ipxe_variants);

function compareFiles($fileOne, $fileTwo) // From: https://jonlabelle.com/snippets/view/php/quickly-check-if-two-files-are-identical
{
	if (!file_exists($fileOne) || !file_exists($fileTwo)) return false;
	
    if (filetype($fileOne) !== filetype($fileTwo)) return false;
    if (filesize($fileOne) !== filesize($fileTwo)) return false;
 
    if (! $fp1 = fopen($fileOne, 'rb')) return false;
 
    if (! $fp2 = fopen($fileTwo, 'rb'))
    {
        fclose($fp1);
        return false;
    }
 
    $same = true;
 
    while (! feof($fp1) and ! feof($fp2))
        if (fread($fp1, 4096) !== fread($fp2, 4096))
        {
            $same = false;
            break;
        }
 
    if (feof($fp1) !== feof($fp2)) $same = false;
 
    fclose($fp1);
    fclose($fp2);
 
    return $same;
}

?>
