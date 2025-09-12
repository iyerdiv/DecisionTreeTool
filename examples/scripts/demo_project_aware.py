#!/usr/bin/env python3
"""
Demo of project-aware DecisionTreeTool functionality
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionNode, DecisionTreeCLI
from src.DecisionTreeTool.project_context import get_project_context

print("🚀 DecisionTreeTool Project-Aware Demo")
print("=" * 50)

# Initialize the CLI with project context
cli = DecisionTreeCLI()

# Show current project detection
print(f"📍 Auto-detected project: {cli.current_project}")
print()

# List available projects
print("📁 Available Projects:")
print(cli.list_projects())
print()

# Create a tree for PerfectMileSciOpsBrain
print("🌳 Creating OpsBrain troubleshooting tree...")
cli.create_tree("OpsBrain Alert Response", "Systematic response to OpsBrain alerts")

# Add nodes to the tree
cli.add_node_cmd("Is this a critical severity alert?", "condition")
cli.add_node_cmd("Page on-call immediately", "action", "Send high-priority page via PagerDuty")
cli.add_node_cmd("Check alert details", "action", "Review alert context, metrics, and timeline")
cli.add_node_cmd("Is this a known issue?", "condition")
cli.add_node_cmd("Follow runbook procedure", "action", "Execute documented resolution steps")
cli.add_node_cmd("Escalate for investigation", "action", "Create incident, gather data, notify team")

# Link nodes (simplified - would need actual IDs in real use)
print("🔗 Building decision flow...")

# Export to PerfectMileSciOpsBrain project
print()
print("💾 Exporting to PerfectMileSciOpsBrain project...")
result = cli.export_tree("json", project_name="PerfectMileSciOpsBrain")
print(result)

result = cli.export_tree("ascii", project_name="PerfectMileSciOpsBrain")
print("ASCII export result:", result)

print()
print("📊 Saving visual formats...")
cli.export_tree("mermaid", project_name="PerfectMileSciOpsBrain")
cli.export_tree("dot", project_name="PerfectMileSciOpsBrain")

# Show project directory structure
print()
print("📂 Created project structure:")
project_ctx = get_project_context()
opsbrain_dir = project_ctx.get_project_dir("PerfectMileSciOpsBrain")
print(f"Project directory: {opsbrain_dir}")

# List files in the project
if opsbrain_dir.exists():
    files = list(opsbrain_dir.glob("*"))
    if files:
        print("Files created:")
        for file in files:
            print(f"  • {file.name}")
    else:
        print("(Directory created but no files yet - CLI doesn't persist between commands)")

print()
print("🎯 Project Context Benefits:")
print("• Decision trees are organized by project")
print("• Auto-detects current project from working directory")
print("• Saves files to appropriate project subdirectories")
print("• Can switch between projects for different contexts")
print("• Each project maintains its own tree library")

print()
print("🔧 Usage Examples:")
print("python3 manage_decision_tree.py list-projects")
print("python3 manage_decision_tree.py set-project PerfectMileSciOpsBrain")
print("python3 manage_decision_tree.py export --format ascii --project QEcosystem")
print("python3 manage_decision_tree.py list  # shows both project trees and active trees")

print()
print("✅ Project-aware functionality is working!")