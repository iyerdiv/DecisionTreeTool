#!/usr/bin/env python3
"""
Create sample decision tree and export in multiple formats
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.DecisionTreeTool.decision_tree_tool import DecisionTree, DecisionNode, DecisionTreeExporter

# Create a sample troubleshooting decision tree
tree = DecisionTree(
    name="System Troubleshooting Guide",
    description="Systematic approach to diagnosing system issues"
)

# Add nodes - building a troubleshooting flow
root = DecisionNode(
    id="check_system",
    question="Is the system responding?",
    node_type="condition"
)
tree.nodes["check_system"] = root
tree.root_id = "check_system"

# Branch 1: System is responding
perf_check = DecisionNode(
    id="check_performance",
    question="Is performance degraded?",
    node_type="condition"
)
tree.nodes["check_performance"] = perf_check
root.children["yes"] = "check_performance"

# Performance issues branch
memory_check = DecisionNode(
    id="check_memory",
    question="Is memory usage > 80%?",
    node_type="condition"
)
tree.nodes["check_memory"] = memory_check
perf_check.children["yes"] = "check_memory"

restart_service = DecisionNode(
    id="restart_service",
    question="Restart service",
    node_type="action",
    action="sudo systemctl restart app-service"
)
tree.nodes["restart_service"] = restart_service
memory_check.children["yes"] = "restart_service"

check_cpu = DecisionNode(
    id="check_cpu",
    question="Is CPU usage > 90%?",
    node_type="condition"
)
tree.nodes["check_cpu"] = check_cpu
memory_check.children["no"] = "check_cpu"

optimize_queries = DecisionNode(
    id="optimize_queries",
    question="Optimize database queries",
    node_type="action",
    action="Run query optimization script"
)
tree.nodes["optimize_queries"] = optimize_queries
check_cpu.children["yes"] = "optimize_queries"

monitor = DecisionNode(
    id="monitor",
    question="Monitor system",
    node_type="action",
    action="Enable detailed monitoring for 1 hour"
)
tree.nodes["monitor"] = monitor
check_cpu.children["no"] = "monitor"
perf_check.children["no"] = "monitor"

# Branch 2: System not responding
check_network = DecisionNode(
    id="check_network",
    question="Can you ping the server?",
    node_type="condition"
)
tree.nodes["check_network"] = check_network
root.children["no"] = "check_network"

check_service = DecisionNode(
    id="check_service",
    question="Is the service running?",
    node_type="condition"
)
tree.nodes["check_service"] = check_service
check_network.children["yes"] = "check_service"

start_service = DecisionNode(
    id="start_service",
    question="Start the service",
    node_type="action",
    action="sudo systemctl start app-service"
)
tree.nodes["start_service"] = start_service
check_service.children["no"] = "start_service"

check_logs = DecisionNode(
    id="check_logs",
    question="Check error logs",
    node_type="action",
    action="tail -n 100 /var/log/app/error.log"
)
tree.nodes["check_logs"] = check_logs
check_service.children["yes"] = "check_logs"

network_team = DecisionNode(
    id="network_team",
    question="Escalate to network team",
    node_type="action",
    action="Create ticket for network team with diagnostics"
)
tree.nodes["network_team"] = network_team
check_network.children["no"] = "network_team"

# Export in different formats
print("=" * 60)
print("SAMPLE DECISION TREE EXPORTS")
print("=" * 60)

# 1. ASCII Format (Terminal Display)
print("\n1. ASCII Tree Format:")
print("-" * 40)
ascii_output = DecisionTreeExporter.to_ascii(tree)
print(ascii_output)

# 2. Mermaid Format (Can be rendered in markdown)
print("\n\n2. Mermaid Diagram Format:")
print("-" * 40)
mermaid_output = DecisionTreeExporter.to_mermaid(tree)
print(mermaid_output)

# Save outputs to files
output_dir = os.path.dirname(os.path.abspath(__file__))

# Save ASCII
with open(os.path.join(output_dir, "sample_tree.txt"), "w") as f:
    f.write(ascii_output)

# Save Mermaid
with open(os.path.join(output_dir, "sample_tree.mmd"), "w") as f:
    f.write(mermaid_output)

# Save JSON
json_output = DecisionTreeExporter.to_json(tree, os.path.join(output_dir, "sample_tree.json"))

# Save DOT
dot_output = DecisionTreeExporter.to_dot(tree, os.path.join(output_dir, "sample_tree.dot"))

print("\n\nFiles saved:")
print(f"  - sample_tree.txt (ASCII)")
print(f"  - sample_tree.mmd (Mermaid)")
print(f"  - sample_tree.json (JSON)")
print(f"  - sample_tree.dot (Graphviz)")
print("\nYou can render the Mermaid diagram at: https://mermaid.live/")
print("You can render the DOT file at: https://dreampuf.github.io/GraphvizOnline/")