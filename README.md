# Overview

This repository contains a PowerShell script designed to manage Intune configurations and assignments. The script provides functionalities to retrieve, update, and back up Intune configurations assigned to a source group, and then update these assignments to a target group. It also includes features for handling backups and tracking changes, ensuring a smooth and reliable configuration management process.

# Features

Retrieve Configurations: Fetch all assigned configurations and applications for a specified source group.

Update Assignments: Update configurations and assignments from a source group to a target group.

Backup and Restore: Create backups of current assignments before making changes, and restore from backups if needed.

Change Tracking: Compare configurations before and after updates to track changes and ensure accuracy.

Permission Checks: Verify required permissions and prompt for missing permissions to ensure smooth execution.

# Prerequisites

PowerShell: Ensure you have PowerShell installed on your system.

Microsoft Graph PowerShell SDK: Install the Microsoft Graph PowerShell SDK to interact with Microsoft Graph API.

Install-Module Microsoft.Graph -Scope CurrentUser

Intune Permissions: Ensure your account has the necessary permissions to manage Intune configurations and assignments. Required permissions include:
User.Read.All
Group.Read.All
Device.Read.All
DeviceManagementConfiguration.ReadWrite.All
DeviceManagementApps.ReadWrite.All
DeviceManagementManagedDevices.ReadWrite.All
DeviceManagementServiceConfig.ReadWrite.All
