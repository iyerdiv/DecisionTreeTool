# Amazon Q Integration Guide

This tool can be used with Amazon Q through its CLI interface.

## Setup for Amazon Q

1. **Clone the repository**:
   ```bash
   git clone https://github.com/dsiyer/DecisionTreeTool.git
   cd DecisionTreeTool
   ```

2. **Install dependencies**:
   ```bash
   pip3 install -r requirements.txt
   ```

3. **Make the tool accessible to Q**:
   ```bash
   # Add to your shell profile (.bashrc, .zshrc, etc.)
   alias decision-tree='python3 /path/to/DecisionTreeTool/src/DecisionTreeTool/decision_tree_tool.py'
   ```

## Using with Amazon Q

### Create a decision tree:
```bash
Q> Run: decision-tree create --name "Debug Tree" --description "For debugging issues"
```

### Add nodes:
```bash
Q> Run: decision-tree add --question "Is the service running?" --type condition
Q> Run: decision-tree add --question "Check logs" --type action --action "tail -f /var/log/app.log"
```

### Link nodes:
```bash
Q> Run: decision-tree link --parent node1 --child node2 --answer "yes"
```

### Export tree:
```bash
Q> Run: decision-tree export --format json --file my_tree.json
```

### List all trees:
```bash
Q> Run: decision-tree list
```

## Q-Specific Features

- **Plain text output**: All commands return simple text that Q can easily parse
- **File-based persistence**: Trees can be saved/loaded via JSON export/import
- **Shell-friendly**: Can be integrated into shell scripts and automation

## Example Q Conversations

### Basic Troubleshooting Tree
```
User: Help me create a decision tree for troubleshooting network issues

Q: I'll help you create a decision tree for network troubleshooting. Let me start by creating the tree structure.

[Runs: decision-tree create --name "Network Troubleshooting" --description "Debug network connectivity issues"]

Now I'll add the diagnostic steps:

[Runs: decision-tree add --question "Can you ping 8.8.8.8?" --type condition]
[Runs: decision-tree add --question "DNS issue - check /etc/resolv.conf" --type action]
[Runs: decision-tree add --question "Network interface down - check with ifconfig" --type action]

Let me link these nodes based on the diagnostic flow:

[Runs: decision-tree link --parent root --child node2 --answer "yes"]
[Runs: decision-tree link --parent root --child node3 --answer "no"]
```

### Good Prompts for Q
```
"Create a decision tree for server troubleshooting with these steps: check if running, check CPU, restart if needed"

"Add a troubleshooting step that checks disk space and warns if above 90%"  

"Show me the tree in ASCII format so I can see the flow"

"Export this as JSON so I can save it to our runbook"

"Walk through the tree assuming the server is down and won't start"
```

### What Q Can Do
- Execute CLI commands to build trees step by step
- Run diagnostic commands as part of actions
- Export trees to files for documentation  
- Integrate with shell scripts and automation
- Test decision paths with different scenarios

## Tips for Q Users

1. Use descriptive node IDs when possible
2. Export trees to JSON for version control
3. Create template trees for common troubleshooting scenarios
4. Combine with Q's ability to run shell commands for powerful automation
