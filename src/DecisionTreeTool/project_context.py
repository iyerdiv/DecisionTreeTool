#!/usr/bin/env python3
"""
Project Context Management for Decision Trees
"""

import os
import json
from pathlib import Path
from typing import Dict, List, Optional

class ProjectContext:
    """Manages project-specific decision tree storage and organization"""
    
    def __init__(self, base_dir: str = None):
        if base_dir is None:
            # Auto-detect if we're in DecisionTreeTool directory
            current_dir = Path.cwd()
            if current_dir.name == "DecisionTreeTool":
                self.base_dir = current_dir / "decision_trees"
            else:
                # Fallback to home directory
                self.base_dir = Path.home() / ".decision_trees"
        else:
            self.base_dir = Path(base_dir)
        
        self.base_dir.mkdir(exist_ok=True)
        self.config_file = self.base_dir / "projects.json"
        self._load_projects()
    
    def _load_projects(self):
        """Load project configuration"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self.projects = json.load(f)
        else:
            # Default projects based on our workspace
            self.projects = {
                "PerfectMileSciOpsBrain": {
                    "description": "OpsBrain RCA and analytics system",
                    "directory": "PerfectMileSciOpsBrain",
                    "tree_types": ["troubleshooting", "rca", "operational"]
                },
                "ctrl-alt-delegate": {
                    "description": "Automation and behavioral learning system", 
                    "directory": "ctrl-alt-delegate",
                    "tree_types": ["automation", "behavioral", "decision"]
                },
                "QEcosystem": {
                    "description": "Q and MCP tools integration",
                    "directory": "QEcosystem", 
                    "tree_types": ["integration", "workflow", "troubleshooting"]
                },
                "DecisionTreeTool": {
                    "description": "Decision tree framework itself",
                    "directory": "DecisionTreeTool",
                    "tree_types": ["development", "testing", "examples"]
                },
                "general": {
                    "description": "General purpose decision trees",
                    "directory": "general",
                    "tree_types": ["personal", "workflows", "troubleshooting"]
                }
            }
            self._save_projects()
    
    def _save_projects(self):
        """Save project configuration"""
        with open(self.config_file, 'w') as f:
            json.dump(self.projects, f, indent=2)
    
    def list_projects(self) -> Dict[str, dict]:
        """Get all available projects"""
        return self.projects
    
    def get_project_dir(self, project_name: str) -> Path:
        """Get the directory for a specific project"""
        if project_name not in self.projects:
            raise ValueError(f"Unknown project: {project_name}")
        
        project_dir = self.base_dir / self.projects[project_name]["directory"]
        project_dir.mkdir(exist_ok=True)
        return project_dir
    
    def add_project(self, name: str, description: str, tree_types: List[str] = None):
        """Add a new project"""
        if tree_types is None:
            tree_types = ["general"]
        
        self.projects[name] = {
            "description": description,
            "directory": name.lower().replace(" ", "_"),
            "tree_types": tree_types
        }
        self._save_projects()
        
        # Create the directory
        self.get_project_dir(name)
    
    def get_project_trees(self, project_name: str) -> List[str]:
        """List all decision tree files for a project"""
        project_dir = self.get_project_dir(project_name)
        tree_files = []
        
        for ext in [".json", ".yaml", ".yml"]:
            tree_files.extend([f.stem for f in project_dir.glob(f"*{ext}")])
        
        return sorted(list(set(tree_files)))
    
    def get_tree_path(self, project_name: str, tree_name: str, format_type: str = "json") -> Path:
        """Get the full path for a decision tree file"""
        project_dir = self.get_project_dir(project_name)
        
        # Clean tree name for filename
        clean_name = tree_name.lower().replace(" ", "_").replace("/", "_")
        
        # Map format to file extension
        ext_map = {
            "json": ".json",
            "yaml": ".yaml", 
            "yml": ".yaml",
            "mermaid": ".mmd",
            "dot": ".dot",
            "ascii": ".txt"
        }
        
        ext = ext_map.get(format_type, ".json")
        return project_dir / f"{clean_name}{ext}"
    
    def detect_current_project(self) -> Optional[str]:
        """Try to detect current project from working directory"""
        cwd = Path.cwd()
        
        # Check if we're in a known project directory
        for project_name, config in self.projects.items():
            if project_name.lower() in str(cwd).lower():
                return project_name
        
        # Check parent directories
        for parent in cwd.parents:
            parent_name = parent.name
            for project_name in self.projects.keys():
                if project_name.lower() == parent_name.lower():
                    return project_name
        
        return "general"  # Default fallback


def get_project_context() -> ProjectContext:
    """Get the global project context instance"""
    return ProjectContext()


if __name__ == "__main__":
    # Demo the project context
    ctx = get_project_context()
    
    print("📁 Available Projects:")
    for name, config in ctx.list_projects().items():
        print(f"  • {name}: {config['description']}")
        print(f"    Directory: {ctx.get_project_dir(name)}")
        trees = ctx.get_project_trees(name)
        if trees:
            print(f"    Trees: {', '.join(trees)}")
        print()
    
    current = ctx.detect_current_project()
    print(f"🎯 Detected current project: {current}")