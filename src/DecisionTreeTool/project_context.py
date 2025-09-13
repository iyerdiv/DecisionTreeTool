#!/usr/bin/env python3
"""
Project Context Management for Decision Trees
"""

import os
import json
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime

class ProjectContext:
    """Manages project-specific decision tree storage and organization"""

    def __init__(self, base_dir: str = None, custom_path: str = None):
        # Environment variable support for portable configuration
        workspace_root = os.environ.get('WORKSPACE_ROOT')

        if custom_path:
            self.base_dir = Path(custom_path)
        elif base_dir is not None:
            self.base_dir = Path(base_dir)
        elif workspace_root:
            self.base_dir = Path(workspace_root)
        else:
            # Walk up directory tree to find DecisionTreeTool
            current_dir = Path.cwd()
            while current_dir != current_dir.parent:
                if current_dir.name == "DecisionTreeTool":
                    self.base_dir = current_dir / "decision_trees"
                    break
                current_dir = current_dir.parent
            else:
                # Fallback: use current directory
                self.base_dir = Path.cwd() / "decision_trees"

        # Fail-fast validation and directory creation
        try:
            self.base_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            raise RuntimeError(f"Cannot create base directory {self.base_dir}: {e}")
        self.config_file = self.base_dir / "projects.json"
        self.state_file = self.base_dir / "current_state.json"
        self._load_projects()
        self._load_state()

    def _load_projects(self):
        """Load project configuration"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self.projects = json.load(f)
        else:
            # Default projects based on our workspace
            self.projects = {
                "project1": {
                    "description": "Main project decision trees",
                    "directory": "project1",
                    "tree_types": ["troubleshooting", "analysis", "operational"]
                },
                "project2": {
                    "description": "Secondary project decision trees",
                    "directory": "project2",
                    "tree_types": ["automation", "workflow", "decision"]
                },
                "integration": {
                    "description": "Integration and workflow trees",
                    "directory": "integration",
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

    def _load_state(self):
        """Load current state (active project, etc.)"""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                state = json.load(f)
                self.current_project = state.get("current_project", "general")
        else:
            self.current_project = "general"

    def _save_state(self):
        """Save current state"""
        state = {
            "current_project": getattr(self, 'current_project', 'general'),
            "last_updated": datetime.now().isoformat()
        }
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)

    def list_projects(self) -> Dict[str, dict]:
        """Get all available projects"""
        return self.projects

    def get_project_dir(self, project_name: str) -> Path:
        """Get the directory for a specific project"""
        if project_name not in self.projects:
            raise ValueError(f"Unknown project: {project_name}")

        # Check if project has a custom path configured
        project_config = self.projects[project_name]
        if "custom_path" in project_config:
            project_dir = Path(project_config["custom_path"])
        else:
            project_dir = self.base_dir / project_config["directory"]

        project_dir.mkdir(parents=True, exist_ok=True)
        return project_dir

    def set_project_custom_path(self, project_name: str, custom_path: str):
        """Set a custom storage path for a project"""
        if project_name not in self.projects:
            raise ValueError(f"Unknown project: {project_name}")

        # Validate path exists or can be created
        from pathlib import Path
        path = Path(custom_path)
        try:
            path.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            raise ValueError(f"Cannot create/access path {custom_path}: {e}")

        self.projects[project_name]["custom_path"] = custom_path
        self._save_projects()

    def set_current_project(self, project_name: str):
        """Set the current active project"""
        if project_name not in self.projects:
            raise ValueError(f"Unknown project: {project_name}")

        self.current_project = project_name
        self._save_state()

    def get_current_project(self) -> str:
        """Get the current active project"""
        return getattr(self, 'current_project', 'general')

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
