#!/usr/bin/env python3
"""
Create a minimal DecisionTreeTool installation
"""

import os
import shutil
import sys
from pathlib import Path

def create_minimal_install():
    print("🧹 Creating Minimal DecisionTreeTool Installation")
    print("=" * 50)
    
    # Create backup of decision_trees if it exists
    if os.path.exists("decision_trees"):
        print("💾 Backing up decision_trees/ to decision_trees_backup/...")
        if os.path.exists("decision_trees_backup"):
            shutil.rmtree("decision_trees_backup")
        shutil.copytree("decision_trees", "decision_trees_backup")
        print("✅ Backup created")
    
    # Files/dirs to keep
    keep_files = {
        "manage_decision_tree.py",
        "src/",
        ".git/",
        ".gitignore",
        "requirements.txt"  # If it exists
    }
    
    # Optional: Keep decision trees
    response = input("\n🤔 Keep your saved decision trees? (y/n): ").lower().strip()
    if response == 'y':
        keep_files.add("decision_trees/")
        print("📁 Will keep decision_trees/")
    else:
        print("🗑️  Will delete decision_trees/ (backed up to decision_trees_backup/)")
    
    print(f"\n📋 Files/directories to keep:")
    for item in sorted(keep_files):
        print(f"  ✅ {item}")
    
    # Show what will be deleted
    current_items = set(os.listdir("."))
    to_delete = current_items - keep_files - {".DS_Store", "__pycache__"}
    
    if to_delete:
        print(f"\n🗑️  Files/directories to delete:")
        for item in sorted(to_delete):
            size_info = ""
            if os.path.isfile(item):
                size = os.path.getsize(item)
                size_info = f" ({size} bytes)"
            elif os.path.isdir(item):
                file_count = len([f for f in os.listdir(item) if os.path.isfile(os.path.join(item, f))])
                size_info = f" ({file_count} files)"
            print(f"  ❌ {item}{size_info}")
    
        # Confirm deletion
        confirm = input(f"\n⚠️  Delete {len(to_delete)} items? (y/n): ").lower().strip()
        
        if confirm == 'y':
            print("\n🗑️  Deleting files...")
            for item in to_delete:
                try:
                    if os.path.isfile(item):
                        os.remove(item)
                        print(f"  ✅ Deleted file: {item}")
                    elif os.path.isdir(item):
                        shutil.rmtree(item)
                        print(f"  ✅ Deleted directory: {item}")
                except Exception as e:
                    print(f"  ❌ Failed to delete {item}: {e}")
            
            print("\n✨ Cleanup complete!")
        else:
            print("\n🚫 Cleanup cancelled")
    else:
        print("\n✅ Directory already minimal - nothing to delete")
    
    # Test the minimal installation
    print("\n🧪 Testing minimal installation...")
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from src.DecisionTreeTool.decision_tree_tool import DecisionTreeCLI
        
        cli = DecisionTreeCLI()
        print("✅ DecisionTreeTool loads successfully")
        print(f"✅ Project detection: {cli.current_project}")
        
        # Test basic command
        result = cli.list_projects()
        if "Available Projects" in result:
            print("✅ Project management works")
        
        print("\n🎉 Minimal installation is working!")
        
    except Exception as e:
        print(f"\n❌ Error testing minimal installation: {e}")
        return False
    
    # Show final size
    total_size = 0
    for root, dirs, files in os.walk("."):
        for file in files:
            try:
                total_size += os.path.getsize(os.path.join(root, file))
            except:
                pass
    
    print(f"\n📊 Final installation size: {total_size / 1024:.1f} KB")
    print("\n💡 Usage:")
    print("python3 manage_decision_tree.py --help")
    print("python3 manage_decision_tree.py list-projects")
    
    return True

if __name__ == "__main__":
    if os.getcwd().endswith("DecisionTreeTool"):
        create_minimal_install()
    else:
        print("❌ Run this script from the DecisionTreeTool directory")