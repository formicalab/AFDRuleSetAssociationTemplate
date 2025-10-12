#!/bin/bash

templateSpecRG="rg-templates-itn-001"
templateSpecName="ts-afd-itn-001"
templateSpecVersion="1.3.0"
templateSpecLocation="italynorth"
templateSpecDisplayName="FrontDoor RuleSet"
templateSpecDescription="Associate RuleSet to AFD Rules"

az ts create \
  --resource-group "$templateSpecRG" \
  --name "$templateSpecName" \
  --version "$templateSpecVersion" \
  --location "$templateSpecLocation" \
  --display-name "$templateSpecDisplayName" \
  --description "$templateSpecDescription" \
  --template-file ./template.json \
  --ui-form-definition ./uiFormDefinition.json \
  --verbose
