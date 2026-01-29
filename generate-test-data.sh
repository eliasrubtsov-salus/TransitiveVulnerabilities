#!/bin/bash

# Test script to generate data for vulnerability remediation agent testing
# Run this after npm install to generate test inputs

echo "==================================="
echo "Generating Test Data for Agent"
echo "==================================="
echo ""

# Create output directory
mkdir -p test-outputs

# 1. Generate npm audit report (JSON)
echo "1. Generating npm audit report..."
npm audit --json > test-outputs/npm-audit.json 2>&1
echo "   ✓ Saved to test-outputs/npm-audit.json"
echo ""

# 2. Generate dependency tree for qs
echo "2. Analyzing qs dependency chain..."
npm ls qs --all > test-outputs/qs-dependency-tree.txt 2>&1
echo "   ✓ Saved to test-outputs/qs-dependency-tree.txt"
echo ""

# 3. Generate dependency tree for minimist
echo "3. Analyzing minimist dependency chain..."
npm ls minimist --all > test-outputs/minimist-dependency-tree.txt 2>&1
echo "   ✓ Saved to test-outputs/minimist-dependency-tree.txt"
echo ""

# 4. Generate full dependency tree
echo "4. Generating complete dependency tree..."
npm ls --all > test-outputs/full-dependency-tree.txt 2>&1
echo "   ✓ Saved to test-outputs/full-dependency-tree.txt"
echo ""

# 5. Generate JSON dependency tree
echo "5. Generating JSON dependency tree..."
npm ls --json --all > test-outputs/dependency-tree.json 2>&1
echo "   ✓ Saved to test-outputs/dependency-tree.json"
echo ""

# 6. Check for outdated packages
echo "6. Checking for outdated packages..."
npm outdated --json > test-outputs/outdated-packages.json 2>&1
echo "   ✓ Saved to test-outputs/outdated-packages.json"
echo ""

# 7. Generate package-lock.json if it doesn't exist
if [ ! -f "package-lock.json" ]; then
    echo "7. Generating package-lock.json..."
    npm install --package-lock-only
    echo "   ✓ package-lock.json created"
else
    echo "7. package-lock.json already exists"
fi
echo ""

# 8. Summary report
echo "==================================="
echo "Summary of Vulnerabilities Found"
echo "==================================="
npm audit --json | grep -o '"severity":"[^"]*"' | sort | uniq -c
echo ""

echo "==================================="
echo "Test Data Generation Complete!"
echo "==================================="
echo ""
echo "Files generated in test-outputs/:"
echo "  - npm-audit.json (vulnerability scan results)"
echo "  - qs-dependency-tree.txt (qs transitive chain)"
echo "  - minimist-dependency-tree.txt (minimist transitive chain)"
echo "  - full-dependency-tree.txt (complete tree)"
echo "  - dependency-tree.json (machine-readable tree)"
echo "  - outdated-packages.json (available updates)"
echo ""
echo "Use these files as input to your remediation agent."
echo ""
echo "Next steps:"
echo "  1. Feed npm-audit.json to your agent"
echo "  2. Agent should analyze dependency-tree.json"
echo "  3. Agent generates remediation patch"
echo "  4. Apply patch and run 'npm install'"
echo "  5. Verify with 'npm audit'"
