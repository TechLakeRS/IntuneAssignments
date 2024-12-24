# Main.ps1
. .\Get.ps1
. .\Update.ps1
. .\Backup.ps1

$ErrorActionPreference = 'Stop'
$global:allConfigurations = $null

function Connect-Entra {
   try {
       $requiredPermissions = @(
           'User.Read.All',
           'Group.Read.All', 
           'Device.Read.All',
           'DeviceManagementConfiguration.ReadWrite.All',
           'DeviceManagementApps.ReadWrite.All',
           'DeviceManagementManagedDevices.ReadWrite.All',
           'DeviceManagementServiceConfig.ReadWrite.All'
       )
       Connect-MgGraph -Scopes $requiredPermissions -NoWelcome
       
       $context = Get-MgContext
       $missingPermissions = $requiredPermissions.Where{ 
           -not ($context.Scopes -contains $_) 
       }
       
       if ($missingPermissions) {
           Write-Warning "Missing permissions: $($missingPermissions -join ', ')"
           if ((Read-Host "Continue? (y/n)") -ne 'y') { 
               throw "Insufficient permissions"
           }
       }
   }
   catch {
       Write-Error $_
       exit 1
   }
}

function Get-GroupId {
   param([string]$Name)
   
   $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$Name'"
   $response = Invoke-MgGraphRequest -Uri $uri
   
   if (-not $response.value) {
       throw "Group not found: $Name"
   }
   return $response.value[0].id
}

# Main execution
try {
   Connect-Entra
   
   $sourceName = Read-Host "Source group name"
   $sourceId = Get-GroupId -Name $sourceName
   
   $global:allConfigurations = Get-Configurations -groupId $sourceId
   $appAssignments = Get-AppAssignments -groupId $sourceId
   Show-IntuneConfigurationsReport -Configurations $allConfigurations -AppAssignments $appAssignments

   # Create backup before changes
   $backupFile = Backup-IntuneAssignments
   Write-Host "Backup created at: $backupFile" -ForegroundColor Cyan
   
   $targetName = Read-Host "Target group name"
   $targetId = Get-GroupId -Name $targetName
   
   Write-Host "Do you want to proceed with the updates? (y/n): " -NoNewline
   if ((Read-Host) -eq 'y') {
       Write-Host "Starting configuration updates..." -ForegroundColor Cyan
       Update-Actions -targetGroupId $targetId
       
       # Compare changes after update
       Write-Host "`nComparing changes..."
       $differences = Compare-IntuneAssignments -BackupFile $backupFile -CurrentConfigurations $global:allConfigurations -CurrentAppAssignments $global:appAssignments
       Show-AssignmentDifferences $differences
       
       Write-Host "`nBackup is available at: $backupFile"
       Write-Host "To restore, use: Restore-IntuneAssignments -BackupFile $backupFile"
       
       Write-Host "Complete!" -ForegroundColor Green
   }
   else {
       Write-Host "Operation cancelled by user" -ForegroundColor Yellow
   }
}
catch {
   Write-Error $_
   if ($backupFile) {
       Write-Host "`nDo you want to restore from backup? (y/n): " -NoNewline
       if ((Read-Host) -eq 'y') {
           Restore-IntuneAssignments -BackupFile $backupFile
       }
   }
   exit 1
}