#!/usr/bin/env python3
"""
Create a decision tree for DecisionTreeTool project completion workflow
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionTreeExporter

def create_project_completion_tree():
    """Create decision tree for project completion workflow"""
    tree = DecisionTree(
        name="DecisionTreeTool Project Completion",
        description="Workflow for completing DecisionTreeTool development and transitioning back to main project"
    )

    # Root: Check if witty comments are complete
    root_id = tree.add_node(
        question="Are witty comments complete in all Python files?",
        node_type="condition"
    )

    # Branch 1: Comments not complete
    add_comments_id = tree.add_node(
        question="Add witty comments to remaining files",
        node_type="action",
        action="Review and add engaging comments to all .py files with 30-something developer humor"
    )
    tree.add_child(root_id, "no", add_comments_id)

    # Branch 2: Comments complete - check tests
    tests_ok_id = tree.add_node(
        question="Are all features tested and working?",
        node_type="condition"
    )
    tree.add_child(root_id, "yes", tests_ok_id)

    # Test branch - fix issues
    fix_issues_id = tree.add_node(
        question="Fix failing tests and functionality",
        node_type="action",
        action="Debug and resolve any failing tests or broken features"
    )
    tree.add_child(tests_ok_id, "no", fix_issues_id)

    # Tests pass - check commit status
    commit_ready_id = tree.add_node(
        question="Is code committed to GitHub?",
        node_type="condition"
    )
    tree.add_child(tests_ok_id, "yes", commit_ready_id)

    # Commit branch
    commit_code_id = tree.add_node(
        question="Commit enhanced code to repository",
        node_type="action",
        action="git add . && git commit -m 'feat: Enhanced DecisionTreeTool with witty comments' && git push"
    )
    tree.add_child(commit_ready_id, "no", commit_code_id)

    # Already committed - check documentation
    docs_complete_id = tree.add_node(
        question="Is documentation complete and engaging?",
        node_type="condition"
    )
    tree.add_child(commit_ready_id, "yes", docs_complete_id)

    # Update docs
    update_docs_id = tree.add_node(
        question="Update README and FUNCTIONALITY.md",
        node_type="action",
        action="Ensure README and FUNCTIONALITY.md reflect all new features with engaging tone"
    )
    tree.add_child(docs_complete_id, "no", update_docs_id)

    # Docs complete - create project decision tree
    create_tree_id = tree.add_node(
        question="Should we create a decision tree for this project?",
        node_type="condition"
    )
    tree.add_child(docs_complete_id, "yes", create_tree_id)

    # Create the project tree
    save_tree_id = tree.add_node(
        question="Create and save DecisionTreeTool project completion tree",
        node_type="action",
        action="Document the project completion workflow as a decision tree for future reference"
    )
    tree.add_child(create_tree_id, "yes", save_tree_id)

    # Skip tree creation
    transition_id = tree.add_node(
        question="Ready to transition back to main project work?",
        node_type="condition"
    )
    tree.add_child(create_tree_id, "no", transition_id)

    # Also link save_tree to transition
    tree.add_child(save_tree_id, "completed", transition_id)

    # Transition actions
    update_context_id = tree.add_node(
        question="Update session context for main project transition",
        node_type="action",
        action="Update NEXT_CLAUDE_PROMPT with main project context and current status"
    )
    tree.add_child(transition_id, "yes", update_context_id)

    # Continue with DecisionTreeTool
    continue_dt_id = tree.add_node(
        question="Continue DecisionTreeTool development",
        node_type="action",
        action="Focus on additional DecisionTreeTool features or improvements"
    )
    tree.add_child(transition_id, "no", continue_dt_id)

    # Final step - switch to main project
    switch_project_id = tree.add_node(
        question="Switch context to main project work",
        node_type="action",
        action="cd /Volumes/workplace && focus on main project analysis and development"
    )
    tree.add_child(update_context_id, "completed", switch_project_id)

    return tree

if __name__ == "__main__":
    tree = create_project_completion_tree()

    # Save as JSON in project
    json_output = DecisionTreeExporter.to_json(tree, "decision_trees/DecisionTreeTool/project_completion.json")
    print(f"✅ Saved project completion tree to: decision_trees/DecisionTreeTool/project_completion.json")

    # Show ASCII visualization
    ascii_output = DecisionTreeExporter.to_ascii(tree)
    print("\n" + "="*60)
    print("PROJECT COMPLETION DECISION TREE")
    print("="*60)
    print(ascii_output)

    # Save ASCII version too
    with open("decision_trees/DecisionTreeTool/project_completion.txt", "w") as f:
        f.write(ascii_output)
    print(f"\n✅ ASCII version saved to: decision_trees/DecisionTreeTool/project_completion.txt")
