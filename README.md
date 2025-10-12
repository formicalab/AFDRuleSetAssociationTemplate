# Front Door RuleSet Association Template

This project contains:

* **template.json** – an ARM template that associates a single Azure Front Door (Std/Premium) Rule Set with one or more existing routes on an endpoint.  
  Only the association changes; all other route properties (origin group, custom domains, patterns, protocols, cache settings, …) are preserved.

* **uiFormDefinition.json** – the "Create UI" definition that drives the portal experience.  
  It lets the operator pick the Front Door profile, endpoint, a ruleset (or `---` for *no* ruleset) and the routes to update.  
  When **Deploy** is pressed, the UI serialises the selection into parameters and calls **template.json**.

## ⚠️ Important: RuleSet Replacement Behavior

**This template REPLACES all existing ruleset associations on the selected routes.**

- If a route currently has **no rulesets**, the selected ruleset will be added.
- If a route currently has **one ruleset**, it will be replaced with the selected ruleset.
- If a route currently has **multiple rulesets** (e.g., RuleSet-A, RuleSet-B, RuleSet-C), **ALL of them will be removed** and replaced with only the selected ruleset.
- If you select `---`, **all ruleset associations will be removed** from the selected routes.

The UI displays the current number and names of rulesets associated with each route to help you understand what will be replaced.

## Workflow
1. Choose subscription / resource group.  
2. Select the Front Door profile and endpoint.  
3. **Review the current ruleset associations** shown for each route in the dropdown.  
4. Pick the Rule Set to associate (or `---` to remove any association).  
5. Multi-select the routes that should receive that Rule Set.  
6. Press **Review + create** → **Create**. The deployment runs in the background and updates every selected route.

## Known issues / work-arounds

| # | Issue | Work-around |
|---|-------|-------------|
| 1 | When only **one** route is selected, sometimes the portal serializes the value as a *string* instead of a single-item array. The ARM template then fails validation. | Select a second route, then immediately de-select it and try **Create** again – the portal now emits a proper single-item array. |
| 2 | After a Rule Set association change the *Route* blade in Front Door Manager may still show the **old** Rule Set. | Press **F5** in the browser (the page reload) – the *Refresh* button inside the blade is not sufficient. You can also check the associations in the other *Rule Sets* blade, since it reflects the change immediately without forcing a browser refresh |
| 3 | Arm templates have a size limit of 4 MiB (https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/best-practices#template-limits). For FrontDoor profiles with complex configurations using many routes with additional configurations (ie. caching), the limit can be potentially reached | Currently being investigated |
| 4 | Routes with multiple rulesets will have **all** rulesets replaced, not just one added/removed. This is a limitation of ARM template PUT operations which require all properties to be specified. | This is the intended behavior. The UI now clearly displays how many rulesets each route currently has and warns about replacement. If you need to preserve specific rulesets, you must manually re-add them after deployment or use Azure CLI/PowerShell for more granular control. |
