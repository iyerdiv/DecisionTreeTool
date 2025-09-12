#!/usr/bin/env python3
"""
Simple command-line tool for creating and managing decision trees.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from src.DecisionTreeTool.decision_tree_tool import main

if __name__ == "__main__":
    main()