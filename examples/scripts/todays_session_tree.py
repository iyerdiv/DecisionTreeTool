#!/usr/bin/env python3
"""
Create a decision tree for today's work session
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionNode, DecisionTreeExporter

# Create today's session decision tree
tree = DecisionTree(
    name="Today's Work Session",
    description="Navigate through today's priorities and tasks"
)

# Root question
root = DecisionNode(
    id="urgent_check",
    question="Are there any urgent issues or deadlines today?",
    node_type="condition"
)
tree.nodes["urgent_check"] = root
tree.root_id = "urgent_check"

# Urgent path
handle_urgent = DecisionNode(
    id="handle_urgent",
    question="Address urgent items first",
    node_type="action",
    action="Focus on urgent tasks, delegate if possible, set timeline"
)
tree.nodes["handle_urgent"] = handle_urgent
root.children["yes"] = "handle_urgent"

# Check after urgent
check_energy = DecisionNode(
    id="check_energy",
    question="What's your energy level right now?",
    node_type="condition"
)
tree.nodes["check_energy"] = check_energy
root.children["no"] = "check_energy"
handle_urgent.children["done"] = "check_energy"

# High energy path
tackle_complex = DecisionNode(
    id="tackle_complex",
    question="Work on complex or creative tasks",
    node_type="action", 
    action="Take on challenging problems, coding, architecture, planning"
)
tree.nodes["tackle_complex"] = tackle_complex
check_energy.children["high"] = "tackle_complex"

# Medium energy path  
productive_work = DecisionNode(
    id="productive_work",
    question="Do routine but important work",
    node_type="action",
    action="Code reviews, documentation, testing, refactoring"
)
tree.nodes["productive_work"] = productive_work
check_energy.children["medium"] = "productive_work"

# Low energy path
light_tasks = DecisionNode(
    id="light_tasks", 
    question="Handle light administrative tasks",
    node_type="action",
    action="Emails, planning, organizing files, research, learning"
)
tree.nodes["light_tasks"] = light_tasks
check_energy.children["low"] = "light_tasks"

# End of work period check
wrap_up_check = DecisionNode(
    id="wrap_up_check",
    question="Is it near end of work time?",
    node_type="condition"
)
tree.nodes["wrap_up_check"] = wrap_up_check

# Connect all work paths to wrap up check
tackle_complex.children["completed"] = "wrap_up_check"
productive_work.children["completed"] = "wrap_up_check" 
light_tasks.children["completed"] = "wrap_up_check"

# Wrap up actions
wrap_up = DecisionNode(
    id="wrap_up",
    question="Wrap up and plan tomorrow",
    node_type="action",
    action="Save work, commit code, write notes, plan tomorrow's priorities"
)
tree.nodes["wrap_up"] = wrap_up
wrap_up_check.children["yes"] = "wrap_up"

# Continue working
continue_work = DecisionNode(
    id="continue_work", 
    question="Take a short break then continue working",
    node_type="action",
    action="5-10 minute break, hydrate, then pick up where you left off"
)
tree.nodes["continue_work"] = continue_work
wrap_up_check.children["no"] = "continue_work"

print("🌳 Today's Work Session Decision Tree")
print("=" * 50)

# Show ASCII visualization
ascii_output = DecisionTreeExporter.to_ascii(tree)
print(ascii_output)

# Export to files
DecisionTreeExporter.to_json(tree, "todays_session.json")
DecisionTreeExporter.to_mermaid(tree, "todays_session.mmd") 

print(f"\n📄 Saved to:")
print(f"  - todays_session.json")  
print(f"  - todays_session.mmd")
print(f"\n💡 Use this tree to navigate your work day based on energy and priorities!")