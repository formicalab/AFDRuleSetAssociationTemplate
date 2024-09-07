New-AzTemplateSpec -ResourceGroupName "rg-templates-itn-001" `
                   -Name "ts-afd-itn-001" `
                   -DisplayName "FrontDoor RuleSet" `
                   -Description "Associate RuleSet to AFD Rules" `
                   -Version "1.0.3" `
                   -Location italynorth `
                   -TemplateFile .\template.json `
                   -UIFormDefinitionFile (Resolve-Path -Path ".\uiFormDefinition.json").Path `
                   -Verbose