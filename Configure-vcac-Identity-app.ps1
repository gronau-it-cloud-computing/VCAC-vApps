#Configure-VCAC-App.ps1
#--------------------------------------------------------------------------
#19-Sep-2014,MAF,Created by Mike Foley. mike@yelof.com or mfoley@vmware.com
#--------------------------------------------------------------------------
#This script is a Powershell wrapper around a script from William Lam for configuring the VCAC Identity Appliance. 
#William's script has been updated to support 6.1 of the VCAC App.
#
#
#
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
# Updated by Mike Foley for VCAC 6.1 Identity VA 

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

SSL_CERT_ORGANIZATION=lab.local
SSL_CERT_ORGANIZATION_UNIT=Marketing
SSL_CERT_COUNTRY=US
SSL_CERT_STATE=CA
SSl_CERT_CITY="Palo Alto"
SSL_CERT_EMAIL=mfoley@vmware.com
SSL_STORE_FILE = "/usr/lib/vmware-sts/conf/ssoserver.p12"
SSL_STORE_PWD = "changeme"
SSL_STORE_ALIAS = "ssoserver"

### DO NOT EDIT BEYOND HERE ###
VCAC_CONFIG_LOG=vghetto-MF-vcac-SSO.log
PRIVATE_KEY_FILE=server.key
CSR_FILE=server.csr
CERT_FILE=server.crt
PFX_FILE=ssoserver.p12

###############################To be fixed Up##########################
echo "Generating Private Key ..."
# OpenSSL Function in config-page.py
/usr/bin/openssl genrsa -aes256 -passout 'pass:123456' -out "`${PRIVATE_KEY_FILE}" 2048 >> "`${VCAC_CONFIG_LOG}" 2>&1

echo "Generating CSR ..."
/usr/bin/openssl req -new -key "`${PRIVATE_KEY_FILE}" -out "`${CSR_FILE}" -passin 'pass:vmware123' -utf8 -subj "/C=`${SSL_CERT_COUNTRY}/ST=`${SSL_CERT_STATE}/L=`${SSl_CERT_CITY}/O=`${SSL_CERT_ORGANIZATION}/OU=`${SSL_CERT_ORGANIZATION_UNIT}/CN=`${VCAC_SSO_HOSTNAME}/emailAddress=`${SSL_CERT_EMAIL}" >> "`${VCAC_CONFIG_LOG}" 2>&1

echo "Removing passphrase from Private Key ..."
/bin/cp "`${PRIVATE_KEY_FILE}" "`${PRIVATE_KEY_FILE}.org" >> "`${VCAC_CONFIG_LOG}" 2>&1
/usr/bin/openssl rsa -in "`${PRIVATE_KEY_FILE}.org" -out "`${PRIVATE_KEY_FILE}" -passin 'pass:vmware123' >> "`${VCAC_CONFIG_LOG}" 2>&1

echo "Generate Self-Signed Certificate ..."
/usr/bin/openssl x509 -req -days 365 -in "`${CSR_FILE}" -signkey "`${PRIVATE_KEY_FILE}" -out "`${CERT_FILE}" >> "`${VCAC_CONFIG_LOG}" 2>&1

echo "Copy the certificate to the correct location"
cp "`${CERT_FILE}" "`${SSL_STORE_FILE}"

echo "Restart the Identity Server to pick up the new certificate"
/etc/init.d/vmware-stsd restart

echo "Waiting 5 minutes for VCAC SSO services to startup ..."
sleep 300

VCAC_CONFIG_LOG=vghetto-MF-vcac-id.log

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