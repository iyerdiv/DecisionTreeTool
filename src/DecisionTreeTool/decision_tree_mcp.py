#!/usr/bin/env python3
"""
Decision Tree MCP Tool
MCP-compliant server integration for decision tree functionality
"""

import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, Any, List, Optional

# Import the decision tree functionality
from .decision_tree_tool import DecisionTree, DecisionTreeExporter, DecisionTreeCLI, create_mcp_tool_definition

class DecisionTreeMCPHandler:
    """MCP handler for decision tree operations"""
    
    def __init__(self):
        self.cli = DecisionTreeCLI()
        self.tool_definition = create_mcp_tool_definition()
    
    async def handle_decision_tree_call(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle decision tree tool calls from Claude"""
        
        try:
            action = params.get("action", "")
            
            if action == "create":
                tree_name = params.get("tree_name", "Unnamed Tree")
                description = params.get("description", "")
                result = self.cli.create_tree(tree_name, description)
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"✅ {result}\n\nYou can now add nodes, link them, and traverse the tree."
                    }]
                }
            
            elif action == "add_node":
                question = params.get("question", "")
                node_type = params.get("node_type", "condition")
                action_text = params.get("action_text")
                
                if not question:
                    return {
                        "content": [{
                            "type": "text", 
                            "text": "❌ Error: 'question' parameter is required for add_node action"
                        }]
                    }
                
                result = self.cli.add_node_cmd(question, node_type, action_text)
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"✅ {result}"
                    }]
                }
            
            elif action == "link":
                parent_id = params.get("parent_id", "")
                child_id = params.get("child_id", "")
                answer = params.get("answer", "")
                
                if not all([parent_id, child_id, answer]):
                    return {
                        "content": [{
                            "type": "text",
                            "text": "❌ Error: 'parent_id', 'child_id', and 'answer' are required for link action"
                        }]
                    }
                
                result = self.cli.link_nodes(parent_id, answer, child_id)
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"✅ {result}"
                    }]
                }
            
            elif action == "traverse":
                answers = params.get("answers", {})
                
                if not answers:
                    return {
                        "content": [{
                            "type": "text",
                            "text": "❌ Error: 'answers' parameter is required for traverse action"
                        }]
                    }
                
                answers_json = json.dumps(answers)
                result = self.cli.traverse_tree(answers_json)
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"🔍 **Tree Traversal Result:**\n\n```\n{result}\n```"
                    }]
                }
            
            elif action == "export":
                format_type = params.get("format", "json")
                filepath = params.get("filepath")
                
                result = self.cli.export_tree(format_type, filepath)
                
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
                # Generate Mermaid diagram
                mermaid_result = self.cli.export_tree("mermaid")
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"📊 **Decision Tree Visualization:**\n\n```mermaid\n{mermaid_result}\n```"
                    }]
                }
            
            elif action == "list":
                result = self.cli.list_trees()
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"📋 **Available Trees:**\n\n```\n{result}\n```"
                    }]
                }
            
            else:
                return {
                    "content": [{
                        "type": "text",
                        "text": f"❌ Error: Unknown action '{action}'. Available actions: create, add_node, link, traverse, export, visualize, list"
                    }]
                }
        
        except Exception as e:
            return {
                "content": [{
                    "type": "text",
                    "text": f"❌ Error executing decision tree action: {str(e)}"
                }]
            }
    
    def get_tool_definition(self) -> Dict[str, Any]:
        """Get the MCP tool definition"""
        return self.tool_definition


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