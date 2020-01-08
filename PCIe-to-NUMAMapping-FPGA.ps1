#Requires -Modules posh-ssh
#https://github.com/darkoperator/Posh-SSH
#Install-Module -Name Posh-SSH

$esxhost = Read-Host "Enter ESXi Host Name"

#Close previous Posh-SSH sessions
$OpenSessions = Get-SSHSession
Foreach ($sid in $OpenSessions.SessionId) {Remove-SSHSession -Index "$_"}

#Clear previous results of executed PCIE-NUMA Mapping script
Clear-Variable b, bdf*, tempbdfObj, session -ErrorAction SilentlyContinue

#Connect to Host via SSH - This will trigger a login screen
$session = New-SSHSession -ComputerName $esxhost -Credential $cred –AcceptKey


#Discovering data phase
#Retrieving Bus/Device/Function (BDF) address of NIC Devices
ForEach-Object -Process {
    $esxcli = Get-EsxCli -VMHost $esxhost -v2
    $bdffpga = $esxcli.hardware.pci.list.Invoke() |
        where{$_.DeviceName -match " Processing accelerators"} |
        Select -ExpandProperty Address
        }        
   
#Collecting data phase
#The PCI address is transformed from a hexidecimal value to a decimal valuea
#The decimal value is required to lookup the device in the VSI shell of the ESXi host
#A VSISH command is executed to retrieve the NUMA node information of the PCIe Device
$bdfOutput = @()
foreach ($b in $bdffpga) {  

Filter bdf0 { $_ }
Filter bdf1 { $_[5,6] -join '' }
Filter bdf2 { “0x” +$_ }
Filter bdf3 { [int]$_ }
Filter bdf4 { "vsish -e get /hardware/pci/seg/0/bus/$_/slot/0/func/0/pciConfigHeader | grep 'Numa node'"}
Filter bdf5 { Invoke-SSHCommand -SSHSession $session -Command $bdf4 }
Filter bdf6 { $_ | Out-String -Stream | Select-String -Pattern "Numa node"}
Filter bdf7 { $_.ToString().Trim("Output     : {   }") }
Filter bdf8 { Get-VM -location $esxhost| Where-Object {$_.ExtensionData.Config.Hardware.Device.Backing.Id -like $bdf0 }
            Select -ExpandProperty Name }

   
#Molding collected data into appropriate output structure
#Data retrieved during the collecting data phase is stored in a PS Object
#The full transformation from hexidecimal to decimal value and vsish result can be viewed by calling $bdfOutput
$tempbdfObj = New-Object -TypeName PSObject

    # BDF0 Object creation - Calling PCI address
    $bdf0 = $b | bdf0
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "PCI-ID" -Value $bdf0
    
    # BDF1 Object creation - Isolating bus id by selecting appropriate characters of PCI Address
    $bdf1 = $b | bdf1
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "BDF1" -Value $bdf1
    
    # BDF2 Object creation - Preparing bus id for using a Integer cast operator
    $bdf2 = $bdf1 | bdf2
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "BDF2" -Value $bdf2
    
    # BDF3 Object creation - Converting Hex bus id value to decimal bus id value
    $bdf3 = $bdf2 | bdf3
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "BDF3" -Value $bdf3

    # BDF4 Object creation - Adding bus id decimal value to vsi shell command
    $bdf4 = $bdf3 | bdf4
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "BDF4" -Value $bdf4
    
    # BDF5 Object creation - Invoking vsi shell command via posh-ssh session
    $bdf5 = $bdf4 | bdf5
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "BDF5" -Value $bdf5
    
    # BDF6 Object creation - Extracting NUMA Node information from vsi shell command output
    $bdf6 = $bdf5 | bdf6
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "BDF6" -Value $bdf6
    
    # BDF7 Object creation - Trimming irrelevant characters from NUMA node output
    $bdf7 = $bdf6 | bdf7
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "NUMA Node" -Value $bdf7
    
    # BDF8 Object creation - Discovering if VMs are configured with PCIe cards as PCI passthrough device
    $bdf8 = $bdf0 | bdf8
    $tempbdfObj | Add-Member -MemberType NoteProperty -Name "PassThru Attached VMs" -Value $bdf8
    
    
    $bdfOutput += $tempbdfObj }
    
 #Writing output - Isolating Host Name, PCI-ID of devices, connected to NUMA Node, and which VMs are configured with that PCIe device 
 Write-Host ""
 $esxhost
 $bdfOutput | select-object "PCI-ID", "NUMA Node", "PassThru Attached VMs"

  $OpenSessions = Get-SSHSession
  Foreach ($sid in $OpenSessions.SessionId) {Remove-SSHSession -Index "$_"
  echo "Closing SSH session" 
  }
