start-transcript -path C:\scripts\iopslimit\log.txt
import-module vmware.powercli
$connect=connect-viserver vcenter-server
if ($connect -eq $null){
	for ($i=0;$i -le 60;$i++){
		sleep 60
		$connect=connect-viserver vcenter-server
		if ($connect -ne $null){
			break
		}
	}
}

[string[]]$To="user1@yourdomain.com","user2@yourdomain.com"


$From = "server@yourdomain.com"
$subject = "Установлены лимиты IOPS"
$MailServer = "mail.yourdomain.com"
$path="C:\scripts\iopslimit\"
$file="limit.csv"
$path=$path+$file
$bodyHead="<html>
                <style>
                BODY{font-family: Arial; font-size: 8pt;}
                H1{font-size: 16px;}
                H2{font-size: 14px;}
                H3{font-size: 12px;}
                TABLE{border: 1px solid black; border-collapse: collapse; font-size: 12pt;}
                TH{border: 1px solid black; background: #FFFFFF; padding: 5px; color: #000000; text-align: left}
                TD{border: 1px solid black; padding: 5px; }
                tr.white{background: #FFFFFF;}
                tr.green{color: #155724;background-color: #d4edda;border-color: #c3e6cb;}
                tr.red{color: #721c24;background-color: #f8d7da;border-color: #f5c6cb;}
                </style>
                <body>"

if ($connect -ne $null){

$HTMLtable="<H1>Установлены следующие лимиты IOPS:</H1><p><table><tr><th>Name</th><th>Result</th></tr>"


foreach($group in (Import-Csv $path -UseCulture)){
  $vm = Get-VM -Name $group.vmName
  if ($vm -ne $null){
    if ($group.IOPSLimit -eq "-1"){
       $verboseLimit="unlimited"
    }
    else {
       $verboseLimit="$($group.IOPSLimit) IOPS"
    }
  $HTMLtable+="<tr class='green'><td>$($group.vmName)</td><td>$verboseLimit</td></tr>"
  }
  else {
     $body+="<br>$($group.vmName) - <b>unable to set limit</b>"
     $HTMLtable+="<tr class='red'><td>$($group.vmName)</td><td>Не удалось изменить лимиты</td></tr>"
  }
  $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
  $vm.ExtensionData.Config.Hardware.Device |  where {$_ -is [VMware.Vim.VirtualDisk]} | %{
    $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $dev.Operation = "edit"
    $dev.Device = $_
    $label = $_.DeviceInfo.Label
    $dev.Device.StorageIOAllocation.Limit = $group.IOPSLimit
    $spec.DeviceChange += $dev
  }
  $vm.ExtensionData.ReconfigVM_Task($spec)
}
$HTMLtable+="</table>"
$bodyFoot+="</body></html>"
$body=$bodyHead+$body+$HTMLtable+$bodyFoot
}
else {
	$HTMLbody="<H1>Не удалось подключиться к серверу vcenter - <b>лимиты IOPS не изменены</b></H1>"
	$HTMLtable="<p><table><tr><th>Name</th><th>Result</th></tr>"
	foreach($group in (Import-Csv $path -UseCulture)){
		$vm = Get-VM -Name $group.vmName
		$HTMLtable+="<tr class='red'><td>$($group.vmName)</td><td>Не удалось изменить лимиты</td></tr>"
	}
	$htmlTable+="</table>"
	$bodyFoot+="</body></html>"
	$body=$bodyHead+$HTMLbody+$HTMLtable+$bodyFoot
}
Send-MailMessage -To $To -From $From -Subject $subject -Body $Body -SmtpServer $MailServer -BodyAsHtml -Encoding ([System.Text.Encoding]::UTF8)
$body
stop-transcript