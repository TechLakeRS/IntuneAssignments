# Helper function to check existing assignments
function Test-ExistingAssignment {
    param($CurrentAssignments, $TargetGroupId, $ItemName)
    
    if ($CurrentAssignments.value.target.groupId -contains $TargetGroupId) {
        Write-Host "  Skipping $ItemName - Group already assigned" -ForegroundColor Yellow
        return $true
    }
    return $false
}

function Update-Actions {
    param([string]$targetGroupId)
    
    $operations = @{
        'DeviceConfig' = 'Device Configurations'
        'SettingsCatalog' = 'Settings Catalog'
        'AdminTemplates' = 'Admin Templates'
        'CompliancePolicies' = 'Compliance Policies'
        'RemediationScripts' = 'Remediation Scripts'
        'PlatformScripts' = 'Platform Scripts'
        'Profiles' = 'Update Profiles'
        'EnrollmentConfigs' = 'Enrollment Configurations'
        'MdmWindowsInformationProtectionPolicies' = 'Windows Information Protection'
        'MobileApps' = 'Apps'
    }

    foreach ($op in $operations.Keys) {
        $function = "Update-$op"
        try {
            Write-Host "Processing $($operations[$op])..." -ForegroundColor Cyan
            & $function -targetGroupId $targetGroupId
        }
        catch {
            Write-Warning "Failed $($operations[$op]): $_"
        }
    }
}

function Update-DeviceConfig {
    param([string]$targetGroupId)
    
    foreach ($config in $global:allConfigurations.DeviceConfigurations) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($config.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $config.Name) { continue }

            $body = @{
                target = @{
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    groupId = $targetGroupId
                }
            } | ConvertTo-Json
            
            Invoke-MgGraphRequest -Uri $currentUri -Method POST -Body $body
            Write-Host "  Updated $($config.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($config.Name): $_"
        }
    }
}

function Update-SettingsCatalog {
    param([string]$targetGroupId)
    
    foreach ($config in $global:allConfigurations.SettingsCatalog) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($config.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $config.Name) { continue }
            
            $body = @{
                assignments = @($current.value + @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $targetGroupId
                    }
                })
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($config.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($config.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($config.Name): $_"
        }
    }
}

function Update-AdminTemplates {
    param([string]$targetGroupId)
    
    foreach ($config in $global:allConfigurations.AdminTemplates) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($config.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $config.Name) { continue }
            
            $body = @{
                assignments = @($current.value + @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $targetGroupId
                    }
                })
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($config.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($config.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($config.Name): $_"
        }
    }
}

function Update-CompliancePolicies {
    param([string]$targetGroupId)
    
    foreach ($policy in $global:allConfigurations.CompliancePolicies) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policy.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $policy.Name) { continue }
            
            $body = @{
                assignments = @($current.value + @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $targetGroupId
                    }
                })
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policy.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($policy.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($policy.Name): $_"
        }
    }
}

function Update-PlatformScripts {
    param([string]$targetGroupId)
    
    foreach ($script in $global:allConfigurations.PlatformScripts) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($script.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $script.Name) { continue }
            
            $assignments = @($current.value | ForEach-Object {
                @{
                    "@odata.type" = "#microsoft.graph.deviceManagementScriptGroupAssignment"
                    targetGroupId = $_.target.groupId
                    id = $_.id
                }
            })
            $assignments += @{
                "@odata.type" = "#microsoft.graph.deviceManagementScriptGroupAssignment"
                targetGroupId = $targetGroupId
            }
            
            $body = @{
                deviceManagementScriptGroupAssignments = $assignments
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($script.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($script.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($script.Name): $_"
        }
    }
}

function Update-RemediationScripts {
    param([string]$targetGroupId)
    
    foreach ($script in $global:allConfigurations.RemediationScripts) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($script.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $script.Name) { continue }
            
            $assignments = @($current.value | ForEach-Object {
                @{
                    id = $_.id
                    runRemediationScript = $_.runRemediationScript
                    target = $_.target
                    runSchedule = $_.runSchedule
                }
            })
            
            if ($current.value.Count -gt 0) {
                $template = $current.value[0]
                $assignments += @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        deviceAndAppManagementAssignmentFilterId = $template.target.deviceAndAppManagementAssignmentFilterId
                        deviceAndAppManagementAssignmentFilterType = $template.target.deviceAndAppManagementAssignmentFilterType
                        groupId = $targetGroupId
                    }
                    runRemediationScript = $template.runRemediationScript
                    runSchedule = $template.runSchedule
                }
            }
            else {
                $assignments += @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        deviceAndAppManagementAssignmentFilterId = "00000000-0000-0000-0000-000000000000"
                        deviceAndAppManagementAssignmentFilterType = "none"
                        groupId = $targetGroupId
                    }
                    runRemediationScript = $false
                    runSchedule = $null
                }
            }
            
            $body = @{
                deviceHealthScriptAssignments = $assignments
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($script.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($script.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($script.Name): $_"
        }
    }
}

function Update-Profiles {
    param([string]$targetGroupId)
    
    $profileTypes = @{
        WindowsUpdateProfiles = "windowsQualityUpdateProfiles"
        AutopilotDeploymentProfiles = "windowsAutopilotDeploymentProfiles"
        DriverUpdateProfiles = "windowsDriverUpdateProfiles"
        FeatureUpdateProfiles = "windowsFeatureUpdateProfiles"
    }
    
    foreach ($type in $profileTypes.Keys) {
        Write-Host "`nProcessing $type..." -ForegroundColor Cyan
        
        if (-not $global:allConfigurations.$type) {
            Write-Host "  No $type configurations found" -ForegroundColor Yellow
            continue
        }

        foreach ($profile in $global:allConfigurations.$type) {
            try {
                $currentUri = "https://graph.microsoft.com/beta/deviceManagement/$($profileTypes[$type])/$($profile.id)/assignments"
                $current = Invoke-MgGraphRequest -Uri $currentUri
                if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $profile.Name) { continue }
                
                Write-Host "  Updating profile: $($profile.Name)" -ForegroundColor Gray
                Write-Host "    ID: $($profile.id)" -ForegroundColor Gray
                Write-Host "    Current assignments: $($current.value.Count)" -ForegroundColor Gray
                
                $body = @{
                    assignments = @($current.value + @{
                        target = @{
                            "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                            groupId = $targetGroupId
                        }
                    })
                } | ConvertTo-Json -Depth 10
                
                $uri = "https://graph.microsoft.com/beta/deviceManagement/$($profileTypes[$type])/$($profile.id)/assign"
                Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
                Write-Host "    ✓ Successfully updated" -ForegroundColor Green
            }
            catch {
                Write-Host "    ✗ Failed to update: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

function Update-EnrollmentConfigs {
    param([string]$targetGroupId)
    
    foreach ($config in $global:allConfigurations.EnrollmentConfigs) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations/$($config.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $config.Name) { continue }
            
            $body = @{
                enrollmentConfigurationAssignments = @(
                    $current.value | ForEach-Object {
                        @{
                            target = @{
                                "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                                groupId = $_.target.groupId
                            }
                        }
                    }
                    @{
                        target = @{
                            "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                            groupId = $targetGroupId
                        }
                    }
                )
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations/$($config.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($config.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($config.Name): $_"
        }
    }
}

function Update-MdmWindowsInformationProtectionPolicies {
    param([string]$targetGroupId)
    
    foreach ($policy in $global:allConfigurations.MdmWindowsInformationProtectionPolicies) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies/$($policy.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $policy.Name) { continue }
            
            $body = @{
                assignments = @($current.value + @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $targetGroupId
                    }
                })
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies/$($policy.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Updated $($policy.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed $($config.Name): $_"
        }
    }
}

function Update-MobileApps {
    param([string]$targetGroupId)
    
    foreach ($app in $appAssignments) {
        try {
            $currentUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/assignments"
            $current = Invoke-MgGraphRequest -Uri $currentUri
            if (Test-ExistingAssignment -CurrentAssignments $current -TargetGroupId $targetGroupId -ItemName $app.Name) { 
                continue
            }
            
            $sourceAssignment = $current.value | Where-Object { $_.target.groupId -eq $sourceId }
            $intent = if ($sourceAssignment) { $sourceAssignment.intent } else { "Required" }

            $body = @{
                mobileAppAssignments = @($current.value + @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $targetGroupId
                    }
                    intent = $intent
                })
            } | ConvertTo-Json -Depth 10
            
            $uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/assign"
            Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            Write-Host "  Added $($app.Name) with intent '$intent'" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed to add $($app.Name): $_"  
        }
    }
}