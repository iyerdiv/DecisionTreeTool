#!/usr/bin/env python3
"""
Test suite for DecisionTreeTool
"""

import pytest
import json
import sys
from pathlib import Path
from unittest.mock import Mock, patch

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from DecisionTreeTool.decision_tree_robust import (
    DecisionNode, 
    DecisionTree, 
    DecisionPath,
    DecisionResult
)


class TestDecisionNode:
    """Test DecisionNode functionality"""
    
    def test_node_creation(self):
        """Test basic node creation"""
        node = DecisionNode(
            id="test_node",
            question="Is this a test?",
            children={"yes": "node1", "no": "node2"}
        )
        assert node.id == "test_node"
        assert node.question == "Is this a test?"
        assert node.children == {"yes": "node1", "no": "node2"}
        assert node.node_type == "condition"
    
    def test_node_with_fallback(self):
        """Test node with fallback logic"""
        node = DecisionNode(
            id="test_node",
            question="What's the severity?",
            children={"high": "urgent", "low": "normal"},
            fallback_node="investigate",
            fallback_reason="Unknown severity"
        )
        assert node.fallback_node == "investigate"
        assert node.fallback_reason == "Unknown severity"
    
    def test_node_with_confidence(self):
        """Test node with confidence scoring"""
        node = DecisionNode(
            id="test_node",
            question="Are you sure?",
            children={"yes": "proceed", "no": "stop"},
            weight=2.0,
            min_confidence=0.7,
            confidence_adjustment=-0.1
        )
        assert node.weight == 2.0
        assert node.min_confidence == 0.7
        assert node.confidence_adjustment == -0.1
    
    def test_node_with_context_requirements(self):
        """Test node with context validation"""
        node = DecisionNode(
            id="test_node",
            question="Check the data?",
            required_context=["data_source", "timestamp"],
            optional_context=["user_id"],
            context_validators={"timestamp": "recent"}
        )
        assert node.required_context == ["data_source", "timestamp"]
        assert node.optional_context == ["user_id"]
        assert node.context_validators == {"timestamp": "recent"}
    
    def test_action_node(self):
        """Test action node creation"""
        node = DecisionNode(
            id="action_node",
            question="",
            node_type="action",
            action="Send alert to team"
        )
        assert node.node_type == "action"
        assert node.action == "Send alert to team"


class TestDecisionTree:
    """Test DecisionTree functionality"""
    
    def test_tree_creation(self):
        """Test basic tree creation"""
        tree = DecisionTree(name="test_tree")
        assert tree.name == "test_tree"
        assert tree.nodes == {}
        assert tree.start_node == "start"
    
    def test_add_node(self):
        """Test adding nodes to tree"""
        tree = DecisionTree(name="test_tree")
        node = DecisionNode(
            id="node1",
            question="Test question?"
        )
        tree.add_node(node)
        assert "node1" in tree.nodes
        assert tree.nodes["node1"].question == "Test question?"
    
    def test_tree_with_metadata(self):
        """Test tree with metadata"""
        tree = DecisionTree(
            name="test_tree",
            description="A test tree",
            metadata={"version": "1.0", "author": "test"}
        )
        assert tree.description == "A test tree"
        assert tree.metadata["version"] == "1.0"
        assert tree.metadata["author"] == "test"
    
    def test_simple_tree_execution(self):
        """Test executing a simple decision tree"""
        tree = DecisionTree(name="simple_tree")
        
        # Build a simple tree
        tree.add_node(DecisionNode(
            id="start",
            question="Is it working?",
            children={"yes": "success", "no": "troubleshoot"}
        ))
        tree.add_node(DecisionNode(
            id="success",
            node_type="action",
            action="Continue monitoring"
        ))
        tree.add_node(DecisionNode(
            id="troubleshoot",
            node_type="action",
            action="Start debugging"
        ))
        
        # Execute with "yes" answer
        with patch('builtins.input', return_value='yes'):
            result = tree.execute()
            assert result.action == "Continue monitoring"
            assert "start" in result.path
    
    def test_tree_with_fallback(self):
        """Test tree execution with fallback logic"""
        tree = DecisionTree(name="fallback_tree")
        
        tree.add_node(DecisionNode(
            id="start",
            question="What's the priority?",
            children={"high": "urgent", "low": "normal"},
            fallback_node="investigate"
        ))
        tree.add_node(DecisionNode(
            id="investigate",
            node_type="action",
            action="Investigate further"
        ))
        
        # Execute with unhandled answer
        with patch('builtins.input', return_value='medium'):
            result = tree.execute()
            assert result.action == "Investigate further"
    
    def test_context_validation(self):
        """Test context validation in tree execution"""
        tree = DecisionTree(name="context_tree")
        
        tree.add_node(DecisionNode(
            id="start",
            question="Process data?",
            required_context=["data_source"],
            children={"yes": "process", "no": "skip"}
        ))
        tree.add_node(DecisionNode(
            id="process",
            node_type="action",
            action="Process the data"
        ))
        
        # Execute without required context
        with patch('builtins.input', return_value='yes'):
            result = tree.execute(context={})
            # Should handle missing context gracefully
            assert result is not None
        
        # Execute with required context
        with patch('builtins.input', return_value='yes'):
            result = tree.execute(context={"data_source": "database"})
            assert result.action == "Process the data"
    
    def test_confidence_tracking(self):
        """Test confidence score tracking"""
        tree = DecisionTree(name="confidence_tree")
        
        tree.add_node(DecisionNode(
            id="start",
            question="Are you certain?",
            children={"yes": "proceed", "maybe": "proceed"},
            weight=1.0,
            confidence_adjustment=0.0
        ))
        tree.add_node(DecisionNode(
            id="proceed",
            node_type="action",
            action="Take action",
            confidence_adjustment=-0.2
        ))
        
        with patch('builtins.input', return_value='yes'):
            result = tree.execute(track_confidence=True)
            assert result.confidence is not None
            assert result.confidence <= 1.0


class TestDecisionPath:
    """Test DecisionPath tracking"""
    
    def test_path_creation(self):
        """Test path creation and tracking"""
        path = DecisionPath()
        assert path.steps == []
        assert path.current_confidence == 1.0
    
    def test_add_step(self):
        """Test adding steps to path"""
        path = DecisionPath()
        path.add_step(
            node_id="node1",
            question="Test?",
            answer="yes",
            confidence=0.9
        )
        assert len(path.steps) == 1
        assert path.steps[0]["node_id"] == "node1"
        assert path.steps[0]["answer"] == "yes"
        assert path.current_confidence == 0.9


class TestDecisionResult:
    """Test DecisionResult structure"""
    
    def test_result_creation(self):
        """Test result creation"""
        result = DecisionResult(
            path=["start", "middle", "end"],
            action="Final action",
            confidence=0.85
        )
        assert result.path == ["start", "middle", "end"]
        assert result.action == "Final action"
        assert result.confidence == 0.85
    
    def test_result_with_metadata(self):
        """Test result with additional metadata"""
        result = DecisionResult(
            path=["start", "end"],
            action="Do something",
            confidence=0.9,
            metadata={"duration": 1.5, "user": "test"}
        )
        assert result.metadata["duration"] == 1.5
        assert result.metadata["user"] == "test"


class TestYAMLLoading:
    """Test loading decision trees from YAML"""
    
    def test_load_yaml_tree(self):
        """Test loading a tree from YAML format"""
        yaml_content = """
name: test_tree
description: A test tree
nodes:
  start:
    question: "Is this a test?"
    children:
      yes: "end"
      no: "end"
  end:
    node_type: action
    action: "Test complete"
"""
        # Create a temporary YAML file
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            f.write(yaml_content)
            temp_path = f.name
        
        try:
            tree = DecisionTree.from_yaml(temp_path)
            assert tree.name == "test_tree"
            assert "start" in tree.nodes
            assert "end" in tree.nodes
            assert tree.nodes["end"].action == "Test complete"
        finally:
            Path(temp_path).unlink()


class TestJSONLoading:
    """Test loading decision trees from JSON"""
    
    def test_load_json_tree(self):
        """Test loading a tree from JSON format"""
        json_content = {
            "name": "test_tree",
            "description": "A test tree",
            "nodes": {
                "start": {
                    "question": "Is this a test?",
                    "children": {
                        "yes": "end",
                        "no": "end"
                    }
                },
                "end": {
                    "node_type": "action",
                    "action": "Test complete"
                }
            }
        }
        
        # Create a temporary JSON file
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(json_content, f)
            temp_path = f.name
        
        try:
            tree = DecisionTree.from_json(temp_path)
            assert tree.name == "test_tree"
            assert "start" in tree.nodes
            assert "end" in tree.nodes
            assert tree.nodes["end"].action == "Test complete"
        finally:
            Path(temp_path).unlink()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])