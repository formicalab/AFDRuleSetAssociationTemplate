# Azure Front Door Load Balancing Template

This ARM template automates percentage-based load balancing configuration for Azure Front Door Premium routes. It enables operators to quickly adjust traffic distribution between Site A and Site B by applying pre-configured rulesets to routes following a specific naming pattern.

## Overview

The template consists of:

- **template.json** – ARM deployment template that updates route ruleset associations
- **uiFormDefinition.json** – Azure Portal UI definition for guided configuration
- **install-template.ps1** / **install-template.sh** – Deployment scripts for Template Spec registration

## Key Concepts

### Route Naming Pattern

Only routes matching the format `route-to-<identifier>` are processed by this template.

**Examples:**
- `route-to-azure`
- `route-to-onprem`
- `route-to-webapp`

The `<identifier>` portion (e.g., `azure`, `onprem`) is extracted and used to match the corresponding load balancing ruleset.

### Ruleset Naming Convention

Load balancing rulesets must follow the format: `Bilanciamento<Identifier>SiteA<a>SiteB<b>`

Where:
- `<Identifier>` = Capitalized route identifier (e.g., `Azure`, `OnPrem`)
- `<a>` = Percentage of traffic to Site A (0-100)
- `<b>` = Percentage of traffic to Site B (0-100)

**Examples:**
- `BilanciamentoAzureSiteA30SiteB70` → 30% to Site A, 70% to Site B
- `BilanciamentoOnPremSiteA50SiteB50` → 50% to Site A, 50% to Site B
- `BilanciamentoAzureSiteA100SiteB0` → 100% to Site A, 0% to Site B

### How It Works

1. **Route Discovery**: The UI automatically discovers all routes matching `route-to-*` pattern from the selected Front Door endpoint
2. **Percentage Selection**: Operator chooses a traffic distribution percentage from 11 predefined options (0/100, 10/90, 20/80, ..., 100/0)
3. **Ruleset Validation**: The UI checks if required rulesets exist for each route identifier and blocks deployment if any are missing
4. **Ruleset Replacement**: The template locates existing `Bilanciamento*` rulesets associated with each route and replaces them with the new percentage-based ruleset **in the same position**
5. **Property Preservation**: All other route properties (origin groups, custom domains, patterns, protocols, cache configuration, etc.) and non-Bilanciamento rulesets remain unchanged

## Deployment Workflow

### Prerequisites

Before using this template, ensure:
- Load balancing rulesets are created in Azure Front Door with the correct naming format
- Routes are named following the `route-to-<identifier>` pattern
- Each route identifier has a corresponding set of percentage-based rulesets (e.g., BilanciamentoAzureSiteA0SiteB100, BilanciamentoAzureSiteA10SiteB90, etc.)

### Using the Azure Portal UI

1. **Basics Step**
   - Select subscription and resource group
   - Choose the Azure Front Door profile
   - Select the endpoint
   - View summary: Number of `route-to-*` routes and available Bilanciamento rulesets

2. **Load Balancing Step**
   - Select percentage distribution from dropdown (e.g., "SiteA30SiteB70")
   - View current selection summary showing:
     - Which routes will be updated (e.g., `route-to-azure`, `route-to-onprem`)
     - Which rulesets will be applied to each route
   - **Validation**: If required rulesets don't exist, an error message appears and deployment is blocked

3. **Deploy**
   - Review configuration
   - Click "Create" to apply changes

### Using Template Spec

Deploy the template as a Template Spec for reusable configurations:

```powershell
# PowerShell
.\install-template.ps1
```

```bash
# Bash
./install-template.sh
```

The scripts will create/update Template Spec: `ts-afd-itn-001` version `2.0.0`

## Technical Details

### UI Features

**Smart Validation:**
- Case-insensitive ruleset matching
- Pre-deployment checks for required rulesets
- Automatic filtering of routes by naming pattern

**Visual Feedback:**
- Route count statistics
- Real-time mapping display (route → ruleset)
- Error messages for missing rulesets

### Template Logic

**Route Filtering:**
```
Filters routes to only those starting with "route-to-"
Uses ARM template filter() and lambda functions
```

**Identifier Mapping:**
- Explicit mapping for known identifiers: `route-to-azure` → `Azure`, `route-to-onprem` → `OnPrem`
- Fallback: Capitalizes the identifier substring for other routes

**Ruleset Replacement:**
- Uses nested map() functions to iterate through existing rulesets
- Replaces only rulesets matching the `Bilanciamento*` pattern
- Preserves order and position of rulesets in the array
- Case-insensitive comparison using toLower()
- All other rulesets remain untouched

**Property Preservation:**
All route properties are captured during UI interaction and passed unchanged to the deployment:
- originGroup
- customDomains
- patternsToMatch
- supportedProtocols
- httpsRedirect
- forwardingProtocol
- enabledState
- linkToDefaultDomain
- cacheConfiguration
- ruleSets (updated with new Bilanciamento ruleset)

## Examples

### Example 1: Single Route Update

**Scenario**: Update `route-to-azure` to send 70% traffic to Site B

**Steps:**
1. Select Front Door endpoint with `route-to-azure`
2. Choose "SiteA30SiteB70" from dropdown
3. UI displays: `route-to-azure → BilanciamentoAzureSiteA30SiteB70`
4. Deploy

**Result**: Route's Bilanciamento ruleset is replaced with `BilanciamentoAzureSiteA30SiteB70`, all other properties unchanged

### Example 2: Multiple Routes Update

**Scenario**: Update both `route-to-azure` and `route-to-onprem` to 50/50 split

**Steps:**
1. Select Front Door endpoint
2. Choose "SiteA50SiteB50"
3. UI displays:
   - `route-to-azure → BilanciamentoAzureSiteA50SiteB50`
   - `route-to-onprem → BilanciamentoOnPremSiteA50SiteB50`
4. Deploy

**Result**: Both routes updated with their respective 50/50 rulesets

### Example 3: Validation Block

**Scenario**: Attempting to use a percentage without required rulesets

**Steps:**
1. Select "SiteA60SiteB40"
2. UI checks for `BilanciamentoAzureSiteA60SiteB40` and `BilanciamentoOnPremSiteA60SiteB40`
3. If either doesn't exist, error message appears: "⚠️ Required rulesets missing..."
4. Deployment is blocked

**Result**: User must create missing rulesets before proceeding

## Troubleshooting

**Issue**: "Required rulesets missing" error
- **Cause**: One or more `Bilanciamento<Identifier>SiteA<a>SiteB<b>` rulesets don't exist
- **Solution**: Create the missing rulesets in Azure Front Door with exact naming format

**Issue**: Route not appearing in UI
- **Cause**: Route name doesn't match `route-to-*` pattern
- **Solution**: Rename route to follow `route-to-<identifier>` format

## Known issues / work-arounds

| # | Issue | Status / Work-around |
|---|-------|---------------------|
| 1 | After a Rule Set association change the *Route* blade in Front Door Manager may still show the **old** Rule Set. | Press **F5** in the browser (the page reload) – the *Refresh* button inside the blade is not sufficient. You can also check the associations in the other *Rule Sets* blade, since it reflects the change immediately without forcing a browser refresh |
| 2 | ARM templates have a size limit of 4 MiB (https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/best-practices#template-limits). For FrontDoor profiles with complex configurations using many routes with additional configurations (ie. caching), the limit can be potentially reached | Repeat the operation in batches of fewer routes each |
