# Claude Integration Guide

This tool is designed to work with Claude through MCP (Model Context Protocol).

## Setup for Claude Desktop

1. **Install the tool**:
   ```bash
   git clone https://github.com/dsiyer/DecisionTreeTool.git
   cd DecisionTreeTool
   pip install -e .
   ```

2. **Add to Claude's MCP configuration**:
   
   Edit your `mcp-servers.json` file (usually in `~/.config/claude/` on macOS/Linux):
   
   ```json
   {
     "decision-tree": {
       "command": "python",
       "args": ["-m", "DecisionTreeTool.decision_tree_mcp"],
       "workingDirectory": "/path/to/DecisionTreeTool"
     }
   }
   ```

3. **Restart Claude Desktop**

## Using with Claude

Once configured, you can ask Claude to:

- "Create a decision tree for debugging network issues"
- "Add a node asking if the server is responding"  
- "Link the nodes based on yes/no answers"
- "Traverse the tree with these conditions..."
- "Export the tree as a Mermaid diagram"

### Example Claude Prompts

**Good prompts for Claude:**
```
"Create a decision tree to troubleshoot website slowness. Start with checking if the site loads, then branch into database vs server issues."

"Add these troubleshooting steps to the tree:
- Check server CPU usage  
- If high, restart the service
- If normal, check database connections"

"Show me the tree as an ASCII diagram so I can see the flow."

"Export this tree as a Mermaid diagram for our documentation."

"Walk me through this decision tree with these conditions: server is responding but slow, CPU is normal, database connections are timing out."
```

**What Claude can do:**
- Build complete decision trees from your description
- Add logical branching based on conditions  
- Create visual representations instantly
- Help you think through all possible paths
- Walk through scenarios to test your logic

## Available Actions

- `create` - Create a new decision tree
- `add_node` - Add a decision node
- `link` - Connect nodes with answers
- `traverse` - Navigate through the tree
- `export` - Export to various formats
- `visualize` - Generate visual representations

## Example Usage

```
User: Create a decision tree for troubleshooting a slow website

Claude: I'll create a decision tree for troubleshooting a slow website.

[Uses decision_tree tool with action: "create"]

Now I'll add the diagnostic nodes...

[Uses decision_tree tool with action: "add_node" multiple times]

Let me connect these nodes based on the logical flow...

[Uses decision_tree tool with action: "link" to connect nodes]
```

## Standalone CLI Usage

The tool also works as a standalone CLI:

```bash
python -m DecisionTreeTool.decision_tree_tool create "My Tree"
python -m DecisionTreeTool.decision_tree_tool add-node "Is it working?"
python -m DecisionTreeTool.decision_tree_tool export json output.json
```