#!/usr/bin/env python3
"""
Test what files are actually needed for DecisionTreeTool to work
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

print("🔍 Testing Minimal DecisionTreeTool Installation")
print("=" * 50)

# Test core imports
try:
    from src.DecisionTreeTool.decision_tree_tool import DecisionTreeCLI
    print("✅ Core DecisionTreeTool imports work")
except ImportError as e:
    print(f"❌ Core import failed: {e}")

try:
    from src.DecisionTreeTool.project_context import get_project_context
    print("✅ Project context imports work")
except ImportError as e:
    print(f"❌ Project context import failed: {e}")

# Test basic functionality
try:
    cli = DecisionTreeCLI()
    result = cli.create_tree("Test Tree", "Testing minimal install")
    print(f"✅ Tree creation works: {result}")
    
    # Test project context
    print(f"✅ Project detection: {cli.current_project}")
    
    # Test export
    ascii_result = cli.export_tree("ascii")
    if ascii_result and "🌳" in ascii_result:
        print("✅ ASCII export works")
    else:
        print(f"⚠️  ASCII export result: {ascii_result}")
        
except Exception as e:
    print(f"❌ Basic functionality failed: {e}")

print()
print("📂 Essential Files Analysis:")
print("=" * 30)

essential_files = [
    "manage_decision_tree.py",
    "src/DecisionTreeTool/__init__.py", 
    "src/DecisionTreeTool/decision_tree_tool.py",
    "src/DecisionTreeTool/project_context.py",
    "src/DecisionTreeTool/decision_tree_robust.py"
]

for file_path in essential_files:
    if os.path.exists(file_path):
        size = os.path.getsize(file_path)
        print(f"✅ {file_path} ({size} bytes)")
    else:
        print(f"❌ MISSING: {file_path}")

print()
print("📁 Optional/Deletable Files:")
print("=" * 30)

optional_files = [
    "examples/",
    "temp_files/", 
    "decision_trees/",
    "docs/",
    "test/",
    "build/",
    "brazil.ion",
    "Config",
    "setup.py",
    "NEXT_CLAUDE_PROMPT_2025_09_12.md",
    "README.md"
]

for item in optional_files:
    if os.path.exists(item):
        if os.path.isdir(item):
            file_count = len([f for f in os.listdir(item) if os.path.isfile(os.path.join(item, f))])
            print(f"🗂️  {item} (directory with {file_count} files) - OPTIONAL")
        else:
            size = os.path.getsize(item)
            print(f"📄 {item} ({size} bytes) - OPTIONAL")
    else:
        print(f"➖ {item} (not present)")

print()
print("🎯 Minimal Installation Requirement:")
print("You need:")
print("  • manage_decision_tree.py (main entry point)")
print("  • src/DecisionTreeTool/ (entire directory)")
print("  • Python 3.7+ with basic libraries")
print()
print("You can delete:")
print("  • examples/ (demo scripts)")
print("  • temp_files/ (temporary outputs)")
print("  • docs/ (documentation)")
print("  • test/ (unit tests)")
print("  • decision_trees/ (your saved trees - but you'll lose them!)")
print("  • All the .md files (documentation)")
print("  • brazil.ion, Config, setup.py (build system)")
print()
print("⚠️  Warning: Deleting decision_trees/ will lose all your saved trees!")
print("💡 Recommended: Keep decision_trees/ or back it up first")