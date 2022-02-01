<!doctype html>
<!--
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
-->
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta http-equiv="refresh" content="60">
	<title>Free Geek - Set iPXE Variant</title>
	<style>
		body {
			font-family: sans-serif;
			text-align: center;
			margin: 30px auto;
			padding: 0px 15px;
			max-width: 600px;
		}
		
		button {
			-webkit-transition: color 0.3s linear, background-color 0.3s linear;
			-moz-transition: color 0.3s linear, background-color 0.3s linear;
			transition: color 0.3s linear, background-color 0.3s linear;
			background-color: #88287B;
			border: none;
			color: #ffffff;
			font-size: 16px;
			font-weight: bold;
			padding: 15px;
		}
		
		button:hover {
			background-color: #55184D;
		}

		button:focus {
			outline: 0;
		}
		
		.alternate {
			color: #226E8A;
		}
		
		.success {
			color: #009933;
		}
		
		.error {
			color: #CC3333;
		}
	</style>
</head>
<body>
<?php
if (array_key_exists('platform', $_POST) && array_key_exists('variant', $_POST)) {
	$set_ipxe_variant_result = file_get_contents('http://newbeta.fglan/boot/ipxe-variants/set-ipxe-variant.php?platform=' . urlencode($_POST['platform']) . '&variant=' . urlencode($_POST['variant']));
	
	$result_class = ((strpos($set_ipxe_variant_result, 'SUCCESSFULLY') !== false) ? 'success' : 'error');
	$set_ipxe_variant_result = str_replace('ALTERNATE', '<strong>ALTERNATE</strong>', $set_ipxe_variant_result);
	$set_ipxe_variant_result = str_replace('SET DEFAULT', 'RESET <strong>DEFAULT</strong>', $set_ipxe_variant_result);
	$set_ipxe_variant_result = str_replace('BIOS', '<strong>LEGACY BIOS</strong>', $set_ipxe_variant_result);
	$set_ipxe_variant_result = str_replace('UEFI', '<strong>UEFI</strong>', $set_ipxe_variant_result);
	
	if ($result_class == 'error') {
		$set_ipxe_variant_result .= '<br/><strong>!!! PLEASE <a href="https://docs.google.com/a/freegeek.org/forms/d/e/1FAIpQLSdVoKXglaAbdQUw8HdQrQTBl6WQVJssUocSnig542ka6tWuAw/viewform" target="_blank">SUBMIT AN I.T. REPORT</a> ABOUT THIS ISSUE !!!</strong>';
	}
?>
	<div class="<?=$result_class?>">
		<strong>SET iPXE VARIANT RESULT:</strong>
		<br/>
		<em><?=$set_ipxe_variant_result?></em>
<?php
} else {
?>
	<div>
		<em>If you're having issues loading iPXE, you can use the buttons below to change the variant for either Legacy BIOS iPXE or UEFI iPXE (whichever you're trying to boot).</em>
<?php
}
?>
	</div>
	<br/>
	
	<strong>AFTER CHANGING THE iPXE VARIANT, REBOOT THE COMPUTER YOU WERE HAVING ISSUES WITH TO LOAD THE NEWLY SET VARIANT OF iPXE.</strong>
	
	<br/>
	<br/>
	
	<em>After manually setting iPXE to the alternate variant, iPXE will be automatically reset to the default variant after 5-10 minutes.</em>
	
	<br/>
	<br/>
	<br/>
	
<?php
$installed_ipxe_variants = json_decode(file_get_contents('http://newbeta.fglan/boot/ipxe-variants/installed-ipxe-variants.php'), true);

// Check if any installed iPXE variants are "UNKNOWN" and reset them to the default variant if so.
// This is make iPXE updates easy... when versions are update in the ipxe-variants folder, just open this page to immediately update the installed versions.
// Otherwise, installed iPXE versions will get updated on the 5 minute mark from the cron job.
$some_variant_was_unknown = false;
foreach ($installed_ipxe_variants as $platform => $platform_variant_info) {
	if ($platform_variant_info['installed_variant'] == 'UNKNOWN') {
		$some_variant_was_unknown = true;
		
		$set_ipxe_variant_result = file_get_contents('http://newbeta.fglan/boot/ipxe-variants/set-ipxe-variant.php?platform=' . urlencode($platform) . '&variant=default');
		if (strpos($set_ipxe_variant_result, 'SUCCESSFULLY') !== false) {
			echo '<strong class="success">&gt;&gt;&gt; UPDATED ' . $platform . ' iPXE TO NEWER DEFAULT VARIANT &lt;&lt;&lt;</strong><br/>';
		} else {
			echo '<strong class="error">!!! FAILED TO UPDATE ' . $platform . ' iPXE TO NEWER DEFAULT VARIANT !!!</strong><br/>';
		}
	}
}
if ($some_variant_was_unknown) {
	echo '<br/><br/>';
	$installed_ipxe_variants = json_decode(file_get_contents('http://newbeta.fglan/boot/ipxe-variants/installed-ipxe-variants.php'), true);
}

foreach ($installed_ipxe_variants as $platform => $platform_variant_info) {
	$platform_display_name = '<strong>' . (($platform == 'BIOS') ? 'Legacy BIOS' : $platform) . '</strong>';
	$installed_ipxe_variant_for_platform_is_default = ($platform_variant_info['installed_variant'] == 'default');
?>
	
	<div<?=($installed_ipxe_variant_for_platform_is_default ? '' : ' class="alternate"')?>>
		<?=$platform_display_name?> iPXE is <?=($installed_ipxe_variant_for_platform_is_default ? 'Currently' : 'Temporarily')?> Set to the <strong><?=($installed_ipxe_variant_for_platform_is_default ? 'Default' : '<em>Alternate</em>')?></strong> Variant
		
<?php
	if ($platform_variant_info['installed_until']) {
?>
		<br/>
		<em><?=$platform_display_name?> iPXE will be automatically reset to the default variant at <?=date('h:i A', $platform_variant_info['installed_until'])?></em>
<?php
	}
?>
	</div>
	
	<form method="post" action="<?=htmlentities($_SERVER['PHP_SELF'])?>">
		<input type="hidden" name="platform" value="<?=$platform?>">
		<input type="hidden" name="variant" value="<?=($installed_ipxe_variant_for_platform_is_default ? 'alternate' : 'default')?>">
		<button type="submit" name="submit"><?=($installed_ipxe_variant_for_platform_is_default ? 'Set' : 'Reset')?> <?=$platform_display_name?> iPXE to <?=($installed_ipxe_variant_for_platform_is_default ? '<em>Alternate</em>' : 'Default')?> Variant <?=($installed_ipxe_variant_for_platform_is_default ? 'Temporarily' : 'Now')?></button>
	</form>
	
	<br/>
	<br/>
	
<?php
}
?>
	
	<em>If the computer fails to load iPXE using both the default and alternate variants, please <a href="https://docs.google.com/a/freegeek.org/forms/d/e/1FAIpQLSdVoKXglaAbdQUw8HdQrQTBl6WQVJssUocSnig542ka6tWuAw/viewform" target="_blank">submit an I.T. report</a> about the issue with details about the computer/motherboard model and all iPXE error messages.</em>
</body>
</html>
