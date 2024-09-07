param(
    [Parameter(Mandatory = $true, HelpMessage = "Specify the name of AFD profile")]
    [string]$afdProfileName = $null,

    [Parameter(Mandatory = $true, HelpMessage = "Specify the resource group name.")]
    [string]$resourceGroupName = $null
)

#requires -version 7

Set-StrictMode -Version Latest
#$ErrorActionPreference = 'Stop'

write-host "Getting AFD profile $afdProfileName in resource group $resourceGroupName ..."
$afdProfile = get-azfrontdoorcdnprofile -ResourceGroupName $resourceGroupName -Name $afdProfileName

write-host "Getting the endpoints for the profile..."
$profileList = Get-AzFrontDoorCdnEndpoint -ProfileName $afdProfileName -resourceGroupName $resourceGroupName

# show the endpoints using out-gridview and allow the user to select one
$selectedEndpoint = $profileList | Out-GridView -OutputMode Single
if ($null -eq $selectedEndpoint) {
    write-host "No endpoint selected. Exiting..."
    exit
}

write-host "Selected endpoint: $($selectedEndpoint.Name)"

# get all the routes for this profile and endpoint
write-host "Getting routes..."
$routes = Get-AzFrontDoorCdnRoute -EndpointName $selectedEndpoint.name -ProfileName $afdProfile.name -ResourceGroupName $ResourceGroupName


# show the list of rule sets and allow the user to select one
$ruleSets = Get-AzFrontDoorCdnRuleSet -ProfileName $afdProfileName -resourceGroupName $resourceGroupName
$selectedRuleSet = $ruleSets | Out-GridView -OutputMode Single
if ($null -eq $selectedRuleSet) {
    write-host "No rule set selected. Exiting..."
    exit
}
write-host "Selected rule set: $($selectedRuleSet.Name)"

foreach ($route in $routes)
{
    Write-Host -NoNewline "$($route.Name): "
    if (($null -ne $route.RuleSet) -and ($route.RuleSet.Count -gt 0) -and ($route.RuleSet.Id -contains $selectedRuleSet.Id))
    {
        Write-Host "X"
    }
    else {
        Write-Host "-"
    }
}



