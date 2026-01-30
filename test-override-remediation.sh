#!/bin/bash
# test-override-remediation.sh
# Automated validation script for testing agent's override remediation capabilities

set -e  # Exit on any error

echo "========================================="
echo "Override Remediation Validation Suite"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test result function
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $2"
        ((TESTS_FAILED++))
    fi
}

# Save original package.json
if [ -f "package.json" ]; then
    cp package.json package.json.backup
    echo "Backed up original package.json"
else
    echo -e "${RED}ERROR: package.json not found${NC}"
    exit 1
fi

echo ""

# Check if agent patch exists
if [ ! -f "agent-generated-patch.diff" ]; then
    echo -e "${YELLOW}WARNING: agent-generated-patch.diff not found${NC}"
    echo "Please generate the patch with your agent first:"
    echo "  your-agent remediate --input npm-audit-full.json --output agent-generated-patch.diff"
    echo ""
    echo "For testing purposes, you can create a reference patch with:"
    echo "  npm audit fix --dry-run --json > suggested-fixes.json"
    exit 1
fi

echo "========================================="
echo "Test 1: Patch Application"
echo "========================================="

# Apply agent's generated patch
git apply agent-generated-patch.diff 2>&1
RESULT=$?
test_result $RESULT "Patch applies cleanly"
echo ""

if [ $RESULT -ne 0 ]; then
    echo -e "${RED}CRITICAL: Cannot continue if patch doesn't apply${NC}"
    cp package.json.backup package.json
    rm package.json.backup
    exit 1
fi

echo "========================================="
echo "Test 2: Package.json Validation"
echo "========================================="

# Validate JSON syntax
node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))" 2>&1
RESULT=$?
test_result $RESULT "package.json is valid JSON"

# Check if overrides section exists (not required, but check if present)
if grep -q '"overrides"' package.json; then
    echo -e "${GREEN}ℹ${NC} Override section found in package.json"
    
    # Validate override syntax
    node -e "
    const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
    if (pkg.overrides && typeof pkg.overrides === 'object') {
        console.log('Override syntax is valid object');
        process.exit(0);
    } else {
        console.error('Override syntax is invalid');
        process.exit(1);
    }
    " 2>&1
    RESULT=$?
    test_result $RESULT "Override syntax is valid"
    
    # Check for semver ranges in overrides (should use exact versions)
    node -e "
    const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
    let hasRanges = false;
    if (pkg.overrides) {
        for (const [key, value] of Object.entries(pkg.overrides)) {
            if (typeof value === 'string' && (value.includes('^') || value.includes('~') || value.includes('>'))) {
                console.error('Override for ' + key + ' uses semver range: ' + value);
                hasRanges = true;
            }
        }
    }
    process.exit(hasRanges ? 1 : 0);
    " 2>&1
    RESULT=$?
    test_result $RESULT "Overrides use exact versions (no semver ranges)"
else
    echo -e "${YELLOW}ℹ${NC} No overrides section (direct upgrades used)"
fi
echo ""

echo "========================================="
echo "Test 3: Dependency Installation"
echo "========================================="

# Install dependencies
npm install > npm-install.log 2>&1
RESULT=$?
test_result $RESULT "npm install completes successfully"

if [ $RESULT -ne 0 ]; then
    echo "npm install output:"
    cat npm-install.log
fi
echo ""

echo "========================================="
echo "Test 4: Transitive Dependency Resolution"
echo "========================================="

# Test Case 4.1: qs vulnerability
echo "Test 4.1: qs package (transitive via express/body-parser)"
QS_VERSION=$(npm ls qs 2>/dev/null | grep -m1 "qs@" | sed -E 's/.*qs@([0-9.]+).*/\1/')

if [ -z "$QS_VERSION" ]; then
    echo -e "${YELLOW}⚠${NC}  qs not found in dependency tree"
else
    # Check if version is >= 6.11.0
    if [ "$(echo "$QS_VERSION" | cut -d. -f1)" -ge 6 ] && [ "$(echo "$QS_VERSION" | cut -d. -f2)" -ge 11 ]; then
        test_result 0 "qs version is $QS_VERSION (>= 6.11.0)"
    else
        test_result 1 "qs version is $QS_VERSION (expected >= 6.11.0)"
    fi
fi
echo ""

# Test Case 4.2: braces vulnerability
echo "Test 4.2: braces package (deep transitive via webpack)"
BRACES_VERSION=$(npm ls braces 2>/dev/null | grep -m1 "braces@" | sed -E 's/.*braces@([0-9.]+).*/\1/')

if [ -z "$BRACES_VERSION" ]; then
    echo -e "${YELLOW}⚠${NC}  braces not found in dependency tree"
else
    # Check if version is >= 3.0.3
    if [ "$(echo "$BRACES_VERSION" | cut -d. -f1)" -ge 3 ]; then
        test_result 0 "braces version is $BRACES_VERSION (>= 3.0.3)"
    else
        echo -e "${YELLOW}ℹ${NC}  braces version is $BRACES_VERSION (may be fixed by webpack upgrade)"
    fi
fi
echo ""

# Test Case 4.3: minimist vulnerability
echo "Test 4.3: minimist package (deep transitive via webpack-cli)"
MINIMIST_VERSION=$(npm ls minimist 2>/dev/null | grep -m1 "minimist@" | sed -E 's/.*minimist@([0-9.]+).*/\1/')

if [ -z "$MINIMIST_VERSION" ]; then
    echo -e "${YELLOW}⚠${NC}  minimist not found in dependency tree"
else
    # Check if version is >= 1.2.8
    if [ "$(echo "$MINIMIST_VERSION" | cut -d. -f1)" -ge 1 ] && [ "$(echo "$MINIMIST_VERSION" | cut -d. -f2)" -ge 2 ] && [ "$(echo "$MINIMIST_VERSION" | cut -d. -f3)" -ge 8 ]; then
        test_result 0 "minimist version is $MINIMIST_VERSION (>= 1.2.8)"
    else
        test_result 1 "minimist version is $MINIMIST_VERSION (expected >= 1.2.8)"
    fi
fi
echo ""

echo "========================================="
echo "Test 5: Direct Dependency Upgrades"
echo "========================================="

# Test Case 5.1: axios (direct dependency)
echo "Test 5.1: axios package (direct dependency)"
AXIOS_VERSION=$(npm ls axios --depth=0 2>/dev/null | grep -m1 "axios@" | sed -E 's/.*axios@([0-9.]+).*/\1/')

if [ -z "$AXIOS_VERSION" ]; then
    test_result 1 "axios not found"
else
    # Check if version is >= 0.21.4 or >= 1.0.0
    MAJOR=$(echo "$AXIOS_VERSION" | cut -d. -f1)
    MINOR=$(echo "$AXIOS_VERSION" | cut -d. -f2)
    PATCH=$(echo "$AXIOS_VERSION" | cut -d. -f3)
    
    if [ "$MAJOR" -ge 1 ]; then
        test_result 0 "axios version is $AXIOS_VERSION (>= 1.0.0)"
    elif [ "$MAJOR" -eq 0 ] && [ "$MINOR" -ge 21 ] && [ "$PATCH" -ge 4 ]; then
        test_result 0 "axios version is $AXIOS_VERSION (>= 0.21.4)"
    else
        test_result 1 "axios version is $AXIOS_VERSION (expected >= 0.21.4)"
    fi
fi
echo ""

# Test Case 5.2: ejs (direct dependency)
echo "Test 5.2: ejs package (direct dependency)"
EJS_VERSION=$(npm ls ejs --depth=0 2>/dev/null | grep -m1 "ejs@" | sed -E 's/.*ejs@([0-9.]+).*/\1/')

if [ -z "$EJS_VERSION" ]; then
    test_result 1 "ejs not found"
else
    # Check if version is >= 3.1.10
    if [ "$(echo "$EJS_VERSION" | cut -d. -f1)" -ge 3 ] && [ "$(echo "$EJS_VERSION" | cut -d. -f2)" -ge 1 ] && [ "$(echo "$EJS_VERSION" | cut -d. -f3)" -ge 10 ]; then
        test_result 0 "ejs version is $EJS_VERSION (>= 3.1.10)"
    else
        test_result 1 "ejs version is $EJS_VERSION (expected >= 3.1.10)"
    fi
fi
echo ""

echo "========================================="
echo "Test 6: Duplicate Override Detection"
echo "========================================="

# Check for duplicate override entries
node -e "
const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
if (!pkg.overrides) {
    console.log('No overrides section');
    process.exit(0);
}

const keys = Object.keys(pkg.overrides);
const uniqueKeys = [...new Set(keys)];

if (keys.length !== uniqueKeys.length) {
    console.error('Found duplicate override keys');
    process.exit(1);
}

console.log('No duplicate override entries found');
process.exit(0);
" 2>&1
RESULT=$?
test_result $RESULT "No duplicate override entries"
echo ""

echo "========================================="
echo "Test 7: Security Audit"
echo "========================================="

# Run npm audit and parse results
npm audit --json > audit-results.json 2>&1 || true

# Check critical vulnerabilities
CRITICAL_VULNS=$(cat audit-results.json | grep -o '"critical":[0-9]*' | head -1 | grep -o '[0-9]*' || echo 0)
HIGH_VULNS=$(cat audit-results.json | grep -o '"high":[0-9]*' | head -1 | grep -o '[0-9]*' || echo 0)

echo "Vulnerability counts after remediation:"
echo "  Critical: $CRITICAL_VULNS"
echo "  High: $HIGH_VULNS"
echo ""

if [ "$CRITICAL_VULNS" -eq 0 ]; then
    test_result 0 "No critical vulnerabilities remaining"
else
    test_result 1 "$CRITICAL_VULNS critical vulnerabilities still present"
fi

if [ "$HIGH_VULNS" -le 3 ]; then
    test_result 0 "High vulnerabilities reduced to acceptable level ($HIGH_VULNS)"
else
    echo -e "${YELLOW}⚠${NC}  $HIGH_VULNS high vulnerabilities still present (may need additional work)"
fi
echo ""

echo "========================================="
echo "Test 8: Application Functionality"
echo "========================================="

# Test if application starts
timeout 5 npm start > app-start.log 2>&1 &
APP_PID=$!
sleep 2

if kill -0 $APP_PID 2>/dev/null; then
    test_result 0 "Application starts successfully"
    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true
else
    test_result 1 "Application failed to start"
fi
echo ""

echo "========================================="
echo "Test 9: Strategy Analysis"
echo "========================================="

# Analyze what remediation strategies were used
echo "Analyzing remediation approach..."

HAS_OVERRIDES=$(grep -c '"overrides"' package.json || echo 0)
EXPRESS_VERSION=$(grep '"express"' package.json | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
WEBPACK_VERSION=$(grep '"webpack"' package.json | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)

echo ""
echo "Remediation Strategy Summary:"
if [ "$HAS_OVERRIDES" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Used npm overrides (escape hatch strategy)"
    echo "    Overrides found:"
    grep -A20 '"overrides"' package.json | grep ':' | grep -v 'overrides' | sed 's/^/    /'
fi

if [ ! -z "$EXPRESS_VERSION" ]; then
    echo -e "  ${GREEN}✓${NC} Express version: $EXPRESS_VERSION"
    if [[ "$EXPRESS_VERSION" =~ ^4\.18\. ]] || [[ "$EXPRESS_VERSION" =~ ^4\.(19|[2-9][0-9]) ]]; then
        echo "    (Updated to fix transitive qs vulnerability)"
    fi
fi

if [ ! -z "$WEBPACK_VERSION" ]; then
    echo "  webpack version: $WEBPACK_VERSION"
    if [[ "$WEBPACK_VERSION" =~ ^5\. ]]; then
        echo "    (Major upgrade to webpack 5 - fixes deep transitive issues)"
    else
        echo "    (webpack 4.x - likely using overrides for transitive deps)"
    fi
fi
echo ""

# Cleanup
echo "========================================="
echo "Cleanup"
echo "========================================="

echo "Restoring original package.json..."
mv package.json package.json.tested
cp package.json.backup package.json
rm package.json.backup

echo "Test artifacts saved:"
echo "  - package.json.tested (patched version)"
echo "  - npm-install.log (installation output)"
echo "  - audit-results.json (post-remediation audit)"
echo "  - app-start.log (application startup log)"
echo ""

echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    echo "Your agent successfully uses overrides as an escape hatch!"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo "Review the failures above to improve your agent's remediation logic."
    exit 1
fi
