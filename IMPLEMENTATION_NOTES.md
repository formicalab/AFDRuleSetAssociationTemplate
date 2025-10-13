# Technical Implementation Guide - Azure Front Door Bilanciamento Ruleset Management

## Architecture Overview

This solution implements selective ruleset association management for Azure Front Door (Standard/Premium) routes. It enables targeted replacement of rulesets with names prefixed by "Bilanciamento" while preserving all other ruleset associations and maintaining positional ordering within the route configuration.

### Design Principles

1. **Selective Modification**: Only rulesets matching the "Bilanciamento" prefix are affected
2. **Position Preservation**: Replacement occurs in-place, maintaining array order
3. **Independent Processing**: Each route's ruleset array is processed independently
4. **Idempotent Operations**: Multiple executions with the same parameters produce the same result

## UI Definition Architecture (uiFormDefinition.json)

The UI workflow is organized into three steps:
1. **Basics** - Resource selection and data collection
2. **Associations** - Ruleset and route selection
3. **Review Changes** - Pre-deployment preview and validation

### Data Collection Pipeline

#### 1. RuleSet Enumeration
```json
"afdRuleSets": {
  "type": "Microsoft.Solutions.ArmApiControl",
  "request": {
    "method": "GET",
    "path": "[concat(steps('basics').afdProfile.id, '/ruleSets?api-version=2025-04-15')]",
    "transforms": {
      "list": "value|[*].{label:name, value:id}",
      "listWithRemove": "[value|[*].{label:name, value:id}, [{label: '---', value: '---'}]][]"
    }
  }
}
```

**Implementation Details:**
- Queries Azure ARM API for all rulesets in the selected Front Door profile
- JMESPath transform `listWithRemove` creates array of `{label, value}` objects plus sentinel `---` option
- The `---` value acts as a removal operation flag in subsequent template logic

#### 2. Route State Capture
```json
"afdRoutes": {
  "transforms": {
    "currentRuleSets": "[value|[*].properties.ruleSets][]",
    "routeIds": "[value|[*].id][]"
  }
}
```

**Critical Transform: `currentRuleSets`**
- Extracts the complete `properties.ruleSets` array from each route
- Returns array of arrays: `[[route1_rulesets], [route2_rulesets], ...]`
- Preserves original ordering and structure of ruleset associations
- Output parameter `route_currentRuleSets` transmits this state to ARM template

#### 3. Bilanciamento-Specific Filtering
```json
"allowedValues": "[filter(
  steps('basics').afdRuleSets.transformed.listWithRemove, 
  (item) => or(
    equals(item.value, '---'), 
    startsWith(toLower(item.label), 'bilanciamento')
  )
)]"
```

**Filter Logic:**
- `toLower()` normalizes casing for case-insensitive comparison
- `startsWith()` performs prefix matching on normalized label
- `or()` short-circuits to include the sentinel `---` option
- Result: Dropdown displays only Bilanciamento rulesets + removal option

### UI Enhancement Features

#### 1. Route Statistics Counter (Basics Step)
```json
{
  "name": "loadBalancingStatistics",
  "type": "Microsoft.Common.TextBlock",
  "options": {
    "text": "[concat('📊 <b>Route Statistics:</b> ', 
      string(length(filter(steps('basics').afdRoutes.transformed.routeList, 
        (r) => greater(length(filter(r.ruleSetIds, 
          (rs) => startsWith(toLower(last(split(rs.id, '/'))), 'bilanciamento'))), 0)))), 
      ' of ', string(length(steps('basics').afdRoutes.value)), 
      ' routes have load balancing configured')]"
  }
}
```

**Implementation:**
- Nested `filter()` operations to identify routes with Bilanciamento rulesets
- Inner filter: checks each ruleset ID for "bilanciamento" prefix (case-insensitive)
- Outer filter: includes routes where inner filter length > 0
- Displays ratio: "X of Y routes have load balancing configured"

**Benefits**: Provides immediate overview of current state before making changes

#### 2. Empty Endpoint Validation
```json
{
  "name": "noRoutesWarning",
  "type": "Microsoft.Common.InfoBox",
  "visible": "[equals(length(coalesce(steps('basics').afdRoutes.value, [])), 0)]",
  "options": {
    "style": "Warning",
    "text": "⚠️ The selected endpoint has <b>no routes</b>..."
  }
}
```

**Implementation:**
- `coalesce()` handles undefined/null API responses safely
- `equals(length(), 0)` detects empty routes array
- Warning-styled InfoBox for high visibility

**Benefits**: Early validation prevents confusion when endpoint has no routes

#### 3. Endpoint Hostname Descriptions
```json
"allowedValues": "[map(steps('basics').afdEndpoints.value, 
  (item) => parse(concat('{\"label\":\"', item.name, 
    '\",\"value\":\"', item.id, 
    '\",\"description\":\"', item.properties.hostName, '\"}'))))]"
```

**Implementation:**
- Adds `description` field to dropdown options
- Extracts `hostName` from endpoint properties
- Displays hostname under endpoint name for context

**Benefits**: Helps distinguish endpoints with similar names

#### 4. No Load Balancing Rulesets Warning (Associations Step)
```json
{
  "name": "noLoadBalancingRulesetsInfo",
  "type": "Microsoft.Common.InfoBox",
  "visible": "[equals(length(filter(..., (item) => startsWith(toLower(item.label), 'bilanciamento'))), 0)]",
  "options": {
    "text": "ℹ️ No load balancing rulesets found..."
  }
}
```

**Implementation:**
- Filters rulesets list for Bilanciamento prefix
- Shows only when filter result is empty
- Explains that only removal (`---`) is possible

**Benefits**: Sets expectations in edge case scenarios

#### 5. Route Description Enhancement
```json
"description": "[if(empty(item.ruleSetIds), 'No rulesets', 
  if(greater(length(filter(item.ruleSetIds, 
    (rs) => startsWith(toLower(last(split(rs.id, '/'))), 'bilanciamento'))), 0), 
    concat(string(length(item.ruleSetIds)), ' rulesets (has load balancing)'), 
    if(equals(length(item.ruleSetIds), 1), '1 ruleset', 
      concat(string(length(item.ruleSetIds)), ' rulesets'))))]"
```

**Implementation:**
- Three-level conditional logic
- Checks for Bilanciamento presence using filter pattern
- Adds "(has load balancing)" suffix when detected
- Falls back to simple count when no load balancing

**Benefits**: Users immediately see which routes have load balancing configured

#### 6. Selection Confirmation Feedback
```json
{
  "name": "currentSelectionSummary",
  "type": "Microsoft.Common.TextBlock",
  "visible": "[not(empty(steps('associations').ddRuleset))]",
  "options": {
    "text": "[concat('✓ <b>Selected:</b> ', 
      if(equals(steps('associations').ddRuleset, '---'), 
        'Remove all load balancing rulesets', 
        concat('Replace with <b>', last(split(steps('associations').ddRuleset, '/')), '</b>')))]"
  }
}
```

**Implementation:**
- Conditional visibility based on dropdown selection
- `not(empty())` ensures display only after selection
- Reuses operation logic from review step

**Benefits**: Immediate visual confirmation reduces selection errors

### Review Step (Pre-Deployment Preview)

The third step provides a comprehensive preview before deployment execution:

#### 1. Operation Summary with Visual Icons
```json
{
  "name": "operationSummary",
  "type": "Microsoft.Common.TextBlock",
  "options": {
    "text": "[if(equals(steps('associations').ddRuleset, '---'), 
      '🗑️ <b>Operation: REMOVE</b> all load balancing rulesets', 
      concat('🔄 <b>Operation: REPLACE</b> load balancing rulesets with <b>', 
        last(split(steps('associations').ddRuleset, '/')), '</b>'))]"
  }
}
```

**Implementation:**
- Unicode emojis (🗑️/🔄) for visual distinction
- Evaluates selected ruleset ID to determine operation type
- Uses `last(split())` to extract ruleset name from Azure resource ID
- Displays human-readable operation description

**Benefits**: Visual icons improve scannability and quick comprehension

#### 2. Impact Summary with Route Count
```json
{
  "name": "impactSummary",
  "type": "Microsoft.Common.InfoBox",
  "visible": "[greater(length(steps('associations').selectedRoutes), 0)]",
  "options": {
    "style": "Warning",
    "text": "[concat('<b>Impact:</b><ul><li><b>Preserved:</b> All non-load balancing rulesets will remain in their current positions</li><li><b>Modified:</b> Load balancing rulesets will be ', if(equals(steps('associations').ddRuleset, '---'), 'removed', 'replaced in their current positions'), '</li><li><b>Routes affected:</b> ', string(length(steps('associations').selectedRoutes)), '. The list will be provided in the final page of this wizard</li></ul>')]"
  }
}
```

**Implementation:**
- Warning-styled InfoBox highlights critical impact information
- Conditional visibility ensures display only when routes are selected
- Lists preserved vs. modified ruleset categories
- Shows affected route count with hint about final confirmation page
- Dynamic text based on operation type (remove vs. replace)

**Benefits:**
- **Validation**: Operator confirms intended changes before deployment
- **Safety**: Visual preview reduces configuration errors
- **Transparency**: Clear communication of operation scope and impact
- **Guidance**: Sets expectation that full route list appears on final Azure Portal confirmation page

## ARM Template Architecture (template.json)

### Input Parameters

```json
"route_currentRuleSets": {
  "type": "array",
  "metadata": {
    "description": "Array of arrays - each inner array contains current ruleset associations for one route"
  }
}
```

**Structure**: `[[{id: "/...ruleset1"}, {id: "/...ruleset2"}], [{id: "/...ruleset3"}], ...]`
- Outer array indexed by route position
- Inner arrays preserve original ruleset association order per route

### Position-Preserving Replacement Algorithm

#### Variable: `processedRuleSets`

```json
"processedRuleSets": "[map(
  parameters('selected_routes'), 
  lambda('routeId', 
    if(equals(parameters('selected_ruleset_id'), '---'),
      // Branch A: Removal operation
      filter(
        parameters('route_currentRuleSets')[indexOf(parameters('all_route_ids'), lambdaVariables('routeId'))],
        lambda('rs', not(startsWith(last(split(lambdaVariables('rs').id, '/')), 'Bilanciamento')))
      ),
      // Branch B: Replacement/Addition operation
      if(greater(length(filter(...)), 0),
        // Sub-branch B1: Replace in position
        map(..., lambda('rs', if(startsWith(...), createObject(...), lambdaVariables('rs')))),
        // Sub-branch B2: Append at end
        concat(..., array(createObject('id', parameters('selected_ruleset_id'))))
      )
    )
  )
)]"
```

#### Algorithm Breakdown

**Step 1: Route Iteration**
```
map(parameters('selected_routes'), lambda('routeId', ...))
```
- Outer `map()` iterates over selected route IDs
- Lambda parameter `routeId` represents current route being processed
- Returns array of processed ruleset arrays, one per route

**Step 2: Route Context Resolution**
```
indexOf(parameters('all_route_ids'), lambdaVariables('routeId'))
```
- Locates current route's position in the complete route list
- This index maps to corresponding position in `route_currentRuleSets`
- Enables retrieval of route-specific current rulesets

**Step 3: Ruleset Name Extraction**
```
last(split(lambdaVariables('rs').id, '/'))
```
- ARM resource IDs follow pattern: `/subscriptions/.../profiles/.../ruleSets/{name}`
- `split()` on `/` tokenizes the ID
- `last()` extracts final segment containing ruleset name
- Result: Name string for prefix matching

**Step 4: Conditional Processing Tree**

```
Branch A (selected_ruleset_id == '---'):
  └─ filter(currentRuleSets, lambda('rs', not(startsWith(name, 'Bilanciamento'))))
     → Removes all Bilanciamento rulesets, preserves others

Branch B (selected_ruleset_id != '---'):
  ├─ Sub-branch B1 (Bilanciamento exists in current rulesets):
  │  └─ map(currentRuleSets, lambda('rs', 
  │       if(startsWith(name, 'Bilanciamento'), 
  │         createObject('id', selected_ruleset_id),  ← Replace with new
  │         lambdaVariables('rs')                     ← Keep unchanged
  │       )))
  │     → In-place replacement preserves position
  │
  └─ Sub-branch B2 (No Bilanciamento in current rulesets):
     └─ concat(currentRuleSets, array(createObject('id', selected_ruleset_id)))
        → Appends new ruleset at end
```

#### Position Preservation Mechanism

**Key Insight**: `map()` function maintains array ordering

When Sub-branch B1 executes:
```
Input:  [{id: "RuleA"}, {id: "BilanciamentoOld"}, {id: "RuleC"}]
                           ↓
map() iterates maintaining indices:
  Index 0: RuleA        → not Bilanciamento → keep as-is
  Index 1: BilanciamentoOld → is Bilanciamento → replace with createObject('id', 'BilanciamentoNew')
  Index 2: RuleC        → not Bilanciamento → keep as-is
                           ↓
Output: [{id: "RuleA"}, {id: "BilanciamentoNew"}, {id: "RuleC"}]
```

Position 1 (index 1) maintains the Bilanciamento ruleset, content replaced.

### Resource Deployment

```json
"resources": [{
  "type": "Microsoft.Cdn/profiles/afdendpoints/routes",
  "copy": {
    "name": "routeAssociationLoop",
    "count": "[length(parameters('selected_routes'))]"
  },
  "properties": {
    "ruleSets": "[variables('processedRuleSets')[copyIndex()]]"
  }
}]
```

**Copy Loop Mechanics:**
- `copyIndex()` provides 0-based iteration index
- Index corresponds to position in `processedRuleSets` array
- Each route receives its independently processed ruleset array
- ARM PUT operation replaces entire route configuration

## Algorithm Execution Examples

### Example 1: In-Place Replacement (Sub-branch B1)

**Initial State:**
```
Route: /subscriptions/.../routes/default-route
Current RuleSets: [
  {id: "/...ruleSets/SecurityRules"},
  {id: "/...ruleSets/BilanciamentoRM50TO50"},
  {id: "/...ruleSets/CachingRules"}
]
```

**Operation:** Select `BilanciamentoRM0TO100`

**Processing:**
1. `indexOf()` finds route position in `all_route_ids`
2. Retrieves corresponding ruleset array from `route_currentRuleSets`
3. `filter()` detects Bilanciamento exists (length > 0) → Sub-branch B1
4. `map()` iterates:
   - Index 0: "SecurityRules" → no match → preserve
   - Index 1: "BilanciamentoRM50TO50" → match → replace with `createObject('id', '/...BilanciamentoRM0TO100')`
   - Index 2: "CachingRules" → no match → preserve

**Result:**
```
RuleSets: [
  {id: "/...ruleSets/SecurityRules"},
  {id: "/...ruleSets/BilanciamentoRM0TO100"},  ← Position 1 maintained
  {id: "/...ruleSets/CachingRules"}
]
```

### Example 2: Removal Operation (Branch A)

**Initial State:**
```
Current RuleSets: [
  {id: "/...ruleSets/BilanciamentoRM50TO50"},
  {id: "/...ruleSets/BilanciamentoRM0TO100"},
  {id: "/...ruleSets/ApiRules"}
]
```

**Operation:** Select `---`

**Processing:**
1. Sentinel value `---` triggers Branch A
2. `filter()` with `not(startsWith(..., 'Bilanciamento'))`:
   - Index 0: "BilanciamentoRM50TO50" → match → exclude
   - Index 1: "BilanciamentoRM0TO100" → match → exclude
   - Index 2: "ApiRules" → no match → include

**Result:**
```
RuleSets: [
  {id: "/...ruleSets/ApiRules"}
]
```

### Example 3: Append Operation (Sub-branch B2)

**Initial State:**
```
Current RuleSets: [
  {id: "/...ruleSets/CdnRules"},
  {id: "/...ruleSets/CompressionRules"}
]
```

**Operation:** Select `BilanciamentoRM50TO50`

**Processing:**
1. `filter()` detects no Bilanciamento (length == 0) → Sub-branch B2
2. `concat(currentRuleSets, array(createObject(...)))`:
   - Preserves existing array: `[CdnRules, CompressionRules]`
   - Appends: `[{id: '/...BilanciamentoRM50TO50'}]`

**Result:**
```
RuleSets: [
  {id: "/...ruleSets/CdnRules"},
  {id: "/...ruleSets/CompressionRules"},
  {id: "/...ruleSets/BilanciamentoRM50TO50"}  ← Appended at end
]
```

### Example 4: Multi-Route Processing

**Initial State:**
```
selected_routes: [routeA_id, routeB_id]
all_route_ids: [routeA_id, routeB_id, routeC_id]
route_currentRuleSets: [
  [{id: "Rule1"}, {id: "BilanciamentoOld"}, {id: "Rule3"}],     ← Route A
  [{id: "Rule1"}, {id: "Rule2"}, {id: "BilanciamentoOld"}],     ← Route B
  [{id: "OtherRule"}]                                             ← Route C (not selected)
]
```

**Operation:** Select `BilanciamentoNew` for routes A and B

**Processing:**
```
Iteration 1 (routeId = routeA_id):
  indexOf(all_route_ids, routeA_id) = 0
  route_currentRuleSets[0] → [{Rule1}, {BilanciamentoOld}, {Rule3}]
  map() → [{Rule1}, {BilanciamentoNew}, {Rule3}]

Iteration 2 (routeId = routeB_id):
  indexOf(all_route_ids, routeB_id) = 1
  route_currentRuleSets[1] → [{Rule1}, {Rule2}, {BilanciamentoOld}]
  map() → [{Rule1}, {Rule2}, {BilanciamentoNew}]
```

**Result:**
```
processedRuleSets: [
  [{id: "Rule1"}, {id: "BilanciamentoNew"}, {id: "Rule3"}],      ← Position 1 preserved
  [{id: "Rule1"}, {id: "Rule2"}, {id: "BilanciamentoNew"}]       ← Position 2 preserved
]
```

Each route independently processes its rulesets, preserving position context.

## Function Reference

### UI Definition Expression Language

**Official Documentation:** [CreateUiDefinition Functions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-functions)

Key functions used in this implementation:
- Collection functions: `filter()`, `map()`
- String functions: `startsWith()`, `toLower()`, `concat()`
- Logical functions: `or()`, `equals()`
- Conversion functions: `parse()`

**Lambda Syntax:** Arrow function notation `(param) => expression`

### ARM Template Expression Language

**Official Documentation:** [ARM Template Functions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/template-functions)

**Lambda Functions:** [ARM Template Lambda Functions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/template-functions-lambda)

Key function categories used in this implementation:
- **Lambda functions**: `map()`, `filter()`, `lambda()`, `lambdaVariables()`
- **Logical functions**: `if()`, `equals()`, `greater()`, `not()`
- **Array functions**: `indexOf()`, `last()`, `length()`, `concat()`, `array()`
- **String functions**: `startsWith()`, `split()`
- **Object functions**: `createObject()`

**Lambda Syntax:** Explicit declaration with `lambda('var', lambdaVariables('var').property)`

### Critical Implementation Notes

1. **Case Sensitivity in startsWith()**
   - UI Definition: Requires explicit `toLower()` for case-insensitive matching
   - ARM Template: Native case-insensitivity in `startsWith()`

2. **Lambda Variable Access**
   - UI Definition: Direct reference `(item) => item.property`
   - ARM Template: Must use `lambdaVariables('item').property`

3. **Array Mutation**
   - All functions are pure - no in-place modification
   - `map()` returns new array maintaining positional correspondence
   - `filter()` returns new array with subset of elements

4. **Conditional Evaluation**
   - `if()` evaluates both branches before selection
   - Nested `if()` creates decision tree evaluated depth-first

5. **Null Safety with coalesce()**
   - UI Definition: Use `coalesce(value, [])` to handle undefined/null API responses
   - Prevents runtime errors when API controls haven't loaded yet
   - Example: `coalesce(steps('basics').afdRoutes.value, [])`

6. **Nested Filter Pattern for Detection**
   - Used extensively for Bilanciamento detection: `filter(rulesets, (rs) => startsWith(...))`
   - Can be nested: `filter(routes, (r) => greater(length(filter(r.rulesets, ...)), 0))`
   - Returns matching items; use `length() > 0` to check for existence

## Test Coverage Matrix

| Test Case | Initial State | Operation | Expected Result | Validates |
|-----------|---------------|-----------|-----------------|-----------|
| **T1** | `[]` | Add Bilanciamento | `[Bilanciamento]` | Empty array handling |
| **T2** | `[A, B, C]` | Add Bilanciamento | `[A, B, C, Bilanciamento]` | Sub-branch B2: Append |
| **T3** | `[A, Bilanciamento, C]` | Replace | `[A, BilanciamentoNew, C]` | Sub-branch B1: Position 1 preservation |
| **T4** | `[Bilanciamento, B, C]` | Replace | `[BilanciamentoNew, B, C]` | Sub-branch B1: Position 0 preservation |
| **T5** | `[A, B, Bilanciamento]` | Replace | `[A, B, BilanciamentoNew]` | Sub-branch B1: Position 2 preservation |
| **T6** | `[Bil1, Bil2, A]` | Replace | `[BilNew, BilNew, A]` | Multiple Bilanciamento replacement |
| **T7** | `[A, Bilanciamento, C]` | Remove (---) | `[A, C]` | Branch A: Removal |
| **T8** | `[Bil1, Bil2, Bil3]` | Remove (---) | `[]` | Branch A: Complete removal |
| **T9** | Route A: `[A, Bil, C]`<br>Route B: `[X, Y, Z, Bil]` | Replace both | Route A: `[A, BilNew, C]`<br>Route B: `[X, Y, Z, BilNew]` | Independent route processing |
| **T10** | `[A, bilanciamento, C]` | Replace | `[A, BilanciamentoNew, C]` | Case-insensitive matching |

## Operational Constraints

### Technical Limitations

1. **Resource ID Parsing**
   - Assumes resource IDs follow Azure standard format: `/subscriptions/.../ruleSets/{name}`
   - Non-standard ID formats may cause name extraction failure

2. **Prefix Matching Scope**
   - Any ruleset with name starting "Bilanciamento" (case-insensitive) is affected
   - No regex or wildcard support - strict prefix only

3. **Multiple Bilanciamento Instances**
   - When route contains multiple Bilanciamento rulesets, ALL are replaced
   - Replacement occurs at position of FIRST match
   - Subsequent matches are also replaced, not removed

4. **ARM Template Size**
   - Variables section contains inline lambda expressions
   - Large route counts may approach 4MB ARM template limit
   - Consider batching for deployments >100 routes

### Deployment Constraints

1. **Idempotency**
   - Executing twice with same parameters produces identical result
   - No drift detection - always applies specified configuration

2. **Atomicity**
   - Copy loop deploys routes sequentially, not atomically
   - Partial failure leaves subset of routes updated

3. **Rollback**
   - No built-in rollback mechanism
   - Revert requires capturing previous state and re-deploying

## Performance Characteristics

### Time Complexity

- **UI Filtering**: O(n) where n = number of rulesets in profile
- **Route Processing**: O(r × s) where r = selected routes, s = avg rulesets per route
- **ARM Deployment**: O(r) sequential route updates

### Space Complexity

- **processedRuleSets Variable**: O(r × s) ruleset objects in memory
- **Template Size**: ~2KB base + ~500 bytes per route

## UI/UX Design Considerations

### Three-Step Workflow Structure

**Step 1: Basics**
- Endpoint descriptions display hostnames for context
- Empty endpoint warnings prevent invalid selections
- Route statistics show overview: "X of Y routes have load balancing configured"

**Step 2: Associations**
- No Bilanciamento rulesets warning handles edge cases
- Route descriptions indicate load balancing status
- Selection confirmation displays current choice

**Step 3: Review Changes**
- Operation icons (🗑️/🔄) provide visual identification
- Impact summary warns about changes
- Route count references final confirmation page

### Review Step Information Hierarchy

The review step uses a three-tier structure:

1. **Informational Context** (Blue InfoBox)
   - Purpose: Orient the user to the review phase
   - Content: General guidance about reviewing changes

2. **Operation Details with Visual Icons** (TextBlock)
   - Purpose: Communicate specific operation type at a glance
   - Content: Operation icon (🗑️ remove / 🔄 replace) + selected ruleset name
   - Format: Bold labels with Unicode emojis for visual distinction
   - Hint: Reference to final page for complete route list

3. **Impact Warning** (Yellow InfoBox)
   - Purpose: Highlight critical impact information requiring attention
   - Content: Preservation guarantees, modification scope, affected route count
   - Style: Warning-level visual emphasis
   - Route list hint: Explains full list appears on final Azure Portal confirmation page

4. **Post-Deployment Guidance** (Blue InfoBox)
   - Purpose: Set expectations for validation
   - Content: Instructions for verifying changes in Azure Portal

**Design Characteristics:**
- Visual hierarchy: InfoBox styling (Info/Warning), TextBlock formatting, Unicode icons (🗑️/🔄/📊/⚠️/ℹ️)
- Conditional visibility: Elements appear only when applicable (e.g., warnings for empty endpoints)
- Contextual feedback: Confirmation messages after selections, statistics before changes

### Expression Language Limitations

**Challenge**: Displaying comma-separated route names  
**Constraint**: UI Definition expression language lacks `join()` function  
**Attempted Solution**: Manual concatenation for 1-4 routes, "... and X more" pattern  
**Issue**: Expression complexity and TextBlock HTML rendering limitations  
**Resolution**: Display route count only; users reference Associations step for names

**Technical Detail**: `map()` returns array; `concat()` cannot flatten to string in UI context

## Extension Points

### Configurable Prefix Pattern

Current implementation hardcodes "Bilanciamento" prefix. To generalize:

1. Add parameter `rulesetPrefix` (string)
2. Replace `startsWith(..., 'Bilanciamento')` with `startsWith(..., parameters('rulesetPrefix'))`
3. Update UI filter to use parameter

### Multi-Ruleset Operations

To support different rulesets per route:

1. Change `selected_ruleset_id` from string to object: `{routeId: rulesetId, ...}`
2. Modify lambda to lookup `lambdaVariables('routeId')` in selection object
3. Requires significant UI redesign for route-specific selection

### Enhanced Route List Display

Current review step shows route count. To display individual route names:

**Option 1**: Static list for small counts (≤3 routes)
- Manually build comma-separated string with nested `concat()` and `if()` expressions
- Limitation: Expression length grows exponentially; impractical for >5 routes

**Option 2**: Summary with truncation
- Display first 2 route names + "... and X more" pattern
- Implemented using `if(equals(length, 1), ..., if(equals(length, 2), ..., ...))`
- Trade-off: Complexity vs. user value

**Option 3**: Separate step/table view
- Add dedicated sub-step with grid/table displaying all selected routes
- Requires CreateUiDefinition schema support for table elements
- Most scalable but increases navigation complexity

**Current Implementation**: Route count only (simplicity, reliability, scalability)
