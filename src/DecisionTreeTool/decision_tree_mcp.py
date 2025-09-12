#!/usr/bin/env python3
"""
Decision Tree MCP Tool - The Claude Whisperer 🤖
MCP-compliant server integration for decision tree functionality
(Because even AI assistants need decision trees to make decisions about decisions)
"""

import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, Any, List, Optional

# Import the decision tree functionality
from .decision_tree_tool import DecisionTree, DecisionTreeExporter, DecisionTreeCLI, create_mcp_tool_definition

class DecisionTreeMCPHandler:
    """
    MCP handler for decision tree operations - The diplomatic translator 🌐
    Bridges the gap between Claude's curiosity and our tree wisdom
    """

    def __init__(self):
        self.cli = DecisionTreeCLI()  # Our tree whisperer
        self.tool_definition = create_mcp_tool_definition()  # The instruction manual

    async def handle_decision_tree_call(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle decision tree tool calls from Claude - The main event 🎪
        Where Claude's requests meet our tree magic (hopefully without explosions)
        """

        try:
            action = params.get("action", "")

            if action == "create":
                tree_name = params.get("tree_name", "Unnamed Tree")  # Even trees need names
                description = params.get("description", "")  # The backstory
                result = self.cli.create_tree(tree_name, description)  # Birth of a digital tree

                return {
                    "content": [{
                        "type": "text",
                        "text": f"✅ {result}\n\nYou can now add nodes, link them, and traverse the tree."
                    }]
                }

            elif action == "add_node":
                question = params.get("question", "")  # The burning question
                node_type = params.get("node_type", "condition")  # What kind of node are we birthing?
                action_text = params.get("action_text")  # The payoff (if any)

                if not question:  # Can't have a node without a question (that's just rude)
                    return {
                        "content": [{
                            "type": "text",
                            "text": "❌ Error: 'question' parameter is required for add_node action (nodes without questions are just confused)"
                        }]
                    }

                result = self.cli.add_node_cmd(question, node_type, action_text)  # Plant the seed

                return {
                    "content": [{
                        "type": "text",
                        "text": f"✅ {result}"
                    }]
                }

            elif action == "link":
                parent_id = params.get("parent_id", "")  # The parent (every node needs one)
                child_id = params.get("child_id", "")  # The offspring
                answer = params.get("answer", "")  # The connection string

                if not all([parent_id, child_id, answer]):  # Family reunion requires all members
                    return {
                        "content": [{
                            "type": "text",
                            "text": "❌ Error: 'parent_id', 'child_id', and 'answer' are required for link action (can't have orphaned nodes!)"
                        }]
                    }

                result = self.cli.link_nodes(parent_id, answer, child_id)  # Play matchmaker

                return {
                    "content": [{
                        "type": "text",
                        "text": f"✅ {result}"
                    }]
                }

            elif action == "traverse":
                answers = params.get("answers", {})  # The user's choices (hopefully good ones)

                if not answers:  # Can't navigate without directions
                    return {
                        "content": [{
                            "type": "text",
                            "text": "❌ Error: 'answers' parameter is required for traverse action (GPS needs coordinates!)"
                        }]
                    }

                answers_json = json.dumps(answers)  # Serialize the choices
                result = self.cli.traverse_tree(answers_json)  # Take the journey

                return {
                    "content": [{
                        "type": "text",
                        "text": f"🔍 **Tree Traversal Result:**\n\n```\n{result}\n```"
                    }]
                }

            elif action == "export":
                format_type = params.get("format", "json")  # Choose your poison
                filepath = params.get("filepath")  # Where to save the masterpiece

                result = self.cli.export_tree(format_type, filepath)  # The great escape

                if filepath:
                    return {
                        "content": [{
                            "type": "text",
                            "text": f"💾 {result}"
                        }]
                    }
                else:
                    # Return the exported content
                    return {
                        "content": [{
                            "type": "text",
                            "text": f"📄 **Exported as {format_type.upper()}:**\n\n```{format_type}\n{result}\n```"
                        }]
                    }

            elif action == "visualize":
                # Generate Mermaid diagram (because pictures are worth 1000 nodes)
                mermaid_result = self.cli.export_tree("mermaid")  # Make it pretty

                return {
                    "content": [{
                        "type": "text",
                        "text": f"📊 **Decision Tree Visualization:**\n\n```mermaid\n{mermaid_result}\n```"
                    }]
                }

            elif action == "list":
                result = self.cli.list_trees()  # Show me what you got

                return {
                    "content": [{
                        "type": "text",
                        "text": f"📋 **Available Trees:**\n\n```\n{result}\n```"
                    }]
                }

            else:
                # Unknown action (Claude got creative)
                return {
                    "content": [{
                        "type": "text",
                        "text": f"❌ Error: Unknown action '{action}'. Available actions: create, add_node, link, traverse, export, visualize, list (Claude, please stick to the menu!)"
                    }]
                }

        except Exception as e:
            # Something went sideways (it happens to the best of us)
            return {
                "content": [{
                    "type": "text",
                    "text": f"❌ Error executing decision tree action: {str(e)} (oops, that wasn't supposed to happen!)"
                }]
            }

    def get_tool_definition(self) -> Dict[str, Any]:
        """Get the MCP tool definition - The instruction manual 📖"""
        return self.tool_definition  # Here's how to talk to us


# Example usage patterns for documentation
USAGE_EXAMPLES = {
    "create_tree": {
        "action": "create",
        "tree_name": "Customer Support Decision Tree",
        "description": "Help route customer inquiries to appropriate departments"
    },
    "add_condition_node": {
        "action": "add_node",
        "question": "Is this a technical issue?",
        "node_type": "condition"
    },
    "add_action_node": {
        "action": "add_node",
        "question": "Route to Technical Support",
        "node_type": "action",
        "action_text": "Transfer call to technical support team"
    },
    "link_nodes": {
        "action": "link",
        "parent_id": "abc123",
        "child_id": "def456",
        "answer": "yes"
    },
    "traverse_tree": {
        "action": "traverse",
        "answers": {
            "Is this a technical issue?": "yes",
            "Is it a software problem?": "no"
        }
    },
    "export_mermaid": {
        "action": "export",
        "format": "mermaid"
    },
    "visualize": {
        "action": "visualize"
    }
}


def print_usage_examples():
    """Print usage examples for documentation"""
    print("Decision Tree Tool - Usage Examples:\n")

    for example_name, example_data in USAGE_EXAMPLES.items():
        print(f"**{example_name.replace('_', ' ').title()}:**")
        print(f"```json\n{json.dumps(example_data, indent=2)}\n```\n")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--examples":
        print_usage_examples()
    else:
        print("Decision Tree MCP Handler")
        print("Use --examples to see usage patterns")
