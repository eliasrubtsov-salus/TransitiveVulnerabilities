#!/usr/bin/env python3
"""
Dependency Chain Analyzer
Analyzes npm dependency trees and identifies transitive vulnerability chains
"""

import json
import sys
from typing import Dict, List, Set, Tuple


def parse_npm_ls_json(json_file: str) -> Dict:
    """Parse npm ls --json output"""
    with open(json_file, 'r') as f:
        return json.load(f)


def parse_npm_audit_json(json_file: str) -> Dict:
    """Parse npm audit --json output"""
    with open(json_file, 'r') as f:
        return json.load(f)


def find_all_paths(dep_tree: Dict, target_package: str, current_path: List[str] = None) -> List[List[str]]:
    """
    Find all dependency paths to a target package
    Returns list of paths, where each path is a list of package names
    """
    if current_path is None:
        current_path = [dep_tree.get('name', 'root')]
    
    paths = []
    
    # Check if current node is the target
    name = dep_tree.get('name', '')
    if target_package in name:
        return [current_path]
    
    # Recursively search dependencies
    dependencies = dep_tree.get('dependencies', {})
    for dep_name, dep_info in dependencies.items():
        new_path = current_path + [f"{dep_name}@{dep_info.get('version', 'unknown')}"]
        sub_paths = find_all_paths(dep_info, target_package, new_path)
        paths.extend(sub_paths)
    
    return paths


def categorize_dependency(paths: List[List[str]]) -> str:
    """Determine if dependency is direct or transitive"""
    if not paths:
        return "not found"
    
    # If shortest path is 2 (root -> package), it's direct
    min_length = min(len(path) for path in paths)
    if min_length == 2:
        return "direct"
    else:
        return "transitive"


def analyze_vulnerability(vuln_data: Dict, dep_tree: Dict) -> Dict:
    """
    Analyze a vulnerability and determine remediation strategy
    """
    via = vuln_data.get('via', [])
    if not via:
        return {}
    
    # Get vulnerable package info
    if isinstance(via[0], dict):
        vuln_package = via[0].get('name', '')
        vuln_version = via[0].get('range', '')
    else:
        vuln_package = via[0] if via else ''
        vuln_version = 'unknown'
    
    # Find all paths to this vulnerable package
    paths = find_all_paths(dep_tree, vuln_package)
    dep_type = categorize_dependency(paths)
    
    # Determine remediation strategy
    if dep_type == "direct":
        strategy = "direct_upgrade"
        explanation = f"Upgrade {vuln_package} directly in package.json"
    elif dep_type == "transitive":
        strategy = "check_direct_then_override"
        # Get the direct dependency from the path
        direct_dep = paths[0][1].split('@')[0] if len(paths[0]) > 1 else "unknown"
        explanation = (
            f"Check if upgrading {direct_dep} resolves the issue. "
            f"If not, use npm overrides to force a safe version of {vuln_package}"
        )
    else:
        strategy = "unknown"
        explanation = "Package not found in dependency tree"
    
    return {
        "package": vuln_package,
        "version": vuln_version,
        "type": dep_type,
        "paths": paths,
        "strategy": strategy,
        "explanation": explanation,
        "severity": vuln_data.get('severity', 'unknown')
    }


def main():
    """Main analysis function"""
    
    print("=" * 70)
    print("Dependency Chain Analyzer for Vulnerability Remediation")
    print("=" * 70)
    print()
    
    # Load data
    try:
        dep_tree = parse_npm_ls_json('test-outputs/dependency-tree.json')
        audit_data = parse_npm_audit_json('test-outputs/npm-audit.json')
    except FileNotFoundError as e:
        print(f"Error: {e}")
        print("Please run './generate-test-data.sh' first to generate required files")
        sys.exit(1)
    
    # Analyze vulnerabilities
    vulnerabilities = audit_data.get('vulnerabilities', {})
    
    print(f"Total vulnerabilities found: {len(vulnerabilities)}")
    print()
    
    # Group by type
    direct_vulns = []
    transitive_vulns = []
    
    for pkg_name, vuln_data in vulnerabilities.items():
        analysis = analyze_vulnerability(vuln_data, dep_tree)
        if not analysis:
            continue
            
        if analysis['type'] == 'direct':
            direct_vulns.append(analysis)
        elif analysis['type'] == 'transitive':
            transitive_vulns.append(analysis)
    
    # Print direct vulnerabilities
    print("=" * 70)
    print(f"DIRECT DEPENDENCIES ({len(direct_vulns)} vulnerabilities)")
    print("=" * 70)
    for vuln in sorted(direct_vulns, key=lambda x: x['severity'], reverse=True):
        print(f"\n📦 {vuln['package']}")
        print(f"   Severity: {vuln['severity'].upper()}")
        print(f"   Strategy: {vuln['strategy']}")
        print(f"   Action: {vuln['explanation']}")
    
    # Print transitive vulnerabilities
    print("\n" + "=" * 70)
    print(f"TRANSITIVE DEPENDENCIES ({len(transitive_vulns)} vulnerabilities)")
    print("=" * 70)
    for vuln in sorted(transitive_vulns, key=lambda x: x['severity'], reverse=True):
        print(f"\n📦 {vuln['package']}")
        print(f"   Severity: {vuln['severity'].upper()}")
        print(f"   Strategy: {vuln['strategy']}")
        print(f"   Dependency chains:")
        for i, path in enumerate(vuln['paths'][:3], 1):  # Show first 3 paths
            print(f"      {i}. {' → '.join(path)}")
        if len(vuln['paths']) > 3:
            print(f"      ... and {len(vuln['paths']) - 3} more paths")
        print(f"   Action: {vuln['explanation']}")
    
    # Summary
    print("\n" + "=" * 70)
    print("REMEDIATION SUMMARY")
    print("=" * 70)
    print(f"Direct dependencies to upgrade: {len(direct_vulns)}")
    print(f"Transitive dependencies requiring analysis: {len(transitive_vulns)}")
    print()
    print("Next steps:")
    print("1. For direct dependencies: Update version in package.json")
    print("2. For transitive dependencies:")
    print("   a. Check if upgrading the direct dependency fixes it")
    print("   b. If not, add npm override for the vulnerable package")
    print("3. Run 'npm install' to apply changes")
    print("4. Verify with 'npm audit'")
    print()


if __name__ == "__main__":
    main()
