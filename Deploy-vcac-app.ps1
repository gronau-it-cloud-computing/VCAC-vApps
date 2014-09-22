
#vCenter
$DefaultVIServer = "pod02-wdc-vcsa.pml.local"
$VCuser = "root"
$VCPass = "VMware1!"
$TempDir = "C:\Temp\"

connect-viserver "$DefaultVIServer" -user "$vcuser" -password "$vcpass" -WarningAction SilentlyContinue


# Load OVF/OVA configuration into a variable
$ovffile = "S:\MikeF\VCAC 6.1 GA\VMware-vCAC-Appliance-6.1.0.0-2077124_OVF10.ova"
$ovfconfig = Get-OvfConfiguration $ovffile

# List properties of the OVF/OVA configuration
#$ovfconfig

# Get the values to use for deployment
$VMHost = Get-VMHost w3r6c1-tm-h360-03.pml.local 
$Datastore = get-Datastore na_pod02_wdc_nfs_200gb
$Network = Get-VirtualPortGroup -Name "DemoLAN" -VMHost $vmhost
$cluster = Get-Cluster "Infra-Cluster"
$folder = Get-Folder "VCAC Demo"
#Virtual Machine
$VMName = "VCAC-App"

# Fill out the OVF/OVA configuration parameters
# $ovfconfig.DeploymentOption.Value = "xsmall"
$ovfconfig.NetworkMapping.Network_1.Value = $Network
$ovfconfig.IpAssignment.IpProtocol.Value = "IPv4"
$ovfconfig.Common.vami.hostname.Value = "vcac-app.lab.local"
$ovfconfig.Common.varoot_password.Value = "VMware1!"
$ovfconfig.Common.va_ssh_enabled.Value = "True"
$ovfconfig.vami.VMware_vCAC_Appliance.DNS.Value = "192.168.1.10"
$ovfconfig.vami.VMware_vCAC_Appliance.gateway.Value = "192.168.1.1"
$ovfconfig.vami.VMware_vCAC_Appliance.ip0.Value = "192.168.1.23"
$ovfconfig.vami.VMware_vCAC_Appliance.netmask0.Value = "255.255.255.0"


# Deploy the OVF/OVA with the config parameters
Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Location $cluster
Move-VM -VM $VMName -Destination $folder

Start-VM -VM $VMName -config:$false -RunAsync