"""File system watcher implementation"""

import os
import sys
import time
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Set
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileSystemEvent

from .event import Event, EventStore
from .logger import TreeLogger
from .chat_extractor import ChatExtractor


class OpsBrainEventHandler(FileSystemEventHandler):
    """Handles file system events and converts to OpsBrain events"""

    def __init__(self, event_store: EventStore, tree_logger: TreeLogger, watch_path: str):
        super().__init__()
        self.event_store = event_store
        self.tree_logger = tree_logger
        self.watch_path = watch_path
        self.chat_extractor = ChatExtractor()
        self.ignored_patterns: Set[str] = {
            '.git', '__pycache__', '.DS_Store',
            '.pyc', '.swp', '~', '.tmp'
        }

    def should_ignore(self, path: str) -> bool:
        """Check if path should be ignored"""
        path_obj = Path(path)

        # Ignore if any part matches ignored patterns
        for part in path_obj.parts:
            for pattern in self.ignored_patterns:
                if pattern in part:
                    return True

        return False

    def get_relative_path(self, absolute_path: str) -> str:
        """Convert absolute path to relative from watch root"""
        try:
            return str(Path(absolute_path).relative_to(self.watch_path))
        except ValueError:
            return absolute_path

    def determine_event_type(self, path: str) -> str:
        """Determine event type based on path"""
        path_lower = path.lower()

        if 'claude_prompt' in path_lower or 'next_prompt' in path_lower:
            return "prompt_created"
        elif 'opsbrain_' in path_lower and path_lower.endswith('.md'):
            return "tree_update"
        elif path_lower.endswith(('.py', '.java', '.scala', '.js', '.ts')):
            return "code_change"
        elif path_lower.endswith('.md'):
            return "doc_change"
        else:
            return "file_change"

    def generate_tags(self, path: str, event_type: str) -> list:
        """Generate hashtags for the event"""
        tags = ["auto", "workspace"]

        # Add event type tag
        tags.append(event_type)

        # Add update tag for modifications
        tags.append("update")

        # Add path-based tags
        if 'claude_prompts' in path:
            tags.append("claude_prompts")
        elif 'daily_trees' in path:
            tags.append("daily_trees")
        elif 'src/' in path:
            tags.append("source_code")

        return tags

    def on_modified(self, event: FileSystemEvent):
        """Handle file modification events"""
        if event.is_directory or self.should_ignore(event.src_path):
            return

        rel_path = self.get_relative_path(event.src_path)
        event_type = self.determine_event_type(rel_path)
        tags = self.generate_tags(rel_path, event_type)

        # Create event
        obs_event = Event(
            timestamp=datetime.now(),
            path=rel_path,
            event_type=event_type,
            tags=tags
        )

        # Store event
        self.event_store.add_event(obs_event)

        # Log to tree (basic event)
        self.tree_logger.log_event(obs_event)

        # If it's a prompt file, extract chat content
        if event_type == "prompt_created":
            extraction = self.chat_extractor.extract_from_file(event.src_path)
            if extraction:
                chat_summary = self.chat_extractor.format_for_tree(extraction)
                # Log chat summary as additional line
                with open(self.tree_logger.tree_path, 'a') as f:
                    f.write(f"  └─ {chat_summary}\n")
                print(f"✓ {obs_event.to_log_entry()}")
                print(f"  └─ {chat_summary}")
            else:
                print(f"✓ {obs_event.to_log_entry()}")
        else:
            print(f"✓ {obs_event.to_log_entry()}")

    def on_created(self, event: FileSystemEvent):
        """Handle file creation events"""
        if event.is_directory or self.should_ignore(event.src_path):
            return

        rel_path = self.get_relative_path(event.src_path)
        event_type = self.determine_event_type(rel_path)
        tags = self.generate_tags(rel_path, event_type) + ["created"]

        # Create event
        obs_event = Event(
            timestamp=datetime.now(),
            path=rel_path,
            event_type=event_type,
            tags=tags
        )

        # Store and log
        self.event_store.add_event(obs_event)
        self.tree_logger.log_event(obs_event)

        # If it's a prompt file, extract chat content
        if event_type == "prompt_created":
            extraction = self.chat_extractor.extract_from_file(event.src_path)
            if extraction:
                chat_summary = self.chat_extractor.format_for_tree(extraction)
                # Log chat summary as additional line
                with open(self.tree_logger.tree_path, 'a') as f:
                    f.write(f"  └─ {chat_summary}\n")
                print(f"✓ {obs_event.to_log_entry()}")
                print(f"  └─ {chat_summary}")
            else:
                print(f"✓ {obs_event.to_log_entry()}")
        else:
            print(f"✓ {obs_event.to_log_entry()}")


class FileSystemWatcher:
    """Main file system watcher"""

    def __init__(self, watch_path: str, tree_path: str):
        self.watch_path = os.path.abspath(watch_path)
        self.tree_path = tree_path
        self.event_store = EventStore(storage_path=tree_path)
        self.tree_logger = TreeLogger(tree_path=tree_path)
        self.observer: Optional[Observer] = None

    def start(self, auto_view: bool = True):
        """Start watching the file system"""
        print(f"🔍 Starting OpsBrain Watcher")
        print(f"   Watching: {self.watch_path}")
        print(f"   Logging to: {self.tree_path}")
        print()

        # Create event handler
        event_handler = OpsBrainEventHandler(
            event_store=self.event_store,
            tree_logger=self.tree_logger,
            watch_path=self.watch_path
        )

        # Set up observer
        self.observer = Observer()
        self.observer.schedule(event_handler, self.watch_path, recursive=True)
        self.observer.start()

        print("✓ Watcher started successfully")
        print("  Press Ctrl+C to stop")
        print()

        # Auto-launch terminal tree viewer in new window
        if auto_view:
            self._launch_tree_viewer()

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()

    def _launch_tree_viewer(self):
        """Launch terminal tree viewer in new terminal window"""
        try:
            viewer_script = Path(__file__).parent / "watch_tree_terminal.py"

            if not viewer_script.exists():
                print(f"⚠️  Tree viewer not found: {viewer_script}")
                return

            # macOS: Open new Terminal window
            if sys.platform == "darwin":
                cmd = [
                    "osascript", "-e",
                    f'tell application "Terminal" to do script "cd {Path.cwd()} && python3 {viewer_script} {self.tree_path}"'
                ]
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print(f"🌳 Launched tree viewer in new terminal window")

            # Linux: Try gnome-terminal, xterm, konsole
            elif sys.platform == "linux":
                for term in ["gnome-terminal", "xterm", "konsole"]:
                    try:
                        cmd = [term, "--", "python3", str(viewer_script), self.tree_path]
                        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        print(f"🌳 Launched tree viewer in new {term} window")
                        break
                    except FileNotFoundError:
                        continue

            # Windows: Use start command
            elif sys.platform == "win32":
                cmd = f'start cmd /k python {viewer_script} {self.tree_path}'
                subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print(f"🌳 Launched tree viewer in new cmd window")

        except Exception as e:
            print(f"⚠️  Could not auto-launch tree viewer: {e}")
            print(f"   Run manually: python3 {viewer_script} {self.tree_path}")

    def stop(self):
        """Stop watching"""
        if self.observer:
            print("\n🛑 Stopping watcher...")
            self.observer.stop()
            self.observer.join()
            print("✓ Watcher stopped")
