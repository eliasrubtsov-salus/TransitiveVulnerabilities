# Agent Testing Guide

## Setup Instructions

1. **Install dependencies**:
```bash
cd vulnerable-transitive-app
npm install
```

2. **Generate test data**:
```bash
./generate-test-data.sh
```

3. **Analyze dependencies** (optional):
```bash
python3 analyze-dependencies.py
```

## Test Cases for Your Agent

### Test Case 1: Direct Dependency Vulnerability (Simple)

**Input**: `axios@0.21.1` has CVE-2021-3749

**Agent Task**:
- Detect the vulnerability
- Identify it as a DIRECT dependency
- Check npm registry for safe version (0.21.4+ or 1.6.0+)
- Generate patch upgrading axios

**Expected Output**:
```json
{
  "vulnerability": "CVE-2021-3749",
  "package": "axios",
  "current_version": "0.21.1",
  "dependency_type": "direct",
  "remediation_strategy": "direct_upgrade",
  "recommended_version": "1.6.7",
  "patch": "diff --git a/package.json...",
  "reasoning": "axios is a direct dependency with a critical SSRF vulnerability. Upgrading to 1.6.7 (latest stable) resolves CVE-2021-3749."
}
```

---

### Test Case 2: Transitive Dependency via Single Path

**Input**: `qs` package has multiple CVEs (CVE-2022-24999, prototype pollution)

**Dependency Chain**:
```
app → express@4.17.1 → body-parser@1.19.0 → qs@6.7.0
```

**Agent Task**:
- Detect qs vulnerability
- Trace dependency path
- Check if express@4.18.2 includes fixed qs version (it does)
- Recommend upgrading express

**Expected Output**:
```json
{
  "vulnerability": "CVE-2022-24999",
  "package": "qs",
  "current_version": "6.7.0",
  "dependency_type": "transitive",
  "dependency_path": ["app", "express@4.17.1", "body-parser@1.19.0", "qs@6.7.0"],
  "remediation_strategy": "upgrade_direct_dependency",
  "direct_dependency": "express",
  "direct_dependency_current": "4.17.1",
  "direct_dependency_recommended": "4.18.2",
  "reasoning": "qs is a transitive dependency through express. Upgrading express from 4.17.1 to 4.18.2 will transitively update qs to a safe version (6.11.0+)."
}
```

---

### Test Case 3: Deep Transitive Dependency

**Input**: `minimist@1.2.5` has CVE-2021-44906

**Dependency Chain**:
```
app → webpack-cli@3.3.12 → yargs@13.3.2 → yargs-parser@13.1.2 → minimist@1.2.5
```

**Agent Task**:
- Detect minimist vulnerability
- Trace deep dependency path
- Recognize webpack-cli@3.3.12 is old (current: 5.1.4)
- Determine if upgrade fixes issue OR if override needed
- Note that webpack-cli 5.x requires webpack 5.x (breaking change)

**Expected Output** (Option 1 - Override):
```json
{
  "vulnerability": "CVE-2021-44906",
  "package": "minimist",
  "current_version": "1.2.5",
  "dependency_type": "transitive",
  "dependency_path": ["app", "webpack-cli@3.3.12", "yargs@13.3.2", "yargs-parser@13.1.2", "minimist@1.2.5"],
  "remediation_strategy": "npm_override",
  "override_package": "minimist",
  "override_version": "1.2.8",
  "reasoning": "minimist is a deep transitive dependency. Upgrading webpack-cli would require upgrading webpack 4→5 (major breaking change). Using npm override is safer for immediate security fix.",
  "alternative": "Consider upgrading to webpack@5.89.0 + webpack-cli@5.1.4 for long-term solution"
}
```

**Expected Output** (Option 2 - Major Upgrade):
```json
{
  "vulnerability": "CVE-2021-44906",
  "package": "minimist",
  "dependency_type": "transitive",
  "remediation_strategy": "major_upgrade_with_breaking_changes",
  "upgrades": [
    {"package": "webpack", "from": "4.46.0", "to": "5.89.0"},
    {"package": "webpack-cli", "from": "3.3.12", "to": "5.1.4"}
  ],
  "reasoning": "Upgrading webpack to v5 resolves all transitive vulnerabilities but requires code migration.",
  "warning": "This is a breaking change requiring webpack.config.js updates",
  "fallback": "Use npm override for minimist@1.2.8 as temporary solution"
}
```

---

### Test Case 4: Multiple Paths to Same Vulnerable Package

**Input**: `qs@6.7.0` appears in multiple dependency chains

**Dependency Chains**:
```
1. app → express@4.17.1 → qs@6.7.0
2. app → express@4.17.1 → body-parser@1.19.0 → qs@6.7.0
3. app → body-parser@1.19.0 → qs@6.7.0
```

**Agent Task**:
- Detect all paths to qs
- Recognize that one fix (upgrade express OR override) fixes all instances
- Don't create duplicate remediation steps

**Expected Output**:
```json
{
  "vulnerability": "CVE-2022-24999",
  "package": "qs",
  "dependency_type": "transitive",
  "multiple_paths": true,
  "dependency_paths": [
    ["app", "express@4.17.1", "qs@6.7.0"],
    ["app", "express@4.17.1", "body-parser@1.19.0", "qs@6.7.0"],
    ["app", "body-parser@1.19.0", "qs@6.7.0"]
  ],
  "remediation_strategy": "single_fix_multiple_paths",
  "solution": "Upgrade express to 4.18.2 OR add npm override for qs",
  "reasoning": "qs appears in 3 dependency chains, but all originate from express and body-parser. Upgrading express resolves all instances."
}
```

---

### Test Case 5: Complete Remediation Plan

**Input**: All vulnerabilities in the project

**Agent Task**:
- Scan all vulnerabilities
- Prioritize by severity
- Generate comprehensive remediation plan
- Create single patch file fixing all issues

**Expected Output Structure**:
```json
{
  "total_vulnerabilities": 15,
  "by_severity": {
    "critical": 2,
    "high": 5,
    "moderate": 8
  },
  "remediation_plan": [
    {
      "priority": 1,
      "type": "direct_upgrade",
      "changes": [
        {"package": "axios", "from": "0.21.1", "to": "1.6.7"},
        {"package": "ejs", "from": "3.1.6", "to": "3.1.10"},
        {"package": "jsonwebtoken", "from": "8.5.1", "to": "9.0.2"}
      ]
    },
    {
      "priority": 2,
      "type": "transitive_upgrade",
      "changes": [
        {"package": "express", "from": "4.17.1", "to": "4.18.2", "fixes": ["qs"]},
        {"package": "body-parser", "from": "1.19.0", "to": "1.20.2"}
      ]
    },
    {
      "priority": 3,
      "type": "npm_override",
      "changes": [
        {"package": "minimist", "version": "1.2.8", "reason": "Deep transitive via webpack-cli"}
      ]
    }
  ],
  "patch_file": "diff --git a/package.json..."
}
```

---

## Evaluation Criteria

### Critical Requirements (Must Pass)
- [ ] Correctly identifies direct vs transitive dependencies
- [ ] Traces complete dependency paths for transitive vulnerabilities
- [ ] Generates valid, applicable patches
- [ ] Uses correct npm override syntax when needed
- [ ] Prefers direct upgrades over overrides

### Advanced Features (Nice to Have)
- [ ] Detects multiple paths to same vulnerable package
- [ ] Handles breaking changes appropriately
- [ ] Provides fallback strategies
- [ ] Validates remediation won't break app
- [ ] Generates comprehensive explanations

### Output Quality
- [ ] Machine-readable JSON output
- [ ] Human-readable explanations
- [ ] Prioritized by severity
- [ ] Includes validation commands
- [ ] Documents trade-offs for breaking changes

---

## Running Your Agent

```bash
# Basic test
your-agent analyze --input test-outputs/npm-audit.json \
                   --deps test-outputs/dependency-tree.json \
                   --output remediation-patch.json

# Apply and validate
git apply remediation.patch
npm install
npm audit
```

---

## Common Pitfalls to Avoid

1. **Don't blindly upgrade everything** - Some upgrades are breaking changes
2. **Don't create multiple overrides for same package** - One override applies globally
3. **Don't miss transitive dependencies** - These are harder but common
4. **Don't forget to check if direct upgrade fixes transitive** - Always check first
5. **Don't use invalid override syntax** - Test with `npm install --dry-run`

---

## Success Metrics

After applying your agent's patch:
- `npm audit` shows 0 high/critical vulnerabilities
- `npm install` completes without errors
- `npm start` runs successfully
- All tests pass (if any)
- Lock file regenerates correctly
