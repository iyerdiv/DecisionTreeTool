#!/usr/bin/env python3
"""
Create a connected decision tree for today's work session with proper flow
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionNode, DecisionTreeExporter

# Create today's session decision tree with connections
tree = DecisionTree(
    name="Connected Work Session Flow",
    description="A cyclical decision tree that flows naturally through work priorities"
)

# Root: Start of work session
start_session = DecisionNode(
    id="start_session",
    question="Starting work session - any urgent items?",
    node_type="condition"
)
tree.nodes["start_session"] = start_session
tree.root_id = "start_session"

# Handle urgent items
urgent_work = DecisionNode(
    id="urgent_work",
    question="Handle urgent items",
    node_type="action",
    action="Focus on deadlines, critical issues, blockers for others"
)
tree.nodes["urgent_work"] = urgent_work
start_session.children["yes"] = "urgent_work"

# Energy check (central hub)
energy_check = DecisionNode(
    id="energy_check",
    question="What's your current energy/focus level?",
    node_type="condition"
)
tree.nodes["energy_check"] = energy_check
start_session.children["no"] = "energy_check"
urgent_work.children["completed"] = "energy_check"

# High energy work
deep_work = DecisionNode(
    id="deep_work",
    question="Deep work session",
    node_type="action",
    action="Complex coding, architecture, problem-solving, creative work"
)
tree.nodes["deep_work"] = deep_work
energy_check.children["high"] = "deep_work"

# Medium energy work
routine_work = DecisionNode(
    id="routine_work", 
    question="Productive routine work",
    node_type="action",
    action="Code reviews, testing, documentation, refactoring"
)
tree.nodes["routine_work"] = routine_work
energy_check.children["medium"] = "routine_work"

# Low energy work
admin_work = DecisionNode(
    id="admin_work",
    question="Light administrative work", 
    node_type="action",
    action="Emails, planning, organizing, learning, research"
)
tree.nodes["admin_work"] = admin_work
energy_check.children["low"] = "admin_work"

# Break and reassess (central connection point)
break_check = DecisionNode(
    id="break_check",
    question="Take a break and reassess?",
    node_type="condition"
)
tree.nodes["break_check"] = break_check

# Connect all work types to break check
deep_work.children["session_done"] = "break_check"
routine_work.children["session_done"] = "break_check" 
admin_work.children["session_done"] = "break_check"

# Take break
take_break = DecisionNode(
    id="take_break",
    question="Take a break",
    node_type="action",
    action="Step away, hydrate, stretch, clear your mind"
)
tree.nodes["take_break"] = take_break
break_check.children["yes"] = "take_break"

# Time check
time_check = DecisionNode(
    id="time_check",
    question="Is it near end of work day?",
    node_type="condition"
)
tree.nodes["time_check"] = time_check
break_check.children["no"] = "time_check"
take_break.children["refreshed"] = "time_check"

# Continue working - loops back to energy check
time_check.children["no"] = "energy_check"

# End of day wrap up
wrap_up = DecisionNode(
    id="wrap_up",
    question="Wrap up work day",
    node_type="action", 
    action="Save progress, commit code, write notes, plan tomorrow"
)
tree.nodes["wrap_up"] = wrap_up
time_check.children["yes"] = "wrap_up"

print("🌳 Connected Work Session Flow")
print("=" * 50)
print("Notice how this tree flows in cycles:")
print("• Start → Urgent (if any) → Energy Check → Work → Break Check → Time Check")
print("• Time Check loops back to Energy Check if continuing work")
print("• Multiple paths lead back to central decision points")
print("=" * 50)

# Show ASCII visualization
ascii_output = DecisionTreeExporter.to_ascii(tree)
print(ascii_output)

# Export to files
DecisionTreeExporter.to_json(tree, "connected_session.json")
DecisionTreeExporter.to_mermaid(tree, "connected_session.mmd") 

print(f"\n📄 Saved to:")
print(f"  - connected_session.json")  
print(f"  - connected_session.mmd")
print(f"\n💡 This creates a natural work flow that cycles through the day!")