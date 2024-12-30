<#
.SYNOPSIS
Main script to manage Intune configurations and assignments.

.DESCRIPTION
This script includes functions to retrieve, update, and back up Intune configurations and assignments. It retrieves configurations assigned to a source group, updates assignments to a target group, and handles backups and change tracking.

.NOTES
Author: Riyadh Sarker
Date: 24/12/2024

.EXAMPLE
.\Main.ps1
Runs the main script, prompting for source and target groups, retrieving assigned configurations and apps, performing the update process, and backing up current assignments.

.\Get.ps1
Contains the function to retrieve all assigned configurations and applications, displaying the results.

.\Update.ps1
Includes functions to update configurations from the source group to the target group.

.\Backup.ps1
Provides functionality to back up assignments and compare changes.
#>


# Main.ps1
. .\Get.ps1
. .\Update.ps1
. .\Backup.ps1

$ErrorActionPreference = 'Stop'
$global:allConfigurations = $null





# Main execution
try {
    Connect-Entra
   
    $sourceName = Read-Host "Source group name"
    $sourceId = Get-GroupId -Name $sourceName
   
    # Get and display current assignments
    $global:allConfigurations = Get-Configurations -groupId $sourceId
    $global:appAssignments = Get-AppAssignments -groupId $sourceId
    Show-IntuneConfigurationsReport -Configurations $allConfigurations -AppAssignments $appAssignments -ShowTemplateFamily

    Write-Host "`nDo you want to copy these assignments to another group? (y/n): " -NoNewline
    if ((Read-Host) -ne 'y') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit
    }

    # Create backup
    Write-Host "Creating backup before proceeding..." -ForegroundColor Cyan
    $backupFile = Backup-IntuneAssignments
    Write-Host "Backup created at: $backupFile" -ForegroundColor Cyan

    # Get target group and process updates
    $targetName = Read-Host "Target group name"
    $targetId = Get-GroupId -Name $targetName
    
    Write-Host "Starting configuration updates..." -ForegroundColor Cyan
    Update-Actions -targetGroupId $targetId
    
    
    # Show results
    Write-Host "`nComparing changes..."
    $differences = Compare-IntuneAssignments -BackupFile $backupFile `
                                           -CurrentConfigurations $global:allConfigurations `
                                           -CurrentAppAssignments $global:appAssignments
    Show-AssignmentDifferences $differences
    
    Write-Host "`nBackup available at: $backupFile"
    Write-Host "To restore: Restore-IntuneAssignments -BackupFile $backupFile"
    Write-Host "Complete!" -ForegroundColor Green
}
catch {
    Write-Error $_
    if ($backupFile) {
        Write-Host "`nRestore from backup? (y/n): " -NoNewline
        if ((Read-Host) -eq 'y') {
            Restore-IntuneAssignments -BackupFile $backupFile
        }
    }
    exit 1
}