#!/usr/bin/env python3
"""
Universal Decision Tree Tool - The Swiss Army Knife of Decision Making 🌳
Usable by both Claude Code and Amazon Q (because we don't discriminate)

Features:
- Create, modify, and traverse decision trees (like a GPS for your brain)
- Export to multiple formats (more options than a fancy restaurant menu)
- CLI interface for Q integration (Q-tiful, isn't it?)
- MCP tool integration for Claude (Claude-tastic!)
- Visual representation support (pretty pictures for pretty decisions)
- Rule-based and ML-based decision paths (for both the logical and the chaotic)
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
    """
    A node in the decision tree - like a fork in the road, but for your brain 🧠
    Each node asks a question and waits for an answer (hopefully a good one)
    """
    id: str  # Unique identifier (because even nodes need names)
    question: str  # The burning question this node asks
    node_type: str = "condition"  # condition, action, data (pick your poison)
    children: Dict[str, str] = None  # answer -> child_node_id (the family tree)
    action: Optional[str] = None  # What to do when we get here (the payoff)
    confidence: Optional[float] = None  # How sure we are (spoiler: never 100%)
    metadata: Dict[str, Any] = None  # Extra baggage (every node has some)

    def __post_init__(self):
        # Initialize the stuff Python can't figure out on its own
        if self.children is None:
            self.children = {}  # No kids yet, but there's always hope
        if self.metadata is None:
            self.metadata = {}  # Empty baggage is still baggage


class DecisionTree:
    """
    Core decision tree implementation - The brain behind the operation 🧠
    Like a family tree, but for decisions (and hopefully less drama)
    """

    def __init__(self, name: str = "Decision Tree", description: str = ""):
        self.name = name  # What shall we call this masterpiece?
        self.description = description  # The elevator pitch
        self.nodes: Dict[str, DecisionNode] = {}  # Our collection of decision points
        self.root_id: Optional[str] = None  # The big boss node (where it all begins)
        self.created_at = datetime.now().isoformat()  # Birth certificate
        self.updated_at = self.created_at  # Last time we touched this beauty

    def add_node(self, question: str, node_type: str = "condition",
                 action: str = None, confidence: float = None,
                 metadata: Dict = None) -> str:
        """Add a node to the tree - like planting a seed of wisdom 🌱"""
        # Input validation (because garbage in = garbage out)
        if not question or not question.strip():
            raise ValueError("Question cannot be empty (nodes need something to ask!)")

        if node_type not in ["condition", "action", "data"]:
            raise ValueError(f"Invalid node_type '{node_type}'. Must be 'condition', 'action', or 'data' (pick a lane!)")

        if confidence is not None and not (0.0 <= confidence <= 1.0):
            raise ValueError("Confidence must be between 0.0 and 1.0 (we're not that confident either)")

        # Clean up the question (remove extra whitespace because we're neat freaks)
        question = question.strip()

        node_id = str(uuid.uuid4())[:8]  # Generate a fancy ID (8 chars should do)
        node = DecisionNode(
            id=node_id,
            question=question,
            node_type=node_type,
            action=action,
            confidence=confidence,
            metadata=metadata or {}  # Empty dict if none provided (we're generous)
        )
        self.nodes[node_id] = node  # Add to our node collection

        # Set as root if it's the first node (someone has to be the boss)
        if self.root_id is None:
            self.root_id = node_id

        self._update_timestamp()  # Mark our territory with a timestamp
        return node_id

    def add_child(self, parent_id: str, answer: str, child_id: str):
        """Add a child relationship - building the family tree 👨‍👩‍👧‍👦"""
        # Validation party (everyone's invited!)
        if not parent_id or parent_id not in self.nodes:
            raise ValueError(f"Parent node '{parent_id}' not found (can't adopt without a parent!)")

        if not child_id or child_id not in self.nodes:
            raise ValueError(f"Child node '{child_id}' not found (can't adopt what doesn't exist!)")

        if not answer or not answer.strip():
            raise ValueError("Answer cannot be empty (silence is not an option here)")

        # Check for cycles (because infinite loops are bad for mental health)
        if self._would_create_cycle(parent_id, child_id):
            raise ValueError(f"Adding this relationship would create a cycle (we don't do time loops here)")

        # Clean up the answer
        answer = answer.strip()

        if parent_id in self.nodes:  # Make sure parent exists (no orphans allowed)
            self.nodes[parent_id].children[answer] = child_id
            self._update_timestamp()  # Another modification, another timestamp

    def create_path(self, path_data: List[Dict[str, Any]]) -> str:
        """Create a complete decision path from structured data - assembly line style 🏭"""
        node_ids = []  # Our breadcrumb trail

        for i, node_data in enumerate(path_data):
            node_id = self.add_node(
                question=node_data.get("question", ""),  # The burning question
                node_type=node_data.get("type", "condition"),  # What kind of node are we?
                action=node_data.get("action"),  # What happens if we get here
                confidence=node_data.get("confidence"),  # How sure are we? (spoiler: not very)
                metadata=node_data.get("metadata", {})  # Extra baggage
            )
            node_ids.append(node_id)

            # Link to previous node (connect the dots)
            if i > 0:
                answer = node_data.get("from_answer", "yes")  # Default to optimism
                self.add_child(node_ids[i-1], answer, node_id)

        return node_ids[0] if node_ids else None  # Return the starting point (or nothing if we failed)

    def traverse(self, answers: Dict[str, str]) -> Tuple[str, List[str]]:
        """Traverse the tree with given answers - like GPS for decisions 🗺️"""
        if not self.root_id:
            return None, ["Error: Empty tree (can't navigate the void!)"]

        # Input validation (trust but verify)
        if not isinstance(answers, dict):
            return None, ["Error: Answers must be a dictionary (we need key-value pairs!)"]

        current_id = self.root_id  # Start at the beginning (revolutionary concept)
        path = []  # Breadcrumb trail for debugging
        visited = set()  # Cycle detection (because we learn from our mistakes)
        max_depth = 100  # Safety net (prevent infinite loops)
        depth = 0

        while current_id and depth < max_depth:  # Keep going until we hit a dead end or safety limit
            # Cycle detection (déjà vu protection)
            if current_id in visited:
                path.append(f"⚠️ Cycle detected at node: {current_id}")
                return None, path

            visited.add(current_id)
            depth += 1

            if current_id not in self.nodes:
                path.append(f"Error: Node '{current_id}' not found (ghost node alert!)")
                return None, path

            current_node = self.nodes[current_id]
            path.append(f"Node: {current_node.question}")

            if current_node.node_type == "action":
                # We've reached the promised land (an action node)
                action_text = current_node.action or "No action specified"
                path.append(f"Action: {action_text}")
                return action_text, path

            # Find next node based on answer (the moment of truth)
            next_id = None
            matched_answer = None

            # Try exact matches first (precision matters)
            for answer, child_id in current_node.children.items():
                if answer in answers and str(answers[answer]).lower().strip() in ["true", "yes", "1", "y"]:
                    next_id = child_id
                    matched_answer = answer
                    break

            # Fallback: try fuzzy matching (because humans are imprecise)
            if not next_id:
                for answer, child_id in current_node.children.items():
                    for user_answer_key, user_answer_value in answers.items():
                        if (answer.lower() in user_answer_key.lower() or
                            user_answer_key.lower() in answer.lower()):
                            if str(user_answer_value).lower().strip() in ["true", "yes", "1", "y"]:
                                next_id = child_id
                                matched_answer = f"{answer} (fuzzy match)"
                                break
                    if next_id:
                        break

            if not next_id:
                # Houston, we have a problem (no matching path)
                available_answers = list(current_node.children.keys())
                path.append(f"No matching path found. Available answers: {available_answers}")
                return None, path

            path.append(f"Answer: {matched_answer}")
            current_id = next_id  # Move to the next node (onward and upward)

        if depth >= max_depth:
            path.append("⚠️ Maximum traversal depth reached (safety brake engaged!)")
            return None, path

        return None, path  # Shouldn't get here, but just in case

    def get_all_paths(self) -> List[List[str]]:
        """Get all possible paths through the tree - the choose your own adventure edition 📚"""
        if not self.root_id:
            return []  # Empty tree, empty paths

        all_paths = []  # Our collection of possible journeys

        def traverse_all(node_id, current_path):
            """Recursive helper - like inception, but for trees 🌀"""
            node = self.nodes[node_id]
            current_path.append(node.question)

            if node.node_type == "action":
                # End of the line (in a good way)
                current_path.append(f"→ {node.action}")
                all_paths.append(current_path.copy())  # Save this path for posterity
            else:
                # Keep exploring (the adventure continues)
                for answer, child_id in node.children.items():
                    child_path = current_path + [f"[{answer}]"]
                    traverse_all(child_id, child_path)

            current_path.pop()  # Clean up after ourselves (good manners)

        traverse_all(self.root_id, [])  # Start the recursive madness
        return all_paths

    def to_dict(self) -> Dict[str, Any]:
        """Export tree to dictionary - serialization made simple 📦"""
        return {
            "name": self.name,
            "description": self.description,
            "root_id": self.root_id,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "nodes": {
                node_id: asdict(node) for node_id, node in self.nodes.items()  # Convert all nodes to dicts
            }
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'DecisionTree':
        """Import tree from dictionary - resurrection magic ✨"""
        tree = cls(data.get("name", ""), data.get("description", ""))  # Create the shell
        tree.root_id = data.get("root_id")  # Set the boss
        tree.created_at = data.get("created_at", datetime.now().isoformat())  # When was it born?
        tree.updated_at = data.get("updated_at", datetime.now().isoformat())  # When was it last touched?

        # Rebuild all the nodes (like IKEA furniture, but easier)
        for node_id, node_data in data.get("nodes", {}).items():
            tree.nodes[node_id] = DecisionNode(**node_data)

        return tree  # Return the fully assembled tree

    def _update_timestamp(self):
        """Update the last modified timestamp - marking our territory 📅"""
        self.updated_at = datetime.now().isoformat()  # Time stamp of shame (or pride)

    def _would_create_cycle(self, parent_id: str, child_id: str) -> bool:
        """Check if adding this relationship would create a cycle - time loop detector 🔄"""
        if parent_id == child_id:
            return True  # Self-reference is definitely a cycle (narcissistic node alert!)

        # Use DFS to check if child_id can reach parent_id
        visited = set()

        def can_reach(current_id: str, target_id: str) -> bool:
            if current_id == target_id:
                return True  # Found the target (cycle detected!)

            if current_id in visited or current_id not in self.nodes:
                return False  # Already visited or doesn't exist (dead end)

            visited.add(current_id)

            # Check all children (recursive exploration)
            for child in self.nodes[current_id].children.values():
                if can_reach(child, target_id):
                    return True  # Found a path to target (cycle alert!)

            return False  # No path found (we're safe)

        return can_reach(child_id, parent_id)  # Would child eventually reach parent?

    def validate_tree(self) -> List[str]:
        """Validate tree structure and return list of issues - the tree doctor 🩺"""
        issues = []

        if not self.nodes:
            issues.append("Tree is empty (existential crisis detected)")
            return issues

        if not self.root_id:
            issues.append("No root node specified (headless tree syndrome)")
        elif self.root_id not in self.nodes:
            issues.append(f"Root node '{self.root_id}' not found (missing head alert!)")

        # Check for orphaned nodes (nodes with no path from root)
        if self.root_id and self.root_id in self.nodes:
            reachable = set()

            def mark_reachable(node_id: str):
                if node_id in reachable or node_id not in self.nodes:
                    return  # Already visited or doesn't exist
                reachable.add(node_id)
                for child_id in self.nodes[node_id].children.values():
                    mark_reachable(child_id)

            mark_reachable(self.root_id)

            # Find orphaned nodes
            orphans = set(self.nodes.keys()) - reachable
            if orphans:
                issues.append(f"Orphaned nodes found: {list(orphans)} (family reunion needed)")

        # Check for nodes with invalid references
        for node_id, node in self.nodes.items():
            for answer, child_id in node.children.items():
                if child_id not in self.nodes:
                    issues.append(f"Node '{node_id}' references non-existent child '{child_id}' (broken family tree)")

        # Check for action nodes with children (they should be leaves)
        for node_id, node in self.nodes.items():
            if node.node_type == "action" and node.children:
                issues.append(f"Action node '{node_id}' has children (actions should be final destinations)")

        return issues


class DecisionTreeExporter:
    """
    Export decision trees to various formats - The Universal Translator 🌍
    Because everyone has their favorite way to consume data (we don't judge)
    """

    @staticmethod
    def to_json(tree: DecisionTree, filepath: str = None) -> str:
        """Export to JSON format - The lingua franca of APIs 📡"""
        json_data = json.dumps(tree.to_dict(), indent=2)  # Pretty print because we're classy
        if filepath:
            Path(filepath).write_text(json_data)  # Save it for posterity
        return json_data  # Return the goods

    @staticmethod
    def to_yaml(tree: DecisionTree, filepath: str = None) -> str:
        """Export to YAML format - For the human-readable crowd 👥"""
        yaml_data = yaml.dump(tree.to_dict(), default_flow_style=False, indent=2)  # Readable indentation
        if filepath:
            Path(filepath).write_text(yaml_data)  # File it away
        return yaml_data  # YAML it up

    @staticmethod
    def to_mermaid(tree: DecisionTree, filepath: str = None) -> str:
        """Export to Mermaid diagram format - Making flowcharts sexy again 🧜‍♀️"""
        if not tree.root_id:
            return "graph TD\n    A[Empty Tree]"  # Even empty trees deserve representation

        mermaid = ["graph TD"]  # Top-down because gravity exists

        def clean_text(text: str) -> str:
            """Clean text for Mermaid compatibility - sanitization station 🧼"""
            return text.replace('"', "'").replace('\n', ' ').strip()  # No funny business allowed

        # Generate nodes and connections (the meat and potatoes)
        for node_id, node in tree.nodes.items():
            clean_question = clean_text(node.question)

            if node.node_type == "action":
                # Action nodes get special treatment (they're the stars)
                mermaid.append(f'    {node_id}["{clean_question}"]')
                mermaid.append(f'    {node_id} --> {node_id}_action["{clean_text(node.action or "")}"]')
                mermaid.append(f'    {node_id}_action:::actionClass')  # Style it up
            else:
                # Regular nodes (the supporting cast)
                mermaid.append(f'    {node_id}["{clean_question}"]')

            # Add connections to children (building the family tree)
            for answer, child_id in node.children.items():
                clean_answer = clean_text(answer)
                mermaid.append(f'    {node_id} -->|{clean_answer}| {child_id}')

        # Add styling (because presentation matters)
        mermaid.extend([
            "    classDef actionClass fill:#90EE90,stroke:#006400,stroke-width:2px",  # Green for go
            "    classDef conditionClass fill:#87CEEB,stroke:#000080,stroke-width:2px"  # Blue for thinking
        ])

        result = '\n'.join(mermaid)  # Assemble the masterpiece
        if filepath:
            Path(filepath).write_text(result)  # Save for the mermaids
        return result

    @staticmethod
    def to_dot(tree: DecisionTree, filepath: str = None) -> str:
        """Export to DOT format for Graphviz - For the graph theory nerds 🤓"""
        if not tree.root_id:
            return 'digraph DecisionTree {\n    empty [label="Empty Tree"]\n}'  # Sad but honest

        dot_lines = [
            'digraph DecisionTree {',  # Directed graph because decisions have direction
            '    rankdir=TD;',  # Top-down layout (gravity wins again)
            '    node [shape=box, style=rounded];'  # Rounded corners are friendlier
        ]

        # Generate nodes (the cast of characters)
        for node_id, node in tree.nodes.items():
            label = node.question.replace('"', '\\"')  # Escape the quotes (safety first)
            if node.node_type == "action":
                # Action nodes get green treatment (money color)
                dot_lines.append(f'    {node_id} [label="{label}\\n→ {node.action or ""}", fillcolor=lightgreen, style="rounded,filled"];')
            else:
                # Condition nodes get blue treatment (thinking color)
                dot_lines.append(f'    {node_id} [label="{label}", fillcolor=lightblue, style="rounded,filled"];')

        # Generate edges (the connections that matter)
        for node_id, node in tree.nodes.items():
            for answer, child_id in node.children.items():
                edge_label = answer.replace('"', '\\"')  # More quote escaping
                dot_lines.append(f'    {node_id} -> {child_id} [label="{edge_label}"];')

        dot_lines.append('}')  # Close the graph (proper etiquette)

        result = '\n'.join(dot_lines)  # Assemble the DOT masterpiece
        if filepath:
            Path(filepath).write_text(result)  # Save for Graphviz to consume
        return result

    @staticmethod
    def to_ascii(tree: DecisionTree) -> str:
        """Export to ASCII art tree for terminal display - Old school cool 🎨"""
        if not tree.root_id:
            return "Empty Tree"  # Sad but true

        lines = []  # Our canvas for ASCII art
        visited_in_path = set()  # Breadcrumb trail to avoid infinite loops
        node_first_occurrence = {}  # Memory palace for cycle detection

        def draw_node(node_id: str, prefix: str = "", is_last: bool = True,
                     parent_answer: str = "", depth: int = 0) -> None:
            """Recursively draw node and its children with cycle detection - The artist at work 🎭"""
            if node_id not in tree.nodes:
                return  # Ghost node? Not on our watch

            # Check for cycles (because infinite loops are bad for business)
            if node_id in visited_in_path:
                # This is a cycle - show a reference instead of recursing
                connector = "└── " if is_last else "├── "  # Choose your connector
                answer_label = f"[{parent_answer}] " if parent_answer else ""

                # Try to find where we first showed this node (déjà vu detection)
                if node_id in node_first_occurrence:
                    target_description = node_first_occurrence[node_id]
                    cycle_text = f"{answer_label}🔄 → loops back to: {target_description}"
                else:
                    node_question = tree.nodes[node_id].question[:50] + ("..." if len(tree.nodes[node_id].question) > 50 else "")
                    cycle_text = f"{answer_label}🔄 → cycles back to: {node_question}"

                lines.append(f"{prefix}{connector}{cycle_text}")
                return

            # Prevent infinite recursion with depth limit (safety first)
            if depth > 20:
                connector = "└── " if is_last else "├── "
                answer_label = f"[{parent_answer}] " if parent_answer else ""
                lines.append(f"{prefix}{connector}{answer_label}⚠️  → (max depth reached)")
                return  # We've gone too deep, abort mission

            # Mark this node as visited in current path (breadcrumb dropping)
            visited_in_path.add(node_id)

            node = tree.nodes[node_id]

            # Create connector (the ASCII art magic)
            connector = "└── " if is_last else "├── "

            # Add answer label if this is not root (context is everything)
            answer_label = f"[{parent_answer}] " if parent_answer else ""

            # Format node text (make it pretty)
            if node.node_type == "action":
                node_text = f"{answer_label}{node.question} → {node.action or 'No action'}"
            else:
                node_text = f"{answer_label}{node.question}"

            # Remember this node's first occurrence for cycle references (memory bank)
            if node_id not in node_first_occurrence:
                node_first_occurrence[node_id] = node.question[:30] + ("..." if len(node.question) > 30 else "")

            # Add the line (commit to canvas)
            lines.append(f"{prefix}{connector}{node_text}")

            # Prepare prefix for children (inheritance planning)
            extension = "    " if is_last else "│   "
            new_prefix = prefix + extension

            # Draw children (the next generation)
            children_items = list(node.children.items())
            for i, (answer, child_id) in enumerate(children_items):
                is_last_child = (i == len(children_items) - 1)
                draw_node(child_id, new_prefix, is_last_child, answer, depth + 1)

            # Remove from visited path when we're done with this branch (cleanup crew)
            visited_in_path.remove(node_id)

        # Start from root (every tree needs roots)
        lines.append(f"🌳 {tree.name}")
        if tree.description:
            lines.append(f"   {tree.description}")  # The subtitle
        lines.append("")  # Breathing room

        # Draw the tree starting from root (the main event)
        root_node = tree.nodes[tree.root_id]
        lines.append(f"Root: {root_node.question}")

        # Remember root for cycle detection (ground zero)
        node_first_occurrence[tree.root_id] = root_node.question[:30] + ("..." if len(root_node.question) > 30 else "")

        children_items = list(root_node.children.items())
        for i, (answer, child_id) in enumerate(children_items):
            is_last_child = (i == len(children_items) - 1)
            draw_node(child_id, "", is_last_child, answer, 0)

        # Add legend if cycles were detected (user manual)
        if any("🔄" in line for line in lines):
            lines.append("")
            lines.append("Legend: 🔄 = cycle/loop back to earlier node")

        return "\n".join(lines)  # The final masterpiece


class DecisionTreeCLI:
    """
    Command line interface for Q integration - The bridge between humans and trees 🌉
    Making decision trees accessible to mere mortals (and Q users)
    """

    def __init__(self):
        self.trees: Dict[str, DecisionTree] = {}  # Our tree collection (a digital forest)
        self.current_tree: Optional[str] = None  # Which tree are we currently climbing?
        self.current_project: Optional[str] = None  # Project context (because organization matters)

        # Try to load project context (optimistic loading)
        try:
            from .project_context import get_project_context
            self.project_ctx = get_project_context()  # Get the context manager
            self.current_project = self.project_ctx.detect_current_project()  # Auto-detect where we are
        except ImportError:
            self.project_ctx = None  # No context? No problem (we'll survive)

    def create_tree(self, name: str, description: str = "") -> str:
        """Create a new decision tree - Birth of a digital tree 🌱"""
        tree = DecisionTree(name, description)  # Create the tree object
        tree_id = str(uuid.uuid4())[:8]  # Generate a short, sweet ID
        self.trees[tree_id] = tree  # Add to our collection
        self.current_tree = tree_id  # Make it the active one (favoritism at its finest)
        return f"Created tree '{name}' with ID: {tree_id}"

    def add_node_cmd(self, question: str, node_type: str = "condition",
                     action: str = None) -> str:
        """Add a node via CLI - Planting seeds of wisdom 🌰"""
        if not self.current_tree:
            return "No active tree. Create one first."  # Can't plant without soil

        tree = self.trees[self.current_tree]  # Get the current tree
        node_id = tree.add_node(question, node_type, action)  # Add the node
        return f"Added node {node_id}: {question}"

    def link_nodes(self, parent_id: str, answer: str, child_id: str) -> str:
        """Link nodes via CLI - Playing matchmaker for nodes 💕"""
        if not self.current_tree:
            return "No active tree. Create one first."  # No tree, no linking

        tree = self.trees[self.current_tree]  # Get the active tree
        tree.add_child(parent_id, answer, child_id)  # Make the connection
        return f"Linked {parent_id} -> {child_id} via '{answer}'"

    def traverse_tree(self, answers_json: str) -> str:
        """Traverse tree with JSON answers - GPS navigation for decisions 🧭"""
        if not self.current_tree:
            return "No active tree. Create one first."  # Can't navigate without a map

        try:
            answers = json.loads(answers_json)  # Parse the JSON (fingers crossed)
            tree = self.trees[self.current_tree]  # Get our navigation tree
            action, path = tree.traverse(answers)  # Take the journey

            result = f"Action: {action}\nPath:\n"  # Format the results
            result += '\n'.join(f"  {step}" for step in path)  # Show the breadcrumbs
            return result
        except json.JSONDecodeError:
            return "Invalid JSON format for answers"  # JSON parsing failed (sad trombone)

    def export_tree(self, format_type: str, filepath: str = None, project_name: str = None) -> str:
        """Export current tree with project-aware storage - The great escape 📤"""
        if not self.current_tree:
            return "No active tree. Create one first."  # Can't export what doesn't exist

        tree = self.trees[self.current_tree]  # Get our tree to liberate

        # Use project context if available and no explicit filepath (smart defaults)
        if self.project_ctx and filepath is None and project_name is not None:
            filepath = str(self.project_ctx.get_tree_path(project_name, tree.name, format_type))  # Project-specific path
        elif self.project_ctx and filepath is None and self.current_project:
            filepath = str(self.project_ctx.get_tree_path(self.current_project, tree.name, format_type))  # Current project path

        # Format selection - choose your own adventure 🎭
        if format_type.lower() == "json":
            result = DecisionTreeExporter.to_json(tree, filepath)  # The API favorite
        elif format_type.lower() == "yaml":
            result = DecisionTreeExporter.to_yaml(tree, filepath)  # The human-readable choice
        elif format_type.lower() == "mermaid":
            result = DecisionTreeExporter.to_mermaid(tree, filepath)  # The pretty picture option
        elif format_type.lower() == "dot":
            result = DecisionTreeExporter.to_dot(tree, filepath)  # The graph theory special
        elif format_type.lower() == "ascii":
            result = DecisionTreeExporter.to_ascii(tree)  # The retro terminal art
            if filepath:
                Path(filepath).write_text(result)  # Save the ASCII masterpiece
        else:
            return f"Unsupported format: {format_type}"  # Format not found (404 error)

        if filepath:
            project_info = f" (project: {project_name or self.current_project})" if self.project_ctx else ""
            return f"Exported to {filepath}{project_info}"  # Success with context
        return result  # Return the raw goods

    def list_trees(self) -> str:
        """List all trees - The forest inventory 🌲"""
        result_lines = []  # Our report card

        # Show project context if available (context is king)
        if self.project_ctx and self.current_project:
            result_lines.append(f"📁 Current Project: {self.current_project}")
            project_trees = self.project_ctx.get_project_trees(self.current_project)  # Get the saved trees
            if project_trees:
                result_lines.append(f"📄 Saved trees in {self.current_project}:")
                for tree_name in project_trees:
                    result_lines.append(f"  • {tree_name}")  # List each saved tree
            result_lines.append("")  # Breathing room

        # Show active trees in memory (the working set)
        if not self.trees:
            result_lines.append("No active trees in memory.")  # Empty forest, sad face
        else:
            result_lines.append("🔥 Active trees in memory:")
            for tree_id, tree in self.trees.items():
                marker = " (current)" if tree_id == self.current_tree else ""  # Mark the active one
                result_lines.append(f"  {tree_id}: {tree.name}{marker}")

        return "\n".join(result_lines)  # Assemble the report

    def list_projects(self) -> str:
        """List all available projects - The project portfolio 📂"""
        if not self.project_ctx:
            return "Project context not available"  # No context manager, no projects

        result_lines = ["📁 Available Projects:"]  # Start the catalog
        for name, config in self.project_ctx.list_projects().items():
            current_marker = " (current)" if name == self.current_project else ""  # Mark the active project
            result_lines.append(f"  • {name}{current_marker}: {config['description']}")

            # Show tree count (because numbers matter)
            tree_count = len(self.project_ctx.get_project_trees(name))
            if tree_count > 0:
                result_lines.append(f"    Trees: {tree_count}")  # Show the tree inventory

        return "\n".join(result_lines)  # Deliver the portfolio

    def set_project(self, project_name: str) -> str:
        """Set the current project context - Changing lanes 🚗"""
        if not self.project_ctx:
            return "Project context not available"  # No context manager, no switching

        if project_name not in self.project_ctx.list_projects():
            return f"Unknown project: {project_name}. Use 'list-projects' to see available projects."  # Project not found

        self.current_project = project_name  # Make the switch
        return f"Switched to project: {project_name}"  # Confirmation of lane change

    def load_tree(self, tree_name: str, project_name: str = None) -> str:
        """Load a previously saved decision tree - Resurrection magic ✨"""
        if not self.project_ctx:
            return "Project context not available"  # No context, no loading

        project = project_name or self.current_project  # Use specified or current project
        if not project:
            return "No project specified. Use --project or set-project first."  # Need a project to load from

        # Try to find the tree file (JSON format preferred)
        tree_path = self.project_ctx.get_tree_path(project, tree_name, "json")

        if not tree_path.exists():
            return f"Tree '{tree_name}' not found in project '{project}'"  # File not found (404)

        try:
            import json  # Import here to avoid circular imports
            with open(tree_path, 'r') as f:
                tree_data = json.load(f)  # Parse the saved tree data

            # Recreate the decision tree from saved data (digital archaeology)
            tree = DecisionTree(tree_data['name'], tree_data.get('description', ''))

            # Load nodes (rebuilding the family tree)
            for node_id, node_data in tree_data['nodes'].items():
                node = DecisionNode(
                    id=node_id,
                    question=node_data['question'],
                    node_type=node_data.get('node_type', 'condition'),  # Default to condition
                    action=node_data.get('action')  # Action might be None
                )
                node.children = node_data.get('children', {})  # Restore the family connections
                tree.nodes[node_id] = node  # Add to the tree

            tree.root_id = tree_data.get('root_id')  # Set the family patriarch

            # Store in memory with a new ID (give it a fresh start)
            tree_id = str(uuid.uuid4())[:8]
            self.trees[tree_id] = tree  # Add to our collection
            self.current_tree = tree_id  # Make it the active one

            return f"Loaded tree '{tree_name}' from project '{project}' with ID: {tree_id}"

        except Exception as e:
            return f"Error loading tree: {str(e)}"  # Something went wrong (error handling)

    def switch_tree(self, tree_id: str) -> str:
        """Switch to a different tree - Tree hopping 🐸"""
        if tree_id in self.trees:
            self.current_tree = tree_id  # Make the switch
            return f"Switched to tree: {self.trees[tree_id].name}"  # Confirmation with tree name
        return f"Tree {tree_id} not found"  # Tree doesn't exist (sad hop)

    def validate_current_tree(self) -> str:
        """Validate the current tree for issues - Tree health checkup 🩺"""
        if not self.current_tree:
            return "No active tree. Create one first."  # Can't validate what doesn't exist

        tree = self.trees[self.current_tree]  # Get the patient
        issues = tree.validate_tree()  # Run the diagnostics

        if not issues:
            return f"✅ Tree '{tree.name}' is healthy! No issues found."  # Clean bill of health
        else:
            result = f"⚠️ Tree '{tree.name}' has {len(issues)} issue(s):\n"
            for i, issue in enumerate(issues, 1):
                result += f"  {i}. {issue}\n"  # List all the problems
            return result.strip()  # Return the diagnosis


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
    parser.add_argument("command", choices=["create", "add", "link", "traverse", "export", "list", "switch", "list-projects", "set-project", "load", "validate"])
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
    parser.add_argument("--project", help="Project name for context")

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
        result = cli.export_tree(args.format, args.file, args.project)

    elif args.command == "list":
        result = cli.list_trees()

    elif args.command == "list-projects":
        result = cli.list_projects()

    elif args.command == "set-project":
        if not args.project:
            print("Error: --project required for set-project command")
            return
        result = cli.set_project(args.project)

    elif args.command == "load":
        if not args.name:
            print("Error: --name required for load command")
            return
        result = cli.load_tree(args.name, args.project)

    elif args.command == "switch":
        if not args.tree_id:
            print("Error: --tree-id required for switch command")
            return
        result = cli.switch_tree(args.tree_id)

    elif args.command == "validate":
        result = cli.validate_current_tree()

    else:
        result = "Unknown command"

    print(result)


if __name__ == "__main__":
    main()
