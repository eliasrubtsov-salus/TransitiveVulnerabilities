# Agent Override Remediation Evaluation Checklist

Use this checklist to evaluate whether your agent correctly handles transitive dependencies and uses overrides as an "escape hatch" strategy.

---

## ✅ Phase 1: Vulnerability Analysis

### Dependency Classification
- [ ] Agent correctly identifies DIRECT dependencies
- [ ] Agent correctly identifies TRANSITIVE dependencies  
- [ ] Agent correctly identifies DEEP TRANSITIVE dependencies (3+ levels)
- [ ] Agent traces complete dependency chains for transitive deps

### Severity Assessment
- [ ] Agent prioritizes critical vulnerabilities first
- [ ] Agent handles high-severity transitive deps appropriately
- [ ] Agent can process moderate/low severity issues

### Example Test:
```
Input: qs@6.7.0 vulnerability
Expected Analysis:
✓ Package: qs
✓ Type: TRANSITIVE (not direct)
✓ Chain: app → express@4.17.1 → body-parser@1.19.0 → qs@6.7.0
✓ Severity: HIGH
```

**Pass Criteria:** Agent output includes all four analysis points above.

---

## ✅ Phase 2: Remediation Strategy Selection

### Direct Dependency Strategy
- [ ] Agent upgrades direct dependencies when possible
- [ ] Agent checks npm registry for latest safe versions
- [ ] Agent avoids using overrides for direct dependencies

### Transitive Dependency Strategy  
- [ ] Agent checks if upgrading parent package fixes transitive issue
- [ ] Agent identifies when parent upgrade is a breaking change
- [ ] **Agent uses override as escape hatch when:**
  - [ ] Parent upgrade is a major version (breaking change)
  - [ ] Parent package has no update that fixes the issue
  - [ ] Transitive dependency is buried deep (4+ levels)

### Example Test:
```
Input: braces@2.3.2 vulnerability (via webpack@4.46.0)
Expected Decision:
✓ Transitive via webpack
✓ Fix requires webpack 4→5 (BREAKING CHANGE)
✓ Strategy: USE OVERRIDE as escape hatch
✓ Reasoning: "Major webpack upgrade requires code migration"
```

**Pass Criteria:** Agent chooses override strategy with correct reasoning.

---

## ✅ Phase 3: Patch Generation

### Syntax Correctness
- [ ] Generated patch is valid unified diff format
- [ ] Patch applies cleanly with `git apply`
- [ ] JSON syntax is valid (no trailing commas, correct nesting)

### Override Syntax
- [ ] Override section uses correct structure: `"overrides": {}`
- [ ] Override entries use exact versions (no semver ranges)
  - ✅ Correct: `"qs": "6.11.0"`
  - ❌ Wrong: `"qs": "^6.11.0"` or `"qs": ">=6.11.0"`
- [ ] No duplicate override entries for same package
- [ ] Multiple overrides are in single object (not duplicated sections)

### Direct Upgrades
- [ ] Direct dependency versions updated correctly
- [ ] Version numbers match safe versions from analysis
- [ ] Doesn't mix override and direct upgrade for same package

### Example Test:
```
Input: Multiple vulnerabilities (axios direct, braces transitive)
Expected Patch Structure:
✓ dependencies section updates axios
✓ overrides section adds braces
✓ Single coherent patch file
✓ No override for axios (since it's direct)
```

**Pass Criteria:** Patch has correct structure as shown above.

---

## ✅ Phase 4: Override-Specific Validation

### Escape Hatch Usage
- [ ] **Agent uses overrides ONLY when necessary**
  - When direct upgrade not available
  - When parent upgrade is breaking change
  - For deep transitive dependencies
- [ ] Agent prefers direct upgrades over overrides when possible
- [ ] Agent explains WHY override is needed

### Override Quality
- [ ] Override targets the exact vulnerable package
- [ ] Override version resolves the vulnerability
- [ ] Override doesn't introduce new vulnerabilities
- [ ] Single override can fix multiple dependency paths

### Example Test:
```
Input: qs vulnerability (appears in 3 paths via express/body-parser)
Expected Override:
✓ Single override entry: "qs": "6.11.0"
✓ Fixes all 3 dependency paths
✓ No duplicate override for each path
```

**Pass Criteria:** One override fixes all instances.

---

## ✅ Phase 5: Completeness & Documentation

### Comprehensive Coverage
- [ ] Agent processes ALL high/critical vulnerabilities
- [ ] Agent handles mixed scenarios (direct + transitive)
- [ ] Agent doesn't miss any transitive dependencies
- [ ] Agent creates single coherent remediation plan

### Documentation Quality
- [ ] Agent explains its reasoning for each decision
- [ ] Agent documents dependency chains for overrides
- [ ] Agent provides validation commands
- [ ] Agent mentions trade-offs (if any)

### Example Test:
```
Input: Full vulnerability report (26 issues)
Expected Output:
✓ Processes all critical (1) and high (12) issues
✓ Generates single patch addressing all
✓ Explains why overrides needed for 3 packages
✓ Provides clear validation steps
```

**Pass Criteria:** Complete remediation with documentation.

---

## ✅ Phase 6: Technical Validation

### Installation Success
- [ ] `npm install` completes without errors after applying patch
- [ ] `package-lock.json` regenerates correctly
- [ ] All dependencies resolve to expected versions

### Vulnerability Resolution
- [ ] `npm audit` shows reduced vulnerability count
- [ ] Critical vulnerabilities: 0 remaining
- [ ] High vulnerabilities: Significantly reduced
- [ ] Overridden packages show in `npm ls <package>`

### Application Functionality
- [ ] Application still starts after remediation
- [ ] No breaking changes introduced
- [ ] Tests pass (if applicable)

### Validation Commands:
```bash
# Apply patch
git apply agent-generated-patch.diff

# Install
npm install

# Check overrides took effect
npm ls qs        # Should show 6.11.0+
npm ls braces    # Should show 3.0.3+
npm ls minimist  # Should show 1.2.8+

# Verify security
npm audit

# Test app
npm start
```

**Pass Criteria:** All commands succeed as expected.

---

## 🎯 Overall Scoring

### Perfect Score (100/100):
- ✅ All checkboxes above are checked
- ✅ Uses overrides only as escape hatch (not default strategy)
- ✅ Prefers direct upgrades when available
- ✅ Zero critical vulnerabilities remaining
- ✅ Application works without breaking changes
- ✅ Clear documentation and reasoning provided

### Good Score (80-99):
- ✅ Most checkboxes checked
- ✅ Uses overrides appropriately
- ⚠️  Minor issues in documentation or explanation
- ✅ All critical issues resolved
- ✅ Application functional

### Needs Improvement (<80):
- ❌ Misses some transitive dependencies
- ❌ Overuses overrides (uses them for direct deps)
- ❌ Invalid override syntax
- ❌ Vulnerabilities remain after remediation
- ❌ Breaking changes introduced

---

## 🔍 Key Indicators of Success

### ✅ Good Override Usage (Escape Hatch Strategy)
```
Agent says: "braces is a deep transitive dependency requiring webpack 
major upgrade. Using override as escape hatch for immediate fix without 
breaking changes."

Agent generates:
{
  "overrides": {
    "braces": "3.0.3"
  }
}
```

### ❌ Bad Override Usage (Over-reliance)
```
Agent says: "Fixing all vulnerabilities with overrides."

Agent generates:
{
  "overrides": {
    "axios": "1.6.7",      // ❌ axios is DIRECT, should upgrade in deps
    "ejs": "3.1.10",       // ❌ ejs is DIRECT, should upgrade in deps
    "express": "4.18.2",   // ❌ express is DIRECT, should upgrade in deps
    "qs": "6.11.0"         // ✅ This one is OK (transitive)
  }
}
```

---

## 📊 Test Case Checklist

Run your agent against these specific scenarios:

### Test Case A: Simple Transitive
- [ ] Input: qs@6.7.0 vulnerability
- [ ] Expected: Upgrade express (preferred) OR override qs
- [ ] Agent chooses correct strategy

### Test Case B: Deep Transitive (Breaking Change)
- [ ] Input: braces@2.3.2 via webpack@4.46.0
- [ ] Expected: Override braces (escape hatch)
- [ ] Agent recognizes webpack 4→5 is breaking

### Test Case C: Mixed Scenario
- [ ] Input: axios (direct) + qs (transitive) + braces (deep transitive)
- [ ] Expected: Upgrade axios, upgrade express, override braces
- [ ] Agent uses mixed strategy correctly

### Test Case D: Multiple Paths
- [ ] Input: qs appears in 3 dependency chains
- [ ] Expected: Single override OR single parent upgrade
- [ ] Agent doesn't create duplicate overrides

### Test Case E: All Critical/High
- [ ] Input: Full vulnerability report (26 issues)
- [ ] Expected: Comprehensive remediation plan
- [ ] Agent addresses all critical and high severity issues

---

## 🎓 Grading Rubric

| Category | Weight | Criteria |
|----------|--------|----------|
| **Dependency Analysis** | 20% | Correctly identifies direct vs transitive |
| **Strategy Selection** | 30% | Uses overrides as escape hatch, prefers direct upgrades |
| **Patch Quality** | 20% | Valid syntax, applies cleanly, no duplicates |
| **Completeness** | 15% | Addresses all vulnerabilities comprehensively |
| **Validation** | 15% | npm install works, vulnerabilities resolved |

**Passing Grade:** 75% or higher  
**Excellent:** 90% or higher

---

## 💡 Common Mistakes to Watch For

### ❌ Mistake 1: Using Overrides for Direct Dependencies
```json
// WRONG - axios is direct dependency
{
  "overrides": {
    "axios": "1.6.7"
  }
}

// CORRECT - upgrade in dependencies
{
  "dependencies": {
    "axios": "1.6.7"
  }
}
```

### ❌ Mistake 2: Duplicate Override Entries
```json
// WRONG - duplicate keys
{
  "overrides": {
    "qs": "6.11.0",
    "braces": "3.0.3",
    "qs": "6.11.0"  // Duplicate!
  }
}
```

### ❌ Mistake 3: Using Semver Ranges in Overrides
```json
// WRONG - use exact versions
{
  "overrides": {
    "qs": "^6.11.0"
  }
}

// CORRECT
{
  "overrides": {
    "qs": "6.11.0"
  }
}
```

### ❌ Mistake 4: Creating Overrides When Direct Upgrade Available
```json
// Input: qs via express@4.17.1
// express@4.18.2 includes qs@6.11.0

// WRONG - unnecessary override
{
  "dependencies": {
    "express": "4.17.1"  // Left old version
  },
  "overrides": {
    "qs": "6.11.0"
  }
}

// CORRECT - prefer direct upgrade
{
  "dependencies": {
    "express": "4.18.2"  // Fixes qs transitively
  }
}
```

---

## 🚀 Quick Start Guide

1. **Generate patch with your agent:**
   ```bash
   your-agent remediate --input npm-audit-full.json --output agent-generated-patch.diff
   ```

2. **Run automated validation:**
   ```bash
   ./test-override-remediation.sh
   ```

3. **Review this checklist manually:**
   - Go through each checkbox
   - Mark items as complete/incomplete
   - Calculate final score

4. **Iterate and improve:**
   - Address any failed checks
   - Re-run validation
   - Repeat until passing

---

## 📝 Final Verification Command

```bash
# Complete verification in one command
echo "=== Applying Patch ===" && \
git apply agent-generated-patch.diff && \
echo "=== Installing ===" && \
npm install && \
echo "=== Checking Overrides ===" && \
cat package.json | jq '.overrides' && \
echo "=== Verifying Packages ===" && \
npm ls qs braces minimist && \
echo "=== Security Audit ===" && \
npm audit && \
echo "=== Testing App ===" && \
timeout 5 npm start
```

Expected output:
- Patch applies cleanly ✓
- npm install succeeds ✓
- Overrides section present (if needed) ✓
- All packages at safe versions ✓
- Reduced vulnerability count ✓
- Application starts ✓

---

**Your agent passes if it uses overrides as an "escape hatch" - only when direct upgrades aren't feasible due to breaking changes or unavailability!**
