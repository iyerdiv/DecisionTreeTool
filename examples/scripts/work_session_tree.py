#!/usr/bin/env python3
"""
Create a comprehensive work session decision tree - The Ultimate Productivity Navigator 🧭
Combines the best of both worlds: urgency handling AND cyclical flow for maximum efficiency
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionNode, DecisionTreeExporter

# Create the ultimate work session decision tree (because productivity is an art form)
tree = DecisionTree(
    name="Ultimate Work Session Flow",
    description="A cyclical decision tree that flows naturally through work priorities with proper urgency handling"
)

# Root: Start of work session (the daily ritual begins)
start_session = DecisionNode(
    id="start_session",
    question="Starting work session - any urgent items demanding immediate attention?",
    node_type="condition"
)
tree.nodes["start_session"] = start_session
tree.root_id = "start_session"

# Handle urgent items (because fires need extinguishing)
urgent_work = DecisionNode(
    id="urgent_work",
    question="Handle urgent items with laser focus",
    node_type="action",
    action="Focus on deadlines, critical issues, blockers for others - be the hero they need"
)
tree.nodes["urgent_work"] = urgent_work
start_session.children["yes"] = "urgent_work"

# Energy check - the central hub of productivity (where the magic happens)
energy_check = DecisionNode(
    id="energy_check",
    question="What's your current energy/focus level? (Be honest, we won't judge)",
    node_type="condition"
)
tree.nodes["energy_check"] = energy_check
start_session.children["no"] = "energy_check"
urgent_work.children["completed"] = "energy_check"  # After urgent work, reassess energy

# High energy work (when you're feeling like a coding superhero)
deep_work = DecisionNode(
    id="deep_work",
    question="Deep work session - time to channel your inner genius",
    node_type="action",
    action="Complex coding, architecture design, problem-solving, creative work - the heavy lifting"
)
tree.nodes["deep_work"] = deep_work
energy_check.children["high"] = "deep_work"

# Medium energy work (the productive middle ground)
routine_work = DecisionNode(
    id="routine_work",
    question="Productive routine work - steady progress mode",
    node_type="action",
    action="Code reviews, testing, documentation, refactoring - the bread and butter"
)
tree.nodes["routine_work"] = routine_work
energy_check.children["medium"] = "routine_work"

# Low energy work (when your brain is running on fumes)
admin_work = DecisionNode(
    id="admin_work",
    question="Light administrative work - cruise control engaged",
    node_type="action",
    action="Emails, planning, organizing, learning, research - the gentle stuff"
)
tree.nodes["admin_work"] = admin_work
energy_check.children["low"] = "admin_work"

# Break and reassess (the productivity pit stop)
break_check = DecisionNode(
    id="break_check",
    question="Take a break and reassess? (Your brain will thank you)",
    node_type="condition"
)
tree.nodes["break_check"] = break_check

# Connect all work types to break check (because all roads lead to rest)
deep_work.children["session_done"] = "break_check"
routine_work.children["session_done"] = "break_check"
admin_work.children["session_done"] = "break_check"

# Take break (the sacred pause)
take_break = DecisionNode(
    id="take_break",
    question="Take a well-deserved break",
    node_type="action",
    action="Step away, hydrate, stretch, clear your mind - recharge those mental batteries"
)
tree.nodes["take_break"] = take_break
break_check.children["yes"] = "take_break"

# Time check (the reality checkpoint)
time_check = DecisionNode(
    id="time_check",
    question="Is it near end of work day? (Time flies when you're productive)",
    node_type="condition"
)
tree.nodes["time_check"] = time_check
break_check.children["no"] = "time_check"
take_break.children["refreshed"] = "time_check"

# Continue working - loops back to energy check (the productivity cycle continues)
time_check.children["no"] = "energy_check"

# End of day wrap up (the grand finale)
wrap_up = DecisionNode(
    id="wrap_up",
    question="Wrap up work day like a pro",
    node_type="action",
    action="Save progress, commit code, write notes, plan tomorrow - set future you up for success"
)
tree.nodes["wrap_up"] = wrap_up
time_check.children["yes"] = "wrap_up"

print("🌳 Ultimate Work Session Flow - The Productivity Masterpiece")
print("=" * 60)
print("🎯 This tree combines the best features:")
print("  • Urgent item handling (because fires happen)")
print("  • Energy-based task matching (work with your brain, not against it)")
print("  • Natural cyclical flow (like a productivity perpetual motion machine)")
print("  • Break reminders (because burnout is not a badge of honor)")
print("  • Proper day wrap-up (tomorrow you will thank today you)")
print("=" * 60)
print("🔄 Flow Pattern:")
print("  Start → Urgent (if any) → Energy Check → Work → Break Check → Time Check")
print("  Time Check loops back to Energy Check if continuing work")
print("  Multiple paths lead back to central decision points")
print("=" * 60)

# Show ASCII visualization (the terminal art gallery)
ascii_output = DecisionTreeExporter.to_ascii(tree)
print(ascii_output)

# Export to files (because sharing is caring)
DecisionTreeExporter.to_json(tree, "ultimate_work_session.json")
DecisionTreeExporter.to_mermaid(tree, "ultimate_work_session.mmd")
DecisionTreeExporter.to_yaml(tree, "ultimate_work_session.yaml")

print(f"\n📄 Exported to multiple formats:")
print(f"  - ultimate_work_session.json (for the API lovers)")
print(f"  - ultimate_work_session.mmd (for the visual thinkers)")
print(f"  - ultimate_work_session.yaml (for the human-readable crowd)")
print(f"\n💡 This creates the ultimate work flow that adapts to your energy and cycles through the day!")
print(f"🚀 Use this tree to maximize productivity while maintaining sanity!")
