# Azure Front Door RuleSet Association Template

This ARM template automates load balancing ruleset configuration for Azure Front Door Premium routes. It supports two different scenarios that can be used independently or together in a single deployment.

## Overview

The template consists of:

- **template.json** – ARM deployment template that updates route ruleset associations
- **uiFormDefinition.json** – Azure Portal UI definition for guided configuration
- **install-template.ps1** / **install-template.sh** – Deployment scripts for Template Spec registration

## Two Deployment Scenarios

### AFD A: N-Routes-1-RuleSet (Apply Single Ruleset to Multiple Routes)

Use this scenario when you want to apply the **same load balancing ruleset** to multiple selected routes.

**Use Case Examples:**
- Apply `BilanciamentoSiteA50SiteB50` to all routes that currently have any Bilanciamento ruleset
- Remove all Bilanciamento rulesets from selected routes (using the `---` option)
- Standardize load balancing across multiple routes

**How It Works:**
1. Select a Front Door profile and endpoint
2. Choose a load balancing ruleset (or `---` to remove)
3. Select which routes to update (only routes with existing Bilanciamento rulesets are shown)
4. The selected ruleset replaces any existing Bilanciamento rulesets on the chosen routes

### AFD B: N-Routes-N-RuleSets (Each Route Gets Its Own Ruleset)

Use this scenario when each route needs its **own specific ruleset** based on a naming convention.

**Use Case Examples:**
- Routes follow `route-to-<identifier>` pattern (e.g., `route-to-azure`, `route-to-onprem`)
- Each route maps to a corresponding ruleset (e.g., `BilanciamentoAzureSiteA50SiteB50`)
- Batch update all routes to a specific percentage distribution

**How It Works:**
1. Select a Front Door profile and endpoint
2. Choose a percentage distribution (e.g., SiteA30SiteB70)
3. Each route automatically maps to its corresponding ruleset based on naming convention
4. All eligible routes are updated in a single deployment

---

## AFD A: Detailed Documentation

### Prerequisites

- Routes must already have at least one Bilanciamento ruleset associated
- Only routes with existing Bilanciamento rulesets can be modified

### Workflow

1. **AFD A - Basics Step**
   - Select the Front Door profile
   - Select the endpoint
   - View summary showing:
     - Number of routes with load balancing rulesets configured
     - Available load balancing rulesets in the profile

2. **AFD A - Associations Step**
   - Choose a load balancing ruleset from the dropdown, OR select `---` to remove
   - Select which routes to apply the ruleset to (multi-select with "Select All" option)
   - View current selection summary

### Behavior

| Selection | Result |
|-----------|--------|
| Ruleset selected | Replaces any existing Bilanciamento ruleset with the selected one |
| `---` selected | Removes all Bilanciamento rulesets from the route |

**Important:** Non-Bilanciamento rulesets are always preserved.

---

## AFD B: Detailed Documentation

### Route Naming Pattern

Only routes matching the format `route-to-<identifier>` are processed.

**Examples:**
- `route-to-azure`
- `route-to-onprem`
- `route-to-webapp`

The `<identifier>` portion is extracted and capitalized to match the corresponding ruleset.

### Ruleset Naming Convention

Load balancing rulesets must follow the format: `Bilanciamento<Identifier>SiteA<a>SiteB<b>`

Where:
- `<Identifier>` = Capitalized route identifier (e.g., `Azure`, `OnPrem`)
- `<a>` = Percentage of traffic to Site A (0-100)
- `<b>` = Percentage of traffic to Site B (0-100)

**Examples:**
- `BilanciamentoAzureSiteA30SiteB70` → 30% to Site A, 70% to Site B
- `BilanciamentoOnPremSiteA50SiteB50` → 50% to Site A, 50% to Site B

### Workflow

1. **AFD B - Basics Step**
   - Select the Front Door profile
   - Select the endpoint
   - View summary showing:
     - Number of `route-to-*` routes (total and with Bilanciamento)
     - Available Bilanciamento rulesets

2. **AFD B - Associations Step**
   - Select percentage distribution from dropdown (e.g., "SiteA30SiteB70")
   - View which routes will be updated and their target rulesets
   - **Validation**: If required rulesets don't exist, deployment is blocked

### Validation

The UI performs pre-deployment validation:
- Checks if required rulesets exist for each route identifier
- Case-insensitive comparison (BilanciamentoAzure = bilanciamentoazure)
- Blocks deployment with clear error message listing missing rulesets

---

## Combined Deployment

You can configure both AFD A and AFD B in a single deployment:
- Configure AFD A to update one Front Door profile
- Configure AFD B to update another Front Door profile
- Both deployments execute together

**Note:** At least one AFD (A or B) must be configured. If neither is configured, deployment is blocked.

---

## Installation

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

---

## Technical Details

### Property Preservation

All route properties are captured and preserved during deployment:
- originGroup
- originPath
- customDomains
- patternsToMatch
- supportedProtocols
- httpsRedirect
- forwardingProtocol
- enabledState
- linkToDefaultDomain
- cacheConfiguration
- ruleSets (only Bilanciamento rulesets are modified)

### Template Logic

**AFD A - Ruleset Replacement:**
- If a Bilanciamento ruleset exists: replaces it with the selected ruleset
- If no Bilanciamento ruleset exists: appends the selected ruleset
- If `---` selected: removes all Bilanciamento rulesets
- Non-Bilanciamento rulesets are always preserved in their original position

**AFD B - Route-to-Ruleset Mapping:**
- Extracts identifier from route name (`route-to-azure` → `azure`)
- Capitalizes first letter (`azure` → `Azure`)
- Constructs ruleset name: `Bilanciamento` + `Azure` + `SiteA50SiteB50`
- Replaces existing Bilanciamento ruleset with the mapped one

---

## Examples

### Example 1: AFD A - Apply Single Ruleset to Multiple Routes

**Scenario**: Apply `BilanciamentoSiteA100SiteB0` to 5 routes to send all traffic to Site A

**Steps:**
1. Select Front Door profile and endpoint
2. Choose `BilanciamentoSiteA100SiteB0` from dropdown
3. Select all 5 routes using "Select All"
4. Deploy

**Result**: All 5 routes now have `BilanciamentoSiteA100SiteB0` as their load balancing ruleset

### Example 2: AFD A - Remove Load Balancing Rulesets

**Scenario**: Remove load balancing from specific routes

**Steps:**
1. Select Front Door profile and endpoint
2. Choose `---` from dropdown
3. Select the routes to remove load balancing from
4. Deploy

**Result**: Selected routes no longer have any Bilanciamento rulesets

### Example 3: AFD B - Update All Routes to 70/30 Split

**Scenario**: Update `route-to-azure` and `route-to-onprem` to 70/30 split

**Steps:**
1. Select Front Door endpoint
2. Choose "SiteA70SiteB30"
3. UI displays:
   - `route-to-azure → BilanciamentoAzureSiteA70SiteB30`
   - `route-to-onprem → BilanciamentoOnPremSiteA70SiteB30`
4. Deploy

**Result**: Both routes updated with their respective 70/30 rulesets

### Example 4: Combined Deployment

**Scenario**: Update two different Front Door profiles in one deployment

**Steps:**
1. Configure AFD A: Select profile/endpoint, choose ruleset, select routes
2. Configure AFD B: Select different profile/endpoint, choose percentage
3. Deploy

**Result**: Both Front Door profiles are updated in a single deployment

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Required rulesets missing" error (AFD B) | Bilanciamento rulesets don't exist for selected percentage | Create missing rulesets with exact naming format |
| Route not appearing in AFD A | Route has no existing Bilanciamento ruleset | Manually add a Bilanciamento ruleset first |
| Route not appearing in AFD B | Route name doesn't match `route-to-*` pattern | Rename route to follow `route-to-<identifier>` format |
| "No AFD Configuration Selected" error | Neither AFD A nor AFD B was configured | Configure at least one AFD profile/endpoint |
| No eligible routes (AFD B) | No routes match both criteria | Ensure routes follow `route-to-*` pattern AND have existing Bilanciamento rulesets |

---

## Known Issues / Work-arounds

| # | Issue | Status / Work-around |
|---|-------|---------------------|
| 1 | After a Rule Set association change the *Route* blade in Front Door Manager may still show the **old** Rule Set. | Press **F5** in the browser (full page reload) – the *Refresh* button inside the blade is not sufficient. You can also check the associations in the *Rule Sets* blade, which reflects changes immediately. |
| 2 | ARM templates have a size limit of 4 MiB. For Front Door profiles with complex configurations using many routes with additional configurations (e.g., caching), the limit can potentially be reached. | Repeat the operation in batches of fewer routes each. |
