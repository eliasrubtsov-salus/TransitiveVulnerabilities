# Expected Remediation Patch (Reference)
# This shows what your agent should generate

## Approach 1: Direct Upgrades Only (Recommended)

```json
{
  "name": "vulnerable-transitive-app",
  "version": "1.0.0",
  "description": "Sample app with vulnerable transitive dependencies for testing remediation agents",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "audit": "npm audit",
    "audit-json": "npm audit --json > audit-report.json"
  },
  "dependencies": {
    "express": "4.18.2",
    "body-parser": "1.20.2",
    "ejs": "3.1.10",
    "axios": "1.6.7",
    "jsonwebtoken": "9.0.2",
    "dotenv": "16.4.5"
  },
  "devDependencies": {
    "webpack": "5.89.0",
    "webpack-cli": "5.1.4"
  },
  "keywords": [
    "vulnerable",
    "testing",
    "security",
    "transitive-dependencies"
  ],
  "author": "Test",
  "license": "MIT"
}
```

## Approach 2: Minimal Upgrades + Overrides

```json
{
  "name": "vulnerable-transitive-app",
  "version": "1.0.0",
  "description": "Sample app with vulnerable transitive dependencies for testing remediation agents",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "audit": "npm audit",
    "audit-json": "npm audit --json > audit-report.json"
  },
  "dependencies": {
    "express": "4.18.2",
    "body-parser": "1.20.2",
    "ejs": "3.1.10",
    "axios": "1.6.7",
    "jsonwebtoken": "9.0.2",
    "dotenv": "16.4.5"
  },
  "devDependencies": {
    "webpack": "4.46.0",
    "webpack-cli": "3.3.12"
  },
  "overrides": {
    "minimist": "1.2.8"
  },
  "keywords": [
    "vulnerable",
    "testing",
    "security",
    "transitive-dependencies"
  ],
  "author": "Test",
  "license": "MIT"
}
```

## Approach 3: Conservative (Override-Heavy)

```json
{
  "name": "vulnerable-transitive-app",
  "version": "1.0.0",
  "description": "Sample app with vulnerable transitive dependencies for testing remediation agents",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "audit": "npm audit",
    "audit-json": "npm audit --json > audit-report.json"
  },
  "dependencies": {
    "express": "4.17.1",
    "body-parser": "1.19.0",
    "ejs": "3.1.10",
    "axios": "1.6.7",
    "jsonwebtoken": "9.0.2",
    "dotenv": "16.4.5"
  },
  "devDependencies": {
    "webpack": "4.46.0",
    "webpack-cli": "3.3.12"
  },
  "overrides": {
    "qs": "6.11.0",
    "minimist": "1.2.8",
    "nth-check": "2.1.1"
  },
  "keywords": [
    "vulnerable",
    "testing",
    "security",
    "transitive-dependencies"
  ],
  "author": "Test",
  "license": "MIT"
}
```

## Validation Commands

After applying any of these approaches:

```bash
# Reinstall with new versions
npm install

# Verify no high/critical vulnerabilities
npm audit

# Check specific packages
npm ls qs        # Should show 6.11.0 or higher
npm ls minimist  # Should show 1.2.8 or higher
npm ls axios     # Should show 1.6.7 or higher

# Test app still works
npm start
```

## Agent Scoring Rubric

**Perfect Score (100%)**:
- Identifies all vulnerabilities correctly
- Distinguishes direct from transitive
- Prefers direct upgrades when available
- Uses overrides only when necessary
- Generates valid, applicable patch
- Includes clear explanations

**Good Score (80-99%)**:
- Fixes all critical/high vulnerabilities
- May over-use overrides instead of direct upgrades
- Minor formatting issues in patch

**Needs Improvement (<80%)**:
- Misses transitive dependencies
- Generates invalid override syntax
- Patch doesn't apply cleanly
- Breaks application functionality
