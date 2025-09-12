#!/usr/bin/env python3
"""
Create decision trees for the DecisionTreeTool project itself
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionNode, DecisionTreeCLI

print("🌳 Creating DecisionTreeTool Project Trees")
print("=" * 50)

cli = DecisionTreeCLI()

# Tree 1: Development Workflow
print("📋 Creating: Development Workflow Decision Tree")
cli.create_tree("Development Workflow", "Guide for developing and enhancing DecisionTreeTool")

# Add nodes for development workflow
cli.add_node_cmd("Is this a new feature request?", "condition")
cli.add_node_cmd("Is this a bug fix?", "condition") 
cli.add_node_cmd("Plan feature implementation", "action", "Write requirements, design API, create examples")
cli.add_node_cmd("Reproduce and diagnose bug", "action", "Create test case, identify root cause, plan fix")
cli.add_node_cmd("Update documentation", "action", "Update README, add examples, document API changes")
cli.add_node_cmd("Run tests and validate", "action", "Test all formats, validate examples, check edge cases")
cli.add_node_cmd("Commit and push changes", "action", "git add, commit with clear message, push to GitHub")

# Save to DecisionTreeTool project
result = cli.export_tree("json")
print(f"✅ {result}")
result = cli.export_tree("ascii") 
print(f"✅ ASCII: {result}")
print()

# Tree 2: User Support Decision Tree
print("🎧 Creating: User Support Decision Tree")  
cli.create_tree("User Support Guide", "Help users troubleshoot DecisionTreeTool issues")

cli.add_node_cmd("What type of issue is the user experiencing?", "condition")
cli.add_node_cmd("Installation problems?", "condition")
cli.add_node_cmd("Tree rendering issues?", "condition")
cli.add_node_cmd("Project organization problems?", "condition")
cli.add_node_cmd("Check Python version and dependencies", "action", "Verify Python 3.7+, check requirements.txt")
cli.add_node_cmd("Test ASCII renderer with simple tree", "action", "Create basic tree, test for cycles or depth issues")
cli.add_node_cmd("Verify project detection and directory structure", "action", "Check decision_trees/ folder, test project commands")
cli.add_node_cmd("Point to documentation and examples", "action", "Reference README, example scripts, GitHub issues")

result = cli.export_tree("json")
print(f"✅ {result}")
result = cli.export_tree("mermaid")
print(f"✅ Mermaid: {result}")
print()

# Tree 3: Feature Planning Decision Tree
print("🚀 Creating: Feature Planning Decision Tree")
cli.create_tree("Feature Planning", "Decide on new features and priorities for DecisionTreeTool")

cli.add_node_cmd("Is this feature request from a user?", "condition")
cli.add_node_cmd("Does it align with core mission?", "condition")
cli.add_node_cmd("How complex is the implementation?", "condition")
cli.add_node_cmd("Add to backlog with high priority", "action", "User-requested features get priority")
cli.add_node_cmd("Evaluate fit with decision tree workflow", "action", "Ensure it enhances tree creation/management")
cli.add_node_cmd("Assess development effort required", "action", "Estimate hours, identify dependencies, plan timeline")
cli.add_node_cmd("Create GitHub issue with requirements", "action", "Document specs, examples, acceptance criteria")

result = cli.export_tree("json")
print(f"✅ {result}")
result = cli.export_tree("dot")
print(f"✅ DOT: {result}")
print()

print("🎯 DecisionTreeTool Project Trees Created!")
print()
print("📂 Files saved to: decision_trees/DecisionTreeTool/")

# Show what was created
import os
dt_dir = "decision_trees/DecisionTreeTool"
if os.path.exists(dt_dir):
    files = os.listdir(dt_dir)
    print("📄 Created files:")
    for file in sorted(files):
        print(f"  • {file}")

print()
print("🔧 Usage:")
print("python3 manage_decision_tree.py list  # See all trees")
print("python3 manage_decision_tree.py load --name 'development_workflow'  # Load specific tree")
print("python3 manage_decision_tree.py export --format ascii  # View loaded tree")

print()
print("✨ The DecisionTreeTool project now has its own decision trees!")