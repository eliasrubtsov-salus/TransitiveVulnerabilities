# Vulnerable Transitive Dependency Test App

This Node.js application intentionally contains multiple security vulnerabilities, including **transitive dependency vulnerabilities**, to test automated vulnerability remediation agents.

## Purpose

Test your vulnerability elimination agent's ability to:
1. Detect direct and transitive dependency vulnerabilities
2. Distinguish between the two types
3. Generate appropriate remediation strategies (upgrades vs. overrides)
4. Create correct patches for transitive dependency fixes

## Known Vulnerabilities

### Direct Dependencies with Vulnerabilities

1. **express@4.17.1**
   - Has transitive vulnerabilities through `qs` package
   - Upgrade path available to 4.18.0+

2. **axios@0.21.1**
   - CVE-2021-3749: Server-Side Request Forgery (SSRF)
   - Fixed in: 0.21.2+

3. **ejs@3.1.6**
   - CVE-2022-29078: Template injection vulnerability
   - Fixed in: 3.1.7+

4. **jsonwebtoken@8.5.1**
   - CVE-2022-23529: Improper validation
   - Fixed in: 9.0.0+

5. **dotenv@8.2.0**
   - Multiple vulnerabilities
   - Fixed in: 16.0.0+

### Transitive Dependencies with Vulnerabilities

1. **qs** (via body-parser and express)
   - Dependency chain: `app → express → body-parser → qs`
   - Vulnerable version: ~6.7.0
   - Multiple CVEs including prototype pollution
   - Fixed in: 6.11.0+

2. **minimist** (via webpack-cli)
   - Dependency chain: `app → webpack-cli → yargs → yargs-parser → minimist`
   - CVE-2021-44906: Prototype pollution
   - Fixed in: 1.2.6+

3. **nth-check** (via webpack)
   - Inefficient regular expression complexity
   - Fixed in newer versions

## Installation

```bash
# Install dependencies (this will show npm audit warnings)
npm install

# View full audit report
npm audit

# View audit in JSON format
npm audit --json > audit-report.json

# Check specific transitive dependency chains
npm ls qs
npm ls minimist
npm ls nth-check
```

## Dependency Tree Examples

### qs dependency chain:
```
vulnerable-transitive-app@1.0.0
├─┬ express@4.17.1
│ ├─┬ body-parser@1.19.0
│ │ └── qs@6.7.0 (VULNERABLE)
│ └── qs@6.7.0 (VULNERABLE)
└─┬ body-parser@1.19.0
  └── qs@6.7.0 (VULNERABLE)
```

### minimist dependency chain:
```
vulnerable-transitive-app@1.0.0
└─┬ webpack-cli@3.3.12
  └─┬ yargs@13.3.2
    └─┬ yargs-parser@13.1.2
      └── minimist@1.2.5 (VULNERABLE)
```

## Testing Your Remediation Agent

### Test Case 1: Simple Direct Dependency
**Objective**: Upgrade `axios` from 0.21.1 to 0.21.4+

**Expected Agent Behavior**:
- Detect CVE-2021-3749
- Recommend direct dependency upgrade
- Generate patch modifying `package.json`
- No override needed

### Test Case 2: Transitive Dependency via Single Path
**Objective**: Fix `qs` vulnerability (CVE-2022-24999, CVE-2014-7191)

**Expected Agent Behavior**:
- Detect `qs@6.7.0` vulnerability
- Trace dependency path: `express → body-parser → qs`
- Check if upgrading `express` to 4.18.2 resolves it (it should)
- Generate patch upgrading `express`
- Alternatively, if agent prefers overrides, add npm override

### Test Case 3: Deep Transitive Dependency
**Objective**: Fix `minimist` vulnerability

**Expected Agent Behavior**:
- Detect `minimist@1.2.5` vulnerability (CVE-2021-44906)
- Trace complex dependency path through webpack-cli
- Determine that `webpack@4.46.0` is outdated (webpack 5+ fixes this)
- Recommend either:
  - Upgrading webpack (breaking change, requires migration)
  - Adding override for minimist
- Generate appropriate patch with override

### Test Case 4: Multiple Overlapping Transitive Dependencies
**Objective**: Fix all `qs` occurrences across different dependency paths

**Expected Agent Behavior**:
- Detect `qs` used by both `express` and `body-parser`
- Understand that a single override fixes all instances
- Generate single override entry, not duplicate entries

## Expected Remediation Strategies

### Strategy 1: Direct Upgrade (Preferred)
```json
{
  "dependencies": {
    "express": "4.18.2",  // Was 4.17.1
    "axios": "0.21.4",    // Was 0.21.1
    "ejs": "3.1.10",      // Was 3.1.6
    "jsonwebtoken": "9.0.2",  // Was 8.5.1
    "dotenv": "16.4.5"    // Was 8.2.0
  }
}
```

### Strategy 2: Override for Stubborn Transitive Dependencies
```json
{
  "dependencies": {
    "express": "4.18.2",
    "axios": "0.21.4",
    "ejs": "3.1.10",
    "jsonwebtoken": "9.0.2",
    "dotenv": "16.4.5"
  },
  "overrides": {
    "minimist": "1.2.8",  // Fix transitive via webpack-cli
    "qs": "6.11.0"        // Backup if express upgrade doesn't work
  }
}
```

### Strategy 3: Dev Dependencies
```json
{
  "devDependencies": {
    "webpack": "5.89.0",     // Major upgrade (breaking)
    "webpack-cli": "5.1.4"   // Compatible with webpack 5
  }
}
```

## Running the App

```bash
# Copy environment file
cp .env.example .env

# Start the server
npm start

# Test endpoints
curl http://localhost:3000/health
curl -X POST http://localhost:3000/login -H "Content-Type: application/json" -d '{"username":"test","password":"test123"}'
```

## Validation After Remediation

After your agent generates patches:

```bash
# Apply the patch
git apply remediation.patch

# Reinstall dependencies
npm install

# Verify vulnerabilities are fixed
npm audit

# Check specific packages are updated
npm ls qs
npm ls minimist
npm ls axios

# Ensure app still runs
npm start
```

## Agent Testing Checklist

- [ ] Agent detects all direct dependency vulnerabilities
- [ ] Agent distinguishes direct from transitive dependencies
- [ ] Agent correctly traces transitive dependency chains
- [ ] Agent prefers direct upgrades over overrides when possible
- [ ] Agent generates valid npm override syntax
- [ ] Agent handles multiple dependency paths to same vulnerable package
- [ ] Agent includes explanatory comments in patches
- [ ] Agent validates fix doesn't break application
- [ ] Generated patches apply cleanly with `git apply`
- [ ] Lock file regenerates correctly after patch

## Expected npm audit Output (Before Fix)

```
found X vulnerabilities (Y moderate, Z high, A critical)
```

Common CVEs you should see:
- CVE-2022-24999 (qs)
- CVE-2021-44906 (minimist)
- CVE-2021-3749 (axios)
- CVE-2022-29078 (ejs)
- CVE-2022-23529 (jsonwebtoken)

## Notes

- This app is intentionally vulnerable - **DO NOT deploy to production**
- Some vulnerabilities require breaking changes (webpack 4→5)
- Your agent should handle both simple and complex remediation scenarios
- Test with `npm audit --json` for machine-readable output
