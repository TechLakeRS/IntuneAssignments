function Get-AssignmentUri {
    param(
        [string]$Type,
        [string]$ConfigId,
        [switch]$IsAssign
    )
    
    $baseUri = switch ($Type) {
        'DeviceConfigurations' { "deviceManagement/deviceConfigurations/$ConfigId" }
        'SettingsCatalog' { "deviceManagement/configurationPolicies/$ConfigId" }
        'AdminTemplates' { "deviceManagement/groupPolicyConfigurations/$ConfigId" }
        'CompliancePolicies' { "deviceManagement/deviceCompliancePolicies/$ConfigId" }
        'PlatformScripts' { "deviceManagement/deviceManagementScripts/$ConfigId" }
        'RemediationScripts' { "deviceManagement/deviceHealthScripts/$ConfigId" }
        'WindowsUpdateProfiles' { "deviceManagement/windowsQualityUpdateProfiles/$ConfigId" }
        'AutopilotDeploymentProfiles' { "deviceManagement/windowsAutopilotDeploymentProfiles/$ConfigId" }
        'DriverUpdateProfiles' { "deviceManagement/windowsDriverUpdateProfiles/$ConfigId" }
        'FeatureUpdateProfiles' { "deviceManagement/windowsFeatureUpdateProfiles/$ConfigId" }
        'EnrollmentConfigs' { "deviceManagement/deviceEnrollmentConfigurations/$ConfigId" }
        'Applications' { "deviceAppManagement/mobileApps/$ConfigId" }
        Default { throw "Unknown configuration type: $Type" }
    }
    
    if ($IsAssign) {
        return "https://graph.microsoft.com/beta/$baseUri/assign"
    }
    return "https://graph.microsoft.com/beta/$baseUri/assignments"
}

function Backup-IntuneAssignments {
    param(
        [Parameter(Mandatory=$false)]
        [string]$BackupName = "IntuneBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
        
        [Parameter(Mandatory=$false)]
        [string]$BackupPath = (Join-Path $PSScriptRoot "backups")
    )
    
    if (-not (Test-Path $BackupPath)) {
        New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        Write-Host "Created backup directory: $BackupPath" -ForegroundColor Cyan
    }

    $backup = @{
        Metadata = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            BackupName = $BackupName
            UserPrincipalName = (Get-MgContext).Account
        }
        Configurations = @{}
        Applications = @{}
    }
    
    # Backup configurations
    foreach ($type in $global:allConfigurations.Keys) {
        Write-Host "`nProcessing $type..." -ForegroundColor Cyan
        $backup.Configurations[$type] = @{}
        
        foreach ($config in $global:allConfigurations[$type]) {
            try {
                $uri = Get-AssignmentUri -Type $type -ConfigId $config.id
                $currentAssignments = Invoke-MgGraphRequest -Uri $uri
                
                $backup.Configurations[$type][$config.id] = @{
                    Name = $config.Name
                    Id = $config.id
                    Type = $type
                    Assignments = $currentAssignments.value
                }
                
                Write-Host "  ✓ Backed up: $($config.Name)" -ForegroundColor Green
            }
            catch {
                Write-Warning "  ✗ Failed to backup: $($config.Name) - $_"
            }
        }
    }

    # Backup app assignments
    if ($global:appAssignments) {
        Write-Host "`nProcessing Applications..." -ForegroundColor Cyan
        foreach ($app in $global:appAssignments) {
            try {
                $uri = Get-AssignmentUri -Type 'Applications' -ConfigId $app.id
                $currentAssignments = Invoke-MgGraphRequest -Uri $uri
                
                $backup.Applications[$app.id] = @{
                    Name = $app.Name
                    Id = $app.id
                    Type = $app.'@odata.type'
                    Publisher = $app.Publisher
                    Assignments = $currentAssignments.value
                }
                
                Write-Host "  ✓ Backed up app: $($app.Name)" -ForegroundColor Green
            }
            catch {
                Write-Warning "  ✗ Failed to backup app: $($app.Name) - $_"
            }
        }
    }

    # Save backup to file
    $backupFile = Join-Path $BackupPath "$BackupName.json"
    $backup | ConvertTo-Json -Depth 20 | Out-File $backupFile -Encoding UTF8
    
    Write-Host "`nBackup completed successfully" -ForegroundColor Green
    Write-Host "Saved to: $backupFile" -ForegroundColor Cyan
    
    return $backupFile
}

function Restore-IntuneAssignments {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupFile,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )

    if (-not (Test-Path $BackupFile)) {
        throw "Backup file not found: $BackupFile"
    }

    try {
        $backup = Get-Content $BackupFile -Raw | ConvertFrom-Json -AsHashtable
        Write-Host "Loading backup from: $BackupFile" -ForegroundColor Cyan
        Write-Host "Backup created: $($backup.Metadata.Timestamp)" -ForegroundColor Cyan
        Write-Host "Created by: $($backup.Metadata.UserPrincipalName)`n" -ForegroundColor Cyan
    }
    catch {
        throw "Failed to load backup file: $_"
    }

    # Restore configurations
    foreach ($type in $backup.Configurations.Keys) {
        Write-Host "`nProcessing $type..." -ForegroundColor Cyan
        
        foreach ($configId in $backup.Configurations[$type].Keys) {
            $config = $backup.Configurations[$type][$configId]
            try {
                $uri = Get-AssignmentUri -Type $type -ConfigId $configId -IsAssign
                
                $body = switch ($type) {
                    'PlatformScripts' { 
                        @{ deviceManagementScriptGroupAssignments = $config.Assignments }
                    }
                    'RemediationScripts' { 
                        @{ deviceHealthScriptAssignments = $config.Assignments }
                    }
                    'EnrollmentConfigs' { 
                        @{ enrollmentConfigurationAssignments = $config.Assignments }
                    }
                    Default { 
                        @{ assignments = $config.Assignments }
                    }
                }
                
                $bodyJson = $body | ConvertTo-Json -Depth 20

                if ($WhatIf) {
                    Write-Host "  WhatIf: Would restore $($config.Name)" -ForegroundColor Yellow
                    continue
                }

                Invoke-MgGraphRequest -Uri $uri -Method Post -Body $bodyJson
                Write-Host "  ✓ Restored: $($config.Name)" -ForegroundColor Green
            }
            catch {
                Write-Warning "  ✗ Failed to restore: $($config.Name) - $_"
            }
        }
    }

    # Restore app assignments
    if ($backup.Applications) {
        Write-Host "`nProcessing Applications..." -ForegroundColor Cyan
        foreach ($appId in $backup.Applications.Keys) {
            $app = $backup.Applications[$appId]
            try {
                $uri = Get-AssignmentUri -Type 'Applications' -ConfigId $appId -IsAssign
                
                $body = @{
                    assignments = $app.Assignments
                } | ConvertTo-Json -Depth 20

                if ($WhatIf) {
                    Write-Host "  WhatIf: Would restore app $($app.Name)" -ForegroundColor Yellow
                    continue
                }

                Invoke-MgGraphRequest -Uri $uri -Method Post -Body $body
                Write-Host "  ✓ Restored app: $($app.Name)" -ForegroundColor Green
            }
            catch {
                Write-Warning "  ✗ Failed to restore app: $($app.Name) - $_"
            }
        }
    }
}

function Compare-IntuneAssignments {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupFile,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$CurrentConfigurations,

        [Parameter(Mandatory=$false)]
        [array]$CurrentAppAssignments = @()
    )

    if (-not (Test-Path $BackupFile)) {
        throw "Backup file not found: $BackupFile"
    }

    $backup = Get-Content $BackupFile | ConvertFrom-Json -AsHashtable
    $differences = @{
        Configurations = @{}
        Applications = @{}
    }

    # Compare configurations
    foreach ($type in $CurrentConfigurations.Keys) {
        $differences.Configurations[$type] = @{}
        
        foreach ($config in $CurrentConfigurations[$type]) {
            try {
                $uri = Get-AssignmentUri -Type $type -ConfigId $config.id
                $currentAssignments = Invoke-MgGraphRequest -Uri $uri
                
                $backupConfig = $backup.Configurations[$type][$config.id]
                if (-not $backupConfig) {
                    $differences.Configurations[$type][$config.id] = @{
                        Name = $config.Name
                        Status = "New configuration - not in backup"
                        BackupAssignments = $null
                        CurrentAssignments = $currentAssignments.value
                    }
                    continue
                }

                $backupGroups = $backupConfig.Assignments.target.groupId
                $currentGroups = $currentAssignments.value.target.groupId
                
                if (Compare-Object $backupGroups $currentGroups) {
                    $differences.Configurations[$type][$config.id] = @{
                        Name = $config.Name
                        Status = "Assignments changed"
                        BackupAssignments = $backupConfig.Assignments
                        CurrentAssignments = $currentAssignments.value
                    }
                }
            }
            catch {
                Write-Warning "Failed to compare $($config.Name): $_"
            }
        }
    }

    # Compare app assignments
    if ($CurrentAppAssignments) {
        foreach ($app in $CurrentAppAssignments) {
            try {
                $uri = Get-AssignmentUri -Type 'Applications' -ConfigId $app.id
                $currentAssignments = Invoke-MgGraphRequest -Uri $uri
                
                $backupApp = $backup.Applications[$app.id]
                if (-not $backupApp) {
                    $differences.Applications[$app.id] = @{
                        Name = $app.Name
                        Status = "New application - not in backup"
                        BackupAssignments = $null
                        CurrentAssignments = $currentAssignments.value
                    }
                    continue
                }

                $backupGroups = $backupApp.Assignments.target.groupId
                $currentGroups = $currentAssignments.value.target.groupId
                
                if (Compare-Object $backupGroups $currentGroups) {
                    $differences.Applications[$app.id] = @{
                        Name = $app.Name
                        Status = "Assignments changed"
                        BackupAssignments = $backupApp.Assignments
                        CurrentAssignments = $currentAssignments.value
                    }
                }
            }
            catch {
                Write-Warning "Failed to compare app $($app.Name): $_"
            }
        }
    }

    return $differences
}

function Show-AssignmentDifferences {
    param($Differences)
    
    # Show configuration differences
    foreach ($type in $Differences.Configurations.Keys) {
        if ($Differences.Configurations[$type].Count -eq 0) { continue }
        
        Write-Host "`n$type Changes:" -ForegroundColor Cyan
        foreach ($configId in $Differences.Configurations[$type].Keys) {
            $diff = $Differences.Configurations[$type][$configId]
            Write-Host "  $($diff.Name)" -ForegroundColor Yellow
            Write-Host "    Status: $($diff.Status)"
            
            if ($diff.BackupAssignments) {
                Write-Host "    Backup Assignments:" -NoNewline
                $diff.BackupAssignments.target.groupId | ForEach-Object {
                    Write-Host " $_" -NoNewline
                }
                Write-Host ""
            }
            
            if ($diff.CurrentAssignments) {
                Write-Host "    Current Assignments:" -NoNewline
                $diff.CurrentAssignments.target.groupId | ForEach-Object {
                    Write-Host " $_" -NoNewline
                }
                Write-Host ""
            }
        }
    }

    # Show application differences
    if ($Differences.Applications.Count -gt 0) {
        Write-Host "`nApplication Changes:" -ForegroundColor Cyan
        foreach ($appId in $Differences.Applications.Keys) {
            $diff = $Differences.Applications[$appId]
            Write-Host "  $($diff.Name)" -ForegroundColor Yellow
            Write-Host "    Status: $($diff.Status)"
            
            if ($diff.BackupAssignments) {
                Write-Host "    Backup Assignments:" -NoNewline
                $diff.BackupAssignments.target.groupId | ForEach-Object {
                    Write-Host " $_" -NoNewline
                }
                Write-Host ""
            }
            
            if ($diff.CurrentAssignments) {
                Write-Host "    Current Assignments:" -NoNewline
                $diff.CurrentAssignments.target.groupId | ForEach-Object {
                    Write-Host " $_" -NoNewline
                }
                Write-Host ""
            }
        }
    }
}