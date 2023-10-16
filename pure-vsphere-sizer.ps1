<#
    .SYNOPSIS
    Generates vSphere sizing data for Pure Storage FlashArray


#>

#Requires -Version 7.0 -Modules @{Modulename="VMware.PowerCLI";ModuleVersion="13.0"}

# Obtain parameters
param(
    [string]$vCenter
)

# Load Modules
Write-Verbose "Attempting to load required modules"
Import-Module VMware.PowerCLI -ErrorAction Stop

# Check if InvalidCertificateAction is set to ignore; Prompt user if not
if ((Get-PowerCLIConfiguration).InvalidCertificateAction -ne "Ignore") {
    Write-Host -ForegroundColor Red -NoNewline "Warning: "
    Write-Host "PowerCLI is not configured to ignore invalid certificates."
    Write-Host "If your vCenter Server is not using valid signed certificates (e.g.: the default self-signed certificate that comes installed with vCenter) this script will fail to connect."
    Write-Host "To allow the script to connect you must set InvalidCertificateAction to ""Ignore"" by running the following command:"
    Write-Host "Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore"
    Start-Sleep -Seconds 2
}

# Obtain credentials for vCenter
if (!$vCCredentials) {
    $vCCredentials = Get-Credential -Message "Enter login credentials for $($vCenter)"
}

# Connect to vCenter
try {
    Write-Verbose "Attempting to connect to vCenter Server $($vCenter)"
    $vCenterObj = Connect-VIServer $vCenter -Credential $vCCredentials
}
catch {
    Write-Verbose "Connection to $($vCenter) failed"
    Throw $_
}

# Obtain view of VM data
$VMView = Get-View -ViewType VirtualMachine -Server $vCenterObj

#TODO: Add datastore outputs
#$DSView = Get-View -ViewType Datastore -Server $vCenterObj

$Output = $VMView | ForEach-Object -Process {
    [PSCustomObject]@{
        Name                   = $_.Name
        OS                     = $_.Summary.Config.GuestFullName
        PowerState             = $_.Runtime.PowerState
        NumberDisks            = $_.Layout.Disk.Count
        ConfiguredDiskBytes    = (($_.Config.Hardware.Device | Where-Object { $_.DiskObjectId }).CapacityInBytes | Measure-Object -Sum).sum
        ConfiguredDiskMiB      = [int]((($_.Config.Hardware.Device | Where-Object { $_.DiskObjectId }).CapacityInBytes | Measure-Object -Sum).sum / 1048576)
        ConfiguredDiskTiB      = ((($_.Config.Hardware.Device | Where-Object { $_.DiskObjectId }).CapacityInBytes | Measure-Object -Sum).sum / 1099511627776)
        # TODO: Need to add logic checks for if VMware Tools is not present these don't execute, since they won't exist
        GuestReportedUsedBytes = ($_.Guest.Disk.Capacity - $_.Guest.Disk.FreeSpace)
        GuestReportedUsedMiB   = ($_.Guest.Disk.Capacity - $_.Guest.Disk.FreeSpace) / 1048576
        GuestReportedUsedTiB   = ($_.Guest.Disk.Capacity - $_.Guest.Disk.FreeSpace) / 1099511627776        
    }
}

#TODO: Add Excel output option (one worksheet per view or dataset, probably)
#TODO: Add HTML output option to generate all data in one nice, neat HTML report
$Output | Format-Table -AutoSize


# Disconnect from vCenter Server
Disconnect-VIServer $vCenterObj -Confirm:$false