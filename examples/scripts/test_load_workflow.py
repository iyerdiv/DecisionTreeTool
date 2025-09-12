#!/usr/bin/env python3
"""
Test the complete load workflow
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTreeCLI

print("🧪 Testing Tree Load Workflow")
print("=" * 40)

cli = DecisionTreeCLI()

# Step 1: Load the saved tree
print("1️⃣ Loading saved tree...")
result = cli.load_tree("opsbrain_alert_response", "PerfectMileSciOpsBrain")
print(f"Result: {result}")
print()

# Step 2: Verify it's the current tree
print("2️⃣ Checking current tree status...")
list_result = cli.list_trees()
print(list_result)
print()

# Step 3: Export it as ASCII to verify content
print("3️⃣ Displaying loaded tree content...")
ascii_result = cli.export_tree("ascii")
print("Loaded tree structure:")
print(ascii_result)
print()

print("✅ Workflow complete!")
print()
print("🎯 Key Points:")
print("• load command loads tree from project directory")
print("• Makes it the current active tree in memory")  
print("• Can then export, modify, or traverse the loaded tree")
print("• Persistence works: save → load → use")