#!/usr/bin/env python3
"""
Display DecisionTreeTool project trees
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.DecisionTreeTool.decision_tree_tool import DecisionTreeCLI

print("🌳 DecisionTreeTool Project Trees")
print("=" * 50)

cli = DecisionTreeCLI()

# Show available project trees
print("📋 Available Trees in DecisionTreeTool Project:")
trees = cli.list_trees()
print(trees)
print()

# Display each tree
tree_names = ["development_workflow", "user_support_guide", "feature_planning"]

for tree_name in tree_names:
    print(f"🔍 {tree_name.replace('_', ' ').title()}")
    print("-" * 30)
    
    # Load and display
    result = cli.load_tree(tree_name, "DecisionTreeTool")
    if "Loaded" in result:
        ascii_output = cli.export_tree("ascii")
        # Extract just the tree part (not the file path)
        if "Exported to" in ascii_output:
            print(f"Tree saved, loading content from file...")
            # Read the actual tree content
            tree_path = f"decision_trees/DecisionTreeTool/{tree_name}.txt"
            if os.path.exists(tree_path):
                with open(tree_path, 'r') as f:
                    print(f.read())
        else:
            print(ascii_output)
    else:
        print(f"❌ {result}")
    
    print()

print("✨ These decision trees help guide DecisionTreeTool development!")
print()
print("💡 Usage:")
print("python3 manage_decision_tree.py load --name 'development_workflow'")
print("python3 manage_decision_tree.py export --format mermaid")