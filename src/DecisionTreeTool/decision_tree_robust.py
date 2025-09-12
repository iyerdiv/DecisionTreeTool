#!/usr/bin/env python3
"""
Robust Decision Tree Tool with Critical Improvements
Enhanced with fallback logic, confidence scoring, and context validation

Critical Improvements:
1. Fallback Logic - Prevents dead ends when no answer matches
2. Confidence Scoring - Track decision quality through the path
3. Context Validation - Ensure required data before proceeding
"""

import json
import yaml
import sys
import argparse
from typing import Dict, Any, List, Optional, Union, Tuple, Set
from pathlib import Path
from dataclasses import dataclass, asdict, field
from datetime import datetime
import uuid
import re


@dataclass
class DecisionNode:
    """Enhanced node with robustness features"""
    id: str
    question: str
    node_type: str = "condition"  # condition, action, data
    children: Dict[str, str] = None  # answer -> child_node_id
    action: Optional[str] = None
    confidence: Optional[float] = None
    metadata: Dict[str, Any] = None
    
    # CRITICAL IMPROVEMENT 1: Fallback Logic
    fallback_node: Optional[str] = None  # Default path if no match
    fallback_reason: Optional[str] = None  # Why fallback was chosen
    
    # CRITICAL IMPROVEMENT 2: Confidence Scoring
    weight: float = 1.0  # Node importance weight
    min_confidence: float = 0.0  # Minimum confidence to proceed
    confidence_adjustment: float = 0.0  # Adjustment to path confidence
    
    # CRITICAL IMPROVEMENT 3: Context Validation
    required_context: List[str] = None  # Required context keys
    optional_context: List[str] = None  # Optional context keys
    context_validators: Dict[str, str] = None  # Context validation rules
    
    def __post_init__(self):
        if self.children is None:
            self.children = {}
        if self.metadata is None:
            self.metadata = {}
        if self.required_context is None:
            self.required_context = []
        if self.optional_context is None:
            self.optional_context = []
        if self.context_validators is None:
            self.context_validators = {}


@dataclass
class TraversalResult:
    """Enhanced traversal result with confidence tracking"""
    action: Optional[str]
    path: List[str]
    confidence: float
    context_used: Dict[str, Any]
    fallbacks_used: List[str]
    validation_errors: List[str]
    final_node_id: Optional[str]


class RobustDecisionTree:
    """Decision tree with fallback logic, confidence scoring, and context validation"""
    
    def __init__(self, name: str = "Decision Tree", description: str = "",
                 default_confidence: float = 1.0,
                 confidence_threshold: float = 0.5):
        self.name = name
        self.description = description
        self.nodes: Dict[str, DecisionNode] = {}
        self.root_id: Optional[str] = None
        self.created_at = datetime.now().isoformat()
        self.updated_at = self.created_at
        
        # Global confidence settings
        self.default_confidence = default_confidence
        self.confidence_threshold = confidence_threshold
        
        # Context requirements
        self.global_required_context: Set[str] = set()
        self.global_optional_context: Set[str] = set()
        
    def add_node(self, question: str, node_type: str = "condition",
                 action: str = None, confidence: float = None,
                 metadata: Dict = None,
                 fallback_node: str = None, fallback_reason: str = None,
                 weight: float = 1.0, min_confidence: float = 0.0,
                 required_context: List[str] = None,
                 optional_context: List[str] = None,
                 context_validators: Dict[str, str] = None) -> str:
        """Add an enhanced node with robustness features"""
        node_id = str(uuid.uuid4())[:8]
        
        node = DecisionNode(
            id=node_id,
            question=question,
            node_type=node_type,
            action=action,
            confidence=confidence or self.default_confidence,
            metadata=metadata or {},
            fallback_node=fallback_node,
            fallback_reason=fallback_reason,
            weight=weight,
            min_confidence=min_confidence,
            required_context=required_context or [],
            optional_context=optional_context or [],
            context_validators=context_validators or {}
        )
        
        self.nodes[node_id] = node
        
        # Update global context requirements
        if required_context:
            self.global_required_context.update(required_context)
        if optional_context:
            self.global_optional_context.update(optional_context)
        
        # Set as root if first node
        if self.root_id is None:
            self.root_id = node_id
            
        self._update_timestamp()
        return node_id
    
    def add_child(self, parent_id: str, answer: str, child_id: str):
        """Add a child relationship"""
        if parent_id in self.nodes:
            self.nodes[parent_id].children[answer] = child_id
            self._update_timestamp()
    
    def set_fallback(self, node_id: str, fallback_node_id: str, reason: str = "No match found"):
        """Set fallback for a node"""
        if node_id in self.nodes:
            self.nodes[node_id].fallback_node = fallback_node_id
            self.nodes[node_id].fallback_reason = reason
            self._update_timestamp()
    
    def validate_context(self, context: Dict[str, Any], node: DecisionNode) -> Tuple[bool, List[str]]:
        """Validate context against node requirements"""
        errors = []
        
        # Check required context
        for req in node.required_context:
            if req not in context or context[req] is None:
                errors.append(f"Missing required context: {req}")
        
        # Run custom validators
        for key, validator_expr in node.context_validators.items():
            if key in context:
                try:
                    # Simple validation expressions (can be enhanced)
                    if validator_expr.startswith("type:"):
                        expected_type = validator_expr[5:]
                        if expected_type == "number" and not isinstance(context[key], (int, float)):
                            errors.append(f"Context '{key}' must be a number")
                        elif expected_type == "string" and not isinstance(context[key], str):
                            errors.append(f"Context '{key}' must be a string")
                        elif expected_type == "boolean" and not isinstance(context[key], bool):
                            errors.append(f"Context '{key}' must be a boolean")
                    elif validator_expr.startswith("min:"):
                        min_val = float(validator_expr[4:])
                        if isinstance(context[key], (int, float)) and context[key] < min_val:
                            errors.append(f"Context '{key}' must be at least {min_val}")
                    elif validator_expr.startswith("max:"):
                        max_val = float(validator_expr[4:])
                        if isinstance(context[key], (int, float)) and context[key] > max_val:
                            errors.append(f"Context '{key}' must be at most {max_val}")
                except Exception as e:
                    errors.append(f"Validation error for '{key}': {str(e)}")
        
        return len(errors) == 0, errors
    
    def find_best_match(self, node: DecisionNode, answer: str, 
                       context: Dict[str, Any]) -> Tuple[Optional[str], float, str]:
        """Find best matching child with fuzzy matching"""
        if not node.children:
            # No children - check fallback
            if node.fallback_node:
                return node.fallback_node, 0.5, node.fallback_reason or "No children, using fallback"
            return None, 0.0, "No children"
        
        # Try exact match first
        if answer in node.children:
            return node.children[answer], 1.0, "Exact match"
        
        # Try case-insensitive match
        answer_lower = answer.lower()
        for child_answer, child_id in node.children.items():
            if child_answer.lower() == answer_lower:
                return child_id, 0.9, "Case-insensitive match"
        
        # Try regex patterns in children keys (before partial match)
        for child_answer, child_id in node.children.items():
            if child_answer.startswith("regex:"):
                pattern = child_answer[6:]
                if re.match(pattern, answer):  # Remove IGNORECASE for strict matching
                    return child_id, 0.8, f"Regex match: {pattern}"
        
        # Try partial match
        for child_answer, child_id in node.children.items():
            # Skip regex patterns
            if child_answer.startswith("regex:"):
                continue
            if answer_lower in child_answer.lower() or child_answer.lower() in answer_lower:
                return child_id, 0.7, "Partial match"
        
        # No match found - use fallback if available
        if node.fallback_node:
            return node.fallback_node, 0.5, node.fallback_reason or "Using fallback"
        
        return None, 0.0, "No match or fallback"
    
    def traverse_robust(self, answers: Dict[str, str], 
                       context: Dict[str, Any] = None) -> TraversalResult:
        """Robust traversal with fallback, confidence, and validation"""
        if not self.root_id:
            return TraversalResult(
                action=None,
                path=["Error: Empty tree"],
                confidence=0.0,
                context_used={},
                fallbacks_used=[],
                validation_errors=["No root node"],
                final_node_id=None
            )
        
        context = context or {}
        current_id = self.root_id
        path = []
        cumulative_confidence = self.default_confidence
        fallbacks_used = []
        validation_errors = []
        context_used = {}
        
        while current_id:
            current_node = self.nodes[current_id]
            
            # Validate context for this node
            is_valid, errors = self.validate_context(context, current_node)
            if errors:
                validation_errors.extend(errors)
                # Continue with warnings but track errors
            
            path.append(f"[{cumulative_confidence:.2f}] Node: {current_node.question}")
            
            # Check minimum confidence threshold
            if cumulative_confidence < current_node.min_confidence:
                path.append(f"⚠️ Confidence {cumulative_confidence:.2f} below minimum {current_node.min_confidence}")
                if not current_node.fallback_node:
                    return TraversalResult(
                        action=None,
                        path=path,
                        confidence=cumulative_confidence,
                        context_used=context_used,
                        fallbacks_used=fallbacks_used,
                        validation_errors=validation_errors,
                        final_node_id=current_id
                    )
            
            # Check if this is an action node
            if current_node.node_type == "action":
                path.append(f"✓ Action: {current_node.action}")
                return TraversalResult(
                    action=current_node.action,
                    path=path,
                    confidence=cumulative_confidence,
                    context_used=context_used,
                    fallbacks_used=fallbacks_used,
                    validation_errors=validation_errors,
                    final_node_id=current_id
                )
            
            # Find next node based on answer
            answer_key = current_node.question
            answer = answers.get(answer_key, context.get(answer_key))
            
            if answer is None and current_node.fallback_node:
                # No answer provided, use fallback
                next_id = current_node.fallback_node
                match_confidence = 0.5
                match_reason = "No answer provided, using fallback"
                fallbacks_used.append(f"{current_id} -> {next_id}")
            else:
                # Try to find best match
                next_id, match_confidence, match_reason = self.find_best_match(
                    current_node, str(answer), context
                )
            
            if next_id:
                # Update cumulative confidence
                cumulative_confidence *= match_confidence * current_node.weight
                cumulative_confidence += current_node.confidence_adjustment
                
                # Track what we used
                context_used[answer_key] = answer
                path.append(f"  → {match_reason}: '{answer}' (confidence: {match_confidence:.2f})")
                
                # Check global confidence threshold
                if cumulative_confidence < self.confidence_threshold:
                    path.append(f"⚠️ Confidence {cumulative_confidence:.2f} below threshold {self.confidence_threshold}")
                    # Try fallback if available
                    if current_node.fallback_node:
                        next_id = current_node.fallback_node
                        fallbacks_used.append(f"Low confidence fallback: {current_id} -> {next_id}")
                    else:
                        return TraversalResult(
                            action=None,
                            path=path,
                            confidence=cumulative_confidence,
                            context_used=context_used,
                            fallbacks_used=fallbacks_used,
                            validation_errors=validation_errors,
                            final_node_id=current_id
                        )
            else:
                # Complete dead end
                path.append(f"✗ Dead end: No match, no fallback")
                return TraversalResult(
                    action=None,
                    path=path,
                    confidence=cumulative_confidence,
                    context_used=context_used,
                    fallbacks_used=fallbacks_used,
                    validation_errors=validation_errors,
                    final_node_id=current_id
                )
            
            current_id = next_id
        
        return TraversalResult(
            action=None,
            path=path,
            confidence=cumulative_confidence,
            context_used=context_used,
            fallbacks_used=fallbacks_used,
            validation_errors=validation_errors,
            final_node_id=current_id
        )
    
    def analyze_robustness(self) -> Dict[str, Any]:
        """Analyze tree robustness and identify weak points"""
        analysis = {
            "total_nodes": len(self.nodes),
            "nodes_with_fallback": 0,
            "nodes_with_validation": 0,
            "dead_ends": [],
            "low_confidence_nodes": [],
            "missing_context_validation": [],
            "coverage_score": 0.0
        }
        
        for node_id, node in self.nodes.items():
            # Check fallbacks
            if node.fallback_node:
                analysis["nodes_with_fallback"] += 1
            elif node.node_type == "condition" and not node.children:
                analysis["dead_ends"].append(node_id)
            
            # Check validation
            if node.required_context or node.context_validators:
                analysis["nodes_with_validation"] += 1
            elif node.node_type == "condition":
                analysis["missing_context_validation"].append(node_id)
            
            # Check confidence
            if node.min_confidence > 0.7:
                analysis["low_confidence_nodes"].append({
                    "id": node_id,
                    "min_confidence": node.min_confidence,
                    "question": node.question
                })
        
        # Calculate coverage score
        if analysis["total_nodes"] > 0:
            fallback_coverage = analysis["nodes_with_fallback"] / analysis["total_nodes"]
            validation_coverage = analysis["nodes_with_validation"] / analysis["total_nodes"]
            analysis["coverage_score"] = (fallback_coverage + validation_coverage) / 2
        
        return analysis
    
    def add_global_fallback(self, fallback_action: str):
        """Add a global fallback for all dead ends"""
        fallback_id = self.add_node(
            question="Global Fallback",
            node_type="action",
            action=fallback_action,
            confidence=0.3,
            metadata={"is_global_fallback": True}
        )
        
        # Set as fallback for all nodes without children or fallback
        for node_id, node in self.nodes.items():
            if node.node_type == "condition" and not node.children and not node.fallback_node:
                node.fallback_node = fallback_id
                node.fallback_reason = "Global fallback - no specific match"
        
        return fallback_id
    
    def optimize_confidence_weights(self, success_paths: List[List[str]]):
        """Optimize node weights based on successful traversals"""
        # Count node usage in successful paths
        node_usage = {}
        for path in success_paths:
            for node_id in path:
                node_usage[node_id] = node_usage.get(node_id, 0) + 1
        
        # Adjust weights based on usage
        total_usage = sum(node_usage.values())
        if total_usage > 0:
            for node_id, usage in node_usage.items():
                if node_id in self.nodes:
                    # Higher weight for frequently used nodes in successful paths
                    self.nodes[node_id].weight = 0.5 + (usage / total_usage)
    
    def to_dict(self) -> Dict[str, Any]:
        """Export tree to dictionary with robustness features"""
        return {
            "name": self.name,
            "description": self.description,
            "root_id": self.root_id,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "default_confidence": self.default_confidence,
            "confidence_threshold": self.confidence_threshold,
            "global_required_context": list(self.global_required_context),
            "global_optional_context": list(self.global_optional_context),
            "nodes": {
                node_id: asdict(node) for node_id, node in self.nodes.items()
            },
            "robustness_analysis": self.analyze_robustness()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'RobustDecisionTree':
        """Import tree from dictionary"""
        tree = cls(
            data.get("name", ""),
            data.get("description", ""),
            data.get("default_confidence", 1.0),
            data.get("confidence_threshold", 0.5)
        )
        tree.root_id = data.get("root_id")
        tree.created_at = data.get("created_at", datetime.now().isoformat())
        tree.updated_at = data.get("updated_at", datetime.now().isoformat())
        tree.global_required_context = set(data.get("global_required_context", []))
        tree.global_optional_context = set(data.get("global_optional_context", []))
        
        for node_id, node_data in data.get("nodes", {}).items():
            tree.nodes[node_id] = DecisionNode(**node_data)
        
        return tree
    
    def _update_timestamp(self):
        """Update the last modified timestamp"""
        self.updated_at = datetime.now().isoformat()


def create_example_robust_tree() -> RobustDecisionTree:
    """Create an example tree demonstrating robustness features"""
    tree = RobustDecisionTree(
        "Robust Customer Support Tree",
        "Demonstrates fallback, confidence, and validation",
        default_confidence=1.0,
        confidence_threshold=0.4
    )
    
    # Root node with context validation
    root = tree.add_node(
        question="issue_type",
        required_context=["customer_id", "product_id"],
        optional_context=["previous_tickets"],
        context_validators={
            "customer_id": "type:string",
            "product_id": "type:string"
        }
    )
    
    # Technical branch with confidence scoring
    tech = tree.add_node(
        question="technical_category",
        weight=0.9,
        min_confidence=0.5,
        required_context=["error_code"]
    )
    tree.add_child(root, "technical", tech)
    
    # Billing branch with fallback
    billing = tree.add_node(
        question="billing_category",
        weight=0.8
    )
    tree.add_child(root, "billing", billing)
    
    # Action nodes
    restart = tree.add_node(
        question="Restart Required",
        node_type="action",
        action="Guide customer through restart process",
        confidence=0.9
    )
    tree.add_child(tech, "connectivity", restart)
    
    refund = tree.add_node(
        question="Process Refund",
        node_type="action",
        action="Initiate refund process",
        confidence=0.85
    )
    tree.add_child(billing, "overcharge", refund)
    
    # Global fallback for unhandled cases
    escalate = tree.add_node(
        question="Escalate to Human",
        node_type="action",
        action="Transfer to human agent",
        confidence=0.3
    )
    
    # Set fallbacks
    tree.set_fallback(root, escalate, "Unknown issue type")
    tree.set_fallback(tech, escalate, "Unknown technical issue")
    tree.set_fallback(billing, escalate, "Unknown billing issue")
    
    return tree


def demonstrate_robustness():
    """Demonstrate the robustness features"""
    tree = create_example_robust_tree()
    
    print("=== Robust Decision Tree Demo ===\n")
    
    # Test 1: Perfect match with all context
    print("Test 1: Perfect match with complete context")
    result = tree.traverse_robust(
        {"issue_type": "technical", "technical_category": "connectivity"},
        {"customer_id": "CUST123", "product_id": "PROD456", "error_code": "E501"}
    )
    print(f"Action: {result.action}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"Path: {result.path[-1]}\n")
    
    # Test 2: Fuzzy match with partial context
    print("Test 2: Fuzzy match (case insensitive)")
    result = tree.traverse_robust(
        {"issue_type": "TECHNICAL", "technical_category": "CONNECT"},
        {"customer_id": "CUST123", "product_id": "PROD456", "error_code": "E501"}
    )
    print(f"Action: {result.action}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"Fallbacks used: {result.fallbacks_used}\n")
    
    # Test 3: Missing context - validation warnings
    print("Test 3: Missing required context")
    result = tree.traverse_robust(
        {"issue_type": "technical", "technical_category": "connectivity"},
        {"customer_id": "CUST123"}  # Missing product_id and error_code
    )
    print(f"Validation errors: {result.validation_errors}")
    print(f"Action: {result.action}\n")
    
    # Test 4: No match - using fallback
    print("Test 4: No match - fallback triggered")
    result = tree.traverse_robust(
        {"issue_type": "unknown_type"},
        {"customer_id": "CUST123", "product_id": "PROD456"}
    )
    print(f"Action: {result.action}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"Fallbacks used: {result.fallbacks_used}\n")
    
    # Test 5: Robustness analysis
    print("Test 5: Tree Robustness Analysis")
    analysis = tree.analyze_robustness()
    print(f"Total nodes: {analysis['total_nodes']}")
    print(f"Nodes with fallback: {analysis['nodes_with_fallback']}")
    print(f"Nodes with validation: {analysis['nodes_with_validation']}")
    print(f"Coverage score: {analysis['coverage_score']:.2%}")
    print(f"Dead ends: {analysis['dead_ends']}")


if __name__ == "__main__":
    demonstrate_robustness()