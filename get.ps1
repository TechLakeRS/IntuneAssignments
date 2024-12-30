function Connect-Entra {
    try {
        $requiredPermissions = @(
            'User.Read.All',
            'Group.Read.All', 
            'Device.Read.All',
            'DeviceManagementConfiguration.Read.All',
            'DeviceManagementApps.Read.All',
            'DeviceManagementManagedDevices.Read.All',
            'DeviceManagementServiceConfig.Read.All'
            <# 'DeviceManagementConfiguration.ReadWrite.All',
            'DeviceManagementApps.ReadWrite.All',
            'DeviceManagementManagedDevices.ReadWrite.All',
            'DeviceManagementServiceConfig.ReadWrite.All' #>
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
        SecurityRules = "deviceManagement/intents"
        iOSAppProtection = "deviceAppManagement/iosManagedAppProtections"
        WindowsAppProtection = "deviceAppManagement/windowsInformationProtectionPolicies"
        AppConfiguration = "deviceAppManagement/mobileAppConfigurations"
        TargetedAppConfig = "deviceAppManagement/targetedManagedAppConfigurations"
        
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
                $isCertificate = $_.'@odata.type' -match "Certificate$|TrustedRootCertificate$"
                $assignments.value.target.groupId -contains $groupId -and -not $isCertificate
             } | ForEach-Object {
                [PSCustomObject]@{
                    Type = $key
                    Name = $_.displayName ?? $_.name
                    id = $_.id
                    TemplateFamily = if ($_.templateReference.templateFamily -or $_.templateId) { 
                        $_.templateReference.templateFamily ?? $_.templateId 
                    } else { $null }
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
    param ([Parameter(Mandatory)][string]$groupId)
 
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
            $assignments = Invoke-MgGraphRequest -Uri "$baseUri/$($_.id)/assignments"
            [PSCustomObject]@{
                Type = 'Application'
                Name = $_.displayName ?? $_.name
                Id = $_.id
                '@odata.type' = $_.'@odata.type'
                Publisher = $_.publisher
                Assignments = $assignments.value
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
        [array]$AppAssignments = @(),
        [Parameter()]
        [switch]$ShowTemplateFamily
    )
    
    foreach ($key in $Configurations.Keys | Sort-Object) {
        Write-Host "`n$key" -ForegroundColor Cyan
        if ($Configurations[$key]) {
            if ($ShowTemplateFamily) {
                $grouped = $Configurations[$key] | Group-Object -Property TemplateFamily
                foreach ($group in $grouped) {
                    if ($group.Name) { Write-Host "  Template: $($group.Name)" -ForegroundColor Yellow }
                    $group.Group | ForEach-Object {
                        Write-Host "    $($_.Name) ($($_.id))"
                    }
                }
            } else {
                $Configurations[$key] | ForEach-Object {
                    Write-Host "  $($_.Name) ($($_.id))"
                }
            }
        } else {
            Write-Host "  No configurations found" -ForegroundColor Yellow
        }
    }
 
    if ($AppAssignments.Count -gt 0) {
        Write-Host "`nApplications" -ForegroundColor Cyan
        $AppAssignments | ForEach-Object {
            Write-Host "  $($_.Name) ($($_.id))"
            Write-Host "    Publisher: $($_.Publisher)"
        }
    }
}
 