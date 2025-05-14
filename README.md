# Front Door RuleSet Association Template

This project contains:

* **template.json** – an ARM template that associates a single Azure Front Door (Std/Premium) Rule Set with one or more existing routes on an endpoint.  
  Only the association changes; all other route properties (origin group, custom domains, patterns, protocols, cache settings, …) are preserved.

* **uiFormDefinition.json** – the “Create UI” definition that drives the portal experience.  
  It lets the operator pick the Front Door profile, endpoint, a ruleset (or `---` for *no* ruleset) and the routes to update.  
  When **Deploy** is pressed, the UI serialises the selection into parameters and calls **template.json**.

Workflow
1. Choose subscription / resource group.  
2. Select the Front Door profile and endpoint.  
3. Pick the Rule Set to associate (or `---` to remove any association).  
4. Multi-select the routes that should receive that Rule Set.  
5. Press **Review + create** → **Create**. The deployment runs in the background and updates every selected route.

## Known issues / work-arounds

| # | Issue | Work-around |
|---|-------|-------------|
| 1 | When only **one** route is selected, sometimes the portal serialises the value as a *string* instead of a single-item array. The ARM template then fails validation. | Select a second route, then immediately de-select it and try **Create** again – the portal now emits a proper single-item array. |
| 2 | After a Rule Set association change the *Route* blade in Front Door Manager may still show the **old** Rule Set. | Press **F5** in the browser (the page reload) – the *Refresh* button inside the blade is not sufficient. You can also check the associations in the other *Rule Sets* blade, since it reflects the change immediately without forcing a browser refresh |
