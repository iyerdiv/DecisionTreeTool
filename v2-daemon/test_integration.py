#!/usr/bin/env python3
"""Integration test for Phase 2 AI extraction"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / 'src'))

def test_imports():
    """Test that all modules import correctly"""
    print("Testing imports...")

    try:
        from watcher import __version__
        print(f"✓ watcher.__version__ = {__version__}")
    except ImportError as e:
        print(f"✗ Failed to import watcher.__version__: {e}")
        return False

    try:
        from watcher.event import Event, EventStore
        print("✓ watcher.event (Event, EventStore)")
    except ImportError as e:
        print(f"✗ Failed to import watcher.event: {e}")
        return False

    try:
        from watcher.logger import TreeLogger
        print("✓ watcher.logger (TreeLogger)")
    except ImportError as e:
        print(f"✗ Failed to import watcher.logger: {e}")
        return False

    try:
        from watcher.category_engine import CategoryEngine
        print("✓ watcher.category_engine (CategoryEngine)")
    except ImportError as e:
        print(f"✗ Failed to import watcher.category_engine: {e}")
        return False

    try:
        from watcher.intelligent_logger import IntelligentLogger
        print("✓ watcher.intelligent_logger (IntelligentLogger)")
    except ImportError as e:
        print(f"✗ Failed to import watcher.intelligent_logger: {e}")
        return False

    return True

def test_category_engine():
    """Test CategoryEngine initialization"""
    print("\nTesting CategoryEngine...")

    from watcher.category_engine import CategoryEngine

    # Test without API key (fallback mode)
    engine = CategoryEngine(api_key=None)
    print(f"✓ CategoryEngine(no API key) - enabled={engine.enabled}")

    # Test categories
    print(f"✓ Categories defined: {len(CategoryEngine.CATEGORIES)}")
    for num, name in CategoryEngine.CATEGORIES.items():
        print(f"  {num}. {name}")

    return True

def test_intelligent_logger():
    """Test IntelligentLogger initialization"""
    print("\nTesting IntelligentLogger...")

    from watcher.intelligent_logger import IntelligentLogger
    import tempfile
    import os

    # Create temp tree file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
        tree_path = f.name
        f.write("# Test Tree\n## 📝 Event Log\n")

    try:
        # Test with AI disabled
        logger_no_ai = IntelligentLogger(tree_path, enable_ai=False)
        print(f"✓ IntelligentLogger(enable_ai=False) - ai_enabled={logger_no_ai.ai_enabled}")

        # Test with AI enabled but no key (should fallback gracefully)
        logger_with_ai = IntelligentLogger(tree_path, enable_ai=True)
        print(f"✓ IntelligentLogger(enable_ai=True) - ai_enabled={logger_with_ai.ai_enabled}")

        return True
    finally:
        os.unlink(tree_path)

def test_event_creation():
    """Test Event creation and formatting"""
    print("\nTesting Event creation...")

    from watcher.event import Event
    from datetime import datetime

    event = Event(
        timestamp=datetime.now(),
        path="src/auth.py",
        event_type="code_change",
        tags=["auto", "workspace", "source_code"]
    )

    print(f"✓ Event created: {event.unique_id}")
    print(f"  Path: {event.path}")
    print(f"  Type: {event.event_type}")
    print(f"  Log entry: {event.to_log_entry()}")

    return True

def main():
    """Run all tests"""
    print("=" * 60)
    print("DecisionTreeTool v2 - Phase 2 Integration Test")
    print("=" * 60)
    print()

    tests = [
        ("Module Imports", test_imports),
        ("CategoryEngine", test_category_engine),
        ("IntelligentLogger", test_intelligent_logger),
        ("Event Creation", test_event_creation),
    ]

    passed = 0
    failed = 0

    for name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                failed += 1
                print(f"✗ {name} FAILED")
        except Exception as e:
            failed += 1
            print(f"✗ {name} FAILED with exception: {e}")

    print()
    print("=" * 60)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 60)

    return failed == 0

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
