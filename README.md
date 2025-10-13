# Front Door RuleSet Association Template

This project contains:

* **template.json** – an ARM template that manages the RuleSets used for load balancing (recognized from their names starting with "Bilanciamento*") in Azure Front Door (Std/Premium), allowing theirassociations with one or more existing routes on an endpoint.  
  Only the load balancing ruleset associations are modified; all other route properties (origin group, custom domains, patterns, protocols, cache settings, …) and other rulesets are preserved.

* **uiFormDefinition.json** – the "Create UI" definition that drives the portal experience.  
  It lets the operator pick the Front Door profile, endpoint, a Bilanciamento ruleset (or `---` to remove all load balancing rulesets) and the routes to update.  
  When **Deploy** is pressed, the UI serialises the selection into parameters and calls **template.json**.

## ℹ️ Selective Bilanciamento RuleSet Management

**This template manages ONLY load balancing ("Bilanciamento*") rulesets while preserving all other ruleset associations.**

### How it works:

- **Select a "Bilanciamento" ruleset**: 
  - All existing rulesets starting with "Bilanciamento" will be **replaced** with the selected ruleset
  - The new ruleset is placed at the **same position** as the original Bilanciamento ruleset
  - If no Bilanciamento ruleset exists, the new one is **added at the end**
  - All other rulesets are **preserved** in their original positions

- **Select `---`**: 
  - All existing rulesets starting with "Bilanciamento" will be **removed**
  - All other rulesets are **preserved** in their original positions

### Examples:

**Example 1**: Route has ["SecurityRules", "Bilanciamento-v1", "CachingRules"]
- Select "Bilanciamento-v2" → Result: ["SecurityRules", "Bilanciamento-v2", "CachingRules"] ← **Position preserved**
- Select "---" → Result: ["SecurityRules", "CachingRules"]

**Example 2**: Route has ["CdnRules", "CompressionRules"] (no Bilanciamento)
- Select "Bilanciamento-new" → Result: ["CdnRules", "CompressionRules", "Bilanciamento-new"] ← **Added at end**
- Select "---" → Result: ["CdnRules", "CompressionRules"] (no change)

**Example 3**: Multiple routes with different positions
- Route A: ["Rule1", "Bilanciamento-old", "Rule3"] → Result: ["Rule1", "Bilanciamento-new", "Rule3"]
- Route B: ["Rule1", "Rule2", "Rule3", "Bilanciamento-old"] → Result: ["Rule1", "Rule2", "Rule3", "Bilanciamento-new"]
- **Each route preserves its Bilanciamento position independently**

The UI displays the current number of rulesets associated with each route. Only Bilanciamento rulesets (plus the `---` option) are shown in the selection dropdown.

**Key Features:**
- ✅ Preserves the position of Bilanciamento rulesets when replacing
- ✅ Handles multiple routes with different ruleset orders
- ✅ Safely manages routes with multiple ruleset associations
- ✅ Case-insensitive matching for "Bilanciamento" prefix

## Workflow

### Step 1: Basics
- Choose subscription / resource group
- Select the Front Door profile and endpoint (with hostname shown)
- View statistics: how many routes have load balancing configured
- **Empty endpoint warning**: If the endpoint has no routes, a warning is displayed

### Step 2: Associations
- **No Bilanciamento warning**: If profile has no load balancing rulesets, an info message explains only removal is possible
- Pick the load balancing ruleset to associate (or `---` to remove)
- **Selection confirmation**: Visual confirmation shows what was selected
- Multi-select target routes with descriptions showing:
  - Number of rulesets per route
  - **(has load balancing)** indicator for routes with existing Bilanciamento rulesets

### Step 3: Review Changes
Preview before deployment with:
- **Operation summary** with visual icons (🗑️ remove / 🔄 replace)
- **Impact details**: What will be preserved vs. changed, with route count

### Step 4: Final Confirmation
The final Azure Portal confirmation page displays the complete list of affected route names before deployment execution.

## UI Features

The wizard includes several validation and feedback features:

**Visual Indicators:**
- 📊 Route statistics showing load balancing configuration overview
- 🗑️ / 🔄 Operation type icons for quick identification
- ⚠️ Warning messages for empty endpoints or edge cases
- ℹ️ Informational guidance throughout the workflow

**Context-Aware Descriptions:**
- Endpoint hostnames displayed in dropdown
- Route descriptions show ruleset count and load balancing status
- Selection confirmations after each major choice

**Validation:**
- Empty endpoint detection
- No load balancing rulesets detection
- Clear messaging for edge cases

## Known issues / work-arounds

| # | Issue | Work-around |
|---|-------|-------------|
| 1 | When only **one** route is selected, sometimes the portal serializes the value as a *string* instead of a single-item array. The ARM template then fails validation. | Select a second route, then immediately de-select it and try **Create** again – the portal now emits a proper single-item array. |
| 2 | After a Rule Set association change the *Route* blade in Front Door Manager may still show the **old** Rule Set. | Press **F5** in the browser (the page reload) – the *Refresh* button inside the blade is not sufficient. You can also check the associations in the other *Rule Sets* blade, since it reflects the change immediately without forcing a browser refresh |
| 3 | Arm templates have a size limit of 4 MiB (https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/best-practices#template-limits). For FrontDoor profiles with complex configurations using many routes with additional configurations (ie. caching), the limit can be potentially reached | repeat the operation in batches of fewer routes each |
