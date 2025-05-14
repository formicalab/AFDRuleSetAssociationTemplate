#Requires -PSEdition Core
using module Az.Resources

$templateSpecRG = "rg-templates-itn-001"
$templateSpecName = "ts-afd-itn-001"
$templateSpecVersion = "1.1.0"
$templateSpecLocation = "italynorth"
$templateSpecDisplayName = "FrontDoor RuleSet"
$templateSpecDescription = "Associate RuleSet to AFD Rules"

New-AzTemplateSpec -ResourceGroupName $templateSpecRG `
                   -Name $templateSpecName `
                   -DisplayName $templateSpecDisplayName `
                   -Description $templateSpecDescription `
                   -Version $templateSpecVersion `
                   -Location $templateSpecLocation `
                   -TemplateFile .\template.json `
                   -UIFormDefinitionFile (Resolve-Path -Path ".\uiFormDefinition.json").Path `
                   -Verbose