#!/usr/bin/env python3
"""
Live tree watcher - Shows tree structure in terminal with auto-refresh
"""

import sys
import time
from pathlib import Path
from rich.console import Console
from rich.tree import Tree
from rich.live import Live
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

console = Console()

class TerminalTreeWatcher(FileSystemEventHandler):
    """Watches tree file and displays in terminal"""

    def __init__(self, tree_path: str):
        self.tree_path = Path(tree_path)
        self.last_content = ""
        self.live_display = None

    def build_tree(self) -> Tree:
        """Parse markdown into terminal tree structure"""
        try:
            with open(self.tree_path, 'r') as f:
                content = f.read()

            # Create root
            tree = Tree(f"🌳 [bold cyan]{self.tree_path.name}[/bold cyan]", guide_style="blue")

            # Parse markdown into tree nodes
            current_section = None
            lines = content.split('\n')

            for line in lines:
                line = line.rstrip()
                if not line:
                    continue

                # Section headers (##)
                if line.startswith('## '):
                    section_name = line[3:].strip()
                    current_section = tree.add(f"[bold yellow]{section_name}[/bold yellow]")

                # Events (starting with -)
                elif line.startswith('- [') and current_section:
                    event_text = line[2:].strip()
                    current_section.add(f"[green]{event_text}[/green]")

                # Chat summaries (└─)
                elif line.strip().startswith('└─') and current_section:
                    chat_text = line.strip()[2:].strip()
                    current_section.add(f"[cyan]{chat_text}[/cyan]")

            return tree

        except Exception as e:
            error_tree = Tree(f"⚠️ Error reading tree", guide_style="red")
            error_tree.add(f"[red]{str(e)}[/red]")
            return error_tree

    def on_modified(self, event):
        if event.src_path == str(self.tree_path):
            if self.live_display:
                self.live_display.update(self.build_tree())

    def watch(self):
        """Start watching with live terminal display"""
        console.print(f"\n[bold]👁️  Watching:[/bold] {self.tree_path}")
        console.print("[dim]Press Ctrl+C to stop[/dim]\n")

        observer = Observer()
        observer.schedule(self, path=str(self.tree_path.parent), recursive=False)
        observer.start()

        try:
            with Live(self.build_tree(), refresh_per_second=2, console=console) as live:
                self.live_display = live
                while True:
                    time.sleep(0.5)

        except KeyboardInterrupt:
            observer.stop()
            console.print("\n\n[bold]👋 Stopped watching tree[/bold]")

        observer.join()

def main():
    if len(sys.argv) < 2:
        console.print("[red]Usage:[/red] python3 watch_tree_terminal.py <path/to/tree.md>")
        sys.exit(1)

    tree_path = sys.argv[1]

    if not Path(tree_path).exists():
        console.print(f"[red]❌ Tree file not found:[/red] {tree_path}")
        sys.exit(1)

    watcher = TerminalTreeWatcher(tree_path)
    watcher.watch()

if __name__ == '__main__':
    main()
