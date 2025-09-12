# DecisionTreeTool

A robust decision tree framework for systematic problem-solving, root cause analysis, and AI-assisted debugging. Features confidence scoring, fallback logic, and MCP integration for use with AI assistants.

## Structure

```
DecisionTreeTool/
├── brazil.ion          # Brazil package configuration
├── Config             # Brazil build configuration
├── setup.py           # Python package setup
├── src/               # Source code
│   └── DecisionTreeTool/ # Main package
├── test/              # Unit tests
├── bin/               # Executable scripts
├── lib/               # Libraries
├── docs/              # Documentation
└── build/             # Build artifacts (generated)
```

## Building

```bash
brazil-build
```

## Testing

```bash
brazil-build test
```

## Development Setup

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install in development mode
pip install -e .
pip install -e .[dev]
```

## Features

### 🎯 Core Capabilities
- **Robust Decision Trees**: Navigate complex decision paths with fallback logic
- **Confidence Scoring**: Track decision quality through the entire path
- **Context Validation**: Ensure required data exists before proceeding
- **AI Assistant Integration**: Works with Claude (via MCP) and Amazon Q (via CLI)
- **Multiple Export Formats**: JSON, YAML, Mermaid diagrams, Graphviz DOT
- **YAML/JSON Support**: Define trees in human-readable formats

### 🤖 AI Assistant Integration
- **Claude Desktop**: Full MCP integration for natural language interaction
- **Amazon Q**: CLI-based integration for command execution
- **Extensible**: Easy to integrate with other AI tools

### 🛡️ Robustness Features
- **Fallback Logic**: Never hit dead ends - always have a default path
- **Minimum Confidence Thresholds**: Prevent low-quality decisions
- **Context Requirements**: Validate required data before each step
- **Weight-based Importance**: Prioritize critical decision nodes

## Usage Examples

### Basic Command Line Usage

```bash
# Run a decision tree
python -m DecisionTreeTool.decision_tree_tool --tree my_tree.yaml

# With initial context
python -m DecisionTreeTool.decision_tree_tool --tree my_tree.yaml --context '{"alert": "Container2", "severity": "high"}'

# Interactive mode
python -m DecisionTreeTool.decision_tree_tool --tree my_tree.yaml --interactive
```

### Python API Usage

```python
from DecisionTreeTool.decision_tree_robust import DecisionTree, DecisionNode

# Create a simple decision tree
tree = DecisionTree(name="troubleshooting")

# Add nodes with fallback logic
tree.add_node(DecisionNode(
    id="start",
    question="Is the system responding?",
    children={
        "yes": "check_performance",
        "no": "check_connection"
    },
    fallback_node="escalate",
    min_confidence=0.7
))

# Execute with context
context = {"system": "production", "alert_type": "timeout"}
result = tree.execute(context=context)
print(f"Decision path: {result.path}")
print(f"Confidence: {result.confidence}")
print(f"Action: {result.action}")
```

### Creating Decision Trees in YAML

```yaml
name: incident_response
description: Automated incident response decision tree
metadata:
  version: "1.0"
  author: "SRE Team"

nodes:
  start:
    question: "What is the alert severity?"
    children:
      critical: "immediate_response"
      high: "check_impact"
      medium: "schedule_review"
      low: "log_and_monitor"
    fallback_node: "check_impact"
    min_confidence: 0.8

  check_impact:
    question: "Are customers impacted?"
    required_context: ["customer_metrics", "error_rate"]
    children:
      yes: "page_oncall"
      no: "automated_remediation"
      unknown: "gather_metrics"
    weight: 2.0  # Double importance

  immediate_response:
    action: "Page on-call engineer and create incident channel"
    confidence_adjustment: -0.1  # Reduce confidence for critical paths
```

### MCP Server Usage

```bash
# Start the MCP server for AI assistant integration
python -m DecisionTreeTool.decision_tree_mcp

# The server exposes tools for:
# - Loading decision trees
# - Executing decisions with context
# - Getting recommendations
# - Tracking decision history
```

### Advanced Features

```python
# Context validation
node = DecisionNode(
    id="verify_data",
    question="Is the data valid?",
    required_context=["data_source", "timestamp"],
    context_validators={
        "timestamp": "lambda x: x > time.time() - 3600"  # Less than 1 hour old
    }
)

# Confidence scoring
result = tree.execute(context, track_confidence=True)
if result.confidence < 0.5:
    print("Low confidence decision - manual review recommended")

# Path history
for step in result.path_history:
    print(f"{step.node_id}: {step.answer} (confidence: {step.confidence})")
```

## Use Cases

- **Incident Response**: Systematic troubleshooting with fallback escalation
- **Root Cause Analysis**: Navigate complex debugging scenarios
- **Automated Remediation**: Execute actions based on conditions
- **Knowledge Capture**: Document expert decision-making processes
- **AI Assistant Integration**: Provide structured reasoning for LLMs

## Testing

```bash
# Run all tests
brazil-build test

# Run specific test
python -m pytest test/test_decision_tree.py

# With coverage
python -m pytest --cov=DecisionTreeTool test/
```
