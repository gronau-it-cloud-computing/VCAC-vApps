
#vCenter
$DefaultVIServer = "pod02-wdc-vcsa.pml.local"
$VCuser = "root"
$VCPass = "VMware1!"
$TempDir = "C:\Temp\"

#Virtual Machine
$vmname = "VCACSSO61"
$vcac_SSO_VM_Password = "VMware1!"

connect-viserver "$DefaultVIServer" -user "$vcuser" -password "$vcpass" -WarningAction SilentlyContinue

$VCAC_config_Script = @"
#!/bin/bash
# William lam
# www.virtuallyghetto.com
# Script to automatically configure the VCAC Identity VA (SSO)

VCAC_SSO_PASSWORD=VMware1!
VCAC_SSO_HOSTNAME=vcacsso61.lab.local
TIMEZONE=PDT
#11-Sep-14,MAF,Differs from Williams script in that on the SSO app you need to supply the list of NTP
#servers as two separated by a space and quoted values
NTP_SERVER01="10.144.106.1"
NTP_SERVER02="10.144.106.2"
JOIN_AD=0
AD_DOMAIN=lab.local
AD_USERNAME=Administrator
AD_PASSWORD=VMware!

### DO NOT EDIT BEYOND HERE ###

VCAC_CONFIG_LOG=vghetto-vcac-id.log

echo -e "\nConfiguring NTP Server(s) to `${NTP_SERVERS}  ..."
/opt/vmware/share/vami/custom-services/bin/vami ntp use-ntp "`${NTP_SERVER01}" "`${NTP_SERVER02}" >> "`${VCAC_CONFIG_LOG}" 2>&1

echo "Configuring Timezone to `${TIMEZONE} ..."
/opt/vmware/share/vami/vami_set_timezone_cmd "`${TIMEZONE}" >> "`${VCAC_CONFIG_LOG}" 2>&1

echo "Configuring SSO ..."
/usr/lib/vmware-identity-va-mgmt/firstboot/vmware-identity-va-firstboot.sh --domain vsphere.local --password "`${VCAC_SSO_PASSWORD}"

echo "`${VCAC_SSO_HOSTNAME}:7444" > /etc/vmware-identity/hostname.txt

if [ `${JOIN_AD} -eq 1 ]; then 
	echo "`${AD_PASSWORD}" > /tmp/ad-pass

	echo "Joining AD Domain `${AD_DOMAIN}"
	/opt/likewise/bin/domainjoin-cli join "`${AD_DOMAIN}" "`${AD_USERNAME}" < /tmp/ad-pass 

	rm -f /tmp/ad-pass
fi

echo 

"@

#Clean up the config script
$VCAC_APP_Script_Clean = $VCAC_config_Script -replace "`r`n", "`n"
$VCAC_APP_Script_Clean | Out-File -FilePath ($Tempdir + "\vcac_config.sh") -Encoding UTF8 -Force

# Copy script to Log Insight
Write-Host "[CONFIGURE] Copying vcac_config.sh to VCAC App VM"
Copy-VMGuestFile -Source ($TempDir + "\vcac_config.sh") -Destination "/storage/core/vcac_config.sh" -LocalToGuest -VM "$vmname" -GuestUser root -GuestPassword "$vcac_SSO_VM_Password" -force
Write-Host "[CONFIGURE] Copy Complete"
# Run CHMOD
$chmod = "chmod +x /storage/core/vcac_config.sh"
Write-Host "[CONFIGURE] Running CHMOD on vcac_config.sh"
Invoke-VMScript -vm "$vmname" -GuestUser root -GuestPassword "$vcac_SSO_VM_Password" -ScriptType Bash -ScriptText $chmod | out-null
# Run Script
Write-Host "[CONFIGURE] Running vcac_config.sh (This will take approximately 90 seconds)"
Invoke-VMScript -VM "$vmname" -GuestUser root -GuestPassword "$vcac_SSO_VM_Password" -ScriptType Bash -ScriptText "/storage/core/vcac_config.sh" | out-null