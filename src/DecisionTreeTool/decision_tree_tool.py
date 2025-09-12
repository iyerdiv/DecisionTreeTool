#!/usr/bin/env python3
"""
Universal Decision Tree Tool
Usable by both Claude Code and Amazon Q

Features:
- Create, modify, and traverse decision trees
- Export to multiple formats (JSON, YAML, Mermaid, DOT)
- CLI interface for Q integration
- MCP tool integration for Claude
- Visual representation support
- Rule-based and ML-based decision paths
"""

import json
import yaml
import sys
import argparse
from typing import Dict, Any, List, Optional, Union, Tuple
from pathlib import Path
from dataclasses import dataclass, asdict
from datetime import datetime
import uuid


@dataclass
class DecisionNode:
    """Represents a node in the decision tree"""
    id: str
    question: str
    node_type: str = "condition"  # condition, action, data
    children: Dict[str, str] = None  # answer -> child_node_id
    action: Optional[str] = None
    confidence: Optional[float] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.children is None:
            self.children = {}
        if self.metadata is None:
            self.metadata = {}


class DecisionTree:
    """Core decision tree implementation"""
    
    def __init__(self, name: str = "Decision Tree", description: str = ""):
        self.name = name
        self.description = description
        self.nodes: Dict[str, DecisionNode] = {}
        self.root_id: Optional[str] = None
        self.created_at = datetime.now().isoformat()
        self.updated_at = self.created_at
        
    def add_node(self, question: str, node_type: str = "condition", 
                 action: str = None, confidence: float = None, 
                 metadata: Dict = None) -> str:
        """Add a node to the tree"""
        node_id = str(uuid.uuid4())[:8]
        node = DecisionNode(
            id=node_id,
            question=question,
            node_type=node_type,
            action=action,
            confidence=confidence,
            metadata=metadata or {}
        )
        self.nodes[node_id] = node
        
        # Set as root if it's the first node
        if self.root_id is None:
            self.root_id = node_id
            
        self._update_timestamp()
        return node_id
    
    def add_child(self, parent_id: str, answer: str, child_id: str):
        """Add a child relationship"""
        if parent_id in self.nodes:
            self.nodes[parent_id].children[answer] = child_id
            self._update_timestamp()
    
    def create_path(self, path_data: List[Dict[str, Any]]) -> str:
        """Create a complete decision path from structured data"""
        node_ids = []
        
        for i, node_data in enumerate(path_data):
            node_id = self.add_node(
                question=node_data.get("question", ""),
                node_type=node_data.get("type", "condition"),
                action=node_data.get("action"),
                confidence=node_data.get("confidence"),
                metadata=node_data.get("metadata", {})
            )
            node_ids.append(node_id)
            
            # Link to previous node
            if i > 0:
                answer = node_data.get("from_answer", "yes")
                self.add_child(node_ids[i-1], answer, node_id)
        
        return node_ids[0] if node_ids else None
    
    def traverse(self, answers: Dict[str, str]) -> Tuple[str, List[str]]:
        """Traverse the tree with given answers"""
        if not self.root_id:
            return None, []
        
        current_id = self.root_id
        path = []
        
        while current_id:
            current_node = self.nodes[current_id]
            path.append(f"Node: {current_node.question}")
            
            if current_node.node_type == "action":
                path.append(f"Action: {current_node.action}")
                return current_node.action, path
            
            # Find next node based on answer
            next_id = None
            for answer, child_id in current_node.children.items():
                if answer in answers and answers[answer]:
                    next_id = child_id
                    path.append(f"Answer: {answer}")
                    break
            
            if not next_id:
                # No matching path found
                path.append("No matching path found")
                return None, path
            
            current_id = next_id
        
        return None, path
    
    def get_all_paths(self) -> List[List[str]]:
        """Get all possible paths through the tree"""
        if not self.root_id:
            return []
        
        all_paths = []
        
        def traverse_all(node_id, current_path):
            node = self.nodes[node_id]
            current_path.append(node.question)
            
            if node.node_type == "action":
                current_path.append(f"→ {node.action}")
                all_paths.append(current_path.copy())
            else:
                for answer, child_id in node.children.items():
                    child_path = current_path + [f"[{answer}]"]
                    traverse_all(child_id, child_path)
            
            current_path.pop()
        
        traverse_all(self.root_id, [])
        return all_paths
    
    def to_dict(self) -> Dict[str, Any]:
        """Export tree to dictionary"""
        return {
            "name": self.name,
            "description": self.description,
            "root_id": self.root_id,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "nodes": {
                node_id: asdict(node) for node_id, node in self.nodes.items()
            }
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'DecisionTree':
        """Import tree from dictionary"""
        tree = cls(data.get("name", ""), data.get("description", ""))
        tree.root_id = data.get("root_id")
        tree.created_at = data.get("created_at", datetime.now().isoformat())
        tree.updated_at = data.get("updated_at", datetime.now().isoformat())
        
        for node_id, node_data in data.get("nodes", {}).items():
            tree.nodes[node_id] = DecisionNode(**node_data)
        
        return tree
    
    def _update_timestamp(self):
        """Update the last modified timestamp"""
        self.updated_at = datetime.now().isoformat()


class DecisionTreeExporter:
    """Export decision trees to various formats"""
    
    @staticmethod
    def to_json(tree: DecisionTree, filepath: str = None) -> str:
        """Export to JSON format"""
        json_data = json.dumps(tree.to_dict(), indent=2)
        if filepath:
            Path(filepath).write_text(json_data)
        return json_data
    
    @staticmethod
    def to_yaml(tree: DecisionTree, filepath: str = None) -> str:
        """Export to YAML format"""
        yaml_data = yaml.dump(tree.to_dict(), default_flow_style=False, indent=2)
        if filepath:
            Path(filepath).write_text(yaml_data)
        return yaml_data
    
    @staticmethod
    def to_mermaid(tree: DecisionTree, filepath: str = None) -> str:
        """Export to Mermaid diagram format"""
        if not tree.root_id:
            return "graph TD\n    A[Empty Tree]"
        
        mermaid = ["graph TD"]
        
        def clean_text(text: str) -> str:
            """Clean text for Mermaid compatibility"""
            return text.replace('"', "'").replace('\n', ' ').strip()
        
        # Generate nodes and connections
        for node_id, node in tree.nodes.items():
            clean_question = clean_text(node.question)
            
            if node.node_type == "action":
                mermaid.append(f'    {node_id}["{clean_question}"]')
                mermaid.append(f'    {node_id} --> {node_id}_action["{clean_text(node.action or "")}"]')
                mermaid.append(f'    {node_id}_action:::actionClass')
            else:
                mermaid.append(f'    {node_id}["{clean_question}"]')
            
            # Add connections to children
            for answer, child_id in node.children.items():
                clean_answer = clean_text(answer)
                mermaid.append(f'    {node_id} -->|{clean_answer}| {child_id}')
        
        # Add styling
        mermaid.extend([
            "    classDef actionClass fill:#90EE90,stroke:#006400,stroke-width:2px",
            "    classDef conditionClass fill:#87CEEB,stroke:#000080,stroke-width:2px"
        ])
        
        result = '\n'.join(mermaid)
        if filepath:
            Path(filepath).write_text(result)
        return result
    
    @staticmethod
    def to_dot(tree: DecisionTree, filepath: str = None) -> str:
        """Export to DOT format for Graphviz"""
        if not tree.root_id:
            return 'digraph DecisionTree {\n    empty [label="Empty Tree"]\n}'
        
        dot_lines = [
            'digraph DecisionTree {',
            '    rankdir=TD;',
            '    node [shape=box, style=rounded];'
        ]
        
        # Generate nodes
        for node_id, node in tree.nodes.items():
            label = node.question.replace('"', '\\"')
            if node.node_type == "action":
                dot_lines.append(f'    {node_id} [label="{label}\\n→ {node.action or ""}", fillcolor=lightgreen, style="rounded,filled"];')
            else:
                dot_lines.append(f'    {node_id} [label="{label}", fillcolor=lightblue, style="rounded,filled"];')
        
        # Generate edges
        for node_id, node in tree.nodes.items():
            for answer, child_id in node.children.items():
                edge_label = answer.replace('"', '\\"')
                dot_lines.append(f'    {node_id} -> {child_id} [label="{edge_label}"];')
        
        dot_lines.append('}')
        
        result = '\n'.join(dot_lines)
        if filepath:
            Path(filepath).write_text(result)
        return result
    
    @staticmethod
    def to_ascii(tree: DecisionTree) -> str:
        """Export to ASCII art tree for terminal display (cycle-aware)"""
        if not tree.root_id:
            return "Empty Tree"
        
        lines = []
        visited_in_path = set()  # Track nodes in current path to detect cycles
        node_first_occurrence = {}  # Track where we first drew each node
        
        def draw_node(node_id: str, prefix: str = "", is_last: bool = True, 
                     parent_answer: str = "", depth: int = 0) -> None:
            """Recursively draw node and its children with cycle detection"""
            if node_id not in tree.nodes:
                return
            
            # Check for cycles
            if node_id in visited_in_path:
                # This is a cycle - show a reference instead of recursing
                connector = "└── " if is_last else "├── "
                answer_label = f"[{parent_answer}] " if parent_answer else ""
                
                # Try to find where we first showed this node
                if node_id in node_first_occurrence:
                    target_description = node_first_occurrence[node_id]
                    cycle_text = f"{answer_label}🔄 → loops back to: {target_description}"
                else:
                    node_question = tree.nodes[node_id].question[:50] + ("..." if len(tree.nodes[node_id].question) > 50 else "")
                    cycle_text = f"{answer_label}🔄 → cycles back to: {node_question}"
                
                lines.append(f"{prefix}{connector}{cycle_text}")
                return
            
            # Prevent infinite recursion with depth limit
            if depth > 20:
                connector = "└── " if is_last else "├── "
                answer_label = f"[{parent_answer}] " if parent_answer else ""
                lines.append(f"{prefix}{connector}{answer_label}⚠️  → (max depth reached)")
                return
            
            # Mark this node as visited in current path
            visited_in_path.add(node_id)
            
            node = tree.nodes[node_id]
            
            # Create connector
            connector = "└── " if is_last else "├── "
            
            # Add answer label if this is not root
            answer_label = f"[{parent_answer}] " if parent_answer else ""
            
            # Format node text
            if node.node_type == "action":
                node_text = f"{answer_label}{node.question} → {node.action or 'No action'}"
            else:
                node_text = f"{answer_label}{node.question}"
            
            # Remember this node's first occurrence for cycle references
            if node_id not in node_first_occurrence:
                node_first_occurrence[node_id] = node.question[:30] + ("..." if len(node.question) > 30 else "")
            
            # Add the line
            lines.append(f"{prefix}{connector}{node_text}")
            
            # Prepare prefix for children
            extension = "    " if is_last else "│   "
            new_prefix = prefix + extension
            
            # Draw children
            children_items = list(node.children.items())
            for i, (answer, child_id) in enumerate(children_items):
                is_last_child = (i == len(children_items) - 1)
                draw_node(child_id, new_prefix, is_last_child, answer, depth + 1)
            
            # Remove from visited path when we're done with this branch
            visited_in_path.remove(node_id)
        
        # Start from root
        lines.append(f"🌳 {tree.name}")
        if tree.description:
            lines.append(f"   {tree.description}")
        lines.append("")
        
        # Draw the tree starting from root
        root_node = tree.nodes[tree.root_id]
        lines.append(f"Root: {root_node.question}")
        
        # Remember root for cycle detection
        node_first_occurrence[tree.root_id] = root_node.question[:30] + ("..." if len(root_node.question) > 30 else "")
        
        children_items = list(root_node.children.items())
        for i, (answer, child_id) in enumerate(children_items):
            is_last_child = (i == len(children_items) - 1)
            draw_node(child_id, "", is_last_child, answer, 0)
        
        # Add legend if cycles were detected
        if any("🔄" in line for line in lines):
            lines.append("")
            lines.append("Legend: 🔄 = cycle/loop back to earlier node")
        
        return "\n".join(lines)


class DecisionTreeCLI:
    """Command line interface for Q integration"""
    
    def __init__(self):
        self.trees: Dict[str, DecisionTree] = {}
        self.current_tree: Optional[str] = None
    
    def create_tree(self, name: str, description: str = "") -> str:
        """Create a new decision tree"""
        tree = DecisionTree(name, description)
        tree_id = str(uuid.uuid4())[:8]
        self.trees[tree_id] = tree
        self.current_tree = tree_id
        return f"Created tree '{name}' with ID: {tree_id}"
    
    def add_node_cmd(self, question: str, node_type: str = "condition", 
                     action: str = None) -> str:
        """Add a node via CLI"""
        if not self.current_tree:
            return "No active tree. Create one first."
        
        tree = self.trees[self.current_tree]
        node_id = tree.add_node(question, node_type, action)
        return f"Added node {node_id}: {question}"
    
    def link_nodes(self, parent_id: str, answer: str, child_id: str) -> str:
        """Link nodes via CLI"""
        if not self.current_tree:
            return "No active tree. Create one first."
        
        tree = self.trees[self.current_tree]
        tree.add_child(parent_id, answer, child_id)
        return f"Linked {parent_id} -> {child_id} via '{answer}'"
    
    def traverse_tree(self, answers_json: str) -> str:
        """Traverse tree with JSON answers"""
        if not self.current_tree:
            return "No active tree. Create one first."
        
        try:
            answers = json.loads(answers_json)
            tree = self.trees[self.current_tree]
            action, path = tree.traverse(answers)
            
            result = f"Action: {action}\nPath:\n"
            result += '\n'.join(f"  {step}" for step in path)
            return result
        except json.JSONDecodeError:
            return "Invalid JSON format for answers"
    
    def export_tree(self, format_type: str, filepath: str = None) -> str:
        """Export current tree"""
        if not self.current_tree:
            return "No active tree. Create one first."
        
        tree = self.trees[self.current_tree]
        
        if format_type.lower() == "json":
            result = DecisionTreeExporter.to_json(tree, filepath)
        elif format_type.lower() == "yaml":
            result = DecisionTreeExporter.to_yaml(tree, filepath)
        elif format_type.lower() == "mermaid":
            result = DecisionTreeExporter.to_mermaid(tree, filepath)
        elif format_type.lower() == "dot":
            result = DecisionTreeExporter.to_dot(tree, filepath)
        elif format_type.lower() == "ascii":
            result = DecisionTreeExporter.to_ascii(tree)
            if filepath:
                Path(filepath).write_text(result)
        else:
            return f"Unsupported format: {format_type}"
        
        if filepath:
            return f"Exported to {filepath}"
        return result
    
    def list_trees(self) -> str:
        """List all trees"""
        if not self.trees:
            return "No trees available"
        
        result = "Available trees:\n"
        for tree_id, tree in self.trees.items():
            marker = " (current)" if tree_id == self.current_tree else ""
            result += f"  {tree_id}: {tree.name}{marker}\n"
        return result
    
    def switch_tree(self, tree_id: str) -> str:
        """Switch to a different tree"""
        if tree_id in self.trees:
            self.current_tree = tree_id
            return f"Switched to tree: {self.trees[tree_id].name}"
        return f"Tree {tree_id} not found"


def create_mcp_tool_definition() -> Dict[str, Any]:
    """Create MCP tool definition for Claude integration"""
    return {
        "name": "decision_tree",
        "description": "Create and manage decision trees for analysis and automation",
        "inputSchema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "add_node", "link", "traverse", "export", "visualize"],
                    "description": "Action to perform on the decision tree"
                },
                "tree_name": {
                    "type": "string",
                    "description": "Name of the decision tree"
                },
                "question": {
                    "type": "string", 
                    "description": "Question or condition for a node"
                },
                "node_type": {
                    "type": "string",
                    "enum": ["condition", "action", "data"],
                    "description": "Type of node to create"
                },
                "action_text": {
                    "type": "string",
                    "description": "Action text for action nodes"
                },
                "parent_id": {
                    "type": "string",
                    "description": "ID of parent node for linking"
                },
                "child_id": {
                    "type": "string", 
                    "description": "ID of child node for linking"
                },
                "answer": {
                    "type": "string",
                    "description": "Answer text for linking nodes"
                },
                "answers": {
                    "type": "object",
                    "description": "Answers for tree traversal"
                },
                "format": {
                    "type": "string",
                    "enum": ["json", "yaml", "mermaid", "dot", "ascii"],
                    "description": "Export format"
                },
                "filepath": {
                    "type": "string",
                    "description": "File path for export"
                }
            },
            "required": ["action"]
        }
    }


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description="Decision Tree Tool")
    parser.add_argument("command", choices=["create", "add", "link", "traverse", "export", "list", "switch"])
    parser.add_argument("--name", help="Tree name")
    parser.add_argument("--description", help="Tree description")
    parser.add_argument("--question", help="Node question")
    parser.add_argument("--type", default="condition", choices=["condition", "action", "data"], help="Node type")
    parser.add_argument("--action", help="Action text")
    parser.add_argument("--parent", help="Parent node ID")
    parser.add_argument("--child", help="Child node ID")
    parser.add_argument("--answer", help="Answer for linking")
    parser.add_argument("--answers", help="JSON answers for traversal")
    parser.add_argument("--format", choices=["json", "yaml", "mermaid", "dot", "ascii"], help="Export format")
    parser.add_argument("--file", help="Output file path")
    parser.add_argument("--tree-id", help="Tree ID to switch to")
    
    args = parser.parse_args()
    cli = DecisionTreeCLI()
    
    # Execute command
    if args.command == "create":
        if not args.name:
            print("Error: --name required for create command")
            return
        result = cli.create_tree(args.name, args.description or "")
    
    elif args.command == "add":
        if not args.question:
            print("Error: --question required for add command")
            return
        result = cli.add_node_cmd(args.question, args.type, args.action)
    
    elif args.command == "link":
        if not all([args.parent, args.child, args.answer]):
            print("Error: --parent, --child, and --answer required for link command")
            return
        result = cli.link_nodes(args.parent, args.answer, args.child)
    
    elif args.command == "traverse":
        if not args.answers:
            print("Error: --answers required for traverse command")
            return
        result = cli.traverse_tree(args.answers)
    
    elif args.command == "export":
        if not args.format:
            print("Error: --format required for export command")
            return
        result = cli.export_tree(args.format, args.file)
    
    elif args.command == "list":
        result = cli.list_trees()
    
    elif args.command == "switch":
        if not args.tree_id:
            print("Error: --tree-id required for switch command")
            return
        result = cli.switch_tree(args.tree_id)
    
    else:
        result = "Unknown command"
    
    print(result)


if __name__ == "__main__":
    main()