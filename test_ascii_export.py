#!/usr/bin/env python3
"""Test ASCII export functionality"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTreeCLI

# Create CLI instance
cli = DecisionTreeCLI()

# Create a simple tree
print("Creating tree...")
result = cli.create_tree("Test Tree", "Testing ASCII export")
print(result)

# Add some nodes
print("\nAdding nodes...")
print(cli.add_node_cmd("Is it working?", "condition"))
print(cli.add_node_cmd("Check the logs", "action", "tail -f /var/log/app.log"))
print(cli.add_node_cmd("Fix the issue", "action", "restart service"))
print(cli.add_node_cmd("Celebrate!", "action", "echo 'Success!'"))

# Link nodes (using simple IDs for demo)
# Note: In real usage, you'd need to track the actual IDs returned
print("\nLinking nodes...")
nodes = list(cli.trees[cli.current_tree].nodes.keys())
if len(nodes) >= 4:
    print(cli.link_nodes(nodes[0], "yes", nodes[3]))  # Working -> Celebrate
    print(cli.link_nodes(nodes[0], "no", nodes[1]))   # Not working -> Check logs
    print(cli.link_nodes(nodes[1], "found_error", nodes[2]))  # Logs -> Fix

# Export as ASCII
print("\n" + "="*60)
print("ASCII EXPORT:")
print("="*60)
ascii_result = cli.export_tree("ascii")
print(ascii_result)

# Export as Mermaid for comparison
print("\n" + "="*60)
print("MERMAID EXPORT:")
print("="*60)
mermaid_result = cli.export_tree("mermaid")
print(mermaid_result)