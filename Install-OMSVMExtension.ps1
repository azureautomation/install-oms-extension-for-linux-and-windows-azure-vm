<#  
.SYNOPSIS  
Installs OMS extension for Linux and Windows Azure ARM VM.

.DESCRIPTION  
Installs OMS extension for Linux and Windows Azure Virtual Machines.
The Runbook takes Subscription Id VM name and installs OMS Agent on the VM
The runbook needs run as connection string to access VM in other subscriptions.
The Runbook also takes WorkspaceId and WorkspaceKey as input.

This Runbook is a child runbook for Onboard-VMsForOMSUpdateManagement.ps1. 
Onboard-VMsForOMSUpdateManagement invokes this runbook for each VM for a given comma seperated list of Azure subscriptions. 
This can be used in scenario to mass onboard list of Azure VM for OMS update management solution.  

.EXAMPLE
.\Install-OMSVMExtension

.NOTES
AUTHOR: Azure Automation Team
LASTEDIT: 2017.06.22
#>

[OutputType([String])]

param (
    [Parameter(Mandatory=$false)] 
    [String]  $AzureConnectionAssetName = "AzureRunAsConnection",
    [Parameter(Mandatory=$true)] 
    [String] $ResourceGroupName,
    [Parameter(Mandatory=$true)] 
    [String] $VMName,
    [Parameter(Mandatory=$true)] 
    [String] $subId,
    [Parameter(Mandatory=$true)] 
    [String] $workspaceId,
    [Parameter(Mandatory=$true)] 
    [String] $workspaceKey	
)
try 
{
    # Connect to Azure using service principal auth
    $ServicePrincipalConnection = Get-AutomationConnection -Name $AzureConnectionAssetName         
    Write-Output "Logging in to Azure..."
    $Null = Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $ServicePrincipalConnection.TenantId `
        -ApplicationId $ServicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint 
}
catch 
{
    if(!$ServicePrincipalConnection) 
    {
        throw "Connection $AzureConnectionAssetName not found."
    }
    else 
    {
        throw $_.Exception
    }
}

Write-Output "Selecting Subscription $($subId)"
Select-AzureRmSubscription -SubscriptionId $subId

# If there is a specific resource group, then get all VMs in the resource group,
$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName 

if($VM -eq $null) 
{
    throw "VM $($VMName) not found in resource group $($ResourceGroupName)" 
}
 
$ExtentionNameAndTypeValue = 'MicrosoftMonitoringAgent'

if ($VM.StorageProfile.OSDisk.OSType -eq "Linux") 
{
    $ExtentionNameAndTypeValue = 'OmsAgentForLinux'	
}

$vmId = $VM.Id
$Rtn = Set-AzureRmVMExtension -ResourceGroupName $VM.ResourceGroupName -VMName $VM.Name -Name $ExtentionNameAndTypeValue -Publisher 'Microsoft.EnterpriseCloud.Monitoring' -ExtensionType $ExtentionNameAndTypeValue -TypeHandlerVersion '1.0' -Location $VM.Location -SettingString "{'workspaceId': '$workspaceId', 'azureResourceId':'$vmId'}" -ProtectedSettingString "{'workspaceKey': '$workspaceKey'}" 

if ($Rtn -eq $null) 
{
    Write-Output ($VM.Name + " did not add extension")
    Write-Error ($VM.Name + " did not add extension") -ErrorAction Continue
    throw "Failed to add extension on $($VM.Name)"
}
else 
{
    Write-Output ($VM.Name + " extension has been deployed")
}