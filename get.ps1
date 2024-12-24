function Get-Configurations {
    param (
        [Parameter(Mandatory)]
        [string]$groupId,
        [string]$configType = "All"
    )
 
    $uris = @{
        DeviceConfigurations = "deviceManagement/deviceConfigurations"
        SettingsCatalog = "deviceManagement/configurationPolicies"
        AdminTemplates = "deviceManagement/groupPolicyConfigurations"
        CompliancePolicies = "deviceManagement/deviceCompliancePolicies"
        PlatformScripts = "deviceManagement/deviceManagementScripts"
        RemediationScripts = "deviceManagement/deviceHealthScripts"
        WindowsUpdateProfiles = "deviceManagement/windowsQualityUpdateProfiles"
        AutopilotDeploymentProfiles = "deviceManagement/windowsAutopilotDeploymentProfiles"
        DriverUpdateProfiles = "deviceManagement/windowsDriverUpdateProfiles"  
        FeatureUpdateProfiles = "deviceManagement/windowsFeatureUpdateProfiles"   
        EnrollmentConfigs = "deviceManagement/deviceEnrollmentConfigurations"
    }
 
    $results = @{}
    foreach ($key in $uris.Keys) {
        if ($configType -ne "All" -and $key -ne $configType) { continue }
        
        try {
            Write-Host "Fetching $key..." -ForegroundColor Cyan
            $baseUri = "https://graph.microsoft.com/beta/$($uris[$key])"
            $configs = @()
            $response = Invoke-MgGraphRequest -Uri $baseUri
            
            while ($response) {
                $configs += $response.value
                if ($response.'@odata.nextLink') {
                    $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink'
                }
                else { $response = $null }
            }
 
            $results[$key] = $configs | Where-Object {
                $assignments = Invoke-MgGraphRequest -Uri "$baseUri/$($_.id)/assignments"
                $assignments.value.target.groupId -contains $groupId
            } | ForEach-Object {
                [PSCustomObject]@{
                    Type = $key
                    Name = $_.displayName ?? $_.name
                    id = $_.id
                }
            }
            
            Write-Host "  Assigned: $($results[$key].Count)" -ForegroundColor Green
        }
        catch {
            Write-Warning "  Failed to get $key : $_"
        }
    }
    return $results
 }
 
 function Get-AppAssignments {
    param (
        [Parameter(Mandatory)]
        [string]$groupId
    )
 
    try {
        Write-Host "Fetching Applications..." -ForegroundColor Cyan
        $baseUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
        $apps = @()
        $response = Invoke-MgGraphRequest -Uri $baseUri
        
        while ($response) {
            $apps += $response.value
            if ($response.'@odata.nextLink') {
                $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink'
            }
            else { $response = $null }
        }
 
        $results = $apps | Where-Object {
            $assignments = Invoke-MgGraphRequest -Uri "$baseUri/$($_.id)/assignments"
            $assignments.value.target.groupId -contains $groupId
        } | ForEach-Object {
            [PSCustomObject]@{
                Type = 'Application'
                Name = $_.displayName ?? $_.name
                id = $_.id
                '@odata.type' = $_.'@odata.type'
                Publisher = $_.publisher
            }
        }
        
        Write-Host "  Assigned: $($results.Count)" -ForegroundColor Green
        return $results
    }
    catch {
        Write-Warning "  Failed to get applications: $_"
        return @()
    }
 }
 

 
 function Show-IntuneConfigurationsReport {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configurations,
        [Parameter()]
        [array]$AppAssignments = @()
    )
    
    foreach ($key in $Configurations.Keys | Sort-Object) {
        Write-Host "`n$key" -ForegroundColor Cyan
        if ($Configurations[$key]) {
            $Configurations[$key] | ForEach-Object {
                Write-Host "  $($_.Name) ($($_.id))"
            }
        }
        else {
            Write-Host "  No configurations found" -ForegroundColor Yellow
        }
    }
 
    if ($AppAssignments.Count -gt 0) {
        Write-Host "`nApplications" -ForegroundColor Cyan
        $AppAssignments | ForEach-Object {
            Write-Host "  $($_.Name) ($($_.id))"
            Write-Host "    Type: $($_.'@odata.type')"
            Write-Host "    Publisher: $($_.Publisher)"
           
        }
    }
 }